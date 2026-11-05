// 通用“手绘”表面：基于世界坐标的笔触噪声、竖向雨渍、底部积垢
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float variation : hint_range(0.0, 1.0) = 0.22;
uniform float noise_scale = 1.4;
uniform float grime = 0.35;

varying vec3 wpos;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise3(wpos * noise_scale) * 0.6 + noise3(wpos * noise_scale * 3.1) * 0.4;
	float streak = noise3(vec3(wpos.x * 3.0, wpos.y * 0.35, wpos.z * 3.0));
	vec3 c = albedo.rgb * (1.0 + variation * (n - 0.5) * 2.0);
	c = mix(c, c * 0.72, smoothstep(0.55, 0.85, streak) * grime);
	c *= mix(1.0 - grime * 0.6, 1.0, smoothstep(0.0, 1.4, wpos.y));
	ALBEDO = c;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy;
}
