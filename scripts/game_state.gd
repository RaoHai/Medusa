extends Node
## 全局游戏状态：技能、检定、旗标、物品、健康/士气。
## Autoload 名称：GameState

signal stats_changed
signal notify(kind: String, text: String)
signal passive_triggered(skill: String, dc: int, text: String, result: Dictionary)
signal demo_finished

## 技能分为四类，每类有自己的颜色（智力 / 心智 / 体魄 / 运动）
const CATEGORY_COLORS := {
	"intellect": Color("6fb4d6"),
	"psyche": Color("a088d8"),
	"physique": Color("d0604e"),
	"motorics": Color("e2bb52"),
}

const SKILLS := {
	"logic": {"name": "逻辑", "cat": "intellect", "value": 3},
	"empathy": {"name": "共情", "cat": "psyche", "value": 4},
	"hunch": {"name": "直觉", "cat": "psyche", "value": 4},
	"volition": {"name": "意志", "cat": "psyche", "value": 2},
	"craving": {"name": "渴求", "cat": "physique", "value": 4},
	"perception": {"name": "感知", "cat": "motorics", "value": 3},
}

const DIFFICULTIES := [
	[6, "微不足道"], [8, "简单"], [10, "中等"], [12, "挑战"], [14, "艰难"], [16, "传奇"],
]

var flags := {}
var inventory: Array[String] = []
var thoughts: Array[String] = []
var health := 3
var morale := 3
var max_health := 4
var max_morale := 4
var player_name := "？？？"
var quest := ""
var minutes := 6 * 60 + 12  # 游戏内时间（06:12）


func _ready() -> void:
	randomize()


func reset() -> void:
	flags.clear()
	inventory.clear()
	thoughts.clear()
	health = 3
	morale = 3
	player_name = "？？？"
	quest = ""
	minutes = 6 * 60 + 12
	stats_changed.emit()


# ---------------------------------------------------------------- 旗标
func has_flag(f: String) -> bool:
	return flags.get(f, false)


func set_flag(f: String, v := true) -> void:
	flags[f] = v


func conditions_met(d: Dictionary) -> bool:
	for f in _as_array(d.get("requires", [])):
		if not has_flag(f):
			return false
	for f in _as_array(d.get("requires_not", [])):
		if has_flag(f):
			return false
	return true


func _as_array(v) -> Array:
	if v is Array:
		return v
	if v is String and v != "":
		return [v]
	return []


# ---------------------------------------------------------------- 技能 & 检定
func skill_name(id: String) -> String:
	return SKILLS.get(id, {}).get("name", id)


func skill_value(id: String) -> int:
	return SKILLS.get(id, {}).get("value", 0)


func skill_color(id: String) -> Color:
	var cat: String = SKILLS.get(id, {}).get("cat", "")
	return CATEGORY_COLORS.get(cat, Color.WHITE)


func difficulty_name(dc: int) -> String:
	var n: String = DIFFICULTIES[0][1]
	for d in DIFFICULTIES:
		if dc >= d[0]:
			n = d[1]
	return n


## 2d6 + 技能 ≥ 难度。双 1 必定失败，双 6 必定成功。
func success_chance(skill: String, dc: int) -> float:
	var ok := 0
	for a in range(1, 7):
		for b in range(1, 7):
			if _is_success(a, b, skill_value(skill), dc):
				ok += 1
	return ok / 36.0


func roll_check(skill: String, dc: int) -> Dictionary:
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	var v := skill_value(skill)
	return {
		"dice": [a, b],
		"bonus": v,
		"total": a + b + v,
		"dc": dc,
		"success": _is_success(a, b, v, dc),
		"critical": (a == 6 and b == 6) or (a == 1 and b == 1),
	}


func _is_success(a: int, b: int, v: int, dc: int) -> bool:
	if a == 1 and b == 1:
		return false
	if a == 6 and b == 6:
		return true
	return a + b + v >= dc


# ---------------------------------------------------------------- 效果
func apply_effects(node: Dictionary) -> void:
	for f in _as_array(node.get("set", [])):
		set_flag(f)
	for f in _as_array(node.get("unset", [])):
		set_flag(f, false)
	var fx: Dictionary = node.get("effects", {})
	if fx.has("health"):
		change_health(fx["health"])
	if fx.has("morale"):
		change_morale(fx["morale"])
	if node.has("add_item"):
		inventory.append(node["add_item"])
		notify.emit("item", "获得物品：" + node["add_item"])
	if node.has("remove_item"):
		inventory.erase(node["remove_item"])
		notify.emit("item", "失去物品：" + node["remove_item"])
	if node.has("thought"):
		thoughts.append(node["thought"])
		notify.emit("thought", "新的念头：『%s』" % node["thought"])
	if node.has("quest"):
		quest = node["quest"]
		notify.emit("quest", "任务更新：" + quest)
	if node.has("name"):
		player_name = node["name"]
	if node.get("end_demo", false):
		demo_finished.emit()
	stats_changed.emit()


func change_health(d: int) -> void:
	health = clampi(health + d, 1, max_health)
	notify.emit("health", "健康 %s%d" % ["+" if d > 0 else "", d])
	stats_changed.emit()


func change_morale(d: int) -> void:
	morale = clampi(morale + d, 1, max_morale)
	notify.emit("morale", "士气 %s%d" % ["+" if d > 0 else "", d])
	if morale == 1 and d < 0:
		notify.emit("info", "你的士气濒临崩溃……")
	stats_changed.emit()


func clock_text() -> String:
	return "%02d:%02d" % [(minutes / 60) % 24, minutes % 60]
