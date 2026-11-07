## "Before" screenshots for the style test: the game as it draws today (Ocean Drive, Gale live 3D in its own little
## viewport, the Arcane Bolt as baked turret sprites), around the same kind of spot as scenes/style_test.tscn.
## xvfb-run -s "-screen 0 1600x900x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/style_before.tscn -- <out dir>
extends Node

var out := "user://style_before"


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane"])
	await _frames(10)
	var g := main.game
	var S := g.S
	S.gold = 99999
	# Gale beside an Ocean Drive building (bld_techshop_91, ground line at art y 744), just in front of it
	var spot := StyleWorld.art_to_field(Vector2(860, 380)) # open ground inside the road loop
	S.hero.x = spot.x
	S.hero.y = spot.y
	S.hero.tx = null
	# an Arcane Bolt on the nearest open ground to the right
	var want := StyleWorld.art_to_field(Vector2(990, 360))
	var best := Vector2i(-1, -1)
	for c in g.build_cells():
		if g.build_problem(c.x, c.y, "arcane") == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(want) < g.cell_pos(best.x, best.y).distance_to(want)):
			best = c
	if best.x >= 0:
		g.place_tower(best.x, best.y, "arcane")
	await _frames(40)
	S.hero.x = spot.x
	S.hero.y = spot.y
	await _frames(20)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join("before_full.png"))
	# the board's picture alone, cropped around the spot and blown up 3x
	var bi := main.board.viewport.get_texture().get_image()
	print("board ", bi.get_size(), " tower cell ", best, " at ", g.cell_pos(best.x, best.y))
	# crops around Gale and the tower where the board actually draws them (its camera can pan and zoom)
	var hp: Vector2 = main.board.hero_3d.get_global_transform_with_canvas().origin
	var vs := Vector2(bi.get_size()) / Vector2(main.board.viewport.size)
	var cut := func(name: String, centre: Vector2, half: Vector2, z: int):
		var r := Rect2i(Vector2i((centre - half) * vs), Vector2i(half * 2 * vs))
		var c := bi.get_region(r.intersection(Rect2i(Vector2i.ZERO, bi.get_size())))
		c.resize(c.get_width() * z, c.get_height() * z, Image.INTERPOLATE_NEAREST)
		c.save_png(out.path_join(name + ".png"))
	print("hero on board ", hp, " board vp ", main.board.viewport.size)
	cut.call("before_zoom", hp + Vector2(40, -20), Vector2(230, 140), 3)
	cut.call("before_gale", hp + Vector2(0, -20), Vector2(60, 45), 6)
	var tp := Vector2.ZERO
	for n in main.board.units.get_children():
		if n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames == DB.towers.arcane.turret:
			tp = n.get_global_transform_with_canvas().origin
	cut.call("before_tower", tp + Vector2(0, -30), Vector2(60, 55), 6)
	print("BEFORE DONE")
	get_tree().quit(0)
