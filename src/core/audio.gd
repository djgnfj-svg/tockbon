extends Node
## 🔊 SFX 재생 허브 — 유일한 오디오 재생 경로 (core 오토로드. GameState처럼 모듈이 직접 부른다).
##
## 두 갈래로 소리가 난다:
##   ① EventBus 글로벌 순간(발사·피격·귀환·사망·해금·맺힘·낮밤)을 여기서 구독 → 자동 재생.
##   ② 국소 순간(펑·획득·제작·장착·UI 클릭)은 모듈이 `Audio.play(&"id")`로 직접 부른다.
##
## 🔴 **새 소리 = `assets/audio/sfx/<id>.wav` 한 장.** 파일명이 곧 id다 — 레지스트리를 안 늘려도
##    `Audio.play(&"<id>")`면 지연 로드된다. 없는 id는 **한 번만** 경고하고 조용히 넘어간다
##    (소리가 아직 없다고 게임이 멎으면 안 된다).
##
## ⚠ **헤드리스(-s·--headless)엔 오디오 드라이버가 없다** — play()는 에러 없이 무음이다.
##    소리 자체는 **에디터 실제 게임에서만** 검증된다(세션 26 "헤드리스는 클릭도 못 본다"의 오디오판).

const _DIR := "res://assets/audio/sfx/"
const POOL := 8  ## 동시 재생 슬롯 — 겹치는 소리가 서로를 자르지 않게.

var _cache: Dictionary = {}          # id(StringName) → AudioStream (지연 로드)
var _missing: Dictionary = {}        # 이미 경고한 id (경고 1회)
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_hp: float = -1.0           # player_hp_changed에서 "줄었을 때만" 아픔음


func _ready() -> void:
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

	# ── EventBus 글로벌 순간 구독 (발신자는 각 모듈, 여긴 수신만) ──
	EventBus.ring_cast_requested.connect(_on_cast)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.player_hp_changed.connect(_on_hp)
	EventBus.extraction_success.connect(_on_extract)
	EventBus.bag_lost.connect(_on_death)
	EventBus.codex_unlocked.connect(_on_unlock)
	EventBus.ring_design_committed.connect(_on_commit)
	EventBus.equipment_changed.connect(_on_equip)
	EventBus.phase_changed.connect(_on_phase)


## 국소 순간 재생 API — 모듈이 직접 부른다. id = 파일명(확장자 없이).
func play(id: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _stream(id: StringName) -> AudioStream:
	if _cache.has(id):
		return _cache[id]
	var path := _DIR + String(id) + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(id):
			_missing[id] = true
			push_warning("[Audio] 소리 없음: %s (assets/audio/sfx/%s.wav)" % [id, id])
		return null
	var s: AudioStream = load(path)
	_cache[id] = s
	return s


# ── EventBus 핸들러 ──────────────────────────────────────────────

func _on_cast(_assembly: Dictionary, _origin: Vector2, _aim: Vector2) -> void:
	play(&"cast")


func _on_enemy_hit(_enemy: Node2D, _damage: float, rune_type: int) -> void:
	# 룬 속성별 피격음 변주 (FIRE=0·WATER=2·WIND=3, 없으면 기본). 약간의 피치 흔들림으로 반복감 완화.
	match rune_type:
		Enums.RuneType.FIRE:  play(&"hit_fire", randf_range(0.95, 1.05))
		Enums.RuneType.WATER: play(&"hit_water", randf_range(0.95, 1.05))
		Enums.RuneType.WIND:  play(&"hit_wind", randf_range(0.95, 1.05))
		_:                    play(&"hit", randf_range(0.95, 1.05))


func _on_hp(hp: float, _hp_max: float) -> void:
	# 줄었을 때만 아픔음 — 출격 만HP·회복은 조용히. 첫 프레임(_last_hp<0)은 기준값만 잡는다.
	if _last_hp >= 0.0 and hp < _last_hp:
		play(&"hurt")
	_last_hp = hp


func _on_extract() -> void:
	play(&"extract")


func _on_death() -> void:
	play(&"death")


func _on_unlock(_id: StringName) -> void:
	play(&"unlock")


func _on_commit(_design) -> void:
	play(&"commit")


func _on_equip() -> void:
	# 장착·해제 (공방에서 펜 등을 낄 때). 부팅 로드 시엔 Audio가 아직 연결 전이라 조용하다.
	play(&"equip")


func _on_phase(phase: int) -> void:
	# 아침·밤 전환만 (낮·저녁은 조용히 — 너무 잦지 않게).
	match phase:
		Enums.Phase.MORNING: play(&"day")
		Enums.Phase.NIGHT:   play(&"night")
