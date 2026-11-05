extends "res://tools/render_hero.gd"
## Renders a 3D tower model into directional sprites: the turret turned to DIRS facings, an idle frame and the
## fire clip for each. Same camera, lights and painted look as the heroes (see render_hero.gd / render_hero.md).
##   xvfb-run godot --path godot --rendering-driver opengl3 -s res://tools/render_tower.gd -- <tower folder>
## <tower folder> is a folder in res://art_src/towers/ holding the model and a tower.json:
##   model   the .glb: Y up, metres, origin at the base's bottom centre, the turret aiming +Z
##   yaw     the node that turns the turret (rotation.y); pitch: the node that tilts it (rotation.x, negative = up)
##   anims   { "idle": clip, "fire": clip }. The tool sets yaw and pitch itself, so any yaw/pitch keys in those
##           clips are overridden.
##   aim     pitch (radians) the turret is baked at, a slight downward tilt toward the enemies on the ground
##   dirs    how many facings (16 by default)
##   fire_frames  how many frames of the fire clip (6 by default)
##   fire_times   optional: the exact clip times (seconds) to take the fire frames from, instead of `fire_frames`
##           evenly spaced ones; for a tower that charges up before it shoots
##   fire_time    optional: how long the fire frames play in game, in seconds (the clip's length by default)
##   muzzle_scale  optional: scales the Muzzle node (and the charge/fire effects under it) up, so a small effect
##           still reads at board size (1 by default)
##   shot    optional: renders the tower's projectile from the model too, as the "shot" animation of the out .tres:
##           { "clip": clip, "t": time, "nodes": [mesh names to show], "zoom": how much bigger than on the tower,
##             "size": frame size }. The board draws it instead of the tower's pixel-art shot.
##   size    frame size (96 = drawn at half size on the board, like a 48px tower frame at 2x)
##   wide    how wide the base renders facing the camera, in frame pixels
##   foot    [x, y]: where the base's bottom centre lands in a frame, in frame pixels
##   out     the name of the files it writes
##   shot_frame  the fire frame whose muzzle point goes in the printed turret_muzzle line (0 by default; a cannon
##           uses the frame its shell leaves on, the same as TowerData.fire_frame)
## It writes res://assets/towers/<out>.png (DIRS columns, facing 0 = up the screen, going clockwise; row 0 idle,
## then the fire frames), res://art/towers/<out>.tres (SpriteFrames idle_N and fire_N) and
## res://art_src/towers/<folder>/muzzle.json (the Muzzle node in every facing and fire frame, in frame pixels).
## It prints the TowerData.turret_muzzle line (each facing's muzzle at fire frame `shot_frame`) to paste into the
## tower's data.

var DIRS := 16
var FIRE := 6
var aim := 0.0
var yaw_node: Node3D
var muzzle_node: Node3D # scaled by muzzle_scale after the clip poses it
var muzzle_scale := 1.0
var muzzle_rest := Vector3.ONE
var pitch_node: Node3D


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_tower: pass the tower folder, e.g. -- laser")
		quit(1)
		return
	var dir := "res://art_src/towers/%s/" % args[0]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "tower.json"))
	var out: String = cfg.get("out", args[0])
	FRAME = int(cfg.get("size", 96))
	FEET = Vector2(cfg.get("foot", [FRAME / 2.0, FRAME * 0.75])[0], cfg.get("foot", [FRAME / 2.0, FRAME * 0.75])[1])
	TALL = FRAME * 0.5 # only a first guess for the camera; _fit_tower sizes the model by its width
	DIRS = int(cfg.get("dirs", 16))
	FIRE = int(cfg.get("fire_frames", 6))
	var times: Array = cfg.get("fire_times", [])
	if times.size():
		FIRE = times.size()
	aim = cfg.get("aim", 0.0)
	painted = cfg.get("style", "painted") == "painted"
	_stage()
	var model: Node3D = (load(dir + cfg.model) as PackedScene).instantiate()
	pivot.add_child(model)
	_toon(model)
	yaw_node = model.get_node(cfg.yaw)
	pitch_node = model.get_node(cfg.pitch)
	var muzzle: Node3D = model.find_child("Muzzle", true, false)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	await _fit_tower(model, ap, cfg.anims.idle, cfg.get("wide", FRAME * 0.62))
	muzzle_scale = float(cfg.get("muzzle_scale", 1.0))
	if muzzle_scale != 1.0:
		muzzle_node = muzzle
		muzzle_rest = muzzle.scale
	var sheet := Image.create(FRAME * DIRS, FRAME * (1 + FIRE), false, Image.FORMAT_RGBA8)
	var tips := {}
	for face in DIRS:
		for row in 1 + FIRE:
			var clip: String = cfg.anims.idle if row == 0 else cfg.anims.fire
			var t := 0.0 if row == 0 else (float(times[row - 1]) if times.size() else ap.get_animation(clip).length * (row - 1) / FIRE)
			await _pose(ap, clip, t, _yaw16(face))
			var img := _shrink(_straight(vp.get_texture().get_image()))
			img = _fx_outline(img) if painted else _outlined(img)
			sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(face * FRAME, row * FRAME))
			if row > 0:
				var tip := cam.unproject_position(muzzle.global_position) / SS
				tips["%d_%d" % [face, row - 1]] = [snappedf(tip.x, 0.1), snappedf(tip.y, 0.1)]
	sheet.save_png("res://assets/towers/%s.png" % out)
	var shot := false
	if cfg.has("shot"):
		await _render_shot(model, ap, muzzle, cfg.shot, out)
		shot = true
	_tower_frames_tres(out, float(cfg.get("fire_time", ap.get_animation(cfg.anims.fire).length)), shot)
	var f := FileAccess.open(dir + "muzzle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(tips, "\t"))
	f.close()
	var first: Array = []
	var sf := clampi(int(cfg.get("shot_frame", 0)), 0, FIRE - 1)
	for face in DIRS:
		first.append_array(tips["%d_%d" % [face, sf]])
	print("render_tower: wrote %s; TowerData.turret_muzzle = PackedVector2Array(%s)" % [out, ", ".join(first.map(func(v): return str(v)))])
	quit()


var shot_size := 32


## The projectile on its own: only `nodes` shown, posed at `t` of `clip`, the camera zoomed in `zoom` times on the
## muzzle, cut to a `size` frame around it. Writes res://assets/towers/<out>_shot.png.
func _render_shot(model: Node3D, ap: AnimationPlayer, muzzle: Node3D, c: Dictionary, out: String) -> void:
	shot_size = int(c.get("size", 32))
	var keep: Array = c.get("nodes", [])
	# the rest of the model moves to a render layer the camera doesn't see (hiding a mesh would hide the orb
	# under it too)
	var hidden: Array[MeshInstance3D] = []
	for n in model.find_children("*", "MeshInstance3D", true, false):
		if not keep.has(String(n.name)):
			n.layers = 2
			hidden.append(n)
	cam.cull_mask = 1
	var size0 := cam.size
	var pos0 := cam.position
	await _pose(ap, c.get("clip", "charge"), float(c.get("t", 0.0)), _yaw16(DIRS / 2))
	# zoom in about the muzzle: move the camera so the muzzle is in the middle, then shrink its view
	var mid := cam.project_position(Vector2(FRAME * SS, FRAME * SS) / 2.0, 20.0)
	var at := cam.project_position(cam.unproject_position(muzzle.global_position), 20.0)
	cam.position += at - mid
	cam.size = size0 / float(c.get("zoom", 1.0))
	cam.set_orthogonal(cam.size, cam.near, cam.far)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := _shrink(_straight(vp.get_texture().get_image()))
	var o := (FRAME - shot_size) / 2
	var cut := img.get_region(Rect2i(o, o, shot_size, shot_size))
	cut.save_png("res://assets/towers/%s_shot.png" % out)
	cam.size = size0
	cam.position = pos0
	cam.set_orthogonal(cam.size, cam.near, cam.far)
	for n in hidden:
		n.layers = 1
	cam.cull_mask = 0xFFFFF


## Translucent effects (an ice orb, a glow) render over the empty background with their colour already multiplied
## by their alpha, so they'd come out dark; this divides it back out. Solid pixels are left as they are.
func _straight(img: Image) -> Image:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 0.99:
				img.set_pixel(x, y, Color(minf(1, c.r / c.a), minf(1, c.g / c.a), minf(1, c.b / c.a), c.a))
	return img


## The painted outline, drawn around the solid model only: translucent effects (a glow, an ice orb) go on top
## afterwards without a dark line of their own, so they stay light.
func _fx_outline(img: Image) -> Image:
	var solid := img.duplicate() as Image
	for y in FRAME:
		for x in FRAME:
			if solid.get_pixel(x, y).a < 0.95:
				solid.set_pixel(x, y, Color(0, 0, 0, 0))
	var out := _soft_outline(solid)
	out.blend_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i.ZERO)
	return out


func _outlined(img: Image) -> Image:
	_outline(img)
	return img


## Poses the model at time t of a clip, then turns the turret to `yaw` and tilts it to `aim` (over any keys the
## clip has for them), and waits for the render.
func _pose(ap: AnimationPlayer, clip: String, t: float, yaw: float) -> void:
	ap.play(clip)
	ap.seek(t, true)
	ap.pause()
	yaw_node.rotation = Vector3(0, yaw, 0)
	pitch_node.rotation = Vector3(aim, 0, 0)
	if muzzle_node:
		muzzle_node.scale = muzzle_rest * muzzle_scale
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


## Facing `face` of DIRS (0 = up the screen, clockwise) as a turn of the turret, through the board's squash like
## the heroes' 8 facings.
func _yaw16(face: int) -> float:
	var a := face * TAU / DIRS - PI / 2 # 0 = right, PI/2 = down the screen
	var g := Vector2(cos(a), sin(a) / K)
	return atan2(g.x, g.y)


## Every facing renders at the same size: facing the camera, the model is scaled so it is `wide` pixels across and
## moved so its lowest pixel sits on FEET.y.
func _fit_tower(model: Node3D, ap: AnimationPlayer, idle: String, wide: float) -> void:
	var px_per_unit := FRAME * SS / cam.size
	for i in 3:
		await _pose(ap, idle, 0.0, _yaw16(DIRS / 2))
		var used := vp.get_texture().get_image().get_used_rect()
		if used.size.x <= 0:
			break
		if i == 0:
			model.scale *= wide * SS / used.size.x
		else:
			var dy := FEET.y * SS - (used.position.y + used.size.y)
			model.position.y -= dy / (px_per_unit * cos(deg_to_rad(PITCH)))


## Writes the SpriteFrames: idle_N (one frame) and fire_N (the fire clip at its own speed) for each facing N.
func _tower_frames_tres(out: String, fire_len: float, shot := false) -> void:
	var subs := PackedStringArray()
	var anims := PackedStringArray()
	var id := 0
	for face in DIRS:
		for anim in ["idle", "fire"]:
			var rows: Array = [0] if anim == "idle" else range(1, 1 + FIRE)
			var refs := PackedStringArray()
			for r in rows:
				id += 1
				subs.append('[sub_resource type="AtlasTexture" id="A%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, %d, %d)\n' % [id, face * FRAME, r * FRAME, FRAME, FRAME])
				refs.append('{\n"duration": 1.0,\n"texture": SubResource("A%d")\n}' % id)
			var fps := 5.0 if anim == "idle" else snappedf(FIRE / fire_len, 0.1)
			anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%d",\n"speed": %.1f\n}' % [", ".join(refs), "true" if anim == "idle" else "false", anim, face, fps])
	if shot:
		id += 1
		subs.append('[sub_resource type="AtlasTexture" id="A%d"]\natlas = ExtResource("2")\nregion = Rect2(0, 0, %d, %d)\n' % [id, shot_size, shot_size])
		anims.append('{\n"frames": [{\n"duration": 1.0,\n"texture": SubResource("A%d")\n}],\n"loop": false,\n"name": &"shot",\n"speed": 1.0\n}' % id)
	var f := FileAccess.open("res://art/towers/%s.tres" % out, FileAccess.WRITE)
	f.store_string('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (id + 2 + (1 if shot else 0)))
	f.store_string('[ext_resource type="Texture2D" path="res://assets/towers/%s.png" id="1"]\n' % out)
	if shot:
		f.store_string('[ext_resource type="Texture2D" path="res://assets/towers/%s_shot.png" id="2"]\n' % out)
	f.store_string("\n")
	f.store_string("\n".join(subs))
	f.store_string("\n[resource]\nanimations = [%s]\n" % ", ".join(anims))
	f.close()
