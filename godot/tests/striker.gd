## Close-ups of the Striker walking and shooting, to check the gun layer against the body. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/striker.tscn -- <out dir> [rendered hero]
## With a second argument (a folder in art_src/heroes rendered by tools/render_hero.gd), the Striker wears that
## render instead, as one sprite with its own muzzle points, to preview a 3D model in game.
extends Node

var out := "user://striker"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("STRIKER TIMEOUT"); get_tree().quit(1))
	seed(3)
	if args.size() > 1:
		_wear(args[1])
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(5)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("striker", Array(DB.tower_order).slice(0, 5))
	await _frames(5)
	var g := main.game
	var S := g.S
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	var h: Hero = S.hero
	var mid: Vector2 = S.map.pos_at(S.map.path_len * 0.35)
	# standing and walking with nothing to shoot
	h.x = mid.x + 60
	h.y = mid.y + 60
	await _frames(10)
	await _close("00_idle")
	for d in [["walk_e", Vector2(1, 0)], ["walk_s", Vector2(0, 1)], ["walk_w", Vector2(-1, 0)], ["walk_n", Vector2(0, -1)]]:
		h.tx = h.x + d[1].x * 300
		h.ty = h.y + d[1].y * 300
		for i in 4:
			await _frames(4)
			await _close("01_%s_%d" % [d[0], i])
		h.tx = null
		h.ty = null
		h.x = mid.x + 60
		h.y = mid.y + 60
	# shooting: stand at different sides of the first enemy so the shots go in every direction, then walk while shooting
	g.start_wave()
	for i in 400:
		await _frames(1)
		if S.enemies.size():
			break
	for i in 8:
		var e: Enemy = S.enemies[0] if S.enemies.size() else null
		if e == null:
			break
		# keep it on screen and alive
		e.d = S.map.path_len * 0.35
		e.x = mid.x
		e.y = mid.y
		e.hp = 999999
		e.max = 999999
		e.speed = 1
		var off := Vector2.from_angle(i * PI / 4) * 90
		h.x = e.x - off.x
		h.y = e.y - off.y
		h.tx = null
		h.ty = null
		await _frames(14)
		await _close("02_shoot_%d" % i)
		await _frames(3)
		await _close("02_shoot_%db" % i)
	var e2: Enemy = S.enemies[0] if S.enemies.size() else null
	if e2:
		h.x = e2.x + 60
		h.y = e2.y - 60
		h.tx = h.x + 160
		h.ty = h.y
		for i in 8:
			await _frames(4)
			await _close("03_walkshoot_%02d" % i)
	print("STRIKER DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## A 3x close-up of the board around the hero.
func _close(name: String) -> void:
	await RenderingServer.frame_post_draw
	var b: Board = main.board
	var img := b.viewport.get_texture().get_image()
	var p := b.hero_spr.get_global_transform_with_canvas().origin if b.hero_spr else Vector2(img.get_width(), img.get_height()) / 2
	var r := Rect2i(int(p.x) - 60, int(p.y) - 80, 120, 110).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_NEAREST)
	c.save_png(out.path_join(name + ".png"))


## Puts a rendered hero's frames and muzzle points on the Striker, and turns off its split gun layer.
func _wear(folder: String) -> void:
	var d: HeroData = DB.heroes["striker"]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/heroes/%s/hero.json" % folder))
	var tips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/heroes/%s/muzzle.json" % folder))
	d.frames = load("res://art/heroes/%s.tres" % cfg.get("out", folder))
	d.body_frames = null
	d.gun = null
	d.gun_fx = null
	var m := PackedVector2Array()
	for face in 8:
		var t: Array = tips["%d_0" % face]
		m.append(Vector2(t[0], t[1]))
	d.muzzle = m
