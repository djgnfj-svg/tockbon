extends Node2D
## 원소 반응·시전·착탄 VFX 스포너 — juice의 형제 공용 노드. 전부 Node2D 절차 연출이다(파티클 안 씀).
## Player가 공용 배우라 마을(연습장)·보스방 양쪽에 자동으로 산다.
##
## 🔴 EventBus만 본다(타 모듈 직접 참조 금지). 발밑 마법진의 렌더·애니는 `floor_circle.gd`가 지고,
## 여기서는 **무엇을 그릴지**(점열·색·크기·시간)만 정해 넘긴다.
## 🔴 각 핸들러는 연출 노드를 **`get_tree().current_scene`에 add_child**한다 — Player 트랜스폼에
## 안 묶여야 그 자리에 남는다.
##
## 🔴🔴 **상태 색은 `SR.draw_color_of`다 — `tint_of`를 여기서 칠하지 마라.** 그건 `modulate`에
##   곱하는 배수라 1.0을 넘고, `Line2D.default_color`로 칠하면 렌더가 클램프해 **감전 노랑이 회색으로
##   나간다.** 그물이 이 파일을 **문자열로 스캔**하니 주석에 옛 안내를 남겨도 빨개진다.
##
## 🔴 수치는 밸런스가 아니라 연출값(손맛)이라 const다.

const SR := preload("res://src/core/status_rules.gd")
## 🔴 **모듈 간 preload의 명시 예외 — 기하 단일 소스.** 좌표를 베끼면 조립 판·책과 갈라져
## 「맺을 때 본 그림 ≠ 쓸 때 나오는 그림」이 되는데, 그게 이 연출이 존재하는 이유를 정면으로 깬다.
const RingBoard := preload("res://src/drawing/ring_board.gd")
## 🔴 **점수를 그대로 lerp에 넣지 마라** — 실사용 하한이 0.70(맨 진)이라 하위 70%가 통째로 죽는다.
## `quality_t`가 그 정규화의 단일 소스다.
const RingPower := preload("res://src/core/ring_power.gd")
const FloorCircle := preload("res://src/actors/floor_circle.gd")

# ── 팽창 링 (버스트 면적 — 반경을 truthful하게 폭로한다) ──────────────────────────
const RING_SEGMENTS := 24        ## 링 원 분할 수
const RING_WIDTH := 3.0          ## 링 선 굵기(px)
const RING_START_SCALE := 0.35   ## 시작 배율(작게 시작해 반경까지 팽창)
const RING_TIME := 0.28          ## 팽창·페이드 시간(s)
const RING_START_ALPHA := 0.9    ## 링 시작 알파

# ── 감전 중심 스파크 (SHOCK 전용) ────────────────────────────────────────────────
const SPARK_COUNT := 6           ## 중심에서 방사되는 짧은 번쩍 개수
const SPARK_LEN_MIN := 8.0       ## 스파크 길이 최소(px)
const SPARK_LEN_MAX := 16.0      ## 스파크 길이 최대(px)
const SPARK_WIDTH := 2.0         ## 스파크 굵기(px)
## 🔴 심지는 **흰색 소량 혼합**이지 색 곱이 아니다 — 상태색이 이미 1.0을 넘는 배수라 곱하면
##   전 상태가 흰색으로 뭉갠다.
const SPARK_LIGHTEN := 0.30      ## 스파크 심지 흰색 혼합률(0=제 색 그대로)
const SPARK_TIME := 0.14         ## 스파크 수명(s)
const SPARK_END_SCALE := 1.5     ## 스파크가 바깥으로 튀는 최종 배율

# ── 지그재그 번개 아크 (감전 연쇄 · 바람 확산 공용) ────────────────────────────────
const ARC_SEGMENTS := 6          ## 지그재그 세그먼트 수(중점 개수 = SEG-1)
const ARC_JITTER := 10.0         ## 중점 수직 변위 최대(px)
const ARC_WIDTH := 2.5           ## 아크 선 굵기(px)
const ARC_LIGHTEN := 0.25        ## 아크 심지 흰색 혼합률 (SPARK_LIGHTEN과 같은 이유 — 세97)
const ARC_TIME := 0.15           ## 아크 수명(s)

## 🔴 죽음 마나 폭발(`mana_burst.BURST_Z` = 50) 위 — 그물이 그 값을 이 인용과 함께 잰다.
const VFX_Z := 55

# ── 머즐 플래시 ─────────────────────────────────────────────────────────────────
const MUZZLE_RADIUS := 12.0       ## 총구의 작은 진 링 반지름(px)
const MUZZLE_TIME := 0.10         ## 확대+페이드 시간(s)
const MUZZLE_TICKS := 3           ## 조준 방향 부채 틱 개수
const MUZZLE_TICK_LEN := 9.0      ## 틱 길이(px)
const MUZZLE_TICK_DIST := 10.0    ## 총구에서 틱 시작까지 거리(px)
const MUZZLE_TICK_SPREAD := 0.55  ## 부채 전체 각(rad)
const MUZZLE_TICK_WIDTH := 2.0    ## 틱 굵기(px)
const MUZZLE_END_SCALE := 1.4     ## 틱이 바깥으로 튀는 최종 배율

# ── 착탄 두 겹 (바닥 데칼 + 솟는 플레어) — `spell_impact` 수신 ────────────────────
## 오블리크 표현: ① 세로로 눌린 팽창 링(지면 파장) + ② 위로 솟는 플레어(높이감).
## 🔴 데칼(53)·플레어(54) 둘 다 반응 링(55) 아래라 "박혔다 → 퍼졌다" 순서로 읽힌다.
## 🔴 발산 진은 착탄점마다 emit돼 이 핸들러가 N번 불린다 — 그래서 플레어를 짧고 좁게 잡는다.
## 🔴 크기는 `score`를 `RingPower.quality_t`로 정규화해 보간한다. 등급 **이름**을 `==`로 비교하지
##   마라 — 이름을 바꾸는 순간 조용히 깨진다.
const DECAL_RADIUS_PLAIN := 15.0  ## 무난한 진(quality 0)의 바닥 데칼 반지름(px)
const DECAL_RADIUS_PERFECT := 30.0 ## 퍼펙트(quality 1)의 데칼 반지름 — 두 배로 벌린다
const DECAL_TIME := 0.22          ## 데칼 팽창·페이드 시간(s)
const DECAL_FLATTEN := 0.4        ## 데칼 세로 눌림(오블리크 지면 타원)
const FLARE_W := 9.0              ## 플레어 밑동 반폭(px) — 아래 배율이 곱해진다
const FLARE_H := 24.0             ## 플레어 높이(px) — 폭보다 커 세로 길쭉(높이 신호)
const FLARE_RISE := 10.0          ## 플레어가 위로 올라가는 양(px)
const FLARE_SCALE_PERFECT := 1.45 ## 퍼펙트에서 플레어가 몇 배까지 커지나(무난 = 1.0)
const FLARE_TIME := 0.16          ## 플레어 수명(s) — 짧게(다중 착탄 도배 방지)
const FLARE_START_SCALE := 0.5    ## 플레어 시작 배율(작게 시작 → 자라며 상승)
const IMPACT_Z := 54              ## 🔴 반응 링(VFX_Z=55) 아래 — 머즐·플레어 층 / 데칼은 IMPACT_Z-1(53)
## Db에 룬이 없을 때 폴백
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)

# ── 발밑 바닥 마법진 ────────────────────────────────────────────────────────────
## 🔴 **등급이 크기를 판다.** 이 반지름이 `compose_guide_paths`의 `ro`라 진 윤곽·층 반경·문양 크기가
## 통째로 따라 커진다 — 전부 `ro` 비율이라 손댈 데가 없다.
## ⚠ 플레이어 실루엣이 ≈28px라 무난은 몸을 겨우 감싸고 퍼펙트면 확실히 벗어난다.
const FLOOR_RADIUS_PLAIN := 28.0
const FLOOR_RADIUS_PERFECT := 50.0
## 룬이 하나도 안 실린 조립본의 폴백 — `RingDesign.runes_of`가 이 값으로 승격한다.
const FLOOR_RUNE_FALLBACK := Enums.RuneType.FIRE

## 지금 열려 있는 바닥 마법진 (한 번에 **하나**). 🔴 연사 차단은 `player_caster`가 지지만 여기서도
## 새 시전이 오면 옛 원을 먼저 지운다 — 그 계약이 풀려도 겹쳐 쌓이지 않게.
var _floor: Node2D = null


func _ready() -> void:
	EventBus.reaction_burst.connect(_on_reaction_burst)
	EventBus.reaction_chain.connect(_on_reaction_chain)
	EventBus.ring_cast_started.connect(_on_ring_cast_started)
	EventBus.ring_cast_canceled.connect(_on_ring_cast_canceled)
	EventBus.ring_cast_requested.connect(_on_ring_cast_fx)
	EventBus.spell_impact.connect(_on_spell_impact)


## 반응이 한 자리에서 터졌다(면적) — 팽창 링. 감전이면 중심 스파크도 얹는다.
func _on_reaction_burst(pos: Vector2, radius: float, status: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := SR.draw_color_of(status)
	_spawn_ring(scene, pos, radius, col)
	# 감전(SHOCK)만 중심 스파크 — 증기(NONE)는 흰 링만.
	if status == Enums.Status.SHOCK:
		_spawn_sparks(scene, pos, col)


## 상태가 A→B로 튀었다 — 지그재그 번개 아크 한 가닥(감전=노랑 · 바람=옮긴 상태색).
func _on_reaction_chain(from: Vector2, to: Vector2, status: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_spawn_arc(scene, from, to, SR.draw_color_of(status))


## 시전이 시작됐다 — 발밑에 「내가 조립한 그 마법진」이 열린다.
##
## 🔴 **매핑표를 만들지 않는다**: `compose_guide_paths`가 조립본 그 자체를 돌려주므로 문양 3개면
## 문양이 3개, 융합진이면 룬이 둘로 저절로 나온다. 문양·진을 늘려도 이 함수는 안 고친다.
##
## 인자 셋의 출처가 갈린다:
##   `runes`     — 🔴 반드시 `RingDesign.runes_of`를 거친다. `assembly["runes"]`를 직접 읽으면
##                 옛 도안·테스트 입력에서 **빈 목록이 나와 룬이 안 그려진다**.
##   `jin_shape` — 🔴 assembly엔 진 id뿐이다. `Db.get_jin(id).guide_shape`로 풀고 null이면 CIRCLE 폴백.
##   `band_defs` — 🔴 **rings를 원본 그대로 넣어라** — 옛 8칸 한 겹도 그 안에서 층 1개로 승격된다.
##
## 🔴🔴 **합성 `GlyphRingDef`에서 `motif`·`count` 말고 읽지 마라** — `ui_color` 기본값이 불색 주황이라
## 읽으면 검게 나오는 게 아니라 **「그럴듯하게」 틀린다**(모든 룬의 마법진이 주황이라 아무도 버그로
## 안 본다). 색은 룬이 판다 = `_rune_flash_color`.
func _on_ring_cast_started(assembly: Dictionary, origin: Vector2, duration: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_clear_floor()
	# 🔴 이 원은 「채워지는 것」을 보여주는 물건이라 duration이 0이면 보여줄 대상이 없다
	#   (열어 봐야 같은 프레임에 발사가 돌아 한 프레임짜리 깜빡임으로만 남는다).
	# ⚠ 스위치는 여기가 아니라 balance의 `cast_time_*` 둘이다.
	if duration <= 0.0:
		return
	var runes := RingDesign.runes_of(
		assembly.get("runes", []), int(assembly.get("rune", FLOOR_RUNE_FALLBACK)))
	var jd := Db.get_jin(StringName(assembly.get("jin", &"")))
	var shape := int(jd.guide_shape) if jd != null else int(Enums.JinShape.CIRCLE)
	var band_defs := RingBoard.band_defs_of(assembly.get("rings", []) as Array)
	var quality := RingPower.quality_t(float(assembly.get("score", 0.0)))
	var ro := lerpf(FLOOR_RADIUS_PLAIN, FLOOR_RADIUS_PERFECT, quality)
	# 🔴 `ctr = Vector2.ZERO` — 점열을 **노드 로컬**로 뽑는다. 그래야 발을 따라갈 때 노드 위치만
	# 옮기면 되고 점열을 매 프레임 다시 만들지 않는다.
	var paths := RingBoard.compose_guide_paths(shape, runes, band_defs, Vector2.ZERO, ro)

	var fc := FloorCircle.new() as Node2D
	# ⚠ 위치는 **붙인 뒤에** 준다 — `global_position`은 부모 트랜스폼을 거치므로 트리 밖에서
	#   대입하면 무대 루트가 원점이 아닐 때 조용히 어긋난다.
	scene.add_child(fc)
	fc.global_position = _floor_anchor(origin)
	fc.setup(paths, _floor_colors(runes, paths.size()), ro, duration, quality, _player_node())
	_floor = fc


## 🔴 시전이 끊겼다 — **반드시 지운다.** 안 지우면 발밑 원만 남아 *"쐈는데 안 나갔다"*로 읽힌다.
func _on_ring_cast_canceled() -> void:
	if _floor != null and is_instance_valid(_floor):
		_floor.cancel()
	_floor = null


## 발사 순간 — 총구에 작은 진 링 + 조준 방향 부채 틱. 여기가 **시전의 끝**이기도 해서 발밑
## 마법진이 확 퍼지며 꺼진다.
## ⚠ `ring_cast_started` 없이 이 신호만 오는 경로도 정상이다 — 그때 `_floor`가 null이라 no-op이 된다.
func _on_ring_cast_fx(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	if _floor != null and is_instance_valid(_floor):
		_floor.release()
	_floor = null
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := _rune_flash_color(int(assembly.get("rune", Enums.RuneType.FIRE)))
	_spawn_ring(scene, origin, MUZZLE_RADIUS, col, MUZZLE_TIME, IMPACT_Z)
	_spawn_muzzle_ticks(scene, origin, aim_dir, col)


## 🔴 서브패스마다 색 하나 — `compose_guide_paths`의 반환 순서와 **짝**이다:
##   `[진 윤곽] + [룬 자리마다 하나(음수 자리는 건너뜀)] + [밴드 모티프들…]`
## **융합진이 두 색으로 보이는 자리다.** 나머지는 첫 룬 색으로 통일한다 — 문양은 「무엇을 하는가」지
## 「무슨 속성인가」가 아니다. ⚠ 음수 건너뜀은 `compose_guide_paths`의 센티넬 규약을 따르는 방어다.
func _floor_colors(runes: Array, path_count: int) -> PackedColorArray:
	var primary := _rune_flash_color(int(runes[0]) if not runes.is_empty() else FLOOR_RUNE_FALLBACK)
	var out := PackedColorArray()
	out.append(primary)                       # [0] 진 윤곽
	for r in runes:
		if int(r) >= 0:
			out.append(_rune_flash_color(int(r)))
	while out.size() < path_count:
		out.append(primary)                   # 밴드 모티프들
	out.resize(path_count)                    # 어긋나도 길이는 맞춘다(색은 틀려도 그림은 안 죽는다)
	return out


## 🔴 **원의 중심은 발밑이지 총구가 아니다** — `origin`은 지팡이 끝이라 몸 옆에 떠 있어 그대로 쓰면
## 원이 캐릭터에서 비껴 앉는다. 플레이어가 없는 무대(검수 도구·테스트)에선 `origin`으로 떨어진다.
func _floor_anchor(origin: Vector2) -> Vector2:
	var p := _player_node()
	return p.global_position if p != null else origin


## 이 vfx가 붙어 있는 플레이어(없으면 null). 🔴 그룹으로 확인해 **다른 무대에 붙었을 때** 엉뚱한
## 노드를 따라가지 않게 한다.
func _player_node() -> Node2D:
	var p := get_parent() as Node2D
	return p if p != null and p.is_in_group(&"player") else null


## 열려 있던 원을 **연출 없이** 즉시 없앤다 — 새 시전이 겹쳐 들어온 자리 전용.
## ⚠ 취소·발사는 각자 제 연출이 있으므로 이걸 쓰지 마라.
func _clear_floor() -> void:
	if _floor != null and is_instance_valid(_floor):
		_floor.queue_free()
	_floor = null


## 탄이 적에 박혔다 — 바닥 데칼 + 솟는 플레어.
## 🔴 **발신원이 `spell_impact`인 게 계약이다** — `enemy_hit`을 쓰면 기둥 틱·반응 피해마다 도배된다.
## 🔴 `quality_t`를 거친다 — 점수를 그대로 쓰면 하한 0.70 때문에 무난한 진이 이미 중간 크기다.
func _on_spell_impact(pos: Vector2, rune_type: int, score: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := _rune_flash_color(rune_type)
	var quality := RingPower.quality_t(score)
	var decal_r := lerpf(DECAL_RADIUS_PLAIN, DECAL_RADIUS_PERFECT, quality)
	_spawn_ring(scene, pos, decal_r, col, DECAL_TIME, IMPACT_Z - 1, DECAL_FLATTEN)
	_spawn_flare(scene, pos, col, lerpf(1.0, FLARE_SCALE_PERFECT, quality))


## 룬 → 플래시 색. 🔴 **`ui_color`를 그대로 쓴다 — 밝히지 마라.** 흰색을 섞으면 채도가 죽어 룬끼리
## 구분이 흐려지고 팔레트 밖으로 나간다(색을 정렬했는데 화면이 안 변한 원인이 그 한 줄이었다).
## ⚠ 밝기가 모자라면 색이 아니라 굵기·수명·알파로 벌어라.
func _rune_flash_color(rune_type: int) -> Color:
	var rune := Db.get_rune(rune_type) as RuneDef
	return rune.ui_color if rune != null else RUNE_FALLBACK


## 🔴 링을 **실제 게임 반경**으로 그린다 — "여기까지 튄다"가 눈에 보여야 「반경 밖이라 연쇄가 한 번도
## 안 터졌다」류의 함정을 링이 폭로한다.
## flatten: 세로 스케일 배수(1.0=정원). 착탄 데칼만 <1로 눌린 오블리크 지면 타원을 만든다.
func _spawn_ring(scene: Node, pos: Vector2, radius: float, col: Color,
		time: float = RING_TIME, z: int = VFX_Z, flatten: float = 1.0) -> void:
	var ring := Line2D.new()
	ring.width = RING_WIDTH
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in RING_SEGMENTS:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(RING_SEGMENTS)) * radius)
	pts.append(pts[0])  # 닫는다(closed 프로퍼티 대신 첫 점을 다시 찍어 버전 무관하게)
	ring.points = pts
	ring.global_position = pos
	ring.z_index = z
	ring.scale = Vector2(RING_START_SCALE, RING_START_SCALE * flatten)
	ring.modulate.a = RING_START_ALPHA
	scene.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.0, flatten), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, time)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


## 감전 중심 — 몸에서 방사형으로 짧게 번쩍. 한 부모 아래 여러 Line2D를 묶어 함께 튄다.
func _spawn_sparks(scene: Node, pos: Vector2, col: Color,
		count: int = SPARK_COUNT, z: int = VFX_Z + 1) -> void:
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = z
	var bright := col.lightened(SPARK_LIGHTEN)
	bright.a = 1.0
	for i in count:
		var ln := Line2D.new()
		ln.width = SPARK_WIDTH
		ln.default_color = bright
		var ang := TAU * float(i) / float(count) + randf_range(-0.35, 0.35)
		var length := randf_range(SPARK_LEN_MIN, SPARK_LEN_MAX)
		ln.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(ang) * length])
		holder.add_child(ln)
	scene.add_child(holder)
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale", Vector2(SPARK_END_SCALE, SPARK_END_SCALE), SPARK_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 0.0, SPARK_TIME)
	tw.set_parallel(false)
	tw.tween_callback(holder.queue_free)


## 솟는 플레어 — 세로 길쭉한 불꽃이 착탄점에서 위로 올라가며 자라고 페이드한다. 원점 = 밑동 중심.
## 🔴 **모양은 그대로 두고 최종 배율만 키운다** — 폴리곤을 다시 짜면 등급마다 실루엣이 달라져
## 「같은 마법의 강약」으로 안 읽힌다. 상승량도 같이 곱한다(안 그러면 제자리에서 부풀기만 한다).
func _spawn_flare(scene: Node, pos: Vector2, col: Color, size_mult: float = 1.0) -> void:
	var flare := Polygon2D.new()
	flare.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(FLARE_W, -FLARE_H * 0.35),
		Vector2(FLARE_W * 0.4, -FLARE_H * 0.75),
		Vector2(0.0, -FLARE_H),
		Vector2(-FLARE_W * 0.4, -FLARE_H * 0.75),
		Vector2(-FLARE_W, -FLARE_H * 0.35),
	])
	flare.color = col
	flare.global_position = pos
	flare.z_index = IMPACT_Z
	flare.scale = Vector2.ONE * FLARE_START_SCALE * size_mult
	scene.add_child(flare)
	var tw := flare.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flare, "scale", Vector2.ONE * size_mult, FLARE_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(flare, "global_position:y",
		pos.y - FLARE_RISE * size_mult, FLARE_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(flare, "modulate:a", 0.0, FLARE_TIME)
	tw.set_parallel(false)
	tw.tween_callback(flare.queue_free)


## 머즐 부채 틱 — 조준 방향으로 짧은 선 몇 개가 바깥으로 튄다(발사 방향이 읽히게).
func _spawn_muzzle_ticks(scene: Node, pos: Vector2, aim_dir: Vector2, col: Color) -> void:
	var base_ang := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = IMPACT_Z
	for i in MUZZLE_TICKS:
		var t := 0.5 if MUZZLE_TICKS <= 1 else float(i) / float(MUZZLE_TICKS - 1)
		var ang := base_ang + (t - 0.5) * MUZZLE_TICK_SPREAD
		var dir := Vector2.from_angle(ang)
		var ln := Line2D.new()
		ln.width = MUZZLE_TICK_WIDTH
		ln.default_color = col
		ln.points = PackedVector2Array(
			[dir * MUZZLE_TICK_DIST, dir * (MUZZLE_TICK_DIST + MUZZLE_TICK_LEN)])
		holder.add_child(ln)
	scene.add_child(holder)
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "scale",
		Vector2(MUZZLE_END_SCALE, MUZZLE_END_SCALE), MUZZLE_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 0.0, MUZZLE_TIME)
	tw.set_parallel(false)
	tw.tween_callback(holder.queue_free)


## from→to를 몇 세그먼트로 나눠 중점을 수직으로 랜덤 변위한 지그재그 번개. 양 끝은 정확히 from·to에 박는다.
func _spawn_arc(scene: Node, from: Vector2, to: Vector2, col: Color) -> void:
	var arc := Line2D.new()
	arc.width = ARC_WIDTH
	var bright := col.lightened(ARC_LIGHTEN)
	bright.a = 1.0
	arc.default_color = bright
	arc.z_index = VFX_Z
	var seg := to - from
	var perp := seg.orthogonal().normalized() if seg.length() > 0.01 else Vector2.UP
	var pts := PackedVector2Array()
	for i in ARC_SEGMENTS + 1:
		var t := float(i) / float(ARC_SEGMENTS)
		var base := seg * t
		var off := 0.0
		if i > 0 and i < ARC_SEGMENTS:  # 양 끝(from·to)은 변위 없음 — 정확히 두 몸을 잇는다
			off = randf_range(-ARC_JITTER, ARC_JITTER)
		pts.append(base + perp * off)
	arc.points = pts
	arc.global_position = from
	scene.add_child(arc)
	var tw := arc.create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, ARC_TIME)
	tw.tween_callback(arc.queue_free)
