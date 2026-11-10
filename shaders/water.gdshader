// 港口海水：缓慢起伏、色块化的波纹、朝着晨光方向渐亮、零星的高光笔触
shader_type spatial;

uniform vec4 deep_color : source_color = vec4(0.03, 0.08, 0.10, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.07, 0.19, 0.20, 1.0);
uniform vec4 dawn_color : source_color = vec4(0.55, 0.30, 0.22, 1.0);
uniform vec4 dab_color : source_color = vec4(0.55, 0.75, 0.72, 1.0);
// 晨光来自的水平方向（世界坐标 xz）
uniform vec2 dawn_dir = vec2(0.85, 0.5);
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
	// 把波高分成三段色块
	float band = smoothstep(0.38, 0.42, h) * 0.5 + smoothstep(0.6, 0.64, h) * 0.5;
	vec3 c = mix(deep_color.rgb, shallow_color.rgb, band);
	// 朝晨光方向渐亮、偏暖
	float toward = dot(wpos.xz, normalize(dawn_dir));
	float dawn = smoothstep(4.0, 40.0, toward);
	c = mix(c, dawn_color.rgb, dawn * (0.25 + 0.45 * band));
	// 拉长的高光笔触
	vec2 q = vec2(dot(wpos.xz, vec2(0.7, 0.7)) * 0.35, dot(wpos.xz, vec2(-0.7, 0.7)) * 2.2);
	float dab = smoothstep(0.86, 0.9, vnoise(q + vec2(TIME * 0.12, TIME * 0.05)) * 0.7 + h * 0.3);
	ALBEDO = c;
	EMISSION = mix(dab_color.rgb, dawn_color.rgb * 1.6, dawn) * dab * 0.14;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
