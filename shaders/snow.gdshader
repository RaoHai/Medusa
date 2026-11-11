// 雪原地面：风吹出的雪垄、蓝紫色的凹处、压实的道路和车辙、零星的冰晶反光
shader_type spatial;

uniform vec4 snow_color : source_color = vec4(0.96, 0.97, 1.0, 1.0);
uniform vec4 hollow_color : source_color = vec4(0.82, 0.87, 0.97, 1.0);
uniform vec4 road_color : source_color = vec4(0.66, 0.69, 0.78, 1.0);
uniform vec4 rut_color : source_color = vec4(0.40, 0.43, 0.54, 1.0);
// 道路线段：xy = 起点 xz，zw = 终点 xz；road_width 是对应的半宽
uniform vec4 roads[8];
uniform float road_width[8];
uniform int road_count = 0;
uniform vec2 wind_dir = vec2(0.8, 0.6);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
// 点到线段的距离，t 返回沿线段的位置
float seg_dist(vec2 p, vec2 a, vec2 b, out float side) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	vec2 d = p - (a + ab * t);
	side = dot(d, normalize(vec2(-ab.y, ab.x)));
	return length(d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 w = normalize(wind_dir);
	// 沿风向拉长的雪垄
	vec2 q = vec2(dot(p, w) * 0.12, dot(p, vec2(-w.y, w.x)) * 0.55);
	float drift = fbm(q + 5.0);
	float fine = vnoise(vec2(dot(p, w) * 0.6, dot(p, vec2(-w.y, w.x)) * 3.5));
	vec3 c = mix(hollow_color.rgb, snow_color.rgb, smoothstep(0.25, 0.7, drift));
	c *= 0.94 + 0.1 * fine;

	// 道路
	float road = 0.0;
	float rut = 0.0;
	for (int i = 0; i < road_count; i++) {
		float side;
		float d = seg_dist(p, roads[i].xy, roads[i].zw, side);
		float hw = road_width[i] + (vnoise(p * 0.35 + float(i) * 7.0) - 0.5) * 0.9;
		road = max(road, 1.0 - smoothstep(hw - 0.5, hw + 0.4, d));
		float r = abs(abs(side) - road_width[i] * 0.42);
		rut = max(rut, (1.0 - smoothstep(0.1, 0.32, r)) * step(d, hw));
	}
	c = mix(c, road_color.rgb * (0.9 + 0.2 * vnoise(p * 1.7)), road * 0.85);
	c = mix(c, rut_color.rgb, rut * 0.55 * (0.6 + 0.4 * vnoise(p * vec2(0.4, 3.0))));

	// 冰晶反光
	float sparkle = step(0.992, hash(floor(p * 9.0))) * (1.0 - road);
	ALBEDO = c;
	EMISSION = vec3(1.0, 0.95, 0.9) * sparkle * 0.25;
	ROUGHNESS = mix(0.92, 0.5, road * 0.6);
	SPECULAR = 0.3;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
}
