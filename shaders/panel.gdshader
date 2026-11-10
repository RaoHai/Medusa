// 对话面板底色：深色底 + 竖向笔刷痕 + 左侧一条被灯光染暖的边
shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.045, 0.042, 0.04, 0.95);
uniform vec4 warm_color : source_color = vec4(0.20, 0.12, 0.06, 1.0);
uniform vec4 cool_color : source_color = vec4(0.03, 0.07, 0.08, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = FRAGCOORD.xy;
	float brush = vnoise(p * vec2(0.12, 0.006)) * 0.6 + vnoise(p * vec2(0.4, 0.02) + 7.0) * 0.4;
	float blot = vnoise(p * 0.004 + 3.0);
	vec3 c = base_color.rgb;
	c = mix(c, cool_color.rgb, smoothstep(0.35, 0.8, blot) * 0.55);
	c += warm_color.rgb * pow(1.0 - UV.x, 6.0) * 0.5;
	c += warm_color.rgb * pow(UV.y, 5.0) * 0.25;
	c *= 0.82 + 0.36 * brush;
	// 左缘毛糙地淡出，像刷出来的边
	float edge = smoothstep(0.0, 0.035 + 0.03 * vnoise(vec2(p.y * 0.05, 1.0)), UV.x);
	COLOR = vec4(c, base_color.a * edge);
}
