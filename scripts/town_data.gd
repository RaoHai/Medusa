@tool
extends RefCounted
## 城镇数据：从 data/buildings.json 读取建筑轮廓（《建筑编号索引》的坐标系，单位米），
## 并换算成游戏里的世界坐标。地图界面和场景搭建共用这一份数据。

const PATH := "res://data/buildings.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_error("读不到 " + PATH)
			_data = {"origin": [0, 0], "scale": 0.33, "buildings": []}
		else:
			_data = JSON.parse_string(f.get_as_text())
	return _data


static func buildings() -> Array:
	return data()["buildings"]


static func scale() -> float:
	return data()["scale"]


## 索引图坐标（米）→ 世界坐标
static func to_world(mx: float, mz: float) -> Vector3:
	var o: Array = data()["origin"]
	return Vector3((mx - o[0]) * scale(), 0.0, (mz - o[1]) * scale())


## 世界坐标 → 索引图坐标（米）
static func to_map(p: Vector3) -> Vector2:
	var o: Array = data()["origin"]
	return Vector2(p.x / scale() + o[0], p.z / scale() + o[1])


## 一栋楼在游戏里的世界坐标。
## 数据里有 wx / wz（tools/relax_layout.py 挤紧街区后算出来的）就用它，
## 没有就按索引图坐标直接换算。
static func pos(b: Dictionary) -> Vector3:
	if b.has("wx") and b.has("wz"):
		return Vector3(b["wx"], 0.0, b["wz"])
	return to_world(b["x"], b["z"])


static func by_id(id: String) -> Dictionary:
	for b in buildings():
		if b["id"] == id:
			return b
	return {}


static func pos_of(id: String) -> Vector3:
	var b := by_id(id)
	return pos(b) if not b.is_empty() else Vector3.ZERO
