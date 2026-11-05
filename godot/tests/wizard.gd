## Close-ups of the Wizard drawn live from its 3D model, casting a spell of each kind (one element, doubled, a
## combination, an ultimate, a flying bolt) in a few directions, and walking (to check the stride), to check each spell plays its own cast clip and
## bolts leave from the staff. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/wizard.tscn -- <out dir>
extends Node

var out := "user://wizard"
var main: Main


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(150).timeout.connect(func(): print("WIZARD TIMEOUT"); get_tree().quit(1))
	seed(3)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames(5)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("wizard", Array(DB.tower_order).slice(0, 5))
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
	h.x = mid.x + 60
	h.y = mid.y + 60
	await _frames(10)
	await _close("00_idle")
	var b: Board = main.board
	# walking east, then south, to check the stride
	for d in [["walk_e", Vector2(1, 0)], ["walk_s", Vector2(0, 1)]]:
		h.tx = h.x + d[1].x * 400
		h.ty = h.y + d[1].y * 400
		await _frames(20)
		for i in 8:
			await _frames(2)
			await _close("00_%s_%d" % [d[0], i])
		if b.hero_3d:
			print("%s: pace %.2f walk_speed %.2f gv %.1f" % [d[0], b.hero_3d.ap.speed_scale, b.hero_3d.walk_speed, b.hero_state.get("gv", 0.0)])
		h.tx = null
		h.ty = null
		h.x = mid.x + 60
		h.y = mid.y + 60
		await _frames(10)
	var casts := [["fire"], ["water", "water"], ["fire", "earth"], ["light", "light", "light"], ["storm"], ["void", "void"], ["nature"], ["air", "air"]]
	for i in casts.size():
		var key := Progress.spell_key(casts[i])
		h.mana = 999
		h.cast_t = 0
		S.el_cd = {}
		S.runes = casts[i]
		var at := Vector2(h.x, h.y) + Vector2.from_angle(i * PI / 4 + 0.3) * 110
		g.cast_runes(at.x, at.y)
		var clip := Board.cast_clip(key)
		var last := 0
		for f in [2, 6, 14, 30]:
			await _frames(f - last)
			last = f
			if f == 2:
				var played: String = b.hero_3d.ap.current_animation if b.hero_3d else "-"
				print("cast %s -> %s (playing %s)" % [key, clip, played])
				if played != clip:
					push_error("wizard: %s should play %s, plays %s" % [key, clip, played])
			await _close("%02d_%s_%02d" % [i + 1, key.replace("+", "_"), f])
		await _frames(60)
	print("WIZARD DONE")
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
	var r := Rect2i(int(p.x) - 80, int(p.y) - 90, 160, 120).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_NEAREST)
	c.save_png(out.path_join(name + ".png"))
