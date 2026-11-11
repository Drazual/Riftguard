## Path colours, accent masks and merge GLBs.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/path_colors.tscn -- <out dir>
extends Node

var out := "/tmp/path_colors"
var fails := 0
var main: Main
var _temps: Array[String] = []


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


## Shader parameters come back as null until something sets them. Null means the shader default.
func _flag(v) -> bool:
	return v == true


func _num(v) -> float:
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return 0.0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(240).timeout.connect(func():
		print("TIMEOUT")
		_cleanup()
		get_tree().quit(1))
	_colors()
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(8)
	_check(main.game != null and main.board != null and main.game.S == null, "the game boots to the menu")
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["frost", "laser", "arcane", "tesla"])
	await _frames(8)
	var g: Game = main.game
	var S: Run = g.S
	var b: Board = main.board
	_check(S != null and S.hero != null and b.live != null, "a run starts with the live 3D layer on")
	S.gold = 99999999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	_logic(g)
	var placed := {}
	var spot := Vector2(480, 300)
	for type in ["frost", "laser", "arcane", "tesla"]:
		placed[type] = _place(g, type, spot)
		spot += Vector2(70, 16)
	await _frames(6)
	var frost: Tower = placed.frost
	var laser: Tower = placed.laser
	_check(frost != null and laser != null and placed.arcane != null and placed.tesla != null, "four towers placed")
	var fv = _view(frost)
	_check(fv is Live3D.LiveTower, "frost is a live base tower, not a merge")
	if fv is Live3D.LiveTower:
		var fl: Live3D.LiveTower = fv
		_check(fl.idle == "shimmer" and fl.ap != null and fl.ap.is_playing(), "frost still plays its own idle (%s)" % fl.idle)
		_check(fl.yaw_node != null and fl.muzzle != null, "frost keeps yaw and muzzle")
		var mat := _toon(fl)
		_check(mat != null and not _flag(mat.get_shader_parameter("use_accent")) and _num(mat.get_shader_parameter("body_tint_strength")) == 0.0,
			"a base tower with no mask is un-tinted")
	_mask("res://art_src/towers/laser/prism_laser_accent_mask.png", Color(1, 0, 0, 1))
	# the mask is read when the live view is built, so rebuild the laser
	if laser.has_meta("view"):
		var old = laser.get_meta("view")
		if is_instance_valid(old):
			old.queue_free()
		laser.remove_meta("view")
	await _frames(4)
	var lv = _view(laser)
	_check(lv is Live3D.LiveTower, "laser reloads live with a mask beside its GLB")
	if lv is Live3D.LiveTower:
		var ll: Live3D.LiveTower = lv
		var mat0 := _toon(ll)
		_check(mat0 != null and _flag(mat0.get_shader_parameter("use_accent")), "the mask turns accent zones on")
		_check((mat0.get_shader_parameter("accent1") as Color).is_equal_approx(laser.color), "before a path, zone 1 is the tower colour")
		_buy(g, laser, "focusl")
		await _frames(3)
		var mat1 := _toon(ll)
		var c1: Color = mat1.get_shader_parameter("accent1")
		_check(c1.is_equal_approx(PathColors.of_tag("precision")), "buying Focusing Lens paints zone 1 precision (%s)" % c1)
		S.sel = laser
		main.ui._panel_show("tower")
		var chip := _swatch("focusl")
		_check(chip != null and chip.color.is_equal_approx(c1), "the path button shows that swatch")
		if chip:
			var tip := _choice(chip)
			_check(tip != null and tip.tooltip_text.contains(c1.to_html(false)), "the path tooltip names the colour (%s)" % (tip.tooltip_text if tip else ""))
		_buy(g, laser, "lensr")
		await _frames(3)
		var mat2 := _toon(ll)
		var c2: Color = mat2.get_shader_parameter("accent1")
		var c3: Color = mat2.get_shader_parameter("accent2")
		_check(not c2.is_equal_approx(c1) and c2.get_luminance() < c3.get_luminance(), "a second precision path shades the two zones apart")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("path_swatches.png"))
	_write_merge()
	MergeArt.clear_cache()
	_check(MergeArt.resolve(_dummy_hybrid()).is_empty() == false, "the test GLB resolves for arcane+tesla")
	var reuse := MergeArt.resolve(_dummy_super())
	_check(reuse.get("reuse", false) == true and is_equal_approx(_num(reuse.get("scale", 0)), MergeArt.SUPER_SCALE),
		"a super with no GLB of its own reuses the first hybrid at 1.15")
	_max(g, placed.arcane)
	_max(g, placed.tesla)
	var ca := PathColors.for_tower(placed.arcane)
	var ct := PathColors.for_tower(placed.tesla)
	_check(placed.arcane.lvl == g.R.max_level and placed.tesla.lvl == g.R.max_level, "both towers reach level %d" % g.R.max_level)
	g.try_merge(placed.arcane, placed.tesla)
	await _frames(6)
	var hybrid: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "arcane+tesla":
			hybrid = t
	_check(hybrid != null, "arcane and tesla merge into a railgun")
	if hybrid:
		_check(hybrid.parent_colors.size() == 2, "the hybrid stores both parents' path colours")
		if hybrid.parent_colors.size() == 2:
			_check((hybrid.parent_colors[0][0] as Color).is_equal_approx(ca[0]), "mask A is arcane (sorted key), not merge order")
			_check((hybrid.parent_colors[1][0] as Color).is_equal_approx(ct[0]), "mask B is tesla")
		var hv = _view(hybrid)
		_check(hv is Live3D.LiveTower, "the hybrid draws the test GLB instead of the plinth")
		if hv is Live3D.LiveTower:
			var ht: Live3D.LiveTower = hv
			_check(ht.model != null and ht.model.find_child("Turret", true, false) != null, "Turret node")
			_check(ht.model.find_child("Gun", true, false) != null and ht.model.find_child("Barrel", true, false) != null, "Gun and Barrel")
			_check(ht.muzzle != null and ht.muzzle.name == "Muzzle", "shots can leave Muzzle")
			_check(ht.model.find_child("MuzzleGlow", true, false) != null and ht.model.find_child("BuffPoint", true, false) != null, "MuzzleGlow and BuffPoint")
			var y0 := ht.yaw
			ht.aim(Vector2(90, 20))
			await _frames(10)
			_check(absf(ht.yaw - y0) > 0.05, "the merge turret aims like a base tower")
			var hm := _toon(ht)
			_check(hm != null and _flag(hm.get_shader_parameter("use_accent")) and _flag(hm.get_shader_parameter("use_accent_b")), "both parent masks are bound")
			_check((hm.get_shader_parameter("accent1") as Color).is_equal_approx(ca[0]), "zone 1 is arcane's first path colour")
			_check((hm.get_shader_parameter("accent2b") as Color).is_equal_approx(ct[1]), "parent B's glow zone is tesla's second path colour")
			_check(is_equal_approx(_num(hm.get_shader_parameter("body_tint_strength")), MergeArt.BODY), "the body tint strength is the recipe mix")
			_check((hm.get_shader_parameter("body_tint") as Color).is_equal_approx(hybrid.color), "the body tint is the recipe colour")
			await _crop("hybrid_model", Vector2(hybrid.x, Board.SY(hybrid.y)), Vector2(90, 110))
	# the style switch still drops live models back to sprites and the plinth, then brings them back
	Save.settings.style3d_test = false
	b.restyle()
	await _frames(4)
	_check(_view(frost) is AnimatedSprite2D, "style off: frost is its baked sprite again")
	_check(hybrid == null or not _view(hybrid) is Live3D.LiveTower, "style off: the hybrid falls back to the plinth")
	Save.settings.style3d_test = true
	b.restyle()
	await _frames(5)
	var back = _view(frost)
	_check(back is Live3D.LiveTower and (back as Live3D.LiveTower).idle == "shimmer", "style on: frost is live again, still unmasked")
	if back is Live3D.LiveTower:
		var bm := _toon(back)
		_check(bm != null and not _flag(bm.get_shader_parameter("use_accent")), "frost still has no accent after the toggle")
	_check(hybrid != null and _view(hybrid) is Live3D.LiveTower, "style on: the hybrid GLB is back")
	_cleanup()
	print("PATH COLORS DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)


func _colors() -> void:
	var pc := PathColors.data()
	var want := {
		power = "#FF4A4A", speed = "#FFD84A", burst = "#FF8A2E", burn = "#FF5A1F", slow = "#6EC8FF",
		chain = "#3CF0FF", precision = "#E6D8FF", arcane = "#FF4FC0", multi = "#6CF07A",
	}
	for tag in want:
		_check((pc.of(tag) as Color).is_equal_approx(Color(want[tag])), "%s is %s" % [tag, want[tag]])
	var sing: Color = DB.recipes["arcane+frost+plasma+tesla"].color
	_check(sing.is_equal_approx(Color("#B07CFF")), "Rift Singularity is void violet (%s)" % sing.to_html(false))


func _logic(g: Game) -> void:
	var t := g.new_tower("laser", 0, 0)
	var pad := PathColors.for_tower(t)
	_check(pad.size() == 3 and pad[0].is_equal_approx(t.color) and pad[2].is_equal_approx(t.color), "no paths: three copies of the tower colour")
	t.order = ["focusl"]
	_check(PathColors.for_tower(t)[0].is_equal_approx(PathColors.of_tag("precision")), "one precision path is the tag colour")
	_check(PathColors.for_tower(t)[1].is_equal_approx(t.color), "the empty zones stay the tower colour")
	t.order = ["lensr", "focusl"]
	var cols := PathColors.for_tower(t)
	_check(cols[0].get_luminance() > cols[1].get_luminance() and not cols[1].is_equal_approx(PathColors.of_tag("precision")),
		"shared precision shades by path index, investment order kept")
	var p: TowerPath = null
	for q in g.tower_paths("laser"):
		if q.id == "focusl":
			p = q
	var old := p.color
	p.color = Color(0.15, 0.25, 0.35, 1)
	var one := g.new_tower("laser", 0, 0)
	one.order = ["focusl"]
	_check(PathColors.for_tower(one)[0].is_equal_approx(p.color), "a path color override replaces the tag")
	p.color = old


func _place(g: Game, type: String, spot: Vector2) -> Tower:
	var best := Vector2i(-1, -1)
	for c in g.build_cells():
		if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
			best = c
	if best.x < 0:
		return null
	g.place_tower(best.x, best.y, type)
	return g.S.towers[g.S.towers.size() - 1]


func _buy(g: Game, t: Tower, id: String) -> void:
	for o in g.tower_options(t):
		if o.id == id:
			g.level_tower(t, o)
			return


func _max(g: Game, t: Tower) -> void:
	var guard := 0
	while t.lvl < g.R.max_level and guard < 20:
		var picked = null
		for o in g.tower_options(t):
			if g.path_state(t, o) == "open":
				picked = o
				break
		if picked == null:
			break
		var before := t.lvl
		g.level_tower(t, picked)
		if t.lvl == before:
			break
		guard += 1


func _view(t: Tower):
	if t == null or not t.has_meta("view"):
		return null
	var v = t.get_meta("view")
	return v if is_instance_valid(v) else null


func _toon(lt: Live3D.LiveTower) -> ShaderMaterial:
	if lt == null or lt.model == null or lt.live == null:
		return null
	var mats := lt.live.rig.toons_of(lt.model)
	return mats[0] if mats.size() else null


func _swatch(id: String) -> ColorRect:
	for n in main.ui.inspector.find_children("*", "ColorRect", true, false):
		if n.has_meta("path_swatch") and str(n.get_meta("path_swatch")) == id:
			return n
	return null


func _choice(n: Node) -> Choice:
	var at := n
	while at:
		if at is Choice:
			return at
		at = at.get_parent()
	return null


func _dummy_hybrid() -> Tower:
	var t := Tower.new()
	t.hybrid = true
	t.type = "arcane+tesla"
	t.parents = PackedStringArray(["arcane", "tesla"])
	t.color = Color("#8AFFFF")
	t.parent_colors = [PackedColorArray([Color.RED, Color.GREEN, Color.BLUE]), PackedColorArray([Color.WHITE, Color.BLACK, Color.CYAN])]
	return t


func _dummy_super() -> Tower:
	var t := Tower.new()
	t.hybrid = true
	t.is_super = true
	t.type = "arcane+tesla"
	t.parents = PackedStringArray(["arcane", "frost", "plasma", "tesla"])
	t.color = Color("#B07CFF")
	t.model_colors = [PackedColorArray([Color.RED, Color.RED, Color.RED])]
	t.parent_colors = [PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE]), PackedColorArray([Color.BLACK, Color.BLACK, Color.BLACK])]
	return t


func _mask(path: String, col: Color) -> void:
	_temps.append(path)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(col)
	img.save_png(ProjectSettings.globalize_path(path))


func _write_merge() -> void:
	var dir := "res://art_src/towers/merges/arcane_tesla"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var glb := dir.path_join("railgun.glb")
	# the real Railgun delivery lives here now: test against it, never write over it (or delete it after)
	if FileAccess.file_exists(glb):
		return
	_temps.append(glb)
	_temps.append(dir.path_join("railgun_accent_mask.png"))
	_temps.append(dir.path_join("railgun_accent_mask_b.png"))
	var f := FileAccess.open(glb, FileAccess.WRITE)
	f.store_buffer(_glb_bytes())
	f.close()
	_mask(dir.path_join("railgun_accent_mask.png"), Color(1, 0, 0, 1))
	_mask(dir.path_join("railgun_accent_mask_b.png"), Color(0, 1, 0, 1))


func _glb_bytes() -> PackedByteArray:
	var pos := _f32s([0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.2, 0.8, 0.15])
	var uv := _f32s([0.5, 0.5, 0.5, 0.5, 0.5, 0.5])
	var idx := PackedByteArray()
	idx.resize(6)
	idx.encode_u16(0, 0)
	idx.encode_u16(2, 1)
	idx.encode_u16(4, 2)
	var blob := PackedByteArray()
	blob.append_array(pos)
	blob.append_array(uv)
	blob.append_array(idx)
	while blob.size() % 4 != 0:
		blob.append(0)
	var gltf := {
		"asset": {"version": "2.0"},
		"scene": 0,
		"scenes": [{"nodes": [0]}],
		"nodes": [
			{"name": "MergeRoot", "children": [1]},
			{"name": "Turret", "children": [2, 3], "mesh": 0},
			{"name": "Gun", "children": [4]},
			{"name": "BuffPoint"},
			{"name": "Barrel", "children": [5, 6]},
			{"name": "Muzzle"},
			{"name": "MuzzleGlow"},
		],
		"meshes": [{"primitives": [{"attributes": {"POSITION": 0, "TEXCOORD_0": 1}, "indices": 2, "material": 0}]}],
		"materials": [{"pbrMetallicRoughness": {"baseColorFactor": [0.75, 0.75, 0.78, 1], "metallicFactor": 0, "roughnessFactor": 1}}],
		"accessors": [
			{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 0.8, 0.15]},
			{"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC2"},
			{"bufferView": 2, "componentType": 5123, "count": 3, "type": "SCALAR"},
		],
		"bufferViews": [
			{"buffer": 0, "byteOffset": 0, "byteLength": pos.size(), "target": 34962},
			{"buffer": 0, "byteOffset": pos.size(), "byteLength": uv.size(), "target": 34962},
			{"buffer": 0, "byteOffset": pos.size() + uv.size(), "byteLength": 6, "target": 34963},
		],
		"buffers": [{"byteLength": blob.size()}],
	}
	var js := JSON.stringify(gltf).to_utf8_buffer()
	while js.size() % 4 != 0:
		js.append(32)
	var total := 12 + 8 + js.size() + 8 + blob.size()
	var out := PackedByteArray()
	out.append_array("glTF".to_utf8_buffer())
	out.append_array(_u32(2))
	out.append_array(_u32(total))
	out.append_array(_u32(js.size()))
	out.append_array("JSON".to_utf8_buffer())
	out.append_array(js)
	out.append_array(_u32(blob.size()))
	out.append_array(PackedByteArray([0x42, 0x49, 0x4E, 0x00]))
	out.append_array(blob)
	return out


func _f32s(vals: Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(vals.size() * 4)
	for i in vals.size():
		b.encode_float(i * 4, float(vals[i]))
	return b


func _u32(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, n)
	return b


func _crop(name: String, at: Vector2, half: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	if r.size.x < 2 or r.size.y < 2:
		return
	var img := bi.get_region(r)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))


func _cleanup() -> void:
	for p in _temps:
		var abs := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(abs):
			DirAccess.remove_absolute(abs)
		var imp := abs + ".import"
		if FileAccess.file_exists(imp):
			DirAccess.remove_absolute(imp)
	var folder := ProjectSettings.globalize_path("res://art_src/towers/merges/arcane_tesla")
	if DirAccess.dir_exists_absolute(folder):
		DirAccess.remove_absolute(folder)
	var merges := ProjectSettings.globalize_path("res://art_src/towers/merges")
	if DirAccess.dir_exists_absolute(merges):
		var d := DirAccess.open(merges)
		if d and d.get_files().is_empty() and d.get_directories().is_empty():
			DirAccess.remove_absolute(merges)
