extends SceneTree
## 🔴 적 히트박스 = 「보이는 몸에 쏘면 맞는다」 자동 검증 (세99 · 잡몹 64px 재작의 짝) — 헤드리스:
##   ./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_hitbox_auto.gd
## 전 항목 통과 시 "TEST_ENEMY_HITBOX_OK" 출력 후 종료 코드 0.
##
## 왜 생겼나: 잡몹 5종이 32px → 64px 프레임으로 다시 그려졌는데 `forest_enemy.tscn`의 히트박스는
## **반경 9.0 고정**이라, 몸통 대비 비율이 0.56 → **0.16**이 됐다. 보이는 몸에 쏴도 탄이 그냥 지나가는데
## **에러가 0이고 전 스위트가 그린**이었다 — 「몸」과 「판정」을 같이 재는 그물이 **한 개도 없었다**.
##
## 🔴🔴 **여기서 재는 계약은 하나다: 그림의 몸통 안쪽으로 쏘면 맞고, 몸 밖으로 쏘면 안 맞는다.**
##  ⓐ만 재면 「반경 = 9999」가 통과하고, ⓑ만 재면 「반경 = 0」이 통과한다 — 둘 다 있어야 그물이다
##  (`test_enemy_ai_auto [4]`의 leash ⓐ/ⓑ와 같은 이유).
##
## 🔴 **진짜 탄으로 쏜다** — `src/spell/projectile.tscn`을 속도 0으로 세워 놓고 겹치게 한다.
##  점 질의(`intersect_point`)로 형상만 재면 레이어·마스크·`take_hit` 계약이 빠져 **「형상은 큰데
##  안 맞는다」**를 놓친다. 여기선 `EventBus.enemy_hit`이 실제로 울렸는지로 판정한다.
##
## 🔴 **몸통 크기는 PNG를 직접 읽어 잰다**(`Image.load_from_file`) — 종마다 숫자를 여기 베끼면
##  아트가 다시 그려질 때 그물이 **거짓 빨강/거짓 그린**이 된다. "반경 22"가 아니라 **"그림의 70%
##  지점에 맞는다"**가 계약이다. ⚠ `load()`(임포트 캐시)가 아니라 **디스크**를 읽는 이유는 [6] 참조.
##
## ⚠ **못 잡는 것**: 화면에서 「커 보이나」·「때리는 맛이 나나」. 반경은 손맛 값이라 F5가 정한다 —
##  여기서 재는 건 **몸과 판정이 갈라지지 않았다**는 사실뿐이다(대역으로 잰다, 정확값을 안 박는다).
##
## 주의: -s 모드는 오토로드 전역 등록보다 먼저 컴파일된다 — 오토로드 식별자·모듈 preload 금지.
## 첫 프레임 후 load()·/root 접근. 지역 변수는 의도적으로 동적 타입.

## 🔴 히트박스를 반드시 .tres로 쥐어야 하는 적 — **명시 열거**다(개수 검사로 바꾸면 장치가 죽는다,
## `test_save_auto`의 시드 집합 선례). 64px 시트로 다시 그려진 잡몹 + 그 시트를 함께 쓰는 네임드.
## ⚠ `gale`·`snake_boss`·`slime_elite`는 **일부러 빠져 있다** — 세99 범위 밖(보고서 참조).
## 🔴🔴 **세99 몹 정리: 8 → 2.** `slime`·`mist`·`beetle`·`vine`(+ 네임드 둘)이 임의로 만든
##  플레이스홀더라 지워졌다(`data/enemies/README.md`). **재는 계약은 한 톨도 안 줄었다** —
##  새 잡몹이 오면 여기 한 줄을 더해라(그게 이 열거의 목적이다: 「64px인데 판정이 9px」로 안 돌아가게).
const REQUIRE_KEY := [
	&"hound", &"hound_alpha",
]

## 몸통 반폭의 이 비율 지점 = **「몸 안쪽」** — 여기 쏘면 맞아야 한다.
## 🔴 값의 근거: 지금 반경들은 지름/몸통폭이 0.66~0.80이라 0.70이면 전 종이 **3px 이상 여유로** 든다.
##  씬 기본값 9.0으로 되돌리면(뮤테이션) 전 종이 **3.5px 이상 밖으로** 나가 빨개진다.
const PROBE_INNER_FRAC := 0.70
## 몸통 반폭의 이 비율 지점 = **「몸 밖」** — 여기 쏘면 안 맞아야 한다(반경 과대 방지).
const PROBE_OUTER_FRAC := 1.25
## 히트박스 **지름 ÷ 몸통 폭**의 허용 대역. 하한 = "몸의 절반은 덮는다"(9.0이면 0.29~0.33이라 빨강),
## 상한 = "몸 밖으로 크게 삐져나오지 않는다". ⚠ 손맛 조임의 여유를 남긴 **대역**이지 정답이 아니다.
const RATIO_MIN := 0.55
const RATIO_MAX := 1.05

var failures: int = 0
var _bus = null
var _db = null
var _enemy_scene = null
var _bolt_scene = null
## 디스크 PNG에서 잰 프레임0 몸통 — {id: {"w": float, "cx": float, "side": int}}
var _body := {}


func _init() -> void:
	_run()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("TEST_ENEMY_HITBOX_TIMEOUT — 90초 초과")
		quit(1))
	await process_frame  # 오토로드 준비 대기

	_bus = root.get_node("/root/EventBus")
	_db = root.get_node("/root/Db")
	_enemy_scene = load("res://src/field/forest_enemy.tscn") as PackedScene
	_bolt_scene = load("res://src/spell/projectile.tscn") as PackedScene

	# 탄·픽업이 `get_tree().current_scene`을 찾는다 — 헤드리스엔 메인 씬이 없어 null이다.
	var container := Node2D.new()
	root.add_child(container)
	current_scene = container

	await _test_key_present()
	await _test_shot_reaches_body()
	await _test_radius_vs_body_ratio()
	await _test_shape_not_shared()
	await _test_named_inherits_by_size()
	await _test_import_is_fresh()

	if failures == 0:
		print("TEST_ENEMY_HITBOX_OK — 전 항목 통과")
		quit(0)
	else:
		print("TEST_ENEMY_HITBOX_FAIL — %d개 실패" % failures)
		quit(1)


## [1] 🔴 **키가 실제로 데이터에 있고 화면(형상)까지 닿는다** — 「.tres에 적었다」로 끝내면
## 코드가 안 읽어도 통과하는 죽은 손잡이가 된다(감사 T3). 그래서 **공개 리더**로 되읽는다.
## ⚠ 값 자체는 안 박는다 — .tres가 유일한 정본이라 여기 베끼면 조일 때 갈라진다.
func _test_key_present() -> void:
	print("[1] hitbox_radius — %d종이 .tres로 쥐고, 그 값이 형상까지 닿는다" % REQUIRE_KEY.size())
	for id: StringName in REQUIRE_KEY:
		var def = _db.get_enemy(id)
		if def == null:
			_check(false, "%s: EnemyDef가 로드된다" % id)
			continue
		var want: float = float(def.params.get("hitbox_radius", 0.0))
		_check(want > 0.0, "%s: .tres가 hitbox_radius를 쥔다 (실제 %.1f)" % [id, want])
		if want <= 0.0:
			continue
		var size: float = float(def.params.get("size", 1.0))
		var e = await _spawn(id)
		# 🔴 최종(화면) 반경 = 로컬 반경 × params.size — `Collision`이 루트 scale의 자식이라서다.
		_check(is_equal_approx(e.hitbox_radius(), want * size),
			"🔴 %s: 형상 반경이 .tres 값 × size 그대로다 (데이터 %.1f×%.2f=%.2f / 형상 %.2f)"
				% [id, want, size, want * size, e.hitbox_radius()])
		e.free()


## [2] 🔴🔴 **이 파일의 심장** — 진짜 탄을 몸 안쪽(ⓐ)·몸 밖(ⓑ)에 세워 판정이 서는지 본다.
## ⓐ = 「쏴도 통과한다」의 직접 검출자 · ⓑ = 「반경만 키워 봉합」의 검출자.
## 🔴 기준은 **PNG에서 잰 몸통 반폭**이라 아트가 바뀌면 기준도 같이 움직인다(숫자를 안 베낀다).
func _test_shot_reaches_body() -> void:
	print("[2] 🔴 보이는 몸에 쏘면 맞는다 — 몸 안쪽은 맞고 몸 밖은 안 맞는다")
	for id: StringName in REQUIRE_KEY:
		var m := _measure(id)
		if m.is_empty():
			_check(false, "%s: 스프라이트 PNG를 디스크에서 읽었다" % id)
			continue
		var e = await _spawn(id)
		var half: float = m["w"] * 0.5 * e.scale.x     # 화면 반폭 (params.size 반영)
		var cx: float = m["cx"] * e.scale.x            # 그림 중심이 노드 원점에서 벗어난 만큼
		var inner: float = cx + half * PROBE_INNER_FRAC
		var outer: float = cx + half * PROBE_OUTER_FRAC

		var hit_in := await _shoot_at(e, Vector2(inner, 0.0))
		_check(hit_in,
			"🔴 %s: 몸통 %.0f%% 지점(중심에서 %.1fpx)에 쏘면 맞는다 [히트박스 %.1f]"
				% [id, PROBE_INNER_FRAC * 100.0, inner, e.hitbox_radius()])

		var hit_out := await _shoot_at(e, Vector2(outer, 0.0))
		_check(not hit_out,
			"🔴 %s: 몸통 밖(중심에서 %.1fpx · 반폭 %.1f)에선 안 맞는다 = 반경 과대가 아니다"
				% [id, outer, half])
		e.free()


## [3] 🔴 히트박스 지름이 그림 몸통 폭의 대역 안이다 — [2]의 **선언형 짝**이다.
## [2]가 "그 지점에서 되나"라면 여기는 "몸과 판정의 비율이 사람이 보기에 맞나"를 한 줄로 못 박는다.
## 씬 기본값 9.0으로 되돌리면 전 종이 0.29~0.33이라 하한에서 빨개진다.
func _test_radius_vs_body_ratio() -> void:
	print("[3] 히트박스 지름 ÷ 몸통 폭이 대역(%.2f~%.2f) 안이다" % [RATIO_MIN, RATIO_MAX])
	for id: StringName in REQUIRE_KEY:
		var m := _measure(id)
		if m.is_empty():
			continue
		var e = await _spawn(id)
		# 반경·폭에 똑같이 size가 곱해지므로 비율은 size와 무관하다 — 네임드도 바탕 종과 같은 값이 나온다.
		var ratio: float = (e.hitbox_radius() * 2.0) / (m["w"] * e.scale.x)
		_check(ratio >= RATIO_MIN and ratio <= RATIO_MAX,
			"🔴 %s: 지름/몸통폭 = %.2f (몸통 %.0fpx · 지름 %.1fpx)"
				% [id, ratio, m["w"] * e.scale.x, e.hitbox_radius() * 2.0])
		e.free()


## [4] 🔴🔴 **형상 리소스 공유 함정** — `.tscn`의 SubResource는 씬 인스턴스끼리 **공유**된다.
## `_apply_hitbox`가 `duplicate()` 없이 radius에 대입하면 **마지막에 스폰된 적의 반경이 전원에게 번진다**
## (슬라임 옆의 안개가 슬라임 히트박스를 쓴다 — 에러 0). `ring_carrier._apply_body_radius`가
## *"형상 리소스는 씬들이 공유하는 물건이라 건드리면 안 된다"*고 적어 둔 바로 그 자리다.
##
## 🔴 재는 법이 핵심이다: **먼저 선 적의 반경을 기억해 두고, 다른 종을 세운 뒤 다시 읽는다.**
##  "둘의 반경이 다르다"만 재면 순서에 따라 우연히 통과할 수 있다.
## ✅ 덤으로 **씬 원본이 안 더럽혀졌다**도 잰다 — 트리에 안 넣은 인스턴스는 `_ready`가 안 돌아
##  씬 파일의 기본 반경을 그대로 들고 있어야 한다(그 값이 `slime_elite`·보스의 하위호환 경로다).
##
## 🔴🔴 **세99 몹 정리 — 뒤에 세우는 몸을 `Db`에 주입한다**(세61 수법). 옛 판은 `slime`(22)과
##  `beetle`(23)이었는데 그 둘이 지워졌고, 남은 `hound`·`hound_alpha`는 **로컬 반경이 둘 다 20**이라
##  이 그물의 검출력이 **0이 된다**: 공유 버그가 있어도 뒤 몸이 같은 20을 쓰면 앞 몸의 값이 안 변한다.
##  🔴 **다른 로컬 반경을 쥔 몸이 있어야 이 함정이 관측된다** — 그래서 13.0짜리를 주입한다
##  (공유면 `a`가 20 → 13으로 끌려가 빨개진다. 실제로 그 뮤테이션으로 확인했다).
const SHARE_PROBE := &"hitbox_probe_small"
const SHARE_PROBE_RADIUS := 13.0

func _test_shape_not_shared() -> void:
	print("[4] 🔴 형상 공유 함정 — 다른 종을 세워도 앞선 적의 반경이 안 번진다")
	var a = await _spawn(&"hound")
	var before: float = a.hitbox_radius()
	_inject_probe()
	var b = await _spawn(SHARE_PROBE)
	_check(not is_equal_approx(before, b.hitbox_radius()),
		"두 종의 반경이 애초에 다르다 = 이 그물이 자명통과가 아니다 (%.1f vs %.1f)"
			% [before, b.hitbox_radius()])
	_check(is_equal_approx(a.hitbox_radius(), before),
		"🔴 뒤에 다른 종이 서도 앞선 적의 반경이 그대로다 (%.1f → %.1f — 다르면 SubResource를 공유하고 있다)"
			% [before, a.hitbox_radius()])
	a.free()
	b.free()

	# 씬 원본 — 트리에 안 넣으면 `_ready`가 안 돌아 .tscn의 기본 반경 그대로여야 한다.
	var raw = _enemy_scene.instantiate()
	var shape = (raw.get_node(^"Collision") as CollisionShape2D).shape
	var raw_r: float = (shape as CircleShape2D).radius if shape is CircleShape2D else -1.0
	_check(raw_r > 0.0 and not is_equal_approx(raw_r, before),
		"🔴 씬 원본 형상이 안 더럽혀졌다 (씬 %.1f · 늑대 %.1f — 같으면 원본 리소스에 직접 썼다)"
			% [raw_r, before])
	raw.free()
	_db.enemies.erase(SHARE_PROBE)   # 🔴 주입 제거 — 남기면 뒤 항목의 적 수가 는다


## [5] 🔴 **네임드는 바탕 종의 반경을 그대로 물려받고 `size`가 곱한다** — 이게 `hitbox_radius`의
## 의미 계약이다(로컬 px이지 화면 px이 아니다). 이 형태라 **덩치를 조이면 히트박스가 저절로 따라온다**.
## 화면 px으로 해석하면 `size`를 만질 때마다 두 숫자를 같이 고쳐야 하고, 한쪽을 잊으면 조용히 갈라진다.
## ⚠ 배율은 .tres의 `size`에서 읽는다 — 1.35 같은 값을 여기 박으면 덩치를 조일 때 거짓 빨강이 된다.
## ⚠ 세99 몹 정리로 짝이 셋 → **하나**가 됐다(`mist/mist_elder`·`beetle/beetle_ancient` 삭제).
##  🔴 계약은 그대로다 — 새 네임드가 오면 여기 짝 한 줄을 더해라.
func _test_named_inherits_by_size() -> void:
	print("[5] 네임드 반경 = 바탕 종 × params.size (물려받는다)")
	for pair in [[&"hound", &"hound_alpha"]]:
		var base_def = _db.get_enemy(pair[0])
		var named_def = _db.get_enemy(pair[1])
		if base_def == null or named_def == null:
			_check(false, "%s/%s: EnemyDef가 둘 다 로드된다" % [pair[0], pair[1]])
			continue
		_check(is_equal_approx(float(base_def.params.get("hitbox_radius", -1.0)),
				float(named_def.params.get("hitbox_radius", -2.0))),
			"%s → %s: 바탕 종과 **같은 로컬 반경**을 쓴다 (바탕 %.1f / 네임드 %.1f)"
				% [pair[0], pair[1], float(base_def.params.get("hitbox_radius", -1.0)),
					float(named_def.params.get("hitbox_radius", -2.0))])
		var base_e = await _spawn(pair[0])
		var named_e = await _spawn(pair[1])
		var mult: float = float(named_def.params.get("size", 1.0)) / float(base_def.params.get("size", 1.0))
		_check(mult > 1.0,
			"🔴 %s가 바탕보다 크다 = 덩치로 구별된다 (×%.2f)" % [pair[1], mult])
		_check(is_equal_approx(named_e.hitbox_radius(), base_e.hitbox_radius() * mult),
			"🔴 %s의 화면 반경이 바탕 × size다 (%.2f × %.2f = %.2f / 실제 %.2f)"
				% [pair[1], base_e.hitbox_radius(), mult, base_e.hitbox_radius() * mult,
					named_e.hitbox_radius()])
		base_e.free()
		named_e.free()


## [6] 🔴🔴 **임포트 캐시가 최신인가** — 이 그물이 「그린인데 게임이 깨졌다」가 되는 유일한 구멍이다.
##
## [2]·[3]은 **디스크 PNG**를 기준으로 잰다(아트가 정본이라서). 그런데 게임이 실제로 그리는 건
## `.godot/imported/*.ctex`이고, **`--import`를 안 돌리면 옛 32px 시트가 그대로 화면에 남는다**
## (실측: 새 PNG가 256×64인데 런타임 `load()`는 128×32를 돌려줬다). 그러면 히트박스만 두 배가 된
## 채로 몸은 작아서, 이 파일 전체가 그린인데 **몸 밖을 때린다.**
## 🔴 그래서 **런타임 프레임 한 변 == 디스크 프레임 한 변**을 여기서 못 박는다.
## ⚠ 빨개지면 코드 버그가 아니다 — **리드가 `--headless --import`를 돌리면 된다**(리드 전용 단계).
func _test_import_is_fresh() -> void:
	print("[6] 🔴 임포트 신선도 — 런타임 시트가 디스크 PNG와 같은 크기다")
	for id: StringName in REQUIRE_KEY:
		var m := _measure(id)
		if m.is_empty():
			continue
		var e = await _spawn(id)
		var vis := e.get_node_or_null(^"Visual") as AnimatedSprite2D
		var frames: SpriteFrames = vis.sprite_frames if vis != null else null
		if frames == null or not frames.has_animation(&"idle") \
				or frames.get_frame_count(&"idle") <= 0:
			_check(false, "%s: idle 애니가 구워졌다" % id)
			e.free()
			continue
		var tex := frames.get_frame_texture(&"idle", 0)
		var got: int = tex.get_height() if tex != null else -1
		_check(got == int(m["side"]),
			"🔴 %s: 런타임 프레임 %dpx == 디스크 %dpx (다르면 임포트 캐시가 낡았다 → 리드가 `--headless --import`)"
				% [id, got, int(m["side"])])
		e.free()


# ── 헬퍼 ──

## 🔴 [4] 전용 몸 — **로컬 반경만 다르면 된다**(그림·행동은 안 잰다). 시트는 살아 있는 PNG를 빌린다.
## ⚠ `Db.enemies`는 공유 레지스트리라 [4] 끝에서 반드시 erase한다(`test_feel_auto [4]` 선례).
func _inject_probe() -> void:
	var def = (load("res://src/core/schemas/enemy_def.gd") as GDScript).new()
	def.id = SHARE_PROBE
	def.hp = 30.0
	def.has_counter = false
	def.params = {
		"sprite": "res://assets/sprites/enemies/hound.png",
		"hitbox_radius": SHARE_PROBE_RADIUS,
	}
	_db.enemies[SHARE_PROBE] = def


## 🔴 몸통 실측 — 디스크 PNG의 **프레임0**에서 불투명 픽셀의 가로 범위를 잰다.
## `load()`(임포트 캐시)가 아니라 `Image.load_from_file`(디스크)인 이유는 [6] 머리말 참조 —
## 캐시가 낡아도 **기준은 아트**여야 하고, 낡았다는 사실 자체는 [6]이 따로 잡는다.
## 반환: {"w": 몸통 폭(px), "cx": 프레임 중심에서 몸통 중심까지(px), "side": 프레임 한 변}
## ⚠ 세로가 아니라 **가로**로 잰다 — 그림은 바닥에 붙어 있어 세로 중심이 노드 원점과 어긋나지만,
##  가로는 거의 중심이라 원점 기준 좌표로 바로 옮길 수 있다(그 나머지 어긋남이 "cx"다).
func _measure(id: StringName) -> Dictionary:
	if _body.has(id):
		return _body[id]
	var def = _db.get_enemy(id)
	if def == null:
		return {}
	var path := str(def.params.get("sprite", ""))
	if path == "":
		return {}
	var img := Image.load_from_file(path)
	if img == null:
		return {}
	if img.is_compressed():
		img.decompress()
	var side := img.get_height()
	var lo := side
	var hi := -1
	for x in side:
		for y in side:
			if img.get_pixel(x, y).a > 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
				break
	if hi < lo:
		return {}
	var out := {
		"w": float(hi - lo + 1),
		"cx": (float(lo + hi) * 0.5) - (float(side) * 0.5 - 0.5),
		"side": side,
	}
	_body[id] = out
	return out


## 🔴 **진짜 탄으로 쏜다** — 속도 0으로 그 자리에 세워 겹치게 한다(움직이는 탄은 프레임 스텝에
## 따라 통과 지점이 흔들려 그물이 불안정해진다). 적 좌표 기준 오프셋에 놓고 `enemy_hit`을 기다린다.
## 반환 = 그 적이 맞았나. 🔴 발신자(who)를 대조해 옆 적의 피격을 내 것으로 세지 않는다.
## ⚠ 피해 1.0 — 0 이하면 적 계약의 **0-피해 가드**에 걸려 `enemy_hit`이 아예 안 나간다(자명 실패).
func _shoot_at(enemy, offset: Vector2) -> bool:
	var box := [false]
	var cb := func(who, _dmg, _r) -> void:
		if who == enemy:
			box[0] = true
	_bus.enemy_hit.connect(cb)
	var bolt = _bolt_scene.instantiate()
	current_scene.add_child(bolt)
	bolt.global_position = enemy.global_position + offset
	bolt.setup(1.0, 0, 0, 0.0, 0.0, 0.0)   # 속도 0 = 제자리 · 룬 FIRE · 상태 없음
	await physics_frame
	await physics_frame
	_bus.enemy_hit.disconnect(cb)
	# 맞은 탄은 스스로 queue_free한다 — 그건 그대로 두고, 빗나가 남은 탄만 걷는다
	# (이미 예약된 노드를 free하면 물리 콜백 중 이중 해제가 된다).
	if is_instance_valid(bolt) and not bolt.is_queued_for_deletion():
		bolt.free()
	return box[0]


## 적 하나를 원점에 스폰한다 — enemy_id는 **_ready 전에** 세워야 _def가 그 적으로 잡힌다.
func _spawn(id):
	var e = _enemy_scene.instantiate()
	e.enemy_id = id
	current_scene.add_child(e)
	e.global_position = Vector2.ZERO
	await process_frame
	await physics_frame
	return e


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
