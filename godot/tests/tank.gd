## The Vanguard's live 3D tank model and its timings, in a real run (needs a display for the model):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/tank.tscn -- <out dir>
## Checks the model's clips and loops, the shield bash landing 0.3s into the swing for 16 + 2% max HP, Shield Slam
## landing at 0.5s ahead of the hero for 60 + 4% max HP with a 1.5s stun, Bulwark Shield going up at 0.35s, soaking
## and bursting for 45 + 60% of what it soaked, and that Phantoms are held. Saves screenshots of each pose.
extends Node

var out := "user://tank"
var fails := 0
var main: Main
var g: Game


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	# a 3x close-up of the board around the hero
	var b: Board = main.board
	var bi := b.viewport.get_texture().get_image()
	var p := b.hero_3d.get_global_transform_with_canvas().origin
	var r := Rect2i(int(p.x) - 70, int(p.y) - 95, 140, 120).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var c := bi.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	c.save_png(out.path_join(name + "_zoom.png"))


## Waits until `secs` of game time have gone by.
func _wait(secs: float) -> void:
	var until := g.S.time + secs
	while g.S.time < until:
		await get_tree().process_frame


func _enemy(type: String, d: float) -> Enemy:
	g.spawn(type, g.S.map.path_len * d)
	var e: Enemy = g.S.enemies[g.S.enemies.size() - 1]
	e.armor = 0
	return e


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("TANK TIMEOUT"); get_tree().quit(1))
	seed(3)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.meta.abilities = Save.meta.get("abilities", {})
	Save.meta.abilities["vanguard"] = "main"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("vanguard", ["plasma"])
	for i in 10:
		await get_tree().process_frame
	g = main.game
	var S := g.S
	var h := S.hero
	S.lives = 999
	var b: Board = main.board
	var m := b.hero_3d
	_check(m != null, "the Vanguard is drawn live from its 3D model")
	_check(m.skel.get_bone_count() == 42, "42 bones (%d)" % m.skel.get_bone_count())
	for c in ["idle", "walk", "block", "bulwark_hold"]:
		_check(m.ap.get_animation(c).loop_mode == Animation.LOOP_LINEAR, c + " loops")
	for c in ["attack", "shield_slam", "bulwark", "bulwark_burst"]:
		_check(m.ap.get_animation(c).loop_mode == Animation.LOOP_NONE, c + " plays once")
	_check(m.model.find_child("SlamPoint", true, false) != null and m.model.find_child("ShieldCenter", true, false) != null, "SlamPoint and ShieldCenter markers")
	_check(h.max_hp == 450 and is_equal_approx(h.armor, 0.1) and is_equal_approx(h.regen, 5) and h.speed == 135 and h.block >= 999, "450 HP, 10% DR, 5 regen, speed 135, holds all")
	_check(is_equal_approx(g.hero_dmg(), 25.0), "bash damage %.1f (16 + 2%% of 450)" % g.hero_dmg())
	_check(m.state == "idle", "idles (%s)" % m.state)
	await _shot("0_idle")
	var c0 := h.pos()
	g.move_hero(c0.x + 90, c0.y + 30)
	await _wait(0.3)
	_check(m.state == "walk", "walks when moving (%s)" % m.state)
	await _shot("1_walk")
	await _wait(1.0)

	# shield bash: lands 0.3s into the swing, once
	g.start_wave()
	S.spawn_q = []
	var e := _enemy("brute", 0.3)
	await get_tree().process_frame
	e.speed = 0
	e.hp = 5000
	e.max = 5000
	h.x = e.x - 30
	h.y = e.y
	h.tx = null
	await _wait(0.4) # the teleport reads as a step on the board; let it settle
	var shot0 := h.atk_at
	while h.atk_at == shot0:
		await get_tree().process_frame
	var hp0 := e.hp
	var t0 := h.atk_at
	await get_tree().process_frame
	_check(e.hp == hp0, "no damage the moment the swing starts")
	_check(m.state == "fire" and m.ap.current_animation == "attack", "plays attack (%s)" % m.ap.current_animation)
	await _wait(0.12)
	await _shot("2_attack")
	while S.time < t0 + 0.3:
		await get_tree().process_frame
	await get_tree().process_frame
	_check(absf((hp0 - e.hp) - 25) < 1.5 or (hp0 - e.hp) > 37, "bash lands at 0.3s for %.1f" % (hp0 - e.hp))

	# Shield Slam: 0.5s into the cast, centred ahead of the hero
	h.ab.t = 0
	var hp1 := e.hp
	var swings := h.attacks
	g.use_ability()
	var cast_at := S.time
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.ap.current_animation == "shield_slam", "plays shield_slam (%s)" % m.ap.current_animation)
	_check(e.stun_t <= 0, "nothing stunned before the release")
	await _wait(0.25)
	await _shot("3_slam")
	while S.time < cast_at + 0.5:
		await get_tree().process_frame
	await get_tree().process_frame
	var bash := (h.attacks - swings) * 25.0
	var lost := hp1 - e.hp
	_check(e.stun_t > 1.3, "slam stuns 1.5s (%.2f left)" % e.stun_t)
	_check(lost >= 78 - 1 and lost <= 78 + bash + 13, "slam hits for 78 (lost %.0f, %d bashes)" % [lost, h.attacks - swings])
	await _wait(0.8)

	# Bulwark Shield: up at 0.35s, soaks, bursts for 45 + 60% of what it soaked
	h.ab = Ability.from_data(DB.heroes.vanguard.alt)
	_check(is_equal_approx(h.ab.release, 0.35), "bulwark releases at 0.35s")
	g.use_ability()
	cast_at = S.time
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.ap.current_animation == "bulwark", "plays bulwark (%s)" % m.ap.current_animation)
	_check(h.shield <= 0, "no shield before 0.35s")
	while S.time < cast_at + 0.35:
		await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(h.shield, 225), "shield 225 (%.0f)" % h.shield)
	await _wait(1.0)
	_check(m.ap.current_animation == "bulwark_hold", "holds the guard (%s)" % m.ap.current_animation)
	await _shot("4_bulwark_hold")
	e.hp = 5000
	e.speed = 0
	e.stun_t = 99
	g.hurt_hero(h, 100 / (1 - g.sb("armor")))
	_check(absf(h.soaked - 100) < 0.5, "soaked 100 (%.0f)" % h.soaked)
	var hp2 := e.hp
	var n0 := h.attacks
	while h.shield_t > 0:
		await get_tree().process_frame
	await get_tree().process_frame
	var burst := hp2 - e.hp - (h.attacks - n0) * 25.0
	_check(absf(burst - 105) < 26, "burst for 45 + 60 = 105 (%.0f)" % burst)
	_check(m.ap.current_animation == "bulwark_burst", "plays bulwark_burst (%s)" % m.ap.current_animation)
	await _wait(0.2)
	await _shot("5_burst")
	await _wait(0.6)

	# Phantoms are held too
	e.hp = 0
	g.damage(e, 99999)
	var ph := _enemy("phantom", 0.3)
	await get_tree().process_frame
	h.x = ph.x
	h.y = ph.y
	await _wait(0.2)
	_check(ph.blocked or ph.dead, "a Phantom is held by the Vanguard")
	print("TANK DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
