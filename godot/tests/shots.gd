## Takes screenshots of the menus and a run, to check the look. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/shots.tscn -- <out dir>
extends Node

var out := "user://shots"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("SHOTS TIMEOUT"); get_tree().quit(1))
	seed(7)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _shot("01_menu")
	main.ui.menus.show_map_select()
	await _shot("02_maps")
	main.ui.menus.new_run("canal")
	await _shot("03_heroes")
	main.ui.menus.start_run("vanguard", Array(DB.tower_order).slice(0, 5))
	await _shot("04_run")
	var g := main.game
	var S := g.S
	S.gold = 2000
	var placed := 0
	for c in range(2, 18):
		for r in range(2, 11):
			if placed < 6 and g.build_problem(c, r, DB.tower_order[placed % 5]) == "":
				g.place_tower(c, r, DB.tower_order[placed % 5])
				placed += 1
	var auto := [true]
	g.modal.connect(func(kind, _d):
		if auto[0] and kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	g.start_wave()
	for i in 200:
		await get_tree().process_frame
	await _shot("05_wave")
	S.hero.x = S.map.pos_at(S.map.path_len * 0.3).x
	S.hero.y = S.map.pos_at(S.map.path_len * 0.3).y
	g.use_ability()
	for i in 20:
		await get_tree().process_frame
	await _shot("05b_wave")
	auto[0] = false
	if S.towers.size():
		S.sel = S.towers[0]
		main.ui.render_inspector()
	await _shot("06_inspect")
	var sel_size := main.board.size
	for tw in S.towers:
		S.sel = tw
		main.ui.render_inspector()
		for i in 3:
			await get_tree().process_frame
		if main.board.size != sel_size:
			print("SHOTS board size changed with %s selected: %s" % [tw.type, main.board.size])
	S.sel = null
	main.ui.render_inspector()
	for i in 4:
		await get_tree().process_frame
	print("SHOTS board size selected %s, deselected %s" % [sel_size, main.board.size])
	main.ui.menus.show_settings()
	await _shot("06b_pause_menu")
	main.ui.menus.close_settings()
	S.pending_levels = 1
	for i in 5:
		await get_tree().process_frame
	await _shot("07_levelup")
	main.ui.close_modal()
	S.paused = false
	S.pending_levels = 0
	g.show_shop()
	await _shot("08_shop")
	main.ui.close_modal()
	g.leave_shop()
	main.ui.menus.show_heroes()
	await _shot("09_hero_page")
	main.ui.menus.show_towers()
	await _shot("10_tower_page")
	main.ui.hide_screen()
	g.end_run(false, true)
	await _shot("11_end")
	main.ui.menus.show_log()
	for bt in main.ui.find_children("*", "Button", true, false):
		if bt.flat and bt.is_visible_in_tree():
			bt.pressed.emit()
			break
	await _shot("18_log_details")
	main.ui.menus.show_heroes("wizard")
	await _shot("19_wizard_elements")
	main.ui.hide_screen()
	main.ui.menus.show_settings()
	await _shot("12_settings")
	main.ui.menus.close_settings()
	main.ui.close_modal()
	Updater._new_engine_notice()
	await _shot("13_new_engine")
	main.ui.close_modal()
	Save.meta.secret_heroes["gale"] = true
	g.modal.emit("secret", { hero = "gale" })
	await _shot("20_secret_popup")
	main.ui.close_modal()
	main.ui.menus.show_heroes("gale")
	await _shot("14_gale_page")
	main.ui.menus.show_towers("shrine")
	await _shot("15_shrine_page")
	main.ui.hide_screen()
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["shrine", "arcane", "frost", "plasma", "tesla"])
	g = main.game
	S = g.S
	S.gold = 5000
	var spots := 0
	for c in range(2, 18):
		for r in range(2, 11):
			var k: String = ["shrine", "arcane", "frost", "plasma", "tesla"][spots % 5]
			if spots < 6 and g.build_problem(c, r, k) == "":
				g.place_tower(c, r, k)
				spots += 1
	g.start_wave()
	S.spawn_q = ["knight", "grunt", "grunt", "brute", "grunt"]
	for i in 260:
		await get_tree().process_frame
	var lead := g.lead_enemy()
	if lead:
		S.hero.x = lead.x - 30
		S.hero.y = lead.y
	g.use_ability()
	for i in 12:
		await get_tree().process_frame
	await _shot("16_gale_run")
	for t in S.towers:
		if t.hero_buff:
			S.sel = t
			main.ui.render_inspector()
	await _shot("17_shrine_inspect")
	S.sel = null
	g.end_run(false, true)
	main.ui.close_modal()
	main.ui.menus.new_run("coral")
	main.ui.menus.start_run("striker", Array(DB.tower_order).slice(0, 5))
	g = main.game
	S = g.S
	S.gold = 3000
	spots = 0
	for cell in [Vector2i(3, 4), Vector2i(7, 3), Vector2i(12, 4), Vector2i(17, 4), Vector2i(18, 8), Vector2i(14, 7), Vector2i(10, 10), Vector2i(6, 8)]:
		var k: String = DB.tower_order[spots % 5]
		if g.build_problem(cell.x, cell.y, k) == "":
			g.place_tower(cell.x, cell.y, k)
		spots += 1
	g.start_wave()
	for i in 240:
		await get_tree().process_frame
		if main.ui.modal_open():
			main.ui.close_modal()
			g.pick_offer(0)
	await _shot("21_coral_run")
	for i in 20:
		await get_tree().process_frame
	await _shot("21b_coral_run")
	g.end_run(false, true)
	main.ui.close_modal()
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("sniper", Array(DB.tower_order).slice(0, 5))
	g = main.game
	S = g.S
	S.hero.crit = 1.0
	for i in 4:
		g.offers = g.roll_perks()
		g.offers[0] = g.offers[0].duplicate()
		g.offers[0].perk = g.R.perks.find("caliber")
		S.pending_levels += 1
		g.pick_offer(0)
	main.ui.render_hero()
	g.start_wave()
	for i in 200:
		await get_tree().process_frame
		if main.ui.modal_open():
			main.ui.close_modal()
			g.pick_offer(0)
	S.hero.x = S.map.pos_at(S.map.path_len * 0.3).x
	S.hero.y = S.map.pos_at(S.map.path_len * 0.3).y + 40
	for i in 90:
		await get_tree().process_frame
		if main.ui.modal_open():
			main.ui.close_modal()
			g.pick_offer(0)
		if i % 20 == 0:
			S.hero.cd = 0
	for i in 300:
		await get_tree().process_frame
		if main.ui.modal_open():
			main.ui.close_modal()
			g.pick_offer(0)
		if S.fx.any(func(f): return f.k == "num"):
			for f in S.fx:
				if f.k == "num":
					print("SHOTS crit number %s at %.0f,%.0f t %.2f" % [f.text, f.x, f.y, f.t])
			break
	await _shot("22_sniper_crits")
	print("SHOTS DONE")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
