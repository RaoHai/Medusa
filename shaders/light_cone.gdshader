// 路灯 / 门灯下的体积光锥（加色混合，越往下越淡）
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform float strength = 0.16;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// 圆柱侧面的 UV.y 只占 0..0.5（另一半给端面），0 = 顶部
	float fall = pow(1.0 - clamp(UV.y * 2.0, 0.0, 1.0), 1.6);
	// 正对相机的面最亮，侧缘淡出
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rays = 0.8 + 0.2 * sin(UV.x * 60.0 + TIME * 0.3);
	ALBEDO = color.rgb;
	ALPHA = strength * fall * smoothstep(0.0, 0.7, facing) * rays;
}
