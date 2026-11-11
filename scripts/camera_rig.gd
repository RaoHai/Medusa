extends Node3D
## 等轴（isometric）正交相机：俯角 35.264°，偏航 45°。平滑跟随目标，滚轮缩放。

@export var target_path: NodePath
@export var follow_speed := 3.5
@export var zoom := 22.0
@export var min_zoom := 9.0
@export var max_zoom := 80.0
## 相机到目标的距离。建筑着色器里的 camera_distance 要和它一致（用于镂空挡住人物的墙）
@export var distance := 220.0

@onready var cam: Camera3D = $Camera3D
var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.near = 0.5
	cam.far = 700.0
	cam.rotation_degrees = Vector3(-35.264, 45.0, 0.0)
	cam.position = cam.transform.basis.z * distance
	if _target:
		global_position = _target.global_position


func _process(delta: float) -> void:
	if _target:
		global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
	cam.size = lerpf(cam.size, zoom, 1.0 - exp(-8.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom * 0.9, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom * 1.1, min_zoom, max_zoom)
