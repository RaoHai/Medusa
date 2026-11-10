// 湿漉漉的石板路：不规则的石块（Voronoi）、杂色、积水反光
shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.33, 0.32, 0.31, 1.0);
uniform vec4 stone_color_b : source_color = vec4(0.39, 0.33, 0.26, 1.0);
uniform vec4 stone_color_c : source_color = vec4(0.25, 0.30, 0.31, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.09, 0.10, 0.11, 1.0);
uniform vec4 puddle_color : source_color = vec4(0.07, 0.11, 0.14, 1.0);
uniform float stone_scale = 2.5;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.45;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 稍微扭曲一下坐标，让石缝不那么笔直
	vec2 p = wpos.xz * stone_scale;
	p += (vec2(vnoise(p * 0.7), vnoise(p * 0.7 + 9.0)) - 0.5) * 0.5;
	p.x *= 0.72; // 长方形石块
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.5 + 0.38 * (hash2(cell + g) - 0.5) * 2.0;
			vec2 r = g + o - f;
			// 切比雪夫距离 → 偏方的石块
			float d = max(abs(r.x), abs(r.y)) * 0.8 + length(r) * 0.2;
			if (d < d1) { d2 = d1; d1 = d; id = cell + g; }
			else if (d < d2) { d2 = d; }
		}
	}
	float edge = d2 - d1;
	float stone = smoothstep(0.025, 0.09, edge);
	float t = hash(id);
	float t2 = hash(id + 31.7);
	vec3 sc = stone_color.rgb;
	sc = mix(sc, stone_color_b.rgb, smoothstep(0.62, 0.7, t));
	sc = mix(sc, stone_color_c.rgb, smoothstep(0.82, 0.88, t2));
	sc *= 0.72 + t2 * 0.5;
	// 石块表面的笔触
	sc *= 0.86 + 0.28 * vnoise(wpos.xz * vec2(7.0, 2.5) + id);
	// 石块边缘略亮（被磨圆的棱）
	sc *= 1.0 + 0.18 * smoothstep(0.12, 0.2, edge) * (1.0 - smoothstep(0.2, 0.34, edge));
	vec3 c = mix(mortar_color.rgb, sc, stone);

	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.06, fbm(wpos.xz * 0.22 + 3.0));
	c = mix(c, puddle_color.rgb, puddle * 0.8);
	// 墙根更暗
	c *= 0.72 + 0.28 * smoothstep(-10.8, -8.0, min(wpos.x, wpos.z));
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.45, 0.7, stone), 0.03, puddle);
	SPECULAR = mix(0.5, 0.95, puddle);
}
