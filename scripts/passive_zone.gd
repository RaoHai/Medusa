extends Area3D
## 走进区域时自动进行一次被动技能检定，成功则内心声音会在左上角低语。

@export_enum("logic", "empathy", "hunch", "volition", "craving", "perception") var skill := "perception"
@export var difficulty := 8
@export_multiline var text := ""
@export var requires_flag := ""

var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _done or not body.is_in_group("player"):
		return
	if requires_flag != "" and not GameState.has_flag(requires_flag):
		return
	_done = true
	var r := GameState.roll_check(skill, difficulty)
	if r.success:
		GameState.passive_triggered.emit(skill, difficulty, text, r)
