## The art blend (MapLight) on Ocean Drive: Gale, a Stone Wall and four towers, photographed with blending off or
## on, so the two can be compared side by side. Visual only; it checks that each pass is in place when on.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/blend_test.tscn -- <out dir> <on|off>
extends Node

var out := "user://blend_test"
var on := true
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The board's picture, cropped around a board world point and blown up (smoothly: these are for people to look at).
func _crop(name: String, at: Vector2, half: Vector2, z: int) -> void:
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var img := bi.get_region(r)
	img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name + ".png"))


func _put(h: Hero, world: Vector2) -> void:
	h.x = world.x
	h.y = (world.y - Board.TOP) / Board.K
	h.tx = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	if args.size() > 1:
		on = args[1] != "off"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(200).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	Save.settings.blend = on
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane", "laser", "mortar", "frost"])
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
	var spot := Vector2(480, 300)
	var placed := 0
	for type in ["arcane", "laser", "mortar", "frost"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		if best.x >= 0:
			g.place_tower(best.x, best.y, type)
			placed += 1
			spot += Vector2(70, 10 if placed % 2 else -40)
	var h := S.hero
	_put(h, Vector2(560, 320))
	await _frames(40)
	_check(b.live == null, "the pixel style is off")
	_check(b.hero_3d != null and b.hero_3d.vp != null, "Gale has his own smooth render")
	var lit := false
	if b.hero_3d and b.hero_3d.vp:
		for n in b.hero_3d.vp.get_children():
			if n is DirectionalLight3D and n.light_color != Color.WHITE:
				lit = true
	_check(lit == on, "Gale is lit by the map's light: %s" % lit)
	_check((b.grade != null) == on, "the board grade is %s" % ("on" if b.grade else "off"))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("full.png"))
	await _crop("close", Vector2(600, 290), Vector2(200, 110), 4)
	await _crop("gale", Vector2(560, 300), Vector2(60, 45), 8)
	# a wave in progress, enemies on the road
	g.start_wave()
	await _frames(240)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("wave.png"))
	print("BLEND DONE fails=%d" % fails)
	get_tree().quit(fails)
