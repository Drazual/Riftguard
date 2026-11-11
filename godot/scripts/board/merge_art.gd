## Live 3D models for hybrid and super towers. Conventions: docs/merge-art.md.
##
## Folder: res://art_src/towers/merges/<recipe key, '+' changed to '_'>/ (arcane+tesla -> arcane_tesla).
## The model is tower.json's "model", or the first *.glb in that folder by name.
## Masks sit next to the GLB: <file>_accent_mask.png is parent A (R trim, G glow, B detail) and
## <file>_accent_mask_b.png is parent B. Metadata accent_mask / accent_mask_b on any node overrides the file.
class_name MergeArt
extends RefCounted

const ROOT := "res://art_src/towers/merges"
## How far a merge body's albedo moves toward the recipe colour. 0 leaves the texture alone.
const BODY := 0.72
const SUPER_SCALE := 1.15

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func folder(key: String) -> String:
	return ROOT.path_join(key.replace("+", "_"))


## {glb, cfg, scale, colors, reuse, body} or {} when the tower keeps the placeholder plinth.
static func resolve(t: Tower) -> Dictionary:
	if t == null or not t.hybrid:
		return {}
	var own_key := recipe_key(t)
	var own := _dir(own_key)
	if not own.is_empty():
		return {glb = own.glb, cfg = own.cfg, scale = 1.0, colors = t.parent_colors, reuse = false, body = t.color}
	if t.is_super and t.type != "" and t.type != own_key:
		var first := _dir(t.type)
		if not first.is_empty():
			var cols = t.model_colors if t.model_colors.size() > 0 else t.parent_colors
			return {glb = first.glb, cfg = first.cfg, scale = SUPER_SCALE, colors = cols, reuse = true, body = t.color}
	return {}


## A super's own folder is its base types sorted. A hybrid's folder is its recipe key (already sorted).
static func recipe_key(t: Tower) -> String:
	if t.is_super:
		var p := Array(t.parents)
		p.sort()
		return "+".join(p)
	return t.type


static func _dir(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var found := _scan(key)
	_cache[key] = found
	return found


static func _scan(key: String) -> Dictionary:
	var dir := folder(key)
	if DirAccess.open(dir) == null:
		return {}
	var cfg := {}
	var json_path := dir.path_join("tower.json")
	if FileAccess.file_exists(json_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			cfg = parsed
	var glb := ""
	if cfg.has("model"):
		var named: String = dir.path_join(String(cfg.model))
		if FileAccess.file_exists(named):
			glb = named
	if glb == "":
		glb = _first_glb(dir)
	if glb == "":
		return {}
	return {glb = glb, cfg = cfg}


static func _first_glb(dir: String) -> String:
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	var names: Array[String] = []
	for f in d.get_files():
		if f.get_extension().to_lower() == "glb":
			names.append(f)
	names.sort()
	if names.is_empty():
		return ""
	return dir.path_join(names[0])


static func instantiate(glb: String) -> Node3D:
	if glb == "":
		return null
	if ResourceLoader.exists(glb):
		var packed := load(glb) as PackedScene
		if packed:
			return packed.instantiate() as Node3D
	var paths := [glb]
	if glb.begins_with("res://"):
		paths.append(ProjectSettings.globalize_path(glb))
	for p in paths:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(p, state) == OK:
			return doc.generate_scene(state) as Node3D
	return null


## suffix is "_accent_mask.png" or "_accent_mask_b.png", glued to the GLB's file name.
static func load_mask(glb: String, suffix: String, root: Node, meta_key: String) -> Texture2D:
	var from_meta := _meta_tex(root, meta_key)
	if from_meta:
		return from_meta
	if glb == "":
		return null
	return load_tex(glb.get_basename() + suffix)


static func load_tex(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var img := Image.new()
	if img.load(path) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _meta_tex(root: Node, key: String) -> Texture2D:
	if root == null:
		return null
	if root.has_meta(key) and root.get_meta(key) is Texture2D:
		return root.get_meta(key)
	for n in root.find_children("*", "", true, false):
		if n.has_meta(key) and n.get_meta(key) is Texture2D:
			return n.get_meta(key)
	return null
