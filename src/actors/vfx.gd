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


func _ready() -> void:
	EventBus.reaction_burst.connect(_on_reaction_burst)
	EventBus.reaction_chain.connect(_on_reaction_chain)


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


## 🔴 링을 **실제 게임 반경**으로 그린다(작게 시작→반경까지 팽창) — "여기까지 튄다"가 눈에 보이고,
## 세50의 「반경 밖이라 연쇄가 한 번도 안 터졌다」 함정을 링이 폭로한다.
func _spawn_ring(scene: Node, pos: Vector2, radius: float, col: Color) -> void:
	var ring := Line2D.new()
	ring.width = RING_WIDTH
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in RING_SEGMENTS:
		pts.append(Vector2.RIGHT.rotated(TAU * float(i) / float(RING_SEGMENTS)) * radius)
	pts.append(pts[0])  # 닫는다(closed 프로퍼티 대신 첫 점을 다시 찍어 버전 무관하게)
	ring.points = pts
	ring.global_position = pos
	ring.z_index = VFX_Z
	ring.scale = Vector2(RING_START_SCALE, RING_START_SCALE)
	ring.modulate.a = RING_START_ALPHA
	scene.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE, RING_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, RING_TIME)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)


## 감전 중심 — 몸에서 방사형으로 짧게 번쩍(전기 스파크). 한 부모 아래 여러 Line2D를 묶어 함께 튄다.
func _spawn_sparks(scene: Node, pos: Vector2, col: Color) -> void:
	var holder := Node2D.new()
	holder.global_position = pos
	holder.z_index = VFX_Z + 1
	var bright := col * SPARK_BRIGHT
	bright.a = 1.0
	for i in SPARK_COUNT:
		var ln := Line2D.new()
		ln.width = SPARK_WIDTH
		ln.default_color = bright
		var ang := TAU * float(i) / float(SPARK_COUNT) + randf_range(-0.35, 0.35)
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
