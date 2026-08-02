shader_type canvas_item;
render_mode unshaded;

// 셀 격자 렌더. 🔴 **CPU는 색을 만들지 않는다** — `_mat`·`_flag` 바이트 배열이
// 그대로 L8 텍스처 2장이고, 여기서 팔레트 룩업만 한다(설계 §3).
//
// 🔴 **색 리터럴을 재료에 쓰지 마라.** 팔레트는 `cell_materials.gd`의 `DEFS`에서 구워 주입한다.
//  여기 색을 박으면 시뮬 테이블과 렌더가 갈린다(SKILL.md T5 — 파생 대신 복제).

uniform sampler2D flag_tex : filter_nearest, repeat_disable;
uniform vec4 palette[16];

// ⚠ `cell_materials.gd`의 FLAG_* 와 **같은 값이어야 한다.** 한쪽만 바꾸면 에러 없이 색만 틀어진다.
const int FLAG_WET = 1;
const int FLAG_CHARGED = 4;

// WET/CHARGED는 재료가 아니라 「재료 위에 얹히는 것」이라 팔레트 항목이 아니다 — 연출값이다.
const vec3 WET_TINT = vec3(0.10, 0.24, 0.48);
const float WET_MIX = 0.45;
const vec3 CHARGE_GLOW = vec3(0.55, 0.78, 1.00);

void fragment() {
	// L8 → 정수 복원. 🔴 재료 id·플래그를 16 미만으로 묶어 둔 이유가 이 나눗셈이다 —
	//  정밀도가 mediump로 떨어지는 기계에서도 0~15는 안전하다(설계 §3).
	int mat_id = clamp(int(texture(TEXTURE, UV).r * 255.0 + 0.5), 0, 15);
	vec4 c = palette[mat_id];

	int fl = int(texture(flag_tex, UV).r * 255.0 + 0.5);
	if ((fl & FLAG_WET) != 0) {
		c.rgb = mix(c.rgb, WET_TINT, WET_MIX);
	}
	if ((fl & FLAG_CHARGED) != 0) {
		// 가산 섬광. 눈에 띄어야 「전기가 젖은 데로 퍼진다」가 화면에 읽힌다.
		c.rgb += CHARGE_GLOW * (0.55 + 0.45 * sin(TIME * 34.0));
	}
	COLOR = c;
}
