extends Node2D
## 고리 조립 발사 시스템 — **유일한 발사 경로**. 필드 씬에 자식으로 넣기만 하면 되는 자립 노드.
## EventBus.ring_cast_requested 수신 → 진(캐리어)을 조준 방향으로 쏜다.
##
## 발사 모델: 진이 통째로 날아가고(ring_carrier), 적에 닿는 그 자리에서 안의 고리가 전개된다
## (발산→ 칸 = 그 방향 탄환 · 응집← 칸 = 모여서 기둥 하나, 많을수록 굵다).
##
## 🔴 마나 판정은 **여기가 아니라 `player_caster.fire()`**가 한다 — 여기에 또 넣으면 이중 과금이 되고,
## 마나 없이 직접 emit하는 테스트가 통째로 막힌다.

const RingPower := preload("res://src/core/ring_power.gd")
const StatusRules := preload("res://src/core/status_rules.gd")   # 융합 룬 반응 순서 정렬
const GlyphRules := preload("res://src/core/glyph_rules.gd")     # 문양 알고리즘·수치 표
const CarrierScene := preload("res://src/spell/ring_carrier.tscn")
const CarrierScript := preload("res://src/spell/ring_carrier.gd")
const BoltScript := preload("res://src/spell/projectile.gd")
const PillarScene := preload("res://src/spell/pillar.tscn")
const PillarScript := preload("res://src/spell/pillar.gd")
const BlastScene := preload("res://src/spell/blast.tscn")
const BlastScript := preload("res://src/spell/blast.gd")

const SLOTS := 8

## 응집 굵기 — 기둥 하나당 scale 증가분 (연출값, 밸런스 아님).
const PILLAR_SCALE_PER_GATHER := 0.22

## 🔴 code→효과 매핑 상수를 여기 되살리지 마라 — 문양 데이터가 자기 효과를 들고 온다
## (`GlyphDef.params.effect` → `GlyphRules.bolt_effects`). 여기 박으면 소스가 둘이 된다.

var balance: BalanceData = preload("res://data/balance.tres")


func _ready() -> void:
	EventBus.ring_cast_requested.connect(_on_ring_cast)


## 🔴 「펑」 판정은 **여기가 아니라 조립대**의 몫이다 — 터진 마법진은 발사까지 오지 않는다.
func _on_ring_cast(assembly: Dictionary, origin: Vector2, aim_dir: Vector2) -> void:
	var rings: Array = assembly.get("rings", [])
	if rings.is_empty():
		return
	var layers := _as_layers(rings)
	if layers.is_empty():
		return
	var angle := aim_dir.angle() if aim_dir.length_squared() > 0.0 else 0.0
	# 🔴 룬은 **복수**다 — 승격 판별을 여기서 하지 말고 `runes_of`를 거쳐야 두 번째 룬이 안 사라진다.
	var runes := RingDesign.runes_of(assembly.get("runes", []), int(assembly.get("rune", Enums.RuneType.FIRE)))
	var power := _power_of(assembly)
	# 특별잉크 상태 증폭 — 위력(피해)과 **다른 축**이라 따로 나른다.
	var status_mult := Db.status_mult_of(StringName(assembly.get("special_ink", &"")),
		float(assembly.get("special_ratio", 0.0)))
	# 🔴 점수를 착탄까지 나른다 — 전개는 나중이라 그때 assembly가 없다(power·status_mult와 같은 길).
	# ⚠ 점수 없는 옛 도안 = 0.0 → 무난한 진과 같은 연출. 여기서 기본 점수를 지어내지 마라.
	var score := float(assembly.get("score", 0.0))

	# 🔴 발사 형태는 **진**이 정한다 — 지팡이는 세기·속도 스칼라만 준다(형태 폴백을 되살리면 두 축이 겹친다).
	var jin_def := Db.get_jin(StringName(assembly.get("jin", &"")))
	var pattern := jin_def.pattern if jin_def != null else Enums.WandPattern.SINGLE
	# 진의 규모가 그 진의 발사 형태를 키운다 — 발수·진폭·몸집.
	var scale := jin_def.body_scale if jin_def != null else 1.0
	# 타겟팅(SEEK)은 조준이 아니라 **적 위치**가 각도를 정하므로 origin이 필요하다.
	for shot: Dictionary in _shot_plan(angle, pattern, scale, origin):
		var delay := float(shot["delay"])
		if delay <= 0.0:
			_spawn_carrier(layers, origin, float(shot["angle"]), power, status_mult, score, runes, jin_def)
		else:
			# 연발·분사 = 시간차. 타이머가 죽어도 게임이 안 멈추게 캐리어 스폰만 지연한다.
			get_tree().create_timer(delay).timeout.connect(
				_spawn_carrier.bind(layers, origin, float(shot["angle"]),
					power, status_mult, score, runes, jin_def), CONNECT_ONE_SHOT)


## `rings`를 층 배열로 정규화한다 — 🔴 규칙은 **core가 쥔다**(`RingDesign.layers_of`).
## 발사·요약·HUD가 같은 함수를 봐야 갈라지지 않는다.
static func _as_layers(rings: Array) -> Array:
	return RingDesign.layers_of(rings)


## 진(캐리어) 하나를 origin에서 angle 방향으로 쏜다. 패턴이 여러 각도면 이걸 여러 번 부른다.
## `layers` = 층 배열 — 캐리어는 이걸 **해석하지 않고 착탄까지 나르기만** 한다(payload).
func _spawn_carrier(layers: Array, origin: Vector2, angle: float,
		power: float, status_mult: float, score: float, runes: Array, jin_def: JinDef = null) -> void:
	if not is_inside_tree():
		return   # 지연 발사 도중 씬이 바뀌었다 (귀환·사망) — 조용히 접는다
	var carrier := CarrierScene.instantiate() as CarrierScript
	if carrier == null:
		return
	add_child(carrier)
	carrier.global_position = origin
	var fire := _fire_hit(power, status_mult, runes)
	# 🔴 캐리어 직격도 `rune_hits`로 **모든 룬 상태**를 얹는다 — 안 그러면 캐리어가 처음 스친 적만
	# 반응이 안 나고 전개 탄은 나는 갈라짐이 생긴다.
	# 지팡이는 속도만 올린다(수명 불변) — 사거리도 같이 늘어 "빠른 지팡이"가 한 축으로 읽힌다.
	carrier.setup(layers, angle,
		balance.projectile_base_speed * GameState.wand_speed_mult(), balance.projectile_lifetime_sec,
		fire.damage, fire.rune_type, fire.status, fire.status_power, fire.get("rune_hits", []), score)
	# 🔴 경로·규모는 setup **뒤에** 얹는다.
	if jin_def != null:
		carrier.set_motion(jin_def.motion, jin_def.body_scale,
			balance.jin_spiral_amplitude_px, balance.jin_spiral_period_sec,
			balance.jin_boomerang_turn_ratio)
	carrier.deployed.connect(_on_carrier_deployed.bind(power, status_mult, score, runes))


## 발사 계획 — 진의 패턴이 "어디로(angle) 언제(delay)"를 정한다. 수치는 balance.
## 🔴 `scale`(진 규모)은 **발수를 늘린다**. 각도 하나뿐인 단발·타겟팅은 발수 대신 캐리어 몸집이
## 커진다(set_motion) — "크다"의 의미가 진마다 다른 게 설계다.
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
			# 연발 = **같은 각도**로 시간차 — 적이 움직이면 뒷발이 빗나간다(산탄과 갈리는 지점).
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
			# 타겟팅 = 진이 가장 가까운 적을 골라 그리로 간다(조준 무시).
			# ⚠ 유도 문양과 층이 다르다 — 저건 착탄 후 **탄**이 쫓고 이건 **진**이 표적을 정한다.
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


## assembly → 위력 배율. 🔴 곡선·기준선은 **core(`RingPower`)가 쥔다** — 여기 베끼면 리포트·HUD와 갈라진다.
## 점수 없는 옛 도안 = 기준 위력(1.0)에 잉크·크기만 곱한다.
func _power_of(assembly: Dictionary) -> float:
	var ink_mult := Db.ink_mult(StringName(assembly.get("ink", &"")))
	var size := float(assembly.get("size", 1.0))
	if not assembly.has("score"):
		return ink_mult * RingPower.size_mult(size)
	return RingPower.power_of(float(assembly.get("score", 0.0)), ink_mult, size)


## 🔴 물리 콜백 중일 수 있으니 지연 실행 — 콜백 안에서 Area2D를 즉시 add_child하면
## "flushing queries" 에러로 **조용히 안 생긴다**.
func _on_carrier_deployed(layers: Array, at: Vector2, travel: float, power: float, status_mult: float, score: float, runes: Array) -> void:
	call_deferred(&"_deploy_now", layers, at, travel, power, status_mult, runes, score)


# ─────────────── 층 해석기 (안→밖 = 연산 순서) ───────────────
## 착탄 전개 = 층(밴드)을 **안쪽부터 바깥쪽으로** 훑으며 전개 명령 목록을 키워 나간 결과다.
##   • 전개형(발산·응집) = 명령을 **새로 만든다**. 칸 인덱스가 탄 각도를 정한다.
##   • 변형형(확산·폭발·응축) = 쌓인 명령 목록을 **함수처럼 변환한다**. 감쌀 게 없으면 룬 씨앗
##     명령 하나를 먼저 깔고 감싼다 — "문양이 감싸는 안쪽"이 그 문양의 대상이기 때문이다.
##
## ⚠ `layers`는 여기서도 **한 번 더 정규화한다**(멱등). 옛 8칸 한 겹으로 부르는 호출자가 실재해서,
## 정규화를 진입점 한쪽에만 두면 그쪽이 `Invalid cast`로 조용히 죽는다.
## 🔴 `score`가 **맨 끝의 기본 인자**인 건 의도다 — 헤드리스 테스트가 이 내부 API를 직접 부른다.
## 인자를 가운데 끼우면 그 호출들이 한꺼번에 `Invalid call`로 죽는다.
func _deploy_now(rings: Array, at: Vector2, travel: float, power: float, status_mult: float,
		runes: Array, score: float = 0.0) -> void:
	var fire := _fire_hit(power, status_mult, runes)
	# 🔴 점수는 룬의 성질이 아니라 도안의 성질이라 `_fire_hit`이 아니라 여기서 얹는다.
	# `_spawn_cmd`가 `fire.duplicate()`로 갈래마다 복사하므로 그대로 실려 간다.
	fire["score"] = score
	var plan: Array = []
	for layer_v in _as_layers(rings):
		if not (layer_v is Array):
			continue
		plan = _apply_layer(plan, layer_v as Array, travel)
	for cmd: Dictionary in plan:
		_spawn_cmd(cmd, at, fire)


## 층 하나를 명령 목록에 적용한다. 반환 = 갱신된 목록.
## 🔴 한 층 안에서는 전개형이 먼저 전부 놓이고 그 다음 변형형이 걸린다 — 층 **내부**는 "동시"라
## 배치와 무관하게 **결정적**이어야 저장 도안이 늘 같게 나간다.
func _apply_layer(plan: Array, layer: Array, travel: float) -> Array:
	if layer.size() < SLOTS:
		# 마나는 이미 나갔는데 조용히 아무것도 안 나오면 버그로 보인다 — 경고는 남긴다.
		push_warning("층의 칸 수가 %d(<%d)라 전개를 건너뛴다 — 밴드 데이터 손상 의심" % [layer.size(), SLOTS])
		return plan
	var out := plan
	var gather := 0
	var mod_counts: Dictionary = {}
	for k in SLOTS:
		var g := int(layer[k])
		# 🔴 빈 칸은 **음수로 판정한다** — `RingAssembly`(drawing의 class_name)를 여기서 참조하면
		#   모듈 경계를 넘는 데다, `-s` 테스트가 전역 클래스 캐시 갱신 전에 컴파일해
		#   **이 파일 전체가 파싱 실패한다**. 문양 code는 늘 0 이상이라 이게 안전한 계약이다.
		# ⚠ 빈 칸에 경고를 달지 마라 — 가장 흔한 값이라 발사 1회에 수십 줄이 쏟아져 진짜 경고가 묻힌다.
		if g < 0:
			continue
		var def := Db.glyph_by_code(g)
		var behavior := def.behavior if def != null else &""
		if not GlyphRules.is_known(behavior):
			# 🔴 데이터 없는 code에 코드가 기본표를 대주면 소스가 둘이 된다 — 경고 + 건너뜀이 규약이다.
			push_warning("문양 code %d에 GlyphDef/behavior가 없다 — 그 칸을 건너뛴다 (data/glyphs 확인)" % g)
			continue
		match behavior:
			&"bolt":
				# 🔴 이 폴백은 **살아 있다** — bolt의 reach 기본값 단일 소스가 balance다
				# (`_glyph_param`으로 바꾸지 마라).
				var reach := GlyphRules.param_f(def, &"reach", balance.glyph_reach_max)
				out.append(_bolt_cmd(travel + TAU * float(k) / float(SLOTS),
					GlyphRules.bolt_effects(def, reach)))
			&"pillar":
				gather += 1
			_:
				if GlyphRules.is_modifier_behavior(behavior):
					mod_counts[g] = int(mod_counts.get(g, 0)) + 1
	if gather > 0:
		out.append(_pillar_cmd(gather))
	# 🔴 변형형 적용 순서 = **code 오름차순 고정** — 같은 층에서 어느 칸에 놨느냐가 결과를 바꾸면 안 된다.
	for code in Db.modifier_codes():
		if mod_counts.has(code):
			out = _apply_modifier(int(code), int(mod_counts[code]), out, travel)
	return _capped(out)


## 🔴 명령 수 상한 — 확산은 **곱셈**이라 층이 깊어지면 명령이 수백 발로 폭증한다.
## 넘쳐도 **조용히 자르지 않는다** — 말없이 자르면 "다 나갔다"로 읽힌다.
func _capped(plan: Array) -> Array:
	if plan.size() <= balance.max_deploy_cmds:
		return plan
	push_warning("착탄 전개 명령이 %d개라 상한 %d로 자른다 (층·확산 조합이 곱셈으로 터졌다)"
		% [plan.size(), balance.max_deploy_cmds])
	return plan.slice(0, balance.max_deploy_cmds)


## 변형형 문양 하나가 안쪽 명령 목록을 감싼다. **새 변형형 = 여기 분기 하나**(+ GlyphCode 값 +
## `GlyphRules.BEHAVIORS` 한 줄). `count` = 그 층에서 이 문양이 차지한 칸 수 = 세기.
## 🔴 분기는 **문양 개수가 아니라 알고리즘 개수**만큼만 는다 — 수치만 다른 문양은 `.tres` 한 장이다.
func _apply_modifier(code: int, count: int, plan: Array, travel: float) -> Array:
	var inner := plan
	if inner.is_empty():
		# 감쌀 게 없다 = 이 문양이 **룬 자체**를 감싼다. 씨앗 = 조준 방향 탄 1발.
		inner = [_bolt_cmd(travel, {})]
	var def := Db.glyph_by_code(code)
	match def.behavior if def != null else &"":
		&"spread":
			return _spread(inner, count, def)
		&"blast":
			return _explode(inner, count, def)
	# 🔴 `inner`가 아니라 `plan`을 돌려준다 — 위에서 씨앗 탄을 깔았을 수 있어,
	# inner를 그대로 내보내면 **없던 탄 1발이 조용히 는다**.
	push_warning("변형형 문양 %d에 _apply_modifier 분기가 없다 — 아무 일도 안 한다" % code)
	return plan


## 🔴 변형형 수치 조회 — **`GlyphRules.DEFAULTS`의 값을 폴백 인자로 베끼지 마라.** 그 리터럴은
## 절대 안 쓰이면서(`.tres`가 늘 이긴다) 읽는 사람에겐 **거짓 손잡이**가 된다 — 고쳐도 아무 일도 안 난다.
## 값이 없다는 건 데이터 결손이므로 그럴듯한 값을 지어내지 않고 경고한다.
func _glyph_param(def: GlyphDef, key: StringName) -> float:
	var v: Variant = GlyphRules.param(def, key, null)
	if v == null:
		push_warning("문양(behavior=%s)의 `%s` 기본값이 GlyphRules.DEFAULTS에 없다 — 0으로 본다"
			% [def.behavior if def != null else &"<null>", key])
		return 0.0
	return float(v)


## **확산 = 복제 산개.** 안쪽 각 갈래를 n개로 복제해 부채꼴로 벌린다.
## 탄은 **각도**가, 제자리 명령(기둥·폭발)은 착탄점 둘레로 **위치**가 벌어진다.
## 갈래마다 세기는 줄지만 합은 늘어난다 — 안 그러면 그릴 이유가 없다.
## 🔴 수치는 balance 전역이 아니라 **그 문양의 `params`**에서 온다 — 같은 알고리즘에 다른 수치를
## 준 `.tres` 한 장이 곧 새 문양이다.
func _spread(inner: Array, count: int, def: GlyphDef) -> Array:
	var min_branches := int(_glyph_param(def, &"min_branches"))
	var n := maxi(count, maxi(min_branches, 2))   # 1갈래는 확산이 아니다 — 최소 2갈래
	var spread := deg_to_rad(_glyph_param(def, &"fan_deg"))
	var branch_mult := _glyph_param(def, &"branch_mult")
	var offset_px := _glyph_param(def, &"offset_px")
	var out: Array = []
	for cmd: Dictionary in inner:
		for i in n:
			var t := float(i) / float(n - 1) - 0.5   # -0.5 … +0.5 (n은 위에서 ≥2라 0나눗셈 없다)
			var c := cmd.duplicate(true)
			c["mult"] = float(cmd.get("mult", 1.0)) * branch_mult
			if c["kind"] == &"bolt":
				c["angle"] = float(cmd.get("angle", 0.0)) + spread * t
			else:
				# 제자리 명령은 각도가 없다 — 겹치면 한 발과 같아지므로 착탄점 둘레로 흩는다.
				var a := TAU * float(i) / float(n)
				c["offset"] = Vector2(cmd.get("offset", Vector2.ZERO)) \
					+ Vector2.from_angle(a) * offset_px
			out.append(c)
	return out


## **폭발 = 융합 광역.** 안쪽 결과를 통째로 하나의 폭발로 합친다.
## 🔴 반경이 **안쪽이 얼마나 퍼져 있었나**(갈래 수)에 비례하는 게 순서 실증의 핵심이다 —
## "각 갈래를 각각 터뜨림"으로 바꾸면 `폭발(확산)`과 `확산(폭발)`이 같아져 순서가 안 보인다.
## 응축도 이 알고리즘을 그대로 쓴다(반경 계수 음수 + 융합 배율 1.0 초과인 `.tres` 한 장).
##
## 🔴 **각 인자를 먼저 0으로 클램프한다** — 응축은 두 계수가 둘 다 음수라, 안 하면 곱이
## **양수로 되살아나** 갈래가 많을수록 반경이 거꾸로 커진다.
## ⚠ 바닥이 둘인 건 의도다 — `blast.gd`의 `maxf(p_radius_px, 1.0)`은 노드의 안전 바닥,
## `min_radius_px`는 게임 규칙이다. 하나를 지우지 마라.
func _explode(inner: Array, count: int, def: GlyphDef) -> Array:
	var branches := maxi(inner.size(), 1)
	var total := 0.0
	var center := Vector2.ZERO
	for cmd: Dictionary in inner:
		total += float(cmd.get("mult", 1.0))
		center += Vector2(cmd.get("offset", Vector2.ZERO))
	center /= float(branches)
	var n := maxi(count, 1)
	var radius := _glyph_param(def, &"base_radius_px") \
		* maxf(1.0 + _glyph_param(def, &"radius_per_branch") * float(branches - 1), 0.0) \
		* maxf(1.0 + _glyph_param(def, &"radius_per_count") * float(n - 1), 0.0)
	radius = maxf(radius, _glyph_param(def, &"min_radius_px"))
	var merge := _glyph_param(def, &"merge_mult") \
		+ _glyph_param(def, &"merge_mult_per_count") * float(n - 1)
	return [{
		"kind": &"blast",
		"offset": center,
		"mult": total * merge,
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
			# 🔴 반경은 **호출자(`_explode`)가 계산해 넘긴다** — 여기서 기본값을 보충하면
			# 수치 소스가 하나 더 생기고, 「반경이 순서를 폭로한다」는 계약이 조용히 거짓이 된다.
			var radius := float(cmd.get("radius", 0.0))
			if radius <= 0.0:
				push_warning("blast 명령에 radius가 없다 — 그 폭발을 건너뛴다 (_explode 경로 확인)")
				return
			_spawn_blast(pos, radius, hit)


## 발산 = 순수 직진 탄환. effects={}면 팅김·유도·관통 없이 곧게 날아간다.
## 🔴 탄 씬은 **룬 데이터가 정한다**(`RuneDef.projectile_scene`) — 여기 preload로 박으면
## "새 룬 = .tres 한 장"이 깨진다.
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
		fire.get("rune_hits", []), float(fire.get("score", 0.0)))


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


## 폭발 = 착탄점 광역 1회 타격. 반경 규칙은 노드가 아니라 `_explode`가 쥔다.
## ⚠ 위치 대입은 **add_child 뒤에** — 앞에 두면 부모 변환이 덮어 조용히 어긋난다.
func _spawn_blast(at: Vector2, radius: float, fire: Dictionary) -> void:
	var blast := BlastScene.instantiate() as BlastScript
	if blast == null:
		return
	add_child(blast)
	blast.global_position = at
	blast.setup(fire.damage, fire.rune_type, fire.status, fire.status_power, radius,
		fire.get("rune_hits", []))


## 룬 히트 정보 — RuneDef에서 피해·상태·세기 + **탄 씬**을 뽑는다.
## 등록이 없으면 기본 피해로 폴백하되 scene은 null (탄은 못 쏜다 — _spawn_bolt가 경고).
##
## 🔴 `power`(잉크 등급·크기)는 **피해에**, `status_mult`(특별잉크)는 **상태 세기에만** 곱한다 —
## 섞으면 두 축이 겹친다.
## 🔴 `runes`는 **목록**이다 — 총 직격은 각 룬 피해의 합을 primary가 지고, 보조 룬은 0-피해
## 상태 히트로 나간다. 반환의 `rune_hits`는 **반응 순서로 정렬**돼 있다.
## ⚠ `balance`의 `rune_density_min/max`·`rune_fill`은 소비자가 없다 — "룬을 얼마나 크게 그렸나"가
##   아무 데도 안 쓰이는 빚이다(여기서 status_power에 반영된다고 믿지 마라).
func _fire_hit(power: float = 1.0, status_mult: float = 1.0,
		runes: Array = []) -> Dictionary:
	var rlist: Array = runes if not runes.is_empty() else [Enums.RuneType.FIRE]
	# 세기 배분 — 2룬 이상이면 룬마다 share를 곱해 합산한다(1룬은 1.0).
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
	# 🔴 반응 순서로 정렬 — 자리 순서와 무관하게 물+번개가 늘 감전이 되어야 한다(규칙은 status_rules).
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
