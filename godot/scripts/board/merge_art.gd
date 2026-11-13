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
static var _miss := {} # key -> engine msec of the last failed scan (retried after RETRY_MS, never stuck)
static var _warned := {}
const RETRY_MS := 2000


static func clear_cache() -> void:
	_cache.clear()
	_miss.clear()
	_warned.clear()


static func folder(key: String) -> String:
	return ROOT.path_join(key.replace("+", "_"))


## {glb, cfg, scale, colors, reuse, body} or {} when the tower keeps the placeholder plinth. A merge whose folder
## has a model always draws it; colors are worked out live from the tower's current paths (colors_for).
static func resolve(t: Tower) -> Dictionary:
	if t == null or not t.hybrid:
		return {}
	var own_key := recipe_key(t)
	var own := _dir(own_key)
	if not own.is_empty():
		return {glb = own.glb, cfg = own.cfg, scale = 1.0, colors = colors_for(t, t.parent_colors), reuse = false, body = t.color}
	if t.is_super and t.type != "" and t.type != own_key:
		var first := _dir(t.type)
		if not first.is_empty():
			var cols = t.model_colors if t.model_colors.size() > 0 else t.parent_colors
			return {glb = first.glb, cfg = first.cfg, scale = SUPER_SCALE, colors = colors_for(t, cols), reuse = true, body = t.color}
	return {}


## The two mask triplets [trim, glow, detail] for a merge, from the paths it actually took. Its own picked fusions are
## ranked by points (t.ups), ties going to the one picked first (t.order): the top one lights the glow (G) on both
## masks, the 2nd the trim (R), the 3rd the detail (B), each in its tag's PathColors colour. A slot with no fusion
## yet keeps the parent's colour for that zone (mask A = the first parent in recipe-key order, B = the second; trim =
## its 1st path, glow = its 2nd, detail = its 3rd), padded with the tower's colour.
static func colors_for(t: Tower, parents: Array = []) -> Array:
	if parents.is_empty():
		parents = t.parent_colors
	var picked: Array = []
	for i in t.order.size():
		var id: String = t.order[i]
		if t.ups_of(id) > 0 and not picked.any(func(x): return x.id == id):
			picked.append({ id = id, n = t.ups_of(id), i = i })
	picked.sort_custom(func(a, b): return a.n > b.n or (a.n == b.n and a.i < b.i))
	var cmap := PathColors._color_map(t, picked.map(func(x): return x.id)) if picked.size() else {}
	var top: Array = picked.map(func(x): return cmap.get(x.id, t.color))
	var out := []
	for k in 2:
		var base: Array = parents[k] if parents.size() > k and parents[k] is Array else []
		var pc := func(j: int) -> Color: return base[j] if base.size() > j and base[j] is Color else t.color
		var glow: Color = top[0] if top.size() > 0 else pc.call(1)
		var trim: Color = top[1] if top.size() > 1 else pc.call(0)
		var detail: Color = top[2] if top.size() > 2 else pc.call(2)
		out.append([trim, glow, detail])
	return out


static func recipe_key(t: Tower) -> String:
	if t.is_super:
		var p := Array(t.parents)
		p.sort()
		return "+".join(p)
	return t.type


## A hybrid's folder is its recipe key (already sorted); a super's is its base types sorted.
static func _dir(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	if _miss.has(key) and Time.get_ticks_msec() - int(_miss[key]) < RETRY_MS:
		return {}
	var found := _scan(key)
	if found.is_empty():
		_miss[key] = Time.get_ticks_msec()
	else:
		_cache[key] = found
		_miss.erase(key)
	return found


static func _scan(key: String) -> Dictionary:
	var dir := folder(key)
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.open(dir) == null:
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
		if ResourceLoader.exists(named) or FileAccess.file_exists(named):
			glb = named
	if glb == "":
		glb = _first_glb(dir)
	if glb == "":
		if not _warned.has(key):
			_warned[key] = true
			push_warning("MergeArt: %s has a folder but no model, using placeholder" % key)
		return {}
	return {glb = glb, cfg = cfg}


## The first *.glb in the folder by name. In an exported game the folder lists x.glb.import (or .remap), not x.glb.
static func _first_glb(dir: String) -> String:
	var files: Array = []
	if ResourceLoader.has_method("list_directory"):
		files = Array(ResourceLoader.call("list_directory", dir))
	if files.is_empty():
		var d := DirAccess.open(dir)
		if d == null:
			return ""
		files = Array(d.get_files())
	var names: Array[String] = []
	for f in files:
		var n := String(f).trim_suffix(".remap").trim_suffix(".import")
		if n.get_extension().to_lower() == "glb" and not names.has(n):
			names.append(n)
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


## An imported texture first (all an exported game has), else the raw file from disk.
static func load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if not FileAccess.file_exists(path):
		return null
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
