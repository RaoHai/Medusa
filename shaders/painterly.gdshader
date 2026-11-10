// 全屏油画后处理：Kuwahara 滤波（笔触色块）+ 笔触扰动 + 墨线 + 色调分级 + 画布纹理 + 暗角
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int radius : hint_range(0, 6) = 3;
uniform float brush_jitter : hint_range(0.0, 4.0) = 1.6;
uniform float outline_strength : hint_range(0.0, 1.0) = 0.35;
uniform float saturation : hint_range(0.0, 2.0) = 0.92;
uniform vec3 shadow_tint : source_color = vec3(0.10, 0.17, 0.20);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.93, 0.80);
uniform float canvas_grain : hint_range(0.0, 0.3) = 0.07;
uniform float vignette : hint_range(0.0, 1.5) = 0.75;

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

	// 1) 笔触扰动：用低频各向异性噪声轻微扭曲采样坐标
	vec2 fc = FRAGCOORD.xy;
	vec2 warp = vec2(vnoise(fc * vec2(0.08, 0.025)), vnoise(fc * vec2(0.025, 0.08) + 13.0)) - 0.5;
	uv += warp * px * brush_jitter * 2.0;

	// 2) Kuwahara：四个象限取方差最小者的均值
	vec3 m0 = vec3(0.0), m1 = vec3(0.0), m2 = vec3(0.0), m3 = vec3(0.0);
	vec3 s0 = vec3(0.0), s1 = vec3(0.0), s2 = vec3(0.0), s3 = vec3(0.0);
	for (int j = -radius; j <= radius; j++) {
		for (int i = -radius; i <= radius; i++) {
			vec3 c = textureLod(screen_tex, uv + vec2(float(i), float(j)) * px, 0.0).rgb;
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

	// 3) 墨线：亮度 Sobel
	float tl = luma(textureLod(screen_tex, uv + px * vec2(-1.5, -1.5), 0.0).rgb);
	float tr = luma(textureLod(screen_tex, uv + px * vec2(1.5, -1.5), 0.0).rgb);
	float bl = luma(textureLod(screen_tex, uv + px * vec2(-1.5, 1.5), 0.0).rgb);
	float br = luma(textureLod(screen_tex, uv + px * vec2(1.5, 1.5), 0.0).rgb);
	float edge = length(vec2(tr + br - tl - bl, bl + br - tl - tr));
	col *= 1.0 - outline_strength * smoothstep(0.08, 0.35, edge);

	// 4) 色调分级：暗部偏青，亮部偏暖，略降饱和
	float l = luma(col);
	col += shadow_tint * pow(1.0 - clamp(l, 0.0, 1.0), 3.0) * 0.6;
	col *= mix(vec3(1.0), highlight_tint, smoothstep(0.35, 0.9, l));
	col = mix(vec3(luma(col)), col, saturation);

	// 5) 画布纹理（经纬纤维 + 颗粒）
	float weave = (vnoise(fc * vec2(0.9, 0.12)) + vnoise(fc * vec2(0.12, 0.9))) * 0.5;
	float grain = hash(fc + fract(TIME) * 37.0);
	col *= 1.0 - canvas_grain * ((weave - 0.5) * 1.4 + (grain - 0.5) * 0.6);

	// 6) 暗角
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.6;
	col *= 1.0 - vignette * smoothstep(0.25, 0.75, length(d));

	COLOR = vec4(col, 1.0);
}
