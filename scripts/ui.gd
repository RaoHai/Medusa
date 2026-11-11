extends CanvasLayer
## HUD（苏联朋克风格：红、奶油、墨黑三色，粗字、色块、斜条）：
## 任务、工作证式的角色卡、电报式通知、被动检定低语、悬停名称、对话面板、编号索引地图。

signal dialogue_finished

const DialoguePanel := preload("res://scripts/dialogue_panel.gd")
const MapView := preload("res://scripts/map_view.gd")
const Fonts := preload("res://scripts/fonts.gd")

const RED := Color("c8281e")
const CREAM := Color("e8dcc0")
const PAPER := Color("e4d8ba")
const INK := Color("14110f")
const COL_DIM := Color("8a8175")
const COL_HEALTH := Color("c8281e")
const COL_MORALE := Color("2f5f9c")

var root: Control
var dialogue: PanelContainer
var map_view: Control
var _quest_label: Label
var _name_label: Label
var _health_label: RichTextLabel
var _morale_label: RichTextLabel
var _clock_label: Label
var _items_label: Label
var _toasts: VBoxContainer
var _whisper: PanelContainer
var _whisper_text: RichTextLabel
var _whisper_tween: Tween
var _hover: PanelContainer
var _hover_label: Label
var _fade: ColorRect
var _clock_accum := 0.0


func _ready() -> void:
	root = Control.new()
	_place(root, Vector4(0, 0, 1, 1), Vector4.ZERO)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	_build_quest()
	_build_card()
	_build_hint()
	_build_toasts()
	_build_whisper()
	_build_hover()

	dialogue = DialoguePanel.new()
	root.add_child(dialogue)
	_place(dialogue, Vector4(1, 0, 1, 1), Vector4(-600, 0, 0, 0))
	dialogue.finished.connect(func(): dialogue_finished.emit())

	map_view = MapView.new()
	root.add_child(map_view)
	_place(map_view, Vector4(0, 0, 1, 1), Vector4.ZERO)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_place(_fade, Vector4(0, 0, 1, 1), Vector4.ZERO)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 2.5).set_delay(0.3)

	GameState.stats_changed.connect(_refresh)
	GameState.notify.connect(_on_notify)
	GameState.passive_triggered.connect(_on_passive)
	_refresh()


func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum >= 8.0:
		_clock_accum = 0.0
		GameState.minutes += 1
		_clock_label.text = GameState.clock_text()
	if _hover.visible:
		_hover.position = root.get_local_mouse_position() + Vector2(18, 14)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and not dialogue.is_open():
			map_view.toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and map_view.visible:
			map_view.visible = false
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 公共接口
func is_dialogue_open() -> bool:
	return dialogue.is_open()


## 对话或地图打开时，世界不响应鼠标
func blocks_world_input() -> bool:
	return dialogue.is_open() or map_view.visible


func start_dialogue(id: String, title: String) -> void:
	set_hover("")
	map_view.visible = false
	dialogue.open(id, title)


func set_hover(text: String) -> void:
	_hover.visible = text != ""
	_hover_label.text = text
	_hover.reset_size()


# ---------------------------------------------------------------- 刷新
func _refresh() -> void:
	_quest_label.text = GameState.quest if GameState.quest != "" else "……"
	_name_label.text = GameState.player_name
	_health_label.text = "[color=#5a5148]健康[/color]  %s" % _pips(GameState.health, GameState.max_health, COL_HEALTH)
	_morale_label.text = "[color=#5a5148]士气[/color]  %s" % _pips(GameState.morale, GameState.max_morale, COL_MORALE)
	_clock_label.text = GameState.clock_text()
	_items_label.text = "随身：" + ("、".join(GameState.inventory) if not GameState.inventory.is_empty() else "无")


func _pips(v: int, m: int, c: Color) -> String:
	var s := ""
	for i in m:
		s += "[color=#%s]■[/color] " % (c.to_html(false) if i < v else "bdb193")
	return s


func _on_notify(kind: String, text: String) -> void:
	var accent := RED
	match kind:
		"morale": accent = COL_MORALE.lightened(0.25)
		"quest": accent = Color("e2bb52")
		"thought": accent = Color("a088d8")
		"item": accent = CREAM
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.93)
	sb.border_width_left = 8
	sb.border_color = accent
	sb.content_margin_left = 18
	sb.content_margin_right = 20
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_font_size_override("font_size", 17)
	p.add_child(l)
	_toasts.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.8)
	tw.tween_callback(p.queue_free)


func _on_passive(skill: String, dc: int, text: String, _result: Dictionary) -> void:
	_whisper_text.text = "[b][color=#%s]%s[/color][/b] [color=#%s][%s：成功][/color]\n%s" % [
		GameState.skill_color(skill).to_html(false), GameState.skill_name(skill), COL_DIM.to_html(false),
		GameState.difficulty_name(dc), text]
	_whisper.visible = true
	if _whisper_tween:
		_whisper_tween.kill()
	_whisper.modulate.a = 0.0
	_whisper_tween = create_tween()
	_whisper_tween.tween_property(_whisper, "modulate:a", 1.0, 0.5)
	_whisper_tween.tween_interval(7.0)
	_whisper_tween.tween_property(_whisper, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------- 布局
## anchors = (left, top, right, bottom)，offsets 同顺序
func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.make(600)
	t.set_font("bold_font", "RichTextLabel", Fonts.make(900))
	t.set_font("italics_font", "RichTextLabel", Fonts.make(400, 0.18))
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	t.set_color("default_color", "RichTextLabel", CREAM)
	return t


func _flat(bg: Color, margin := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.content_margin_left = margin + 4
	sb.content_margin_right = margin + 4
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	return sb


## 红色抬头条 + 内容区，像一张表格的栏目
func _slab(title: String, body_bg: Color) -> Array:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(RED, 8))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl := Label.new()
	hl.text = title
	hl.add_theme_font_override("font", Fonts.make(900))
	hl.add_theme_font_size_override("font_size", 14)
	hl.add_theme_color_override("font_color", CREAM)
	head.add_child(hl)
	outer.add_child(head)
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", _flat(body_bg))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(body)
	return [outer, body, hl]


func _build_quest() -> void:
	var parts := _slab("★ 当前任务", Color(INK, 0.9))
	var outer: VBoxContainer = parts[0]
	outer.position = Vector2(24, 22)
	root.add_child(outer)
	_quest_label = Label.new()
	_quest_label.add_theme_font_override("font", Fonts.make(800))
	_quest_label.add_theme_font_size_override("font_size", 20)
	_quest_label.add_theme_color_override("font_color", CREAM)
	(parts[1] as PanelContainer).add_child(_quest_label)


func _build_card() -> void:
	# 一张奶油色的“工作证”
	var parts := _slab("工作证 · 国家建筑普查委员会", PAPER)
	var outer: VBoxContainer = parts[0]
	root.add_child(outer)
	outer.custom_minimum_size = Vector2(300, 0)
	_place(outer, Vector4(0, 1, 0, 1), Vector4(24, -24, 324, -24))
	outer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	(parts[1] as PanelContainer).add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_override("font", Fonts.make(900))
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", INK)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name_label)
	_clock_label = Label.new()
	_clock_label.add_theme_color_override("font_color", RED)
	_clock_label.add_theme_font_override("font", Fonts.make(900))
	top.add_child(_clock_label)
	_health_label = _rich_line()
	v.add_child(_health_label)
	_morale_label = _rich_line()
	v.add_child(_morale_label)
	_items_label = Label.new()
	_items_label.add_theme_font_size_override("font_size", 14)
	_items_label.add_theme_color_override("font_color", Color("5a5148"))
	v.add_child(_items_label)


func _rich_line() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(220, 0)
	return r


func _build_hint() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(INK, 0.78), 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	_place(p, Vector4(0.5, 1, 0.5, 1), Vector4(0, -14, 0, -14))
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var l := Label.new()
	l.text = "左键 移动 / 交互　·　双击 奔跑　·　滚轮 缩放　·　Tab 显示可交互物　·　M 地图"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(CREAM, 0.85))
	p.add_child(l)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 6)
	root.add_child(_toasts)
	_place(_toasts, Vector4(0.5, 0, 0.5, 0), Vector4(0, 24, 0, 24))
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _build_whisper() -> void:
	_whisper = PanelContainer.new()
	var sb := _flat(Color(INK, 0.9))
	sb.border_width_left = 8
	sb.border_color = RED
	_whisper.add_theme_stylebox_override("panel", sb)
	_whisper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whisper.position = Vector2(24, 116)
	_whisper.custom_minimum_size = Vector2(430, 0)
	_whisper.visible = false
	root.add_child(_whisper)
	_whisper_text = RichTextLabel.new()
	_whisper_text.bbcode_enabled = true
	_whisper_text.fit_content = true
	_whisper_text.scroll_active = false
	_whisper_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whisper_text.add_theme_font_size_override("normal_font_size", 17)
	_whisper_text.add_theme_font_size_override("bold_font_size", 17)
	_whisper.add_child(_whisper_text)


func _build_hover() -> void:
	_hover = PanelContainer.new()
	_hover.add_theme_stylebox_override("panel", _flat(RED, 6))
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.visible = false
	root.add_child(_hover)
	_hover_label = Label.new()
	_hover_label.add_theme_font_override("font", Fonts.make(900))
	_hover_label.add_theme_font_size_override("font_size", 16)
	_hover_label.add_theme_color_override("font_color", CREAM)
	_hover.add_child(_hover_label)
