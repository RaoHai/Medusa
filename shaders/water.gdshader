// 港口海水：缓慢起伏 + 噪声法线
shader_type spatial;

uniform vec4 deep_color : source_color = vec4(0.03, 0.07, 0.085, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.09, 0.16, 0.17, 1.0);
uniform float wave_height = 0.06;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float height(vec2 p, float t) {
	float h = sin(dot(p, vec2(0.9, 0.4)) * 1.7 + t * 1.1) * 0.35;
	h += sin(dot(p, vec2(-0.3, 1.0)) * 2.9 - t * 1.6) * 0.2;
	h += sin(dot(p, vec2(0.7, -0.7)) * 5.3 + t * 2.3) * 0.1;
	h += vnoise(p * 0.35 + vec2(t * 0.05, 0.0)) * 0.35;
	return h * 0.5 + 0.5;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (sin(wpos.x * 0.5 + TIME * 0.8) + cos(wpos.z * 0.7 + TIME * 1.1)) * wave_height;
}

void fragment() {
	float h = height(wpos.xz, TIME);
	float hx = height(wpos.xz + vec2(0.05, 0.0), TIME) - h;
	float hz = height(wpos.xz + vec2(0.0, 0.05), TIME) - h;
	vec3 nw = normalize(vec3(-hx * 4.0, 1.0, -hz * 4.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, h);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
}
