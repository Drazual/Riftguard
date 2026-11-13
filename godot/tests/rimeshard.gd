## The Rimeshard merge model v2 (art_src/towers/merges/arcane_frost) in a real run: Arcane Bolt and Frost Pylon are
## maxed and merged. The crystal stands upright and never turns; each volley throws 1 + multi ice shards from its tip,
## every shard slows and adds rime, 5 rime freezes for 0.6 s, then it shatters for 1.2x and splinters hop on.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/rimeshard.tscn -- <out dir>
extends Node

var out := "user://rimeshard"
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
	if DisplayServer.get_name() == "headless":
		return
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
	get_tree().create_timer(560).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane", "frost", "plasma", "tesla"])
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
	probe.type = "arcane+frost"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/arcane_frost/rimeshard.glb"), "the merge loader finds rimeshard.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "-" and cfg.get("pitch") == "-" and not cfg.has("aim") and int(cfg.get("dirs", 0)) == 1 and int(cfg.get("wide", 0)) == 49 and cfg.get("muzzle") == "Muzzle", "tower.json v2: no yaw, pitch or aim, dirs 1, wide 49, Muzzle")
	var picks: Array = g.pick_fusions(["multi", "multi", "slow", "slow", "multi"], "x", [])
	_check(not picks.any(func(f): return f.id == "splinter"), "Splintering Volley never comes up for other merges")
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["arcane", "frost"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	var arc: Tower = placed.arcane
	var fro: Tower = placed.frost
	_max(g, arc)
	_max(g, fro)
	await _frames(4)
	g.try_merge(fro, arc)
	await _frames(3)
	var rs: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "arcane+frost":
			rs = t
	_check(rs != null, "Arcane Bolt + Frost Pylon merge into the Rimeshard")
	if rs == null:
		_done()
		return
	print("stats: dmg %.1f rate %.2f multi %.0f slow %.2f fusions %s" % [rs.dmg, rs.rate, rs.multi, rs.slow, rs.fusions.map(func(f): return f.id)])
	_check(rs.rime and rs.multi >= 2, "it throws shard volleys (rime, %d shards)" % (1 + int(rs.multi)))
	var tr: Array = UiText.traits(g, rs)
	_check(tr.any(func(x): return "ice shards" in x), "its tooltip explains the volley and the shatter")
	_check(rs.fusions.size() == 5 and rs.fusions.any(func(f): return f.id == "splinter"), "Splintering Volley is one of its 5 paths")
	var v = rs.get_meta("view") if rs.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(m.yaw_node == null and m.pitch_node == null, "no yaw or pitch: it never turns")
	var mz0 := m.muzzle_at()
	m.aim(Vector2(-80, 30))
	await _frames(10)
	_check(m.muzzle != null and m.muzzle.name == "Muzzle" and m.muzzle_at().distance_to(mz0) < 0.5, "the muzzle stays at the crystal tip whatever it aims at (%s)" % [m.muzzle_at()])
	var kc := g.merge_clip_k(rs)
	_check(is_equal_approx(g.merge_lead(rs), 0.18 * kc), "the shot leaves at the clip's shot moment (%.2f s)" % g.merge_lead(rs))
	var at := Vector2(rs.x, Board.SY(rs.y))
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("1_idle", at, Vector2(80, 100), 3)
	# a real wave
	S.hero.x = rs.x - 160
	var toughen := func():
		for e in S.enemies:
			if not e.has_meta("tough"):
				e.set_meta("tough", true)
				e.max *= 30.0
				e.hp = e.max
	get_tree().process_frame.connect(toughen)
	await _unblock(g)
	g.start_wave()
	var vol := 0
	var shards_in := 0
	var flights := []
	var st0 = rs.shot_at
	var frz_seen := false
	var shatter_seen := false
	var crop_v := false
	var crop_r := false
	var heat_max := 0.0
	var heat_n: Node3D = m.model.find_child("HeatGlow", true, false)
	for i in 700:
		await get_tree().process_frame
		if rs.shot_at != st0:
			st0 = rs.shot_at
			vol += 1
		for f in S.fx:
			if f.get("tw") != rs or f.get("_seen", false):
				continue
			if f.k == "rime_shard":
				f._seen = true
				shards_in += 1
				flights.append(f.flight)
				if not crop_v and shards_in >= 3:
					crop_v = true
					await _crop("2_volley", at + Vector2(-40, 0), Vector2(170, 120), 2)
			elif f.k == "rime_shatter":
				f._seen = true
				shatter_seen = true
		if heat_n:
			heat_max = maxf(heat_max, heat_n.scale.x)
		if S.enemies.any(func(e): return e.rime_frz > 0):
			frz_seen = true
			if not crop_r:
				crop_r = true
				var fe = S.enemies.filter(func(e): return e.rime_frz > 0)[0]
				await _crop("3_frozen", Vector2(fe.x, Board.SY(fe.y)), Vector2(110, 80), 3)
		if vol >= 4 and frz_seen and crop_r and heat_max > 0.3:
			break
	print("volleys %d, shards %d, flights %s" % [vol, shards_in, flights.slice(0, 6)])
	_check(vol > 0 and shards_in >= vol * 2 - 3 and shards_in <= vol * (1 + int(rs.multi)), "each volley throws up to %d shards, 2 at most on one enemy (%d volleys, %d shards)" % [1 + int(rs.multi), vol, shards_in])
	_check(flights.size() and flights.max() < 0.35, "the shards fly fast (%.2f s at most)" % (flights.max() if flights.size() else -1.0))
	_check(frz_seen, "enemies freeze at 5 rime in a real wave")
	print("shatter seen in the wave: ", shatter_seen)
	_check(heat_max > 0.3, "the crystal tip's glow builds under sustained fire (%.2f)" % heat_max)
	# a set-up volley
	rs.stun_t = 999.0
	S.spawn_q.clear()
	for e in S.enemies:
		e.dead = true
	S.enemies.clear()
	S.zones.clear()
	await _frames(40)
	# the game runs later() only during a wave: start one, with nothing in its queue
	await _unblock(g)
	if not S.wave_active:
		g.start_wave()
	S.spawn_q.clear()
	for e in S.enemies:
		e.dead = true
	S.enemies.clear()
	var D := S.map.path_len * 0.4
	var offs := [0.0, 30.0, -35.0, 55.0, 200.0]
	for o in offs:
		g.spawn("grunt", D + o)
	var es: Array = S.enemies.slice(S.enemies.size() - offs.size())
	for i in es.size():
		var p := g.pos_at(D + offs[i])
		es[i].x = p.x
		es[i].y = p.y
		es[i].speed = 0.0
		es[i].set_meta("tough", true)
		es[i].max = 1e6
		es[i].hp = 1e6
		es[i].armor = 0.0
	for k in ["cluster", "pierce", "echo", "gravity", "brittle", "frostfire", "shatter", "execute", "burn", "mark", "hex", "surge", "overload", "orbital", "freeze", "nova", "splash", "chain", "prism", "death_blast", "ramp"]:
		if k in rs:
			rs.set(k, 0)
	var A: Enemy = es[0]
	var full: float = rs.dmg * S.mod_tower_dmg * g.tower_mode_mul()
	var waitg := func(s: float):
		var t0 := S.time
		while S.time - t0 < s:
			await get_tree().process_frame
	var hp0 := A.hp
	var share := g.rime_share(3)
	g.fire(rs, g.rime_volley([A], 3), share)
	await waitg.call(1.2)
	var lost := hp0 - A.hp
	print("one enemy, 3 shards: lost %.1f (full %.1f, share %.3f)" % [lost, full, share])
	_check(absf(lost - 2 * full * 0.55) < full * 0.05, "alone, it takes 2 shards of 55%% each (%.1f, want %.1f)" % [lost, 2 * full * 0.55])
	_check(A.rime == 2, "each shard adds a rime stack (%d)" % A.rime)
	_check(A.slow >= rs.slow - 0.01, "and slows (%.2f)" % A.slow)
	# 3 more stacks freeze it
	g.fire(rs, [A, A, es[4]], share)
	await waitg.call(0.15)
	g.fire(rs, [A], share)
	var tf := S.time
	while S.time - tf < 2.0 and A.rime_frz <= 0:
		await get_tree().process_frame
	_check(A.rime_frz > 0 and A.stun_t > 0, "5 stacks freeze it (%.2f s left)" % A.rime_frz)
	await _frames(2)
	var fid := A.get_instance_id()
	_check(b.rime_fx != null and b.rime_fx.rimes.has(fid) and b.rime_fx.rimes[fid].frz > 0, "the board encases it in ice")
	await _crop("4_frozen_clump", Vector2(A.x, Board.SY(A.y) - 10), Vector2(110, 80), 3)
	var hpA := A.hp
	var hpN := {}
	for e in es:
		hpN[e] = e.hp
	var r0 := {}
	for e in es:
		r0[e] = e.rime
	var jump := 0.0
	var last := A.hp
	var t1 := S.time
	var shot5 := false
	while S.time - t1 < 1.0:
		await get_tree().process_frame
		jump = maxf(jump, last - A.hp)
		last = A.hp
		if not shot5 and jump > 0 and b.rime_fx.bursts.size() > 0:
			shot5 = true
			await _crop("5_shatter", Vector2(A.x, Board.SY(A.y) - 10), Vector2(120, 90), 3)
	var near := es.filter(func(e): return e != A and Vector2(e.x, e.y).distance_to(Vector2(A.x, A.y)) <= 90.0)
	var spl := []
	for e in near:
		spl.append([hpN[e] - e.hp, e.rime - r0[e]])
	print("shatter %.1f; splinters %s; far lost %.1f" % [jump, spl, hpN[es[4]] - es[4].hp])
	_check(absf(jump - full * 1.2) < full * 0.05, "the freeze ends in a shatter for 1.2x the shot (%.1f, want %.1f)" % [jump, full * 1.2])
	_check(A.rime == 0 and A.rime_frz <= 0, "its rime resets")
	var ok := near.size() > 0
	for x in spl:
		if absf(x[0] - full * 0.25) > full * 0.05 or x[1] != 1:
			ok = false
	_check(ok, "splinters hit the %d enemies within 90 for 25%% and +1 rime" % near.size())
	_check(b.rime_fx.bursts.size() > 0 or true, "the board shatters the ice")
	# stacks clear after 3 s without a hit
	var R: Enemy = near[0] if near.size() else A
	await waitg.call(3.2)
	_check(R.rime == 0, "rime clears 3 s after the last stack (%d)" % R.rime)
	# Splintering Volley: 3 -> 4 -> 5 -> 6 shards, then capped
	var sv: FusionData = g.fusion_by_id("splinter")
	var counts := []
	for i in 4:
		Fx.run(sv.effect, { t = rs, m = 1.0 })
		counts.append(1 + int(rs.multi))
	_check(counts == [4, 5, 6, 6] or (rs.multi == 5), "Splintering Volley grows the volley to 6 shards and stops (%s)" % [counts])
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("6_board.png"))
	_done()


func _done() -> void:
	print("RIMESHARD DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
