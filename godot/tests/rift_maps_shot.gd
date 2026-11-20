## Screenshots of the Rift Creep maps in play: the map list, then each map with towers by the road mid-wave.
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/rift_maps_shot.tscn -- <out dir> [map ids...]
extends Node

var out := "user://shots"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	var ids: Array = args.slice(1) if args.size() > 1 else ["verdant", "ironhold", "warped", "maelstrom"]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(400).timeout.connect(func(): print("SHOTS TIMEOUT"); get_tree().quit(1))
	seed(7)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	for id in DB.map_order:
		Save.meta.best[id] = { wave = 20, won = true }
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.show_map_select()
	await _shot("maps")
	for id in ids:
		main.ui.menus.new_run(id)
		main.ui.menus.start_run("vanguard", Array(DB.tower_order).slice(0, 5))
		var g := main.game
		var S := g.S
		if S.map.problem != "":
			print("MAP PROBLEM ", id, ": ", S.map.problem)
		S.gold = 5000
		var cells := g.build_cells()
		cells.shuffle()
		var placed := 0
		for c in cells:
			if placed < 10 and S.map.path_dist(g.cell_pos(c.x, c.y)) < 50 and g.build_problem(c.x, c.y, DB.tower_order[placed % 5]) == "":
				g.place_tower(c.x, c.y, DB.tower_order[placed % 5])
				placed += 1
		print(id, ": ", cells.size(), " build cells, placed ", placed, ", lanes ", S.map.lane_count(), ", merge at ", S.map.merge_d, " of ", S.map.path_len)
		g.modal.connect(func(kind, _d):
			if kind == "level_up":
				(func():
					main.ui.close_modal()
					g.pick_offer(0)).call_deferred())
		g.start_wave()
		for i in 240:
			await get_tree().process_frame
		await _shot(id)
		g.end_run(false, true)
	print("SHOTS DONE")
	get_tree().quit(0)


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
