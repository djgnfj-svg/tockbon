shader_type canvas_item;
// 🔴🔴 **시야 부채꼴 밖을 조금 어둡게 한다** (세104 · 정본 `docs/takbon-design/vision_design.md`).
//
// 🔴 **이 셰이더는 자기 부채꼴을 계산하지 않는다 — 모양을 밖에서 통째로 받는다.**
//  판정의 단일 소스는 `src/core/vision.gd`이고 수치는 `balance_data.gd`의 `vision_*` 셋이다.
//  여기에 120·560·220 같은 값을 **한 글자라도 박으면** 「어두운 데 서 있는데 보이는 적」·
//  「밝은 데 있는데 안 보이는 적」이 생기고 **에러가 0이다**(감사 T5 — 같은 말이 두 벌).
//  ⇒ 그물(`tests/test_vision_overlay_auto.gd`)이 uniform 값을 balance와 대조하고,
//    **이 파일에 그 숫자가 있는지 문자열로 훑는다.**
//
// ⚠ **`fan_deg`는 전체 각도다**(반각이 아니다 — 120이면 좌우 60씩). `vision.gd`가
//  `absf(aim.angle_to(d)) <= deg_to_rad(fan_deg * 0.5)`로 재므로 여기서도 반으로 갈라 쓴다.
// ⚠ **합집합이지 교집합이 아니다** — 부채꼴 ∪ 주변시원. 둘 중 하나에만 들면 밝다(`max`).
//
// 🔴 좌표는 **월드**다. `rect_pos`·`rect_size`(= 방의 Ground 사각형)로 UV를 월드로 되돌리므로
//  카메라가 흔들리든 줌이 바뀌든 부채꼴이 **월드에 고정**된다(화면 좌표를 아예 안 쓴다).
// 🔴 `unshaded` — 이 방엔 볕뉘(PointLight2D)가 5개다. 안 끄면 조명 패스가 어둠 위에 얹혀
//  「어두운 데만 빛나는」 얼룩이 된다.
render_mode unshaded;

// ── 밖에서 주입한다 (기본값을 **일부러 안 준다** — 주입이 끊기면 0이 되어 «안개 없음»으로
//    떨어진다. 시야 판정의 fail-open과 같은 방향의 안전한 실패다.)
uniform vec2 origin;             // 보는 쪽(플레이어)의 월드 위치
uniform vec2 aim;                // 조준 방향 (정규화해서 넘긴다)
uniform float fan_deg;           // 🔴 **전체** 각도 · balance `vision_fan_deg`
uniform float fan_range;         // balance `vision_fan_range`
uniform float near_radius;       // balance `vision_near_radius`
uniform vec2 rect_pos;           // 이 사각형의 월드 좌상단
uniform vec2 rect_size;
uniform float darkness;          // 밖을 얼마나 누르나 (연출값 — 정의는 `vision_overlay.gd`)
uniform float edge_feather;      // 반경 경계의 그라디언트 폭(px)
uniform float angle_feather;     // 각 경계의 그라디언트 폭(px — 호 길이 기준이라 거리로 나눈다)

// ⚠ **세107: 차폐 그늘이 은퇴했다** — 여기 있던 `MAX_OCCLUDERS` const · `occluders[]`·`occluder_count`
//  ·`shadow_feather` uniform과 아래 fragment의 그늘 계산 루프가 통째로 빠졌다
//  (사용자 확정 *"구지 나무나 돌맹이에 시야가 가려지지 않도록"*).
//  🔴 **되살리려면 판정(`src/core/vision.gd`)·화면(여기 + `vision_overlay.gd`)·그물을 셋 같이 열어라** —
//   하나만 열면 「밝은데 적이 안 보인다」가 돌아온다. 경위 = `vision.gd` 머리말 · `git show`(세105~107).

void fragment() {
	vec2 world = rect_pos + UV * rect_size;
	vec2 d = world - origin;
	float dist = length(d);
	// 같은 자리(dist 0)에선 방향이 정의되지 않는다 — 아래 주변시가 1.0이라 결과엔 영향이 없지만
	// normalize가 NaN을 내면 max()로 새 나가므로 여기서 끊는다.
	vec2 dir = dist > 0.001 ? d / dist : vec2(1.0, 0.0);

	// 주변시 — 방향을 안 본다.
	float near_lit = 1.0 - smoothstep(near_radius - edge_feather, near_radius, dist);

	// 부채꼴 — 각 · 사거리 둘 다 들어야 한다.
	// 🔴 그라디언트는 **경계에서 안쪽으로** 깐다: 어둠이 100%가 되는 선 = 적이 실제로 사라지는 선.
	//  경계를 중심으로 걸치면 「밝게 그려진 자리인데 적이 없다」가 생겨 링이 거짓말을 한다.
	float half_rad = radians(fan_deg * 0.5);
	float ang = acos(clamp(dot(dir, aim), -1.0, 1.0));
	// 각 그라디언트는 **화면에서 같은 두께**로 보이게 px를 거리로 나눠 라디안으로 바꾼다
	// (고정 각으로 두면 멀수록 번짐이 넓어져 부채꼴 끝이 뭉갠다).
	float af = clamp(angle_feather / max(dist, 1.0), 0.0, half_rad);
	float ang_lit = 1.0 - smoothstep(half_rad - af, half_rad, ang);
	float range_lit = 1.0 - smoothstep(fan_range - edge_feather, fan_range, dist);
	float fan_lit = ang_lit * range_lit;

	// ⚠ 여기 있던 **차폐 그늘 루프가 세107에 은퇴했다**(위 uniform 문단) — 남는 건
	//  부채꼴 ∪ 주변시뿐이다. 🔴 `max`가 그 합집합이다(교집합이 아니다).
	float lit = max(near_lit, fan_lit);
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - lit));
}
