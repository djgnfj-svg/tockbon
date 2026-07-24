extends Node2D
## 고리 조립 발사 시스템 — 모듈 B (세션 12~). 필드 씬에 자식으로 넣기만 하면 되는 자립 노드.
## EventBus.ring_cast_requested 수신 → 진(캐리어)을 조준 방향으로 쏜다.
##
## 🔴 세션 22: 옛 spell_system(SpellDesign·cast_requested)을 매장해 **이게 유일한 발사 경로**다.
##
## 발사 모델 (사용자 확정 세션 10):
##   1) 발사 = 조립한 마법진(진)이 통째로 조준 방향으로 날아간다 (ring_carrier).
##   2) 착탄 = 적에 닿는 그 자리에서 안의 고리가 전개된다:
##        • 발산→ 칸: 그 방향으로 불 탄환 (projectile.tscn 순수 직진탄 재사용)
##        • 응집← 칸: 하나로 모여 불기둥 (pillar.tscn 재사용, 많을수록 굵다)
##
## 마나·내구 판정 없음 (고리 모델의 경제는 #17에서 정한다 — 지금은 순수 발사 검증).

const RingPower := preload("res://src/core/ring_power.gd")
const StatusRules := preload("res://src/core/status_rules.gd")   # 🔴 세81 M2: 융합 룬 반응 순서 정렬
const CarrierScene := preload("res://src/spell/ring_carrier.tscn")
const CarrierScript := preload("res://src/spell/ring_carrier.gd")
const BoltScript := preload("res://src/spell/projectile.gd")
const PillarScene := preload("res://src/spell/pillar.tscn")
const PillarScript := preload("res://src/spell/pillar.gd")
const BlastScene := preload("res://src/spell/blast.tscn")
const BlastScript := preload("res://src/spell/blast.gd")

const SLOTS := 8

## 응집 굵기 — 기둥 하나당 scale 증가분 (연출값, 밸런스 아님. 선례: spell_system CIRCLE_* 연출 상수).
## 응집 1개면 기본 크기, 여럿 모이면 굵어진다 ("많을수록 굵다").
const PILLAR_SCALE_PER_GATHER := 0.22

## 🔴 발사 코드 → 탄 행동 효과 (세션47). RADIATE는 효과 없는 순수 직진탄이고, 2~5는 **같은 탄에
## 효과 하나가 얹힌 것**이다 — `projectile._setup_effects`가 이미 소비하는 사전 형식({GlyphType: reach}).
## 세션44 이전엔 이 사전이 늘 비어 있어 팅김·유도·추진 기계가 통째로 잠들어 있었다(미배선 자산).
## **새 문양 = 여기 한 줄** (+ `Enums.GlyphCode` 값 하나 + `data/glyphs/*.tres` 한 장).
const BOLT_EFFECTS := {
	Enums.GlyphCode.PIERCE: Enums.GlyphType.PIERCE,
	Enums.GlyphCode.HOMING: Enums.GlyphType.HOMING,
	Enums.GlyphCode.BOUNCE: Enums.GlyphType.BOUNCE,
	Enums.GlyphCode.THRUST: Enums.GlyphType.THRUST,
}

var balance: BalanceData = preload("res://data/balance.tres")


func _ready() -> void:
	EventBus.ring_cast_requested.connect(_on_ring_cast)


## 🔴 세션 23: `assembly.score`(손그림 종합)가 **위력을 정한다**. 점수를 안 실어 온 assembly는
## 기준 위력(1.0)으로 폴백한다 — 옛 저장·테스트가 조용히 0 피해가 되지 않도록.
## (펑 판정은 **여기가 아니라 조립대**의 몫이다 — 터진 마법진은 애초에 발사까지 오지 않는다.)
func _on_ring_cast(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	var rings: Array = assembly.get("rings", [])
	if rings.is_empty():
		return
	# 🔴 세79 M1: `rings`를 **층(밴드) 배열**로 정규화한다. 옛 도안(8칸 한 겹)은 "층 1개"로 승격돼
	# 예전과 **똑같이** 돈다 — 아래 `_deploy_now`의 층 루프가 층 하나면 옛 분기와 같은 명령을 낸다.
	var layers := _as_layers(rings)
	if layers.is_empty():
		return
	var angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	# 🔴 세81 M2: 발사가 **룬 목록**을 쓴다(융합진). 승격 판별은 core 단일 소스(`runes_of`) — 옛 도안은
	# `rune` 하나에서 `[rune]`로 올라와 예전과 똑같이 돈다(룬 1개 = 세션34 경로와 계산 동일).
	var runes := RingDesign.runes_of(assembly.get("runes", []), int(assembly.get("rune", Enums.RuneType.FIRE)))
	var power := _power_of(assembly)
	# 🔴 특별잉크 화상 증폭 (세션29) — 위력(피해)과 별개 축이라 따로 나른다. 전개는 나중이라
	# 그때 assembly가 없으므로, power처럼 캐리어에 실어 착탄까지 들고 간다.
	var status_mult := Db.status_mult_of(StringName(assembly.get("special_ink", &"")),
		float(assembly.get("special_ratio", 0.0)))

	# 🔴 지팡이 발사 패턴 부활 (세션 42). 옛 소비자(spell_system.wand_shots)는 세션22에 매장됐고
	# 그 뒤로 이 새 경로는 무조건 단발이었다 — GameState.wand_pattern()이 정의만 되고 orphan이었다.
	# 이제 진(캐리어)을 패턴이 정한 각도들로 **여러 개** 쏜다. 착탄 전개는 캐리어당 그대로 돈다.
	# 🔴 발사 형태 = 마법진이 그려진 **진**이 정한다 (세션44, 진=형태). 그전엔 장착 지팡이
	# (wand_pattern)가 쥐었다 — 이제 진이 도안에 저장돼 "이 마법은 이 형태로 나간다"가 도안에 묶인다.
	# 진 없는 옛 도안·매직볼은 폴백(장착 지팡이 또는 단발) — 하위호환.
	var jin_def := Db.get_jin(StringName(assembly.get("jin", &"")))
	var pattern := jin_def.pattern if jin_def != null else GameState.wand_pattern()
	# 🔴 세션48: 진의 **규모**(body_scale)가 그 진의 발사 형태를 키운다 — 발수·진폭·몸집. 진이 없는
	# 매직볼·옛 도안은 1.0(예전과 동일). 사용자 확정: "크면 진마다 있는 발사 형태가 강해지게."
	var scale := jin_def.body_scale if jin_def != null else 1.0
	# 🔴 타겟팅(SEEK)은 조준이 아니라 **적 위치**가 각도를 정하므로 origin이 필요하다.
	for shot: Dictionary in _shot_plan(angle, pattern, scale, origin):
		var delay := float(shot["delay"])
		if delay <= 0.0:
			_spawn_carrier(layers, origin, float(shot["angle"]), power, status_mult, runes, jin_def)
		else:
			# 연발·분사 = 시간차. 타이머가 죽어도 게임이 안 멈추게 캐리어 스폰만 지연한다.
			get_tree().create_timer(delay).timeout.connect(
				_spawn_carrier.bind(layers, origin, float(shot["angle"]),
					power, status_mult, runes, jin_def), CONNECT_ONE_SHOT)


## 🔴 `rings`를 **층 배열**로 정규화한다 (세79 M1) — 저장 도안·옛 호출자 흡수.
## 판별 자체는 **core가 쥔다**(`RingDesign.layers_of`) — 발사·요약(`filled_count`)·HUD가 같은
## 함수를 봐야 갈라지지 않는다. 여기 남긴 건 발사부의 이름일 뿐이고 규칙은 core에 하나다.
static func _as_layers(rings: Array) -> Array:
	return RingDesign.layers_of(rings)


## 진(캐리어) 하나를 origin에서 angle 방향으로 쏜다. 패턴이 여러 각도면 이걸 여러 번 부른다.
## `layers` = 층 배열 — 캐리어는 이걸 **해석하지 않고 착탄까지 나르기만** 한다(payload).
func _spawn_carrier(layers: Array, origin: Vector2, angle: float,
		power: float, status_mult: float, runes: Array, jin_def: JinDef = null) -> void:
	if not is_inside_tree():
		return   # 지연 발사 도중 씬이 바뀌었다 (귀환·사망) — 조용히 접는다
	var carrier := CarrierScene.instantiate() as CarrierScript
	if carrier == null:
		return
	add_child(carrier)
	carrier.global_position = origin
	var fire := _fire_hit(power, status_mult, runes)
	# 🔴 세81 M2: 캐리어도 몸으로 직격할 때 **모든 룬 상태**를 얹어야 한다(rune_hits) — 안 그러면
	# 캐리어가 처음 스친 적만 반응이 안 나고 전개 탄은 나는 갈라짐이 생긴다.
	carrier.setup(layers, angle,
		balance.projectile_base_speed, balance.projectile_lifetime_sec,
		fire.damage, fire.rune_type, fire.status, fire.status_power, fire.get("rune_hits", []))
	# 🔴 경로·규모는 setup **뒤에** 얹는다. 진 없는 도안(매직볼)은 안 부르므로 예전과 픽셀 동일.
	if jin_def != null:
		carrier.set_motion(jin_def.motion, jin_def.body_scale,
			balance.jin_spiral_amplitude_px, balance.jin_spiral_period_sec,
			balance.jin_boomerang_turn_ratio)
	carrier.deployed.connect(_on_carrier_deployed.bind(power, status_mult, runes))


## 발사 계획 — 진의 패턴이 "어디로(angle) 언제(delay)"를 정한다. 수치는 balance.
##
## 🔴 세션48에 반환형이 **각도 배열 → {angle, delay} 사전 배열**로 넓어졌다. 연발·분사가 들어오며
## "몇 발"만으로는 부족해졌기 때문이다 — 시간축이 곧 그 두 진의 정체성이다(산탄과 갈리는 지점).
## 🔴 `scale`(진 규모)은 **발수를 늘린다** — 큰 산탄진 = 갈래가 많다. 각도 하나뿐인 단발·타겟팅은
## 발수가 안 늘고 대신 캐리어 몸집이 커진다(set_motion). "크다"의 의미가 진마다 다른 게 설계다.
func _shot_plan(base: float, pattern: int, scale: float, origin: Vector2) -> Array:
	match pattern:
		Enums.WandPattern.MULTI:
			return _fan(base, _scaled(balance.wand_multi_count, scale),
				balance.wand_multi_spread_deg, 0.0)
		Enums.WandPattern.NOVA:
			var n2 := _scaled(balance.wand_nova_count, scale)
			var out2: Array = []
			for i in n2:
				out2.append({"angle": base + TAU * float(i) / float(n2), "delay": 0.0})
			return out2
		Enums.WandPattern.BURST:
			# 연발 = **같은 각도**로 시간차. 전부 조준선에 맞지만, 적이 움직이면 뒷발이 빗나간다
			# (산탄은 한순간에 퍼지고 연발은 조준을 계속 유지해야 한다 — 손이 다르게 쓰인다).
			var n3 := _scaled(balance.jin_burst_count, scale)
			var out3: Array = []
			for i in n3:
				out3.append({"angle": base, "delay": balance.jin_burst_interval_sec * float(i)})
			return out3
		Enums.WandPattern.SPRAY:
			# 분사 = 좁은 각 + 촘촘한 시간차. 산탄(넓게 한 방)과 연발(한 점 시간차) 사이.
			return _fan(base, _scaled(balance.jin_spray_count, scale),
				balance.jin_spray_spread_deg, balance.jin_spray_interval_sec)
		Enums.WandPattern.SEEK:
			# 타겟팅 = 진이 **가장 가까운 적을 골라** 그리로 간다 (조준 무시).
			# ⚠ 유도 문양(GlyphCode.HOMING)과 층이 다르다: 저건 착탄 후 **탄**이 쫓는 것이고,
			# 이건 **진 자체**가 표적을 정해 날아가는 것이다. 둘은 겹쳐 쓸 수 있다.
			return [{"angle": _nearest_enemy_angle(origin, base), "delay": 0.0}]
		_:
			return [{"angle": base, "delay": 0.0}]


## 부채꼴 n발 — 양 끝 사이 총각이 spread_deg. interval>0이면 순서대로 시간차를 준다(분사).
func _fan(base: float, n: int, spread_deg: float, interval: float) -> Array:
	var out: Array = []
	if n <= 1:
		return [{"angle": base, "delay": 0.0}]
	var spread := deg_to_rad(spread_deg)
	for i in n:
		out.append({
			"angle": base - spread * 0.5 + spread * (float(i) / float(n - 1)),
			"delay": interval * float(i),
		})
	return out


## 규모가 곱해진 발수 — 최소 1발은 보장한다 (작은 진이 아예 안 나가면 버그로 보인다).
func _scaled(count: int, scale: float) -> int:
	return maxi(int(round(float(count) * scale)), 1)


## origin에서 가장 가까운 적 방향. 사거리 안에 아무도 없으면 조준 각도 그대로 (헛발질 방지).
## 그룹 "enemies" = 적 노드 계약 (ring_carrier 상단 주석과 같은 계약).
func _nearest_enemy_angle(origin: Vector2, fallback: float) -> float:
	var best: Node2D = null
	var best_d := balance.jin_seek_radius_px * balance.jin_seek_radius_px
	for e in get_tree().get_nodes_in_group("enemies"):
		var n2d := e as Node2D
		if n2d == null or not n2d.is_inside_tree():
			continue
		var d := origin.distance_squared_to(n2d.global_position)
		if d < best_d:
			best_d = d
			best = n2d
	if best == null:
		return fallback
	return (best.global_position - origin).angle()


## assembly → 위력 배율. 손그림 점수(곡선) × **잉크 등급 배수** × **진 크기**(세션29). 규칙은
## core가 쥔다(리포트·HUD와 같은 값). 점수 없는 옛 도안 = 기준 위력(1.0)에 잉크·크기만 곱한다.
func _power_of(assembly: Dictionary) -> float:
	var ink_mult := Db.ink_mult(StringName(assembly.get("ink", &"")))
	var size := float(assembly.get("size", 1.0))
	if not assembly.has("score"):
		return ink_mult * RingPower.size_mult(size)
	return RingPower.power_of(float(assembly.get("score", 0.0)), ink_mult, size)


## 착탄 = 안의 고리를 편다. 물리 콜백 중일 수 있으니 지연 실행 (Area2D를 콜백 안에서 즉시
## add_child하면 "flushing queries" 에러로 조용히 안 생긴다 — projectile와 같은 함정).
func _on_carrier_deployed(layers: Array, at: Vector2, travel: float, power: float, status_mult: float, runes: Array) -> void:
	call_deferred(&"_deploy_now", layers, at, travel, power, status_mult, runes)


# ─────────────── 🔴 세79 M1: 층 해석기 (안→밖 = 연산 순서) ───────────────
## 착탄 전개 = **층(밴드)을 안쪽부터 바깥쪽으로 훑으며 「전개 명령 목록」을 키워 나간 결과**다.
## (정본 = docs/takbon-design/jin_interpretation_design.md — "룬을 문양이 겹겹이 감싼다, 안→밖 = 연산 순서")
##
## 층 하나를 처리하는 규칙:
##   • **전개형**(발산 계열·응집) = 명령을 **새로 만든다**. 칸 인덱스가 탄 각도를 정한다(세44 계약 그대로).
##   • **변형형**(확산·폭발, `Enums.MODIFIER_GLYPHS`) = 지금까지 쌓인 명령 목록을 **함수처럼 변환한다**.
##     감쌀 게 아직 없으면(=안쪽이 비었으면) **룬 씨앗** 명령 하나를 먼저 깔고 감싼다 — 설계의
##     *"문양이 영향 주는 대상 = 그 문양이 감싸는 안쪽(룬 또는 안쪽 문양 뭉치)"* 그대로다.
##
## 🔴 **회귀 계약**: 층이 하나뿐이고 변형형이 없으면(=세78까지의 모든 도안) 명령 목록이 옛 분기와
## 정확히 같아진다 — 발산 칸마다 탄 1발 + 응집 칸 수만큼 굵은 기둥 1개. 픽셀 동일.
## ⚠ `layers`는 여기서도 **한 번 더 정규화한다**(`_as_layers`는 멱등). 이 함수는 캐리어가 나른
## payload를 그대로 받는 자리라 **옛 8칸 한 겹**으로 부르는 호출자(저장 도안·기존 테스트)가 실재한다 —
## 정규화를 진입점 한쪽에만 두면 그쪽이 `Invalid cast` 로 조용히 죽는다(세23 「테스트가 옛 인자로
## 내부 API를 부른다」 함정을 이번에 그대로 밟았다).
func _deploy_now(rings: Array, at: Vector2, travel: float, power: float, status_mult: float, runes: Array) -> void:
	var fire := _fire_hit(power, status_mult, runes)
	var plan: Array = []
	for layer_v in _as_layers(rings):
		if not (layer_v is Array):
			continue
		plan = _apply_layer(plan, layer_v as Array, travel)
	for cmd: Dictionary in plan:
		_spawn_cmd(cmd, at, fire)


## 층 하나를 명령 목록에 적용한다. 반환 = 갱신된 목록.
## 🔴 **한 층 안에서는 전개형이 먼저 전부 놓이고 그 다음 변형형이 걸린다** — 층이 곧 순서라
## 층 **내부**는 "동시"로 본다. (밴드 하나엔 문양-고리 하나만 끼우므로 실사용에선 섞이지 않지만,
## 섞였을 때의 결과가 **결정적**이어야 저장 도안이 늘 같게 나간다.)
func _apply_layer(plan: Array, layer: Array, travel: float) -> Array:
	if layer.size() < SLOTS:
		# ⚠ 세78까지는 `_on_ring_cast`가 8칸 미만이면 **발사 자체를 접었다**. 층 모델에선 층마다
		# 판정하므로 여기서 건너뛴다 — 마나는 이미 나갔는데 조용히 아무것도 안 나오면 버그로 보인다.
		push_warning("층의 칸 수가 %d(<%d)라 전개를 건너뛴다 — 밴드 데이터 손상 의심" % [layer.size(), SLOTS])
		return plan
	var out := plan
	var gather := 0
	var mod_counts: Dictionary = {}
	for k in SLOTS:
		var g := int(layer[k])
		if g == Enums.GlyphCode.RADIATE or BOLT_EFFECTS.has(g):
			# 🔴 발산 계열 (세션44 관통 → 세션47 확장): 전부 바깥으로 탄을 쏘고, 다른 건 그 탄이
			# **어떻게 나는가**뿐이다 — 세기가 아니라 **전투 방식**이 달라진다. RADIATE는 효과 없는
			# 순수 직진탄. reach는 지금 고정(balance.glyph_reach_max=최대 세기) — 나중에 문양 크기
			# 축과 이을 자리다.
			var effects: Dictionary = {}
			if BOLT_EFFECTS.has(g):
				effects[BOLT_EFFECTS[g]] = balance.glyph_reach_max
			out.append(_bolt_cmd(travel + TAU * float(k) / float(SLOTS), effects))
		elif g == Enums.GlyphCode.GATHER:
			gather += 1
		elif Enums.is_modifier_glyph(g):
			mod_counts[g] = int(mod_counts.get(g, 0)) + 1
	if gather > 0:
		out.append(_pillar_cmd(gather))
	# 🔴 변형형 적용 순서 = `Enums.MODIFIER_GLYPHS` 순서 고정(사전 키 순서에 기대지 않는다 —
	# 그러면 같은 도안이 실행마다 다르게 나갈 수 있다).
	for code in Enums.MODIFIER_GLYPHS:
		if mod_counts.has(code):
			out = _apply_modifier(int(code), int(mod_counts[code]), out, travel)
	return _capped(out)


## 🔴 명령 수 상한 (세79 I4) — 확산은 **곱셈**이라 층이 깊어지면 명령이 폭증한다(수백 발).
## 넘치면 **조용히 자르지 않는다** — 경고를 남긴다(세58 「silent cap」 금기: 말없이 자르면
## "다 나갔다"로 읽힌다). 상한에 걸린다는 건 대개 밸런스가 아니라 설계가 샌 것이다.
func _capped(plan: Array) -> Array:
	if plan.size() <= balance.max_deploy_cmds:
		return plan
	push_warning("착탄 전개 명령이 %d개라 상한 %d로 자른다 (층·확산 조합이 곱셈으로 터졌다)"
		% [plan.size(), balance.max_deploy_cmds])
	return plan.slice(0, balance.max_deploy_cmds)


## 변형형 문양 하나가 안쪽 명령 목록을 감싼다. **새 변형형 = 여기 분기 하나**(+ GlyphCode 값 +
## `Enums.MODIFIER_GLYPHS` 한 줄). `count` = 그 층에서 이 문양이 차지한 칸 수 = **세기**
## (응집의 "많을수록 굵다"와 같은 결 — 많이 그릴수록 세다).
func _apply_modifier(code: int, count: int, plan: Array, travel: float) -> Array:
	var inner := plan
	if inner.is_empty():
		# 감쌀 게 없다 = 이 문양이 **룬 자체**를 감싼다. 씨앗 = 조준 방향 탄 1발(그 원소 그대로).
		inner = [_bolt_cmd(travel, {})]
	match code:
		Enums.GlyphCode.SPREAD:
			return _spread(inner, count)
		Enums.GlyphCode.EXPLODE:
			return _explode(inner, count)
	# 🔴 `MODIFIER_GLYPHS`에 값만 넣고 여기 분기를 빠뜨린 경우 — `inner`엔 이미 **씨앗 탄 1발이
	# 주입돼 있을 수 있어**, 그대로 돌려주면 **없던 탄 1발이 조용히 는다**. 씨앗을 되돌린다.
	push_warning("변형형 문양 %d에 _apply_modifier 분기가 없다 — 아무 일도 안 한다" % code)
	return plan


## **확산 = 복제 산개** (사용자 확정 세79). 안쪽 각 갈래를 n개로 복제해 부채꼴로 벌린다.
## 탄은 **각도**가 벌어지고, 제자리 명령(기둥·폭발)은 착탄점 둘레로 **위치**가 벌어진다.
## 갈래마다 세기는 줄지만(balance) 합은 늘어난다 — 안 그러면 그릴 이유가 없다.
func _spread(inner: Array, count: int) -> Array:
	var n := maxi(count, 2)     # 1갈래는 확산이 아니다 — 최소 2갈래
	var spread := deg_to_rad(balance.spread_fan_deg)
	var out: Array = []
	for cmd: Dictionary in inner:
		for i in n:
			var t := float(i) / float(n - 1) - 0.5   # -0.5 … +0.5 (n은 위에서 ≥2라 0나눗셈 없다)
			var c := cmd.duplicate(true)
			c["mult"] = float(cmd.get("mult", 1.0)) * balance.spread_branch_mult
			if c["kind"] == &"bolt":
				c["angle"] = float(cmd.get("angle", 0.0)) + spread * t
			else:
				# 제자리 명령은 각도가 없다 — 착탄점 둘레로 흩는다(같은 자리에 겹치면 한 발과 같다).
				var a := TAU * float(i) / float(n)
				c["offset"] = Vector2(cmd.get("offset", Vector2.ZERO)) \
					+ Vector2.from_angle(a) * balance.spread_offset_px
			out.append(c)
	return out


## **폭발 = 융합 광역** (사용자 확정 세79). 안쪽 결과를 **통째로 하나의 광역 폭발로 합친다**.
## 🔴 반경이 **안쪽이 얼마나 퍼져 있었나**(갈래 수)에 비례하는 게 순서 실증의 핵심이다:
##   `폭발(확산(불))` = 3갈래를 융합 → **큰** 폭발 하나 (넓은 지역 광역 한 방)
##   `확산(폭발(불))` = 씨앗 1개를 융합 → 작은 폭발, 그 뒤 확산이 3개로 복제 → 작은 폭발 다발
## 폭발이 "각 갈래를 각각 터뜨림"이면 두 순서가 같아져 순서가 안 보인다 — 그래서 **융합**이다.
func _explode(inner: Array, count: int) -> Array:
	var branches := maxi(inner.size(), 1)
	var total := 0.0
	var center := Vector2.ZERO
	for cmd: Dictionary in inner:
		total += float(cmd.get("mult", 1.0))
		center += Vector2(cmd.get("offset", Vector2.ZERO))
	center /= float(branches)
	var radius := balance.blast_base_radius_px \
		* (1.0 + balance.blast_radius_per_branch * float(branches - 1)) \
		* (1.0 + balance.blast_radius_per_count * float(maxi(count, 1) - 1))
	return [{
		"kind": &"blast",
		"offset": center,
		"mult": total * balance.blast_merge_mult,
		"radius": radius,
	}]


func _bolt_cmd(angle: float, effects: Dictionary) -> Dictionary:
	return {"kind": &"bolt", "angle": angle, "offset": Vector2.ZERO,
		"effects": effects, "mult": 1.0}


func _pillar_cmd(gather: int) -> Dictionary:
	return {"kind": &"pillar", "offset": Vector2.ZERO, "gather": gather, "mult": 1.0}


## 명령 하나를 실제 노드로 스폰한다. `mult` = 그 갈래의 세기 배율 — 피해에 곱한다.
func _spawn_cmd(cmd: Dictionary, at: Vector2, fire: Dictionary) -> void:
	var mult := float(cmd.get("mult", 1.0))
	var pos := at + Vector2(cmd.get("offset", Vector2.ZERO))
	var hit := fire.duplicate()
	hit["damage"] = float(fire.get("damage", 0.0)) * mult
	match StringName(cmd.get("kind", &"bolt")):
		&"bolt":
			_spawn_bolt(pos, float(cmd.get("angle", 0.0)), hit,
				cmd.get("effects", {}) as Dictionary)
		&"pillar":
			_spawn_pillar(pos, int(cmd.get("gather", 1)), hit)
		&"blast":
			_spawn_blast(pos, float(cmd.get("radius", balance.blast_base_radius_px)), hit)


## 발산 = 순수 직진 탄환. effects={}로 쓰면 팅김·유도·관통 없이 곧게 날아가 적에 닿으면 소멸한다.
##
## 🔴 세션 22 (M2): 탄 씬을 **룬 데이터가 정한다** — 예전엔 `preload(projectile.tscn)`로 박아 놔서
## `RuneDef.projectile_scene`을 읽는 코드가 죽은 spell_system뿐이었다. 결합 비용만 내고 이득이 0이었고,
## *"새 룬 = .tres 한 장"*(jin_def.gd:6)이라는 이 프로젝트의 약속이 새 경로에서 깨져 있었다.
## 이제 물·바람 룬 추가가 진짜로 .tres 한 장이다.
## 🔴 effects (세션44) = 탄 행동 효과 사전 {GlyphType: reach} — 관통·팅김·유도 등. 기본 {}면 순수
## 직진탄(발산). projectile._setup_effects가 이 사전을 읽어 이미 있는 기계를 켠다(그전엔 늘 {}라 DARK).
func _spawn_bolt(at: Vector2, angle: float, fire: Dictionary, effects: Dictionary = {}) -> void:
	var scene := fire.get("scene") as PackedScene
	if scene == null:
		push_warning("룬에 projectile_scene이 없다 — 발산 탄을 못 쏜다 (data/runes/*.tres 확인)")
		return
	var bolt := scene.instantiate() as BoltScript
	if bolt == null:
		return
	add_child(bolt)
	bolt.global_position = at
	bolt.setup(fire.damage, fire.rune_type, fire.status, fire.status_power,
		balance.projectile_base_speed, angle, effects, balance.projectile_lifetime_sec,
		fire.get("rune_hits", []))


## 응집 = 착탄점에 불기둥 하나. 응집 칸이 많을수록 굵다 (node scale).
func _spawn_pillar(at: Vector2, gather: int, fire: Dictionary) -> void:
	var pillar := PillarScene.instantiate() as PillarScript
	if pillar == null:
		return
	add_child(pillar)
	pillar.global_position = at
	pillar.scale = Vector2.ONE * (1.0 + PILLAR_SCALE_PER_GATHER * float(gather - 1))
	pillar.setup(fire.damage, fire.rune_type, fire.status, fire.status_power,
		fire.get("rune_hits", []))


## 🔴 폭발 = 착탄점 광역 1회 타격 (세79 M1 변형형 문양 EXPLODE의 결과물).
## 반경은 **호출자가 계산해 넘긴다** — "안쪽이 얼마나 퍼져 있었나"가 반경을 정하는 게 순서 실증의
## 핵심이라, 노드가 아니라 `_explode`가 그 규칙을 쥔다(blast.gd에는 밸런스 수치가 하나도 없다).
## ⚠ 위치 대입은 **add_child 뒤에** (세58 함정 ① — 앞에 두면 부모 변환이 덮어 조용히 어긋난다).
func _spawn_blast(at: Vector2, radius: float, fire: Dictionary) -> void:
	var blast := BlastScene.instantiate() as BlastScript
	if blast == null:
		return
	add_child(blast)
	blast.global_position = at
	blast.setup(fire.damage, fire.rune_type, fire.status, fire.status_power, radius,
		fire.get("rune_hits", []))


## 룬 히트 정보 — Db에서 **고른 룬** RuneDef를 읽어 피해·상태·세기 + **탄 씬**을 뽑는다 (세션 34).
## 등록이 없으면 기본 피해(balance)로 폴백하되 scene은 null (탄은 못 쏜다 — _spawn_bolt가 경고).
##
## 🔴 `power` = 손그림·잉크·크기가 정한 위력 배율 → **피해에** 곱한다 (세션 23·29).
## 🔴 `status_mult` = 특별잉크 화상 증폭 (세션29) → **상태이상 세기에만** 곱한다. 피해(power)와
## 상태(status_mult)는 **다른 축**이다 — 잉크 등급=피해, 특별잉크=상태. 섞으면 축이 겹친다.
## ⚠ **거짓 주석 정정**(세50): 전엔 여기에 *"룬 농도 세기가 조립 단계에서 status_power에 이미
## 반영돼 들어온다"*고 적혀 있었는데 **사실이 아니다.** 아래 `rune`은 `Db.get_rune()`으로 갓 꺼낸
## RuneDef라 조립 결과가 아니고, `balance`의 `rune_density_min/max`·`rune_fill`은 **소비자가 0곳**이다.
## 즉 "진 안에 룬을 얼마나 크게 그렸나"가 아무 데도 안 쓰인다 = **그리는 재미 축 하나가 죽어 있다**
## (세50 빚① `status_power`와 정확히 같은 병 — 살릴지 접을지는 다음 세션 결정).
## 🔴 세81 M2: `runes` = 이 발사가 실은 룬 목록(융합진). 룬 1개면 예전과 **계산 완전 동일**
## (share 1.0 · rune_hits=[primary] 하나라 projectile 루프가 primary를 건너뛰어 부작용 0).
## 반환 = primary 히트 정보 + `rune_hits`(전 룬 상태, 자리 순서 = 반응 순서로 정렬됨).
## 🔴 **총 직격 = 각 룬 피해의 합**을 primary가 진다(사용자 확정: 둘 다 0.7씩, 합 1.4). 보조 룬은
## 0-피해 상태 히트로 나가고, 도배는 적 계약의 0-피해 가드가 막는다(세81).
func _fire_hit(power: float = 1.0, status_mult: float = 1.0,
		runes: Array = []) -> Dictionary:
	var rlist: Array = runes if not runes.is_empty() else [Enums.RuneType.FIRE]
	# 🔴 세기 배분 — 2룬+면 각 룬에 multi_rune_share(0.7)를 곱해 합산(합 1.4). 1룬은 1.0(무회귀).
	var share := balance.multi_rune_share if rlist.size() > 1 else 1.0
	var entries: Array = []
	var total_damage := 0.0
	var scene: PackedScene = null
	for rt in rlist:
		var rune: RuneDef = Db.get_rune(int(rt))
		var base_dmg := rune.base_damage if rune != null else 1.0
		total_damage += balance.projectile_base_damage * base_dmg * power * share
		entries.append({
			"rune": int(rt),
			"status": rune.status if rune != null else Enums.Status.NONE,
			"status_power": (rune.status_power * status_mult) if rune != null else 0.0,
			"scene": rune.projectile_scene if rune != null else null,
		})
	# 🔴 반응이 나는 순서로 정렬 — 자리 순서와 무관하게 물+번개가 늘 감전이 되게(status_rules 단일 소스).
	entries = StatusRules.order_for_reaction(entries)
	var primary: Dictionary = entries[0]
	scene = primary["scene"]
	var rune_hits: Array = []
	for e: Dictionary in entries:
		rune_hits.append({"rune_type": int(e["rune"]), "status": int(e["status"]),
			"status_power": float(e["status_power"])})
	return {"damage": total_damage, "rune_type": int(primary["rune"]),
		"status": int(primary["status"]), "status_power": float(primary["status_power"]),
		"scene": scene, "rune_hits": rune_hits}
