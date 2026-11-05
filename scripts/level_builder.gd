@tool
extends Node3D
## 程序化搭建“维斯珀港”码头场景：鹅卵石街道、旅馆/仓库立面、栈桥、海水、
## 路灯、火桶、电话亭、木箱、小船、远处的灯塔。
## 带 StaticBody3D 碰撞（layer 1），供 NavigationRegion3D 烘焙导航网格。
## 这是 @tool 脚本，在编辑器里打开场景时也能直接看到。

const PAINTED := preload("res://shaders/painted.gdshader")
const COBBLES := preload("res://shaders/cobbles.gdshader")
const WATER := preload("res://shaders/water.gdshader")

## 在检查器里勾选即可重建
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			build()

var _t := 0.0
var _fire_light: OmniLight3D
var _lamp_light: OmniLight3D
var _neon: Array[Node3D] = []
var _neon_light: OmniLight3D
var _boat: Node3D
var _cjk_font: SystemFont


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_neon.clear()
	_cjk_font = SystemFont.new()
	_cjk_font.font_names = PackedStringArray(["Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "SimSun", "Noto Sans CJK SC", "Microsoft YaHei", "PingFang SC", "WenQuanYi Zen Hei"])

	_build_ground()
	_build_water()
	_build_pier()
	_build_buildings()
	_build_lamp(Vector3(-3, 0, -3))
	_build_bench(Vector3(-5.5, 0, 0.4))
	_build_fire_barrel(Vector3(3, 0, -5))
	_build_phone_booth(Vector3(-8.5, 0, -7.5))
	_build_crates(Vector3(6.5, 0, 0))
	_build_puddle(Vector3(-1, 0, -1.5))
	_build_bollards()
	_build_boat(Vector3(5.7, -0.45, 10.5))
	_build_lighthouse(Vector3(-24, -0.6, 15))
	_build_wires()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _fire_light:
		_fire_light.light_energy = 2.6 + sin(_t * 13.0) * 0.35 + sin(_t * 7.3) * 0.4 + randf() * 0.25
	if _lamp_light:
		_lamp_light.light_energy = 2.2 + (randf() * 0.6 if fmod(_t, 9.0) < 0.25 else 0.0)
	# 霓虹偶尔闪烁
	var on := not (fmod(_t, 5.3) < 0.12 or fmod(_t + 1.1, 7.7) < 0.08)
	for n in _neon:
		n.visible = on
	if _neon_light:
		_neon_light.visible = on
	if _boat:
		_boat.position.y = -0.45 + sin(_t * 1.1) * 0.06
		_boat.rotation.z = sin(_t * 0.9) * 0.03
		_boat.rotation.x = sin(_t * 0.7 + 1.0) * 0.02


# ================================================================ 场景各部分
func _build_ground() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = COBBLES
	# 街面（顶面 y=0），x: -11..10, z: -11..4
	_box(Vector3(21, 2.0, 15), Vector3(-0.5, -1.0, -3.5), Color.GRAY, true, 0.0, mat)
	# 码头岸边石沿（栈桥处断开）
	var curb := Color(0.36, 0.35, 0.33)
	_box(Vector3(12.3, 0.14, 0.35), Vector3(-4.85, 0.07, 3.82), curb, true)
	_box(Vector3(5.8, 0.14, 0.35), Vector3(7.1, 0.07, 3.82), curb, true)
	_box(Vector3(0.35, 0.14, 15), Vector3(9.82, 0.07, -3.5), curb, true)
	# 岸壁
	_box(Vector3(21.2, 1.4, 0.4), Vector3(-0.5, -0.75, 4.15), Color(0.22, 0.22, 0.22), false)
	_box(Vector3(0.4, 1.4, 15.4), Vector3(10.15, -0.75, -3.5), Color(0.22, 0.22, 0.22), false)


func _build_water() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = WATER
	var plane := PlaneMesh.new()
	plane.size = Vector2(140, 140)
	plane.subdivide_width = 70
	plane.subdivide_depth = 70
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(10, -0.65, 15)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_pier() -> void:
	var wood := Color(0.30, 0.23, 0.17)
	var x0 := 1.5
	var x1 := 4.0
	var z0 := 3.9
	var z1 := 13.0
	# 不可见的整体碰撞（顶面 y=0.02）
	_collider_box(Vector3(x1 - x0, 0.2, z1 - z0), Vector3((x0 + x1) * 0.5, -0.08, (z0 + z1) * 0.5))
	var z := z0 + 0.15
	var i := 0
	while z < z1:
		var shade := 0.85 + 0.3 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		_box(Vector3(x1 - x0 + randf_range(-0.05, 0.12), 0.08, 0.27), Vector3((x0 + x1) * 0.5 + randf_range(-0.04, 0.04), -0.02, z), wood * shade, false)
		z += 0.31
		i += 1
	# 纵梁与桩
	for x in [x0 + 0.1, x1 - 0.1]:
		_box(Vector3(0.18, 0.2, z1 - z0), Vector3(x, -0.16, (z0 + z1) * 0.5), wood * 0.6, false)
		var pz := z0 + 1.0
		while pz < z1 + 0.1:
			_cyl(0.13, 0.13, 1.6, Vector3(x, -0.6, pz), wood * 0.5, false)
			pz += 2.6
	# 栈桥尽头的系缆桩
	_cyl(0.16, 0.2, 0.55, Vector3(x0 + 0.3, 0.27, z1 - 0.3), Color(0.12, 0.12, 0.13), true)
	_cyl(0.16, 0.2, 0.55, Vector3(x1 - 0.3, 0.27, z1 - 0.3), Color(0.12, 0.12, 0.13), true)


func _build_buildings() -> void:
	# 背面一排（正面朝 +Z，位于 z=-11）
	_facade_block(Vector3(-11, 0, -16), Vector3(-4, 8.0, -11), Color(0.42, 0.35, 0.26), "z", [
		Vector2(-9.5, 2.6), Vector2(-7.0, 2.6), Vector2(-9.5, 5.4), Vector2(-7.0, 5.4), Vector2(-5.2, 5.4),
	], [1, 3])
	_facade_block(Vector3(-4, 0, -16), Vector3(4, 9.5, -11), Color(0.22, 0.30, 0.29), "z", [
		Vector2(-2.6, 4.4), Vector2(2.6, 4.4), Vector2(-2.6, 7.0), Vector2(0.0, 7.0), Vector2(2.6, 7.0),
	], [0, 4])
	_facade_block(Vector3(4, 0, -16), Vector3(10, 6.0, -11), Color(0.34, 0.19, 0.15), "z", [
		Vector2(5.2, 4.6), Vector2(8.8, 4.6),
	], [])
	# 左侧一排（正面朝 +X，位于 x=-11）
	_facade_block(Vector3(-16, 0, -11), Vector3(-11, 7.0, 4), Color(0.30, 0.31, 0.26), "x", [
		Vector2(-9.0, 2.5), Vector2(-4.5, 2.5), Vector2(-1.5, 2.5), Vector2(1.8, 2.5),
		Vector2(-9.0, 5.2), Vector2(-6.0, 5.2), Vector2(-3.0, 5.2), Vector2(0.0, 5.2), Vector2(2.6, 5.2),
	], [2, 6])

	# 旅馆：门、雨棚、霓虹招牌
	_box(Vector3(1.5, 2.6, 0.2), Vector3(0, 1.3, -10.95), Color(0.16, 0.10, 0.07), false)
	_box(Vector3(1.8, 2.85, 0.12), Vector3(0, 1.4, -10.98), Color(0.08, 0.07, 0.06), false)
	var door_glow := _box(Vector3(1.1, 0.5, 0.05), Vector3(0, 2.25, -10.84), Color.BLACK, false)
	door_glow.material_override = _mat(Color(0.1, 0.07, 0.04), 0.3, Color(1.0, 0.7, 0.35), 1.6)
	var awning := _box(Vector3(3.2, 0.12, 1.3), Vector3(0, 3.05, -10.4), Color(0.35, 0.10, 0.09), false)
	awning.rotation.x = 0.18
	_box(Vector3(3.6, 0.9, 0.12), Vector3(0, 3.75, -10.92), Color(0.07, 0.07, 0.08), false)
	var sign := Label3D.new()
	sign.font = _cjk_font
	sign.text = "维斯珀  馆"
	sign.font_size = 110
	sign.pixel_size = 0.0055
	sign.outline_size = 0
	sign.shaded = false
	sign.double_sided = false
	sign.modulate = Color(1.6, 0.42, 0.62)
	sign.position = Vector3(0, 3.75, -10.83)
	add_child(sign)
	_neon.append(sign)
	var sign2 := Label3D.new()
	sign2.font = _cjk_font
	sign2.text = "HOTEL VESPER"
	sign2.font_size = 60
	sign2.pixel_size = 0.005
	sign2.shaded = false
	sign2.modulate = Color(0.45, 1.1, 1.3)
	sign2.position = Vector3(0, 3.38, -10.83)
	add_child(sign2)
	_neon.append(sign2)
	_neon_light = _omni(Vector3(0, 3.6, -9.8), Color(1.0, 0.4, 0.6), 1.6, 5.5, false)

	# 仓库卷帘门
	var shutter := _box(Vector3(3.4, 3.6, 0.1), Vector3(7, 1.8, -10.95), Color(0.30, 0.31, 0.30), false)
	shutter.material_override = _mat(Color(0.28, 0.29, 0.28), 0.5)
	for k in range(12):
		_box(Vector3(3.42, 0.03, 0.12), Vector3(7, 0.2 + k * 0.29, -10.9), Color(0.18, 0.18, 0.18), false)
	# 左侧楼的一个门洞
	_box(Vector3(0.2, 2.4, 1.3), Vector3(-10.95, 1.2, -1.5), Color(0.12, 0.09, 0.07), false)


func _facade_block(a: Vector3, b: Vector3, color: Color, facing: String, windows: Array, lit: Array) -> void:
	var size := b - a
	var center := (a + b) * 0.5
	_box(size, center, color, true)
	# 屋顶檐口与屋面
	_box(Vector3(size.x + 0.3, 0.3, size.z + 0.3), Vector3(center.x, b.y + 0.15, center.z), color * 0.55, false)
	# 一层墙裙
	if facing == "z":
		_box(Vector3(size.x, 1.0, 0.08), Vector3(center.x, 0.5, b.z + 0.04), color * 0.6, false)
		_box(Vector3(size.x, 0.18, 0.18), Vector3(center.x, 3.2, b.z + 0.08), color * 0.75, false)
		_cyl(0.06, 0.06, b.y, Vector3(b.x - 0.25, b.y * 0.5, b.z + 0.1), Color(0.15, 0.16, 0.16), false)
	else:
		_box(Vector3(0.08, 1.0, size.z), Vector3(b.x + 0.04, 0.5, center.z), color * 0.6, false)
		_box(Vector3(0.18, 0.18, size.z), Vector3(b.x + 0.08, 3.2, center.z), color * 0.75, false)
	# 窗
	for i in windows.size():
		var w: Vector2 = windows[i]
		var is_lit := lit.has(i)
		var glass: Material
		if is_lit:
			glass = _mat(Color(0.3, 0.22, 0.1), 0.3, Color(1.0, 0.72, 0.38), 2.2)
		else:
			glass = _mat(Color(0.06, 0.08, 0.10), 0.12)
		if facing == "z":
			_box(Vector3(1.2, 1.55, 0.1), Vector3(w.x, w.y, b.z + 0.03), color * 0.45, false)
			_box(Vector3(1.0, 1.35, 0.06), Vector3(w.x, w.y, b.z + 0.07), Color.BLACK, false).material_override = glass
			_box(Vector3(1.0, 0.05, 0.08), Vector3(w.x, w.y, b.z + 0.1), color * 0.45, false)
			_box(Vector3(1.35, 0.1, 0.22), Vector3(w.x, w.y - 0.82, b.z + 0.1), color * 0.7, false)
			if is_lit:
				_omni(Vector3(w.x, w.y, b.z + 1.2), Color(1.0, 0.7, 0.4), 0.6, 4.0, false)
		else:
			_box(Vector3(0.1, 1.55, 1.2), Vector3(b.x + 0.03, w.y, w.x), color * 0.45, false)
			_box(Vector3(0.06, 1.35, 1.0), Vector3(b.x + 0.07, w.y, w.x), Color.BLACK, false).material_override = glass
			_box(Vector3(0.08, 0.05, 1.0), Vector3(b.x + 0.1, w.y, w.x), color * 0.45, false)
			_box(Vector3(0.22, 0.1, 1.35), Vector3(b.x + 0.1, w.y - 0.82, w.x), color * 0.7, false)
			if is_lit:
				_omni(Vector3(b.x + 1.2, w.y, w.x), Color(1.0, 0.7, 0.4), 0.6, 4.0, false)
	# 烟囱
	var chimney_pos := Vector3(center.x + size.x * 0.25, b.y + 0.8, center.z - size.z * 0.15)
	_box(Vector3(0.6, 1.6, 0.6), chimney_pos, color * 0.5, false)


func _build_lamp(p: Vector3) -> void:
	var iron := Color(0.09, 0.10, 0.10)
	_cyl(0.2, 0.26, 0.4, p + Vector3(0, 0.2, 0), iron, true)
	_cyl(0.06, 0.08, 4.0, p + Vector3(0, 2.2, 0), iron, false)
	_box(Vector3(0.1, 0.08, 0.7), p + Vector3(0, 4.1, 0.3), iron, false)
	var head := _box(Vector3(0.36, 0.42, 0.36), p + Vector3(0, 3.85, 0.62), iron, false)
	_box(Vector3(0.28, 0.3, 0.28), Vector3(0, -0.06, 0), Color.BLACK, false, 0.0, _mat(Color(0.4, 0.3, 0.15), 0.3, Color(1.0, 0.78, 0.45), 4.0), head)
	_lamp_light = _omni(p + Vector3(0, 3.5, 0.62), Color(1.0, 0.76, 0.48), 2.2, 10.0, true)


func _build_bench(p: Vector3) -> void:
	var wood := Color(0.33, 0.22, 0.14)
	var iron := Color(0.08, 0.08, 0.09)
	var root := Node3D.new()
	root.position = p
	add_child(root)
	for k in range(4):
		_box(Vector3(2.0, 0.05, 0.1), Vector3(0, 0.46, -0.18 + k * 0.12), wood * (0.9 + k * 0.05), false, 0.0, null, root)
	for k in range(3):
		var slat := _box(Vector3(2.0, 0.1, 0.04), Vector3(0, 0.66 + k * 0.14, -0.28), wood, false, 0.0, null, root)
		slat.rotation.x = -0.12
	for x in [-0.85, 0.85]:
		_box(Vector3(0.06, 0.46, 0.5), Vector3(x, 0.23, -0.05), iron, false, 0.0, null, root)
		_box(Vector3(0.06, 0.55, 0.06), Vector3(x, 0.72, -0.3), iron, false, 0.0, null, root)
	_collider_box(Vector3(2.0, 0.9, 0.55), p + Vector3(0, 0.45, -0.08))


func _build_fire_barrel(p: Vector3) -> void:
	var rust := Color(0.30, 0.15, 0.08)
	_cyl(0.38, 0.38, 0.95, p + Vector3(0, 0.475, 0), rust, true)
	_cyl(0.395, 0.395, 0.05, p + Vector3(0, 0.25, 0), rust * 0.6, false)
	_cyl(0.395, 0.395, 0.05, p + Vector3(0, 0.75, 0), rust * 0.6, false)
	var embers := _cyl(0.34, 0.34, 0.04, p + Vector3(0, 0.9, 0), Color.BLACK, false)
	embers.material_override = _mat(Color(0.2, 0.05, 0.0), 0.9, Color(1.0, 0.35, 0.08), 3.0)
	# 火焰粒子
	var fire := CPUParticles3D.new()
	fire.position = p + Vector3(0, 0.95, 0)
	fire.amount = 46
	fire.lifetime = 0.8
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.22
	fire.direction = Vector3.UP
	fire.spread = 12.0
	fire.gravity = Vector3(0, 1.6, 0)
	fire.initial_velocity_min = 0.4
	fire.initial_velocity_max = 1.0
	fire.scale_amount_min = 0.6
	fire.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0))
	fire.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	grad.set_color(1, Color(0.8, 0.12, 0.02, 0.0))
	grad.add_point(0.4, Color(1.0, 0.45, 0.1, 0.9))
	fire.color_ramp = grad
	var q := SphereMesh.new()
	q.radius = 0.11
	q.height = 0.22
	q.radial_segments = 8
	q.rings = 4
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = fm
	fire.mesh = q
	add_child(fire)
	_fire_light = _omni(p + Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.2), 2.6, 7.0, true)


func _build_phone_booth(p: Vector3) -> void:
	var red := Color(0.50, 0.10, 0.08)
	var root := Node3D.new()
	root.position = p
	root.rotation.y = deg_to_rad(45)
	add_child(root)
	_box(Vector3(1.15, 0.12, 1.15), Vector3(0, 0.06, 0), red * 0.7, false, 0.0, null, root)
	_box(Vector3(1.2, 0.25, 1.2), Vector3(0, 2.5, 0), red, false, 0.0, null, root)
	_box(Vector3(1.0, 0.12, 1.0), Vector3(0, 2.68, 0), red * 0.8, false, 0.0, null, root)
	for c in [Vector2(-0.53, -0.53), Vector2(0.53, -0.53), Vector2(-0.53, 0.53), Vector2(0.53, 0.53)]:
		_box(Vector3(0.1, 2.3, 0.1), Vector3(c.x, 1.25, c.y), red, false, 0.0, null, root)
	var glass := _mat(Color(0.15, 0.22, 0.22), 0.1, Color(0.35, 0.6, 0.5), 0.35)
	for side in [Vector3(0, 0, 0.53), Vector3(0, 0, -0.53)]:
		_box(Vector3(0.96, 2.0, 0.03), Vector3(0, 1.2, side.z), Color.BLACK, false, 0.0, glass, root)
	for side in [Vector3(0.53, 0, 0), Vector3(-0.53, 0, 0)]:
		_box(Vector3(0.03, 2.0, 0.96), Vector3(side.x, 1.2, 0), Color.BLACK, false, 0.0, glass, root)
	for k in range(4):
		_box(Vector3(1.0, 0.04, 0.05), Vector3(0, 0.6 + k * 0.5, 0.55), red, false, 0.0, null, root)
	var top_sign := _box(Vector3(0.8, 0.16, 0.05), Vector3(0, 2.5, 0.61), Color.BLACK, false, 0.0, null, root)
	top_sign.material_override = _mat(Color(0.9, 0.9, 0.8), 0.4, Color(1.0, 0.95, 0.8), 1.2)
	_box(Vector3(0.25, 0.35, 0.15), Vector3(0, 1.45, -0.42), Color(0.08, 0.08, 0.08), false, 0.0, null, root)
	_omni(p + Vector3(0, 2.2, 0), Color(0.55, 0.9, 0.75), 0.7, 3.0, false)
	_collider_box(Vector3(1.2, 2.6, 1.2), p + Vector3(0, 1.3, 0), deg_to_rad(45))


func _build_crates(p: Vector3) -> void:
	var c1 := Color(0.40, 0.31, 0.19)
	var c2 := Color(0.33, 0.27, 0.17)
	_crate(p + Vector3(-0.5, 0.45, -0.4), 0.9, c1, 0.1)
	_crate(p + Vector3(0.5, 0.45, -0.3), 0.9, c2, -0.15)
	_crate(p + Vector3(0.0, 1.3, -0.35), 0.8, c1, 0.35)
	_crate(p + Vector3(0.2, 0.35, 0.6), 0.7, c2, 0.6)
	# 帆布
	var tarp := _box(Vector3(1.0, 0.04, 0.9), p + Vector3(0.05, 1.72, -0.35), Color(0.18, 0.24, 0.20), false)
	tarp.rotation = Vector3(0.1, 0.3, 0.08)
	# 小桶
	_cyl(0.25, 0.25, 0.7, p + Vector3(1.3, 0.35, 0.5), Color(0.20, 0.27, 0.32), true)
	_cyl(0.25, 0.25, 0.7, p + Vector3(1.4, 0.35, -0.2), Color(0.32, 0.20, 0.16), true)


func _crate(p: Vector3, s: float, c: Color, rot: float) -> void:
	var crate := _box(Vector3(s, s, s), p, c, true, rot)
	# 外框木条
	for k in [-1, 1]:
		_box(Vector3(s + 0.02, 0.08, s + 0.02), Vector3(0, k * s * 0.44, 0), c * 0.6, false, 0.0, null, crate)
		_box(Vector3(0.08, s, s + 0.02), Vector3(k * s * 0.44, 0, 0), c * 0.6, false, 0.0, null, crate)


func _build_puddle(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.07, 0.09)
	m.roughness = 0.02
	m.metallic_specular = 1.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.8
	mesh.bottom_radius = 0.8
	mesh.height = 0.01
	mesh.radial_segments = 24
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p + Vector3(0, 0.006, 0)
	mi.scale = Vector3(1.0, 1.0, 0.65)
	mi.rotation.y = 0.4
	add_child(mi)


func _build_bollards() -> void:
	for x in [-9.0, -5.5, -1.5, 6.0, 8.8]:
		_cyl(0.15, 0.2, 0.5, Vector3(x, 0.25, 3.55), Color(0.12, 0.12, 0.13), true)
		_cyl(0.22, 0.22, 0.06, Vector3(x, 0.52, 3.55), Color(0.12, 0.12, 0.13), false)
	# 盘起的缆绳
	var rope := TorusMesh.new()
	rope.inner_radius = 0.18
	rope.outer_radius = 0.36
	for k in range(3):
		var mi := MeshInstance3D.new()
		mi.mesh = rope
		mi.material_override = _mat(Color(0.45, 0.38, 0.26), 0.9)
		mi.position = Vector3(-4.6, 0.05 + k * 0.08, 3.1)
		mi.scale = Vector3.ONE * (1.0 - k * 0.12)
		add_child(mi)


func _build_boat(p: Vector3) -> void:
	_boat = Node3D.new()
	_boat.position = p
	add_child(_boat)
	var hull := Color(0.18, 0.25, 0.26)
	_box(Vector3(1.7, 0.7, 4.2), Vector3(0, 0, 0), hull, false, 0.0, null, _boat)
	var bow := _box(Vector3(1.2, 0.7, 1.2), Vector3(0, 0, 2.3), hull, false, 0.0, null, _boat)
	bow.rotation.y = deg_to_rad(45)
	_box(Vector3(1.75, 0.12, 4.25), Vector3(0, 0.38, 0), Color(0.55, 0.50, 0.42), false, 0.0, null, _boat)
	_box(Vector3(1.2, 0.9, 1.3), Vector3(0, 0.85, -0.8), Color(0.60, 0.56, 0.48), false, 0.0, null, _boat)
	_box(Vector3(1.35, 0.1, 1.5), Vector3(0, 1.33, -0.8), Color(0.25, 0.12, 0.10), false, 0.0, null, _boat)
	var win := _box(Vector3(1.0, 0.3, 0.05), Vector3(0, 0.95, -0.14), Color.BLACK, false, 0.0, null, _boat)
	win.material_override = _mat(Color(0.05, 0.07, 0.08), 0.1)
	_cyl(0.04, 0.05, 2.4, Vector3(0, 2.0, 0.6), Color(0.3, 0.25, 0.2), false, _boat)


func _build_lighthouse(p: Vector3) -> void:
	_cyl(2.5, 3.6, 1.6, p + Vector3(0, 0.3, 0), Color(0.18, 0.18, 0.19), false)
	_cyl(0.75, 1.1, 8.0, p + Vector3(0, 5.0, 0), Color(0.62, 0.60, 0.56), false)
	_cyl(0.78, 0.78, 0.9, p + Vector3(0, 3.0, 0), Color(0.45, 0.12, 0.10), false)
	_cyl(0.78, 0.78, 0.9, p + Vector3(0, 6.2, 0), Color(0.45, 0.12, 0.10), false)
	_cyl(0.65, 0.65, 0.9, p + Vector3(0, 9.4, 0), Color(0.08, 0.09, 0.10), false)
	_cyl(0.1, 0.85, 0.7, p + Vector3(0, 10.2, 0), Color(0.12, 0.12, 0.12), false)


func _build_wires() -> void:
	# 横跨街道的电线（几段细长方块）
	var pts := [Vector3(-10.9, 6.2, -6.0), Vector3(-3.0, 5.4, -7.5), Vector3(4.5, 5.6, -10.9)]
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var segs := 8
		for s in range(segs):
			var t0 := float(s) / segs
			var t1 := float(s + 1) / segs
			var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * 0.6, 0)
			var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * 0.6, 0)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.025, 0.025, p0.distance_to(p1))
			mi.mesh = bm
			mi.material_override = _mat(Color(0.05, 0.05, 0.05), 0.9)
			add_child(mi)
			mi.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP)


# ================================================================ 工具函数
func _mat(color: Color, rough := 0.85, emission := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINTED
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("emission_energy", energy)
	return m


func _box(size: Vector3, pos: Vector3, color: Color, collide := true, rot_y := 0.0, mat: Material = null, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat if mat else _mat(color)
	mi.position = pos
	mi.rotation.y = rot_y
	(parent if parent else self).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _cyl(rt: float, rb: float, h: float, pos: Vector3, color: Color, collide := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 18
	m.rings = 1
	mi.mesh = m
	mi.material_override = _mat(color)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(rt, rb)
		sh.height = h
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _collider_box(size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.position = pos
	sb.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	add_child(sb)


func _omni(pos: Vector3, color: Color, energy: float, rng: float, shadow: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	add_child(l)
	return l
