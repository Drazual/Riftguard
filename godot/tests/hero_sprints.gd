## The authored hero sprints (art_src/heroes/_sprints): in the Test Room, each of Striker, Sniper, Wizard, Vanguard
## and Gale crossing open ground plays its own run at about 1x (its feet were planted for that speed), keeps running
## while attacking on the move (Striker and Sniper raise the gun in "runfire"), and drops back to the walk when slow.
## The Oracle keeps its hover. Saves a strip of frames of each sprint (and a GIF of them if PIL is around).
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/hero_sprints.tscn -- <out dir>
extends Node

var out := "user://hero_sprints"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _crop(name: String, at: Vector2, half: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var img := bi.get_region(r)
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join(name + ".png"))


## Walks the hero to x and back for `n` frames, counting the clip that plays (and its play rate while it runs).
## With `pts`, it goes from point to point instead (and round again).
func _cross(h: Hero, n: int, shots := "", pts := []) -> Dictionary:
	var g := main.game
	var res := {"states": {}, "rates": [], "atk": 0}
	if pts.is_empty():
		pts = [Vector2(h.x + 320 if h.x < 500 else h.x - 320, h.y), h.pos()]
	var at := 0
	var a0 := h.atk_at
	g.move_hero(pts[0].x, pts[0].y)
	for i in n:
		await get_tree().process_frame
		var v: Hero3D = main.board.hero_3d
		if v == null:
			continue
		if h.tx == null or Vector2(h.x - h.tx, h.y - h.ty).length() < 20:
			at = (at + 1) % pts.size()
			g.move_hero(pts[at].x, pts[at].y)
		res.states[v.state] = res.states.get(v.state, 0) + 1
		if v.state == "run" or v.state == "runfire":
			res.rates.append(absf(v.ap.speed_scale))
		if h.atk_at != a0:
			a0 = h.atk_at
			res.atk += 1
		if shots != "" and i < 40 and i % 2 == 0:
			await _crop("%s_%02d" % [shots, i / 2], Vector2(h.x, Board.SY(h.y) - 20), Vector2(60, 60))
	return res


## The median play rate (the per-frame ground speed is noisy under a slow test display, and turning round spikes it).
func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


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
	await _frames(3)
	main.ui.menus.start_test_room()
	await _frames(10)
	var g := main.game
	var S := g.S
	S.lives = 9999
	var walkfire := {"striker": true, "sniper": true}
	for k in ["striker", "sniper", "wizard", "vanguard", "gale", "oracle"]:
		if not DB.heroes.has(k):
			continue
		g.test_swap_hero(k, false)
		g.test_clear()
		await _frames(10)
		var h := S.hero
		h.x = 380.0
		h.y = 470.0
		h.tx = h.x
		h.ty = h.y
		await _frames(10)
		var v: Hero3D = main.board.hero_3d
		if v == null:
			_check(false, "%s has a 3D model" % k)
			continue
		var authored: bool = v.cfg.has("run_speed")
		print("%s: speed %d px/s, runs above %d px/s" % [k, roundi(h.speed), roundi(1.4 * v.walk_speed * v.tall / 1.8)])
		# open ground, nothing to shoot
		var r := await _cross(h, 90, k + "_run")
		print("%s: %s, run rate %.2f" % [k, r.states, _mean(r.rates)])
		if k == "oracle":
			_check(not authored and not r.states.has("run"), "the Oracle keeps its hover (%s)" % [r.states])
			continue
		_check(authored and v.anims.get("run", "") != "", "%s has its authored run" % k)
		_check(r.states.get("run", 0) > 40, "%s sprints across open ground (%s)" % [k, r.states])
		var m := _mean(r.rates)
		_check(absf(m - 1.0) < 0.05, "%s's sprint plays at about 1x (%.2f)" % [k, m])
		# attacking on the move: tough, still enemies along the way
		for j in 4:
			g.spawn("brute", S.map.path_len * (0.25 + j * 0.06))
		g.start_wave()
		for e: Enemy in S.enemies:
			e.speed = 0.0
			e.max = 1e7
			e.hp = 1e7
		# along the road, right past them (the Vanguard and Gale hit up close)
		var way := []
		for j in 7:
			way.append(g.pos_at(S.map.path_len * (0.2 + j * 0.05)) + Vector2(0, 18))
		var back := way.slice(0, 6)
		back.reverse()
		way.append_array(back)
		var p0: Vector2 = way.pop_back()
		h.x = p0.x
		h.y = p0.y
		h.tx = null
		h.ty = null
		# the Sniper has to stand still to aim (brace), so it never shoots on the move in a run: let it here to see runfire
		var brace := h.brace
		h.brace = 0.0
		await _frames(5)
		var f := await _cross(h, 150, "", way)
		h.brace = brace
		print("%s attacking on the move: %s, %d attacks" % [k, f.states, f.atk])
		if walkfire.has(k):
			_check(f.states.get("runfire", 0) > 20 and f.atk > 0, "%s shoots on the run with the gun raised (runfire %d, %d shots)" % [k, f.states.get("runfire", 0), f.atk])
			_check(_mean(f.rates) > 0.8 and _mean(f.rates) < 1.2, "  and the legs keep the sprint's pace (%.2f)" % _mean(f.rates))
		else:
			# (the Wizard's attacks are its spells, cast standing, so it only has to keep running here)
			_check(f.states.get("run", 0) > 100 and (f.atk > 0 or k == "wizard"), "%s keeps running while attacking (run %d, %d attacks)" % [k, f.states.get("run", 0), f.atk])
		g.test_clear()
		await _frames(5)
		# slowed: back to the walk
		# the way the game slows a hero (a curse's drag)
		h.drag = 0.75
		h.drag_t = 999.0
		var s := await _cross(h, 60)
		h.drag = 0.0
		h.drag_t = 0.0
		# Striker, Sniper and Wizard walk slowly (they run above ~20-30 px/s), so only a very hard slow walks them
		var slow_px := h.speed * 0.25
		var walks := 1.4 * v.walk_speed * v.tall / 1.8 > slow_px
		if walks:
			_check(s.states.get("walk", 0) > 30 and s.states.get("run", 0) < 10, "%s walks when slowed (%s)" % [k, s.states])
		else:
			print("     %s at %d px/s still runs (%s)" % [k, roundi(slow_px), s.states])
	_done()


func _done() -> void:
	print("HERO SPRINTS DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
