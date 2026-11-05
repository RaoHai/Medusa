// 湿漉漉的鹅卵石路面，带积水反光
shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.30, 0.31, 0.32, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.12, 0.12, 0.13, 1.0);
uniform vec4 puddle_color : source_color = vec4(0.10, 0.13, 0.16, 1.0);
uniform float stone_scale = 2.2;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.45;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * stone_scale;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float stone = smoothstep(0.03, 0.14, e);
	float tint = hash(cell);
	vec3 sc = stone_color.rgb * (0.75 + tint * 0.45);
	sc *= 0.85 + 0.3 * vnoise(wpos.xz * 9.0);
	vec3 c = mix(mortar_color.rgb, sc, stone);

	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.08, fbm(wpos.xz * 0.22 + 3.0));
	c = mix(c, puddle_color.rgb, puddle * 0.75);
	// 屋檐下与墙根更暗
	c *= 0.8 + 0.2 * smoothstep(-10.5, -8.0, min(wpos.x, wpos.z));
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.55, 0.78, stone), 0.04, puddle);
	SPECULAR = mix(0.5, 0.9, puddle);
}
