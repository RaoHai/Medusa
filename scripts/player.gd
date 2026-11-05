extends CharacterBody3D
## 点击移动的玩家角色：用 NavigationServer3D 求路径（只按水平距离推进），
## 靠近可交互物后发出 arrived_at 信号。

signal arrived_at(target: Node3D)

@export var walk_speed := 3.0
@export var run_speed := 5.6

@onready var visual: Node3D = $Visual

var locked := false
var _moving := false
var _speed := 3.0
var _target: Node3D = null
var _path: PackedVector3Array = []
var _path_i := 0


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("player")


func move_to(point: Vector3, run := false) -> void:
	_target = null
	_set_destination(point, run)


func go_interact(target: Node3D, run := false) -> void:
	_target = target
	if _flat_dist(target.global_position) <= target.interact_distance:
		_arrive()
		return
	_set_destination(target.get_approach_point(global_position), run)


func stop() -> void:
	_moving = false
	velocity = Vector3.ZERO


func face(point: Vector3) -> void:
	var d := point - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		var tw := create_tween()
		tw.tween_property(visual, "rotation:y", _target_angle(visual.rotation.y, atan2(d.x, d.z)), 0.25)


func _set_destination(p: Vector3, run: bool) -> void:
	var map := get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, p, true)
	_path_i = 0
	_speed = run_speed if run else walk_speed
	_moving = not _path.is_empty()
	if not _moving and _target:
		_arrive()


func _physics_process(delta: float) -> void:
	if locked or not _moving:
		visual.walk_amount = move_toward(visual.walk_amount, 0.0, delta * 5.0)
		return
	if _target and _flat_dist(_target.global_position) <= _target.interact_distance:
		_arrive()
		return
	# 跳过已经到达的路径点（只比较水平距离，导航网格高度可能略有偏移）
	while _path_i < _path.size() and _flat_dist(_path[_path_i]) < 0.15:
		_path_i += 1
	if _path_i >= _path.size():
		if _target:
			_arrive()
		else:
			stop()
		return
	var next := _path[_path_i]
	var dir := next - global_position
	dir.y = 0.0
	var dist := dir.length()
	dir = dir.normalized()
	velocity = dir * minf(_speed, dist / delta)
	move_and_slide()
	global_position.y = 0.0
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
	var amt := 1.0 if _speed <= walk_speed else 1.5
	visual.walk_amount = move_toward(visual.walk_amount, amt, delta * 6.0)


func _arrive() -> void:
	var t := _target
	_target = null
	stop()
	face(t.global_position)
	arrived_at.emit(t)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _target_angle(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)
