## The pixel art test (Settings > "Pixel art test", StyleSettings.pixel_grid_on): one map, one look, photographed.
## "old" is the game as it ships (heroes in their own smooth viewport, baked tower sprites, the map at its own
## resolution); "pixel" is the one-768-grid look. Checks the pixel look's rules and saves the screen, plus close-ups
## cut from the real screen pixels.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path godot --rendering-driver opengl3 --resolution 1920x1080 \
##     res://tests/pixel_grid.tscn -- <out dir> <map id: canal | coral> <old | pixel>
extends Node

var out := "user://pixel_grid"
var map_id := "coral"
var mode := "pixel"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A board world point -> real screen pixels.
func _screen(at: Vector2) -> Vector2:
	var b := main.board
	var v: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var per := float(get_tree().root.size.x) / get_viewport().get_visible_rect().size.x
	return (b.get_global_rect().position + b.fit_offset() + v * b.fit_scale()) * per


func _shots(tag: String, close: Array) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("%s_%s_%s_full.png" % [map_id, mode, tag]))
	for c in close:
		var at: Vector2 = _screen(c[1])
		var half: Vector2 = c[2]
		var r := Rect2i(Vector2i(at - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop := img.get_region(r)
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(out.path_join("%s_%s_%s_%s.png" % [map_id, mode, tag, c[0]]))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		map_id = args[1]
	if args.size() > 2:
		mode = args[2]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(240).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	Save.settings.pixel_grid = mode == "pixel"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run(map_id)
	main.ui.menus.start_run("gale", ["arcane", "frost", "laser", "mortar"])
	await _frames(10)
	var g := main.game
	var S := g.S
	var b := main.board
	S.gold = 99999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	# towers on open ground near the hero's spot
	var spot := Vector2(480, 290) if map_id == "canal" else Vector2(300, 330)
	var placed := []
	for type in ["arcane", "frost", "laser", "mortar"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		if best.x >= 0:
			g.place_tower(best.x, best.y, type)
			placed.append(type)
			spot += Vector2(60, 0)
	await _frames(5)
	var h := S.hero
	var hp := Vector2(S.towers[0].x + 55, Board.SY(S.towers[0].y) + 30)
	h.x = hp.x
	h.y = (hp.y - Board.TOP) / Board.K
	h.tx = null
	await _frames(40)
	var per := float(get_tree().root.size.x) / get_viewport().get_visible_rect().size.x
	var px := b.fit_scale() * per
	print("window %s  board %s  render %s  screen px per board px %.3f  zoom %.2f" % [get_tree().root.size, b.viewport.size, b.live.vp.size if b.live else "-", px, b.zoom])
	if mode == "pixel":
		_check(b.pixel and b.live != null and b.live.settings.pixel_grid, "the pixel grid is on, with the shared 3D layer")
		_check(b.viewport.size == Vector2i(768, 416), "the board is the 768x416 grid (%s)" % b.viewport.size)
		var ss: int = b.live.settings.supersample
		_check(b.live.vp.size == Vector2i(768, 416) * ss, "the 3D layer renders %dx the same grid (%s) and averages down to it" % [ss, b.live.vp.size])
		_check(is_equal_approx(px, roundf(px)) and px >= 1.0, "the board is shown at a whole multiple (%.3f)" % px)
		_check(b.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "and never smoothed")
		_check(b.hero_3d != null and b.hero_3d.anchor != null and is_equal_approx(b.hero_3d.anchor.scale.x, 1.35), "Gale is drawn 1.35x his size")
		var flat := 0
		for m in b.live.rig.toons_of(b.hero_3d.model):
			var t = m.get_shader_parameter("albedo_tex")
			if t is Texture2D and t.resource_path.ends_with("_flat.png"):
				flat += 1
		_check(flat > 0, "Gale wears his flat-colour textures (%d materials)" % flat)
		var lives := 0
		for t: Tower in S.towers:
			if t.has_meta("view") and t.get_meta("view") is Live3D.LiveTower:
				lives += 1
		_check(lives == placed.size(), "every tower is a live model (%d of %d)" % [lives, placed.size()])
		_check(bool((b.live.pic.material as ShaderMaterial).get_shader_parameter("quantize")), "the 3D layer is snapped to the shared palette")
	var close := [["gale", hp + Vector2(0, -20), Vector2(70, 55)]]
	for t: Tower in S.towers:
		close.append([t.type, Vector2(t.x, Board.SY(t.y)) + Vector2(0, -22), Vector2(50, 45)])
	close.append(["towers", Vector2(S.towers[0].x + 90, Board.SY(S.towers[0].y) - 20), Vector2(160, 70)])
	await _shots("build", close)
	# a wave, for shots and enemies on the grid
	g.start_wave()
	for i in 260:
		await get_tree().process_frame
	await _shots("wave", [["wave", hp + Vector2(0, -10), Vector2(200, 110)]])
	if mode == "pixel":
		# zoom snaps to whole multiples only
		b.zoom_by(1.15, b.size / 2)
		await _frames(3)
		_check(is_equal_approx(b.zoom, 2.0), "zooming in goes straight to 2x (%.2f)" % b.zoom)
		var o := b.viewport.canvas_transform.origin
		_check(is_equal_approx(o.x, roundf(o.x)) and is_equal_approx(o.y, roundf(o.y)), "the zoomed view sits on whole pixels")
		await _shots("zoom2x", [])
		b.zoom_by(1 / 1.15, b.size / 2)
		await _frames(2)
		_check(is_equal_approx(b.zoom, 1.0), "zooming out goes back to 1x")
		# switching it off brings the shipped look back
		Save.settings.pixel_grid = false
		b.restyle()
		await _frames(10)
		_check(b.live == null and not b.pixel, "switched off: the shipped look is back")
	print("PIXEL GRID DONE, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
