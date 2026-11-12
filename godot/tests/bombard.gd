## The Bombard merge model (art_src/towers/merges/mortar_plasma) in a real run with the default look: Siege Mortar and
## Plasma Cannon are maxed and merged, and the hybrid draws the Bombard GLB in its own smooth render (Merge3D): spawn
## then idle, the Turret yaws to targets with the Gun held at its 62 degree lob, and each shot charges first: fire
## starts, the plasma glob and charge rings build, and the shot only leaves (and hits) 0.55 s in, from the Muzzle.
## Mortar's path colours on mask A (the barrel), plasma's on mask B (the base and canisters).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/bombard.tscn -- <out dir>
extends Node

var out := "user://bombard"
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
		g.level_tower(t, picked)
		guard += 1


## Clears whatever a merge or a level-up left waiting (boon card, wave choice), so the game runs (paused, every
## model holds still, spawn included).
func _unblock(g: Game) -> void:
	for i in 30:
		main.ui.close_modal()
		if g.S.pending_boon != "":
			g.take_boon()
		if g.S.paused and g.wave_opts.size() > 0:
			g.choose_mode(0)
		await get_tree().process_frame
	print("paused=", g.S.paused)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(240).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["mortar", "plasma", "frost", "arcane"])
	await _frames(10)
	var g := main.game
	var S := g.S
	var b := main.board
	S.gold = 999999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	_check(b.live == null, "the default look: no shared low-res layer")
	MergeArt.clear_cache()
	var probe := Tower.new()
	probe.hybrid = true
	probe.type = "mortar+plasma"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/mortar_plasma/bombard.glb"), "the merge loader finds bombard.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "Turret" and cfg.get("pitch") == "Turret/Gun" and cfg.get("muzzle") == "Muzzle" and is_equal_approx(float(cfg.get("shot_time", 0)), 0.55) and int(cfg.get("wide", 0)) == 54, "tower.json: yaw Turret, pitch Turret/Gun, muzzle by name, shot_time 0.55, wide 54")
	var spot := g.pos_at(300.0) # beside the road, so it gets shots in during the wave
	var placed := {}
	for type in ["mortar", "plasma"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	var arc: Tower = placed.mortar
	var tes: Tower = placed.plasma
	_max(g, arc)
	_max(g, tes)
	await _frames(4)
	var ca := PathColors.for_tower(arc)
	var ct := PathColors.for_tower(tes)
	print("mortar paths ", arc.order, " ", ca, "  plasma paths ", tes.order, " ", ct)
	_check(arc.lvl == g.R.max_level and tes.lvl == g.R.max_level, "both parents maxed")
	await RenderingServer.frame_post_draw
	_crop("0_parents", Vector2(arc.x, Board.SY(arc.y)), Vector2(170, 110), 2)
	print("merge problem: '", g.merge_problem(tes, arc), "'")
	g.try_merge(tes, arc) # started from the plasma: mask A is still mortar (sorted key)
	await _frames(3)
	var rail: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "mortar+plasma":
			rail = t
	_check(rail != null, "Siege Mortar + Plasma Cannon merge into the Bombard")
	if rail == null:
		_done()
		return
	var v = rail.get_meta("view") if rail.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	_check(v is Merge3D, "the Bombard draws its GLB in its own smooth render, not the plinth")
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(b._merge_model(rail), "the board treats it as a model (no plinth or placeholder core)")
	_check(m.yaw_node != null and m.yaw_node.name == "Turret", "yaw node is Turret")
	_check(m.pitch_node != null and m.pitch_node.name == "Gun", "pitch node is Gun")
	_check(is_equal_approx(m.pitch_node.rotation.x, -1.0858), "the Gun rests at tower.json aim -1.0858 (%.4f)" % m.pitch_node.rotation.x)
	_check(m.muzzle != null and m.muzzle.name == "Muzzle" and m.muzzle.get_parent().name == "Barrel", "muzzle is the bore mouth (Barrel/Muzzle)")
	_check(m.mats.size() == 1, "one recolour material for the body (bombard_mat)")
	_check(is_equal_approx(g.merge_lead(rail), 0.55), "the game holds the shot 0.55 s into fire")
	_check(m.mask_a != null and m.mask_b != null, "both accent masks load")
	var mat := m.mats[0]
	_check((mat.get_shader_parameter("a_trim") as Color).is_equal_approx(ca[0]), "mask A (barrel) trim = mortar's first path colour")
	_check((mat.get_shader_parameter("a_glow") as Color).is_equal_approx(ca[1]), "mask A glow = mortar's second path colour")
	_check((mat.get_shader_parameter("b_trim") as Color).is_equal_approx(ct[0]), "mask B (base, canisters) trim = plasma's first path colour")
	_check((mat.get_shader_parameter("b_detail") as Color).is_equal_approx(ct[2]), "mask B detail = plasma's third path colour")
	_check((mat.get_shader_parameter("recipe") as Color).is_equal_approx(Color("#D8F0B0")), "body tint is the recipe colour #D8F0B0")
	var at := Vector2(rail.x, Board.SY(rail.y))
	await _frames(20)
	await _crop("1_spawning", at, Vector2(90, 90), 3)
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("2_idle", at, Vector2(90, 90), 3)
	m.aim(Vector2(-60, 25))
	await get_tree().create_timer(0.8).timeout
	_check(absf(m.yaw_node.rotation.y) > 0.5, "the Turret yaws toward a target (%.2f rad)" % m.yaw_node.rotation.y)
	_check(is_equal_approx(m.pitch_node.rotation.x, -1.0858), "the Gun keeps its lob angle while turning")
	await _crop("3_aim_left", at, Vector2(90, 90), 3)
	var mm = b.merge_muzzle(rail)
	_check(mm != null and (mm as Vector2).y < Board.SY(rail.y) - 25, "the muzzle shows up at the barrel's mouth, over the tower (%s)" % [mm])
	# a real wave: it fires at enemies
	S.hero.x = rail.x - 120
	await _unblock(g)
	g.start_wave()
	_check(S.wave_active, "the wave starts")
	var fired := false
	var st0 = rail.shot_at
	for i in 600:
		await get_tree().process_frame
		if rail.shot_at != st0 and m.ap.current_animation == "fire":
			fired = true
			break
	_check(fired, "fire starts when the Bombard picks a target in a wave")
	# the charge: fire has started, but nothing has left the barrel yet
	var glob: Node3D = m.model.find_child("MuzzleGlow", true, false)
	var halo: Node3D = m.model.find_child("ChargeHalo", true, false)
	var ring2: Node3D = m.model.find_child("ChargeRing2", true, false)
	var tagged := func() -> bool: return S.fx.any(func(f): return f.k == "line" and f.get("tw") == rail)
	_check(not tagged.call(), "no shot has left as the charge starts")
	var t0 := S.time
	var hp0 := 0.0
	for e in S.enemies:
		hp0 += e.hp
	var g_early := 0.0
	var g_late := 0.0
	var shot_t := -1.0
	var shown_mid := false
	for i in 200:
		await get_tree().process_frame
		var el := S.time - t0
		if el > 0.08 and el < 0.14 and g_early == 0.0:
			g_early = glob.scale.x
		if el > 0.40 and el < 0.50 and not shown_mid:
			shown_mid = true
			g_late = glob.scale.x
			_check(m.ap.current_animation == "fire" and not tagged.call(), "0.45 s in: still charging, no shot yet")
			_check(halo.scale.x > 0.3 and ring2.scale.x > 0.3, "the charge halo and all three charge rings are lit (halo %.2f, ring %.2f)" % [halo.scale.x, ring2.scale.x])
			await _crop("4_charging", at, Vector2(110, 110), 3)
		if tagged.call():
			shot_t = el
			break
	_check(g_early > 0.0 and g_late > g_early * 2.0, "the plasma glob swells through the charge (%.2f -> %.2f)" % [g_early, g_late])
	_check(shot_t >= 0.5 and shot_t <= 0.75, "the shot leaves the Muzzle at the shot moment (%.2f s after fire starts)" % shot_t)
	await _crop("5_firing", at, Vector2(110, 90), 3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("6_board.png"))
	_done()


func _done() -> void:
	print("BOMBARD DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
