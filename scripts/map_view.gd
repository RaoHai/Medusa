extends Control
## 《建筑编号索引》地图（按 M 开关）。
## 直接用 data/buildings.json 里的轮廓来画，所以和场景里的建筑一一对应。

const Town := preload("res://scripts/town_data.gd")

const PAPER := Color("e4d8ba")
const INK := Color("1a1614")
const RED := Color("c8281e")
const KIND_COLORS := {
	"ruin": Color("a9aca6"),
	"husk": Color("8f948f"),
	"block": Color("d9a066"),
	"public": Color("7fb3cc"),
}
## 地图范围（米，索引图坐标）
const BOUNDS := Rect2(-280, -560, 990, 990)
## 道路（世界坐标）——和 level_builder.gd 里的一致
const ROADS := [
	[Vector2(0, -150), Vector2(0, 62)], [Vector2(-62, 0), Vector2(92, 0)],
	[Vector2(0, -150), Vector2(-48, -160)], [Vector2(0, 62), Vector2(40, 84)],
]

var player: Node3D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func toggle() -> void:
	visible = not visible
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		visible = false
		accept_event()


func _draw() -> void:
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.04, 0.72))
	var margin := Vector2(120, 70)
	var sheet := Rect2(margin, size - margin * 2.0)
	draw_rect(sheet, PAPER)
	draw_rect(Rect2(sheet.position, Vector2(sheet.size.x, 54)), RED)
	draw_string(font, sheet.position + Vector2(24, 37), "建筑编号索引 | B001–B132", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PAPER)
	draw_string(font, sheet.position + Vector2(sheet.size.x - 330, 36), "国家建筑普查委员会 · 霜原-7", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PAPER)
	# 斜向的黑条：构成主义的版式
	var c := sheet.position + Vector2(sheet.size.x - 30, 54)
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(-60, 0), c + Vector2(-130, 70), c + Vector2(-70, 70)]), INK)

	var area := Rect2(sheet.position + Vector2(30, 84), sheet.size - Vector2(60, 150))
	var k := minf(area.size.x / BOUNDS.size.x, area.size.y / BOUNDS.size.y)
	var off := area.position + (area.size - BOUNDS.size * k) * 0.5 - BOUNDS.position * k
	# 网格（每 100 米）
	var gx := ceilf(BOUNDS.position.x / 100.0) * 100.0
	while gx < BOUNDS.end.x:
		draw_line(off + Vector2(gx, BOUNDS.position.y) * k, off + Vector2(gx, BOUNDS.end.y) * k, Color(INK, 0.1), 1.0)
		gx += 100.0
	var gz := ceilf(BOUNDS.position.y / 100.0) * 100.0
	while gz < BOUNDS.end.y:
		draw_line(off + Vector2(BOUNDS.position.x, gz) * k, off + Vector2(BOUNDS.end.x, gz) * k, Color(INK, 0.1), 1.0)
		gz += 100.0
	# 道路
	for r in ROADS:
		var a := Town.to_map(Vector3(r[0].x, 0, r[0].y))
		var b := Town.to_map(Vector3(r[1].x, 0, r[1].y))
		draw_line(off + a * k, off + b * k, Color(INK, 0.28), 5.0)
	# 界外的五个原轮廓：只有虚线和问号
	var outside := [Vector2(395, -530), Vector2(430, -522), Vector2(465, -534), Vector2(410, -505), Vector2(452, -503)]
	for i in outside.size():
		var p: Vector2 = off + outside[i] * k
		var blink := 0.45 + 0.35 * sin(_t * 2.0 + i)
		draw_rect(Rect2(p - Vector2(9, 5), Vector2(18, 10)), Color(RED, blink), false, 1.5)
	draw_string(font, off + Vector2(482, -514) * k, "五个原轮廓 ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED)
	draw_dashed_line(off + Vector2(BOUNDS.position.x, -480) * k, off + Vector2(BOUNDS.end.x, -480) * k, Color(RED, 0.7), 1.5, 8.0)
	draw_string(font, off + Vector2(BOUNDS.position.x + 6, -488) * k, "界 外", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, RED)
	# 建筑
	for b in Town.buildings():
		var center := Vector2(b["x"], b["z"])
		var hl: float = b["len"] * 0.5
		var hw: float = b["wid"] * 0.5
		var ang := deg_to_rad(b["rot"])
		var pts := PackedVector2Array()
		for corner in [Vector2(-hl, -hw), Vector2(hl, -hw), Vector2(hl, hw), Vector2(-hl, hw)]:
			pts.append(off + (center + corner.rotated(ang)) * k)
		var col: Color = KIND_COLORS.get(b["kind"], Color.GRAY)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(INK, 0.55), 1.0)
		if hl > 12.0 and not String(b["id"]).ends_with("b"):
			draw_string(font, off + center * k + Vector2(-13, 4), b["id"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(INK, 0.85))
	# 厂区
	draw_string(font, off + Town.to_map(Vector3(14, 0, -176)) * k + Vector2(-28, 4), "▲ 热电厂", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	draw_string(font, off + Town.to_map(Vector3(-52, 0, -172)) * k + Vector2(-80, 4), "▲ 选矿厂", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
	# 你在这里
	if player:
		var pp: Vector2 = off + Town.to_map(player.global_position) * k
		var pulse := 6.0 + 2.5 * sin(_t * 4.0)
		draw_circle(pp, pulse + 3.0, Color(RED, 0.25))
		draw_circle(pp, 5.0, RED)
		draw_string(font, pp + Vector2(10, -8), "你在这里", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RED)
	# 图例与图注
	var ly := sheet.end.y - 48
	var lx := sheet.position.x + 30
	for item in [["ruin", "无顶废墟"], ["husk", "停暖的空楼"], ["block", "住人的楼"], ["public", "公共建筑"]]:
		draw_rect(Rect2(lx, ly, 18, 12), KIND_COLORS[item[0]])
		draw_rect(Rect2(lx, ly, 18, 12), Color(INK, 0.6), false, 1.0)
		draw_string(font, Vector2(lx + 26, ly + 12), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
		lx += 150
	draw_string(font, Vector2(sheet.position.x + 30, sheet.end.y - 14), "编号分配后不重排。当前 127 栋位于界内，5 个原轮廓在边界外。　　按 M 或点击关闭", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(INK, 0.7))
