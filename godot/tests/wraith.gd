## Wraiths drawn live from their rigged model, in a real run on Rift Plaza (needs a display):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/wraith.tscn -- <out dir>
## Checks the Wraith gets a model view with every clip enemy.json names, that move, idle and slowed loop and death
## doesn't, that it plays spawn as it appears, moves, flinches when hurt, plays its own slowed clip when slowed, shrugs
## off stuns, passes the hero without being held up, and that a killed one plays its death and is freed. Saves close-ups.
extends Node

var out := "user://wraith"
var fails := 0
var main: Main
var g: Game


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(name: String, at: Vector2, w := 120, h := 90) -> void:
	await RenderingServer.frame_post_draw
	var b: Board = main.board
	var bi := b.viewport.get_texture().get_image()
	var p := b.units.get_global_transform_with_canvas() * Vector2(at.x, b.SY(at.y))
	var r := Rect2i(int(p.x) - w / 2, int(p.y) - h + 20, w, h).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var c := bi.get_region(r)
	c.resize(c.get_width() * 4, c.get_height() * 4, Image.INTERPOLATE_NEAREST)
	c.save_png(out.path_join(name + ".png"))


func _wait(secs: float) -> void:
	var until := g.S.time + secs
	while g.S.time < until:
		await get_tree().process_frame


func _wraith(d: float) -> Enemy:
	g.spawn("wraith", d)
	var e: Enemy = g.S.enemies[g.S.enemies.size() - 1]
	e.hp = 1e6
	e.max = 1e6
	return e


func _clip(e: Enemy) -> String:
	var v := main.board.crowd.view_of(e)
	return v.state if v else "(no model)"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("WRAITH TIMEOUT"); get_tree().quit(1))
	seed(5)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("plaza")
	main.ui.menus.start_run("striker", [])
	for i in 10:
		await get_tree().process_frame
	g = main.game
	var S := g.S
	S.lives = 999
	S.hero.x = -500 # out of the way
	S.hero.y = -500
	g.start_wave()
	S.spawn_q = []
	for e in S.enemies:
		e.dead = true
	var L: float = S.map.path_len
	var a := _wraith(L * 0.30)
	var b := _wraith(L * 0.45)
	await get_tree().process_frame
	await get_tree().process_frame
	var v := main.board.crowd.view_of(a)
	_check(v != null, "a Wraith is drawn from its model")
	if v == null:
		get_tree().quit(1)
		return
	var missing := []
	for s in v.anims:
		if not v.ap.has_animation(v.anims[s]):
			missing.append(s)
	_check(missing.is_empty() and v.anims.size() == 10, "every clip enemy.json names is in the model (%d, missing %s)" % [v.anims.size(), missing])
	for s in ["walk", "idle", "slowed"]:
		_check(v.ap.get_animation(v.anims[s]).loop_mode == Animation.LOOP_LINEAR, "%s (%s) loops" % [s, v.anims[s]])
	for s in ["death", "hit", "spawn"]:
		_check(v.ap.get_animation(v.anims[s]).loop_mode == Animation.LOOP_NONE, "%s doesn't loop" % s)
	_check(_clip(a) == "spawn", "plays spawn as it appears (%s)" % _clip(a))
	await _wait(0.3)
	await _shot("0_spawn", a.pos())
	await _wait(1.0)
	_check(_clip(a) == "walk", "then moves (%s)" % _clip(a))
	await _shot("1_move", a.pos())
	# hurt while just moving: a short flinch, then it moves on
	a.hp -= 10
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_clip(a) == "hit", "flinches when hurt while moving (%s)" % _clip(a))
	await _wait(0.6)
	_check(_clip(a) == "walk", "then moves on (%s)" % _clip(a))
	# slowed: its own slowed clip, not slowed further, frosted
	g.slow_enemy(b, 0.5, 30)
	await _wait(0.5)
	_check(b.slow > 0.4, "slows work on it (%.2f)" % b.slow)
	var vb := main.board.crowd.view_of(b)
	_check(_clip(b) == "slowed", "slowed: plays its slowed clip (%s)" % _clip(b))
	var want := clampf(b.speed / float(vb.cfg.walk_speed), 0.4, 2.5) * S.speed
	_check(absf(vb.ap.speed_scale - want) < 0.01, "at its normal pace, not slowed again (%.2f, want %.2f)" % [vb.ap.speed_scale, want])
	_check(vb.frost > 0.5, "and frosted (%.2f)" % vb.frost)
	await _shot("2_slowed", b.pos())
	b.slow = 0
	b.slow_t = 0
	await _wait(0.4)
	_check(_clip(b) == "walk", "back to moving when the slow ends (%s)" % _clip(b))
	# stuns slide off: it keeps moving and never plays its stun clip
	var d0 := b.d
	for i in 20:
		b.stun_t = 5
		await get_tree().process_frame
	_check(b.d > d0 + 5 and _clip(b) == "walk", "can't be stunned: keeps moving (%.0f further, %s)" % [b.d - d0, _clip(b)])
	# the hero standing in its way doesn't hold it up
	S.hero.x = g.pos_at(b.d + 10).x
	S.hero.y = g.pos_at(b.d + 10).y
	S.hero.tx = null
	var d1 := b.d
	var held := false
	for i in 20:
		await get_tree().process_frame
		held = held or b.blocked
	_check(not held and b.d > d1 + 5 and _clip(b) == "walk", "the hero can't hold it up (%.0f further, %s)" % [b.d - d1, _clip(b)])
	await _shot("3_past_hero", b.pos())
	S.hero.x = -500
	S.hero.y = -500
	# killed: plays its death, holds, sinks and goes
	var at := a.pos()
	a.hp = 1
	g.damage(a, 1e7)
	await _wait(0.5)
	_check(is_instance_valid(v) and v.state == "death", "dies with its death clip (%s)" % (v.state if is_instance_valid(v) else "freed"))
	await _shot("4_death", at)
	var length := v.ap.get_animation(v.anims.death).length
	await _wait(length + Enemy3D.DEATH_HOLD + Enemy3D.SINK + 0.4)
	_check(not is_instance_valid(v), "then sinks away and is freed")
	print("WRAITH %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)
