## The Oracle's live 3D hovering model in a real run (needs a display for the model):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/oracle.tscn -- <out dir>
## Checks idle_hover / hover_move with hover_start and hover_stop between them, that the mesh keeps its hover (never
## pulled to the ground), the orb crystal spinning on through clip changes, shots from the orb's CastPoint, and the
## optional cast clip letting go 0.45s in.
extends Node

var out := "user://oracle"
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


## Waits (up to `secs` of game time) until the model plays `clip`; returns whether it did.
func _until(m: Hero3D, clip: String, secs: float) -> bool:
	var until := g.S.time + secs
	while g.S.time < until:
		if m.ap.current_animation == clip:
			return true
		await get_tree().process_frame
	return m.ap.current_animation == clip


func _core_angle(m: Hero3D) -> Quaternion:
	return m.skel.get_bone_pose_rotation(m.skel.find_bone("PropCore"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): print("ORACLE TIMEOUT"); get_tree().quit(1))
	seed(4)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("oracle", ["plasma"])
	for i in 10:
		await get_tree().process_frame
	g = main.game
	var S := g.S
	var h := S.hero
	S.lives = 999
	var m := main.board.hero_3d
	_check(m != null and m.skel.get_bone_count() == 68, "the Oracle is drawn live from its 3D model (68 bones)")
	_check(m.anims.idle == "idle_hover" and m.anims.walk == "hover_move", "idle_hover for idle, hover_move for walk")
	_check(m.ap.current_animation == "idle_hover", "hovers idle (%s)" % m.ap.current_animation)
	# never pulled down to the ground: the model's origin stays on the floor, so her feet hang above it
	await _wait(0.3)
	_check(is_equal_approx(m.model.position.y, 0.0), "keeps its hover (model height %.3f)" % m.model.position.y)
	var toe := INF
	for f in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftFoot", "mixamorig_RightFoot"]:
		var b := m.skel.find_bone(f)
		if b >= 0:
			toe = minf(toe, (m.skel.global_transform * m.skel.get_bone_global_pose(b).origin).y)
	_check(toe > 0.03, "feet clear of the ground (%.3f units)" % toe)
	# the coat and orb keep their animation tracks
	var a := m.ap.get_animation("idle_hover")
	var coat := 0
	var prop := 0
	for t in a.get_track_count():
		var path := String(a.track_get_path(t))
		coat += 1 if path.contains(":Coat") else 0
		prop += 1 if path.contains(":Prop") else 0
	_check(coat >= 24 and prop >= 2, "coat and orb tracks kept (%d coat, %d orb)" % [coat, prop])
	# the crystal spins under the clips, on through a clip change
	var spin := m.skel.get_children().filter(func(n): return n is OracleOrbSpin)
	_check(spin.size() == 1, "orb spin modifier under the Skeleton3D (%s)" % str(m.skel.get_children().map(func(n): return n.get_class())))
	var q0 := _core_angle(m)
	await _shot("0_idle")
	# moving: hover_start, then hover_move
	var c0 := h.pos()
	g.move_hero(c0.x - 140, c0.y + 30)
	_check(await _until(m, "hover_start", 0.3), "starts moving with hover_start (%s)" % m.ap.current_animation)
	var q1 := _core_angle(m)
	_check(q0.angle_to(q1) > 0.05, "crystal keeps spinning across the clip change (%.2f rad)" % q0.angle_to(q1))
	_check(await _until(m, "hover_move", 1.0), "then hover_move (%s)" % m.ap.current_animation)
	_check(is_equal_approx(m.model.position.y, 0.0), "no ground snap while moving (%.3f)" % m.model.position.y)
	await _shot("1_move")
	_check(await _until(m, "hover_stop", 3.0), "stops with hover_stop (%s)" % m.ap.current_animation)
	_check(await _until(m, "idle_hover", 1.5), "then back to idle_hover (%s)" % m.ap.current_animation)
	await _shot("2_stopped")
	# shots leave from the orb's CastPoint
	_check(m.muzzle != null and m.muzzle.name == "CastPoint", "shots leave from the orb's CastPoint")
	# the optional cast: lets go 0.45s in, at CastPoint (no ability uses it yet)
	_check(is_equal_approx(float(m.cfg.release.cast), 0.45) and m.ap.has_animation("cast"), "cast clip lets go at 0.45s")
	m.cast("cast")
	await get_tree().process_frame
	_check(m.ap.current_animation == "cast" and m.cast_at == 0.45, "plays cast with its release at 0.45s (%s)" % m.ap.current_animation)
	await _wait(0.5)
	await _shot("3_cast")
	print("ORACLE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
