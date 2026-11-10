// 全屏油画后处理：
//  Kuwahara 滤波（色块笔触）→ 笔触方向的涂抹 → 墨线 → 冷暖分离调色 →
//  整幅画面的色彩晕染 → 厚涂笔触纹理 → 画布纹理 → 暗角
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int radius : hint_range(0, 6) = 3;
// 采样步长（像素）。画面越大可以调得越大
uniform float brush_size : hint_range(0.5, 3.0) = 1.35;
uniform float brush_jitter : hint_range(0.0, 6.0) = 3.0;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec3 outline_color : source_color = vec3(0.06, 0.05, 0.09);
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.08;
uniform vec3 shadow_tint : source_color = vec3(0.07, 0.20, 0.24);
uniform vec3 midtone_tint : source_color = vec3(1.0, 0.97, 0.94);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.88, 0.68);
uniform float color_wash : hint_range(0.0, 0.5) = 0.14;
uniform float impasto : hint_range(0.0, 0.5) = 0.16;
uniform float canvas_grain : hint_range(0.0, 0.3) = 0.08;
uniform float vignette : hint_range(0.0, 1.5) = 0.6;

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

	// 1) 笔触扰动：沿两个斜向的各向异性噪声扭曲采样坐标，边缘会变得毛糙
	vec2 r1 = vec2(fc.x * 0.7 + fc.y * 0.7, -fc.x * 0.7 + fc.y * 0.7);
	vec2 warp = vec2(vnoise(r1 * vec2(0.11, 0.022)), vnoise(r1 * vec2(0.022, 0.11) + 13.0)) - 0.5;
	uv += warp * px * brush_jitter * 2.0;

	// 2) Kuwahara：四个象限里取方差最小者的均值
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
	vec3 col = m0;
	float best = v0;
	if (v1 < best) { best = v1; col = m1; }
	if (v2 < best) { best = v2; col = m2; }
	if (v3 < best) { best = v3; col = m3; }

	// 3) 墨线：亮度 Sobel，线条粗细随噪声变化，颜色是深紫而不是纯黑
	float w = 1.2 + 1.2 * vnoise(fc * 0.02);
	float tl = luma(textureLod(screen_tex, uv + px * vec2(-w, -w), 0.0).rgb);
	float tr = luma(textureLod(screen_tex, uv + px * vec2(w, -w), 0.0).rgb);
	float bl = luma(textureLod(screen_tex, uv + px * vec2(-w, w), 0.0).rgb);
	float br = luma(textureLod(screen_tex, uv + px * vec2(w, w), 0.0).rgb);
	float edge = length(vec2(tr + br - tl - bl, bl + br - tl - tr));
	float ink = smoothstep(0.1, 0.34, edge) * outline_strength;
	col = mix(col, outline_color, ink);

	// 4) 冷暖分离调色：暗部压向青绿，亮部推向暖黄
	float l = luma(col);
	col = (col - 0.5) * contrast + 0.5;
	col = max(col, vec3(0.0));
	col += shadow_tint * pow(1.0 - clamp(l, 0.0, 1.0), 2.5) * 0.55;
	col *= mix(midtone_tint, highlight_tint, smoothstep(0.3, 0.85, l));
	// 提饱和时保护已经很鲜艳的颜色
	float sat_now = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
	col = mix(vec3(luma(col)), col, mix(saturation, 1.0, clamp(sat_now * 1.5, 0.0, 1.0) * 0.5));

	// 5) 色彩晕染：整幅画面上缓慢变化的冷暖色斑，像底色透出来
	float wash = vnoise(fc * 0.0035 + 4.0) * 0.6 + vnoise(fc * 0.011) * 0.4;
	vec3 wash_col = mix(vec3(0.86, 1.0, 1.1), vec3(1.14, 1.0, 0.86), smoothstep(0.3, 0.7, wash));
	col *= mix(vec3(1.0), wash_col, color_wash * 2.0);

	// 6) 厚涂：斜向短笔触的明暗起伏，亮部更明显
	float st = vnoise(r1 * vec2(0.035, 0.35)) * 0.6 + vnoise(r1 * vec2(0.09, 0.9) + 31.0) * 0.4;
	col *= 1.0 + impasto * (st - 0.5) * (0.6 + l);

	// 7) 画布纹理（经纬纤维 + 颗粒）
	float weave = (vnoise(fc * vec2(0.9, 0.12)) + vnoise(fc * vec2(0.12, 0.9))) * 0.5;
	float grain = hash(fc + fract(TIME) * 37.0);
	col *= 1.0 - canvas_grain * ((weave - 0.5) * 1.4 + (grain - 0.5) * 0.5);

	// 8) 暗角（偏紫而不是纯黑）
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.6;
	float vg = vignette * smoothstep(0.25, 0.8, length(d));
	col = mix(col, col * vec3(0.10, 0.08, 0.16), clamp(vg, 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
