## Prism Lance v2 (arcane+laser) in a real run with the default look: Arcane Bolt and Prism Laser are maxed and merged
## into a held beam that charges first (charge clip, no tick yet), then ticks every rate from the model's Muzzle,
## heating up on one target (cyan -> pink -> magenta/white and wider), resetting on a switch, with arcane sparks off
## every tick to nearby enemies for 35% of it. Turning and tilting follow the target; stun, pause and sell behave.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/prism_lance.tscn -- <out dir>
extends Node

var out := "user://prism_lance"
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
	main.ui.menus.start_run("gale", ["arcane", "laser", "mortar", "frost"])
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
	probe.type = "arcane+laser"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/arcane_laser/prism_lance.glb"), "the merge loader finds prism_lance.glb")
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("beam") == true and float(cfg.get("shot_time", 1)) == 0.0 and cfg.get("muzzle") == "Muzzle", "tower.json: beam, shot_time 0, muzzle by name")
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["arcane", "laser"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	_max(g, placed.arcane)
	_max(g, placed.laser)
	await _frames(3)
	g.try_merge(placed.laser, placed.arcane)
	await _frames(3)
	var t: Tower = null
	for x: Tower in S.towers:
		if x.hybrid and x.type == "arcane+laser":
			t = x
	_check(t != null, "Arcane Bolt + Prism Laser merge into the Prism Lance")
	if t == null:
		_done()
		return
	_check(t.lance and t.beam, "it is a beam tower (lance)")
	_check(is_equal_approx(t.ramp, 0.08) and is_equal_approx(t.ramp_max, 10.0), "heat: +8%% per stack, 10 stacks (%.2f, %d)" % [t.ramp, int(t.ramp_max)])
	_check(int(t.spark_n) == 2 and is_equal_approx(t.spark_r, 90.0) and is_equal_approx(t.spark_pct, 0.35), "sparks: 2 targets, 90 px, 35%")
	_check(is_zero_approx(g.merge_lead(t)), "no held shot (merge_lead 0)")
	print("lance dmg %.1f every %.2fs" % [t.dmg, t.rate])
	await _unblock(g)
	var v = t.get_meta("view") if t.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).beam, "drawn from its GLB in its own render, as a beam model")
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle after spawn")
	var at := Vector2(t.x, Board.SY(t.y))
	var pitch0 := m.pitch_node.rotation.x
	# a wave: the first lock charges, then the beam starts
	S.hero.x = t.x - 150
	await _unblock(g)
	g.start_wave()
	# tougher enemies, so one stays in the beam long enough to heat it up
	var toughen := func():
		for e in S.enemies:
			if not e.has_meta("tough"):
				e.set_meta("tough", true)
				e.max *= 60.0
				e.hp = e.max
	get_tree().process_frame.connect(toughen)
	var charged := false
	var shots0 := t.shots
	for i in 900:
		await get_tree().process_frame
		if t.lance_state == "charge":
			charged = true
			break
	_check(charged, "the first lock starts the charge")
	# the charge began during the frame before this one was seen
	var t_detect: float = S.time - get_process_delta_time() * S.speed
	await _frames(2)
	_check(m.ap.current_animation == "charge", "the charge clip plays")
	_check(t.shots == shots0 and not b.lance_beams.has(t), "no tick and no beam while charging")
	await _crop("1_charging", at, Vector2(120, 110), 3)
	var on := false
	var t_charge := t_detect
	for i in 120:
		await get_tree().process_frame
		if b.lance_beams.has(t):
			on = true
			break
	_check(on and S.time - t_charge >= 0.25, "the beam starts when the charge is done (%.2f s)" % (S.time - t_charge))
	await _frames(3)
	_check(m.ap.current_animation == "fire", "the fire loop holds while the beam is on")
	var bm = b.lance_beams.get(t)
	var h0: float = bm.heat if bm else -1.0
	var w0: float = bm._width() if bm else 0.0
	await _crop("2_beam_cold", at, Vector2(170, 130), 2)
	# heat builds while the beam stays on one enemy
	var hot := 0.0
	var e0 = t.last_target
	var sparks_seen := 0
	var spark_ok := true
	var hp_ok := true
	# the game tick runs after this script resumes, so a burst seen now was
	# made during the last frame: compare against hp from two frames back
	var older := {}
	var before := {}
	for i in 240:
		older = before
		before = {}
		for e in S.enemies:
			before[e] = e.hp
		await get_tree().process_frame
		for f in S.fx:
			if f.k == "sparks" and not f.get("_seen", false):
				f._seen = true
				sparks_seen += 1
				var want := 2 + (1 if f.heat >= 0.5 else 0) + int(round(t.prism))
				if f.to.size() > want or f.to.is_empty():
					spark_ok = false
					print("  burst of %d (want <= %d, heat %.2f)" % [f.to.size(), want, f.heat])
				for o in f.to:
					if older.has(o) and o.hp >= older[o] and not o.dead:
						hp_ok = false
						print("  spark target hp %.1f -> %.1f" % [older[o], o.hp])
		bm = b.lance_beams.get(t)
		if bm and is_instance_valid(bm):
			hot = maxf(hot, bm.heat)
		if hot >= 0.95:
			break
	bm = b.lance_beams.get(t)
	_check(hot > h0 + 0.3, "heat builds on one target (%.2f -> %.2f)" % [h0, hot])
	if bm and is_instance_valid(bm):
		_check(bm._width() > w0 * 1.2, "the beam widens as it heats (%.1f -> %.1f px)" % [w0, bm._width()])
		var cold := PrismLanceBeam.heat_color(0.0)
		var hc := PrismLanceBeam.heat_color(bm.heat)
		_check(cold.b > 0.9 and hc.r > 0.9 and hc.g < 0.5, "colour runs cyan -> pink/magenta (%s -> %s)" % [cold, hc])
		await _crop("3_beam_hot", at, Vector2(170, 130), 2)
	_check(sparks_seen > 0, "sparks fly off the ticks (%d bursts)" % sparks_seen)
	_check(spark_ok, "each burst hits up to 2 nearby enemies, 3 at half heat (+%d from Prism Split)" % int(round(t.prism)))
	_check(hp_ok, "the spark targets take damage")
	# sparks are 35% of the tick: call the spark step directly on a known tick
	var tgt = t.last_target
	if tgt != null and not tgt.dead:
		var near := g.in_range(tgt.x, tgt.y, t.spark_r).filter(func(o): return o != tgt)
		if near.size():
			var o: Enemy = near[0]
			var hp1 := o.hp
			g.lance_sparks(t, tgt, 100.0, [tgt], 0.0)
			var lost := hp1 - o.hp
			var full := 100.0
			print("spark took %.1f of a 100 tick (armor %.0f)" % [lost, o.armor if "armor" in o else 0.0])
			_check(lost > 0 and lost <= 35.0 + 0.01 * full, "a spark deals at most 35%% of the tick (%.1f of 100, after armor)" % lost)
	# a switch resets heat (Prism Lance has no retain unless a path gives it)
	var others := S.enemies.filter(func(e): return not e.dead and e != t.last_target)
	if others.size():
		var st := t.stacks
		g.fire(t, [others[0]])
		_check(t.stacks <= (floorf(st / 2) + 1 if t.retain else 1.0), "switching targets resets the heat (%.0f -> %.0f)" % [st, t.stacks])
	# turning and tilting follow the target
	_check(absf(m.yaw_node.rotation.y) > 0.05, "the turret turns to the target (%.2f)" % m.yaw_node.rotation.y)
	_check(not is_equal_approx(m.pitch_node.rotation.x, pitch0), "the gun tilts with the target's distance (%.3f -> %.3f)" % [pitch0, m.pitch_node.rotation.x])
	# pause: the beam and the model hold still
	await _frames(5)
	if b.lance_beams.has(t):
		bm = b.lance_beams[t]
		S.user_pause = true
		S.paused = true
		var bt: float = bm._t
		var ap0 := m.ap.current_animation_position
		await _frames(20)
		_check(is_equal_approx(bm._t, bt) and is_equal_approx(m.ap.current_animation_position, ap0), "paused: the beam and the clip hold still")
		S.paused = false
		S.user_pause = false
	# stun: the beam drops and the model goes back to idle
	await _frames(10)
	t.stun_t = 1.0
	await _frames(8)
	_check(not b.lance_beams.has(t) and t.lance_state == "", "stunned: the beam drops")
	_check(m.ap.current_animation == "idle", "stunned: the model eases back to idle")
	var relock := false
	for i in 240:
		await get_tree().process_frame
		if t.lance_state != "" or g.in_range(t.x, t.y, g.t_range(t)).is_empty():
			relock = true
			break
	_check(relock, "after the stun it locks on again")
	# sell: the beam goes with the tower
	await _frames(30)
	var had := b.lance_beams.has(t)
	var beam_node = b.lance_beams.get(t)
	g.sell(t)
	await _frames(4)
	_check(not b.lance_beams.has(t), "sold: its beam goes (it had one: %s)" % had)
	await get_tree().create_timer(0.3).timeout
	_check(beam_node == null or not is_instance_valid(beam_node), "the faded beam is freed")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("4_board.png"))
	_done()


func _done() -> void:
	print("PRISM LANCE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
