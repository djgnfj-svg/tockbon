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

## 🔇 소리 설정 (음소거) — Audio가 소유·저장·적용한다. SFX·음악·모든 소리가 Master로 모이므로
## Master 버스를 음소거하면 전부 꺼진다 (버스별로 끌 일이 생기면 여기서 갈래를 늘린다).
## 상태는 user://settings.cfg에 남아 껐다 켜도 유지된다. `O` 키로 어느 씬에서든 토글된다.
const _SETTINGS_PATH := "user://settings.cfg"

var _cache: Dictionary = {}          # id(StringName) → AudioStream (지연 로드)
var _missing: Dictionary = {}        # 이미 경고한 id (경고 1회)
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _muted: bool = false             # 저장에서 부팅 때 복원 → 아래 _apply_mute로 버스에 반영


func _ready() -> void:
	for _i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)

	_load_settings()   # 🔇 저장된 음소거 상태를 부팅 때 곧바로 버스에 적용

	# ── EventBus 글로벌 순간 구독 (발신자는 각 모듈, 여긴 수신만) ──
	EventBus.ring_cast_requested.connect(_on_cast)
	EventBus.enemy_hit.connect(_on_enemy_hit)
	EventBus.player_hurt.connect(_on_hurt)
	EventBus.extraction_success.connect(_on_extract)
	EventBus.bag_lost.connect(_on_death)
	EventBus.codex_unlocked.connect(_on_unlock)
	EventBus.ring_design_committed.connect(_on_commit)
	EventBus.equipment_changed.connect(_on_equip)
	EventBus.phase_changed.connect(_on_phase)
	EventBus.quest_completed.connect(_on_quest_complete)


# ── 🔇 소리 설정 (음소거) ────────────────────────────────────────

## 어느 씬에서든 `O` 키로 음소거 토글. Audio는 오토로드라 트리 루트에 살아 전역 입력을 받는다
## → 씬마다 배선하지 않아도 베이스·숲·타이틀 어디서나 먹는다. keycode가 아니라 physical_keycode로
## 봐야 자판 배열과 무관하다 (프로젝트 입력맵과 같은 규약). O(=79)는 입력맵의 어느 액션과도 안 겹친다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.physical_keycode == KEY_O:
			toggle_mute()
			get_viewport().set_input_as_handled()


func is_muted() -> bool:
	return _muted


func toggle_mute() -> void:
	set_muted(not _muted)


## 음소거 설정 — 버스에 적용 + 저장 + UI에 알림. 타이틀 버튼·`O` 키가 부른다.
func set_muted(value: bool) -> void:
	if value == _muted:
		return
	_muted = value
	_apply_mute()
	_save_settings()
	EventBus.audio_muted_changed.emit(_muted)


## Master 버스에 음소거를 반영한다 (SFX·음악이 다 Master로 모이므로 하나면 전부 꺼진다).
func _apply_mute() -> void:
	var idx := AudioServer.get_bus_index(&"Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, _muted)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) == OK:
		_muted = bool(cfg.get_value("audio", "muted", false))
	_apply_mute()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_SETTINGS_PATH)   # 다른 설정 키가 있으면 보존
	cfg.set_value("audio", "muted", _muted)
	cfg.save(_SETTINGS_PATH)


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
	# 룬 속성별 피격음 변주. 약간의 피치 흔들림으로 반복감 완화.
	# ⚠ **룬은 6종인데 전용 음은 셋뿐이다** — BOLT·EARTH·GRASS는 기본음(`hit`)으로 떨어진다
	#   (세83에 룬 6종이 복원되며 생긴 빚. 새 소리 = `assets/audio/sfx/hit_*.wav` 한 장 + 여기 한 줄).
	match rune_type:
		Enums.RuneType.FIRE:  play(&"hit_fire", randf_range(0.95, 1.05))
		Enums.RuneType.WATER: play(&"hit_water", randf_range(0.95, 1.05))
		Enums.RuneType.WIND:  play(&"hit_wind", randf_range(0.95, 1.05))
		_:                    play(&"hit", randf_range(0.95, 1.05))


func _on_hurt(_amount: float, _source_pos: Vector2) -> void:
	# 🔴 세션63: `player_hurt`(damage_player만 발신)로 이관 — 옛 "hp 직전값 비교로 감소 추측"이
	# 필요 없어졌다(회복·출격 만HP는 이 신호를 안 쏜다 — 신호 자체가 오발을 막는다).
	play(&"hurt")


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


func _on_quest_complete(_quest_id: StringName) -> void:
	# 목표 달성 (세션36) — 전용 소리가 없으면 해금음을 재사용한다(둘 다 "새로 열렸다"의 순간).
	play(&"unlock")


func _on_phase(phase: int) -> void:
	# 아침·밤 전환만 (낮·저녁은 조용히 — 너무 잦지 않게).
	match phase:
		Enums.Phase.MORNING: play(&"day")
		Enums.Phase.NIGHT:   play(&"night")
