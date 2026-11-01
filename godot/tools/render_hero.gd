extends SceneTree
## Renders a rigged 3D hero model into the game's 8-direction pixel-art sprite sheet.
## Needs a display (it renders), so on a server run it under Xvfb:
##   xvfb-run godot --path godot --rendering-driver opengl3 -s res://tools/render_hero.gd -- <hero folder>
## <hero folder> is a folder in res://art_src/heroes/ holding the model and a hero.json:
##   model   the .glb (rigged, about 1.8 units tall, standing at the origin, facing +Z)
##   anims   { "idle": clip, "walk": clip, "fire": clip } from the model's AnimationPlayer
##   weapon  optional: the node of the weapon mesh; its front end is the muzzle if there's no "Muzzle" node
##   hide    optional: nodes to hide (spare weapons and props)
##   out     the name of the files it writes
## It writes res://assets/heroes/<out>.png (8 columns N, NE, E, SE, S, SW, W, NW; rows idle 0-3, walk 4-11,
## fire 12-15, 64px frames, feet on row 59), res://art/heroes/<out>.tres (SpriteFrames idle_N, walk_N, fire_N)
## and res://art_src/heroes/<folder>/muzzle.json (the gun tip in every direction and fire frame, in frame pixels).
## How it all fits together, and how to make a model for it: tools/render_hero.md.

const FRAME := 64
const SS := 4 # render at 4x, then shrink: crisp pixels, no blur
const FEET := Vector2(32, 59) # where the hero's origin lands in a frame
const TALL := 38.0 # how many pixels a 1.8-unit hero stands on screen
const K := 0.75 # the board squashes the ground vertically by this (Board.K); the 8 facings follow it
## How far the camera looks down. Flatter than the ground's tilt (asin(K), about 49) so characters read more
## from the front, like hand-drawn 3/4 sprites.
const PITCH := 35.0
const ROWS := { idle = [0, 4, 5.0, true], walk = [4, 8, 12.0, true], fire = [12, 4, 15.0, false] } # first row, frames, fps, loops
const OUTLINE := Color(0.06, 0.05, 0.12)

var vp: SubViewport
var cam: Camera3D
var pivot: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_hero: pass the hero folder, e.g. -- rogue_test")
		quit(1)
		return
	var dir := "res://art_src/heroes/%s/" % args[0]
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "hero.json"))
	var out: String = cfg.get("out", args[0])
	_stage()
	var model: Node3D = (load(dir + cfg.model) as PackedScene).instantiate()
	pivot.add_child(model)
	for n in cfg.get("hide", []):
		var h := model.find_child(n, true, false)
		if h:
			h.visible = false
	_toon(model)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var muzzle: Node3D = model.find_child("Muzzle", true, false)
	var weapon: Node3D = model.find_child(cfg.get("weapon", ""), true, false) if cfg.has("weapon") else null
	await _fit(model, ap, cfg.anims.idle, weapon)
	var sheet := Image.create(FRAME * 8, FRAME * 16, false, Image.FORMAT_RGBA8)
	var tips := {}
	for face in 8:
		pivot.rotation.y = _yaw(face)
		for anim in ROWS:
			var r: Array = ROWS[anim]
			var clip: String = cfg.anims[anim]
			var length := ap.get_animation(clip).length
			for f in r[1]:
				ap.play(clip)
				ap.seek(length * f / r[1], true)
				ap.pause()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var img := _shrink(vp.get_texture().get_image())
				_outline(img)
				sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(face * FRAME, (r[0] + f) * FRAME))
				if anim == "fire":
					var tip := _tip(muzzle, weapon, face)
					tips["%d_%d" % [face, f]] = [snappedf(tip.x, 0.1), snappedf(tip.y, 0.1)]
	sheet.save_png("res://assets/heroes/%s.png" % out)
	_frames_tres(out)
	var f := FileAccess.open(dir + "muzzle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(tips, "\t"))
	f.close()
	var first: Array = []
	for face in 8:
		first.append_array(tips["%d_0" % face])
	print("render_hero: wrote %s; HeroData.muzzle = PackedVector2Array(%s)" % [out, ", ".join(first.map(func(v): return str(v)))])
	quit()


## The camera never moves: orthographic, tilted so the ground squashes by K like the board, framing a hero
## TALL pixels high with its origin on FEET. Toon key light from the top left, flat ambient fill.
func _stage() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(FRAME * SS, FRAME * SS)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.75)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.25
	vp.add_child(sun)
	pivot = Node3D.new()
	vp.add_child(pivot)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var pitch := deg_to_rad(PITCH)
	cam.rotation = Vector3(-pitch, 0, 0)
	cam.position = Vector3(0, sin(pitch), cos(pitch)) * 20.0
	# a 1.8-unit hero stands 1.8 * cos(pitch) tall on screen; size it to TALL pixels of FRAME
	cam.size = 1.8 * cos(pitch) * FRAME / TALL
	# slide the view so the origin sits on FEET instead of the middle
	# (moved along its own up and right axes; Camera3D.v_offset doesn't render the same way in Compatibility)
	var up := Vector3(0, cos(pitch), -sin(pitch))
	cam.position += up * (FEET.y - FRAME / 2.0) / FRAME * cam.size
	cam.position += Vector3.RIGHT * -(FEET.x - FRAME / 2.0) / FRAME * cam.size
	cam.near = 0.1
	cam.far = 60.0
	vp.add_child(cam)
	cam.set_orthogonal(cam.size, cam.near, cam.far)
	cam.make_current()


## Turns the model so it faces the given direction on screen (0 = up the screen, clockwise). Screen directions
## map to ground directions through the board's tilt, so the diagonals match the game's 8 sectors.
func _yaw(face: int) -> float:
	var a := (face - 2) * PI / 4 # 0 = right, PI/2 = down the screen
	var g := Vector2(cos(a), sin(a) / K) # on the ground: x right, y toward the camera (+Z)
	return atan2(g.x, g.y)


## Every hero renders at the same size and with its feet in the same place. Skinned meshes don't report their
## posed size reliably, so this measures the render itself: facing the camera in the first idle frame, without the
## weapon, it scales the model to TALL pixels high and moves it so its lowest pixel lands on FEET.
func _fit(model: Node3D, ap: AnimationPlayer, idle: String, weapon: Node3D) -> void:
	pivot.rotation.y = _yaw(4)
	ap.play(idle)
	ap.seek(0.0, true)
	ap.pause()
	var shown := weapon.visible if weapon else false
	if weapon:
		weapon.visible = false
	var px_per_unit := FRAME * SS / cam.size
	for i in 3:
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var used := vp.get_texture().get_image().get_used_rect()
		if used.size.y <= 0:
			break
		if i == 0:
			model.scale *= TALL * SS / used.size.y
		else:
			var dy := FEET.y * SS - (used.position.y + used.size.y)
			model.position.y -= dy / (px_per_unit * cos(deg_to_rad(PITCH)))
	if weapon:
		weapon.visible = shown


## Hard-edged light bands instead of smooth shading, and no shine.
func _toon(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is StandardMaterial3D:
				var t: StandardMaterial3D = m.duplicate()
				t.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				t.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.set_surface_override_material(i, t)
	for c in n.get_children():
		_toon(c)


## Box-filters the SS-times render down to FRAME, then cuts alpha hard, like hand-placed pixels.
func _shrink(src: Image) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var n := float(SS * SS)
	for y in FRAME:
		for x in FRAME:
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var a := 0.0
			for j in SS:
				for i in SS:
					var c := src.get_pixel(x * SS + i, y * SS + j)
					r += c.r * c.a
					g += c.g * c.a
					b += c.b * c.a
					a += c.a
			if a / n >= 0.45:
				out.set_pixel(x, y, Color(r / a, g / a, b / a, 1))
	return out


## A 1px dark outline around the silhouette.
func _outline(img: Image) -> void:
	var edge: Array[Vector2i] = []
	for y in FRAME:
		for x in FRAME:
			if img.get_pixel(x, y).a > 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < FRAME and p.y < FRAME and img.get_pixelv(p).a > 0:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixelv(p, OUTLINE)


## The gun tip in frame pixels: the "Muzzle" node if the model has one, else the front of the weapon's box.
func _tip(muzzle: Node3D, weapon: Node3D, face: int) -> Vector2:
	var at := Vector3.ZERO
	if muzzle:
		at = muzzle.global_position
	elif weapon:
		var fwd := Vector3(sin(_yaw(face)), 0, cos(_yaw(face)))
		var best := -INF
		var sum := Vector3.ZERO
		var n := 0
		for mi in [weapon] + weapon.find_children("*", "MeshInstance3D", true, false):
			if not (mi is MeshInstance3D):
				continue
			var box: AABB = mi.get_aabb()
			for i in 8:
				var p: Vector3 = mi.global_transform * box.get_endpoint(i)
				var d := p.dot(fwd)
				if d > best + 0.02:
					best = d
					sum = p
					n = 1
				elif d > best - 0.02:
					sum += p
					n += 1
		at = sum / maxf(1, n)
	return cam.unproject_position(at) / SS


## Writes the SpriteFrames: idle_N, walk_N and fire_N for each facing N, cut from the sheet.
func _frames_tres(out: String) -> void:
	var subs := PackedStringArray()
	var anims := PackedStringArray()
	var id := 0
	for face in 8:
		for anim in ROWS:
			var r: Array = ROWS[anim]
			var refs := PackedStringArray()
			for f in r[1]:
				id += 1
				subs.append('[sub_resource type="AtlasTexture" id="A%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, %d, %d)\n' % [id, face * FRAME, (r[0] + f) * FRAME, FRAME, FRAME])
				refs.append('{\n"duration": 1.0,\n"texture": SubResource("A%d")\n}' % id)
			anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%d",\n"speed": %.1f\n}' % [", ".join(refs), "true" if r[3] else "false", anim, face, r[2]])
	var f := FileAccess.open("res://art/heroes/%s.tres" % out, FileAccess.WRITE)
	f.store_string('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (id + 2))
	f.store_string('[ext_resource type="Texture2D" path="res://assets/heroes/%s.png" id="1"]\n\n' % out)
	f.store_string("\n".join(subs))
	f.store_string("\n[resource]\nanimations = [%s]\n" % ", ".join(anims))
	f.close()
