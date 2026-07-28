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
## 🔴🔴 **인자를 「늘리는」 것은 위 방어선의 반대편이 아니다** (세105 차폐).
## 위 문단이 막는 건 **수치를 이 파일 안으로 끌어들이는 것**이지 인자 수 자체가 아니다.
## `occluders`도 **밖에서 주입하는 값**이라 그 정신을 그대로 따른다 — 오히려 노드·씬·그룹을
## 여기서 조회하는 순간(그게 「인자를 줄이는」 형태다) 이 파일이 `SceneTree`를 알게 되어
## *"여긴 노드도 씬도 시간도 모른다"*는 계약이 깨진다.
##
## @param origin      보는 쪽의 위치 (플레이어)
## @param aim         보는 방향 (정규화 불필요 · 영벡터면 fail-open)
## @param target      보이는지 물어보는 대상의 위치 (적)
## @param fan_deg     부채꼴 **전체** 각도 (반각이 아니다 — 120이면 좌우 60씩)
## @param fan_range   부채꼴 사거리
## @param near_radius 주변시 반경 (방향 무관)
## @param occluders   🔴 **`(x, y, r)`의 배열 — `z`가 반경이다. 3D 좌표가 아니다.**
##                    시선을 끊는 것들(나무·큰 바위). 비면 차폐 없음 = 옛 동작 그대로.
static func is_seen(
	origin: Vector2,
	aim: Vector2,
	target: Vector2,
	fan_deg: float,
	fan_range: float,
	near_radius: float,
	occluders: PackedVector3Array = PackedVector3Array()
) -> bool:
	var to_target := target - origin
	var dist := to_target.length()

	# 🔴🔴 주변시 — 방향을 안 본다. 같은 자리(dist 0)도 여기서 잡힌다.
	#
	# **이 검사가 차폐(아래)보다 위에 있는 것이 계약이다**(세105 · `vision_occlusion_design` §2-3 ①).
	# 주변시는 「눈」이 아니라 **「몸으로 느끼는 범위」**라 나무가 막을 이유가 없고, 더 중요하게는
	# 이 순서가 `vision_design` §4-1의 보장(*"쫓기 시작한 적은 반드시 보인다"*)을 지탱한다 —
	# 🔴 **아래로 내리면 나무 뒤에서 달려오는 늑대가 코앞까지 안 보이고**, 그 설계가 막으려던
	#   *"안 보이는 데서 맞았다"*가 에러 0으로 돌아온다(그물 = `test_vision_auto [1]`의 차폐 표).
	if dist <= near_radius:
		return true

	# 판정 불가 → 보인다 (fail-open · 위 주석)
	if aim.is_zero_approx():
		return true

	if dist > fan_range:
		return false

	## 🔴🔴 **전방위(360° 이상)는 각도 비교에 맡기지 않는다 — 세105에 실제로 밟았다.**
	##
	## `Vector2.angle_to`는 **float32**로 계산해 정확히 등 뒤에서 `3.14159274…`를 돌려주는데,
	## `deg_to_rad(180.0)`은 **double** `3.14159265…`다 ⇒ `<=`가 **거짓**이 되어
	## **「360°인데 등 뒤만 안 보인다」**가 된다. 부동소수 폭이 아니라 **타입이 다른** 문제라
	## 여유(epsilon)로 덮을 값이 아니고, 애초에 **전방위면 각도를 볼 이유가 없다.**
	##
	## 🔴 **이게 왜 치명적인가**: 360°는 인지 설계 §7-b의 **폴백값**이다 —
	## *"`sight_angle` 키가 없으면 360° = 부채꼴이 무의미 = 늘 본다(옛 동작)"*가 하위호환의 심장인데,
	## 그 심장이 **정확히 한 각도에서만** 조용히 멎었다. 세105에 인지 키 0개인 그물 몸을
	## 「등 뒤」에 둔 판이 통째로 굳어 **`test_enemy_facing_auto` 12건 + `test_enemy_ai_auto` 4건**이
	## 빨개졌고, 원인이 이 한 줄이라는 걸 알아내는 데 한참 걸렸다.
	##
	## ⚠ **부르는 쪽에서 우회하지 마라** — 이 파일이 부채꼴 판정의 **단일 소스**인 이유가
	## 「같은 수학을 두 벌로 두지 않는다」인데, 호출자마다 360° 예외를 따로 적으면 그게 곧 T5다.
	if fan_deg >= 360.0:
		return not _blocked(origin, target, occluders)

	# 부채꼴 — `fan_deg`는 전체 각도라 반으로 갈라 비교한다.
	if absf(aim.angle_to(to_target)) > deg_to_rad(fan_deg * 0.5):
		return false

	return not _blocked(origin, target, occluders)


## 🔴 시선(선분)이 엄폐물(원) 하나라도 지나면 막힌 것이다 — 순수 기하.
##
## ⚠ **여유(epsilon)를 넣지 마라.** 이 파일이 세105에 float32 경계로 밟은 자리가 위에 있는데,
##   여기는 **거리 제곱끼리 비교**라 그 함정이 없다(`sqrt`도 안 쓴다 — 느리기만 하다).
##
## 🔴 **양 끝점이 원 안이면 「막힌 것」이 아니다.** 안 걸러내면 나무에 몸을 붙이고 선 쪽이
##   자기 나무에 가려져 **「나무를 껴안으면 아무것도 안 보인다」**가 된다.
##   ⚠ 보는 쪽(`origin`)만이 아니라 **대상(`target`)도** 봐야 한다 — 나무 밑동에 선 적을
##   못 보면 「나무 옆에 붙은 적이 영영 안 보인다」가 된다.
static func _blocked(origin: Vector2, target: Vector2, occluders: PackedVector3Array) -> bool:
	if occluders.is_empty():
		return false

	var seg := target - origin
	var seg_len_sq := seg.length_squared()

	for o: Vector3 in occluders:
		var c := Vector2(o.x, o.y)
		var r := o.z
		if r <= 0.0:
			continue
		var r_sq := r * r

		# 끝점이 원 안이면 이 엄폐물은 건너뛴다 (위 주석)
		if origin.distance_squared_to(c) <= r_sq or target.distance_squared_to(c) <= r_sq:
			continue

		# 선분 위에서 원 중심에 가장 가까운 점 — t를 [0,1]로 clamp한다.
		# ⚠ seg_len_sq가 0이면(같은 자리) 위 끝점 검사에서 이미 걸러졌거나 원 밖이라 안전하다.
		var t := 0.0
		if seg_len_sq > 0.0:
			t = clampf((c - origin).dot(seg) / seg_len_sq, 0.0, 1.0)
		if (origin + seg * t).distance_squared_to(c) <= r_sq:
			return true

	return false
