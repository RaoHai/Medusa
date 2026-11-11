// 全屏后处理 —— 极夜的电影感：
//  很轻的色块化（保留一点手绘味，不再涂抹）→ 淡墨线 → 冷色调分级（暗部发蓝、灯光发暖）
//  → 漂移的薄雾 → 胶片颗粒 → 暗角
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Kuwahara 半径和混合量。paint_amount = 0 就是完全不做色块化
uniform int radius : hint_range(0, 6) = 2;
uniform float brush_size : hint_range(0.5, 3.0) = 1.0;
uniform float paint_amount : hint_range(0.0, 1.0) = 0.3;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.14;
uniform vec3 outline_color : source_color = vec3(0.01, 0.015, 0.03);
uniform float saturation : hint_range(0.0, 2.0) = 0.55;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
// 暗部抬起来的颜色：黑不是纯黑，是雾里的蓝灰
uniform vec3 shadow_tint : source_color = vec3(0.03, 0.038, 0.052);
uniform vec3 midtone_tint : source_color = vec3(0.92, 0.97, 1.05);
uniform vec3 highlight_tint : source_color = vec3(1.08, 0.96, 0.8);
uniform vec3 mist_color : source_color = vec3(0.13, 0.15, 0.19);
uniform float mist : hint_range(0.0, 0.5) = 0.1;
uniform float film_grain : hint_range(0.0, 0.3) = 0.07;
uniform float vignette : hint_range(0.0, 1.5) = 0.95;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 fc = FRAGCOORD.xy;
	vec3 src = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 col = src;

	// 1) 轻度色块化
	if (paint_amount > 0.001 && radius > 0) {
		vec2 stp = px * brush_size;
		vec3 m0 = vec3(0.0), m1 = vec3(0.0), m2 = vec3(0.0), m3 = vec3(0.0);
		vec3 s0 = vec3(0.0), s1 = vec3(0.0), s2 = vec3(0.0), s3 = vec3(0.0);
		for (int j = -radius; j <= radius; j++) {
			for (int i = -radius; i <= radius; i++) {
				vec3 c = textureLod(screen_tex, uv + vec2(float(i), float(j)) * stp, 0.0).rgb;
				vec3 c2 = c * c;
				if (i <= 0 && j <= 0) { m0 += c; s0 += c2; }
				if (i >= 0 && j <= 0) { m1 += c; s1 += c2; }
				if (i >= 0 && j >= 0) { m2 += c; s2 += c2; }
				if (i <= 0 && j >= 0) { m3 += c; s3 += c2; }
			}
		}
		float n = float((radius + 1) * (radius + 1));
		m0 /= n; m1 /= n; m2 /= n; m3 /= n;
		float v0 = dot(abs(s0 / n - m0 * m0), vec3(1.0));
		float v1 = dot(abs(s1 / n - m1 * m1), vec3(1.0));
		float v2 = dot(abs(s2 / n - m2 * m2), vec3(1.0));
		float v3 = dot(abs(s3 / n - m3 * m3), vec3(1.0));
		vec3 k = m0;
		float best = v0;
		if (v1 < best) { best = v1; k = m1; }
		if (v2 < best) { best = v2; k = m2; }
		if (v3 < best) { best = v3; k = m3; }
		col = mix(src, k, paint_amount);
	}

	// 2) 淡墨线
	float tl = luma(textureLod(screen_tex, uv + px * vec2(-1.0, -1.0), 0.0).rgb);
	float tr = luma(textureLod(screen_tex, uv + px * vec2(1.0, -1.0), 0.0).rgb);
	float bl = luma(textureLod(screen_tex, uv + px * vec2(-1.0, 1.0), 0.0).rgb);
	float br = luma(textureLod(screen_tex, uv + px * vec2(1.0, 1.0), 0.0).rgb);
	float edge = length(vec2(tr + br - tl - bl, bl + br - tl - tr));
	col = mix(col, outline_color, smoothstep(0.08, 0.3, edge) * outline_strength);

	// 3) 调色：整体偏冷，只有灯光是暖的
	float l = luma(col);
	col = max((col - 0.5) * contrast + 0.5, vec3(0.0));
	col *= mix(midtone_tint, highlight_tint, smoothstep(0.35, 0.85, l));
	// 降饱和时保住暖色（灯、火、亮窗、红色标语）
	float warm = clamp((col.r - col.b) * 3.0, 0.0, 1.0);
	col = mix(vec3(luma(col)), col, mix(saturation, 1.05, warm));
	col += shadow_tint * (1.0 - smoothstep(0.0, 0.5, l));

	// 4) 薄雾：大块的、缓慢漂移的灰蓝色
	float m = vnoise(uv * vec2(3.0, 5.0) + vec2(TIME * 0.012, TIME * 0.004)) * 0.6
			+ vnoise(uv * vec2(7.0, 11.0) - vec2(TIME * 0.02, 0.0)) * 0.4;
	col += mist_color * mist * smoothstep(0.35, 0.9, m) * (1.0 - smoothstep(0.3, 0.9, l));

	// 5) 胶片颗粒：暗部更明显
	float g = hash(fc + fract(TIME) * 91.0) - 0.5;
	col += g * film_grain * (0.35 + 0.65 * (1.0 - l));

	// 6) 暗角
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.62;
	float vg = vignette * smoothstep(0.22, 0.8, length(d));
	col *= 1.0 - clamp(vg, 0.0, 1.0) * 0.9;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
