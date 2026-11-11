// 预制板住宅楼 / 厂房的立面：按层数和开间程序化生成窗洞、板缝、亮灯的窗户、
// 可选的横向色带（厂房的蓝白条纹），以及墙根的积雪和檐下的霜。
// 用在 BoxMesh 上：size 传入盒子的尺寸，窗洞按盒子的本地坐标排布。
shader_type spatial;

uniform vec3 size = vec3(10.0, 6.0, 4.0);
uniform vec4 wall_color : source_color = vec4(0.72, 0.70, 0.68, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.16, 0.30, 0.62, 1.0);
uniform float stripe_amount : hint_range(0.0, 1.0) = 0.0;
uniform float floor_height = 1.8;
uniform float bay_width = 1.6;
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.15;
uniform float seed = 0.0;
// 1 = 废墟：窗洞是空的，墙面剥落
uniform float ruined : hint_range(0.0, 1.0) = 0.0;
uniform float windows : hint_range(0.0, 1.0) = 1.0;
uniform float frost : hint_range(0.0, 1.0) = 0.6;
uniform float banding : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D facade_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_facade_texture = false;
uniform bool use_wall_texture = false;
uniform bool use_snow_texture = false;
uniform float wall_texture_meters = 3.0;

varying vec3 lpos;
varying vec3 lnorm;
varying vec3 wpos;
// 人物被挡住时的镂空：相机始终对着人物（见 camera_rig.gd），所以人物在视图空间里
// 位于 (0, 0, -camera_distance)。片元比人物离相机近、且落在画面中心附近时，按抖动图案丢弃。
uniform float camera_distance = 90.0;
varying vec3 vpos_view;
// 极夜的雾：离画面中心（也就是人物）越远，越沉进蓝灰色的雾里
uniform vec3 fog_color : source_color = vec3(0.075, 0.09, 0.115);
uniform float fog_start = 12.0;
uniform float fog_end = 46.0;
uniform float fog_max : hint_range(0.0, 1.0) = 0.96;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float night_fog(vec3 v, float cam_dist) {
	float dist = length(vec3(v.xy, v.z + cam_dist));
	return smoothstep(fog_start, fog_end, dist) * fog_max;
}

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	vec3 c = wall_color.rgb;
	vec3 emit = vec3(0.0);
	float rough = 0.9;
	float n = vnoise(wpos.xz * 1.3 + wpos.y * 2.1) * 0.6 + vnoise(wpos.xy * 4.0 + wpos.z) * 0.4;

	if (lnorm.y > 0.5) {
		// 顶面：积雪
		c = mix(vec3(0.78, 0.83, 0.94), vec3(0.93, 0.95, 0.99), n);
		if (use_snow_texture) {
			c = texture(snow_texture, wpos.xz / 4.0).rgb;
		}
	} else if (lnorm.y > -0.5) {
		bool x_face = abs(lnorm.x) > 0.5;
		float u = x_face ? lpos.z : lpos.x;
		float face_len = x_face ? size.z : size.x;
		float v = lpos.y + size.y * 0.5;
		float face_id = x_face ? (lnorm.x > 0.0 ? 1.0 : 2.0) : (lnorm.z > 0.0 ? 3.0 : 4.0);

		// 墙面：笔触 + 冷暖色偏 + 竖向污渍
		float drift = vnoise(wpos.xz * 0.5 + wpos.y * 0.3 + seed);
		c *= 0.86 + 0.28 * n;
		c = mix(c * vec3(0.84, 0.96, 1.14), c * vec3(1.14, 1.0, 0.84), smoothstep(0.3, 0.7, drift));
		float streak = vnoise(vec2(u * 2.5 + seed, v * 0.3));
		c = mix(c, c * vec3(0.6, 0.64, 0.72), smoothstep(0.6, 0.9, streak) * 0.5);
		// 剥落：废墟的抹灰大片脱落，露出暗色砖
		float peel = smoothstep(0.55, 0.62, vnoise(vec2(u, v) * 0.9 + seed * 3.0)) * ruined;
		c = mix(c, vec3(0.42, 0.26, 0.22) * (0.8 + 0.4 * n), peel * 0.7);

		// 横向色带（厂房）
		float fl = floor(v / floor_height);
		float stripe = step(0.5, fract(fl * 0.5)) * stripe_amount;
		c = mix(c, stripe_color.rgb * (0.85 + 0.3 * n), stripe);

		// 板缝
		float fu = fract(u / bay_width + 0.5);
		float fv = fract(v / floor_height);
		float seam = max(1.0 - smoothstep(0.0, 0.04, min(fu, 1.0 - fu)), 1.0 - smoothstep(0.0, 0.05, min(fv, 1.0 - fv)));
		c *= 1.0 - seam * 0.22 * (1.0 - stripe);

		// 窗洞（离两端留出半个开间）
		float in_len = step(abs(u), face_len * 0.5 - bay_width * 0.35);
		float in_h = step(v, size.y - 0.15);
		float win = step(0.25, fu) * step(fu, 0.75) * step(0.28, fv) * step(fv, 0.78) * in_len * in_h * windows;
		if (win > 0.5) {
			vec2 id = vec2(floor(u / bay_width + 0.5), fl) + face_id * 17.0 + seed;
			float r = hash(id);
			float is_lit = step(r, lit_ratio) * (1.0 - ruined);
			// 窗框十字
			float cross_bar = max(1.0 - smoothstep(0.0, 0.03, abs(fu - 0.5)), 1.0 - smoothstep(0.0, 0.04, abs(fv - 0.53)));
			vec3 dark = mix(vec3(0.10, 0.13, 0.20), vec3(0.04, 0.05, 0.08), ruined);
			vec3 glow = mix(vec3(1.0, 0.72, 0.36), vec3(0.45, 0.95, 0.9), step(0.8, hash(id + 3.0)));
			c = mix(dark, wall_color.rgb * 0.55, cross_bar * (1.0 - ruined));
			emit = glow * is_lit * (1.0 - cross_bar * 0.6) * (1.6 + hash(id + 9.0));
			rough = mix(0.25, 0.9, ruined);
		}
		// 可选立面贴图，保留程序化灯光。
		if (use_wall_texture && win < 0.5) {
			c = mix(c, texture(wall_texture, vec2(u, -v) / wall_texture_meters).rgb, 0.8);
		}
		if (use_facade_texture && in_len * in_h * windows > 0.5) {
			vec4 facade = texture(facade_texture, vec2(fu, 1.0 - fv));
			// 裁切而非半透明混合，保持墙体的深度和阴影正确。
			if (ruined > 0.5 && facade.a < 0.5) { discard; }
			c = facade.rgb * mix(vec3(1.0), wall_color.rgb, 0.15);
		}
		// 窗台上的积雪
		float sill = step(0.25, fu) * step(fu, 0.75) * step(0.24, fv) * step(fv, 0.29) * in_len * in_h * windows;
		c = mix(c, vec3(0.92, 0.94, 0.99), sill);

		// 墙根的雪堆、檐下和墙面的霜
		float base = 1.0 - smoothstep(0.15, 0.7 + 0.5 * vnoise(vec2(u * 0.8, seed)), v);
		float top = smoothstep(size.y - 0.9, size.y, v) * vnoise(vec2(u * 1.7, seed + 4.0));
		float rime = smoothstep(0.62, 0.8, vnoise(vec2(u * 0.6, v * 0.9) + seed * 2.0)) * 0.6;
		float fr = clamp(base + (top + rime) * frost, 0.0, 1.0) * (1.0 - step(0.5, win) * 0.8);
		c = mix(c, vec3(0.88, 0.91, 0.98), fr * frost + base * (1.0 - frost));
	}
	float fog = night_fog(vpos_view, camera_distance);
	ALBEDO = c * (1.0 - fog);
	ROUGHNESS = rough;
	// 远处的亮窗在雾里还剩一点光
	EMISSION = emit * (1.0 - fog * 0.75) + fog_color * fog;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float soft = clamp(ndl, 0.0, 1.0);
	float hard = smoothstep(0.0, 0.06, ndl) * 0.5 + smoothstep(0.42, 0.5, ndl) * 0.3 + smoothstep(0.78, 0.86, ndl) * 0.2;
	DIFFUSE_LIGHT += mix(soft, hard, banding) * ATTENUATION * LIGHT_COLOR;
}
