## Gale's live 3D sword-and-shield model in a real run (needs a display for the model):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/gale.tscn -- <out dir>
## Checks the clips (its posed stance, run, sword slash and shield brace), the sword hit landing 0.3s into the swing, Whirlwind
## landing 0.5s into its shield_slam clip, Air Strike's slam 0.60s into air_strike (trail, blast, cancel), and armor.
extends Node

var out := "user://gale"
var fails := 0
var main: Main
var g: Game


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


## The whole board (for the beam, which crosses it).
func _board_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	main.board.viewport.get_texture().get_image().save_png(out.path_join(name + ".png"))


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var b: Board = main.board
	var bi := b.viewport.get_texture().get_image()
	var p := b.hero_3d.get_global_transform_with_canvas().origin
	var r := Rect2i(int(p.x) - 70, int(p.y) - 95, 140, 120).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var c := bi.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	c.save_png(out.path_join(name + ".png"))


func _wait(secs: float) -> void:
	var until := g.S.time + secs
	while g.S.time < until:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): print("GALE TIMEOUT"); get_tree().quit(1))
	seed(4)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.meta.abilities = Save.meta.get("abilities", {})
	Save.meta.abilities["gale"] = "main"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["plasma"])
	for i in 10:
		await get_tree().process_frame
	g = main.game
	var S := g.S
	var h := S.hero
	S.lives = 999
	var m := main.board.hero_3d
	_check(m != null and m.skel.get_bone_count() == 43, "Gale is drawn live from its 3D model (43 bones)")
	_check(m.anims.walk == "ext/run" and m.anims.fire == "ext/slash", "posed run, sword slash")
	_check(m.anims.idle == "ext/stance" and m.anims.block == "ext/brace", "posed stance and shield brace")
	_check(m.ap.current_animation == "ext/stance", "stands in its stance (%s)" % m.ap.current_animation)
	_check(is_equal_approx(h.armor, 60) and absf(h.armor_cut() - 0.375) < 0.001, "60 armor = 37.5%% less damage (%.0f)" % h.armor)
	await _shot("0_idle")
	var c0 := h.pos()
	g.move_hero(c0.x + 90, c0.y + 30)
	await _wait(0.3)
	_check(m.state == "walk" and m.ap.current_animation == "ext/run", "runs when moving (%s)" % m.ap.current_animation)
	await _shot("1_run")
	await _wait(1.0)
	g.start_wave()
	S.spawn_q = []
	g.spawn("brute", S.map.path_len * 0.3)
	var e: Enemy = S.enemies[S.enemies.size() - 1]
	await get_tree().process_frame
	e.speed = 0
	e.armor = 0
	e.hp = 5000
	e.max = 5000
	h.x = e.x - 30
	h.y = e.y
	h.tx = null
	await _wait(0.4)
	var shot0 := h.atk_at
	while h.atk_at == shot0:
		await get_tree().process_frame
	var hp0 := e.hp
	var t0 := h.atk_at
	await get_tree().process_frame
	_check(m.ap.current_animation == "ext/slash", "swings the sword (%s)" % m.ap.current_animation)
	await _wait(0.15)
	await _shot("2_attack")
	while S.time < t0 + 0.3:
		await get_tree().process_frame
	await get_tree().process_frame
	_check(hp0 - e.hp > 1, "the sword hit lands by 0.3s (%.0f)" % (hp0 - e.hp))
	# Whirlwind: lands 0.5s into shield_slam
	h.ab.t = 0
	var hp1 := e.hp
	g.use_ability()
	var cast_at := S.time
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.ap.current_animation == "shield_slam", "Whirlwind plays shield_slam (%s)" % m.ap.current_animation)
	_check(h.shield <= 0, "no Whirlwind shield before the release")
	await _wait(0.2)
	await _shot("3_whirl")
	while S.time < cast_at + 0.5:
		await get_tree().process_frame
	await get_tree().process_frame
	_check(h.shield > 0 and hp1 - e.hp >= 40, "Whirlwind lands at 0.5s (shield %.0f, hit %.0f)" % [h.shield, hp1 - e.hp])
	await _wait(1.0)
	# Air Strike: air_strike, slamming down 0.60s in: the trail is laid once from AirStrikePoint the way it was aimed,
	# to the screen edge, and locked; after the delay the whole trail blasts once (blast_triggered sets off the hit)
	h.ab = Ability.from_data(DB.heroes.gale.alt)
	_check(h.ab.name == "Air Strike" and is_equal_approx(h.ab.release, 0.6), "Air Strike releases at 0.60s")
	var b: Board = main.board
	_check(b.beam_layer != null and h.beam_3d and BeamLayer.can_strike(m), "Gale has the strike layer")
	_check(b._ability_clip(h) == "air_strike", "Air Strike plays the air_strike clip")
	# it needs no target: far from every enemy, aimed at the cursor, it still casts that way
	var at0 := Vector2(h.x, h.y)
	h.x = clampf(e.x + (380 if e.x < 480 else -380), 60, 900)
	h.y = clampf(e.y + 250, 60, 460)
	h.tx = null
	await _wait(0.3)
	var lone := e.pos().distance_to(h.pos())
	var side := -1.0 if h.x > 480 else 1.0
	S.pointer = h.pos() + Vector2(120 * side, 0)
	h.ab.t = 0
	var ab0 := h.ab_at
	g.use_ability()
	_check(h.ab_at != ab0 and h.ab.t > 0, "casts with no enemy in reach (%.0f away)" % lone)
	_check(h.stream_dir.distance_to(Vector2(side, 0)) < 0.01, "aimed at the cursor (%s)" % h.stream_dir)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.ap.current_animation == "air_strike", "Air Strike plays air_strike (%s)" % m.ap.current_animation)
	# (by the clip's own time: under a slow renderer the clip runs ahead of the game's capped steps, so it lays the
	# trail on the first frame at or past 0.60s)
	var n0: int = b.beam_layer.strikes
	var prev := 0.0
	var step := 0.0
	for i in 600:
		if b.beam_layer.strikes > n0:
			break
		step = maxf(step, m.ap.current_animation_position - prev)
		prev = m.ap.current_animation_position
		await get_tree().process_frame
	var at: float = b.beam_layer.strike_clip
	_check(b.beam_layer.strikes == n0 + 1 and at >= 0.6 and at < 0.6 + maxf(step, 0.05) + 0.01,
		"the slam lets go once, at the clip's 0.60s release (%.2fs, frames %.2fs apart)" % [at, step])
	var fx: GaleAirStrike = b.beam_layer.strike
	_check(fx != null, "the trail is laid")
	var sp: Node3D = b.beam_layer.strike_point
	_check(fx != null and b.beam_layer.strike_from.distance_to(sp.global_position) < 0.05, "it leaves from AirStrikePoint")
	var aim0 := fx.global_basis.z if fx else Vector3.ZERO
	var pos0 := fx.global_position if fx else Vector3.ZERO
	var tip := b.beam_layer.strike_from + aim0 * b.beam_layer.strike_len
	var on := b.beam_layer.cam.unproject_position(tip) / Vector2(b.beam_layer.cam.get_viewport().size)
	_check(on.x <= 0.01 or on.x >= 0.99 or on.y <= 0.01 or on.y >= 0.99, "reaches the screen edge (%.2f, %.2f)" % [on.x, on.y])
	_check(absf(aim0.y) < 0.001, "aim is flat on the ground")
	await _board_shot("4_strike")
	# Gale walks off: the trail stays where it was laid, aimed the same way
	g.move_hero(h.x, h.y - 90)
	await _wait(0.2)
	_check(fx != null and is_instance_valid(fx) and fx.global_basis.z.dot(aim0) > 0.9999 and fx.global_position.distance_to(pos0) < 0.001,
		"the trail stays locked as Gale moves")
	await _board_shot("4b_trail")
	var blasts0: int = fx.blast_count if fx else 0
	var t_go := S.time
	while is_instance_valid(fx) and fx.blast_count == blasts0 and S.time < t_go + 3:
		await get_tree().process_frame
	_check(is_instance_valid(fx) and fx.blast_count == 1, "the whole trail blasts once, after the delay")
	await _board_shot("4c_blast")
	await _wait(1.6)
	_check(not is_instance_valid(fx) and b.beam_layer.strike == null, "the effect clears itself")
	# the blast's hit: an enemy on the trail takes the damage, once (the signal and the game's fallback timer agree)
	h.x = at0.x
	h.y = at0.y
	h.hold = false
	await _wait(0.3)
	S.pointer = e.pos()
	h.ab.t = 0
	var hp2 := e.hp
	h.strike = null
	g.use_ability()
	while not h.strike or not h.strike.done:
		await get_tree().process_frame
		if S.time > h.ab_at + 4:
			break
	var dealt := hp2 - e.hp
	_check(h.strike != null and h.strike.done and dealt >= 50, "the blast hits the enemy on the trail (%.0f)" % dealt)
	var hp3 := e.hp
	g.strike_blast(h, h.strike) # (the game's fallback timer, coming after the effect's own blast)
	_check(is_equal_approx(e.hp, hp3), "it hits only once")
	await _wait(1.5)
	# cancel(): a waiting trail's blast never comes
	await _wait(1.0)
	h.ab.t = 0
	g.use_ability()
	var n1: int = b.beam_layer.strikes
	while b.beam_layer.strikes == n1 and S.time < h.ab_at + 3:
		await get_tree().process_frame
	var fx2: GaleAirStrike = b.beam_layer.strike
	var fired := [0]
	var had := fx2 != null and fx2.blast_count == 0
	if fx2:
		fx2.blast_triggered.connect(func(_a, _b, _c): fired[0] += 1)
	b.beam_layer.stop()
	await _wait(1.0)
	_check(had and fired[0] == 0 and not is_instance_valid(fx2), "cancel() stops the pending blast")
	# holding position (H) away from the fight: braced behind the shield
	h.x = e.x - 250
	h.tx = null
	h.hold = true
	await _wait(0.6)
	_check(m.ap.current_animation == "ext/brace", "braces behind the shield while holding (%s)" % m.ap.current_animation)
	await _shot("5_brace")
	print("GALE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
