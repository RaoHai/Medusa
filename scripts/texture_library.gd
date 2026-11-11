@tool
extends RefCounted
## 可选贴图：缺少文件时继续使用原来的程序化材质。

static var _cache: Dictionary = {}


static func get_texture(asset: String) -> Texture2D:
	if not _cache.has(asset):
		var path := "res://textures/%s.png" % asset
		if not ResourceLoader.exists(path):
			return null
		_cache[asset] = load(path)
	return _cache[asset] as Texture2D


static func bind_texture(material: ShaderMaterial, parameter: String, asset: String) -> void:
	var tex := get_texture(asset)
	material.set_shader_parameter(parameter, tex)
	material.set_shader_parameter("use_" + parameter, tex != null)
