## Screenshots of the hero select (3D heroes show their live model as the portrait) and of each 3D hero on the
## board: idling, walking a circle (turning smoothly) and firing or casting. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/heroes3d.tscn -- <out dir>
extends Node

var out := "user://heroes3d"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(220).timeout.connect(func(): print("HEROES TIMEOUT"); get_tree().quit(1))
	seed(5)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.show_hero_select()
	await _shot("00_select", 20)
	for hero in ["striker", "sniper", "wizard", "vanguard"]:
		main.ui.menus.start_run(hero, ["arcane", "plasma", "laser", "frost", "tesla", "mortar"])
		for i in 10:
			await get_tree().process_frame
		var g := main.game
		var S := g.S
		var h := S.hero
		S.lives = 999
		var b: Board = main.board
		for i in 5:
			await get_tree().process_frame
		print(hero, " hero at ", h.pos(), " 3d ", b.hero_3d, " vis ", b.hero_3d.visible if b.hero_3d else null, " pos ", b.hero_3d.position if b.hero_3d else null, " in tree ", b.hero_3d.is_inside_tree() if b.hero_3d else null, " ko ", h.ko)
		await _shot("%s_0_idle" % hero, 20)
		# walk a circle around where it stands, so it turns through every direction
		var c := h.pos()
		for k in 8:
			var a := k * TAU / 8
			g.move_hero(c.x + cos(a) * 70, c.y + sin(a) * 70)
			for i in 12:
				await get_tree().process_frame
			await _shot("%s_1_walk_%d" % [hero, k], 1)
		g.start_wave()
		for k in 6:
			g.spawn("brute", S.map.path_len * (0.3 + k * 0.05))
		if hero == "wizard":
			g.ready_rune("q")
		for i in 120:
			await get_tree().process_frame
			if hero == "wizard" and i == 30:
				var e = S.enemies[0]
				g.cast_runes(e.x, e.y)
		for k in 3:
			await _shot("%s_2_fight_%d" % [hero, k], 6)
		print(hero, " shots ", h.atk_at, " enemies ", S.enemies.size(), " model ", main.board.hero_3d != null, " sheet ", main.board.hero_spr.sprite_frames)
		main.game.end_run(false, true)
		for i in 5:
			await get_tree().process_frame
		main.ui.close_modal()
		main.ui.menus.new_run("canal")
	get_tree().quit()


func _shot(name: String, wait := 4) -> void:
	for i in wait:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
