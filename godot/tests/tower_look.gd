## Close-ups of every turret tower standing on the map (how its shadow grounds it), and of the Razor Disc
## throwing its saw (the flying saw should match the blade loaded on the tower). Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/tower_look.tscn -- <out dir>
extends Node

var out := "user://tower_look"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): print("LOOK TIMEOUT"); get_tree().quit(1))
	seed(5)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var kinds := ["disc", "plasma", "laser", "frost", "tesla", "shrine", "mortar"]
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("striker", kinds)
	for i in 10:
		await get_tree().process_frame
	var g := main.game
	var S := g.S
	S.gold = 50000
	S.lives = 999
	var cells := g.build_cells()
	var dist := {}
	for c in cells:
		dist[c] = S.map.path_dist(g.cell_pos(c.x, c.y))
	cells.sort_custom(func(a, b): return dist[a] < dist[b])
	var towers := []
	for k in kinds:
		for c in cells:
			if g.build_problem(c.x, c.y, k) == "":
				g.place_tower(c.x, c.y, k)
				towers.append(S.towers[S.towers.size() - 1])
				break
	await _frames(20)
	var b: Board = main.board
	for t: Tower in towers:
		await _close(b, Vector2(t.x, b.SY(t.y)), "tower_" + t.type, 4)
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	g.start_wave()
	for k in 8:
		g.spawn("brute", S.map.path_len * (0.2 + k * 0.07))
	var disc: Tower = towers[0]
	for i in 30:
		await _frames(3)
		if S.discs.any(func(dk): return dk.tw == disc and dk.wait <= 0):
			break
	for k in 4:
		await _close(b, Vector2(disc.x, b.SY(disc.y)), "disc_throw_%d" % k, 3, 2)
		await _frames(2)
	# the mortar's shell: straight up out of its barrel, then straight down onto the target
	var mortar: Tower = towers[towers.size() - 1]
	for want in [0.1, 0.94]:
		for i in 400:
			await get_tree().process_frame
			var sh = S.shells.filter(func(x): return x.tw == mortar and x.wait <= 0 and not x.done)
			if sh.size() and absf(sh[0].t / sh[0].T - want) < 0.04:
				print("mortar shell at %.2f of its flight, T %.2f" % [sh[0].t / sh[0].T, sh[0].T])
				var p := Vector2(mortar.x, b.SY(mortar.y)) if want < 0.5 else Vector2(sh[0].x1, b.SY(sh[0].y1))
				await _close(b, p + Vector2(0, -20), "mortar_%02d" % int(want * 100), 2, 2)
				break
	print("LOOK DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _close(b: Board, p: Vector2, name: String, zoom := 4, wide := 1) -> void:
	await RenderingServer.frame_post_draw
	var img := b.viewport.get_texture().get_image()
	var s := img.get_width() / 960.0
	var c := Vector2(p.x * s, p.y * s)
	var hw := 40 * wide * s
	var r := Rect2i(int(c.x - hw), int(c.y - 60 * s), int(hw * 2), int(80 * s)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var cr := img.get_region(r)
	cr.resize(cr.get_width() * zoom / int(maxf(1, s)), cr.get_height() * zoom / int(maxf(1, s)), Image.INTERPOLATE_NEAREST)
	cr.save_png(out.path_join(name + ".png"))
