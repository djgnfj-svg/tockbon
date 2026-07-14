extends Node2D
## 스펠 발사 시스템 — 모듈 B. 필드 씬에 자식으로 넣기만 하면 되는 자립 노드.
## EventBus.cast_requested 수신 → 내구·마나 검사 → SpellDesign을 투사체로 컴파일.
##
## **역할 축 (v2.0, TECH_SPEC §4.0)**:
##   **지팡이** = 방향(에임)·발수·기점  /  **진** = 규모 + **투사체의 모양**
##   **룬** = 속성 + 농도             /  **문양** = **효과 부여** (한 탄에 N개가 얹힌다)
##
## 🔴 **v2.0에서 방향이 문양에서 지팡이로 갔다** (사용자 확정). 그 한 줄이 연쇄를 일으킨다:
##   문양이 방향을 안 정하는데 문양마다 탄을 만들면 **N발이 같은 자리에 겹쳐 나간다.**
##   그래서 **발수는 지팡이가 갖고(_wand_shots), 문양은 그 탄에 얹히는 효과가 된다(compile_effects).**
##   팅김⚡ + 관통‖를 한 장에 그리면 **튕기면서 뚫는 탄 하나**가 나간다.
##
## 소비 중단된 값들 (필드는 남지만 **읽지 말 것**): ArrowData.direction · ArrowData.origin ·
## SpellDesign.aim_axis · SpellDesign.circle_type. 발사각은 **에임 하나**이고 회전은 없다.

const ProjectileScene := preload("res://src/spell/projectile.tscn")
const ProjectileScript := preload("res://src/spell/projectile.gd")
const InkRender := preload("res://src/core/ink_render.gd")

## 캐스팅 마법진 연출 (밸런스 수치 아님 — 연출 전용. 선례: src/field/boss_intro.gd)
const CIRCLE_GROW_SEC := 0.14        # 발밑에서 진이 펼쳐지는 시간
const CIRCLE_FADE_SEC := 0.26        # 사그라드는 시간 (총 0.4초 — 연사를 가리지 않는 길이)
const CIRCLE_SCALE_FROM := 0.75      # 펼쳐지기 전 크기
const CIRCLE_Z := -5                 # 지형(-10..-8) 위, 플레이어(0) 아래 — 바닥에 깔린 진

## 총구 오프셋 — 탄이 플레이어 몸 안에서 생기지 않도록 조준 방향으로 밀어낸다.
## 물리 여유값이지 밸런스가 아니다 (기본 완드 약공격 wand_bolt와 같은 10px)
const MUZZLE_PX := 10.0

var balance: BalanceData = preload("res://data/balance.tres")

func _ready() -> void:
	EventBus.cast_requested.connect(_on_cast_requested)

func _on_cast_requested(design: SpellDesign, origin: Vector2, aim_dir: Vector2) -> void:
	if design == null or design.arrows.is_empty():
		EventBus.cast_failed.emit(design, Enums.CastFailReason.INVALID)
		return
	# 내구를 마나보다 먼저 검사 — 손상 도안에 마나를 낭비하지 않게
	if design.is_broken():
		EventBus.cast_failed.emit(design, Enums.CastFailReason.BROKEN)
		return
	if not GameState.spend_mana(design.mana_cost):
		EventBus.cast_failed.emit(design, Enums.CastFailReason.NO_MANA)
		return
	_spawn_projectiles(design, origin, aim_dir)
	design.durability -= 1
	EventBus.cast_executed.emit(design, design.mana_cost)


# ── 지팡이 축 (v2.0) ──────────────────────────────────────────────────────
# 사용자: "결국 보는 방향으로 발사가 맞고, **지팡이에 따라** 여러 발이 나가거나
#          내 주변에서 전체 방향으로 나가거나가 정해짐."

## 지팡이가 **발사각 목록**을 준다 — 이 함수가 **발수와 방향의 유일한 출처**다.
## 사용자: *"결국 보는 방향으로 발사가 맞고, 지팡이에 따라 여러 발이 나가거나
## 내 주변에서 전체 방향으로 나가거나가 정해짐."*
##
## 🔴 **WandDef 리소스를 만들지 않았다.** `ItemDef.params["wand_pattern"]`이면 충분하다 —
## **새 지팡이는 .tres 하나 추가하면 끝**이고 코드는 안 바뀐다 (GameState.wand_pattern).
##
## ⚠ **NOVA는 에임과 무관하게 균등하다** — 에임이 바뀌면 통째로 돌 뿐 간격은 불변이다.
## (v1.5가 "대칭 도안은 회전해도 대칭이라 고정진이 필요 없다"고 한 것과 같은 성질을
##  이제 **지팡이가** 갖는다. 도안이 아니라 무기가 대칭을 만든다)
func wand_shots(aim_angle: float) -> Array[float]:
	var out: Array[float] = []
	match GameState.wand_pattern():
		Enums.WandPattern.NOVA:
			var n := maxi(balance.wand_nova_count, 1)
			for i in n:
				out.append(aim_angle + TAU * float(i) / float(n))
		Enums.WandPattern.MULTI:
			var n := maxi(balance.wand_multi_count, 1)
			var spread := deg_to_rad(balance.wand_multi_spread_deg)
			if n == 1:
				out.append(aim_angle)
			else:
				# 양 끝 사이가 spread — 에임이 한가운데다 (홀수면 정중앙에 한 발이 온다)
				for i in n:
					var t := float(i) / float(n - 1) - 0.5
					out.append(aim_angle + t * spread)
		_:
			out.append(aim_angle)
	return out


# ── 문양 축 (v2.0) — 효과 부여 ────────────────────────────────────────────

## 도안의 문양들 → **효과 사전** {GlyphType: Σreach}.
##
## 🔴 **문양 개수는 발수가 아니다** (v2.0). 한 탄에 전부 얹힌다.
## **같은 글자를 여럿 그으면 세기가 합산된다** — 팅김을 둘 그으면 더 튕긴다.
## BASIC(글자 아닌 획)은 **효과가 없다** — 사거리에만 기여한다 (아래 design_reach).
func compile_effects(design: SpellDesign) -> Dictionary:
	var effects: Dictionary = {}
	for arrow: ArrowData in design.arrows:
		if arrow.glyph == Enums.GlyphType.BASIC:
			continue
		effects[arrow.glyph] = float(effects.get(arrow.glyph, 0.0)) + arrow.reach
	return effects


## 사거리 배율의 입력 = 문양 reach의 **최댓값** — *가장 멀리 뻗은 획만큼 날아간다.*
##
## 🔴 **합이 아니라 최댓값인 이유**: 합이면 효과를 하나 더 얹을 때마다 사거리가 **공짜로** 늘어나
## "문양은 무조건 많이"가 유일한 정답이 된다. 최댓값이면 멀리 보내려면 **실제로 길게 그어야** 한다.
## 문양이 없으면 1.0 (기준 배율 — 구세이브·샘플 도안 불변).
func design_reach(design: SpellDesign) -> float:
	var best := 0.0
	for arrow: ArrowData in design.arrows:
		best = maxf(best, arrow.reach)
	return best if best > 0.0 else 1.0


# ── 진 축 (v1.6~, 유지) ───────────────────────────────────────────────────

## 위력 = 기본 위력 × **진 규모** × 룬 계수 (TECH_SPEC §4.0).
## v1.7: rune_accuracy를 위력에서 뺐다 (축 위반 해소) — 위력은 진의 축이고,
## accuracy는 속성 순도로 옮겨 갔다 (compute_status_power). 룬이 위력을 흔들면 진이 의미를 잃는다.
func compute_damage(design: SpellDesign, rune: RuneDef) -> float:
	var rune_coef := rune.base_damage if rune != null else 1.0
	return balance.projectile_base_damage * (balance.circle_damage_base + design.circle_radius) \
		* rune_coef


## 상태이상 세기 — **룬의 농도 축** (v1.7, TECH_SPEC §4.0).
## 세기 = RuneDef.status_power × 농도(rune_fill) × 순도(rune_accuracy, 하한 accuracy_floor).
## 진을 꽉 채운 룬은 깊이 물들고, 구석에 작게 그린 룬은 옅게 스친다. 위력은 건드리지 않는다.
func compute_status_power(design: SpellDesign, rune: RuneDef) -> float:
	if rune == null:
		return 0.0
	var density := lerpf(balance.rune_density_min, balance.rune_density_max,
		clampf(design.rune_fill, 0.0, 1.0))
	var accuracy := maxf(design.rune_accuracy, balance.accuracy_floor)
	return rune.status_power * density * accuracy


## 탄의 반지름(px) — **v2.0: 진이 곧 탄이다.** 진 반지름(캔버스 0.5×circle_radius)을
## 월드로 옮기고 projectile_circle_scale로 줄인다. **먹선과 히트박스가 이 함수 하나를 공유한다** —
## 갈라지면 보이는 것과 맞는 것이 어긋난다 (그게 이 게임의 정체성이다).
##
## ⚠ compute_size_scale(circle_size_min/max)은 **v2.0에서 소비 중단**됐다 — 탄이 진과 무관한
## 스프라이트였을 때만 말이 되던 배율이고, 지금 곱하면 **같은 축을 두 번** 먹인다.
func compute_radius_px(design: SpellDesign) -> float:
	var r := design.circle_radius * 0.5 * InkRender.unit_px(balance) * balance.projectile_circle_scale
	return maxf(r, balance.projectile_min_radius_px)


## **기준** 사거리(투사체 수명, 초) — 진 규모 축. 속도가 고정이므로 수명 = 사거리.
func compute_lifetime(design: SpellDesign) -> float:
	return balance.projectile_lifetime_sec * lerpf(balance.circle_range_min, balance.circle_range_max,
		clampf(design.circle_radius, 0.0, 1.0))


## 탄의 실제 사거리 = **진 기준 사거리 × 문양 배율**(최장 문양).
## 🔴 **v2.0: 도안당 1회다.** v1.9는 탄마다 갈라졌는데(문양 1개 = 1발이었으므로), 이제
## 한 탄에 모든 문양이 얹히므로 **갈라질 것이 없다.**
func compute_design_lifetime(design: SpellDesign) -> float:
	return compute_lifetime(design) * ProjectileScript.range_mult(balance, design_reach(design))


func _spawn_projectiles(design: SpellDesign, origin: Vector2, aim_dir: Vector2) -> void:
	var rune: RuneDef = Db.get_rune(design.rune_type)
	if rune == null:
		push_warning("SpellSystem: RuneDef 미등록 (rune_type=%d) — 기본 계수로 발사" % design.rune_type)
	var aim_angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	_spawn_cast_circle(design, origin)

	var scene := ProjectileScene
	if rune != null and rune.projectile_scene != null:
		scene = rune.projectile_scene

	# 전부 도안당 1회다 — **탄마다 갈라지는 값이 하나도 없다** (v2.0).
	# 지팡이가 발수를 정하므로 같은 도안의 탄들은 방향만 다르다.
	var damage := compute_damage(design, rune)
	var status_power := compute_status_power(design, rune)
	var effects := compile_effects(design)
	var lifetime := compute_design_lifetime(design)

	for shot_angle: float in wand_shots(aim_angle):
		var proj := scene.instantiate() as ProjectileScript
		if proj == null:
			push_warning("SpellSystem: projectile_scene이 투사체 스크립트가 아님 — 스킵")
			continue
		add_child(proj)
		proj.global_position = origin + Vector2.RIGHT.rotated(shot_angle) * MUZZLE_PX
		proj.setup(
			damage,
			design.rune_type,
			rune.status if rune != null else Enums.Status.NONE,
			status_power,
			balance.projectile_base_speed,
			shot_angle,
			effects,
			lifetime,
			design
		)

## 발밑에 내가 그린 진이 먹선으로 펼쳐졌다 사라진다 (GDD §10.5). 순수 비주얼 — 충돌·물리 없음.
## strokes가 없는 샘플·구세이브 도안이면 build_design이 null → 조용히 스킵.
##
## 🔴 **v2.0: 회전이 없다.** v1.9는 도안 전체를 에임으로 돌렸지만(aim_axis), 방향이 지팡이로
## 간 지금 돌릴 이유가 없다 — **그린 자세 그대로** 발밑에 펼쳐진다.
func _spawn_cast_circle(design: SpellDesign, origin: Vector2) -> void:
	var circle := InkRender.build_design(design, InkRender.unit_px(balance), {"bright": true})
	if circle == null:
		return
	circle.name = "CastCircle"
	circle.z_index = CIRCLE_Z
	circle.scale = Vector2.ONE * CIRCLE_SCALE_FROM
	add_child(circle)
	circle.global_position = origin

	var tw := circle.create_tween()
	tw.tween_property(circle, "scale", Vector2.ONE, CIRCLE_GROW_SEC) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(circle, "modulate:a", 0.0, CIRCLE_FADE_SEC) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(circle.queue_free)
