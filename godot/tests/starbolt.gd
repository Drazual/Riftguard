## The Starbolt merge (art_src/towers/merges/arcane_plasma) in a real run: Arcane Bolt and Plasma Cannon are maxed and
## merged. It fires fast star bolts that burst on impact, and every 4th shot is a supernova (a bigger, harder blast
## that plays the supernova clip and leaves a faint star field). The star's heat glow builds under sustained fire.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/starbolt.tscn -- <out dir>
extends Node

var out := "user://starbolt"
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


func _unblock(g: Game) -> void:
	for i in 30:
		main.ui.close_modal()
		if g.S.pending_boon != "":
			g.take_boon()
		if g.S.paused and g.wave_opts.size() > 0:
			g.choose_mode(0)
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(400).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane", "plasma", "frost", "tesla"])
	await _frames(10)
	var g := main.game
	var S := g.S
	S.gold = 999999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	MergeArt.clear_cache()
	var probe := Tower.new()
	probe.hybrid = true
	probe.type = "arcane+plasma"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/arcane_plasma/starbolt.glb"), "the merge loader finds starbolt.glb (%s)" % spec.get("glb", ""))
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["arcane", "plasma"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	_max(g, placed.arcane)
	_max(g, placed.plasma)
	await _frames(4)
	g.try_merge(placed.plasma, placed.arcane)
	await _frames(3)
	var sb: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "arcane+plasma":
			sb = t
	_check(sb != null and sb.star, "Arcane Bolt + Plasma Cannon merge into the Starbolt")
	if sb == null:
		_done()
		return
	print("stats: dmg %.1f rate %.2f range %.0f splash %.0f" % [sb.dmg, sb.rate, sb.range, sb.splash])
	var v = sb.get_meta("view") if sb.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	var at := Vector2(sb.x, Board.SY(sb.y))
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("1_idle", at, Vector2(80, 100), 3)
	# a real wave, with tough enemies so it keeps shooting
	S.hero.x = sb.x - 160
	get_tree().process_frame.connect(func():
		for e in S.enemies:
			if not e.has_meta("tough"):
				e.set_meta("tough", true)
				e.max *= 30.0
				e.hp = e.max)
	await _unblock(g)
	g.start_wave()
	var shots := 0
	var novas := 0
	var nova_shots := []
	var bolts := 0
	var nova_bolts := 0
	var bursts := 0
	var nova_bursts := 0
	var nova_clip := false
	var nova_zone := false
	var st0 = sb.shot_at
	var heat_max := 0.0
	var heat_n: Node3D = m.model.find_child("HeatGlow", true, false)
	var crop_b := false
	var crop_n := false
	for i in 900:
		await get_tree().process_frame
		if sb.shot_at != st0:
			st0 = sb.shot_at
			shots += 1
			if sb.nova_at == sb.shot_at:
				novas += 1
				nova_shots.append(sb.star_n)
		if m.ap.current_animation == "supernova":
			nova_clip = true
		for f in S.fx:
			if f.get("tw") != sb or f.get("_seen", false):
				continue
			if f.k == "star_bolt":
				f._seen = true
				bolts += 1
				if f.nova:
					nova_bolts += 1
				if not crop_b and bolts >= 2:
					crop_b = true
					await _crop("2_bolt", at + Vector2(-40, 0), Vector2(170, 120), 2)
			elif f.k == "star_burst":
				f._seen = true
				bursts += 1
				if f.nova:
					nova_bursts += 1
					if not crop_n:
						crop_n = true
						await _frames(6)
						await _crop("3_supernova", Vector2(f.x, Board.SY(f.y)), Vector2(130, 90), 3)
		if S.zones.any(func(z): return z.get("src") == sb):
			nova_zone = true
		if heat_n:
			heat_max = maxf(heat_max, heat_n.scale.x)
		if novas >= 2 and nova_bursts >= 1 and heat_max > 0.2 and crop_n:
			break
	print("shots %d, novas %d at %s, bolts %d (%d nova), bursts %d (%d nova)" % [shots, novas, nova_shots, bolts, nova_bolts, bursts, nova_bursts])
	_check(bolts > 0 and bursts > 0, "it fires star bolts that burst where they land (%d bolts, %d bursts)" % [bolts, bursts])
	_check(novas > 0 and nova_shots.all(func(n): return n % 4 == 0), "every 4th shot is a supernova (%s)" % [nova_shots])
	_check(nova_bolts > 0 and nova_bursts > 0, "a supernova shot sends a nova bolt and a nova burst")
	_check(nova_clip, "the tower plays its supernova clip for a supernova")
	_check(nova_zone, "a supernova leaves its faint star field")
	_check(heat_max > 0.2, "the star's glow builds under sustained fire (%.2f)" % heat_max)
	# a set-up shot: one still enemy, normal then nova damage
	sb.stun_t = 999.0
	S.spawn_q.clear()
	for e in S.enemies:
		e.dead = true
	S.enemies.clear()
	S.zones.clear()
	await _frames(20)
	var D := S.map.path_len * 0.4
	g.spawn("grunt", D)
	var A: Enemy = S.enemies[S.enemies.size() - 1]
	var p := g.pos_at(D)
	A.x = p.x
	A.y = p.y
	A.speed = 0.0
	A.set_meta("tough", true)
	A.max = 1e6
	A.hp = 1e6
	A.armor = 0.0
	for k in ["cluster", "pierce", "echo", "gravity", "brittle", "frostfire", "shatter", "execute", "burn", "mark", "hex", "surge", "overload", "orbital", "freeze", "nova", "chain", "prism", "death_blast", "ramp", "crit"]:
		if k in sb:
			sb.set(k, 0)
	# the supernova's star field is left out of the hit: it is cleared every frame
	var waitg := func(s: float):
		var t0 := S.time
		while S.time - t0 < s:
			await get_tree().process_frame
			S.zones = S.zones.filter(func(z): return z.get("src") != sb)
	sb.star_n = 0
	var hp0 := A.hp
	g.star_bolt(sb, A, 100.0, sb.splash, false, false, false, false, 0.0, false)
	await waitg.call(0.8)
	var plain := hp0 - A.hp
	hp0 = A.hp
	g.star_bolt(sb, A, 100.0, sb.splash, false, false, false, false, 0.0, true)
	await waitg.call(0.8)
	var big := hp0 - A.hp
	print("100 dmg bolt: plain %.1f, nova %.1f" % [plain, big])
	_check(plain > 0 and absf(big / plain - 1.4) < 0.08, "a supernova hits 1.4x as hard (%.2fx)" % (big / maxf(0.01, plain)))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("4_board.png"))
	_done()


func _done() -> void:
	print("STARBOLT DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
