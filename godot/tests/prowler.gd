## Grunts drawn live from the rigged Rift Prowler model, in a real run on Rift Plaza (needs a display):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/prowler.tscn -- <out dir>
## Lines up Grunts in each state (running, slowed, stunned, frozen, knocked back, held up by the hero) and checks each
## plays its clip (a slowed one runs that much slower, frosted over), then kills one and checks it plays its death,
## sinks and is freed. Saves close-ups.
extends Node

var out := "user://prowler"
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


func _grunt(d: float) -> Enemy:
	g.spawn("grunt", d)
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
	get_tree().create_timer(120).timeout.connect(func(): print("PROWLER TIMEOUT"); get_tree().quit(1))
	seed(3)
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
	var walker := _grunt(L * 0.30)
	var slowed := _grunt(L * 0.36)
	var stunned := _grunt(L * 0.42)
	var frozen := _grunt(L * 0.48)
	var pushed := _grunt(L * 0.54)
	var hit := _grunt(L * 0.60)
	await _wait(0.3)
	_check(main.board.crowd.view_of(walker) != null, "a Grunt is drawn from its model")
	_check(_clip(walker) == "walk", "running (%s)" % _clip(walker))
	await _shot("0_walk", walker.pos())
	g.slow_enemy(slowed, 0.5, 30)
	stunned.stun_t = 30
	frozen.rime_frz = 30
	frozen.speed = 0
	await _wait(0.4)
	var vs := main.board.crowd.view_of(slowed)
	var vw := main.board.crowd.view_of(walker)
	_check(_clip(slowed) == "walk" and absf(vs.ap.speed_scale / vs.dir_k - vw.ap.speed_scale / vw.dir_k * (1.0 - slowed.slow)) < 0.01, "slowed %d%%: its run is that much slower (%.2f vs %.2f)" % [int(slowed.slow * 100), vs.ap.speed_scale, vw.ap.speed_scale])
	_check(vs.frost > 0.5 and vw.frost == 0.0, "slowed: frosted over (%.2f), the other isn't" % vs.frost)
	_check(_clip(stunned) == "stun", "stunned (%s)" % _clip(stunned))
	_check(_clip(frozen) == "frozen", "frozen (%s)" % _clip(frozen))
	await _shot("1_slowed", slowed.pos())
	await _shot("2_stun", stunned.pos())
	await _shot("3_frozen", frozen.pos())
	pushed.push_t = 0.6
	pushed.push_spd = 80
	hit.hp = hit.max * 0.8
	await _wait(0.12)
	_check(_clip(pushed) == "knockback", "knocked back (%s)" % _clip(pushed))
	_check(_clip(hit) == "walk", "no flinch on a big hit (%s)" % _clip(hit))
	await _shot("4_knockback", pushed.pos())
	await _shot("5_hit", hit.pos())
	await _wait(0.8)
	# held up by the hero standing in its way: claws at it
	S.hero.x = g.pos_at(walker.d + 14).x
	S.hero.y = g.pos_at(walker.d + 14).y
	S.hero.tx = null
	await _wait(0.6)
	_check(_clip(walker) == "attack", "attacks the hero holding it up (%s)" % _clip(walker))
	var vw2 := main.board.crowd.view_of(walker)
	_check(vw2 != null and absf(angle_difference(vw2.yaw, vw2._face(main.board.P(S.hero.x, S.hero.y) - vw2.position))) < 0.3, "and faces the hero")
	await _shot("6_attack", walker.pos())
	S.hero.x = -500
	S.hero.y = -500
	# a wide shot of the road with all of them
	await _shot("7_road", g.pos_at(L * 0.45), 420, 200)
	# killed: plays its death, sinks and goes
	var v := main.board.crowd.view_of(hit)
	var at := hit.pos()
	hit.hp = 1
	g.damage(hit, 1e7)
	await _wait(0.5)
	_check(is_instance_valid(v) and v.state == "death", "dies with its death clip (%s)" % (v.state if is_instance_valid(v) else "freed"))
	await _shot("8_death", at)
	await _wait(0.7)
	await _shot("9_dead", at)
	await _wait(1.5)
	_check(not is_instance_valid(v), "then sinks away and is freed")
	print("PROWLER %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)
