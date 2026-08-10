extends Node
## Procedural sound effects — **there is no `.wav`/`.ogg` in this repo**, so every clip here is synthesized
##  once, at boot, straight into PCM bytes (`AudioStreamWAV`). Generating at boot rather than at call time
##  keeps a hot path (`play_fire()` fires on every click) free of any DSP work.
##
## **Screen-only, like everything in `src/view/`.** A sound is heard differently per client the same way
##  `blast_fx.gd`'s screen shake is allowed to use `randf()` — not one byte here feeds back into the sim.
##
## **A fixed pool of `AudioStreamPlayer`s, not one node per sound.** The same discipline `blast_fx.gd`
##  already states for flashes ("do not `add_child` a node per blast") — a chain of blasts landing on one
##  tick is the ordinary case, not the rare one, so the pool is sized for that (`Fx.SFX_VOICES`).
##
## **Every play is counted, whether or not `Fx.SFX_ENABLED` lets it actually sound.** `play_count(name)` is
## the one thing a headless net can read — CLAUDE.md's own line for this feature is "whether it rang" is
## measurable, "does it sound good" is not. Counting before the switch check means a net can tell "the call
## arrived" from "the switch ate it", instead of both cases reading as zero.

const Fx := preload("res://src/view/fx_tuning.gd")

const NAME_FIRE := "fire"
const NAME_BLAST := "blast"
const NAME_JUMP := "jump"
const NAME_LAND := "land"
const NAME_HIT := "hit"

var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0

var _stream_fire: AudioStreamWAV
var _stream_blast: AudioStreamWAV
var _stream_jump: AudioStreamWAV
var _stream_land: AudioStreamWAV
var _stream_hit: AudioStreamWAV

## **A running total, never cleared.** `net_sfx` reads the delta around one call rather than an absolute
##  value, so there is no reset to forget (the same choice `world_step`'s own fire/impact counters made).
var _play_counts: Dictionary = {
	NAME_FIRE: 0, NAME_BLAST: 0, NAME_JUMP: 0, NAME_LAND: 0, NAME_HIT: 0,
}


func _ready() -> void:
	_stream_fire = _make_tone(Fx.SFX_FIRE_SEC, Fx.SFX_FIRE_FREQ_START, Fx.SFX_FIRE_FREQ_END)
	_stream_blast = _make_noise(Fx.SFX_BLAST_SEC, Fx.SFX_BLAST_DECAY_POW)
	_stream_jump = _make_tone(Fx.SFX_JUMP_SEC, Fx.SFX_JUMP_FREQ_START, Fx.SFX_JUMP_FREQ_END)
	_stream_land = _make_tone(Fx.SFX_LAND_SEC, Fx.SFX_LAND_FREQ_START, Fx.SFX_LAND_FREQ_END)
	_stream_hit = _make_noise(Fx.SFX_HIT_SEC, Fx.SFX_HIT_DECAY_POW)
	for i in Fx.SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


# ══════════════════════════════════════════════════════════════════
#  Triggers — one call per event, no state kept by the caller
# ══════════════════════════════════════════════════════════════════

func play_fire() -> void:
	_play(NAME_FIRE, _stream_fire, Fx.SFX_MASTER_DB + Fx.SFX_FIRE_DB)


func play_blast() -> void:
	_play(NAME_BLAST, _stream_blast, Fx.SFX_MASTER_DB + Fx.SFX_BLAST_DB)


func play_jump() -> void:
	_play(NAME_JUMP, _stream_jump, Fx.SFX_MASTER_DB + Fx.SFX_JUMP_DB)


func play_land() -> void:
	_play(NAME_LAND, _stream_land, Fx.SFX_MASTER_DB + Fx.SFX_LAND_DB)


func play_hit() -> void:
	_play(NAME_HIT, _stream_hit, Fx.SFX_MASTER_DB + Fx.SFX_HIT_DB)


## **Read by name, not one getter per sound** — a net loops over the known names instead of growing one more
##  near-identical assertion each time a fifth, sixth sound is added.
func play_count(name: String) -> int:
	return int(_play_counts.get(name, 0))


func _play(name: String, stream: AudioStreamWAV, volume_db: float) -> void:
	_play_counts[name] = int(_play_counts[name]) + 1
	# **Counted above this line, silenced below it.** A net flips this constant off and on to prove the two
	#  halves are actually separate — leave the counter after the guard and "the switch ate it" and "the call
	#  never came" both read as the same zero.
	if not Fx.SFX_ENABLED or stream == null or _players.is_empty():
		return
	# **Round-robin, not "find an idle one".** Scanning for an idle voice is a search on every call; this is
	#  one index and a modulo. The failure mode — cutting the oldest voice's tail one call early — is
	#  inaudible at these clip lengths (under a quarter second), the same trade `blast_fx._add`'s own
	#  "discard the oldest flash" already makes.
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.play()


# ══════════════════════════════════════════════════════════════════
#  Generation — PCM written once, at boot, never touched again
# ══════════════════════════════════════════════════════════════════

## A tone sweeping linearly from `freq_start` to `freq_end`. **A decay envelope, not a sustained note** —
##  nothing in this game holds a pitch, every clip here is a short "pluck" that starts loud and dies fast.
func _make_tone(duration_sec: float, freq_start: float, freq_end: float) -> AudioStreamWAV:
	var n := maxi(1, int(Fx.SFX_SAMPLE_RATE * duration_sec))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var freq := lerpf(freq_start, freq_end, u)
		phase += freq / float(Fx.SFX_SAMPLE_RATE) * TAU
		var env := pow(1.0 - u, 1.6)
		_write_sample(bytes, i, sin(phase) * env)
	return _wrap_wav(bytes)


## White noise with a decaying envelope — an impact, not a pitch. `blast` and `hit` are the only two clips
##  built this way; every tonal sound above is a sine sweep, so the two families never get confused by ear.
func _make_noise(duration_sec: float, decay_pow: float) -> AudioStreamWAV:
	var n := maxi(1, int(Fx.SFX_SAMPLE_RATE * duration_sec))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	# **A fixed seed.** This is presentation (`src/view/`, allowed to differ per client — the door
	#  `blast_fx._advance_shake`'s own comment already opens for `randf()`), but there is no reason for the
	#  *timbre* of a clip generated once at boot to reroll every launch — only which voice plays it and how
	#  loud varies per call, driven by what actually happened that tick, not by the waveform itself.
	rng.seed = 20260810
	for i in n:
		var u := float(i) / float(n)
		var env := pow(1.0 - u, decay_pow)
		_write_sample(bytes, i, rng.randf_range(-1.0, 1.0) * env)
	return _wrap_wav(bytes)


func _write_sample(bytes: PackedByteArray, i: int, s: float) -> void:
	bytes.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))


func _wrap_wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = Fx.SFX_SAMPLE_RATE
	w.stereo = false
	w.data = bytes
	return w
