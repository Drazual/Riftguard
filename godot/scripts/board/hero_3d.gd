class_name Hero3D
extends Node2D
## A hero drawn live from its 3D model instead of a sprite sheet. The model is rendered every frame into a small
## transparent viewport by an orthographic camera at the board's 3/4 angle, and the picture is drawn on the board.
## So the hero turns smoothly to any angle, aims exactly at its target, and blends between idle, walk and fire.
## It reads the same hero.json as tools/render_hero.gd (model, animation files, held weapon, root lock), from the
## folder in HeroData.model_dir. Painted look: soft lambert-wrap light, warm key, pink neon rim, dark outline.

const PITCH := 35.0 # how far the camera looks down (flatter than the ground's tilt, so heroes read from the front)
const K := 0.75 # Board.K: the ground's vertical squash; facings go through it so they match the screen
const Q := 2 # render at 2x board pixels and draw at half size, for detail on big screens
const BOX := Vector2(128, 128) # the viewport in board pixels
const FEET := Vector2(64, 112) # where the hero's feet land in the viewport, in board pixels
const OUTLINE := Color(0.13, 0.06, 0.2)
const LINE_W := 0.014 # outline thickness, in world units of a 1.8-unit hero

var vp: SubViewport
var cam: Camera3D
var model: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var held: Node3D
var muzzle: Node3D
var cfg: Dictionary
var anims := {}
var pic: Sprite2D
var yaw := 0.0 # the model's current turn, eased toward the wanted one
var want_yaw := 0.0
var aim_fix := 0.0 # extra turn while shooting so the barrel, not the body, points at the target
var state := ""
var fitted := false
var tall := 38.0
var lines: Array[StandardMaterial3D] = [] # the model's outline materials (their width follows its scale)


## dir: the hero's source folder (with hero.json). tall: the hero's height on the board, in pixels.
func setup(dir: String, height: float = 38.0) -> void:
	tall = height
	cfg = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("hero.json")))
	vp = SubViewport.new()
	vp.size = Vector2i(BOX * Q)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	_lights()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var p := deg_to_rad(PITCH)
	cam.rotation = Vector3(-p, 0, 0)
	# a 1.8-unit hero stands 1.8 * cos(pitch) units tall on screen, which should be `tall` board pixels
	var units_per_px := 1.8 * cos(p) / tall
	cam.size = BOX.y * units_per_px
	cam.position = Vector3(0, sin(p), cos(p)) * 20.0
	var up := Vector3(0, cos(p), -sin(p))
	cam.position += up * (FEET.y - BOX.y / 2) * units_per_px
	cam.position += Vector3.RIGHT * -(FEET.x - BOX.x / 2) * units_per_px
	cam.near = 0.1
	cam.far = 60.0
	vp.add_child(cam)
	cam.current = true
	model = (load(dir.path_join(cfg.model)) as PackedScene).instantiate()
	vp.add_child(model)
	for n in cfg.get("hide", []):
		var h := model.find_child(n, true, false)
		if h:
			h.visible = false
	ap = model.find_child("AnimationPlayer", true, false)
	skel = model.find_child("Skeleton3D", true, false)
	for a in cfg.anims:
		var clip: String = cfg.anims[a]
		if clip.get_extension() in ["fbx", "glb", "gltf"]:
			clip = _import_clip(dir.path_join(clip), a)
		var anim := ap.get_animation(clip)
		if cfg.has("lock_root"):
			_lock_root(anim, cfg.lock_root)
		anim.loop_mode = Animation.LOOP_NONE if a == "fire" else Animation.LOOP_LINEAR
		anims[a] = clip
	# a shooting clip that steps around (Mixamo's "Firing Rifle" does) would make him walk on the spot when he
	# shoots standing still, so his legs and hips keep the idle pose while his upper body fires
	if cfg.get("fire_legs", "") == "idle" and anims.has("fire") and anims.has("idle"):
		_legs_from(ap.get_animation(anims.fire), ap.get_animation(anims.idle))
	if cfg.has("held"):
		held = (load(dir.path_join(cfg.held.scene)) as PackedScene).instantiate()
		vp.add_child(held)
	muzzle = (held if held else model).find_child("Muzzle", true, false)
	_paint(model)
	var model_lines := lines.duplicate()
	if held:
		_paint(held)
	lines = model_lines # the weapon isn't rescaled, so its outline keeps LINE_W
	pic = Sprite2D.new()
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = Vector2.ONE / Q
	pic.position = -FEET
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(pic)
	play("idle")


## Soft painted light like the map's sprites: a warm key from the top left, a pink-violet neon rim from behind
## on the right, and a bright, slightly warm ambient so the shadows stay colourful.
func _lights() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.7, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.light_energy = 1.35
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 140, 0)
	rim.light_color = Color(1.0, 0.45, 0.85)
	rim.light_energy = 0.8
	vp.add_child(rim)


## Soft matte shading, plus a dark outline drawn as a slightly grown back-face shell around every mesh.
func _paint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var line := StandardMaterial3D.new()
		line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.albedo_color = OUTLINE
		line.cull_mode = BaseMaterial3D.CULL_FRONT
		line.grow = true
		line.grow_amount = LINE_W
		lines.append(line)
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is StandardMaterial3D:
				var t: StandardMaterial3D = m.duplicate()
				t.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
				t.metallic = 0.0
				t.roughness = maxf(t.roughness, 0.6)
				t.next_pass = line
				mi.set_surface_override_material(i, t)
	for c in n.get_children():
		_paint(c)


## Adds the first clip of a separate animation file (same skeleton) to the model's player, as "ext/<name>".
func _import_clip(path: String, name: String) -> String:
	var src := (load(path) as PackedScene).instantiate()
	var sp: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	var a: Animation = sp.get_animation(sp.get_animation_list()[0]).duplicate()
	src.free()
	if not ap.has_animation_library("ext"):
		ap.add_animation_library("ext", AnimationLibrary.new())
	ap.get_animation_library("ext").add_animation(name, a)
	return "ext/" + name


## Replaces the leg and root (hips) tracks of `to` with those of `from`, over `to`'s length.
func _legs_from(to: Animation, from: Animation) -> void:
	for t in to.get_track_count():
		var path := String(to.track_get_path(t))
		var bone := path.get_slice(":", 1)
		var leg := bone.contains("Leg") or bone.contains("Foot") or bone.contains("Toe")
		if not leg and not bone.ends_with("Hips"):
			continue
		var src := from.find_track(to.track_get_path(t), to.track_get_type(t))
		if src < 0:
			continue
		while to.track_get_key_count(t) > 0:
			to.track_remove_key(t, 0)
		for k in from.track_get_key_count(src):
			var at := from.track_get_key_time(src, k)
			if at > to.length:
				break
			to.track_insert_key(t, at, from.track_get_key_value(src, k))


## Pins the root bone's sideways position to where it starts, so the hero walks on the spot.
func _lock_root(a: Animation, bone: String) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(a.track_get_path(t)).ends_with(":" + bone):
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var p: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))


## Plays idle, walk or fire with a short blend. Fire restarts on every call (one per shot).
func play(what: String, speed: float = 1.0) -> void:
	if not anims.has(what):
		return
	if what != state or what == "fire":
		ap.play(anims[what], 0.12)
		if what == "fire":
			ap.seek(0.0, true)
		state = what
	ap.speed_scale = speed


## Turns the hero to face a direction on screen (any angle: 0 = right, PI/2 = down the screen).
func face(screen_angle: float, instant: bool = false) -> void:
	var g := Vector2(cos(screen_angle), sin(screen_angle) / K) # on the ground: x right, y toward the camera
	want_yaw = atan2(g.x, g.y)
	if instant:
		yaw = want_yaw


func _process(dt: float) -> void:
	if model == null:
		return
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-dt * 16.0))
	if not fitted:
		_fit()
	if held:
		_hold()
	# while shooting, turn the body a little more or less so the barrel itself points at the target (a clip's
	# torso twist can otherwise aim it up to ~30 degrees off); eases back once he stops. The barrel runs from the
	# weapon's origin to its Muzzle.
	var gun: Node3D = held if held else (muzzle.get_parent() as Node3D if muzzle else null)
	var fix := 0.0
	if state == "fire" and gun:
		var m := muzzle.global_position - gun.global_position
		if Vector2(m.x, m.z).length() > 0.05:
			fix = clampf(wrapf(want_yaw - atan2(m.x, m.z) + aim_fix, -PI, PI), -0.7, 0.7)
	aim_fix = lerpf(aim_fix, fix, 1.0 - exp(-dt * 12.0))
	model.rotation.y = yaw + aim_fix


## Scales the model so it stands `tall` pixels, measured from its skeleton (head top to toes) once it is posed,
## and stands it on the origin.
func _fit() -> void:
	var top := -INF
	var low := INF
	for i in skel.get_bone_count():
		var y := (skel.global_transform * skel.get_bone_global_pose(i).origin).y
		top = maxf(top, y)
		low = minf(low, y)
	if top - low <= 0.001:
		return
	# the head-top bone sits inside the hair, so leave a little room above it
	model.scale *= 1.8 / ((top - low) * 1.08)
	model.position.y -= low * 1.8 / ((top - low) * 1.08)
	for l in lines:
		l.grow_amount = LINE_W / model.scale.x
	fitted = true


## Puts the held weapon in the grip hand, its barrel pointing through the support hand.
func _hold() -> void:
	var h: Dictionary = cfg.held
	var grip := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(h.grip)).origin
	var support := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(h.support)).origin
	var dir := (support - grip).normalized()
	if dir == Vector3.ZERO:
		return
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK
	var b := Basis.looking_at(dir, up) * Basis(Vector3.UP, deg_to_rad(h.get("turn", 0.0)))
	held.global_transform = Transform3D(b, grip)


## Where the gun tip is, in board pixels from the hero's feet.
func tip() -> Vector2:
	if muzzle == null:
		return Vector2(0, -tall * 0.6)
	return cam.unproject_position(muzzle.global_position) / Q - FEET
