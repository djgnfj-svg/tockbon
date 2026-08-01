extends SceneTree
## 🔊 오디오 배선 자동 검증 — 헤드리스 실행:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd
## 전 항목 통과 시 "TEST_AUDIO_OK" 출력 후 종료 코드 0.
##
## 검증 대상 = **Audio 오토로드**(src/core/audio.gd)의 계약 세 가지:
##   ① `IDS`의 SFX가 전부 실제 로드된다 (파일명=id, 길이>0). ⚠ **개수를 여기 박지 마라** — 늘 때마다 어긋난다.
##   ② Audio가 EventBus 글로벌 순간 9종에 연결돼 있다.
##   ③ 시그널을 쏘면 **올바른 소리가 실제로 물린다** (id→스트림 리졸버가 산다).
##
## ⚠ **헤드리스엔 오디오 드라이버가 없다** — 소리가 나는지는 여기서 못 잡는다(에디터 실게임 몫).
## 여기서 잡는 건 "play()가 올바른 스트림에 도달하는가" = 배선. AudioStreamPlayer.stream을
## 공개 프로퍼티로 관찰해 검증한다(내부 필드가 아니라 계약).
##
## 🔴 부작용 있는 순간(extraction_success·bag_lost=자동저장, ring_design_committed=GameState가
## design을 읽음)은 **발신하지 않고 연결만** 확인한다 — 세이브를 건드리거나 null로 크래시하지 않게.
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 /root 접근. 지역 변수는 의도적으로 동적 타입, enum은 리터럴 정수로 박는다.

const SFX_DIR := "res://assets/audio/sfx/"
## 🔴 **이 배열은 자동으로 안 는다 — 새 wav를 넣으면 여기 손으로 더해라**(그게 이 그물의 계약이다).
## ⚠ 그리고 **여기만 늘리면 「파일이 있다」까지만 잰다** — `match`에 줄이 빠져도 초록이다.
##   새 소리는 **반드시 ④(`_test_events_reach_correct_sound`)에도 한 줄**을 더해라. 세104에 실제로
##   그 갈림이 지적돼서 BOLT·EARTH·GRASS는 양쪽에 다 넣었다.
## 🔴🔴 **세112: `growl`·`howl`은 「소비자 0」인 고아 자산이다** — 인지(짖음)가 은퇴하며
##   재생하던 유일한 자리(`forest_enemy._play_percept_sfx`)가 사라졌다. 🔴 **파일은 일부러 남겼다**
##   (`room_loop_design` §6-1) — 여기 두 줄과 ⑤가 **`Audio.stream_of` 대출구 계약**을 계속 재는데,
##   그 문(위치 있는 소리를 빌려 가는 길)은 다음에 위치 SFX를 붙일 때 그대로 쓰인다.
##   ⚠ 이 둘은 EventBus로 안 나서 ④에 넣을 자리가 없다 — 그래서 ⑤가 따로 있다.
const IDS := [
	"cast", "hit", "hit_fire", "hit_water", "hit_wind", "hit_bolt", "hit_earth", "hit_grass",
	"hurt", "commit", "pop",
	"extract", "death", "pickup", "unlock", "ui_click", "day", "night", "craft", "equip",
	"growl", "howl",
]
# EventBus 글로벌 순간 — Audio가 이 전부에 붙어 있어야 한다.
const SIGNALS := [
	"ring_cast_requested", "enemy_hit", "player_hurt", "extraction_success",
	"bag_lost", "codex_unlocked", "ring_design_committed", "equipment_changed", "phase_changed",
]
# 룬 타입 리터럴 (Enums.RuneType — FIRE=0·WATER=2·WIND=3·BOLT=4·EARTH=5·GRASS=6).
# ⚠ **값이 연속이 아니다**(1 = 옛 IMPACT 구멍) — range로 훑지 말고 낱개로 박는다.
const R_FIRE := 0
const R_WATER := 2
const R_WIND := 3
const R_BOLT := 4
const R_EARTH := 5
const R_GRASS := 6

var failures: int = 0
var _bus = null
var _audio = null


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		print("TEST_AUDIO_TIMEOUT — 20초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_audio = root.get_node("/root/Audio")

	_test_autoload_present()
	_test_all_sfx_load()
	_test_connected_to_signals()
	_test_events_reach_correct_sound()
	_test_stream_of_public_accessor()

	if failures == 0:
		print("TEST_AUDIO_OK — 전 항목 통과")
	else:
		print("TEST_AUDIO_FAIL — %d건 실패" % failures)
	quit(0 if failures == 0 else 1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		failures += 1


# ── ① 오토로드 존재 ──────────────────────────────────────────
func _test_autoload_present() -> void:
	_check(_audio != null, "Audio 오토로드가 /root/Audio에 있다")


# ── ② 17개 SFX 로드 ──────────────────────────────────────────
func _test_all_sfx_load() -> void:
	for id in IDS:
		var path: String = SFX_DIR + id + ".wav"
		var exists := ResourceLoader.exists(path)
		_check(exists, "SFX 존재: %s.wav" % id)
		if exists:
			var s = load(path)
			var ok: bool = s != null and s is AudioStream and s.get_length() > 0.0
			_check(ok, "SFX 유효(길이>0): %s.wav" % id)


# ── ③ EventBus 연결 ──────────────────────────────────────────
func _test_connected_to_signals() -> void:
	for sig_name in SIGNALS:
		_check(_signal_hits_audio(sig_name), "Audio가 EventBus.%s에 연결됨" % sig_name)


func _signal_hits_audio(sig_name: String) -> bool:
	for conn in _bus.get_signal_connection_list(sig_name):
		var cb: Callable = conn["callable"]
		if cb.get_object() == _audio:
			return true
	return false


# ── ④ 발신 → 올바른 스트림이 물린다 (부작용 없는 순간만) ──────────
func _test_events_reach_correct_sound() -> void:
	# 발사
	_clear()
	_bus.ring_cast_requested.emit({}, Vector2.ZERO, Vector2.RIGHT)
	_check(_played("cast"), "ring_cast_requested → cast")

	# 룬별 피격 변주
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_FIRE)
	_check(_played("hit_fire"), "enemy_hit(불) → hit_fire")
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_WATER)
	_check(_played("hit_water"), "enemy_hit(물) → hit_water")
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_WIND)
	_check(_played("hit_wind"), "enemy_hit(바람) → hit_wind")
	# 세104 `C2` — 룬 6종이 전부 전용 음을 갖는다. 🔴 **이 셋이 「match에 줄이 실제로 있나」의
	# 유일한 검출자다** — IDS(②)는 파일 존재만 재서 배선이 빠져도 초록이다.
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_BOLT)
	_check(_played("hit_bolt"), "enemy_hit(번개) → hit_bolt")
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_EARTH)
	_check(_played("hit_earth"), "enemy_hit(흙) → hit_earth")
	_clear(); _bus.enemy_hit.emit(null, 10.0, R_GRASS)
	_check(_played("hit_grass"), "enemy_hit(풀) → hit_grass")
	# 🔴 폴백이 살아 있나 — 룬이 또 늘 때 「소리가 없다」가 아니라 기본음으로 떨어져야 한다.
	_clear(); _bus.enemy_hit.emit(null, 10.0, 99)  # 알 수 없는 룬 → 기본
	_check(_played("hit"), "enemy_hit(그 외) → hit")

	# 낮/밤 전환 (MORNING=0·NIGHT=3만 소리, 낮·저녁은 조용)
	_clear(); _bus.phase_changed.emit(0)
	_check(_played("day"), "phase MORNING → day")
	_clear(); _bus.phase_changed.emit(3)
	_check(_played("night"), "phase NIGHT → night")
	_clear(); _bus.phase_changed.emit(1)  # DAY = 조용
	_check(not _any_played(), "phase DAY → 조용 (소리 없음)")

	# 아픔음 (세63 이관): `player_hurt`(damage_player만 발신)가 유일 트리거 — 옛 "hp 직전값
	# 비교로 감소 추측"은 은퇴했다. 회복·출격 만HP는 player_hurt 자체가 안 실리므로 오발이 없다.
	_clear(); _bus.player_hurt.emit(10.0, Vector2(INF, INF))
	_check(_played("hurt"), "player_hurt → hurt")
	_clear(); _bus.player_hp_changed.emit(100.0, 100.0)  # hp 변화만(회복 계열) → 조용
	_check(not _any_played(), "hp 변화만 → 조용 (아픔음은 player_hurt만 듣는다)")

	# 해금 (부작용 없음 — id는 임의 프로브 키, 세61에 rune_water .tres 은퇴로 개명)
	_clear(); _bus.codex_unlocked.emit(&"__probe_unlock")
	_check(_played("unlock"), "codex_unlocked → unlock")

	# 장착 (equipment_changed — 자동저장 안 함)
	_clear(); _bus.equipment_changed.emit()
	_check(_played("equip"), "equipment_changed → equip")


# ── ⑤ 위치 있는 소리의 스트림 대출구 (세105 몬스터 인지) ──────────────
## 🔴 **왜 ④가 아니라 별도 갈래인가**: `growl`·`howl`은 EventBus로 안 난다 — 방 반대편 짐승이
## 코앞처럼 들리면 통보가 아니라 잡음이라, **몸이 `AudioStreamPlayer2D`로 직접 재생**하고 스트림만
## `Audio`에서 빌리는 길이었다. ④는 「시그널 → 풀」을 재므로 이 경로를 못 본다.
## ⚠ **세112에 그 재생자가 인지와 함께 죽었다** — 지금 남은 것은 **대출구(`stream_of`) 계약**이고,
##  다음에 위치 있는 소리를 붙이는 쪽이 그대로 쓴다(위 `IDS` 머리말).
##
## 🔴🔴 **가장 중요한 계약은 「캐시가 한 벌인가」다.** `stream_of`가 `_stream`을 안 지나고 제 손으로
## `load()`를 부르도록 「정리」되면 — 없는 id 경고 1회 규약이 죽고 캐시 관리가 두 벌이 된다.
##
## 🔴🔴 **그런데 그건 런타임 값으로 못 잰다 — 세105에 뮤테이션으로 실증했다.**
## `stream_of`를 `return load(path)`로 바꿔 놓고 돌렸더니 **전 항목 그린이었다**(검출 0).
## 이유: **Godot의 `load()` 자체가 리소스 캐시를 지나** 어느 길로 가든 **같은 인스턴스**를 준다.
## ⇒ 「인스턴스가 같다」는 우회해도 참이라 **자명 통과**다. 세86 *"「결과 값이 같다」는
## 「같은 길로 왔다」가 아니다"*가 그대로 재현된 자리다.
## ⚠ **그 검사를 「있으니 됐다」고 남겨 두면 그물이 있다는 착각만 준다** — 그래서 걷어냈다.
##
## 🔴 **실패 형태가 늘 「소스에서 그 호출이 빠진다」라서 소스로 잰다**(선례 = `test_scene_contract_auto`가
## `mouse_filter`를 `.tscn` 프로퍼티로 잡는 것 · `test_ui_text_auto`의 사본 재발 스캔).
func _test_stream_of_public_accessor() -> void:
	_check(_audio.has_method("stream_of"), "Audio.stream_of() 공개 접근자가 있다")
	if not _audio.has_method("stream_of"):
		return

	for id in ["growl", "howl"]:
		var s = _audio.stream_of(StringName(id))
		var ok: bool = s != null and s is AudioStream and s.get_length() > 0.0
		_check(ok, "stream_of(%s) → 유효한 스트림" % id)

	# 없는 id는 null이어야 한다 — 부르는 쪽이 null을 확인하도록 계약이 잡혀 있다
	# (소리가 아직 없다고 게임이 멎으면 안 된다는 audio.gd의 규율).
	_check(_audio.stream_of(&"__no_such_sfx__") == null, "stream_of(없는 id) → null")

	# 🔴 캐시 단일 소스 — 소스 스캔 (위 머리말 참조: 런타임 값으로는 검출력이 0이다)
	var src := ""
	var f := FileAccess.open("res://src/core/audio.gd", FileAccess.READ)
	if f != null:
		src = f.get_as_text()
		f.close()
	_check(src != "", "audio.gd 소스를 읽었다 (빈 문자열이면 아래가 전부 자명 통과)")
	if src == "":
		return

	# `func stream_of` 본문만 잘라낸다 — 다음 `func ` 선언 전까지.
	var start := src.find("func stream_of(")
	_check(start >= 0, "소스에 func stream_of( 선언이 있다")
	if start < 0:
		return
	var rest := src.substr(start + 15)
	var stop := rest.find("\nfunc ")
	var body := rest if stop < 0 else rest.substr(0, stop)

	_check(body.contains("_stream("),
		"stream_of 본문이 _stream()을 부른다 (캐시·경고1회 단일 소스)")
	# 🔴 짝 검사 — 우회 형태를 직접 금지한다. 위 검사만 있으면 `_stream()`을 부르면서
	#   `load()`도 같이 부르는 「반만 고친」 형태가 통과한다.
	_check(not body.contains("load("),
		"stream_of 본문이 load()를 직접 부르지 않는다 (캐시가 두 벌이 되는 형태)")


# ── AudioStreamPlayer 풀 관찰 헬퍼 (공개 프로퍼티만) ──────────────
func _pool() -> Array:
	var a := []
	for c in _audio.get_children():
		if c is AudioStreamPlayer:
			a.append(c)
	return a


func _clear() -> void:
	for p in _pool():
		p.stream = null


func _played(id: String) -> bool:
	var want: String = SFX_DIR + id + ".wav"
	for p in _pool():
		if p.stream != null and p.stream.resource_path == want:
			return true
	return false


func _any_played() -> bool:
	for p in _pool():
		if p.stream != null:
			return true
	return false
