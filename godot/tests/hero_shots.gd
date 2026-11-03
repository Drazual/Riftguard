## Checks that a hero's bullets leave its gun tip: stands the hero on 8 sides of an enemy, slows time right
## down, and saves a close-up as each round leaves the barrel, plus how far the round's start is from the gun tip
## a few frames later. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/hero_shots.tscn -- <out dir> <hero id>
extends Node

var out := "user://hero_shots"
var hero := "sniper"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	if args.size() > 1:
		hero = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(600).timeout.connect(func(): print("SHOTS TIMEOUT"); get_tree().quit(1))
	seed(3)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(5)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run(hero, Array(DB.tower_order).slice(0, 5))
	await _frames(5)
	var g := main.game
	var S := g.S
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	var h: Hero = S.hero
	var b: Board = main.board
	var mid: Vector2 = S.map.pos_at(S.map.path_len * 0.35)
	g.start_wave()
	for i in 400:
		await _frames(1)
		if S.enemies.size():
			break
	var worst := 0.0
	for i in 8:
		var e: Enemy = S.enemies[0] if S.enemies.size() else null
		if e == null:
			break
		e.d = S.map.path_len * 0.35
		e.x = mid.x
		e.y = mid.y
		e.hp = 999999
		e.max = 999999
		e.speed = 1
		var off := Vector2.from_angle(i * PI / 4) * 85
		h.x = e.x - off.x
		h.y = e.y - off.y
		h.tx = null
		h.ty = null
		Engine.time_scale = 2.0
		var n := b.hero_bullets.size()
		# a second shot, so the gun is already up from the first (continuous fire)
		for shot in 2:
			for f in 900:
				await _frames(1)
				if b.hero_bullets.size() > n:
					break
				n = b.hero_bullets.size()
			n = b.hero_bullets.size()
			# slow time before the second shot, since a change of time scale only lands a frame later
			Engine.time_scale = 0.05
		if b.hero_bullets.is_empty():
			print("no shot at side %d" % i)
			continue
		Engine.time_scale = 0.004
		var round: Dictionary = b.hero_bullets[-1]
		await _frames(1)
		var miss: float = round.a.distance_to(b.hero_muzzle(h)) * Board.PX
		worst = maxf(worst, miss)
		print("side %d: round starts %.1f px from the gun tip" % [i, miss])
		# a few frames of it leaving the barrel
		for f in 3:
			await _frames(2)
			if is_instance_valid(round.sp):
				print("  frame %d: round %.0f px out" % [f, round.a.distance_to(round.sp.position) * Board.PX])
			await _close("side_%d_%d" % [i, f])
	Engine.time_scale = 1.0
	print("SHOTS DONE worst %.1f px" % worst)
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A 3x close-up of the board around the hero.
func _close(name: String) -> void:
	await RenderingServer.frame_post_draw
	var b: Board = main.board
	var img := b.viewport.get_texture().get_image()
	var p := b.hero_spr.get_global_transform_with_canvas().origin
	var r := Rect2i(int(p.x) - 110, int(p.y) - 95, 220, 140).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_NEAREST)
	c.save_png(out.path_join(name + ".png"))
