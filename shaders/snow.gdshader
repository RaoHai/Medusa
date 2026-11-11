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
uniform sampler2D snow_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_snow_texture = false;
uniform bool use_road_texture = false;

varying vec3 wpos;
varying vec3 vpos_view;
uniform float camera_distance = 220.0;
// 极夜的雾：离画面中心（也就是人物）越远，越沉进蓝灰色的雾里
uniform vec3 fog_color : source_color = vec3(0.075, 0.09, 0.115);
uniform float fog_start = 28.0;
uniform float fog_end = 125.0;
uniform float fog_max : hint_range(0.0, 1.0) = 0.96;
// 路灯：xyz = 灯头下方的地面位置（y 不用），在雪地上画出钠灯的暖色光斑
uniform vec3 lamps[64];
uniform int lamp_count = 0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.62, 0.28);
uniform float lamp_radius = 7.5;

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
float night_fog(vec3 v, float cam_dist) {
	float dist = length(vec3(v.xy, v.z + cam_dist));
	return smoothstep(fog_start, fog_end, dist) * fog_max;
}

float seg_dist(vec2 p, vec2 a, vec2 b, out float side) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	vec2 d = p - (a + ab * t);
	side = dot(d, normalize(vec2(-ab.y, ab.x)));
	return length(d);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vpos_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 w = normalize(wind_dir);
	// 沿风向拉长的雪垄
	vec2 q = vec2(dot(p, w) * 0.05, dot(p, vec2(-w.y, w.x)) * 0.22);
	float drift = fbm(q + 5.0);
	float fine = vnoise(vec2(dot(p, w) * 0.3, dot(p, vec2(-w.y, w.x)) * 1.6));
	vec3 c = mix(hollow_color.rgb, snow_color.rgb, smoothstep(0.25, 0.7, drift));
	c *= 0.94 + 0.1 * fine;
	if (use_snow_texture) {
		// 两种尺度叠在一起，大面积雪地上看不出贴图在重复
		vec3 near_tex = texture(snow_texture, p / 4.0).rgb;
		vec3 far_tex = texture(snow_texture, p.yx / 23.0 + 0.37).rgb;
		c = mix(c, mix(near_tex, far_tex, 0.5) * mix(hollow_color.rgb, snow_color.rgb, drift) * 1.12, 0.8);
	}

	// 道路
	float road = 0.0;
	float rut = 0.0;
	vec2 road_uv = p;
	for (int i = 0; i < road_count; i++) {
		float side;
		float d = seg_dist(p, roads[i].xy, roads[i].zw, side);
		float hw = road_width[i] + (vnoise(p * 0.2 + float(i) * 7.0) - 0.5) * 1.6;
		float r_here = 1.0 - smoothstep(hw - 0.9, hw + 0.7, d);
		if (r_here > road) {
			road = r_here;
			// 道路自己的坐标：x 横跨路面，y 沿着路走。贴图里的车辙是竖向的，这样才会顺着路
			vec2 dir = normalize(roads[i].zw - roads[i].xy);
			road_uv = vec2(side, dot(p - roads[i].xy, dir));
		}
		float r = abs(abs(side) - road_width[i] * 0.42);
		rut = max(rut, (1.0 - smoothstep(0.15, 0.5, r)) * step(d, hw));
	}
	c = mix(c, road_color.rgb * (0.9 + 0.2 * vnoise(p * 1.7)), road * 0.85);
	if (use_road_texture) {
		c = mix(c, texture(road_texture, road_uv / 4.0).rgb, road * 0.9);
	} else {
		c = mix(c, rut_color.rgb, rut * 0.55 * (0.6 + 0.4 * vnoise(p * vec2(0.4, 3.0))));
	}

	// 冰晶反光
	float sparkle = step(0.994, hash(floor(p * 7.0))) * (1.0 - road);
	float pool = 0.0;
	for (int i = 0; i < lamp_count; i++) {
		vec2 d = p - lamps[i].xz;
		pool += exp(-dot(d, d) / (lamp_radius * lamp_radius));
	}
	pool = min(pool, 1.2);
	float fog = night_fog(vpos_view, camera_distance);
	ALBEDO = c * (1.0 - fog);
	EMISSION = (lamp_color * mix(vec3(0.6), c, 0.5) * pool * 0.8 + vec3(1.0, 0.9, 0.75) * sparkle * pool * 0.5) * (1.0 - fog * 0.6) + fog_color * fog;
	ROUGHNESS = mix(0.92, 0.5, road * 0.6);
	SPECULAR = 0.3;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
}
