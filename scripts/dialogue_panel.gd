extends PanelContainer
## 右侧对话面板：滚动日志 + 打字机效果 + 编号选项 + 2d6 技能检定。
## 空格 / 回车 / 点击面板：跳过打字；数字键 1-9：选择选项。

signal finished

const DB := preload("res://scripts/dialogue_db.gd")

const COL_TEXT := Color("d8cfc0")
const COL_NARRATION := Color("a89f92")
const COL_SPEAKER := Color("efe4d2")
const COL_YOU := Color("c9a46a")
const COL_OPTION := Color("c9533f")
const COL_OPTION_HOVER := Color("f2e6d4")
const COL_RED_CHECK := Color("e0503c")
const COL_DIM := Color("7d756b")

enum State { IDLE, TYPING, PAUSE, OPTIONS }

var _header: Label
var _log: RichTextLabel
var _options_box: VBoxContainer
var _hint: Label

var _state := State.IDLE
var _node_id := ""
var _node: Dictionary = {}
var _queue: Array = []
var _pause := 0.0
var _tween: Tween
var _fade: Tween
var _open := false
var _visible_options: Array = []  # [{opt, key}]


func _ready() -> void:
	_build()
	visible = false


func is_open() -> bool:
	return _open


func open(dialogue_id: String, title: String) -> void:
	visible = true
	_open = true
	_header.text = title
	_log.clear()
	_log.text = ""
	_clear_options()
	modulate.a = 0.0
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, 0.25)
	_goto(dialogue_id)


func close() -> void:
	_open = false
	_state = State.IDLE
	_clear_options()
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.2)
	_fade.tween_callback(func(): visible = false)
	finished.emit()


# ---------------------------------------------------------------- 流程
func _goto(id: String) -> void:
	_clear_options()
	if id == "END" or id == "":
		close()
		return
	if not DB.NODES.has(id):
		push_error("对话节点不存在：%s" % id)
		close()
		return
	_node_id = id
	_node = DB.NODES[id]
	_queue.clear()
	for line in _node.get("lines", []):
		if GameState.conditions_met(line):
			_queue.append(line)
	_next_line()


func _next_line() -> void:
	while not _queue.is_empty():
		var line: Dictionary = _queue.pop_front()
		var bb := _format_line(line)
		if bb != "":
			_append(bb, true)
			return
	_node_done()


func _node_done() -> void:
	GameState.apply_effects(_node)
	if _node.has("goto"):
		_goto(_node["goto"])
	else:
		_show_options()


func _append(bb: String, typewriter: bool) -> void:
	if _log.get_total_character_count() > 0:
		_log.append_text("\n\n")
	var start := _log.get_total_character_count()
	_log.append_text(bb)
	var total := _log.get_total_character_count()
	if not typewriter:
		_log.visible_characters = -1
		return
	_log.visible_characters = start
	_state = State.TYPING
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_log, "visible_characters", total, maxf(0.2, (total - start) * 0.02))
	_tween.finished.connect(_on_typed)


func _on_typed() -> void:
	_log.visible_characters = -1
	_state = State.PAUSE
	_pause = 0.45


func _process(delta: float) -> void:
	if _state == State.PAUSE:
		_pause -= delta
		if _pause <= 0.0:
			_state = State.IDLE
			_next_line()


func _skip() -> void:
	if _state == State.TYPING:
		if _tween:
			_tween.kill()
		_on_typed()
		_pause = 0.08
	elif _state == State.PAUSE:
		_pause = 0.0


# ---------------------------------------------------------------- 台词格式
func _format_line(line: Dictionary) -> String:
	var text: String = line.get("text", "")
	if line.has("passive"):
		var p: Dictionary = line["passive"]
		var r := GameState.roll_check(p["skill"], p["dc"])
		if not r.success:
			return ""
		var sk: String = p["skill"]
		return "[b][color=#%s]%s[/color][/b] [color=#%s][%s：成功][/color] — [color=#%s]%s[/color]" % [
			GameState.skill_color(sk).to_html(false), GameState.skill_name(sk).to_upper(),
			COL_DIM.to_html(false), GameState.difficulty_name(p["dc"]), COL_TEXT.to_html(false), text]
	if line.has("skill"):
		var sk: String = line["skill"]
		return "[b][color=#%s]%s[/color][/b] — [color=#%s]%s[/color]" % [
			GameState.skill_color(sk).to_html(false), GameState.skill_name(sk), COL_TEXT.to_html(false), text]
	if line.has("speaker"):
		var spk: String = line["speaker"]
		var c := COL_YOU if spk == "你" else Color(line.get("color", COL_SPEAKER.to_html(false)))
		return "[b][color=#%s]%s[/color][/b] — [color=#%s]%s[/color]" % [
			c.to_html(false), spk, COL_TEXT.to_html(false), text]
	return "[i][color=#%s]%s[/color][/i]" % [COL_NARRATION.to_html(false), text]


# ---------------------------------------------------------------- 选项
func _show_options() -> void:
	_clear_options()
	_state = State.OPTIONS
	_visible_options.clear()
	var opts: Array = _node.get("options", [])
	for i in opts.size():
		var opt: Dictionary = opts[i]
		var key := "opt:%s#%d" % [_node_id, i]
		if not GameState.conditions_met(opt):
			continue
		if (opt.get("once", false) or opt.has("check")) and GameState.has_flag(key):
			continue
		_visible_options.append({"opt": opt, "key": key})
	if _visible_options.is_empty():
		_visible_options.append({"opt": {"text": "[离开]", "next": "END"}, "key": ""})
	for i in _visible_options.size():
		_options_box.add_child(_make_option(i, _visible_options[i]["opt"]))
	_hint.visible = true


func _make_option(i: int, opt: Dictionary) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	r.add_theme_font_size_override("normal_font_size", 19)
	r.add_theme_font_size_override("bold_font_size", 19)
	r.add_theme_color_override("default_color", COL_OPTION)
	var prefix := ""
	if opt.has("check"):
		var c: Dictionary = opt["check"]
		var sk: String = c["skill"]
		var chance := int(round(GameState.success_chance(sk, c["dc"]) * 100.0))
		var bracket_col := COL_RED_CHECK if c.get("red", false) else Color("e8e0d2")
		prefix = "[color=#%s][%s - %s %d][/color] " % [bracket_col.to_html(false), GameState.skill_name(sk), GameState.difficulty_name(c["dc"]), c["dc"]]
		r.text = "%d. %s%s  [color=#%s]%d%%[/color]" % [i + 1, prefix, opt["text"], COL_DIM.to_html(false), chance]
	else:
		r.text = "%d. %s" % [i + 1, opt["text"]]
	r.mouse_entered.connect(func(): r.add_theme_color_override("default_color", COL_OPTION_HOVER))
	r.mouse_exited.connect(func(): r.add_theme_color_override("default_color", COL_OPTION))
	r.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_choose(i)
			accept_event())
	return r


func _choose(i: int) -> void:
	if _state != State.OPTIONS or i < 0 or i >= _visible_options.size():
		return
	var entry: Dictionary = _visible_options[i]
	var opt: Dictionary = entry["opt"]
	if entry["key"] != "":
		GameState.set_flag(entry["key"])
	_clear_options()
	_state = State.IDLE
	var clean_text: String = opt["text"]
	_append("[b][color=#%s]你[/color][/b] — [color=#%s]%s[/color]" % [COL_YOU.to_html(false), COL_YOU.lightened(0.25).to_html(false), clean_text], false)
	var next: String = opt.get("next", "END")
	if opt.has("check"):
		var c: Dictionary = opt["check"]
		var sk: String = c["skill"]
		var r := GameState.roll_check(sk, c["dc"])
		var res_col := Color("8fcf7a") if r.success else Color("d9614c")
		_append("[color=#%s][%s %s：%s][/color]  [color=#%s]掷骰 %d + %d，技能 +%d = %d / %d[/color]" % [
			res_col.to_html(false), GameState.skill_name(sk), GameState.difficulty_name(c["dc"]),
			"成功" if r.success else "失败", COL_DIM.to_html(false),
			r.dice[0], r.dice[1], r.bonus, r.total, c["dc"]], false)
		next = opt.get("pass" if r.success else "fail", "END")
	_goto(next)


func _clear_options() -> void:
	for c in _options_box.get_children():
		c.queue_free()
	_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_skip()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			_choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip()


# ---------------------------------------------------------------- 布局
func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.042, 0.04, 0.94)
	sb.border_width_left = 2
	sb.border_color = Color(0.36, 0.29, 0.2)
	sb.content_margin_left = 34
	sb.content_margin_right = 30
	sb.content_margin_top = 30
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 24
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 14)
	_header.add_theme_color_override("font_color", COL_DIM)
	v.add_child(_header)
	v.add_child(_sep())

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	_log.selection_enabled = false
	_log.add_theme_font_size_override("normal_font_size", 20)
	_log.add_theme_font_size_override("bold_font_size", 20)
	_log.add_theme_font_size_override("italics_font_size", 20)
	_log.add_theme_constant_override("line_separation", 6)
	_log.add_theme_color_override("default_color", COL_TEXT)
	v.add_child(_log)

	v.add_child(_sep())
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 10)
	v.add_child(_options_box)

	_hint = Label.new()
	_hint.text = "按数字键或点击选择"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", COL_DIM)
	v.add_child(_hint)


func _sep() -> HSeparator:
	var s := HSeparator.new()
	var st := StyleBoxLine.new()
	st.color = Color(0.3, 0.26, 0.2, 0.7)
	st.thickness = 1
	s.add_theme_stylebox_override("separator", st)
	return s
