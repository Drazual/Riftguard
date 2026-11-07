## Screenshots and checks for the style test scene (needs a display):
## xvfb-run -s "-screen 0 1600x900x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/style_shot.tscn -- <out dir>
## Checks occlusion against the building (behind: hidden head to feet; in front: drawn), mouse targeting through the
## upscaled render at several window sizes, the beam's screen-edge length through the real camera and its low-res
## viewport, and that moving models stay on the render's pixel grid. Saves full-size and zoomed screenshots.
extends Node

var out := "user://style"
var fails := 0
var t: Control
var w: StyleWorld


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	return img


## The low-res render itself (what the camera sees, before upscaling).
func _render() -> Image:
	await RenderingServer.frame_post_draw
	return w.vp.get_texture().get_image()


## A part of the scene (art pixels), cut from the window and blown up `z` times without smoothing.
func _crop(name: String, art: Rect2, z := 3) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var per := img.get_width() / get_viewport().get_visible_rect().size.x
	var k := w.view.size.x / StyleWorld.ART.x * per
	var o := (w.view.position + w.position) * per
	var c := img.get_region(Rect2i(Vector2i(o + art.position * k), Vector2i(art.size * k)))
	c.resize(int(art.size.x * z), int(art.size.y * z), Image.INTERPOLATE_NEAREST)
	c.save_png(out.path_join(name + ".png"))


func _knob(key: String, v) -> void:
	t.settings.set(key, v)
	w.apply()
	await _frames(4)


## Gale's on-screen box in the low-res render (art rect -> render pixels), for the occlusion check.
func _diff(a: Image, b: Image, art: Rect2) -> int:
	var k := float(a.get_width()) / StyleWorld.ART.x
	var n := 0
	for y in range(int(art.position.y * k), int(art.end.y * k)):
		for x in range(int(art.position.x * k), int(art.end.x * k)):
			if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)) == false:
				n += 1
	return n


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(180).timeout.connect(func(): print("STYLE TIMEOUT"); get_tree().quit(1))
	t = (load("res://scenes/style_test.tscn") as PackedScene).instantiate()
	add_child(t)
	w = t.world
	await _frames(30)
	print("vp ", w.vp.size, " scale ", w.scale_px, " view ", w.view.position, " ", w.view.size)
	_check(w.vp.size == Vector2i(1536, 832) and is_equal_approx(w.scale_px, 1.0), "renders 1536x832, shown at a whole 1x on a 1600x900 window")
	t.paused = true
	t.at = Vector2(700, 600)
	await _frames(20)
	await _shot("after_full")
	await _crop("after_zoom", Rect2(540, 380, 460, 280))
	await _crop("after_gale", Rect2(640, 530, 120, 90), 6)
	await _crop("beam_zoom", Rect2(300, 560, 520, 220))
	await _crop("after_tower", Rect2(840, 470, 120, 110), 6)
	# the same scene with the models' own materials (the stylized material off)
	await _knob("stylize", false)
	await _crop("plain_zoom", Rect2(540, 380, 460, 280))
	await _crop("plain_gale", Rect2(640, 530, 120, 90), 6)
	await _crop("plain_tower", Rect2(840, 470, 120, 110), 6)
	await _knob("stylize", true)
	# chunkier: half the render resolution, upscaled 2x
	await _knob("res_scale", 1.0)
	_check(w.vp.size == Vector2i(768, 416) and is_equal_approx(w.scale_px, 2.0), "res scale 1: 768x416 at a whole 2x (%s, %.2f)" % [w.vp.size, w.scale_px])
	await _crop("res1_zoom", Rect2(540, 380, 460, 280))
	await _knob("res_scale", 2.0)

	# occlusion: Gale just behind the building's ground line is hidden head to feet; just in front, drawn over it
	var box := Rect2(650, 420, 100, 120) # where Gale stands over the building's face, art pixels
	t.at = Vector2(700, 540)
	await _frames(6)
	var with := await _render()
	t.gale.visible = false
	await _frames(3)
	var without := await _render()
	t.gale.visible = true
	_check(_diff(with, without, box) == 0, "behind the building: Gale is hidden (%d pixels differ)" % _diff(with, without, box))
	await _crop("occlusion_behind", Rect2(600, 380, 200, 200))
	t.at = Vector2(700, 572)
	await _frames(6)
	with = await _render()
	t.gale.visible = false
	await _frames(3)
	without = await _render()
	t.gale.visible = true
	var front := _diff(with, without, Rect2(650, 490, 100, 90))
	_check(front > 200, "in front of the building: Gale is drawn over it (%d pixels differ)" % front)
	await _crop("occlusion_front", Rect2(600, 380, 200, 200))

	# moving models stay on the pixel grid (no half-pixel shimmer): Gale's anchor lands on whole render pixels
	var off := 0.0
	for i in 40:
		t.at = Vector2(600 + i * 0.37, 600 + i * 0.21)
		await get_tree().process_frame
		var p := w.cam.unproject_position(t.gale.global_position)
		off = maxf(off, maxf(absf(p.x - roundf(p.x)), absf(p.y - roundf(p.y))))
	_check(off < 0.02, "moving Gale stays on whole render pixels (off by %.3f)" % off)

	# targeting and the beam's edge at several window sizes (windowed, so the size can change)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	for size in [Vector2i(1600, 900), Vector2i(1280, 800), Vector2i(1000, 640), Vector2i(1920, 1080)]:
		get_tree().root.size = size
		await _frames(10)
		print("window now ", get_tree().root.size, " canvas ", get_viewport().get_visible_rect().size, " view ", w.view.position, " ", w.view.size)
		_check(get_tree().root.size == size, "window resized to %s" % size)
		var worst := 0.0
		for a in [Vector2(100, 100), Vector2(768, 416), Vector2(1400, 780), Vector2(702.5, 560.5)]:
			# a click at that art pixel's spot on the window -> the scene's mouse handling -> back to art pixels
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = w.art_to_local(a) + w.position - t.position
			t.goal = null
			t._gui_input(ev)
			worst = maxf(worst, (t.goal as Vector2).distance_to(a))
			# and the 3D round trip: art pixel -> ground point -> camera -> art pixel
			worst = maxf(worst, w.world_to_art(w.art_to_ground(a)).distance_to(a))
		t.goal = null
		_check(worst < 0.6, "%s window: clicks and the 3D round trip land within %.2f art px (render %s at %.2fx)" % [size, worst, w.vp.size, w.scale_px])
		# Gale's beam from the shield toward the right of the screen ends on the render's right edge
		var from := w.art_to_ground(t.at) + Vector3.UP * 0.5
		var dir := w.cam.global_basis.x
		var len: float = t.edge_length(t.at, dir)
		var tip := w.world_to_art(from + dir * len)
		_check(absf(tip.x - StyleWorld.ART.x) < 1.0, "%s window: the beam reaches the render's right edge (tip at %.1f of %d)" % [size, tip.x, StyleWorld.ART.x])
		if size == Vector2i(1280, 800):
			await _shot("after_1280x800")
	get_tree().root.size = Vector2i(1600, 900)
	await _frames(10)
	print("STYLE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
