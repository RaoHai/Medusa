extends Node3D
## 主场景控制：烘焙导航、鼠标拾取（移动/交互/悬停）、对话开关、开场。

const Town := preload("res://scripts/town_data.gd")

@export var intro_dialogue := "intro"
@export var location_title := "霜原-7 · 十字街口 · 极夜第四十天"

@onready var player: CharacterBody3D = $Player
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var ui: CanvasLayer = $UI
@onready var nav_region: NavigationRegion3D = $NavRegion

var _hovered: Node3D = null
var _talking_to: Node3D = null
var _click_ring: MeshInstance3D


func _ready() -> void:
	GameState.reset()
	# 镇子很大，导航网格用 0.5 米的格子烘焙；地图的格子大小要和它一致
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.5)
	# 文化宫（B122）的位置来自建筑数据，门的交互点跟着它走
	var palace := Town.pos_of("B122")
	var door: Node3D = $NavRegion/Interactables/HotelDoor
	door.position = Vector3(palace.x, 1.9, palace.z + 18.0 * Town.scale() * 0.5 + 1.6)
	nav_region.bake_navigation_mesh(false)
	ui.map_view.player = player
	player.arrived_at.connect(_on_player_arrived)
	ui.dialogue_finished.connect(_on_dialogue_finished)
	_make_click_ring()
	if intro_dialogue != "":
		player.locked = true
		await get_tree().create_timer(1.6).timeout
		ui.start_dialogue(intro_dialogue, location_title)


func _unhandled_input(event: InputEvent) -> void:
	if ui.blocks_world_input():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _pick(event.position)
		if hit.is_empty():
			return
		var target := _interactable_from(hit.collider)
		if target:
			player.go_interact(target, event.double_click)
		else:
			player.move_to(hit.position, event.double_click)
			_show_click_ring(hit.position)
	elif event is InputEventKey and event.keycode == KEY_TAB and not event.echo:
		for n in get_tree().get_nodes_in_group("interactable"):
			n.set_reveal(event.pressed)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var target: Node3D = null
	if not ui.blocks_world_input():
		var hit := _pick(get_viewport().get_mouse_position())
		if not hit.is_empty():
			target = _interactable_from(hit.collider)
	if target != _hovered:
		if _hovered:
			_hovered.set_hovered(false)
		_hovered = target
		if _hovered:
			_hovered.set_hovered(true)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if _hovered else Input.CURSOR_ARROW)
	ui.set_hover(_hovered.get_display_name() if _hovered else "")


func _pick(screen_pos: Vector2) -> Dictionary:
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 300.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _interactable_from(n: Object) -> Node3D:
	if n is Node and n.is_in_group("interactable"):
		return n
	return null


func _on_player_arrived(target: Node3D) -> void:
	if target.dialogue_id == "":
		return
	_talking_to = target
	player.locked = true
	target.on_interact_start(player)
	ui.start_dialogue(target.dialogue_id, "%s · %s" % [location_title.get_slice(" · ", 0), target.get_display_name()])


func _on_dialogue_finished() -> void:
	player.locked = false
	_talking_to = null


# ---------------------------------------------------------------- 点击反馈
func _make_click_ring() -> void:
	_click_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.22
	t.outer_radius = 0.28
	_click_ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.9, 0.8, 0.8)
	_click_ring.material_override = m
	_click_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_click_ring.visible = false
	add_child(_click_ring)


func _show_click_ring(p: Vector3) -> void:
	var map := get_world_3d().navigation_map
	_click_ring.global_position = NavigationServer3D.map_get_closest_point(map, p) + Vector3(0, 0.03, 0)
	_click_ring.visible = true
	_click_ring.scale = Vector3.ONE * 0.6
	var m: StandardMaterial3D = _click_ring.material_override
	m.albedo_color.a = 0.85
	var tw := create_tween().set_parallel()
	tw.tween_property(_click_ring, "scale", Vector3.ONE * 1.3, 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
