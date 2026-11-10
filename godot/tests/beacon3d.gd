## The Rift Beacon live from its 3D model (Beacon3D): placed on Ocean Drive next to two towers, it spins up, keeps
## its idle spin, its ground ring is the size of its buff range, and each aura tick plays buff_pulse on the second
## player while the rings keep turning. Photographed placed, idle and mid-pulse.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/beacon3d.tscn -- <out dir>
extends Node

var out := "user://beacon3d"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _crop(name: String, at: Vector2, half: Vector2, z: int) -> void:
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var img := bi.get_region(r)
	img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(200).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["beacon", "arcane", "mortar", "frost"])
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
	# placing it: the ghost under the pointer is the live model, not the old sprite
	var cells: Array = g.build_cells()
	var hc: Vector2i = cells[cells.size() / 2]
	S.build = "beacon"
	S.hover = hc
	await _frames(20)
	_check(b.beacon_ghost != null and b.beacon_ghost.visible and (b.ghost == null or not b.ghost.visible), "the placement ghost is the live model")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("0_placing.png"))
	S.build = ""
	await _frames(2)
	_check(not b.beacon_ghost.visible, "the ghost goes away when not placing")
	var spot := Vector2(560, 290)
	var placed := {}
	for type in ["beacon", "arcane", "mortar"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		if best.x >= 0:
			g.place_tower(best.x, best.y, type)
			placed[type] = S.towers[S.towers.size() - 1]
		spot += Vector2(60, 20)
	S.hero.x = 420
	S.hero.tx = null
	await _frames(3)
	var t: Tower = placed.get("beacon")
	_check(t != null, "a Rift Beacon was placed")
	var v = t.get_meta("view") if t and t.has_meta("view") else null
	_check(v is Board.BEACON_VIEW, "it is drawn live from its 3D model (%s)" % [v.get_class() if v else "-"])
	if not v is Board.BEACON_VIEW:
		print("BEACON DONE fails=%d" % fails)
		get_tree().quit(1)
		return
	var bv = v
	var ap: AnimationPlayer = bv.vis.anim
	_check(ap.current_animation == "spawn", "it spins up when placed (%s)" % ap.current_animation)
	await _crop("1_spawn", Vector2(t.x, Board.SY(t.y)), Vector2(70, 60), 6)
	await _frames(90)
	_check(ap.current_animation == "idle", "then it idles (%s)" % ap.current_animation)
	_check(is_equal_approx(bv.radius, g.t_range(t)), "its ground ring has the buff range (%.0f = %.0f)" % [bv.radius, g.t_range(t)])
	var px: Vector2i = bv.ring_vp.size
	_check(absf(px.x - (g.t_range(t) * Board.PX * 2 + 12)) < 2 and absf(float(px.y) / px.x - Board.K) < 0.02, "the ring lies at the ground's tilt, like the range rings (%s)" % px)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("2_board.png"))
	await _crop("3_idle", Vector2(t.x, Board.SY(t.y)), Vector2(70, 60), 6)
	bv.ring_vp.get_texture().get_image().save_png(out.path_join("3c_ring_vp.png"))
	await _crop("3b_ring", Vector2(t.x, Board.SY(t.y)), Vector2(330, 230), 2)
	# a wave: the aura ticks and the pulse plays without stopping the spin
	var rotor: Node3D = bv.vis.get_node("Model/Turret/Rotor")
	g.start_wave()
	var pulsed := false
	var spun := true
	for i in 400:
		await get_tree().process_frame
		if bv.vis.fx.current_animation == "buff_pulse":
			var y0 := rotor.rotation.y
			await _frames(3)
			spun = absf(angle_difference(rotor.rotation.y, y0)) > 0.005 and ap.current_animation == "idle"
			await _frames(8)
			await _crop("4_pulse", Vector2(t.x, Board.SY(t.y)), Vector2(70, 60), 6)
			await _crop("4b_pulse_ring", Vector2(t.x, Board.SY(t.y)), Vector2(330, 230), 2)
			pulsed = true
			break
	_check(pulsed, "the aura tick plays buff_pulse")
	_check(spun, "the rings keep spinning while it pulses")
	var buffed := false
	for o: Tower in S.towers:
		if o != t and o.buff != null:
			buffed = true
	_check(buffed, "a tower in range gets the Beacon's buff (unchanged game logic)")
	print("BEACON DONE fails=%d" % fails)
	get_tree().quit(fails)
