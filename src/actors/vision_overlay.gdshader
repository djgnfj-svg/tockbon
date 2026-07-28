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

// 🔴🔴 **엄폐물 = `(x, y, r)` — z가 반경이다. 3D 좌표가 아니다**(`vision.gd is_seen`의 그 관례).
//  세105에 `vision_occlusion_design` ⓓ(*"차폐 영역은 화면에 안 그린다"*)를 **뒤집으면서** 열었다.
//  발단 = 사용자 *"몬스터만 안보여짐 **빛이 안가야하거든**"* — 판정은 이미 돌고 있었고 화면만
//  나무를 통과하고 있었다. 그 문서 §2-5가 *"뒤집으면 셰이더와 `lit_at`을 **같이** 열어라"*고
//  미리 적어 뒀고, 이 uniform이 그 문장의 절반이다(나머지 절반 = `vision_overlay.lit_at`).
//
// 🔴 배열 크기는 컴파일 타임 상수여야 해서 **`vision_overlay.gd`의 `MAX_OCCLUDERS`와 두 벌**이다.
//  ⇒ 그물(`test_vision_overlay_auto`)이 **이 줄을 문자열로 읽어** 그쪽 const와 대조한다(T5 방어).
//  실제로 몇 개를 볼지는 `occluder_count`가 쥔다 — 사거리 밖·등 뒤는 CPU가 미리 걷어낸다.
const int MAX_OCCLUDERS = 16;
uniform vec3 occluders[MAX_OCCLUDERS];
uniform int occluder_count;
uniform float shadow_feather;    // 그늘 경계의 반그림자 폭(px — 엄폐물 반경에 더한다)

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

	// ── 🔴🔴 차폐 그늘 — **주변시 안은 면제다** ────────────────────────────────────────────
	// `vision.gd`의 판정 순서 ①(*"주변시가 차폐보다 먼저다"*)이 여기서도 그대로여야 한다.
	//
	// 🔴 **그 면제는 아래 `max(near_lit, fan_lit)`가 통째로 진다** — 그늘은 `fan_lit`만 깎으므로,
	//  주변시 안(`near_lit == 1`)이면 무엇을 깎든 `max`가 1을 돌려준다. **구조로 보장된다.**
	//
	// ⚠ **그러니 아래 `near_lit < 1.0`은 정확성이 아니라 성능 조건이다.** (여기 처음엔
	//  *"이걸 빼면 주변시 원이 뚫린다"*고 적었는데 **틀렸다** — 뮤테이션으로 빼고 그림자를
	//  `near_lit`에까지 곱해 봐도 화면이 한 픽셀도 안 변했다. 잘리는 자리가 늘 **엄폐물 자기
	//  스프라이트 밑**이기 때문이다. 계약이 아닌 걸 계약이라 적으면 그게 T4다.)
	//  ⇒ 이 조건이 하는 일: **부채꼴 안이면서 주변시 밖인 픽셀만** 루프를 타게 한다.
	//   화면의 대부분(주변시 원 + 부채꼴 밖 전부)이 루프를 건너뛴다 = 이 셰이더 비용의 심장.
	if (fan_lit > 0.0 && near_lit < 1.0 && occluder_count > 0) {
		float seg_len_sq = max(dot(d, d), 0.000001);
		float shade = 0.0;
		for (int i = 0; i < MAX_OCCLUDERS; i++) {
			if (i >= occluder_count) { break; }
			vec2 c = occluders[i].xy;
			float r = occluders[i].z;
			float r_sq = r * r;
			// 🔴 **끝점(이 픽셀)이 원 안이면 건너뛴다** — 안 그러면 나무를 껴안은 쪽이 자기 나무에
			//  가려져 「나무 밑동이 통째로 검다」가 된다(`vision.gd._blocked`의 그 규칙).
			//  ⚠ 보는 쪽(origin)이 원 안인 경우는 **CPU가 목록에서 아예 뺀다**
			//   (`vision_overlay._refresh_live`) — 픽셀마다 다시 잴 이유가 없고 답이 완전히 같다.
			vec2 tc = c - world;
			float dt = dot(tc, tc);
			// 선분 위에서 원 중심에 가장 가까운 점 — t를 [0,1]로 clamp한다(`_blocked`와 같은 수학).
			float t = clamp(dot(c - origin, d) / seg_len_sq, 0.0, 1.0);
			// 🔴🔴 **반그림자 폭 하나로 옆선과 밑동 테두리를 **둘 다** 판다.** 두 개를 따로 두면
			//  한쪽만 조여져 밑동에 **테두리 링**이 남는다(실제로 밟았다 — `occl_f24` 첫 판의 「비눗방울」).
			float pen = shadow_feather * (1.0 - t);
			// 🔴 밑동 원 안쪽 = 밝다(끝점 규칙). 그 경계를 `pen`만큼 **안쪽으로** 번지게 한다.
			float ri = max(r - pen, 0.0);
			if (dt <= ri * ri) { continue; }
			vec2 h = c - (origin + d * t);
			// 🔴🔴 **반그림자는 「엄폐물 뒤로 얼마나 깊이 갔나」에 비례한다** — 폭을 고정하면
			//  원 둘레에 **일정한 검은 후광**이 생겨 밑동이 「구멍」으로 보인다(첫 판에서 실제로 그랬다:
			//  나무 옆·앞까지 어두워져 원뿔이 아니라 얼룩으로 읽혔다).
			//  `t`가 그 깊이다 — 이 픽셀이 엄폐물보다 **가깝거나 옆이면** t가 1로 clamp되어 폭이 0이 되고
			//  (그 자리는 판정과 **완전히 같다**), 뒤로 갈수록 t가 작아져 원뿔 옆선이 부드러워진다.
			//  ⇒ 실제 반그림자와 같은 방향이고, 「어둠 100%가 되는 선 = 판정이 막힌다고 답하는 선」이라는
			//    이 파일의 `edge_feather` 규율도 그대로다.
			// 🔴 **제곱끼리 비교한다 — `sqrt`를 안 쓴다**(`_blocked`와 같은 수학).
			// ⚠ `max(…, r_sq * 1.0001)`은 **0폭 smoothstep(edge0 == edge1)을 막는 가드**다.
			//  🔴 눈에 보이는 이유가 있다: 폭을 px로 더해 가드하면(`+ 1.0`) **밑동 둘레에 1px짜리
			//   검은 테두리 원**이 그려져 「도장을 찍은 것」처럼 보인다(실제로 그렇게 찍혔다).
			//   비율로 벌리면 그 폭이 사실상 0이라 원 밖은 판정 그대로 **완전히 밝다.**
			float ro = r + pen;
			float occl = 1.0 - smoothstep(r_sq, max(ro * ro, r_sq * 1.0001), dot(h, h));
			// 🔴🔴 **밑동 원의 테두리 — 그라디언트를 「안쪽으로」 깐다.** 위 `continue`(끝점 규칙)는
			//  원 안을 통째로 밝게 두는데, 그 경계가 **완벽한 원**이라 그냥 두면 바닥에 **도장을 찍은 것**처럼
			//  보인다(실제로 그렇게 찍혔다 — 큰 바위 쪽이 특히 티가 났다).
			//
			// 🔴🔴 **방향이 계약이다 — 안쪽이어야 한다.** 두 오류 중 **덜 나쁜 쪽**을 고르는 자리다:
			//   • 안쪽(지금): `dt < r²`는 판정상 **보이는데** 화면이 조금 어둡다 → 「어두운데 보였다」
			//   • 바깥쪽(❌): `dt > r²`는 판정상 **막혔는데** 화면이 조금 밝다 → 🔴 **「밝은데 안 보였다」**
			//  뒤쪽이 바로 사용자가 지적한 그 증상(*"몬스터만 안보여짐"*)이라 **절대 뒤집지 마라.**
			//  ⚠ 처음엔 바깥쪽으로 깔았다 — 밑동 **앞쪽**이 안 어두워져 보기엔 나았지만 금지된 방향이었다.
			// 🔴 **어둠이 100%가 되는 선은 여전히 `dt = r²`**, 즉 `_blocked`가 「막힘」이라 답하기
			//  시작하는 바로 그 선이다(이 파일의 `edge_feather` 규율과 같다).
			shade = max(shade, occl * smoothstep(ri * ri, max(r_sq, ri * ri * 1.0001), dt));
		}
		fan_lit *= 1.0 - shade;
	}

	float lit = max(near_lit, fan_lit);
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - lit));
}
