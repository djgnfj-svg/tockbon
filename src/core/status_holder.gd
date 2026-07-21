extends RefCounted
## 🔴 상태이상 **보유고**(세션50 신설). class_name 없음 — `const SH := preload(...)`.
##
## 왜 core에 있나: 세션49엔 이 코드가 `forest_enemy`에만 있어 **허수아비(연습장)가 상태를 못 받았다** —
## 마법을 만들고 바로 쏴 보는 자리인데 반응을 시험할 수 없었다. 규칙(`status_rules`)을 core에 둔
## 이유가 "적·허수아비·플레이어가 같은 함수를 부른다"였는데, **보유·틱**만 적에게 남아 절반만 공유됐다.
##
## 🔴 역할 경계:
##   • `status_rules` = **규칙**(무엇이 무엇이 되는가 · 얼마나 세게). 시간도 노드도 모른다.
##   • 여기(holder) = **보유와 시간**(무엇이 걸려 있나 · 언제 만료되나 · 반응 순서).
##   • 소유자(적·허수아비) = **몸**(피해를 어떻게 받나 · 옆 적을 어떻게 찾나 · 색을 어디 칠하나).
##
## 🔴 **콜백 경계가 핵심이다.** holder는 피해를 주지도, 씬을 뒤지지도, modulate를 만지지도 않는다.
##   그건 소유자마다 다르기 때문이다 — 적은 hp를 깎고 허수아비는 카운터를 올리며,
##   틴트는 rgb만 쥐고 **알파는 분산(안개 반투명)이 쥔다**. holder가 modulate를 통째로 쥐면
##   안개의 반투명이 **조용히 사라진다**. 그래서 색은 **반환만** 한다.
##
## ⚠ `_dead` 가드는 소유자가 쥔다 — holder는 죽음을 모른다(소유자가 틱 호출 자체를 건너뛴다).
##
## 🔴 **소유자 계약: 죽을 때 반드시 `clear()`를 불러라.** DoT 틱이 소유자를 죽였을 때 holder는
##   그 사실을 모르고, `clear()`로 비워진 걸 보고서야 남은 틱을 멈춘다(`tick()` 참조).
##   안 부르면 **시체를 계속 때린다.** 지금은 `forest_enemy._die`가 지킨다(허수아비는 안 죽는다).
##
## ⚠ **알려진 것: 반응 산물에 취약 배수가 두 번 곱한다.** `_resolve_reaction`이 넘기는 power엔
##   이미 증폭이 반영돼 있는데 `add()`가 취약이 아직 붙어 있으면 또 곱한다(취약 1.0+특별잉크
##   1.5 → 진흙 2.25배). **세49부터 있던 구조라 회귀는 아니지만**, 세50이 세기를 특별잉크로
##   흔들 수 있게 만들면서 눈에 띄게 커졌다. 의도인지 사고인지 **아직 안 정했다** — 쏴 보고 정한다.

const SR := preload("res://src/core/status_rules.gd")
const BAL := preload("res://data/balance.tres")

## `{status(int): {"power": float, "time": float, "seq": int}}`.
## **여러 상태를 동시에** 가진다(젖음+취약처럼 축이 다른 것들이 겹쳐야 조합이 성립한다).
## `seq`는 적용 순번 — 틴트를 "가장 최근 것"으로 고르는 데만 쓴다.
var _statuses: Dictionary = {}
var _seq: int = 0
## DoT 틱 누적 — `balance.status_tick_sec`마다 한 번 깎는다(매 프레임 깎으면 숫자가 도배된다).
var _tick_accum: float = 0.0

# ── 소유자 콜백 (전부 선택 — 안 주면 그 축을 안 쓴다는 뜻) ─────────────────────
## 지속 피해가 났다. `func(amount: float) -> void`. 🔴 여기서 `enemy_hit`을 쏘지 마라(도배).
var on_dot: Callable = Callable()
## 반경 안 즉발 피해.
## `func(radius: float, amount: float, include_self: bool, result_status: int, rune: int) -> void`.
## 🔴 result_status(세52) = 증기면 `Enums.Status.NONE`, 감전이면 `Enums.Status.SHOCK`. 몸이 VFX 링
## 색과 "연쇄 아크를 그릴지"를 정하는 데 쓴다 — include_self로 유추하지 않는다(암묵 결합 회피).
## 🔴 rune(세56) = 이 버스트의 **정체 룬**(REACTIONS의 "rune" 키, 없으면 들어온 룬 폴백). 몸이
## `take_reaction_damage`→`enemy_hit`에 그대로 실어야 소리·(향후)색이 반응과 맞는다 — 그전엔
## FIRE 하드코딩이라 감전 연쇄가 불 소리를 냈다.
var on_burst: Callable = Callable()
## 붙은 상태를 옆으로 번뜨린다(바람). `func(statuses: Dictionary) -> void`.
var on_spread: Callable = Callable()
## 상태 구성이 바뀌었다 = 틴트를 다시 칠할 때. `func() -> void`.
var on_changed: Callable = Callable()


## 남은 시간을 깎고, 만료된 걸 지우고, `status_tick_sec`마다 지속 피해를 콜백으로 넘긴다.
## 🔴 **지속 피해는 `enemy_hit` 계약이 아니다** — 그 시그널엔 피해 숫자·히트스톱·피격음이 물려
## 있어서(세38·46) 0.5초마다 쏘면 화면이 도배되고 히트스톱에 갇힌다. 표현은 틴트가 맡는다.
## ⚠ 소유자가 이 틱 중에 죽을 수 있다 — DoT 콜백 뒤 `_statuses`가 비었으면 곧장 빠져나온다.
func tick(delta: float) -> void:
	if _statuses.is_empty():
		return
	var expired: Array[int] = []
	for key: int in _statuses.keys():
		var e: Dictionary = _statuses[key]
		e["time"] = float(e["time"]) - delta
		if float(e["time"]) <= 0.0:
			expired.append(key)
	for key: int in expired:
		_statuses.erase(key)
	if not expired.is_empty():
		_notify_changed()

	_tick_accum += delta
	var step: float = BAL.status_tick_sec
	if step <= 0.0:
		return
	while _tick_accum >= step:
		_tick_accum -= step
		var dot := 0.0
		for key: int in _statuses.keys():
			dot += SR.dot_per_sec(key, float(_statuses[key]["power"]))
		if dot > 0.0 and on_dot.is_valid():
			on_dot.call(dot * step)
			# 소유자가 이 피해로 죽었을 수 있다 — 죽으면 소유자가 clear한다.
			if _statuses.is_empty():
				return


## 걸린 상태들 중 **가장 센 감속 하나**만 쓴다 (곱하면 두세 개만 겹쳐도 즉시 정지가 된다).
## 🔴 상태마다 **자기 세기**를 넘긴다 — 그래야 특별잉크 증폭이 감전·덩굴·진흙에도 통한다(세션50 빚①).
func move_mult() -> float:
	var m := 1.0
	for key: int in _statuses.keys():
		m = minf(m, SR.move_mult(key, float(_statuses[key]["power"])))
	return m


## 🔴 새로 들어온 룬을 상태로 번역한다 — `take_hit`의 유일한 진입점.
## 순서가 곧 규칙이다: ① 바람이면 확산만 하고 끝 → ② 반응이 있으면 반응이 이긴다 → ③ 아니면 덮어쓴다.
func apply_incoming(rune_type: int, status: int, status_power: float) -> void:
	# ① 🔴 바람 = 확산자 (원신 Swirl 모델) — **자기 상태를 안 남긴다.** 혼자선 아무것도 아닌데
	#    조합에선 최고가 되는 자리라, 여기서 일찍 빠져나가는 게 바람의 정체성이다.
	if SR.spreads(rune_type):
		if on_spread.is_valid():
			on_spread.call(_statuses)
		return
	# ② 반응 — 이미 붙어 있는 바탕 중 이 룬과 반응하는 게 있으면 그 결과가 이긴다.
	for base: int in _statuses.keys():
		var r: Dictionary = SR.react(base, rune_type)
		if not r.is_empty():
			_resolve_reaction(base, r, status_power, rune_type)
			return
	# ③ 반응 없음 = 그냥 새 상태.
	var s := status
	# 흙은 자기 상태(취약)를 데이터로 못 받은 경우에도 취약을 남긴다 — `amplifies()`가 곧
	# "이 룬이 취약을 만든다"는 규칙이고, 룬 .tres가 채워지면 위의 `status`가 그대로 이긴다.
	if s == Enums.Status.NONE and SR.amplifies(rune_type):
		s = Enums.Status.VULNERABLE
	add(s, status_power)


## 반응 처리 — 바탕은 **소진되고**(반응에 쓰였다), 결과 상태가 있으면 새로 걸린다.
## kind: convert=조용히 바뀐다 · burst=즉발 폭발(연쇄/증기) · clear=씻겨 사라진다.
## 세기는 들어온 룬과 바탕 중 **센 쪽**을 쓴다 — 약한 룬으로 강한 바탕을 깎아먹지 않게.
## 🔴 incoming_rune(세56) = "rune" 키가 없을 때의 폴백 — 버스트의 정체 룬을 on_burst 5번째로 싣는다.
func _resolve_reaction(base_status: int, r: Dictionary, incoming_power: float, incoming_rune: int) -> void:
	var power := maxf(incoming_power, power_of(base_status))
	var result := int(r.get("status", Enums.Status.NONE))
	var kind := str(r.get("kind", "convert"))
	var burst_rune := int(r.get("rune", incoming_rune))
	_statuses.erase(base_status)
	if kind == "burst" and on_burst.is_valid():
		# 🔴 피해 계산은 `SR.burst_damage` 한 곳 — `power * mult`로 되돌리면 배율 통일 뒤
		# 피해가 조용히 1/3로 토막 난다(에러도 테스트 실패도 없다).
		if result == Enums.Status.NONE:
			# 증기(젖음+불) — 바탕이 날아가며 **제자리 반경 즉발 피해**. 남는 상태가 없다.
			# 🔴 result_status=NONE을 실어 보낸다 — 몸이 흰 링만 그리고 연쇄 아크는 안 그린다(세52).
			on_burst.call(BAL.status_steam_px, SR.burst_damage(power, BAL.status_steam_mult), true, result, burst_rune)
		else:
			# 감전 연쇄(젖음+번개) — 주변 적들에게 옮겨 붙는 피해. 맞은 본인은 아래에서 상태를 받는다.
			# 🔴 result_status=SHOCK을 실어 보낸다 — 몸이 노란 링 + 대상마다 번개 아크를 그린다(세52).
			on_burst.call(BAL.status_shock_chain_px, SR.burst_damage(power, BAL.status_shock_chain_mult), false, result, burst_rune)
	if result != Enums.Status.NONE:
		add(result, power)
	else:
		_notify_changed()


## 상태를 건다. 🔴 **중첩 금지 — 재적용은 지속시간 갱신 + 더 센 power 채택**이다
## (누적시키면 연사만으로 폭발한다). 취약이 걸려 있으면 새로 거는 상태가 더 세진다.
func add(status: int, power: float) -> void:
	# 즉발 축(바람 밀림·넉백)은 지속 상태가 아니다 — 이미 다른 축(투사체·넉백)이 처리한다.
	if status == Enums.Status.NONE or status == Enums.Status.FLOW or status == Enums.Status.KNOCKBACK:
		return
	var dur := SR.duration_of(status)
	if dur <= 0.0:
		return
	# 취약 자신에겐 안 곱한다 — 취약이 취약을 키우면 흙만 겹쳐도 무한히 세진다.
	# 🔴 취약의 **세기**를 넘긴다(bool 아님) — 세게 건 취약이 더 크게 증폭한다(사용자 확정 세션50).
	var vuln := 0.0
	if status != Enums.Status.VULNERABLE:
		vuln = power_of(Enums.Status.VULNERABLE)
	var p := power * SR.power_mult(vuln)
	var cur: Dictionary = _statuses.get(status, {})
	_seq += 1
	_statuses[status] = {
		"power": maxf(p, float(cur.get("power", 0.0))),
		"time": dur,
		"seq": _seq,
	}
	_notify_changed()


## 🔴 공개 관측점 — 소유자·테스트가 내부 사전을 더듬지 않게 (takbon-verify §3 "공개 API로만").
func has(status: int) -> bool:
	return _statuses.has(status)


func power_of(status: int) -> float:
	if not _statuses.has(status):
		return 0.0
	return float(_statuses[status]["power"])


func is_empty() -> bool:
	return _statuses.is_empty()


## 소유자가 죽을 때 부른다 — 남은 틱이 시체를 더 때리지 않게.
func clear() -> void:
	_statuses.clear()


## 🔴 지금 대표 상태 = **가장 최근에 걸린 상태** 하나 (여럿이면 최신이 이긴다 — 방금 한 짓이
## 보여야 룬을 바꾼 보람이 있다). 비었으면 `Enums.Status.NONE`(_statuses엔 NONE이 안 들어가므로
## NONE == "빔"이 명확하다).
## 🔴 세52: 공개로 뽑았다 — 틴트(색)와 바람 확산 아크(색)가 **같은 "최신이 이긴다" 규칙**을 써야 하는데
## 그전엔 몸(forest_enemy·dummy_target)이 이 seq-최대 로직을 **각자 복제**하고 holder 내부 dict의
## `["seq"]`를 더듬었다(공개 API 위반·사본 3개). 이제 한 곳이다 — tint()도 이걸 쓴다.
func representative() -> int:
	var best := int(Enums.Status.NONE)
	var best_seq := -1
	for key: int in _statuses.keys():
		var sq := int(_statuses[key]["seq"])
		if sq > best_seq:
			best_seq = sq
			best = key
	return best


## 🔴 지금 보여 줄 색 = 대표 상태의 틴트. 상태가 다 풀리면 흰색(tint_of(NONE) == WHITE).
## ⚠ **반환만 한다** — 칠하는 건 소유자다(알파 소유권. 파일 상단 주석 참조).
func tint() -> Color:
	return SR.tint_of(representative())


func _notify_changed() -> void:
	if on_changed.is_valid():
		on_changed.call()
