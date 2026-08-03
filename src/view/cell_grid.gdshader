shader_type canvas_item;
render_mode unshaded;

// 셀 격자 렌더. 🔴 **CPU는 색을 만들지 않는다** — `_mat`·`_flag` 바이트 배열이 그대로 L8 텍스처이고,
//  여기서 팔레트 룩업만 한다.
//
// 🔴 **색 리터럴을 재료에 쓰지 마라.** 팔레트는 `cell_materials.gd`의 `DEFS`에서 구워 주입한다.
//  여기 색을 박으면 시뮬 표와 렌더가 갈린다(파생 대신 복제).
// 🔴 불 색과 비트 위치도 마찬가지로 **주입된다**(`fx_tuning.gd` · `cell_materials.gd`).

uniform vec4 palette[16];

// 🔴 `_flag` 텍스처. 재료는 그대로인데 상태만 바뀌는 것(= 타는 중)을 나르는 유일한 축이다.
uniform sampler2D flag_tex : filter_nearest, repeat_disable;
uniform int flag_burning;
uniform vec4 fire_lo;
uniform vec4 fire_hi;
uniform float fire_hz;

// L8 → 정수 복원. 🔴 값을 16 미만으로 묶어 둔 이유가 이 반올림이다 —
//  정밀도가 mediump로 떨어지는 기계에서도 0~15는 안전하다.
//
// 🔴🔴 **인자가 sampler가 아니라 「이미 읽은 texel」인 것이 이 함수의 전부다.**
//  sampler를 인자로 받으면 같은 함수를 내장(`TEXTURE`)과 uniform(`flag_tex`) 양쪽으로 못 부른다
//  (`Sampler argument 0 ... called more than once using both built-ins and uniform textures`).
//  ⇒ 그렇게 짜면 **컴파일이 통째로 실패하는데 게임은 안 멈추고 화면만 검게 뜬다** —
//   격자가 L8 원본 바이트값(돌 1 · 나무 2)으로 그려지고, `_draw()`로 그리는 캐릭터만 제 색으로 남는다.
//  ⚠ 실측으로 그 상태에서 그물 534개가 전부 초록이었다. `net_render`가 그래서 생겼다.
//  ⚠ 파서 규칙이라 **백엔드·헤드리스와 무관하다**(검증자가 변형 4개를 컴파일해 좁혔다).
int l8_to_int(vec4 texel) {
	return clamp(int(texel.r * 255.0 + 0.5), 0, 15);
}

void fragment() {
	int mat_id = l8_to_int(texture(TEXTURE, UV));
	int flags = l8_to_int(texture(flag_tex, UV));

	vec4 c = palette[mat_id];

	if ((flags & flag_burning) != 0) {
		// 🔴 **셀마다 위상을 흩는다.** 안 그러면 불 전체가 한 덩어리로 같이 깜빡여서
		//  「타는 면」이 아니라 「깜빡이는 사각형」으로 보인다.
		// ⚠ 격자 크기를 여기 박지 않는다 — `TEXTURE_PIXEL_SIZE`가 그 값을 이미 들고 있고,
		//  손으로 적으면 W/H를 바꾸는 날 조용히 낡는다.
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
		float ph = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		c = mix(fire_lo, fire_hi, 0.5 + 0.5 * sin(TIME * fire_hz + ph * 6.2831853));
	}

	COLOR = c;
}
