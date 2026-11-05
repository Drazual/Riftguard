extends SceneTree
## Renders a rigged 3D hero model into the game's 8-direction pixel-art sprite sheet.
## Needs a display (it renders), so on a server run it under Xvfb:
##   xvfb-run godot --path godot --rendering-driver opengl3 -s res://tools/render_hero.gd -- <hero folder>
## <hero folder> is a folder in res://art_src/heroes/ holding the model and a hero.json:
##   model   the .glb (rigged, about 1.8 units tall, standing at the origin, facing +Z)
##   anims   { "idle": clip, "walk": clip, "fire": clip }: a clip in the model's AnimationPlayer, or a separate
##           animation file on the same skeleton (e.g. "walk.fbx" downloaded from Mixamo "Without Skin")
##   span    optional: { "idle": [from, to] } seconds of a clip to sample, for long clips
##   held    optional: a weapon held in both hands, for models that come without one (e.g. from Mixamo):
##           { "scene": "rifle.tscn", "grip": right hand bone, "support": left hand bone }. The weapon scene has
##           its grip at the origin, the barrel along -Z and a "Muzzle" node at the tip; every frame it is put in
##           the grip hand and pointed at the support hand, so it follows the animation's hands exactly.
##           "turn": 180 for a weapon modelled with its barrel along +Z.
##   lock_root optional: the root bone (e.g. "mixamorig_Hips"); its sideways drift is removed so walks stay in place
##   weapon  optional: the node of the weapon mesh; its front end is the muzzle if there's no "Muzzle" node
##   muzzle  optional: the name of the node at the weapon's tip ("Muzzle" by default; the Wizard's is "CastPoint")
##   extra   optional: more one-shot clips (casts) beyond idle, walk and fire, in groups:
##           { "<group>": { "<clip>": frames, ... }, ... }. Each group gets its own sheet,
##           res://assets/heroes/<out>_<group>.png (8 columns, the group's clips one after another, `frames` rows
##           each), so a hero with many clips never makes one texture taller than the GPU allows (16384 px). Their
##           animations, <clip>_N per facing at the clip's own speed, go in res://art/heroes/<out>_extra.tres, apart
##           from the hero's main SpriteFrames, so the game doesn't load them unless it asks for them.
##   release optional: { "<clip>": seconds }: the moment in a one-shot clip the shot or spell leaves. That clip's
##           frames are spaced so one lands exactly on it, and muzzle.json says which ("release": { animation: frame }, e.g. "fire" or "cast_water_strong").
##   hide    optional: nodes to hide (spare weapons and props)
##   out     the name of the files it writes
##   size    optional: frame size, 64 (default) or 128 for heroes shown at 0.5 (HeroData.art_scale)
##   style   optional: "pixel" (default) or "painted"
## It writes res://assets/heroes/<out>.png (8 columns N, NE, E, SE, S, SW, W, NW; rows idle 0-3, walk 4-11,
## fire 12-15, 64px frames, feet on row 59), res://art/heroes/<out>.tres (SpriteFrames idle_N, walk_N, fire_N)
## and res://art_src/heroes/<folder>/muzzle.json (the gun tip in every direction and fire frame, in frame pixels; for
## the extra clips "<clip>_<facing>_<frame>").
## How it all fits together, and how to make a model for it: tools/render_hero.md.

## Frame size and framing are for 64px frames; "size" in hero.json scales all three (128 = drawn at 2x).
var FRAME := 64
const SS := 4 # render at 4x, then shrink
var FEET := Vector2(32, 59) # where the hero's origin lands in a frame
var TALL := 38.0 # how many pixels a 1.8-unit hero stands in a frame
## "pixel": toon bands, hard edges and a 1px outline. "painted": smooth shading, soft anti-aliased edges and a soft
## dark outline, like the painted map sprites.
var painted := false
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
	var k: float = cfg.get("size", 64) / 64.0
	FRAME = int(64 * k)
	FEET *= k
	TALL *= k
	painted = cfg.get("style", "pixel") == "painted"
	_stage()
	var model: Node3D = (load(dir + cfg.model) as PackedScene).instantiate()
	pivot.add_child(model)
	for n in cfg.get("hide", []):
		var h := model.find_child(n, true, false)
		if h:
			h.visible = false
	_toon(model)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var anims: Dictionary = cfg.anims.duplicate()
	for anim in anims:
		if String(anims[anim]).get_extension() in ["fbx", "glb", "gltf"]:
			anims[anim] = _import_clip(ap, dir + anims[anim], anim)
		if cfg.has("lock_root"):
			_lock_root(ap.get_animation(anims[anim]), cfg.lock_root)
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var held: Node3D = null
	if cfg.has("held"):
		for b in [cfg.held.grip, cfg.held.support]:
			if skel.find_bone(b) < 0:
				push_error("render_hero: no bone %s in the model" % b)
				quit(1)
				return
		held = (load(dir + cfg.held.scene) as PackedScene).instantiate()
		vp.add_child(held)
		_toon(held)
	var muzzle: Node3D = (held if held else model).find_child(cfg.get("muzzle", "Muzzle"), true, false)
	var weapon: Node3D = held
	if cfg.has("weapon"):
		weapon = model.find_child(cfg.weapon, true, false)
	await _fit(model, ap, anims.idle, weapon)
	var release: Dictionary = cfg.get("release", {})
	var rel_frames := {}
	# the sheets to draw: the main one (ROWS: idle, walk, fire), then one per group of extra clips. Each row set is
	# { anim: [first row, frames, fps, loops] }; an extra clip's animation is named after the clip itself.
	var sheets := [{ name = out, rows = ROWS }]
	var extra: Dictionary = cfg.get("extra", {})
	for g in extra:
		var rows := {}
		var next := 0
		for clip in extra[g]:
			var n := int(extra[g][clip])
			anims[clip] = clip
			if cfg.has("lock_root"):
				_lock_root(ap.get_animation(clip), cfg.lock_root)
			rows[clip] = [next, n, snappedf(n / ap.get_animation(clip).length, 0.1), false]
			next += n
		sheets.append({ name = "%s_%s" % [out, g], rows = rows })
	var tips := {}
	for sh in sheets:
		var rows: Dictionary = sh.rows
		var tall := 0
		for anim in rows:
			tall = maxi(tall, rows[anim][0] + rows[anim][1])
		var sheet := Image.create(FRAME * 8, FRAME * tall, false, Image.FORMAT_RGBA8)
		for face in 8:
			pivot.rotation.y = _yaw(face)
			for anim in rows:
				var r: Array = rows[anim]
				var clip: String = anims[anim]
				var span: Array = cfg.get("span", {}).get(anim, [0.0, ap.get_animation(clip).length])
				var at := _sample_times(span, r[1], release.get(clip, -1.0))
				if release.has(clip):
					rel_frames[anim] = at.find(float(release[clip]))
				for f in r[1]:
					ap.play(clip)
					ap.seek(at[f], true)
					ap.pause()
					await process_frame
					if held:
						_hold(held, skel, cfg.held)
					await process_frame
					await RenderingServer.frame_post_draw
					var img := _shrink(vp.get_texture().get_image())
					if painted:
						img = _soft_outline(img)
					else:
						_outline(img)
					sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(face * FRAME, (r[0] + f) * FRAME))
					if not r[3]:
						# every one-shot row records its tip; the fire row keeps its old "<facing>_<frame>" keys
						var tip := _tip(muzzle, weapon, face)
						var key := "%d_%d" % [face, f] if anim == "fire" else "%s_%d_%d" % [anim, face, f]
						tips[key] = [snappedf(tip.x, 0.1), snappedf(tip.y, 0.1)]
		sheet.save_png("res://assets/heroes/%s.png" % sh.name)
	_frames_tres(out, [sheets[0]], "res://art/heroes/%s.tres" % out)
	if sheets.size() > 1:
		_frames_tres(out, sheets.slice(1), "res://art/heroes/%s_extra.tres" % out)
	if rel_frames.size():
		tips["release"] = rel_frames
	var f := FileAccess.open(dir + "muzzle.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(tips, "\t"))
	f.close()
	var first: Array = []
	for face in 8:
		first.append_array(tips["%d_0" % face])
	print("render_hero: wrote %s; HeroData.muzzle = PackedVector2Array(%s)" % [out, ", ".join(first.map(func(v): return str(v)))])
	quit()


## When to take n frames from a clip's span: evenly spaced, and if the clip has a release time, shifted so one frame
## lands exactly on it (the frame the spell spawns on), kept inside the span.
func _sample_times(span: Array, n: int, rel: float) -> Array:
	var step: float = (span[1] - span[0]) / n
	var at := []
	var shift := 0.0
	if rel >= span[0] and rel <= span[1]:
		var k := roundi((rel - span[0]) / step)
		shift = rel - (span[0] + k * step)
	for f in n:
		at.append(clampf(span[0] + f * step + shift, span[0], span[1]))
	if rel >= span[0] and rel <= span[1]:
		at[roundi((rel - span[0]) / step)] = rel # exactly, so it can be found again
	return at


## Adds the first clip of a separate animation file (same skeleton) to the model's player, as "ext/<name>".
func _import_clip(ap: AnimationPlayer, path: String, name: String) -> String:
	var src := (load(path) as PackedScene).instantiate()
	var sp: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	var a: Animation = sp.get_animation(sp.get_animation_list()[0]).duplicate()
	src.free()
	if not ap.has_animation_library("ext"):
		ap.add_animation_library("ext", AnimationLibrary.new())
	ap.get_animation_library("ext").add_animation(name, a)
	return "ext/" + name


## Pins the root bone's sideways position to where it starts, so the hero walks on the spot. Height is kept.
func _lock_root(a: Animation, bone: String) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(a.track_get_path(t)).ends_with(":" + bone):
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var p: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))


## Puts the held weapon in the grip hand, its barrel pointing through the support hand.
func _hold(held: Node3D, skel: Skeleton3D, cfg: Dictionary) -> void:
	var grip := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(cfg.grip)).origin
	var support := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(cfg.support)).origin
	var dir := (support - grip).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK
	var b := Basis.looking_at(dir, up) * Basis(Vector3.UP, deg_to_rad(cfg.get("turn", 0.0)))
	held.global_transform = Transform3D(b, grip)


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
	if painted:
		# soft studio light like the map's sprites: warm key from the top left, a cool pink-violet rim from behind
		# on the right (the neon city), and a brighter, slightly warm ambient so shadows stay colourful
		sun.light_color = Color(1.0, 0.95, 0.9)
		sun.light_energy = 1.35
		env.ambient_light_color = Color(0.78, 0.7, 0.85)
		env.ambient_light_energy = 0.6
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-20, 140, 0)
		rim.light_color = Color(1.0, 0.45, 0.85)
		rim.light_energy = 0.8
		vp.add_child(rim)
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
				if painted:
					t.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					t.metallic = 0.0
					t.roughness = maxf(t.roughness, 0.6)
					t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				else:
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
			if painted:
				if a > 0.0:
					out.set_pixel(x, y, Color(r / a, g / a, b / a, a / n))
			elif a / n >= 0.45:
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


## Painted style: a soft dark line around the silhouette, about one screen pixel wide, drawn under the hero.
func _soft_outline(img: Image) -> Image:
	var out := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	var line := OUTLINE.lerp(Color(0.2, 0.08, 0.25), 0.3)
	for y in FRAME:
		for x in FRAME:
			var a := 0.0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < FRAME and p.y < FRAME:
					a = maxf(a, img.get_pixelv(p).a * (1.0 if d.x == 0 or d.y == 0 else 0.7))
			var c := img.get_pixel(x, y)
			var under := Color(line, a * 0.85)
			# hero over the outline ("over" compositing, straight alpha)
			var oa := c.a + under.a * (1.0 - c.a)
			if oa > 0.0:
				var rgb := (Color(c.r, c.g, c.b) * c.a + Color(under.r, under.g, under.b) * under.a * (1.0 - c.a)) / oa
				out.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, oa))
	return out


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


## Writes a SpriteFrames to `path`: <anim>_N for each facing N and each row set of `sheets` (see _run), cut from
## that sheet's PNG.
func _frames_tres(out: String, sheets: Array, path: String) -> void:
	var subs := PackedStringArray()
	var anims := PackedStringArray()
	var exts := PackedStringArray()
	var id := 0
	for si in sheets.size():
		exts.append('[ext_resource type="Texture2D" path="res://assets/heroes/%s.png" id="%d"]' % [sheets[si].name, si + 1])
		var rows: Dictionary = sheets[si].rows
		for face in 8:
			for anim in rows:
				var r: Array = rows[anim]
				var refs := PackedStringArray()
				for f in r[1]:
					id += 1
					subs.append('[sub_resource type="AtlasTexture" id="A%d"]\natlas = ExtResource("%d")\nregion = Rect2(%d, %d, %d, %d)\n' % [id, si + 1, face * FRAME, (r[0] + f) * FRAME, FRAME, FRAME])
					refs.append('{\n"duration": 1.0,\n"texture": SubResource("A%d")\n}' % id)
				anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%d",\n"speed": %.1f\n}' % [", ".join(refs), "true" if r[3] else "false", anim, face, r[2]])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (id + 1 + sheets.size()))
	f.store_string("\n".join(exts) + "\n\n")
	f.store_string("\n".join(subs))
	f.store_string("\n[resource]\nanimations = [%s]\n" % ", ".join(anims))
	f.close()
