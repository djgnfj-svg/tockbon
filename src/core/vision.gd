extends RefCounted
## 🔴 **시야 판정의 단일 소스** (세104 신설). 순수 수학 · 오토로드 아님 · class_name 없음 —
## 부르는 쪽은 `const Vision := preload("res://src/core/vision.gd")`.
##
## 왜 core에 있나: `ring_power.gd`·`status_rules.gd`와 같은 이유다 — **같은 부채꼴을 두 축이 쓴다.**
##   • 지금(N27 시야): 적이 *"내가 플레이어에게 보이나"*를 묻는다.
##   • 다음(N30 몬스터 인지): 적이 *"플레이어가 나에게 보이나"*를 **같은 부채꼴로** 묻는다.
## 두 축이 각자 부채꼴을 짜면 「같은 말이 두 벌」이 되어 한쪽만 고쳐도 아무도 못 알아챈다(감사 T5).
## 정본 = `docs/takbon-design/vision_design.md` · 짝 = `enemy_perception_design.md` §3.
##
## 🔴 규칙 (사용자 확정 세101):
##   **보인다 = 부채꼴(보는 쪽 · 멀리) ∪ 주변시원(몸 둘레 · 방향 무관).**
##   **합집합이지 교집합이 아니다** — 둘 중 하나에만 들면 보인다.
##   부채꼴은 「어디를 겨누고 있나」이고 주변시는 「몸으로 느끼는 범위」다.
##
## ⚠ 이 파일은 **무엇이 보이는지만 판정한다.** 그 결과로 무엇을 흐릴지(적의 몸? 그림자? 피해 숫자?)는
##   부르는 쪽이 정한다 — 여긴 노드도 씬도 시간도 모른다.


## 🔴🔴 **인자를 줄이지 마라 — 이 서명 자체가 숨은 방어선이다.**
##
## GDScript는 **static 함수 안의 `const BAL.프로퍼티`를 컴파일 타임에 굳힌다**(`takbon-verify` §5 ·
## memory `godot-const-resource-folding`). 누가 *"인자가 여섯이나 된다"*며 이 파일 안에서
## `const BAL := preload("res://data/balance.tres")`를 읽도록 「정리」하면, 그물이 수치를 흔드는
## **뮤테이션이 아무 효과도 못 내면서 전 스위트가 초록**이 된다 — 검출력 0인데 초록이다.
## **이 프로젝트가 실제로 밟은 함정이다.** 수치는 반드시 **밖에서 주입**한다.
##
## 폴백: `aim`이 영벡터면 **각도가 정의되지 않는다** ⇒ 「판정 불가」이므로 **보인다**(fail-open).
##   🔴 *"알 수 없으니 숨긴다"*는 **안 보여야 할 이유가 없는 적을 지우는** 최악의 실패 형태다
##   (설계 §5-1 A4 — 기존 그물 둘이 `modulate == Color(1,1,1,1)` 완전 일치를 단언해서 계약이기도 하다).
##
## @param origin      보는 쪽의 위치 (플레이어)
## @param aim         보는 방향 (정규화 불필요 · 영벡터면 fail-open)
## @param target      보이는지 물어보는 대상의 위치 (적)
## @param fan_deg     부채꼴 **전체** 각도 (반각이 아니다 — 120이면 좌우 60씩)
## @param fan_range   부채꼴 사거리
## @param near_radius 주변시 반경 (방향 무관)
static func is_seen(
	origin: Vector2,
	aim: Vector2,
	target: Vector2,
	fan_deg: float,
	fan_range: float,
	near_radius: float
) -> bool:
	var to_target := target - origin
	var dist := to_target.length()

	# 주변시 — 방향을 안 본다. 같은 자리(dist 0)도 여기서 잡힌다.
	if dist <= near_radius:
		return true

	# 판정 불가 → 보인다 (fail-open · 위 주석)
	if aim.is_zero_approx():
		return true

	if dist > fan_range:
		return false

	# 부채꼴 — `fan_deg`는 전체 각도라 반으로 갈라 비교한다.
	return absf(aim.angle_to(to_target)) <= deg_to_rad(fan_deg * 0.5)
