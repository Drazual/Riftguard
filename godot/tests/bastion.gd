## Bastions (formerly the Juggernaut) drawn live from their rigged model, in a real run on Rift Plaza (needs a display):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/bastion.tscn -- <out dir>
## Checks the Bastion gets a model view with every clip enemy.json names, that move, idle and slowed loop and death
## doesn't, that it plays spawn as it appears, moves, flinches when hurt, plays its own slowed clip paced to the slow
## (forced: Bastions can't be slowed in play), is stunned, and that a killed one plays its death and is freed.
extends Node

var out := "user://bastion"
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


func _bastion(d: float) -> Enemy:
	g.spawn("bastion", d)
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
	get_tree().create_timer(120).timeout.connect(func(): print("BASTION TIMEOUT"); get_tree().quit(1))
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
	var a := _bastion(L * 0.30)
	var b := _bastion(L * 0.45)
	await get_tree().process_frame
	await get_tree().process_frame
	var v := main.board.crowd.view_of(a)
	_check(v != null, "a Bastion is drawn from its model")
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
	await _shot("0_spawn", a.pos(), 160, 120)
	await _wait(1.0)
	_check(_clip(a) == "walk", "then moves (%s)" % _clip(a))
	await _shot("1_move", a.pos(), 160, 120)
	# hurt while just moving: a short flinch, then it moves on
	a.hp -= 10
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_clip(a) == "hit", "flinches when hurt while moving (%s)" % _clip(a))
	await _wait(0.8)
	_check(_clip(a) == "walk", "then moves on (%s)" % _clip(a))
	# slowed (Bastions can't be slowed in play, so it's forced): its own slowed clip, paced to the slow it was made for
	b.slow = 0.35
	b.slow_t = 30
	await _wait(0.6)
	var vb := main.board.crowd.view_of(b)
	_check(_clip(b) == "slowed", "slowed: plays its slowed clip (%s)" % _clip(b))
	var want := clampf(b.speed / float(vb.cfg.walk_speed), 0.4, 2.5) * vb.dir_k * S.speed
	_check(absf(vb.ap.speed_scale - want) < 0.01, "at a 35%% slow (what it was made for) its steps keep pace (%.2f, want %.2f)" % [vb.ap.speed_scale, want])
	b.slow = 0.6
	await _wait(0.1)
	_check(absf(vb.ap.speed_scale - want * 0.4 / 0.65) < 0.01, "a stronger slow slows the steps to match (%.2f)" % vb.ap.speed_scale)
	_check(vb.frost > 0.4, "and frosted (%.2f)" % vb.frost)
	await _shot("2_slowed", b.pos(), 160, 120)
	b.slow = 0
	b.slow_t = 0
	await _wait(0.5)
	_check(_clip(b) == "walk", "back to moving when the slow ends (%s)" % _clip(b))
	b.stun_t = 30
	await _wait(0.4)
	_check(_clip(b) == "stun", "stunned (%s)" % _clip(b))
	await _shot("3_stun", b.pos(), 160, 120)
	# killed: plays its death, holds, sinks and goes
	var at := a.pos()
	a.hp = 1
	g.damage(a, 1e7)
	await _wait(0.5)
	_check(is_instance_valid(v) and v.state == "death", "dies with its death clip (%s)" % (v.state if is_instance_valid(v) else "freed"))
	await _shot("4_death", at, 160, 120)
	var length := v.ap.get_animation(v.anims.death).length
	await _wait(length + Enemy3D.DEATH_HOLD + Enemy3D.SINK + 0.4)
	_check(not is_instance_valid(v), "then sinks away and is freed")
	print("BASTION %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)
