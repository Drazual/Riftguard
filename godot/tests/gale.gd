## Gale's live 3D sword-and-shield model in a real run (needs a display for the model):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/gale.tscn -- <out dir>
## Checks the clips (its posed stance, run, sword slash and shield brace), the sword hit landing 0.3s into the swing, Whirlwind
## landing 0.5s into its shield_slam clip and Air Stream 0.35s into its bash, and armor as points.
extends Node

var out := "user://gale"
var fails := 0
var main: Main
var g: Game


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


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
	# Air Stream: lands 0.35s into bash
	h.ab = Ability.from_data(DB.heroes.gale.alt)
	_check(is_equal_approx(h.ab.release, 0.35), "Air Stream releases at 0.35s")
	g.use_ability()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(m.ap.current_animation == "bash", "Air Stream plays bash (%s)" % m.ap.current_animation)
	await _wait(0.2)
	await _shot("4_stream")
	# holding position (H) away from the fight: braced behind the shield
	h.x = e.x - 250
	h.tx = null
	h.hold = true
	await _wait(0.6)
	_check(m.ap.current_animation == "ext/brace", "braces behind the shield while holding (%s)" % m.ap.current_animation)
	await _shot("5_brace")
	print("GALE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
