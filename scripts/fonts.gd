@tool
extends RefCounted
## 字体工具：使用随项目打包的思源宋体（Noto Serif SC，子集，OFL 许可），
## 这样在 Web 导出里也能显示中文；缺字时回退到系统字体。

const FONT_PATH := "res://fonts/NotoSerifSC-subset.ttf"
const SYSTEM_NAMES := ["Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "STSong", "SimSun", "Noto Sans CJK SC", "Microsoft YaHei", "PingFang SC", "WenQuanYi Zen Hei"]

static var _base: Font


static func base() -> Font:
	if _base == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(SYSTEM_NAMES)
		if ResourceLoader.exists(FONT_PATH):
			var f: FontFile = load(FONT_PATH)
			f.fallbacks = [sys]
			_base = f
		else:
			_base = sys
	return _base


## weight: 可变字重（200–900）；slant: 伪斜体
static func make(weight := 500, slant := 0.0) -> Font:
	var v := FontVariation.new()
	v.base_font = base()
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	v.variation_opentype = {tag: weight}
	if slant != 0.0:
		v.variation_transform = Transform2D(Vector2(1, 0), Vector2(slant, 1), Vector2.ZERO)
	return v
