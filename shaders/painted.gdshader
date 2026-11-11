// 通用“手绘”表面：
//  - 分段（色块化）的漫反射，像用几笔颜料铺出明暗
//  - 基于世界坐标的笔触噪声、冷暖色偏、竖向雨渍、底部积垢
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float variation : hint_range(0.0, 1.0) = 0.22;
uniform float noise_scale = 1.4;
uniform float grime = 0.35;
uniform sampler2D surface_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_surface_texture = false;
uniform vec2 texture_meters = vec2(3.0);
uniform bool texture_mesh_uv = false;
uniform vec2 texture_uv_scale = vec2(1.0);
uniform bool texture_uv_swap = false;
// 色偏强度：同一块颜色里混入偏暖 / 偏冷的笔触
uniform float hue_drift : hint_range(0.0, 1.0) = 0.35;
// 明暗分段的硬度（0 = 平滑，1 = 赛璐璐）
uniform float banding : hint_range(0.0, 1.0) = 0.8;

varying vec3 wpos;
varying vec3 wnorm;
// 人物被挡住时的镂空：相机始终对着人物（见 camera_rig.gd），所以人物在视图空间里
// 位于 (0, 0, -camera_distance)。片元比人物离相机近、且落在画面中心附近时，按抖动图案丢弃。
uniform float camera_distance = 90.0;
varying vec3 vpos_view;
// 极夜的雾：离画面中心（也就是人物）越远，越沉进蓝灰色的雾里
uniform vec3 fog_color : source_color = vec3(0.075, 0.09, 0.115);
uniform float fog_start = 12.0;
uniform float fog_end = 46.0;
uniform float fog_max : hint_range(0.0, 1.0) = 0.96;

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

float night_fog(vec3 v, float cam_dist) {
	float dist = length(vec3(v.xy, v.z + cam_dist));
	return smoothstep(fog_start, fog_end, dist) * fog_max;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vpos_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	{
		float ahead = vpos_view.z + camera_distance;
		float d = length(vpos_view.xy - vec2(0.0, 0.6));
		float cut = (1.0 - smoothstep(3.0, 5.5, d)) * smoothstep(1.2, 2.5, ahead);
		float dither = fract(dot(floor(FRAGCOORD.xy), vec2(0.7548777, 0.5698403)));
		if (cut > dither * 0.9 + 0.1) {
			discard;
		}
	}
	float n = noise3(wpos * noise_scale) * 0.6 + noise3(wpos * noise_scale * 3.1) * 0.4;
	// 斜向的长笔触
	vec3 sp = vec3(dot(wpos.xz, vec2(0.7, 0.7)) * 0.9, wpos.y * 4.5 + dot(wpos.xz, vec2(-0.7, 0.7)) * 3.0, 0.0);
	float stroke = noise3(sp * noise_scale);
	float streak = noise3(vec3(wpos.x * 3.0, wpos.y * 0.35, wpos.z * 3.0));
	vec3 c = albedo.rgb * (1.0 + variation * (n - 0.5) * 2.0);
	c *= 1.0 + variation * 0.6 * (stroke - 0.5);
	// 冷暖色偏
	float drift = noise3(wpos * noise_scale * 0.45 + 17.0);
	vec3 warm = c * vec3(1.18, 1.0, 0.78);
	vec3 cool = c * vec3(0.82, 1.0, 1.2);
	c = mix(c, mix(cool, warm, smoothstep(0.3, 0.7, drift)), hue_drift);
	c = mix(c, c * vec3(0.62, 0.68, 0.74), smoothstep(0.55, 0.85, streak) * grime);
	c *= mix(1.0 - grime * 0.6, 1.0, smoothstep(0.0, 1.4, wpos.y));
	if (use_surface_texture) {
		vec3 an = abs(wnorm);
		vec2 uv = an.y > max(an.x, an.z) ? wpos.xz : (an.x > an.z ? vec2(wpos.z, -wpos.y) : vec2(wpos.x, -wpos.y));
		vec2 mesh_uv = texture_uv_swap ? UV.yx : UV;
		uv = texture_mesh_uv ? mesh_uv * texture_uv_scale : uv / texture_meters;
		vec3 surface = texture(surface_texture, uv).rgb;
		c = mix(c, surface * mix(vec3(1.0), albedo.rgb, 0.2), 0.85);
	}
	float fog = night_fog(vpos_view, camera_distance);
	ALBEDO = c * (1.0 - fog);
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy * (1.0 - fog * 0.7) + fog_color * fog;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float soft = clamp(ndl, 0.0, 1.0);
	float hard = smoothstep(0.0, 0.06, ndl) * 0.5 + smoothstep(0.42, 0.5, ndl) * 0.3 + smoothstep(0.78, 0.86, ndl) * 0.2;
	DIFFUSE_LIGHT += mix(soft, hard, banding) * ATTENUATION * LIGHT_COLOR;
}
