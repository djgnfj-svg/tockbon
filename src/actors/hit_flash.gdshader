shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float telegraph_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 telegraph_color : source_color = vec4(1.0, 0.45, 0.3, 1.0);

void fragment() {
    // 🔴 COLOR를 그대로 만진다 — canvas_item fragment 진입 시 COLOR = texture × 버텍스색(modulate)라
    // 상태 틴트·분산 알파가 이미 실려 있다. texture(TEXTURE, UV)를 직접 샘플해 COLOR에 대입하면
    // modulate가 통째로 죽는다(상태 틴트 침묵사) — 그 함정을 피하는 게 이 세 줄의 이유다.
    COLOR.rgb = mix(COLOR.rgb, telegraph_color.rgb, telegraph_amount);
    COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash_amount);
}
