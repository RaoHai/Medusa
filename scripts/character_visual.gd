@tool
extends Node3D
## 用基础几何体拼出的风格化人物（风衣、帽子、围巾），带简单的走路/呼吸动画。
## 人物正面朝向本地 +Z。

const PAINTED := preload("res://shaders/painted.gdshader")

@export var coat_color := Color(0.30, 0.24, 0.17):
	set(v):
		coat_color = v
		_rebuild()
@export var pants_color := Color(0.11, 0.11, 0.13):
	set(v):
		pants_color = v
		_rebuild()
@export var skin_color := Color(0.80, 0.62, 0.50):
	set(v):
		skin_color = v
		_rebuild()
@export var hair_color := Color(0.16, 0.11, 0.08):
	set(v):
		hair_color = v
		_rebuild()
@export var has_hat := false:
	set(v):
		has_hat = v
		_rebuild()
@export var hat_color := Color(0.14, 0.12, 0.11):
	set(v):
		hat_color = v
		_rebuild()
## 护耳帽：帽檐换成垂下来的两片护耳
@export var ushanka := false:
	set(v):
		ushanka = v
		_rebuild()
@export var has_scarf := false:
	set(v):
		has_scarf = v
		_rebuild()
@export var scarf_color := Color(0.45, 0.12, 0.10):
	set(v):
		scarf_color = v
		_rebuild()
@export_range(0.8, 1.2) var body_scale := 1.0:
	set(v):
		body_scale = v
		_rebuild()
@export_range(0.0, 0.5) var stoop := 0.0:
	set(v):
		stoop = v
		_rebuild()

## 0 = 站立，1 = 全速走
var walk_amount := 0.0
var _phase := 0.0
var _t := 0.0
var _root: Node3D
var _upper: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _root:
		_root.free()
	_root = Node3D.new()
	_root.name = "_Generated"
	_root.scale = Vector3.ONE * body_scale
	add_child(_root)

	var coat := _mat(coat_color)
	var pants := _mat(pants_color)
	var skin := _mat(skin_color, 0.7)
	var hair := _mat(hair_color)

	# 腿
	_leg_l = _pivot(_root, Vector3(-0.11, 0.9, 0))
	_leg_r = _pivot(_root, Vector3(0.11, 0.9, 0))
	for leg in [_leg_l, _leg_r]:
		_capsule(leg, 0.085, 0.9, Vector3(0, -0.45, 0), pants)
		_box(leg, Vector3(0.14, 0.08, 0.26), Vector3(0, -0.88, 0.05), _mat(Color(0.07, 0.06, 0.06), 0.4))

	# 上半身（可前倾）
	_upper = _pivot(_root, Vector3(0, 0.9, 0))
	_upper.rotation.x = stoop
	# 风衣下摆
	var skirt := _cyl(_upper, 0.25, 0.34, 0.75, Vector3(0, -0.12, 0), coat)
	skirt.scale = Vector3(1.0, 1.0, 0.82)
	# 躯干
	var torso := _capsule(_upper, 0.24, 0.8, Vector3(0, 0.45, 0), coat)
	torso.scale = Vector3(1.15, 1.0, 0.78)
	# 领子
	var collar := _cyl(_upper, 0.17, 0.22, 0.14, Vector3(0, 0.78, 0), coat)
	collar.scale = Vector3(1.1, 1, 0.9)
	if has_scarf:
		_cyl(_upper, 0.15, 0.16, 0.11, Vector3(0, 0.8, 0.0), _mat(scarf_color))
		_box(_upper, Vector3(0.09, 0.32, 0.04), Vector3(0.07, 0.6, 0.2), _mat(scarf_color))
	# 手臂
	_arm_l = _pivot(_upper, Vector3(-0.29, 0.7, 0))
	_arm_r = _pivot(_upper, Vector3(0.29, 0.7, 0))
	for arm in [_arm_l, _arm_r]:
		_capsule(arm, 0.075, 0.72, Vector3(0, -0.33, 0), coat)
		_sphere(arm, 0.06, Vector3(0, -0.7, 0.02), skin)
	_arm_l.rotation.z = -0.08
	_arm_r.rotation.z = 0.08
	# 头
	var head := _pivot(_upper, Vector3(0, 0.95, 0.02))
	_sphere(head, 0.14, Vector3.ZERO, skin).scale = Vector3(0.95, 1.08, 1.0)
	_box(head, Vector3(0.035, 0.06, 0.05), Vector3(0, -0.01, 0.14), skin)  # 鼻子
	var h := _sphere(head, 0.148, Vector3(0, 0.035, -0.02), hair)
	h.scale = Vector3(1.0, 0.85, 1.0)
	if has_hat and ushanka:
		var fur := _mat(hat_color)
		var crown := _cyl(head, 0.155, 0.165, 0.15, Vector3(0, 0.1, -0.005), fur)
		crown.scale = Vector3(1.0, 1.0, 1.05)
		_box(head, Vector3(0.26, 0.09, 0.05), Vector3(0, 0.1, 0.15), _mat(hat_color.lightened(0.12)))
		for sx in [-1.0, 1.0]:
			_box(head, Vector3(0.05, 0.2, 0.17), Vector3(sx * 0.155, -0.02, -0.01), fur)
		_box(head, Vector3(0.04, 0.04, 0.01), Vector3(0, 0.11, 0.178), _mat(Color(0.7, 0.12, 0.09)))
	elif has_hat:
		var hm := _mat(hat_color)
		_cyl(head, 0.27, 0.27, 0.025, Vector3(0, 0.1, 0), hm)
		_cyl(head, 0.14, 0.16, 0.16, Vector3(0, 0.19, 0), hm)
		_cyl(head, 0.162, 0.162, 0.035, Vector3(0, 0.13, 0), _mat(Color(0.05, 0.05, 0.05)))


func _process(delta: float) -> void:
	if _root == null:
		return
	_t += delta
	_phase += delta * 9.0 * walk_amount
	var s := sin(_phase)
	var w := walk_amount
	_leg_l.rotation.x = s * 0.55 * w
	_leg_r.rotation.x = -s * 0.55 * w
	_arm_l.rotation.x = -s * 0.4 * w
	_arm_r.rotation.x = s * 0.4 * w
	var breathe := sin(_t * 1.8) * 0.012 * (1.0 - w)
	_root.position.y = absf(cos(_phase)) * 0.045 * w
	_upper.scale = Vector3(1.0 + breathe, 1.0 + breathe * 0.5, 1.0 + breathe)
	_upper.rotation.x = stoop + 0.08 * w


# ---------------------------------------------------------------- 几何体工具
func _mat(c: Color, rough := 0.85) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINTED
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("noise_scale", 6.0)
	m.set_shader_parameter("grime", 0.0)
	m.set_shader_parameter("variation", 0.15)
	# 一点自发光补光，让人物在暗处也能从背景里读出来
	m.set_shader_parameter("emission", c)
	m.set_shader_parameter("emission_energy", 0.22)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return _add_mesh(parent, m, pos, mat)


func _cyl(parent: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return _add_mesh(parent, m, pos, mat)


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return _add_mesh(parent, m, pos, mat)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(parent, m, pos, mat)
