extends StaticBody3D
## 可点击交互的物件 / NPC。放在 collision layer 2（interact）上。
## 鼠标悬停或按住 Tab 时，头顶会出现一个发光的小圆点。

@export var display_name := "物件"
## 满足 name_flag 后显示 alt_name（例如问出 NPC 的名字之后）
@export var alt_name := ""
@export var name_flag := ""
@export var dialogue_id := ""
@export var interact_distance := 1.7
@export var marker_height := 2.2
## 交互时让 Visual 子节点转向玩家（NPC 用）
@export var turn_to_player := false

var _marker: MeshInstance3D
var _hovered := false
var _reveal := false
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	_marker = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.11
	s.height = 0.22
	_marker.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 0.85)
	m.no_depth_test = true
	m.render_priority = 10
	_marker.material_override = m
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	_marker.global_position = global_position + Vector3(0, marker_height - global_position.y, 0)
	_marker.top_level = true


func _process(delta: float) -> void:
	_t += delta
	_marker.visible = _hovered or _reveal
	if _marker.visible:
		var y := marker_height + sin(_t * 3.0) * 0.06
		_marker.global_position = Vector3(global_position.x, y, global_position.z)
		_marker.scale = Vector3.ONE * (1.35 if _hovered else 1.0)


func set_hovered(v: bool) -> void:
	_hovered = v


func set_reveal(v: bool) -> void:
	_reveal = v


func get_display_name() -> String:
	if alt_name != "" and name_flag != "" and GameState.has_flag(name_flag):
		return alt_name
	return display_name


func get_approach_point(from: Vector3) -> Vector3:
	var d := from - global_position
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(0, 0, 1)
	var p := global_position + d.normalized() * interact_distance * 0.8
	p.y = 0.0
	return p


func on_interact_start(player: Node3D) -> void:
	if turn_to_player and has_node("Visual"):
		var v: Node3D = $Visual
		var d := player.global_position - global_position
		var target := atan2(d.x, d.z)
		var tw := create_tween()
		tw.tween_property(v, "rotation:y", v.rotation.y + wrapf(target - v.rotation.y, -PI, PI), 0.35)
