extends Node2D
## 원소 반응 VFX 스포너 (세션52) — Juice의 형제 공용 노드. 반응이 터진 자리·연쇄가 튄 선을
## **Node2D 절차 연출**로 그린다(파티클 안 씀 — death_puff 결).
##
## 🔴 왜 Player 아래 공용 노드인가: juice.gd와 똑같은 이유다. Player가 공용 배우라 **베이스(연습장)·
## 숲 양쪽에 자동으로 산다** — 사용자가 마법을 만들고 바로 쏴 보는 연습장에서 반응이 보여야 한다.
## 상태 보유고(status_holder)가 연습장 허수아비도 쓰도록 추출된 것과 짝이 맞는다(설계 §1의 존재 이유).
##
## 🔴 EventBus만 본다 (타 모듈 직접 참조 금지). 신호 둘:
##   reaction_burst(pos, radius, status) → 팽창 링 (감전이면 중심 스파크도)
##   reaction_chain(from, to, status)    → 지그재그 번개 아크
## 각 핸들러는 연출 Node2D를 만들어 **`get_tree().current_scene`에 add_child** + global_position만
## 세팅한다 (juice._spawn_number·death_puff와 동일 — Player 트랜스폼에 안 묶이게 월드 씬에 붙인다).
##
## 🔴 색은 `SR.tint_of(status)` **재사용** — 상태 색 단일 소스를 되쓴다(색 테이블 복사 금지).
##   증기(NONE)는 tint_of가 흰색을 돌려주므로 그대로 맞다.
##
## 🔴 여기 수치는 밸런스가 아니라 **연출값(손맛)이다** (juice.gd·forest_enemy 팝 상수 선례) —
##   balance.tres가 아니라 여기 const로 둔다. 사용자가 쏴 보며 조일 값이다.
##
## class_name 없음 — 모듈 규칙(preload로만 참조).

const SR := preload("res://src/core/status_rules.gd")

# ── 팽창 링 (버스트 면적 — 반경을 truthful하게 폭로한다) ──────────────────────────
const RING_SEGMENTS := 24        ## 링 원 분할 수
const RING_WIDTH := 3.0          ## 링 선 굵기(px)
const RING_START_SCALE := 0.35   ## 시작 배율(작게 시작해 반경까지 팽창)
const RING_TIME := 0.28          ## 팽창·페이드 시간(s)
const RING_START_ALPHA := 0.9    ## 링 시작 알파

# ── 감전 중심 스파크 (SHOCK 전용 — "아크 + 중심 스파크", 사용자 확정) ──────────────
const SPARK_COUNT := 6           ## 중심에서 방사되는 짧은 번쩍 개수
const SPARK_LEN_MIN := 8.0       ## 스파크 길이 최소(px)
const SPARK_LEN_MAX := 16.0      ## 스파크 길이 최대(px)
const SPARK_WIDTH := 2.0         ## 스파크 굵기(px)
const SPARK_BRIGHT := 1.8        ## 스파크 번쩍 밝기 배수
const SPARK_TIME := 0.14         ## 스파크 수명(s)
const SPARK_END_SCALE := 1.5     ## 스파크가 바깥으로 튀는 최종 배율

# ── 지그재그 번개 아크 (감전 연쇄 · 바람 확산 공용) ────────────────────────────────
const ARC_SEGMENTS := 6          ## 지그재그 세그먼트 수(중점 개수 = SEG-1)
const ARC_JITTER := 10.0         ## 중점 수직 변위 최대(px)
const ARC_WIDTH := 2.5           ## 아크 선 굵기(px)
const ARC_BRIGHT := 1.6          ## 번쩍 밝기 배수
const ARC_TIME := 0.15           ## 아크 수명(s)

## 연출을 death_puff(50) 위로 — 적 스프라이트·퍼프보다 위에서 번쩍인다.
const VFX_Z := 55

# ── 머즐 플래시 (세션59 설계 §2-D) — 기존 `ring_cast_requested` 재사용, 신규 시그널 0.
## 마나 부족이면 player_caster.fire()가 먼저 걸러 emit 자체가 안 온다 — 헛플래시 없음.
const MUZZLE_RADIUS := 12.0       ## 총구의 작은 진 링 반지름(px)
const MUZZLE_TIME := 0.10         ## 확대+페이드 시간(s)
const MUZZLE_TICKS := 3           ## 조준 방향 부채 틱 개수
const MUZZLE_TICK_LEN := 9.0      ## 틱 길이(px)
const MUZZLE_TICK_DIST := 10.0    ## 총구에서 틱 시작까지 거리(px)
const MUZZLE_TICK_SPREAD := 0.55  ## 부채 전체 각(rad)
const MUZZLE_TICK_WIDTH := 2.0    ## 틱 굵기(px)
const MUZZLE_END_SCALE := 1.4     ## 틱이 바깥으로 튀는 최종 배율

# ── 착탄 버스트 (세션59 설계 §2-D) — 신규 `spell_impact`("탄이 박혔다") 수신.
## 🔴 reaction_burst와의 시각 분리: 착탄 = **작고 짧은 속 찬 플래시**(16px·0.15s·z=54) /
## 반응 = 크고 긴 팽창 **외곽선** 링(실반경·0.28s·z=55). 형태·크기·수명·z가 전부 달라
## 동시에 터져도 "박혔다 → 퍼졌다" 순서로 읽힌다. 착탄 z는 반응 아래(54).
const IMPACT_RADIUS := 16.0       ## 속 찬 팝 최종 반지름(px)
const IMPACT_TIME := 0.15         ## 팝 시간(s)
const IMPACT_SPIKES := 4          ## 방사 틱 개수 (반응 스파크 6개와 구분)
const IMPACT_START_SCALE := 0.3   ## 팝 시작 배율 (작게 시작 → IMPACT_RADIUS)
const IMPACT_POP_SEGMENTS := 16   ## 팝 원 분할 수
const FLASH_LIGHTEN := 0.35     ## ui_color는 UI 셀용이라 어둡다 — 플래시용 밝힘(머즐·착탄 공용, carrier GLOW_LIGHTEN 결)
const IMPACT_Z := 54              ## 🔴 반응 링(VFX_Z=55) 아래 — 머즐도 같은 층
## Db에 룬이 없을 때 폴백 (ring_carrier와 같은 규칙)
const RUNE_FALLBACK := Color(0.95, 0.35, 0.15)


func _ready() -> void:
	EventBus.reaction_burst.connect(_on_reaction_burst)
	EventBus.reaction_chain.connect(_on_reaction_chain)
	EventBus.ring_cast_requested.connect(_on_ring_cast_fx)
	EventBus.spell_impact.connect(_on_spell_impact)


## 반응이 한 자리에서 터졌다(면적) — 팽창 링. 감전이면 중심 스파크도 얹는다.
func _on_reaction_burst(pos: Vector2, radius: float, status: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := SR.tint_of(status)
	_spawn_ring(scene, pos, radius, col)
	# 🔴 감전(SHOCK)만 중심 스파크 — 증기(NONE)는 흰 링만(설계 §4).
	if status == Enums.Status.SHOCK:
		_spawn_sparks(scene, pos, col)


## 상태가 A→B로 튀었다 — 지그재그 번개 아크 한 가닥(감전=노랑 · 바람=옮긴 상태색).
func _on_reaction_chain(from: Vector2, to: Vector2, status: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_spawn_arc(scene, from, to, SR.tint_of(status))


## 발사 순간 (세션59) — 총구에 작은 진 링 확대+페이드 + 조준 방향 부채 틱 ("작은 진이 번쩍").
## assembly `rune` 키로 룬색 — 시그니처에 필요한 전부(origin·rune·aim_dir)가 이미 실려 있다.
func _on_ring_cast_fx(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := _rune_flash_color(int(assembly.get("rune", Enums.RuneType.FIRE)))
	_spawn_ring(scene, origin, MUZZLE_RADIUS, col, MUZZLE_TIME, IMPACT_Z)
	_spawn_muzzle_ticks(scene, origin, aim_dir, col)


## 탄이 적에 박혔다 (세션59) — 룬색 속 찬 팝 + 방사 틱. 발신원이 spell_impact인 게 핵심 계약:
## enemy_hit을 쓰면 기둥 틱·반응 피해마다 버스트가 도배된다 (설계 §3 — DoT 도배 함정의 사촌).
func _on_spell_impact(pos: Vector2, rune_type: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var col := _rune_flash_color(rune_type)
	_spawn_pop(scene, pos, col)
	_spawn_sparks(scene, pos, col, IMPACT_SPIKES, IMPACT_Z)


## 룬 → 플래시 색. vfx는 Player 자식(오토로드 컨텍스트 보장)이라 Db 직접 호출 OK —
## SR.tint_of 재사용과 같은 결. ui_color의 **파생**(lightened)이다 — 새 색 테이블 아님.
func _rune_flash_color(rune_type: int) -> Color:
	var rune := Db.get_rune(rune_type) as RuneDef
	var base := rune.ui_color if rune != null else RUNE_FALLBACK
	return base.lightened(FLASH_LIGHTEN)


## 🔴 링을 **실제 게임 반경**으로 그린다(작게 시작→반경까지 팽창) — "여기까지 튄다"가 눈에 보이고,
## 세50의 「반경 밖이라 연쇄가 한 번도 안 터졌다」 함정을 링이 폭로한다.
## 세션59: 머즐 플래시가 재사용할 수 있게 시간·z를 선택 인자로 열었다 — 기존 호출은 기본값 그대로.
func _spawn_ring(scene: Node, pos: Vector2, radius: float, col: Color,
		time: float = RING_TIME, z: int = VFX_Z) -> void:
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
	ring.scale = Vector2(RING_START_SCALE, RING_START_SCALE)
	ring.modulate.a = RING_START_ALPHA
	scene.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE, time).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, time)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


## 감전 중심 — 몸에서 방사형으로 짧게 번쩍(전기 스파크). 한 부모 아래 여러 Line2D를 묶어 함께 튄다.
## 세션59: 착탄 버스트가 재사용할 수 있게 개수·z를 선택 인자로 열었다 — 기존 호출은 기본값 그대로.
func _spawn_sparks(scene: Node, pos: Vector2, col: Color,
		count: int = SPARK_COUNT, z: int = VFX_Z + 1) -> void:
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = z
	var bright := col * SPARK_BRIGHT
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


## 착탄 팝 (세션59) — 룬색 **속 찬** 원이 작게 시작해 IMPACT_RADIUS까지 커지며 사라진다.
## Polygon2D 도형이지만 절차 VFX 예외에 해당(빛 이펙트 — 도트로 그릴 물건이 아니다).
func _spawn_pop(scene: Node, pos: Vector2, col: Color) -> void:
	var pop := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in IMPACT_POP_SEGMENTS:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(IMPACT_POP_SEGMENTS)) * IMPACT_RADIUS)
	pop.polygon = pts
	pop.color = col
	pop.global_position = pos
	pop.z_index = IMPACT_Z
	pop.scale = Vector2.ONE * IMPACT_START_SCALE
	scene.add_child(pop)
	var tw := pop.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pop, "scale", Vector2.ONE, IMPACT_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "modulate:a", 0.0, IMPACT_TIME)
	tw.set_parallel(false)
	tw.tween_callback(pop.queue_free)


## 머즐 부채 틱 (세션59) — 조준 방향으로 짧은 선 몇 개가 바깥으로 튄다 (발사 방향이 읽히게).
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
	var bright := col * ARC_BRIGHT
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
