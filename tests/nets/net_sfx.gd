extends RefCounted
## Net for `src/view/sfx_bank.gd` — the procedural sound bank (the "약하지만 넣어줘" sound pass).
##
## **Whether a sound "rang" is measurable headless; whether it "sounds good" never is** (this feature's own
## brief). This net only ever reads `play_count()` — it never touches `AudioServer`, never asserts on the
## generated PCM, and never cares whether `Fx.SFX_ENABLED` actually lets a voice play. That split is the
## whole reason `_play()` counts *before* the `SFX_ENABLED` guard (`sfx_bank.gd`'s own comment) — this net is
## what the counter's existence is for.
##
## **Driven treed** (`t.root.add_child`), never by hand-setting fields — `SfxBank._ready()` is what builds
## the voice pool, and skipping the tree would test a bank whose pool `stage.gd`'s real one never has.

const SfxBank := preload("res://src/view/sfx_bank.gd")
const Fx := preload("res://src/view/fx_tuning.gd")


func run(t) -> void:
	await _every_trigger_counts_its_own_sound_and_only_its_own(t)
	await _the_master_switch_mutes_playback_but_not_the_count(t)
	await _voices_survive_more_calls_than_there_are_players(t)
	await _headless_counts_without_touching_a_voice(t)


func _every_trigger_counts_its_own_sound_and_only_its_own(t) -> void:
	var bank := SfxBank.new()
	t.root.add_child(bank)
	await t.pump_frames(2)

	t.eq(bank.play_count(SfxBank.NAME_FIRE), 0, "부팅 직후엔 발사음이 한 번도 안 울렸다 (전제)")
	bank.play_fire()
	t.eq(bank.play_count(SfxBank.NAME_FIRE), 1, "발사를 한 번 부르면 발사 카운트만 오른다")
	t.eq(bank.play_count(SfxBank.NAME_BLAST), 0, "발사가 착탄 카운트를 올리지 않는다 (오염 없음)")
	t.eq(bank.play_count(SfxBank.NAME_JUMP), 0, "발사가 점프 카운트를 올리지 않는다 (오염 없음)")

	bank.play_blast()
	bank.play_jump()
	bank.play_land()
	bank.play_hit()
	t.eq(bank.play_count(SfxBank.NAME_BLAST), 1, "착탄이 한 번 울렸다")
	t.eq(bank.play_count(SfxBank.NAME_JUMP), 1, "점프가 한 번 울렸다")
	t.eq(bank.play_count(SfxBank.NAME_LAND), 1, "착지가 한 번 울렸다")
	t.eq(bank.play_count(SfxBank.NAME_HIT), 1, "피격이 한 번 울렸다")

	# **Invert it** — a counter that never moves past 1 (a latch dressed as a counter) would still pass
	#  every check above. Five more calls must read five more.
	for i in 5:
		bank.play_fire()
	t.eq(bank.play_count(SfxBank.NAME_FIRE), 6, "발사를 다섯 번 더 부르면 6이 된다 (누적이지 래치가 아니다)")

	# **`remove_child` + `free()`, not `queue_free()`.** The net quits right after `run()` returns, with no
	#  further frame pumped — a deferred `queue_free()` never actually runs before exit, so every bank (and
	#  its `Fx.SFX_VOICES` `AudioStreamPlayer` children) would show up as leaked at shutdown. Freeing
	#  immediately, the same idiom `net_render.gd` already states for an untreed root, closes that here too.
	t.root.remove_child(bank)
	bank.free()


## **The mutation this net exists to catch**: move the counter increment below `Fx.SFX_ENABLED`'s `return`
## and this goes red, because muted playback would silently start eating the "did it ring" signal the
## counter exists to survive (`sfx_bank._play`'s own comment names this exact ordering).
func _the_master_switch_mutes_playback_but_not_the_count(t) -> void:
	var bank := SfxBank.new()
	t.root.add_child(bank)
	await t.pump_frames(2)
	bank.play_fire()
	t.eq(bank.play_count(SfxBank.NAME_FIRE), 1,
		"Fx.SFX_ENABLED이 지금 값이어도(%s) 카운트는 오른다 — 스위치는 소리만 죽인다" % Fx.SFX_ENABLED)
	# **`remove_child` + `free()`, not `queue_free()`.** The net quits right after `run()` returns, with no
	#  further frame pumped — a deferred `queue_free()` never actually runs before exit, so every bank (and
	#  its `Fx.SFX_VOICES` `AudioStreamPlayer` children) would show up as leaked at shutdown. Freeing
	#  immediately, the same idiom `net_render.gd` already states for an untreed root, closes that here too.
	t.root.remove_child(bank)
	bank.free()


## A chain of blasts can land on one tick (`stage.gd`'s own comment on the door this bank sits behind) —
## more calls than there are voices in the pool must not crash and must not drop a count, the same
## discipline `blast_fx.on_blasts` already holds for flashes.
func _voices_survive_more_calls_than_there_are_players(t) -> void:
	var bank := SfxBank.new()
	t.root.add_child(bank)
	await t.pump_frames(2)
	var n := Fx.SFX_VOICES * 3
	for i in n:
		bank.play_blast()
	t.eq(bank.play_count(SfxBank.NAME_BLAST), n,
		"보이스(%d개)보다 많이 불러도 호출 수(%d)는 전부 세어진다" % [Fx.SFX_VOICES, n])
	# **`remove_child` + `free()`, not `queue_free()`.** The net quits right after `run()` returns, with no
	#  further frame pumped — a deferred `queue_free()` never actually runs before exit, so every bank (and
	#  its `Fx.SFX_VOICES` `AudioStreamPlayer` children) would show up as leaked at shutdown. Freeing
	#  immediately, the same idiom `net_render.gd` already states for an untreed root, closes that here too.
	t.root.remove_child(bank)
	bank.free()


## **The mutation this net was born to catch.** Every net in this repo runs `--headless`, and
## `AudioStreamPlayer.play()` under the dummy driver creates an `AudioStreamPlaybackWAV` that never gets
## released before the process quits — measured directly (`--verbose`): a first cut of this bank leaked 36
## `ObjectDB` instances from three banks' worth of play calls alone, and the same wiring inside `stage.gd`
## dirtied a dozen unrelated integration nets that merely fire or move a character. `_headless` is the fix
## (`sfx_bank._play`'s own header) — this reads the pool directly (`_players`, the same "read the private
## field straight" idiom `net_render.gd` already uses on `Stage`) to prove `.play()` was never reached, not
## only that the counter moved (the counter alone cannot tell "skipped" from "played and already finished").
func _headless_counts_without_touching_a_voice(t) -> void:
	var bank := SfxBank.new()
	t.root.add_child(bank)
	await t.pump_frames(2)
	t.ok(DisplayServer.get_name() == "headless", "이 그물 자체가 헤드리스로 돈다 (전제)")
	for p: AudioStreamPlayer in bank._players:
		t.ok(not p.playing, "부팅 직후 보이스는 재생 중이 아니다 (전제)")
	bank.play_blast()
	bank.play_hit()
	t.eq(bank.play_count(SfxBank.NAME_BLAST), 1, "헤드리스에서도 카운트는 오른다 (전제)")
	for p: AudioStreamPlayer in bank._players:
		t.ok(not p.playing, "헤드리스라 play_blast/play_hit가 실제 보이스를 건드리지 않았다")
	t.root.remove_child(bank)
	bank.free()
