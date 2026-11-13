## Screenshots of map 2 (Neon Spiral): the map list with it unlocked, a run with towers, and a wave.
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/map2_shot.tscn -- <out dir>
extends Node

var out := "user://shots"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(200).timeout.connect(func(): print("SHOTS TIMEOUT"); get_tree().quit(1))
	seed(7)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.meta.best.erase("coral")
	Save.meta.best["canal"] = { wave = 20, won = true }
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _shot("m2_00_menu")
	main.ui.menus.show_map_select()
	await _shot("m2_01_maps")
	main.ui.menus.new_run("coral")
	main.ui.menus.start_run("striker", Array(DB.tower_order).slice(0, 5))
	await _shot("m2_02_run")
	var g := main.game
	var S := g.S
	S.gold = 5000
	var cells := g.build_cells()
	var dist := {}
	for c in cells:
		dist[c] = S.map.path_dist(g.cell_pos(c.x, c.y))
	cells.shuffle()
	var placed := 0
	for c in cells:
		if placed < 9 and dist[c] < 60 and g.build_problem(c.x, c.y, DB.tower_order[placed % 5]) == "":
			var p := g.cell_pos(c.x, c.y)
			if p.x > 250 and p.x < 720:
				g.place_tower(c.x, c.y, DB.tower_order[placed % 5])
				placed += 1
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	g.start_wave()
	for i in 260:
		await get_tree().process_frame
	await _shot("m2_03_wave")
	for i in 200:
		await get_tree().process_frame
	await _shot("m2_04_wave")
	print("SHOTS DONE")
	get_tree().quit(0)


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
