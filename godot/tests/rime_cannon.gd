## The Rime Cannon merge model v2 (art_src/towers/merges/frost_plasma, cryo_cannon_*) in a real run: Frost Pylon and
## Plasma Cannon are maxed and merged. The turret aims; each shot charges an ice-plasma ball at the crown for 0.45 s,
## fires it at shell_speed onto the target's lead point, bursts (splash + slow), and leaves a frozen patch that slows
## and hurts for 1.6 s, then shatters for a last burst.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/rime_cannon.tscn -- <out dir>
extends Node

var out := "user://rime_cannon"
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
	main.ui.menus.start_run("gale", ["frost", "plasma", "tesla", "arcane"])
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
	probe.type = "frost+plasma"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/frost_plasma/cryo_cannon.glb"), "the merge loader finds cryo_cannon.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "Turret" and cfg.get("pitch") == "Turret/Gun" and is_equal_approx(float(cfg.get("aim", 0)), 0.06) and cfg.get("muzzle") == "Muzzle" and is_equal_approx(float(cfg.get("shot_time", 0)), 0.45) and int(cfg.get("wide", 0)) == 40, "tower.json: yaw Turret, pitch Turret/Gun, aim 0.06, Muzzle, shot_time 0.45, wide 40")
	var rec = DB.recipes.get("frost+plasma")
	if rec != null:
		_check(rec.name == "Rime Cannon", "it is called the Rime Cannon (%s)" % rec.name)
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["frost", "plasma"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	var fro: Tower = placed.frost
	var pla: Tower = placed.plasma
	_max(g, fro)
	_max(g, pla)
	await _frames(4)
	g.try_merge(pla, fro)
	await _frames(3)
	var rc: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "frost+plasma":
			rc = t
	_check(rc != null, "Frost Pylon + Plasma Cannon merge into the Rime Cannon")
	if rc == null:
		_done()
		return
	print("stats: dmg %.1f rate %.2f splash %.0f slow %.2f slow_dur %.2f brittle %.2f frostfire %.2f sig frost %s plasma %s" % [rc.dmg, rc.rate, rc.splash, rc.slow, rc.slow_dur, rc.brittle, rc.frostfire, S.sig.get("frost", false), S.sig.get("plasma", false)])
	_check(rc.cryo and not rc.lob and not rc.beam, "it fires the ice-plasma ball (cryo)")
	_check(rc.splash >= 50 and rc.slow >= 0.45, "splash %.0f, slow %.2f" % [rc.splash, rc.slow])
	var v = rc.get_meta("view") if rc.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(m.yaw_node != null and m.yaw_node.name == "Turret" and m.pitch_node != null and m.pitch_node.name == "Gun", "yaw Turret, pitch Gun")
	_check(is_equal_approx(m.pitch_node.rotation.x, 0.06), "the Gun rests at aim 0.06 (%.3f)" % m.pitch_node.rotation.x)
	_check(m.muzzle != null and m.muzzle.name == "Muzzle", "muzzle is the crown tip's Muzzle")
	var kc := g.merge_clip_k(rc)
	_check(is_equal_approx(g.merge_lead(rc), 0.45 * kc), "the game holds the shot to the clip's shot moment (%.2f s; the clip plays %.2fx to fit a %.2f s rate)" % [g.merge_lead(rc), 1.0 / kc, rc.rate])
	var at := Vector2(rc.x, Board.SY(rc.y))
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("1_idle", at, Vector2(90, 100), 3)
	# a real wave
	S.hero.x = rc.x - 160
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
	var st0 = rc.shot_at
	for i in 900:
		await get_tree().process_frame
		if rc.shot_at != st0 and m.ap.current_animation == "fire":
			fired = true
			break
	_check(fired, "fire starts when it picks a target in a wave")
	var orb: Node3D = m.model.find_child("IceOrb", true, false)
	var t0 := S.time
	var o_early := -1.0
	var o_late := -1.0
	var ball_t := -1.0
	var burst_t := -1.0
	var ball: Dictionary = {}
	var no_line := true
	var crop2 := false
	for i in 400:
		await get_tree().process_frame
		var el := S.time - t0
		var cp: float = m.ap.current_animation_position if m.ap.current_animation == "fire" else -1.0
		if orb and cp > 0.04 and cp < 0.12 and o_early < 0:
			o_early = orb.scale.x
		if orb and cp > 0.34 and cp < 0.45 and o_late < 0:
			o_late = orb.scale.x
			await _crop("2_charging", at, Vector2(90, 100), 3)
		for f in S.fx:
			if f.get("tw") != rc:
				continue
			if f.k == "line":
				no_line = false
			if f.k == "cryo_ball" and ball_t < 0:
				ball_t = el
				ball = f
			if f.k == "cryo_burst" and burst_t < 0 and ball_t >= 0:
				burst_t = el
		if ball_t >= 0 and burst_t < 0 and not crop2 and el > ball_t + 0.04:
			crop2 = true
			_check(b.cryo_fx != null and b.cryo_fx.balls.size() > 0, "the board draws the ball in flight")
		if burst_t >= 0 and el > burst_t + 0.1:
			break
	_check(absf(m.yaw_node.rotation.y) > 0.05, "the turret turns to the target (%.2f)" % m.yaw_node.rotation.y)
	_check(o_early >= 0 and o_late > o_early * 1.5, "the ball charges at the crown (%.2f -> %.2f)" % [o_early, o_late])
	_check(ball_t >= 0.45 * kc - 0.05 and ball_t <= 0.45 * kc + 0.12, "the ball leaves at the shot moment (%.2f s after fire)" % ball_t)
	var fl: float = ball.get("flight", 0.0)
	_check(fl > 0.05 and fl < 0.5 and absf((burst_t - ball_t) - fl) < 0.1, "it bursts when it lands (flight %.2f s, burst %.2f s later)" % [fl, burst_t - ball_t])
	_check(no_line, "no instant shot line")
	# a set-up shot: a clump on the road
	S.towers.erase(rc)
	await _frames(30)
	S.spawn_q.clear()
	for e in S.enemies:
		e.dead = true
	S.enemies.clear()
	S.zones.clear()
	await _frames(2)
	var D := S.map.path_len * 0.4
	var offs := [0.0, 10.0, -12.0, rc.splash + 60.0]
	for o in offs:
		g.spawn("grunt", D + o)
	var c := g.pos_at(D)
	var cpx := Vector2(c.x, Board.SY(c.y))
	var es: Array = S.enemies.slice(S.enemies.size() - offs.size())
	for i in es.size():
		var p := g.pos_at(D + offs[i])
		es[i].x = p.x
		es[i].y = p.y
		es[i].speed = 0.0
		es[i].set_meta("tough", true)
		es[i].max = 1e6
		es[i].hp = 1e6
	S.towers.append(rc)
	rc.stun_t = 30.0
	# just the ball, the burst and the ice (path extras would muddy the numbers)
	for k in ["cluster", "pierce", "echo", "gravity", "brittle", "frostfire", "shatter", "execute", "burn", "mark", "hex"]:
		rc.set(k, 0)
	var dd := 100.0
	var mid: Enemy = es[0]
	var far: Enemy = es[3]
	var hp_mid := mid.hp
	var hp_far := far.hp
	var tb := S.time
	g.cryo_ball(rc, mid, dd, rc.splash, false, false, false, false, 0.0)
	var burst_at := -1.0
	var zone_z = null
	var patch_ok := false
	var hp_after_burst := 0.0
	var last := mid.hp
	var jumps := []
	var shot3 := false
	while S.time - tb < 3.0:
		await get_tree().process_frame
		var drop := last - mid.hp
		last = mid.hp
		if drop > 5.0:
			jumps.append([S.time - tb, drop])
		if burst_at < 0:
			for z in S.zones:
				if z.get("src") == rc and z.get("end_dmg", 0.0) > 0:
					zone_z = z
					burst_at = S.time
					hp_after_burst = mid.hp
			continue
		if not shot3 and S.time - burst_at > 0.5:
			shot3 = true
			var here := 0
			for q in (b.cryo_fx.patches if b.cryo_fx else []):
				if (q.p as Vector2).distance_to(cpx) < 2.0:
					here += 1
			patch_ok = here == 1
			await _crop("3_ice_patch", Vector2(c.x, Board.SY(c.y)), Vector2(110, 80), 3)
	print("jumps (time, hp drop): ", jumps)
	var burst_dmg := hp_mid - hp_after_burst
	var total := hp_mid - mid.hp
	var shatter_dmg := 0.0
	for j in jumps:
		if j[0] > 1.0:
			shatter_dmg = maxf(shatter_dmg, j[1])
	var ice := total - burst_dmg - shatter_dmg
	print("burst %.1f, ice %.1f, shatter %.1f, total %.1f; far lost %.1f; slow %.2f" % [burst_dmg, ice, shatter_dmg, total, hp_far - far.hp, mid.slow])
	_check(burst_at > 0 and absf(burst_dmg - dd) < 1.0, "the burst hits for the full shot (%.1f of %.0f)" % [burst_dmg, dd])
	_check(zone_z != null and is_equal_approx(zone_z.r, rc.splash * 0.9) and is_equal_approx(zone_z.T, 1.6) and is_equal_approx(zone_z.slow, rc.slow) and zone_z.quiet, "a frozen patch: r %.0f, 1.6 s, slow %.2f, drawn by the FX" % [rc.splash * 0.9, rc.slow])
	_check(ice > dd * 0.2 * 1.6 * 0.85 and ice < dd * 0.2 * 1.6 * 1.15, "the ice hurts 20%%/s of the shot for 1.6 s (%.1f, want ~%.1f)" % [ice, dd * 0.32])
	_check(absf(shatter_dmg - dd * 0.25) < 2.0, "it shatters for 25%% of the shot at the end (%.1f)" % shatter_dmg)
	_check(hp_far == far.hp, "an enemy outside the burst and the patch is untouched")
	_check(patch_ok, "the board draws its ice patch where it landed")
	var left := 0
	for q in b.cryo_fx.patches:
		if (q.p as Vector2).distance_to(cpx) < 2.0:
			left += 1
	_check(left == 0, "the patch is gone after it shatters")
	# the slow: a fresh burst on a clump slows it
	mid.slow = 0.0
	mid.slow_t = 0.0
	g.cryo_ball(rc, mid, dd, rc.splash, false, false, false, false, 0.0)
	var t2 := S.time
	var landed := false
	while S.time - t2 < 2.0 and not landed:
		await get_tree().process_frame
		landed = S.zones.any(func(z): return z.get("src") == rc)
	await _frames(3)
	_check(mid.slow >= rc.slow - 0.01, "the burst and the ice slow it (%.2f)" % mid.slow)
	# the zone goes early (a reset): the FX shatters its patch at once
	var n0: int = b.cryo_fx.patches.size()
	S.zones.clear()
	await _frames(3)
	var broke: bool = n0 > 0 and (b.cryo_fx.patches.is_empty() or b.cryo_fx.patches.all(func(p): return p.brk >= 0))
	_check(broke, "a patch whose zone is removed early shatters (%d patches)" % n0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("4_board.png"))
	_done()


func _done() -> void:
	print("RIME CANNON DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
