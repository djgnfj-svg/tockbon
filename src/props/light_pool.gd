extends PointLight2D
## 빛 웅덩이 — 살아있는 마법이 스스로 숨 쉬는 자리 (세89 · `docs/takbon-design/world_and_visual_design.md` §3·§5).
##
## 🔴 **세계관 규칙 「마법 = 빛」의 구현체가 이것 하나다.** 지금 쓰는 곳은 숲길 문(`forest_gate.tscn`)
## 하나지만 — 문은 망한 마을에 마지막까지 살아남은 마법이고 첫 화면에서 유일하게 빛을 가진 것이다 —
## 설계 §3의 *"되살아난 건물마다 발밑에 빛 웅덩이 하나"* 가 **같은 물건**이라 문 전용으로 짜지 않았다.
## → **새 빛 웅덩이 = `PointLight2D` 하나 + 이 스크립트.** 배선은 그게 전부다.
##
## 🔴 **역할을 씬과 갈라 놓은 게 계약이다**: **겉모습(색·`energy`·`texture_scale`·위치)은 씬이 쥐고**,
## **움직임(맥동)은 이 스크립트가 쥔다.** 그래서 아트가 스프라이트를 새로 그려도 색은 씬에서 한 줄이고,
## 숨결을 손볼 땐 여기 상수 둘만 만진다 — 그리고 웅덩이 여럿이 **한 호흡으로 같이 뛴다**(시각 언어가 하나).
## 씬이 정한 `energy`는 밝기의 **꼭대기가 아니라 한가운데**다(`_base`) — 폭을 조여도 화면이 안 어두워진다.
##
## ⚠ 프레임 애니가 아니다 — 스프라이트는 **정지 1장**이고 노드 타입도 안 바꾼다(설계 §5가 일부러 그
## 길을 각하했다: 맥동을 그림에 넣으면 `Sprite2D` → `AnimatedSprite2D`로 타입이 바뀌고 어휘가 둘로 갈린다).
##
## 🔴 **「살아 있다」로 읽히는지는 헤드리스가 못 잡는다** — 그건 F5·MCP다. 배선이 사는지는
## `test_base_auto [9]`가 잰다(빛 텍스처 로드 · energy가 실제로 변함 · 한 호흡 뒤에도 계속 돎).

## 숨 한 결의 길이(초) — 이 값의 **두 배**가 한 호흡(내쉬고 들이쉬기)이다. 즉 지금은 3.0초 한 호흡.
## 🔴 분당 약 20회 = 사람이 편히 쉴 때의 호흡(12~20회)에서 빠른 쪽이다. 양쪽 끝이 다 함정이라 그 사이다:
##   더 빠르면 **경보등**으로 읽히고, 더 느리면 화면을 스치는 몇 초 동안 **안 움직이는 것처럼** 보인다.
## (형제 값 = `drop_pickup.gd`의 `HALO_PULSE_TIME` 0.85 — 그건 "이거 챙겨라"라 더 급하다. 문은 느긋하다.)
const PULSE_TIME := 1.5

## 맥동 폭 — `energy`가 씬이 정한 밝기의 (1 ± 이 비율) 사이를 오간다. 0.25 = ±25%.
## 🔴 **평균 밝기는 안 바뀐다**(씬 값이 한가운데) — 폭만 건드리면 되고 밝기와 안 엉킨다.
## 0.25 아래로 내리면 넓은 웅덩이에선 변화가 안 읽히고, 0.4를 넘기면 깜빡임(고장 난 등)으로 보인다.
const PULSE_DEPTH := 0.25

var _base: float = 1.0    ## 씬이 정한 밝기 = 맥동의 한가운데
var _tw: Tween = null
var _breaths: int = 0


func _ready() -> void:
	_base = energy
	_start()


## 맥동의 한가운데(= 씬이 정한 밝기). 밖에서 읽기만 한다.
func base_energy() -> float:
	return _base


## 밝기를 갈고 맥동을 그 둘레로 다시 건다 — 건물이 되살아나며 서서히 밝아질 때 쓸 문이다.
## 🔴 `energy`에 **직접 대입하지 마라**: 도는 트윈과 같은 프로퍼티를 놓고 싸워 값이 튄다.
## 밝기를 바꾸는 길은 이 함수 하나다(옛 트윈을 죽이고 새 폭으로 다시 건다).
func set_base_energy(value: float) -> void:
	_base = maxf(value, 0.0)
	_start()


## 몇 번 숨 쉬었나 — 맥동이 **끝나지 않고 계속 도는지**를 밖에서 잴 수 있게 남긴 창이다.
## 원샷 트윈은 한 번 밝아지고 영영 멈추는데 **눈으로는 못 가른다**(그물이 이걸 읽는 이유).
func breaths() -> int:
	return _breaths


func _start() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_breaths = 0
	energy = _base
	# 꺼진 웅덩이는 숨도 안 쉰다 — 되살리기 전 건물(밝기 0)에 그대로 달아 둘 수 있게.
	if _base <= 0.0:
		return
	var hi := _base * (1.0 + PULSE_DEPTH)
	var lo := _base * (1.0 - PULSE_DEPTH)
	_tw = create_tween()
	_tw.set_loops()
	_tw.loop_finished.connect(func(_count: int) -> void: _breaths += 1)
	# 🔴 첫 결에 `.from(hi)`를 박는다 — 루프가 되감길 때 시작값이 직전 결의 끝값과 **정확히 같아야**
	# 이음매에서 안 튄다(트윈 루프의 단골 함정). 이미 hi에 서 있으니 매 바퀴 그 대입은 무해하다.
	_tw.tween_property(self, "energy", lo, PULSE_TIME).from(hi) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "energy", hi, PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
