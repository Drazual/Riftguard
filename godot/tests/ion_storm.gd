## The Ion Storm merge model (art_src/towers/merges/plasma_tesla) in a real run: Plasma Cannon and Tesla Coil are
## maxed and merged. The model never turns; each shot charges 0.55 s, a shell leaves its Muzzle straight up, falls
## 0.6 s later on the target's lead point and blasts, and lightning forks outward to the nearest enemies it missed.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/ion_storm.tscn -- <out dir>
extends Node

var out := "user://ion_storm"
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
	main.ui.menus.start_run("gale", ["plasma", "tesla", "frost", "arcane"])
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
	MergeArt.clear_cache()
	var probe := Tower.new()
	probe.hybrid = true
	probe.type = "plasma+tesla"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/plasma_tesla/ion_storm.glb"), "the merge loader finds ion_storm.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "-" and cfg.get("pitch") == "-" and cfg.get("muzzle") == "Muzzle" and cfg.get("buff_point") == "BuffPoint" and is_equal_approx(float(cfg.get("shot_time", 0)), 0.55), "tower.json: no yaw or pitch, Muzzle, BuffPoint, shot_time 0.55")
	_check(ClassDB.class_exists("IonStormFX") or ResourceLoader.exists("res://art_src/towers/merges/plasma_tesla/fx/ion_storm_fx.tscn"), "IonStormFX is there")
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["plasma", "tesla"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	var pla: Tower = placed.plasma
	var tes: Tower = placed.tesla
	_max(g, pla)
	_max(g, tes)
	await _frames(4)
	g.try_merge(tes, pla)
	await _frames(3)
	var ion: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "plasma+tesla":
			ion = t
	_check(ion != null, "Plasma Cannon + Tesla Coil merge into the Ion Storm")
	if ion == null:
		_done()
		return
	print("ion stats: dmg %.1f rate %.2f splash %.0f chain %.0f chain_mul %.2f reach %.0f keep %s stun %.2f blast %.2f sig plasma %s tesla %s" % [ion.dmg, ion.rate, ion.splash, ion.chain, ion.chain_mul, ion.chain_reach, ion.chain_keep, ion.stun, ion.chain_blast, S.sig.get("plasma", false), S.sig.get("tesla", false)])
	_check(ion.radial_chain and not ion.beam and not ion.lob, "it throws its lightning outward (radial_chain)")
	_check(ion.splash >= 50 and ion.chain >= 4 and ion.chain_mul >= 0.7, "splash %.0f, chain %.0f, chain_mul %.2f" % [ion.splash, ion.chain, ion.chain_mul])
	var v = ion.get_meta("view") if ion.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(m.yaw_node == null and m.pitch_node == null, "no yaw or pitch: it never turns")
	_check(m.muzzle != null and m.muzzle.name == "Muzzle", "muzzle is the barrel's Muzzle")
	_check(is_equal_approx(g.merge_lead(ion), 0.55), "the game holds the shot 0.55 s into fire")
	_check(is_equal_approx(g.ion_flight(ion), 0.6), "the shell flies 0.6 s (tower.json shell_flight)")
	var at := Vector2(ion.x, Board.SY(ion.y))
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("1_idle", at, Vector2(90, 110), 3)
	var mm = b.merge_muzzle(ion)
	_check(mm != null and (mm as Vector2).y < Board.SY(ion.y) - 40, "the muzzle is up at the barrel's top (%s)" % [mm])
	# a real wave
	S.hero.x = ion.x - 160
	var toughen := func():
		for e in S.enemies:
			if not e.has_meta("tough"):
				e.set_meta("tough", true)
				e.max *= 30.0
				e.hp = e.max
	get_tree().process_frame.connect(toughen)
	await _unblock(g)
	g.start_wave()
	var fired := false
	var st0 = ion.shot_at
	for i in 900:
		await get_tree().process_frame
		if ion.shot_at != st0 and m.ap.current_animation == "fire":
			fired = true
			break
	_check(fired, "fire starts when it picks a target in a wave")
	var t0 := S.time
	var shell_t := -1.0
	var blast_t := -1.0
	var no_line := true
	var shot_crop := false
	var blast_crop := false
	var sh: Dictionary = {}
	for i in 400:
		await get_tree().process_frame
		var el := S.time - t0
		for f in S.fx:
			if f.get("tw") == ion and f.k == "line":
				no_line = false
			if f.get("tw") == ion and f.k == "ion_shell" and shell_t < 0:
				shell_t = el
				sh = f
			if f.get("tw") == ion and f.k == "ion_blast" and blast_t < 0 and shell_t >= 0:
				blast_t = el
				print("blast: forks to %d, r %.0f, power %.2f" % [f.to.size(), f.r, f.pw])
		if shell_t >= 0 and not shot_crop and el > shell_t + 0.45:
			shot_crop = true
			_check(b.ion_fx != null and b.ion_fx.shells.size() > 0, "the board draws the shell in flight")
		if blast_t >= 0 and not blast_crop:
			blast_crop = true
			await _frames(2)
			await _crop("3_blast_forks", Vector2(sh.x, Board.SY(sh.y)), Vector2(170, 130), 2)
		if blast_t >= 0 and el > blast_t + 0.4:
			break
	_check(shell_t >= 0.5 and shell_t <= 0.7, "the shell leaves at the shot moment (%.2f s after fire)" % shell_t)
	_check(blast_t - shell_t >= 0.55 and blast_t - shell_t <= 0.75, "it lands 0.6 s later (%.2f s)" % (blast_t - shell_t))
	_check(no_line, "no instant shot line")
	# a set-up blast: a clump on the road, more enemies further out
	S.towers.erase(ion) # out of the loop while we hit by hand
	await _frames(30)
	for e in S.enemies:
		e.dead = true
	S.enemies.clear()
	await _frames(2)
	var D := S.map.path_len * 0.4
	var sp := ion.splash
	var reach := sp + ion.chain_reach
	var offs := [0.0, 8.0, -8.0, sp + 12.0, -(sp + 25.0), sp + 45.0, -(sp + 60.0), sp + 75.0, -(sp + 85.0), reach + 120.0]
	for o in offs:
		g.spawn("grunt", D + o)
	var c := g.pos_at(D)
	var es: Array = S.enemies.duplicate()
	for i in es.size():
		var p := g.pos_at(D + offs[i])
		es[i].x = p.x
		es[i].y = p.y
		es[i].speed = 0.0
		es[i].set_meta("tough", true)
		es[i].max = 1e6
		es[i].hp = 1e6
	S.towers.append(ion)
	ion.stun_t = 30.0
	# just the blast and the forks here (path extras like cluster bombs would muddy the numbers)
	ion.cluster = 0
	ion.pierce = 0
	ion.echo = 0
	ion.gravity = 0
	ion.chain_blast = 0
	var inside := g.in_range(c.x, c.y, ion.splash)
	var out_r := g.in_range(c.x, c.y, reach).filter(func(e): return not inside.has(e))
	out_r.sort_custom(func(p, q): return Vector2(p.x, p.y).distance_to(c) < Vector2(q.x, q.y).distance_to(c))
	var want := out_r.slice(0, int(ion.chain))
	var hp0 := {}
	for e in es:
		hp0[e] = e.hp
	var zones0 := S.zones.size()
	g._land(ion, { x = c.x, y = c.y, d = -1.0, dead = false, fake = true }, 100.0, ion.splash, false, false, false, false, 0.0, false)
	var blast_dmg := 0.0
	for e in inside:
		blast_dmg = maxf(blast_dmg, hp0[e] - e.hp)
	# the biggest one-frame drop is the fork's hit (path burns tick on top, a little each frame)
	var jump := {}
	var last := {}
	for e in es:
		last[e] = e.hp
		jump[e] = 0.0
	var tl := S.time
	var snap := false
	while S.time - tl < 0.4:
		await get_tree().process_frame
		for e in es:
			jump[e] = maxf(jump[e], last[e] - e.hp)
			last[e] = e.hp
		if not snap and S.time - tl > 0.09:
			snap = true
			await _crop("4_blast_forks", Vector2(c.x, Board.SY(c.y)), Vector2(220, 160), 2)
			get_viewport().get_texture().get_image().save_png(out.path_join("5_board.png"))
		for e in es:
			jump[e] = maxf(jump[e], last[e] - e.hp)
			last[e] = e.hp
	var keep: bool = S.sig.get("tesla", false) or ion.chain_keep
	var ok_set := true
	var fork_dmg := []
	for e in es:
		var lost: float = hp0[e] - e.hp
		if want.has(e):
			fork_dmg.append(jump[e])
			if lost <= 0:
				ok_set = false
		elif not inside.has(e) and lost > 1.0 and ion.chain_blast == 0:
			ok_set = false
			print("  not a fork target but lost %.1f at %.0f px" % [lost, Vector2(e.x, e.y).distance_to(c)])
	for e in es:
		print("  at %.0f px lost %.1f%s" % [Vector2(e.x, e.y).distance_to(c), hp0[e] - e.hp, " (fork)" if want.has(e) else ""])
	print("inside %d, out %d (forks want %d), blast %.1f, forks %s, keep %s" % [inside.size(), out_r.size(), want.size(), blast_dmg, fork_dmg, keep])
	_check(blast_dmg > 0, "the blast hits the clump (%d enemies, %.1f)" % [inside.size(), blast_dmg])
	_check(want.size() > 0 and ok_set, "lightning forks to the %d nearest enemies the blast missed, within %.0f px" % [want.size(), reach])
	var ratio: float = (fork_dmg.min() / blast_dmg) if fork_dmg.size() and blast_dmg > 0 else 0.0
	var ratio_hi: float = (fork_dmg.max() / blast_dmg) if fork_dmg.size() and blast_dmg > 0 else 0.0
	var exp := 1.0 if keep else ion.chain_mul
	_check(absf(ratio - exp) < 0.08 and absf(ratio_hi - exp) < 0.08, "each fork takes %d%% of the shot, no falloff (%.2f..%.2f)" % [exp * 100, ratio, ratio_hi])
	# a shell on the clump, to see it fall
	g.ion_shell(ion, es[0], 100.0, ion.splash, false, false, false, false, 0.0)
	var ts := S.time
	while S.time - ts < 0.42:
		await get_tree().process_frame
	await _crop("2_shell_falling", Vector2(c.x, Board.SY(c.y) - 120), Vector2(160, 170), 2)
	if S.sig.get("plasma", false):
		_check(S.zones.size() > zones0, "Napalm Shells leave a burning zone")
	_done()


func _done() -> void:
	print("ION STORM DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
