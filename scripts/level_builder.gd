@tool
extends Node3D
## 程序化搭建极地矿镇“霜原-7”。
##
## 建筑轮廓来自 data/buildings.json（《建筑编号索引 | B001–B132》的坐标系），
## 所以镇子的布局和索引图一致：西区斜向的长条板楼、大街两侧的无顶废墟、
## 东区还住着人的楼。大街北端是热电厂和选矿厂。
## 带 StaticBody3D 碰撞（layer 1），供 NavigationRegion3D 烘焙导航网格。
## 相机从东南上方往西北看，所以只有朝南（+Z）和朝东（+X）的立面看得见，
## 招牌、门、屏幕都放在这两个朝向上。
## 这是 @tool 脚本，在编辑器里打开场景时也能直接看到。

const PAINTED := preload("res://shaders/painted.gdshader")
const SNOW := preload("res://shaders/snow.gdshader")
const BUILDING := preload("res://shaders/building.gdshader")
const LIGHT_CONE := preload("res://shaders/light_cone.gdshader")
const Fonts := preload("res://scripts/fonts.gd")
const Town := preload("res://scripts/town_data.gd")

const FLOOR_H := 1.8
const RED := Color(0.70, 0.12, 0.09)
const CREAM := Color(0.86, 0.80, 0.66)
const RUST := Color(0.45, 0.22, 0.12)
const IRON := Color(0.10, 0.11, 0.13)
const SNOW_WHITE := Color(0.90, 0.93, 0.98)

## 道路中心线（世界坐标 xz）与半宽：中央大街、十字街、去厂区的路、南边的岔路
const ROADS := [
	[Vector2(0, -150), Vector2(0, 62), 2.1],
	[Vector2(-62, 0), Vector2(92, 0), 1.9],
	[Vector2(0, -150), Vector2(-48, -160), 1.8],
	[Vector2(0, 62), Vector2(40, 84), 1.6],
]

## 在检查器里勾选即可重建
@export var rebuild := false:
	set(v):
		if v and is_inside_tree():
			build()

var _t := 0.0
var _fire_light: OmniLight3D
var _crt_light: OmniLight3D
var _neon: Array[Node3D] = []
var _neon_light: OmniLight3D
var _beacons: Array[MeshInstance3D] = []
var _font: Font
var _snow_material: ShaderMaterial
var _mat_cache := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_neon.clear()
	_beacons.clear()
	_snow_material = null
	_mat_cache.clear()
	_font = Fonts.make(900)

	_build_ground()
	_build_town()
	_build_vegetation()
	_build_power_plant(Vector3(14, 0, -176))
	_build_concentrator(Vector3(-52, 0, -172))
	_build_spoil_heap(Vector3(92, 0, -196))
	_build_pylons()
	# 十字街口的布景
	_build_bus_stop(Vector3(-6, 0, -3.9))
	_build_loudspeaker(Vector3(2.9, 0, -3.1))
	_build_fire_barrel(Vector3(9, 0, 3.4))
	_build_ice_patch(Vector3(3.6, 0, 0.5))
	_build_ration_crates(Vector3(14, 0, -3.6))
	_build_map_board(Vector3(-3.0, 0, 3.5))
	_build_terminal_booth(Vector3(21.5, 0, -3.3))
	_build_boiler_house()
	_build_culture_palace()
	_build_heating_pipes()
	_build_monument(Vector3(0, 0, -24))
	_build_billboard(Vector3(-3.6, 0, -9.5), "计划就是法律", "每一栋楼都有编号\n每一个人都有位置")
	_build_billboard(Vector3(-3.6, 0, 22), "煤是工业的面包", "第七矿超额完成\n第四季度采掘任务")
	_build_walker(Vector3(-9, 0, -118))
	_build_truck(Vector3(-16, 0, 2.6))
	_merge_static()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	if _fire_light:
		_fire_light.light_energy = 2.8 + sin(_t * 13.0) * 0.35 + sin(_t * 7.3) * 0.4 + randf() * 0.25
	if _crt_light:
		_crt_light.light_energy = 1.1 + sin(_t * 31.0) * 0.08 + (0.5 if fmod(_t, 6.1) < 0.1 else 0.0)
	var on := not (fmod(_t, 5.3) < 0.12 or fmod(_t + 1.1, 7.7) < 0.08)
	for n in _neon:
		n.visible = on
	if _neon_light:
		_neon_light.visible = on
	# 烟囱上的航空障碍灯缓慢明灭
	var blink := 0.5 + 0.5 * sin(_t * 2.2)
	for b in _beacons:
		b.scale = Vector3.ONE * (0.7 + 0.5 * blink)


# ================================================================ 地面与城镇
func _build_ground() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SNOW
	var segs := PackedVector4Array()
	var widths := PackedFloat32Array()
	for r in ROADS:
		segs.append(Vector4(r[0].x, r[0].y, r[1].x, r[1].y))
		widths.append(r[2])
	while segs.size() < 8:
		segs.append(Vector4.ZERO)
		widths.append(0.0)
	mat.set_shader_parameter("roads", segs)
	mat.set_shader_parameter("road_width", widths)
	mat.set_shader_parameter("road_count", ROADS.size())
	# 可行走的雪地（顶面 y=0）
	_box(Vector3(440, 2.0, 380), Vector3(-65, -1.0, -50), Color.WHITE, true, 0.0, mat)
	# 远处的苔原，只用来铺满画面
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	far.mesh = pm
	far.material_override = mat
	far.position = Vector3(-65, -0.05, -50)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)


func _build_town() -> void:
	var s := Town.scale()
	for b in Town.buildings():
		var root := Node3D.new()
		root.name = String(b["id"])
		root.position = Town.to_world(b["x"], b["z"])
		root.rotation.y = -deg_to_rad(b["rot"])
		add_child(root)
		var length: float = b["len"] * s
		var width: float = b["wid"] * s
		var floors: int = b["floors"]
		var sd := float(hash(b["id"]) % 1000)
		match String(b["kind"]):
			"ruin":
				_ruin(root, length, width, floors, sd)
			"husk":
				_block(root, length, width, floors, sd, 0.012, Color(0.60, 0.60, 0.62), 0.85)
			"block":
				_block(root, length, width, floors, sd, 0.3, _block_color(sd), 0.45)
			"public":
				_block(root, length, width, floors, sd, 0.45, Color(0.74, 0.68, 0.52), 0.35)
		var h := floors * FLOOR_H
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(length, h, width)
		cs.shape = sh
		sb.position = Vector3(0, h * 0.5, 0)
		sb.add_child(cs)
		root.add_child(sb)


func _block_color(sd: float) -> Color:
	var cols := [Color(0.70, 0.66, 0.60), Color(0.66, 0.56, 0.48), Color(0.62, 0.66, 0.68), Color(0.72, 0.64, 0.50)]
	return cols[int(sd) % cols.size()]


func _building_mat(size: Vector3, color: Color, sd: float, lit: float, ruined: float, frost: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BUILDING
	m.set_shader_parameter("size", size)
	m.set_shader_parameter("wall_color", color)
	m.set_shader_parameter("seed", sd)
	m.set_shader_parameter("lit_ratio", lit)
	m.set_shader_parameter("ruined", ruined)
	m.set_shader_parameter("frost", frost)
	m.set_shader_parameter("floor_height", FLOOR_H)
	return m


## 完整的板楼：一个带程序化立面的盒子 + 屋顶积雪 + 屋顶小间 + 单元门
func _block(root: Node3D, length: float, width: float, floors: int, sd: float, lit: float, color: Color, frost: float) -> void:
	var h := floors * FLOOR_H
	var size := Vector3(length, h, width)
	_box(size, Vector3(0, h * 0.5, 0), color, false, 0.0, _building_mat(size, color, sd, lit, 0.0, frost), root)
	_box(Vector3(length + 0.3, 0.22, width + 0.3), Vector3(0, h + 0.11, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	var n := maxi(1, int(length / 9.0))
	for i in n:
		var x := (float(i) + 0.5) / n * length - length * 0.5
		_box(Vector3(1.2, 0.9, 1.0), Vector3(x, h + 0.6, 0), color * 0.8, false, 0.0, null, root)
		_box(Vector3(1.4, 0.16, 1.2), Vector3(x, h + 1.12, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
		_box(Vector3(1.1, 0.1, 0.7), Vector3(x, 1.45, width * 0.5 + 0.3), color * 0.55, false, 0.0, null, root)
		_box(Vector3(0.7, 1.3, 0.06), Vector3(x, 0.65, width * 0.5 + 0.03), Color(0.20, 0.13, 0.10), false, 0.0, null, root)


## 无顶废墟：四面外墙 + 内部隔墙 + 灌进来的雪
func _ruin(root: Node3D, length: float, width: float, floors: int, sd: float) -> void:
	var h := floors * FLOOR_H
	var t := 0.32
	var color := Color(0.74, 0.72, 0.70)
	_rng.seed = int(sd) + 7
	for sz in [-1.0, 1.0]:
		var size := Vector3(length, h, t)
		var pos := Vector3(0, h * 0.5, sz * (width * 0.5 - t * 0.5))
		_box(size, pos, color, false, 0.0, _building_mat(size, color, sd, 0.0, 1.0, 0.8), root)
		_box(Vector3(length, 0.1, t + 0.12), pos + Vector3(0, h * 0.5 + 0.05, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	for sx in [-1.0, 1.0]:
		var size := Vector3(t, h, width - t * 2.0)
		var pos := Vector3(sx * (length * 0.5 - t * 0.5), h * 0.5, 0)
		_box(size, pos, color, false, 0.0, _building_mat(size, color, sd + 1.0, 0.0, 1.0, 0.8), root)
		_box(Vector3(t + 0.12, 0.1, width), pos + Vector3(0, h * 0.5 + 0.05, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	var inner := _mat(Color(0.62, 0.60, 0.60), 0.9)
	# 横向隔墙，高低不一（塌掉的部分）
	var n := maxi(2, int(length / 3.4))
	for i in range(1, n):
		var x := float(i) / n * length - length * 0.5
		var ph := h * _rng.randf_range(0.45, 1.0)
		_box(Vector3(t * 0.8, ph, width - t * 2.0), Vector3(x, ph * 0.5, 0), Color.WHITE, false, 0.0, inner, root)
		_box(Vector3(t * 0.8 + 0.1, 0.08, width - t * 2.0), Vector3(x, ph + 0.04, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	# 纵向的中墙
	if width > 3.0:
		var sh := h * 0.75
		_box(Vector3(length - t * 2.0, sh, t * 0.8), Vector3(0, sh * 0.5, 0), Color.WHITE, false, 0.0, inner, root)
		_box(Vector3(length - t * 2.0, 0.08, t * 0.8 + 0.1), Vector3(0, sh + 0.04, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	# 屋里的积雪
	_box(Vector3(length - t * 2.0, 0.7, width - t * 2.0), Vector3(0, 0.35, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)


func _build_vegetation() -> void:
	# 挂满雾凇的行道树和灌木：用 MultiMesh，一次绘制
	var blob := SphereMesh.new()
	blob.radius = 0.5
	blob.height = 1.0
	blob.radial_segments = 7
	blob.rings = 4
	var frost_mat := _mat_new(Color(0.86, 0.88, 0.95), 0.95)
	frost_mat.set_shader_parameter("grime", 0.0)
	frost_mat.set_shader_parameter("noise_scale", 3.0)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.03
	trunk.bottom_radius = 0.07
	trunk.height = 1.0
	trunk.radial_segments = 5
	var trunk_mat := _mat(Color(0.22, 0.19, 0.20), 0.9)

	var blobs: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	_rng.seed = 42
	# 大街两侧的行道树
	var z := -148.0
	while z < 60.0:
		for side in [-1.0, 1.0]:
			if absf(z) < 4.5 or absf(z + 24.0) < 4.0 or _rng.randf() < 0.18:
				continue
			_tree(Vector3(side * (3.2 + _rng.randf_range(-0.2, 0.3)), 0, z + _rng.randf_range(-0.6, 0.6)), _rng.randf_range(2.0, 3.2), blobs, trunks)
		z += 2.6
	# 苔原上的矮灌木
	for i in 700:
		var p := Vector3(_rng.randf_range(-270, 140), 0, _rng.randf_range(-225, 125))
		if _near_road(p, 2.5) or _inside_building(p, 1.0):
			continue
		var sc := _rng.randf_range(0.35, 0.9)
		blobs.append(Transform3D(Basis().scaled(Vector3(sc * 1.4, sc * 0.8, sc * 1.4)), p + Vector3(0, sc * 0.3, 0)))
	_multimesh(blob, frost_mat, blobs)
	_multimesh(trunk, trunk_mat, trunks)


func _tree(p: Vector3, h: float, blobs: Array[Transform3D], trunks: Array[Transform3D]) -> void:
	trunks.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), p + Vector3(0, h * 0.5, 0)))
	for k in 4:
		var o := Vector3(_rng.randf_range(-0.5, 0.5), h * _rng.randf_range(0.6, 1.05), _rng.randf_range(-0.5, 0.5))
		var sc := _rng.randf_range(0.8, 1.5)
		blobs.append(Transform3D(Basis().scaled(Vector3(sc, sc * 0.85, sc)), p + o))


func _near_road(p: Vector3, margin: float) -> bool:
	var q := Vector2(p.x, p.z)
	for r in ROADS:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if q.distance_to(a + (b - a) * t) < r[2] + margin:
			return true
	return false


func _inside_building(p: Vector3, margin: float) -> bool:
	var s := Town.scale()
	for b in Town.buildings():
		var c := Town.to_world(b["x"], b["z"])
		var d := (p - c).rotated(Vector3.UP, deg_to_rad(b["rot"]))
		var hl: float = b["len"] * s * 0.5 + margin
		var hw: float = b["wid"] * s * 0.5 + margin
		if absf(d.x) < hl and absf(d.z) < hw:
			return true
	return false


func _multimesh(mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


# ================================================================ 厂区
func _build_power_plant(p: Vector3) -> void:
	# 热电厂：砖红色的主厂房、一排细烟囱、一座红白相间的高烟囱
	var brick := Color(0.42, 0.24, 0.19)
	var hall := Vector3(34, 10.8, 13)
	_box(hall, p + Vector3(0, 5.4, 0), brick, true, 0.0, _factory_mat(hall, brick, 3.0, 0.2, 0.0))
	_box(Vector3(34.4, 0.3, 13.4), p + Vector3(0, 10.95, 0), SNOW_WHITE, false, 0.0, _snow_mat())
	var annex := Vector3(16, 7.2, 10)
	_box(annex, p + Vector3(24, 3.6, 2), Color(0.55, 0.53, 0.50), true, 0.0, _factory_mat(annex, Color(0.55, 0.53, 0.50), 8.0, 0.25, 0.0))
	_box(Vector3(16.4, 0.3, 10.4), p + Vector3(24, 7.35, 2), SNOW_WHITE, false, 0.0, _snow_mat())
	# 一排细烟囱 + 钢架
	for i in 6:
		var x := -12.0 + i * 3.2
		_cyl(0.45, 0.55, 20.0, p + Vector3(x, 21.0, -1.5), Color(0.08, 0.08, 0.10), false)
		if i % 2 == 0:
			_steam(p + Vector3(x, 31.5, -1.5), 1.0)
	for y in [15.0, 20.0, 25.0, 30.0]:
		_box(Vector3(17.5, 0.18, 0.18), p + Vector3(-4, y, -0.7), IRON, false)
		_box(Vector3(17.5, 0.18, 0.18), p + Vector3(-4, y, -2.3), IRON, false)
	for x in [-12.6, -4.0, 4.6]:
		_box(Vector3(0.18, 20, 0.18), p + Vector3(x, 21, -0.7), IRON, false)
		_box(Vector3(0.18, 20, 0.18), p + Vector3(x, 21, -2.3), IRON, false)
	# 高烟囱
	var tall := p + Vector3(10, 0, -2)
	for k in 8:
		var col := RED if k % 2 == 0 else Color(0.85, 0.85, 0.83)
		_cyl(0.8 - k * 0.03, 0.83 - k * 0.03, 4.0, tall + Vector3(0, 11 + k * 4.0 + 2.0, 0), col, false)
	_steam(tall + Vector3(0, 44, 0), 1.6)
	_beacon(tall + Vector3(0, 43.3, 0.9))
	_beacon(tall + Vector3(0.9, 27, 0))
	# 输煤栈桥
	var gallery := _box(Vector3(26, 1.6, 1.8), p + Vector3(-27, 6.0, 3), Color(0.30, 0.32, 0.36), false)
	gallery.rotation.z = -0.36
	for x in [-34.0, -27.0, -20.0]:
		var gh: float = 6.0 + (x + 27.0) * 0.37
		_box(Vector3(0.3, gh, 0.3), p + Vector3(x, gh * 0.5, 3), IRON, false)
	_omni(p + Vector3(0, 6, 9), Color(1.0, 0.55, 0.25), 2.0, 16.0, false)
	_box(Vector3(9.0, 1.3, 0.1), p + Vector3(0, 8.2, 6.52), RED, false)
	_sign(p + Vector3(0, 8.2, 6.6), "霜原热电厂", 150, CREAM)


func _build_concentrator(p: Vector3) -> void:
	# 选矿厂：蓝白条纹的大盒子，斜向的皮带廊
	var blue := Color(0.16, 0.30, 0.62)
	var white := Color(0.82, 0.84, 0.88)
	var main := Vector3(26, 12.6, 13)
	_box(main, p + Vector3(0, 6.3, 0), white, true, 0.0, _factory_mat(main, white, 1.0, 0.12, 1.0))
	_box(Vector3(26.4, 0.3, 13.4), p + Vector3(0, 12.75, 0), SNOW_WHITE, false, 0.0, _snow_mat())
	var tower := Vector3(8, 16.2, 8)
	_box(tower, p + Vector3(15, 8.1, -1), blue, true, 0.0, _factory_mat(tower, blue * 0.9, 5.0, 0.1, 0.0))
	_box(Vector3(8.4, 0.3, 8.4), p + Vector3(15, 16.35, -1), SNOW_WHITE, false, 0.0, _snow_mat())
	var low := Vector3(18, 5.4, 9)
	_box(low, p + Vector3(-20, 2.7, 3), white, true, 0.0, _factory_mat(low, white, 9.0, 0.15, 1.0))
	_box(Vector3(18.4, 0.3, 9.4), p + Vector3(-20, 5.55, 3), SNOW_WHITE, false, 0.0, _snow_mat())
	# 红色坡屋顶的小库房
	_box(Vector3(9, 3.0, 6), p + Vector3(6, 1.5, 12), Color(0.80, 0.82, 0.86), true)
	var roof := _box(Vector3(9.4, 0.3, 4.0), p + Vector3(6, 3.6, 10.6), RED, false)
	roof.rotation.x = -0.45
	var roof2 := _box(Vector3(9.4, 0.3, 4.0), p + Vector3(6, 3.6, 13.4), RED, false)
	roof2.rotation.x = 0.45
	# 皮带廊
	var gallery := _box(Vector3(30, 1.5, 1.7), p + Vector3(-31, 5.6, -2), Color(0.20, 0.22, 0.26), false)
	gallery.rotation.z = -0.36
	_steam(p + Vector3(15, 17.5, -1), 0.7)
	_sign(p + Vector3(0, 9.9, 6.56), "第七矿选矿厂", 150, blue * 0.7)


func _factory_mat(size: Vector3, color: Color, sd: float, lit: float, stripes: float) -> ShaderMaterial:
	var m := _building_mat(size, color, sd, lit, 0.0, 0.35)
	m.set_shader_parameter("stripe_amount", stripes)
	m.set_shader_parameter("bay_width", 2.2)
	return m


func _build_spoil_heap(p: Vector3) -> void:
	# 矸石山：顶上冒着一点自燃的烟
	var m := _cyl(3.0, 34.0, 15.0, p + Vector3(0, 7.5, 0), Color.WHITE, false)
	m.material_override = _snow_mat()
	_cyl(4.0, 16.0, 6.0, p + Vector3(2, 12.0, 1), Color(0.26, 0.25, 0.28), false)
	_steam(p + Vector3(1, 16, 0), 0.5)


func _build_pylons() -> void:
	# 输电铁塔，从热电厂一路排到镇子东边
	var pts := [Vector3(48, 0, -168), Vector3(70, 0, -120), Vector3(86, 0, -70), Vector3(96, 0, -20)]
	for p in pts:
		_pylon(p)
	for i in range(pts.size() - 1):
		for off in [-2.6, 2.6]:
			_cable(pts[i] + Vector3(off, 11.5, 0), pts[i + 1] + Vector3(off, 11.5, 0), 2.5)


func _pylon(p: Vector3) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := _box(Vector3(0.14, 12.5, 0.14), p + Vector3(sx * 0.7, 6.1, sz * 0.7), IRON, false)
			leg.rotation.z = sx * 0.085
			leg.rotation.x = -sz * 0.085
	for y in [3.0, 6.0, 9.0]:
		var w: float = 2.4 - y * 0.16
		_box(Vector3(w, 0.1, 0.1), p + Vector3(0, y, w * 0.5), IRON, false)
		_box(Vector3(w, 0.1, 0.1), p + Vector3(0, y, -w * 0.5), IRON, false)
		_box(Vector3(0.1, 0.1, w), p + Vector3(w * 0.5, y, 0), IRON, false)
		_box(Vector3(0.1, 0.1, w), p + Vector3(-w * 0.5, y, 0), IRON, false)
	_box(Vector3(5.6, 0.14, 0.14), p + Vector3(0, 11.6, 0), IRON, false)
	_box(Vector3(3.6, 0.14, 0.14), p + Vector3(0, 9.6, 0), IRON, false)
	_collider_box(Vector3(1.8, 4, 1.8), p + Vector3(0, 2, 0))


func _cable(a: Vector3, b: Vector3, sag: float) -> void:
	var segs := 10
	var mat := _mat(Color(0.05, 0.05, 0.06), 0.9)
	for s in segs:
		var t0 := float(s) / segs
		var t1 := float(s + 1) / segs
		var p0 := a.lerp(b, t0) - Vector3(0, sin(t0 * PI) * sag, 0)
		var p1 := a.lerp(b, t1) - Vector3(0, sin(t1 * PI) * sag, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.03, p0.distance_to(p1))
		mi.mesh = bm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP)


func _steam(p: Vector3, size: float) -> void:
	var s := CPUParticles3D.new()
	s.position = p
	s.amount = 26
	s.lifetime = 11.0
	s.preprocess = 11.0
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 0.4 * size
	s.direction = Vector3(-0.5, 1.0, 0.3)
	s.spread = 10.0
	s.gravity = Vector3(-0.55, 0.05, 0.3)
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 3.0
	s.damping_min = 0.15
	s.damping_max = 0.25
	s.scale_amount_min = 1.6 * size
	s.scale_amount_max = 2.6 * size
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.25))
	curve.add_point(Vector2(0.4, 0.8))
	curve.add_point(Vector2(1, 1.3))
	s.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.97, 0.94, 0.9))
	grad.set_color(1, Color(0.78, 0.80, 0.90, 0.0))
	grad.add_point(0.5, Color(0.95, 0.90, 0.90, 0.6))
	s.color_ramp = grad
	var q := SphereMesh.new()
	q.radius = 1.0
	q.height = 2.0
	q.radial_segments = 10
	q.rings = 5
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = fm
	s.mesh = q
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)


func _beacon(p: Vector3) -> void:
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	b.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(3.0, 0.25, 0.15)
	b.material_override = m
	b.position = p
	add_child(b)
	_beacons.append(b)


# ================================================================ 十字街口
func _build_bus_stop(p: Vector3) -> void:
	# 混凝土候车亭，背墙上是马赛克拼的太阳
	var conc := Color(0.62, 0.62, 0.64)
	_box(Vector3(4.6, 2.5, 0.25), p + Vector3(0, 1.25, -0.9), conc, true)
	_box(Vector3(0.25, 2.5, 1.6), p + Vector3(-2.2, 1.25, -0.2), conc, true)
	var roof := _box(Vector3(5.2, 0.2, 2.6), p + Vector3(0, 2.62, 0.0), conc * 0.8, false)
	roof.rotation.x = 0.06
	var roof_snow := _box(Vector3(5.3, 0.22, 2.7), p + Vector3(0, 2.83, 0.0), SNOW_WHITE, false, 0.0, _snow_mat())
	roof_snow.rotation.x = 0.06
	_cyl(0.08, 0.08, 2.5, p + Vector3(2.3, 1.25, 0.9), IRON, false)
	# 马赛克：放射状的色块
	var tiles := [RED, Color(0.86, 0.62, 0.16), Color(0.16, 0.36, 0.60), Color(0.88, 0.84, 0.72), Color(0.10, 0.45, 0.42)]
	for i in 9:
		var a := PI * (float(i) + 0.5) / 9.0
		var tile := _box(Vector3(0.34, 1.2, 0.04), p + Vector3(cos(a) * 1.15, 0.95 + sin(a) * 1.0, -0.76), tiles[i % tiles.size()], false)
		tile.rotation.z = a - PI * 0.5
	var sun := _cyl(0.5, 0.5, 0.05, p + Vector3(0, 0.95, -0.75), Color(0.86, 0.62, 0.16), false)
	sun.rotation.x = PI * 0.5
	# 长椅
	var wood := Color(0.36, 0.24, 0.16)
	for k in 3:
		_box(Vector3(3.2, 0.06, 0.13), p + Vector3(0, 0.5, -0.45 + k * 0.16), wood * (0.9 + k * 0.06), false)
	for x in [-1.4, 1.4]:
		_box(Vector3(0.08, 0.5, 0.5), p + Vector3(x, 0.25, -0.3), IRON, false)
	_box(Vector3(1.7, 0.1, 0.4), p + Vector3(-0.7, 0.58, -0.4), SNOW_WHITE, false, 0.0, _snow_mat())
	# 站牌
	_cyl(0.04, 0.04, 2.6, p + Vector3(3.1, 1.3, 1.0), IRON, false)
	_box(Vector3(0.7, 0.5, 0.04), p + Vector3(3.1, 2.4, 1.0), Color(0.86, 0.72, 0.18), false)
	_sign(p + Vector3(3.1, 2.4, 1.03), "7", 120, IRON)
	_collider_box(Vector3(3.3, 0.8, 0.6), p + Vector3(0, 0.4, -0.35))


func _build_loudspeaker(p: Vector3) -> void:
	# 广播杆：两只灰喇叭、一面小红旗、一盏还亮着的灯
	_cyl(0.2, 0.26, 0.4, p + Vector3(0, 0.2, 0), IRON, true)
	_cyl(0.07, 0.09, 5.2, p + Vector3(0, 2.8, 0), Color(0.30, 0.30, 0.32), false)
	for sgn in [-1.0, 1.0]:
		var horn := _cyl(0.4, 0.1, 0.75, p + Vector3(sgn * 0.45, 4.9, 0.15), Color(0.58, 0.60, 0.63), false)
		horn.rotation.z = -sgn * PI * 0.5
		horn.rotation.y = -sgn * 0.6
	_box(Vector3(0.1, 0.08, 0.8), p + Vector3(0, 4.0, 0.35), IRON, false)
	var head := _box(Vector3(0.34, 0.3, 0.34), p + Vector3(0, 3.86, 0.72), IRON, false)
	_box(Vector3(0.26, 0.2, 0.26), Vector3(0, -0.08, 0), Color.BLACK, false, 0.0, _mat(Color(0.4, 0.3, 0.15), 0.3, Color(1.0, 0.78, 0.45), 4.0), head)
	_omni(p + Vector3(0, 3.5, 0.72), Color(1.0, 0.76, 0.48), 1.6, 9.0, false)
	_light_cone(p + Vector3(0, 3.7, 0.72), 3.7, 2.2, Color(1.0, 0.80, 0.5), 0.12)
	_box(Vector3(0.9, 0.55, 0.03), p + Vector3(0.52, 3.0, 0), RED, false)


func _build_fire_barrel(p: Vector3) -> void:
	_cyl(0.38, 0.38, 0.95, p + Vector3(0, 0.475, 0), RUST, true)
	_cyl(0.395, 0.395, 0.05, p + Vector3(0, 0.25, 0), RUST * 0.6, false)
	_cyl(0.395, 0.395, 0.05, p + Vector3(0, 0.75, 0), RUST * 0.6, false)
	var embers := _cyl(0.34, 0.34, 0.04, p + Vector3(0, 0.9, 0), Color.BLACK, false)
	embers.material_override = _mat(Color(0.2, 0.05, 0.0), 0.9, Color(1.0, 0.35, 0.08), 3.0)
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fire)
	_fire_light = _omni(p + Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.2), 2.8, 8.0, true)
	# 雪被烤化了一圈
	var melt := _cyl(1.3, 1.3, 0.02, p + Vector3(0, 0.012, 0), Color(0.30, 0.30, 0.34), false)
	melt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_ice_patch(p: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.42, 0.55)
	m.roughness = 0.03
	m.metallic_specular = 1.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.85
	mesh.bottom_radius = 0.85
	mesh.height = 0.01
	mesh.radial_segments = 24
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = p + Vector3(0, 0.008, 0)
	mi.scale = Vector3(1.0, 1.0, 0.62)
	mi.rotation.y = 0.4
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_ration_crates(p: Vector3) -> void:
	var c1 := Color(0.34, 0.38, 0.26)
	var c2 := Color(0.42, 0.33, 0.20)
	_crate(p + Vector3(-0.5, 0.45, -0.4), 0.9, c1, 0.0)
	_crate(p + Vector3(0.5, 0.45, -0.3), 0.9, c2, -0.15)
	_crate(p + Vector3(0.0, 1.3, -0.35), 0.8, c1, 0.35)
	_crate(p + Vector3(0.2, 0.35, 0.6), 0.7, c2, 0.6)
	_box(Vector3(1.0, 0.14, 0.9), p + Vector3(0.0, 1.78, -0.35), SNOW_WHITE, false, 0.35, _snow_mat())
	_sign(p + Vector3(-0.5, 0.48, 0.07), "★", 90, CREAM)
	_cyl(0.25, 0.25, 0.7, p + Vector3(1.3, 0.35, 0.5), RED * 0.8, true)
	_cyl(0.25, 0.25, 0.7, p + Vector3(1.4, 0.35, -0.2), Color(0.20, 0.27, 0.32), true)


func _crate(p: Vector3, s: float, c: Color, rot: float) -> void:
	var crate := _box(Vector3(s, s, s), p, c, true, rot)
	for k in [-1, 1]:
		_box(Vector3(s + 0.02, 0.08, s + 0.02), Vector3(0, k * s * 0.44, 0), c * 0.6, false, 0.0, null, crate)
		_box(Vector3(0.08, s, s + 0.02), Vector3(k * s * 0.44, 0, 0), c * 0.6, false, 0.0, null, crate)


func _build_map_board(p: Vector3) -> void:
	# 《建筑编号索引》公告牌，牌面朝南
	for x in [-1.1, 1.1]:
		_cyl(0.05, 0.05, 2.3, p + Vector3(x, 1.15, 0), IRON, false)
	_box(Vector3(2.5, 1.5, 0.08), p + Vector3(0, 1.5, 0), Color(0.16, 0.14, 0.13), true)
	_box(Vector3(2.3, 1.3, 0.04), p + Vector3(0, 1.5, 0.05), CREAM, false)
	_box(Vector3(2.3, 0.2, 0.05), p + Vector3(0, 2.05, 0.055), RED, false)
	# 牌面上的小方块：示意建筑轮廓
	_rng.seed = 132
	for i in 22:
		var col := Color(0.50, 0.52, 0.51) if i % 5 != 0 else Color(0.80, 0.52, 0.26)
		var b := _box(Vector3(_rng.randf_range(0.1, 0.34), 0.07, 0.02), p + Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(1.0, 1.85), 0.075), col, false)
		b.rotation.z = [0.0, 0.5, -0.9, 1.57][i % 4]
	_box(Vector3(2.6, 0.1, 0.3), p + Vector3(0, 2.3, 0), SNOW_WHITE, false, 0.0, _snow_mat())


func _build_terminal_booth(p: Vector3) -> void:
	# 公用终端亭：电话亭的骨架里塞了一台阴极射线管终端，屏幕朝南
	var red := Color(0.52, 0.11, 0.08)
	var root := Node3D.new()
	root.position = p
	root.rotation.y = deg_to_rad(20)
	add_child(root)
	_box(Vector3(1.15, 0.12, 1.15), Vector3(0, 0.06, 0), red * 0.7, false, 0.0, null, root)
	_box(Vector3(1.2, 0.25, 1.2), Vector3(0, 2.5, 0), red, false, 0.0, null, root)
	_box(Vector3(1.3, 0.16, 1.3), Vector3(0, 2.7, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	for c in [Vector2(-0.53, -0.53), Vector2(0.53, -0.53), Vector2(-0.53, 0.53), Vector2(0.53, 0.53)]:
		_box(Vector3(0.1, 2.3, 0.1), Vector3(c.x, 1.25, c.y), red, false, 0.0, null, root)
	var glass := _mat(Color(0.20, 0.30, 0.32), 0.1, Color(0.3, 0.9, 0.8), 0.25)
	_box(Vector3(0.96, 2.0, 0.03), Vector3(0, 1.2, -0.53), Color.BLACK, false, 0.0, glass, root)
	_box(Vector3(0.03, 2.0, 0.96), Vector3(-0.53, 1.2, 0), Color.BLACK, false, 0.0, glass, root)
	# 终端机身、屏幕、键盘、指示灯
	_box(Vector3(0.8, 0.9, 0.5), Vector3(0, 1.25, -0.22), Color(0.55, 0.56, 0.50), false, 0.0, null, root)
	_box(Vector3(0.5, 0.36, 0.04), Vector3(0, 1.42, 0.04), Color.BLACK, false, 0.0, _mat(Color(0.02, 0.1, 0.08), 0.2, Color(0.25, 1.0, 0.75), 2.6), root)
	_box(Vector3(0.6, 0.06, 0.3), Vector3(0, 0.95, 0.12), Color(0.12, 0.12, 0.12), false, 0.0, null, root)
	_box(Vector3(0.12, 0.05, 0.02), Vector3(0.28, 1.1, 0.04), Color.BLACK, false, 0.0, _mat(Color.BLACK, 0.3, Color(1.0, 0.2, 0.1), 3.0), root)
	_box(Vector3(0.9, 0.18, 0.05), Vector3(0, 2.5, 0.61), Color.BLACK, false, 0.0, _mat(CREAM, 0.4, Color(1.0, 0.95, 0.8), 0.9), root)
	_crt_light = _omni(p + Vector3(0.2, 1.5, 0.6), Color(0.3, 1.0, 0.8), 1.1, 3.5, false)
	_collider_box(Vector3(1.2, 2.6, 1.2), p + Vector3(0, 1.3, 0), deg_to_rad(20))


func _build_boiler_house() -> void:
	# B125：小锅炉房的砖烟囱和门牌
	var c := Town.to_world(508, 72)
	_cyl(0.45, 0.6, 9.0, c + Vector3(1.6, 4.5 + FLOOR_H, 0.6), Color(0.45, 0.24, 0.18), false)
	_cyl(0.5, 0.5, 0.5, c + Vector3(1.6, 9.0 + FLOOR_H, 0.6), RED, false)
	_steam(c + Vector3(1.6, 9.8 + FLOOR_H, 0.6), 0.55)
	_box(Vector3(1.9, 0.6, 0.06), c + Vector3(-1.0, 1.35, 1.86), RED, false)
	_sign(c + Vector3(-1.0, 1.35, 1.9), "锅炉房", 80, CREAM)


func _build_culture_palace() -> void:
	# B122：矿工文化宫，南立面带柱廊
	var c := Town.to_world(532, 40)
	var s := Town.scale()
	var front := c.z + 18.0 * s * 0.5
	var h := 3 * FLOOR_H
	for i in 6:
		var x := c.x - 3.5 + i * 1.4
		_box(Vector3(0.3, h - 0.6, 0.3), Vector3(x, (h - 0.6) * 0.5, front + 0.75), Color(0.82, 0.78, 0.68), i == 0 or i == 5)
	_box(Vector3(8.2, 0.5, 1.3), Vector3(c.x, h - 0.35, front + 0.55), Color(0.74, 0.68, 0.52), false)
	_box(Vector3(8.5, 0.2, 1.5), Vector3(c.x, h - 0.02, front + 0.55), SNOW_WHITE, false, 0.0, _snow_mat())
	# 大门与门上的灯
	_box(Vector3(1.5, 2.4, 0.12), Vector3(c.x, 1.2, front + 0.04), Color(0.20, 0.12, 0.08), false)
	_box(Vector3(1.1, 0.4, 0.05), Vector3(c.x, 2.15, front + 0.1), Color.BLACK, false, 0.0, _mat(Color(0.1, 0.07, 0.04), 0.3, Color(1.0, 0.7, 0.35), 1.8))
	# 两侧的红色条幅
	for sx in [-2.9, 2.9]:
		_box(Vector3(0.8, 3.4, 0.04), Vector3(c.x + sx, 2.9, front + 0.06), RED, false)
	# 霓虹招牌：“文”字坏了，只剩“化宫”
	_box(Vector3(4.6, 0.9, 0.1), Vector3(c.x, h + 0.75, front + 0.5), IRON, false)
	var neon := _sign(Vector3(c.x + 0.6, h + 0.75, front + 0.57), "化 宫", 120, Color(2.4, 0.4, 0.3))
	_neon.append(neon)
	_neon_light = _omni(Vector3(c.x, h, front + 2.0), Color(1.0, 0.3, 0.25), 1.4, 6.0, false)
	_light_cone(Vector3(c.x, 2.2, front + 0.5), 2.2, 1.4, Color(1.0, 0.7, 0.4), 0.1)


func _build_heating_pipes() -> void:
	# 架空供暖管：从锅炉房出来，沿十字街北侧向西，在大街上方拱起一个“П”形补偿弯
	var y := 2.5
	var z := -6.3
	_pipe_run(Vector3(22.8, y, z), Vector3(2.5, y, z))
	_pipe_run(Vector3(2.5, y, z), Vector3(2.5, 5.2, z))
	_pipe_run(Vector3(2.5, 5.2, z), Vector3(-2.5, 5.2, z))
	_pipe_run(Vector3(-2.5, 5.2, z), Vector3(-2.5, y, z))
	_pipe_run(Vector3(-2.5, y, z), Vector3(-58, y, z))
	_pipe_run(Vector3(22.8, y, z), Vector3(22.8, y, -8.6))
	var x := 20.0
	while x > -58.0:
		if absf(x) > 3.5:
			_box(Vector3(0.14, y, 0.14), Vector3(x, y * 0.5, z - 0.3), IRON, false)
			_box(Vector3(0.14, y, 0.14), Vector3(x, y * 0.5, z + 0.3), IRON, false)
			_box(Vector3(0.2, 0.12, 0.9), Vector3(x, y - 0.3, z), IRON, false)
		x -= 5.5
	# 接头处漏出来的蒸汽
	_steam(Vector3(-14.0, y + 0.4, z), 0.16)


func _pipe_run(a: Vector3, b: Vector3) -> void:
	# 两根并排的保温管，包着发黄的铁皮，隔一段一道锈箍
	var length := a.distance_to(b)
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = Vector3(0, 0, 1)
	side = side.normalized()
	for sgn in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.2
		m.bottom_radius = 0.2
		m.height = length + 0.2
		m.radial_segments = 10
		m.rings = 1
		mi.mesh = m
		mi.material_override = _mat(Color(0.66, 0.60, 0.46) if sgn < 0.0 else Color(0.58, 0.56, 0.52), 0.6)
		add_child(mi)
		mi.transform = Transform3D(Basis(side, dir, side.cross(dir)), mid + side * 0.24 * sgn)
	var n := int(length / 2.4)
	for i in range(1, n + 1):
		var ring := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.96, 0.1, 0.46)
		ring.mesh = rm
		ring.material_override = _mat(RUST, 0.8)
		add_child(ring)
		ring.transform = Transform3D(Basis(side, dir, side.cross(dir)), a + dir * (float(i) / (n + 1) * length))
	# 管顶的雪
	if absf(dir.y) < 0.5:
		var snow := _box(Vector3(0.7, 0.1, length), mid + Vector3(0, 0.22, 0), SNOW_WHITE, false, 0.0, _snow_mat())
		snow.rotation.y = atan2(dir.x, dir.z)


func _build_monument(p: Vector3) -> void:
	# 大街正中的纪念碑：混凝土方尖碑，顶上一颗红星
	_cyl(2.6, 2.9, 0.5, p + Vector3(0, 0.25, 0), Color(0.58, 0.58, 0.60), true)
	_cyl(2.65, 2.65, 0.1, p + Vector3(0, 0.55, 0), Color.WHITE, false).material_override = _snow_mat()
	_box(Vector3(1.5, 1.4, 1.5), p + Vector3(0, 1.2, 0), Color(0.52, 0.52, 0.55), true)
	var shaft := _cyl(0.28, 0.62, 7.0, p + Vector3(0, 5.4, 0), Color(0.64, 0.64, 0.66), false)
	(shaft.mesh as CylinderMesh).radial_segments = 4
	shaft.rotation.y = PI * 0.25
	var star := _sign(p + Vector3(0, 9.6, 0), "★", 300, Color(2.4, 0.25, 0.18))
	star.pixel_size = 0.006
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_omni(p + Vector3(0, 9.0, 0.8), Color(1.0, 0.25, 0.2), 1.2, 7.0, false)
	_box(Vector3(1.2, 0.5, 0.04), p + Vector3(0, 1.3, 0.77), Color(0.20, 0.18, 0.16), false)
	_sign(p + Vector3(0, 1.3, 0.8), "1957", 90, Color(0.80, 0.70, 0.45))


func _build_billboard(p: Vector3, title: String, body: String) -> void:
	# 宣传牌：红底、奶油色大字、一道斜向的黑条。立在大街西侧，牌面朝东
	var root := Node3D.new()
	root.position = p
	root.rotation.y = PI * 0.5
	add_child(root)
	for x in [-1.9, 1.9]:
		_box(Vector3(0.14, 3.6, 0.14), Vector3(x, 1.8, -0.1), IRON, false, 0.0, null, root)
	_box(Vector3(4.4, 2.3, 0.1), Vector3(0, 2.6, 0), RED, false, 0.0, null, root)
	var bar := _box(Vector3(1.6, 0.3, 0.02), Vector3(1.7, 2.1, 0.06), Color(0.08, 0.07, 0.07), false, 0.0, null, root)
	bar.rotation.z = 0.9
	_box(Vector3(4.4, 0.08, 0.02), Vector3(0, 2.72, 0.062), CREAM, false, 0.0, null, root)
	_box(Vector3(4.6, 0.14, 0.4), Vector3(0, 3.82, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	var t := _sign(Vector3(0, 3.2, 0.075), title, 110, Color(0.95, 0.90, 0.76))
	t.reparent(root, false)
	var bl := _sign(Vector3(-0.3, 2.15, 0.075), body, 54, Color(0.95, 0.90, 0.76))
	bl.font = Fonts.make(700)
	bl.reparent(root, false)
	_collider_box(Vector3(0.5, 3.6, 4.4), p + Vector3(0, 1.8, 0))


func _build_walker(p: Vector3) -> void:
	# “猛犸-2”步行掘进机：四条腿的旧机器，半埋在雪里，停在去矿上的路边
	var root := Node3D.new()
	root.position = p
	root.rotation = Vector3(0.06, 0.5, -0.1)
	add_child(root)
	var hull := Color(0.62, 0.36, 0.12)
	_box(Vector3(6.4, 2.6, 4.0), Vector3(0, 5.0, 0), hull, false, 0.0, null, root)
	_box(Vector3(6.6, 0.2, 4.2), Vector3(0, 6.4, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	_box(Vector3(2.2, 1.6, 2.6), Vector3(3.6, 5.6, 0), hull * 0.85, false, 0.0, null, root)
	_box(Vector3(0.06, 0.9, 2.2), Vector3(4.72, 5.8, 0), Color.BLACK, false, 0.0, _mat(Color(0.05, 0.08, 0.10), 0.1), root)
	# 警示条
	for k in 6:
		_box(Vector3(0.5, 0.5, 0.03), Vector3(-2.6 + k * 1.0, 3.95, 2.02), Color(0.90, 0.72, 0.10) if k % 2 == 0 else IRON, false, 0.0, null, root)
	# 四条腿：大腿 + 小腿 + 脚掌
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var hip := Vector3(sx * 2.4, 4.4, sz * 2.3)
			var thigh := _box(Vector3(0.7, 3.2, 0.7), hip + Vector3(sx * 0.6, -0.6, sz * 0.9), IRON.lightened(0.15), false, 0.0, null, root)
			thigh.rotation = Vector3(sz * 0.6, 0, -sx * 0.35)
			var shin := _box(Vector3(0.5, 3.6, 0.5), hip + Vector3(sx * 1.3, -2.8, sz * 1.9), hull * 0.7, false, 0.0, null, root)
			shin.rotation = Vector3(-sz * 0.12, 0, sx * 0.1)
			_cyl(0.9, 1.1, 0.4, hip + Vector3(sx * 1.4, -4.4, sz * 2.0), IRON, false, root)
	# 斗轮臂
	var boom := _box(Vector3(7.0, 0.5, 0.6), Vector3(-6.0, 5.4, 0), IRON.lightened(0.1), false, 0.0, null, root)
	boom.rotation.z = -0.3
	var wheel := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.7
	wheel.mesh = tm
	wheel.material_override = _mat(RUST, 0.8)
	wheel.position = Vector3(-9.6, 4.2, 0)
	wheel.rotation.x = PI * 0.5
	root.add_child(wheel)
	var star := _sign(Vector3(0, 5.2, 2.03), "★ 猛犸-2", 130, Color(0.92, 0.86, 0.70))
	star.pixel_size = 0.006
	star.reparent(root, false)
	# 雪堆
	for o in [Vector3(-3, 0, 3), Vector3(3.5, 0, -2.5), Vector3(-9, 0, 0.5)]:
		var mound := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 2.4
		sm.height = 2.2
		mound.mesh = sm
		mound.material_override = _snow_mat()
		mound.position = p + o + Vector3(0, -0.2, 0)
		add_child(mound)
	_collider_box(Vector3(9.0, 4.0, 7.5), p + Vector3(0, 2, 0), 0.5)


func _build_truck(p: Vector3) -> void:
	# 抛锚的卡车：蓝驾驶室、军绿车斗
	var root := Node3D.new()
	root.position = p
	root.rotation.y = 0.12
	add_child(root)
	var cab := Color(0.20, 0.36, 0.52)
	_box(Vector3(1.5, 1.3, 1.9), Vector3(1.9, 1.35, 0), cab, false, 0.0, null, root)
	_box(Vector3(1.1, 0.8, 1.7), Vector3(3.0, 1.0, 0), cab * 0.9, false, 0.0, null, root)
	_box(Vector3(0.05, 0.6, 1.5), Vector3(2.67, 1.65, 0), Color.BLACK, false, 0.0, _mat(Color(0.05, 0.08, 0.10), 0.1), root)
	_box(Vector3(3.4, 0.9, 2.0), Vector3(-0.8, 1.3, 0), Color(0.30, 0.34, 0.22), false, 0.0, null, root)
	_box(Vector3(3.5, 0.2, 2.1), Vector3(-0.8, 1.86, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	_box(Vector3(1.6, 0.14, 2.0), Vector3(1.9, 2.07, 0), SNOW_WHITE, false, 0.0, _snow_mat(), root)
	for wx in [-1.8, -0.6, 2.6]:
		for wz in [-0.9, 0.9]:
			var w := _cyl(0.45, 0.45, 0.3, Vector3(wx, 0.45, wz), Color(0.06, 0.06, 0.07), false, root)
			w.rotation.x = PI * 0.5
	_collider_box(Vector3(5.6, 2.2, 2.1), p + Vector3(0.4, 1.1, 0), 0.12)


# ================================================================ 工具函数
## 相同参数的材质只建一份——这样用到它的零碎网格才能在 _merge_static() 里合并
func _mat(color: Color, rough := 0.85, emission := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	var key := [color, rough, emission, energy]
	if not _mat_cache.has(key):
		_mat_cache[key] = _mat_new(color, rough, emission, energy)
	return _mat_cache[key]


## 需要单独改参数的材质用这个（不进缓存）
func _mat_new(color: Color, rough := 0.85, emission := Color.BLACK, energy := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINTED
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("grime", 0.2)
	return m


func _snow_mat() -> ShaderMaterial:
	if _snow_material == null:
		_snow_material = _mat_new(SNOW_WHITE, 0.95)
		_snow_material.set_shader_parameter("grime", 0.0)
		_snow_material.set_shader_parameter("variation", 0.08)
		_snow_material.set_shader_parameter("hue_drift", 0.25)
		_snow_material.set_shader_parameter("banding", 0.3)
	return _snow_material


func _sign(pos: Vector3, text: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font = _font
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.0055
	l.shaded = false
	l.modulate = color
	l.position = pos
	add_child(l)
	return l


func _light_cone(top: Vector3, height: float, radius: float, color: Color, strength: float) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.12
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 24
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = LIGHT_CONE
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("strength", strength)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = top - Vector3(0, height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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


## 把共用同一个材质的静态网格合并成一个网格。
## 整个镇子有两千多个小盒子（雪檐、隔墙、道具……），而 Web 上的 Compatibility 渲染器
## 在场景里的网格实例超过一千个左右时会整帧不出图，所以必须合并。
## 带程序化立面的建筑盒子（building.gdshader，按盒子的本地坐标排窗）和会动的东西不参与。
func _merge_static() -> void:
	var groups := {}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or _beacons.has(mi):
			continue
		var mat := mi.material_override
		if mat == null or (mat is ShaderMaterial and (mat as ShaderMaterial).shader != PAINTED):
			continue
		var key := [mat.get_instance_id(), mi.cast_shadow]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var inv := global_transform.affine_inverse()
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in list:
			st.append_from(mi.mesh, 0, inv * mi.global_transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = (list[0] as MeshInstance3D).material_override
		merged.cast_shadow = (list[0] as MeshInstance3D).cast_shadow
		add_child(merged)
		for mi: MeshInstance3D in list:
			if mi.get_child_count() == 0:
				mi.get_parent().remove_child(mi)
				mi.queue_free()
			else:
				# 还挂着碰撞体或子节点：留下节点，只去掉网格
				mi.mesh = null
