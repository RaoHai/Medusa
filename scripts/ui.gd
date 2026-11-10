extends CanvasLayer
## HUD：任务、角色卡（健康/士气）、物品、提示、通知、被动检定低语、悬停名称，以及对话面板。

signal dialogue_finished

const DialoguePanel := preload("res://scripts/dialogue_panel.gd")
const Fonts := preload("res://scripts/fonts.gd")

const COL_TEXT := Color("d8cfc0")
const COL_DIM := Color("8a8175")
const COL_HEALTH := Color("c4513f")
const COL_MORALE := Color("5e8fc4")

var root: Control
var dialogue: PanelContainer
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
		var mp := root.get_local_mouse_position()
		_hover.position = mp + Vector2(18, 14)


# ---------------------------------------------------------------- 公共接口
func is_dialogue_open() -> bool:
	return dialogue.is_open()


func start_dialogue(id: String, title: String) -> void:
	set_hover("")
	dialogue.open(id, title)


func set_hover(text: String) -> void:
	_hover.visible = text != ""
	_hover_label.text = text
	_hover.reset_size()


# ---------------------------------------------------------------- 刷新
func _refresh() -> void:
	_quest_label.text = GameState.quest if GameState.quest != "" else "……"
	_name_label.text = GameState.player_name
	_health_label.text = "[color=#%s]健康[/color]  %s" % [COL_DIM.to_html(false), _pips(GameState.health, GameState.max_health, COL_HEALTH)]
	_morale_label.text = "[color=#%s]士气[/color]  %s" % [COL_DIM.to_html(false), _pips(GameState.morale, GameState.max_morale, COL_MORALE)]
	_clock_label.text = GameState.clock_text()
	_items_label.text = "物品：" + ("、".join(GameState.inventory) if not GameState.inventory.is_empty() else "无")


func _pips(v: int, m: int, c: Color) -> String:
	var s := ""
	for i in m:
		s += "[color=#%s]■[/color] " % (c.to_html(false) if i < v else "3a3530")
	return s


func _on_notify(kind: String, text: String) -> void:
	var col := COL_TEXT
	match kind:
		"health": col = COL_HEALTH.lightened(0.2)
		"morale": col = COL_MORALE.lightened(0.2)
		"quest": col = Color("e2bb52")
		"thought": col = Color("a088d8").lightened(0.2)
		"item": col = Color("d8cfc0")
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, 0.88)
	sb.border_width_bottom = 2
	sb.border_color = col.darkened(0.3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
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
	_whisper_tween.tween_interval(6.0)
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
	t.default_font = Fonts.make(500)
	t.set_font("bold_font", "RichTextLabel", Fonts.make(800))
	t.set_font("italics_font", "RichTextLabel", Fonts.make(400, 0.18))
	t.default_font_size = 18
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("default_color", "RichTextLabel", COL_TEXT)
	return t


func _panel_style(alpha := 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.04, alpha)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _build_quest() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _panel_style(0.7))
	p.position = Vector2(24, 22)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var h := Label.new()
	h.text = "当前任务"
	h.add_theme_font_size_override("font_size", 13)
	h.add_theme_color_override("font_color", COL_DIM)
	v.add_child(h)
	_quest_label = Label.new()
	_quest_label.add_theme_font_size_override("font_size", 19)
	_quest_label.add_theme_color_override("font_color", Color("e2bb52"))
	v.add_child(_quest_label)


func _build_card() -> void:
	var p := PanelContainer.new()
	var sb := _panel_style(0.85)
	sb.border_width_top = 2
	sb.border_color = Color(0.36, 0.29, 0.2)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	p.custom_minimum_size = Vector2(260, 0)
	_place(p, Vector4(0, 1, 0, 1), Vector4(24, -24, 284, -24))
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name_label)
	_clock_label = Label.new()
	_clock_label.add_theme_color_override("font_color", COL_DIM)
	top.add_child(_clock_label)
	_health_label = _rich_line()
	v.add_child(_health_label)
	_morale_label = _rich_line()
	v.add_child(_morale_label)
	_items_label = Label.new()
	_items_label.add_theme_font_size_override("font_size", 14)
	_items_label.add_theme_color_override("font_color", COL_DIM)
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
	var l := Label.new()
	l.text = "左键 移动 / 交互　·　双击 奔跑　·　滚轮 缩放　·　按住 Tab 显示可交互物"
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62, 0.6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	_place(l, Vector4(0, 1, 1, 1), Vector4(0, -40, 0, -14))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 8)
	root.add_child(_toasts)
	_place(_toasts, Vector4(0.5, 0, 0.5, 0), Vector4(0, 24, 0, 24))
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _build_whisper() -> void:
	_whisper = PanelContainer.new()
	var sb := _panel_style(0.8)
	sb.border_width_left = 3
	sb.border_color = Color(0.4, 0.34, 0.25)
	_whisper.add_theme_stylebox_override("panel", sb)
	_whisper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_whisper.position = Vector2(24, 110)
	_whisper.custom_minimum_size = Vector2(420, 0)
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
	var sb := _panel_style(0.85)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	_hover.add_theme_stylebox_override("panel", sb)
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.visible = false
	root.add_child(_hover)
	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 16)
	_hover.add_child(_hover_label)
