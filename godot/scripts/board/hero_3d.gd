class_name Hero3D
extends Node2D
## A hero drawn live from its 3D model instead of a sprite sheet. In the unified style it stands in the board's
## shared pixel camera (StyleRig, the same one as the towers). With that style off — and for menu portraits — the
## model is rendered into its own small viewport by an orthographic camera and drawn as a sprite. Either way it
## turns to any angle, aims at its target, and blends between idle, walk and fire. It reads the same hero.json as
## tools/render_hero.gd (model, animation files, held weapon, root lock), from the folder in HeroData.model_dir.
## The own-viewport path uses the model's materials under neutral white studio light (clean_light).
## Spell casters (the Wizard) also play any of the model's one-shot clips by name with cast(): its hero.json
## "release" times say when in each clip the spell leaves, and the wind-up before it is sped up to "windup" seconds,
## since the spell itself lands the moment it is cast.

const PITCH := 35.0 # how far the camera looks down (flatter than the ground's tilt, so heroes read from the front)
const K := 0.75 # Board.K: the ground's vertical squash; facings go through it so they match the screen
const Q := 2 # render at 2x board pixels and draw at half size, for detail on big screens
const BOX := Vector2(128, 128) # the viewport in board pixels
const FEET := Vector2(64, 112) # where the hero's feet land in the viewport, in board pixels
## Heroes cover ground far faster than a walk clip steps (several body lengths a second), so the clip's leg swing is
## stretched by STRIDE for longer steps, and its pace is capped at MAX_PACE times normal; past that the feet glide.
## A hero.json can set its own "stride" and "max_pace" (a short-stepping clip wants a bigger stride and a lower cap).
const STRIDE := 1.15
const NARROW := 0.0 # degrees each thigh turns in during a walk or run (see _narrow)
const MAX_PACE := 2.2

var vp: SubViewport # its own viewport and camera (null when drawn in a shared StyleRig)
var cam: Camera3D
## Drawn in the board's one shared 3D world (StyleRig, the unified style) instead of its own viewport: the model
## stands on `anchor` there, turned with the shared camera, and this node's position (times art_per_unit) is the
## art pixel its feet stand on.
var rig: StyleRig = null
var anchor: Node3D = null
var art_per_unit := 1.0
var pitch := PITCH # the camera's look-down angle, for facings (the shared camera's is the scenery's 30)
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
var want_screen := PI / 2 # the screen angle it was last asked to face
var aim_fix := 0.0 # extra turn while shooting so the barrel, not the body, points at the target
var state := ""
var cast_rel := 0.0 # while casting: the clip time the spell leaves at; the wind-up before it plays fast
var cast_speed := 1.0
var cast_at := 0.0 # the clip time this cast lets go at (kept after cast_rel clears), for its squash and pop
var cast_spin := 0.0 # a full twirl through the wind-up (the ultimate)
var fit_scale := Vector3.ONE
var ground_y := 0.0 # the model's height before a cast's hop (eased toward base_y less the hip drop)
var fitted := false
var hover := {} # hero.json "hover": { start, stop } clips into and out of its hover_move (see play)
var tall := 26.0
## How fast the walk (and run) clips would carry the hero, in world units per second of a 1.8-unit hero, measured
## from the clip: twice the forward-and-back swing of one foot (relative to the hips) per cycle, over its length.
var walk_speed := 1.0
var run_speed := 0.0
var kick := 0.0 # recoil left from the last shot, 1 right after it, easing to 0 (hero.json "kick": degrees of lean)
var base_y := 0.0 # the model's height offset once fitted, before the walk's hip drop
var ankle := 0.0 # how high the ankles sit when standing, so longer strides can lower the hips to keep feet down


## dir: the hero's source folder (with hero.json). tall: the hero's height on the board, in pixels.
## shared: draw it in that StyleRig's world (the unified style) instead of its own viewport; per_unit: art pixels
## per unit of this node's position.
func setup(dir: String, height: float = 26.0, shared: StyleRig = null, per_unit := 1.0) -> void:
	tall = height
	cfg = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("hero.json")))
	if shared:
		rig = shared
		art_per_unit = per_unit
		pitch = StyleRig.PITCH
		_setup_model(dir)
		return
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
	_setup_model(dir)


func _setup_model(dir: String) -> void:
	model = (load(dir.path_join(cfg.model)) as PackedScene).instantiate()
	# per-hero toon knobs (hero.json "style_overrides"), read by StyleRig. Empty for heroes that use the globals.
	if cfg.get("style_overrides") is Dictionary:
		model.set_meta("style_overrides", cfg.style_overrides)
	if rig:
		anchor = rig.add_model(model, 0.42, true)
	else:
		vp.add_child(model)
	for n in cfg.get("hide", []):
		var h := model.find_child(n, true, false)
		if h:
			h.visible = false
	ap = model.find_child("AnimationPlayer", true, false)
	skel = model.find_child("Skeleton3D", true, false)
	# the clips below are reshaped in place (stretched strides, narrower legs, locked roots...), and an imported
	# model's clips are shared by every copy of it, so each hero gets its own copies first: a second hero (a new
	# run, a preview) would otherwise reshape them again on top
	for lib_name in ap.get_animation_library_list():
		var lib: AnimationLibrary = ap.get_animation_library(lib_name).duplicate(true)
		ap.remove_animation_library(lib_name)
		ap.add_animation_library(lib_name, lib)
	# clips posed from the idle stance (hero.json "poses"), named "@<pose>" in "anims"
	for pose in cfg.get("poses", {}):
		if not ap.has_animation_library("ext"):
			ap.add_animation_library("ext", AnimationLibrary.new())
		ap.get_animation_library("ext").add_animation(pose, _posed(cfg.poses[pose]))
	# a hovering hero (hero.json "hover": its "start" and "stop" clips): no strides to stretch or legs to narrow, and
	# its mesh floats where it was made to (never pulled down to the ground)
	hover = cfg.get("hover", {})
	for a in cfg.anims:
		var clip: String = cfg.anims[a]
		var posed := clip.begins_with("@")
		if posed:
			clip = "ext/" + clip.substr(1)
		elif clip.get_extension() in ["fbx", "glb", "gltf"]:
			clip = _import_clip(dir.path_join(clip), a)
		var anim := ap.get_animation(clip)
		if cfg.has("lock_root") and not posed:
			_lock_root(anim, cfg.lock_root)
		anim.loop_mode = Animation.LOOP_NONE if a == "fire" else Animation.LOOP_LINEAR
		if (a == "walk" or a == "run") and not posed and not hover:
			_stretch(anim, cfg.get("stride", STRIDE))
			_narrow(anim, float(cfg.get("narrow", NARROW)))
		# a firing clip that lowers the gun after the shot is cut where the gun is still up, so firing again and
		# again keeps it raised (each shot restarts the clip, and it holds its last pose between shots)
		if a == "fire" and cfg.has("fire_end"):
			_trim(anim, cfg.fire_end)
		anims[a] = clip
	# a shooting clip that steps around (Mixamo's "Firing Rifle" does) would make him walk on the spot when he
	# shoots standing still, so his legs and hips keep the idle pose while his upper body fires
	if cfg.get("fire_legs", "") == "idle" and anims.has("fire") and anims.has("idle"):
		_legs_from(ap.get_animation(anims.fire), ap.get_animation(anims.idle))
	# a model with only a walk can run: hero.json "run_from_walk" makes one out of it (see _run_from)
	if cfg.has("run_from_walk") and anims.has("walk") and not anims.has("run"):
		var run := _run_from(ap.get_animation(anims.walk), cfg.run_from_walk)
		if not ap.has_animation_library("ext"):
			ap.add_animation_library("ext", AnimationLibrary.new())
		ap.get_animation_library("ext").add_animation("run", run)
		anims.run = "ext/run"
	# one-shot casts (every clip named in "release"): root locked like the rest, played once
	for clip in cfg.get("release", {}):
		if ap.has_animation(clip):
			var anim := ap.get_animation(clip)
			if cfg.has("lock_root"):
				_lock_root(anim, cfg.lock_root)
			anim.loop_mode = Animation.LOOP_NONE
			if cfg.has("cast_big"):
				_exaggerate(anim, float(cfg.cast_big))
	# shooting on the move: the walk's legs and hips with the fire clip's raised, aimed upper body (not for a
	# caster, whose "fire" is a whole-body cast: "walkfire": false)
	if anims.has("walk") and anims.has("fire") and cfg.get("walkfire", true):
		var wf := _upper_from(ap.get_animation(anims.walk), ap.get_animation(anims.fire))
		if not ap.has_animation_library("ext"):
			ap.add_animation_library("ext", AnimationLibrary.new())
		ap.get_animation_library("ext").add_animation("walkfire", wf)
		anims.walkfire = "ext/walkfire"
	if cfg.has("held"):
		held = (load(dir.path_join(cfg.held.scene)) as PackedScene).instantiate()
		(anchor if rig else vp).add_child(held)
	muzzle = (held if held else model).find_child(cfg.get("muzzle", "Muzzle"), true, false)
	# cosmetic SkeletonModifier3D scripts the model ships with (hero.json "modifiers"), run after its clips under the
	# Skeleton3D: the Oracle's orb crystal keeps spinning across every clip change
	for path in cfg.get("modifiers", []):
		var mod: Node = (load(dir.path_join(path)) as Script).new()
		skel.add_child(mod)
	if rig:
		# the shared rig styles it (its own materials when the style's stylize is off), and draws it
		if held:
			if model.has_meta("style_overrides"):
				held.set_meta("style_overrides", model.get_meta("style_overrides"))
			rig.add_styled(held)
		play("idle")
		return
	_paint(model)
	if held:
		_paint(held)
	pic = Sprite2D.new()
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = Vector2.ONE / Q
	pic.position = -FEET
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(pic)
	play("idle")


## Neutral studio light, so a model looks as it does in a model viewer: a white key from the top left, a soft white
## fill from the right, white ambient, and a plain grey sky for metal to reflect (it isn't drawn: the background stays
## clear). Shared with tools/render_hero.gd and tools/render_tower.gd.
static func clean_light(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.78, 0.8, 0.84)
	sm.sky_horizon_color = Color(0.82, 0.82, 0.82)
	sm.ground_horizon_color = Color(0.6, 0.6, 0.6)
	sm.ground_bottom_color = Color(0.32, 0.32, 0.32)
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.15
	parent.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 60, 0)
	fill.light_energy = 0.35
	parent.add_child(fill)


## In the shared world: stands the model where this node is now (the board calls it after moving the hero, so the
## model doesn't trail a frame behind the 2D board).
func place_now() -> void:
	if anchor:
		anchor.visible = is_visible_in_tree()
		rig.place_art(anchor, position * art_per_unit)


func _exit_tree() -> void:
	if anchor and is_instance_valid(anchor) and is_queued_for_deletion():
		anchor.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and anchor and is_instance_valid(anchor):
		anchor.queue_free()


func _lights() -> void:
	clean_light(vp)


## The model keeps its own materials. Only the texture filtering is set, so the textures stay smooth at board size.
func _paint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var t: BaseMaterial3D = m.duplicate()
				t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


## A copy of `walk` whose upper body (everything but the legs and hips) holds `fire`'s last pose.
func _upper_from(walk: Animation, fire: Animation) -> Animation:
	var a: Animation = walk.duplicate(true)
	for t in a.get_track_count():
		var path := a.track_get_path(t)
		var bone := String(path).get_slice(":", 1)
		if bone.contains("Leg") or bone.contains("Foot") or bone.contains("Toe") or bone.ends_with("Hips"):
			continue
		var type := a.track_get_type(t)
		var src := fire.find_track(path, type)
		if src < 0:
			continue
		var at := fire.length
		var v: Variant
		match type:
			Animation.TYPE_ROTATION_3D:
				v = fire.rotation_track_interpolate(src, at)
			Animation.TYPE_POSITION_3D:
				v = fire.position_track_interpolate(src, at)
			Animation.TYPE_SCALE_3D:
				v = fire.scale_track_interpolate(src, at)
			_:
				continue
		while a.track_get_key_count(t) > 0:
			a.track_remove_key(t, 0)
		a.track_insert_key(t, 0.0, v)
	return a


## Swings the legs further each step: every leg-bone rotation is pushed away from that bone's average pose
## over the clip by `k`, so the strides get longer while the rhythm stays the same.
func _stretch(a: Animation, k: float) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(t)).get_slice(":", 1)
		if not (bone.contains("UpLeg") or bone.ends_with("Leg") or bone.contains("Foot")):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var q0: Quaternion = a.track_get_key_value(t, 0)
		var sum := Quaternion(0, 0, 0, 0)
		for i in n:
			var q: Quaternion = a.track_get_key_value(t, i)
			if q.dot(q0) < 0:
				q = -q
			sum = Quaternion(sum.x + q.x, sum.y + q.y, sum.z + q.z, sum.w + q.w)
		var mean := sum.normalized()
		for i in n:
			var q: Quaternion = a.track_get_key_value(t, i)
			var d := mean.inverse() * q
			if d.w < 0:
				d = -d
			var ang := d.get_angle()
			if ang < 0.0001 or Vector3(d.x, d.y, d.z).length_squared() < 1e-12:
				continue
			a.track_set_key_value(t, i, (mean * Quaternion(d.get_axis().normalized(), ang * k)).normalized())


## Bigger, cartoonier casts: every upper-body bone (spine, neck, head, arms, hands) swings `k` times as far from
## the clip's first pose (the stance it starts from), so the staff goes higher, the lean deeper and the throw wider.
## The extra is capped at about 30 degrees a bone, so the big swings keep their shape instead of folding over.
func _exaggerate(a: Animation, k: float) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(t)).get_slice(":", 1)
		if not (bone.contains("Spine") or bone.contains("Neck") or bone.contains("Head") or bone.contains("Shoulder") \
				or bone.contains("Arm") or bone.ends_with("Hand")):
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var q0: Quaternion = a.track_get_key_value(t, 0)
		for i in range(1, n):
			var q: Quaternion = a.track_get_key_value(t, i)
			var d := q0.inverse() * q
			if d.w < 0:
				d = -d
			var ang := d.get_angle()
			if ang < 0.0001 or Vector3(d.x, d.y, d.z).length_squared() < 1e-12:
				continue
			a.track_set_key_value(t, i, (q0 * Quaternion(d.get_axis().normalized(), ang + minf(ang * (k - 1.0), 0.5))).normalized())


## Brings the legs closer together in a walk or run: each thigh turns `deg` degrees in toward the other about the
## model's forward axis, and each foot turns back as far so its sole stays flat, so the feet land close under the
## body instead of in a wide waddle (hero.json "narrow", 0 to keep the clip's own width).
func _narrow(a: Animation, deg: float) -> void:
	if deg == 0.0:
		return
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(a.track_get_path(t)).get_slice(":", 1)
		var side := "Left" if bone.contains("Left") else ("Right" if bone.contains("Right") else "")
		var foot := bone.ends_with("Foot")
		if side == "" or not (bone.ends_with("UpLeg") or foot):
			continue
		var b := skel.find_bone(bone)
		var par := skel.get_bone_parent(b)
		if b < 0 or par < 0:
			continue
		# which way is in, from the rest pose itself (so whichever way the skeleton faces): the thigh swings its
		# foot toward the middle of the body, about the axis square to the leg and to the hips' sideways line
		var up := skel.find_bone(bone.replace("Foot", "UpLeg")) if foot else b
		var hip := skel.get_bone_parent(up)
		var lower := skel.find_bone(bone.replace("UpLeg", "Leg")) if not foot else b
		if up < 0 or hip < 0 or lower < 0:
			continue
		var at := skel.get_bone_global_rest(up).origin
		var mid := skel.get_bone_global_rest(hip).origin
		var leg := (skel.get_bone_global_rest(lower).origin - at).normalized()
		var side_in := mid - at
		side_in -= leg * side_in.dot(leg)
		var axis := leg.cross(side_in)
		if axis.length() < 1e-5:
			continue
		var turn := Quaternion(axis.normalized(), deg_to_rad(deg))
		if foot:
			turn = turn.inverse()
		var pq := skel.get_bone_global_rest(par).basis.get_rotation_quaternion()
		var local := pq.inverse() * turn * pq
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, (local * (a.track_get_key_value(t, k) as Quaternion)).normalized())


## A run made from a walk: the legs swing `stride` times further (on top of the walk's own stretch), the upper body
## leans `lean` degrees forward, and the hips bob up `bounce` metres between footfalls (twice a cycle).
## { "stride": 1.4, "lean": 12, "bounce": 0.04 }
func _run_from(walk: Animation, c: Dictionary) -> Animation:
	var a: Animation = walk.duplicate(true)
	_stretch(a, float(c.get("stride", 1.4)))
	var lean := deg_to_rad(float(c.get("lean", 12.0)))
	var bounce := float(c.get("bounce", 0.04))
	var spine := String(c.get("spine", "mixamorig_Spine"))
	var hips := String(cfg.get("lock_root", "mixamorig_Hips"))
	for t in a.get_track_count():
		var bone := String(a.track_get_path(t)).get_slice(":", 1)
		var type := a.track_get_type(t)
		if bone == spine and type == Animation.TYPE_ROTATION_3D and lean != 0.0:
			# tip forward about the skeleton's sideways axis (the model faces +Z), turned into the bone's own space
			var b := skel.find_bone(bone)
			var par := skel.get_bone_parent(b)
			var pq := skel.get_bone_global_rest(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
			var tilt := pq.inverse() * Quaternion(Vector3.RIGHT, lean) * pq
			for k in a.track_get_key_count(t):
				a.track_set_key_value(t, k, (tilt * (a.track_get_key_value(t, k) as Quaternion)).normalized())
		elif bone == hips and type == Animation.TYPE_POSITION_3D and bounce != 0.0:
			for k in a.track_get_key_count(t):
				var at := a.track_get_key_time(t, k)
				var s := sin(TAU * at / a.length)
				var p: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, p + Vector3(0, bounce * s * s, 0))
	return a


## A clip posed by hand from the idle stance (the first frame of the model's "idle", or of "base"), for a model whose own clips lack a move
## (the Vanguard's run, punch and shield brace). c: { "length": s, "loop": bool, "keys": [{ "t": s, "bones":
## { "LeftArm": [x, y, z], ... }, "hips": [x, y, z] }, ...], "copy": { "clip": name, "bones": [names] } }.
## A bone's [x, y, z] (degrees) turns it about the model's own axes (x sideways: + tips a hanging limb back and the
## spine forward; y up: + turns the right shoulder forward; z forward) on top of wherever its parent carried it, so
## a bent knee rides along with its thigh. "hips" moves the hips (metres). Bone names leave off the "mixamorig_"
## prefix. Bones it doesn't name hold the idle stance (or "fill_from"'s first frame, for bones idle has no track
## for); "copy" takes some bones' tracks whole from another clip (the Bulwark glow; "fit": true squeezes them to
## this clip's length, so a looping effect still loops); a bone in "keep" holds its idle facing in the world (plus its
## own turn), so a shield or sword in that hand stays as it is held however the arm swings. Keys ease into each other.
func _posed(c: Dictionary) -> Animation:
	var idle := ap.get_animation(c.get("base", "idle"))
	var a: Animation = idle.duplicate(true)
	a.length = float(c.length)
	a.loop_mode = Animation.LOOP_LINEAR if c.get("loop", false) else Animation.LOOP_NONE
	var pre := "mixamorig_" if skel.find_bone("mixamorig_Hips") >= 0 else ""
	var hips := String(cfg.get("lock_root", pre + "Hips"))
	# every track holds its idle value from the first frame
	for t in a.get_track_count():
		var v: Variant = null
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				v = idle.rotation_track_interpolate(t, 0.0)
			Animation.TYPE_POSITION_3D:
				v = idle.position_track_interpolate(t, 0.0)
			Animation.TYPE_SCALE_3D:
				v = idle.scale_track_interpolate(t, 0.0)
		if v == null:
			continue
		while a.track_get_key_count(t) > 0:
			a.track_remove_key(t, 0)
		a.track_insert_key(t, 0.0, v)
	var prefix := String(a.track_get_path(0)).get_slice(":", 0)
	# a bone the idle clip leaves alone (its import dropped the unchanging track) takes its value from the first
	# frame of "fill_from" (a clip that starts in the idle stance), so an effect bone stays as it is in idle
	if c.has("fill_from") and ap.has_animation(c.fill_from):
		var src := ap.get_animation(c.fill_from)
		for t in src.get_track_count():
			var type := src.track_get_type(t)
			if a.find_track(src.track_get_path(t), type) >= 0 or src.track_get_key_count(t) == 0:
				continue
			var v: Variant = src.track_get_key_value(t, 0)
			var nt := a.add_track(type)
			a.track_set_path(nt, src.track_get_path(t))
			a.track_insert_key(nt, 0.0, v)
	var track := func(bone: String, type: int) -> int:
		var path := NodePath(prefix + ":" + bone)
		var t := a.find_track(path, type)
		if t < 0:
			t = a.add_track(type)
			a.track_set_path(t, path)
		return t
	# the idle stance: each bone's own rotation and the hips' position
	var base: Array[Quaternion] = []
	for i in skel.get_bone_count():
		var t := idle.find_track(NodePath(prefix + ":" + skel.get_bone_name(i)), Animation.TYPE_ROTATION_3D)
		base.append(idle.rotation_track_interpolate(t, 0.0) if t >= 0 else skel.get_bone_rest(i).basis.get_rotation_quaternion())
	var ht := idle.find_track(NodePath(prefix + ":" + hips), Animation.TYPE_POSITION_3D)
	var hips0: Vector3 = idle.position_track_interpolate(ht, 0.0) if ht >= 0 else skel.get_bone_rest(skel.find_bone(hips)).origin
	var keep: Array = c.get("keep", [])
	var idle_glob: Array[Quaternion] = []
	for i in skel.get_bone_count():
		var par := skel.get_bone_parent(i)
		idle_glob.append((idle_glob[par] if par >= 0 else Quaternion.IDENTITY) * base[i])
	var moved := {}
	for b in keep:
		moved[skel.find_bone(pre + b)] = true
	for k in c["keys"]:
		for b in k.get("bones", {}):
			moved[skel.find_bone(pre + b)] = true
	moved.erase(-1)
	var keys: Array = c["keys"].duplicate()
	if c.get("loop", false) and keys.size() and float(keys[-1].t) < a.length:
		var last: Dictionary = keys[0].duplicate()
		last.t = a.length
		keys.append(last)
	var cleared := {}
	for k in keys:
		var at := float(k.t)
		var glob: Array[Quaternion] = []
		glob.resize(skel.get_bone_count())
		for i in skel.get_bone_count():
			var par := skel.get_bone_parent(i)
			var pg := glob[par] if par >= 0 else Quaternion.IDENTITY
			var local := base[i]
			var name := skel.get_bone_name(i).trim_prefix(pre)
			var d: Array = k.get("bones", {}).get(name, [])
			var turn := Quaternion.IDENTITY
			if d.size() == 3:
				turn = Quaternion.from_euler(Vector3(deg_to_rad(d[0]), deg_to_rad(d[1]), deg_to_rad(d[2])))
			if name in keep:
				# keeps its idle facing in the world whatever the arm does (the shield stays upright)
				local = (pg.inverse() * turn * idle_glob[i]).normalized()
			elif d.size() == 3:
				local = (pg.inverse() * turn * pg * local).normalized()
			glob[i] = pg * local
			if moved.has(i):
				var t: int = track.call(skel.get_bone_name(i), Animation.TYPE_ROTATION_3D)
				if not cleared.has(t):
					cleared[t] = true
					while a.track_get_key_count(t) > 0:
						a.track_remove_key(t, 0)
					a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
				a.track_insert_key(t, at, local)
		var hp: Array = k.get("hips", [0, 0, 0])
		var t: int = track.call(hips, Animation.TYPE_POSITION_3D)
		if not cleared.has(t):
			cleared[t] = true
			while a.track_get_key_count(t) > 0:
				a.track_remove_key(t, 0)
			a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
		a.track_insert_key(t, at, hips0 + Vector3(hp[0], hp[1], hp[2]))
	var cp: Dictionary = c.get("copy", {})
	if cp.has("clip") and ap.has_animation(cp.clip):
		var src := ap.get_animation(cp.clip)
		for b in cp.get("bones", []):
			for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
				var st := src.find_track(NodePath(prefix + ":" + b), type)
				if st < 0:
					continue
				var t: int = track.call(b, type)
				while a.track_get_key_count(t) > 0:
					a.track_remove_key(t, 0)
				# "fit": squeeze or stretch the source to this clip's length, so a looping effect loops with it
				var k := a.length / src.length if cp.get("fit", false) and src.length > 0 else 1.0
				for i in src.track_get_key_count(st):
					if src.track_get_key_time(st, i) * k <= a.length + 0.0001:
						a.track_insert_key(t, src.track_get_key_time(st, i) * k, src.track_get_key_value(st, i))
	return a


## Cuts a clip off at `end` seconds.
func _trim(a: Animation, end: float) -> void:
	if end <= 0.0 or end >= a.length:
		return
	for t in a.get_track_count():
		for i in range(a.track_get_key_count(t) - 1, -1, -1):
			if a.track_get_key_time(t, i) > end + 0.0001:
				a.track_remove_key(t, i)
	a.length = end


## Pins the root bone's sideways position to where it starts, so the hero walks on the spot.
func _lock_root(a: Animation, bone: String) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(a.track_get_path(t)).ends_with(":" + bone):
			continue
		var p0: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var p: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(p0.x, p.y, p0.z))


## Plays idle, walk or fire (or a hero's extra looping stances: "block", "hold") with a short blend. Fire restarts on
## every call (one per shot). A cast or swing still playing isn't cut short by standing still, nor a cast by a shot
## (only by walking or another cast).
func play(what: String, speed: float = 1.0) -> void:
	if not anims.has(what):
		return
	# a cast, or a melee swing, still playing isn't cut short by standing still (idle, a block or a held guard)
	if (state == "cast" or state == "fire") and what in ["idle", "block", "hold"] and ap.is_playing() \
			or state == "cast" and what == "fire" and ap.is_playing():
		if state == "cast":
			cast_speed = speed
		return
	cast_rel = 0.0
	if not hover.is_empty() and what != state and (what == "walk" and state != "walk" or what == "idle" and state == "walk"):
		# into the hover_move through hover_start, back to the idle hover through hover_stop
		var via: String = hover.get("start" if what == "walk" else "stop", "")
		if ap.has_animation(via):
			ap.play(via, 0.12)
			ap.queue(anims[what])
			state = what
			ap.speed_scale = speed
			return
	if what != state or what == "fire":
		ap.play(anims[what], 0.0 if what == state else 0.12)
		if what == "fire":
			ap.seek(0.0, true)
			kick = 1.0
		state = what
	ap.speed_scale = speed


## Plays a one-shot clip of the model by name (a spell cast), from the start, with a short blend. Up to its
## release time (hero.json "release") it plays fast enough to reach it in "windup" seconds, then at `speed`.
func cast(clip: String, speed: float = 1.0) -> void:
	if not ap.has_animation(clip):
		play("fire", speed)
		return
	ap.play(clip, 0.08)
	ap.seek(0.0, true)
	state = "cast"
	cast_speed = speed
	cast_rel = float(cfg.get("release", {}).get(clip, 0.0))
	cast_at = cast_rel if cast_rel > 0.0 else ap.get_animation(clip).length * 0.35
	cast_spin = TAU if clip == "cast_ultimate" and cfg.has("cast_big") else 0.0
	ap.speed_scale = speed * _windup_rate()


func _windup_rate() -> float:
	var w := float(cfg.get("windup", 0.0))
	if cast_rel <= 0.0 or w <= 0.0:
		return 1.0
	return maxf(1.0, cast_rel / w)


## Raises the gun and holds it on target between shots (the fire clip's last pose), without shooting.
func aim() -> void:
	if state == "fire" or state == "cast" or not anims.has("fire") or not cfg.get("walkfire", true):
		return
	ap.play(anims.fire, 0.12)
	ap.seek(ap.get_animation(anims.fire).length, true)
	ap.speed_scale = 1.0
	state = "fire"


## Turns the hero to face a direction on screen (any angle: 0 = right, PI/2 = down the screen).
func face(screen_angle: float, instant: bool = false) -> void:
	# on the ground (x right, y toward the camera), through this camera's own tilt so it matches on screen
	want_screen = screen_angle
	var g := Vector2(cos(screen_angle), sin(screen_angle) / sin(deg_to_rad(pitch)))
	want_yaw = atan2(g.x, g.y)
	if instant:
		yaw = want_yaw


func _process(dt: float) -> void:
	if model == null:
		return
	place_now()
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-dt * 16.0))
	if state == "cast" and cast_rel > 0.0:
		if ap.current_animation_position >= cast_rel:
			cast_rel = 0.0
			ap.speed_scale = cast_speed
		else:
			# fast up to the release, but never so fast that one slow frame skips past it (and the whole clip)
			var left := (cast_rel - ap.current_animation_position) / maxf(dt, 1.0 / 60.0)
			ap.speed_scale = cast_speed * clampf(left, 1.0, _windup_rate())
	if not fitted:
		_fit()
	if held:
		_hold()
	# while shooting, turn the body a little more or less so the barrel itself points at the target (a clip's
	# torso twist can otherwise aim it up to ~30 degrees off); eases back once he stops. The barrel runs from the
	# weapon's origin to its Muzzle.
	var gun: Node3D = held if held else (muzzle.get_parent() as Node3D if muzzle else null)
	var fix := 0.0
	if (state == "fire" or state == "walkfire") and gun:
		var m := muzzle_at() - _on_bone(gun)
		if m.length() > 0.05:
			fix = clampf(aim_fix + _barrel_turn(m), -1.2, 1.2)
	aim_fix = lerpf(aim_fix, fix, 1.0 - exp(-dt * 12.0))
	model.rotation.y = yaw + aim_fix
	# recoil: each shot rocks the hero back on its heels and nudges it back a step, then it settles
	kick = maxf(0.0, kick - dt * 5.0)
	var k := kick * kick * float(cfg.get("kick", 0.0))
	model.rotation.x = -deg_to_rad(k)
	var back := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y)) * -k * 0.006
	model.position.x = back.x
	model.position.z = back.z
	# the stretched strides lift the feet off the ground, so the hips come down to keep the lower foot on it
	var drop := 0.0
	if fitted and ankle > 0.0 and (state == "walk" or state == "run" or state == "walkfire"):
		var low := INF
		for f in [cfg.get("foot", "mixamorig_LeftFoot"), cfg.get("foot_r", "mixamorig_RightFoot")]:
			var b := skel.find_bone(f)
			if b >= 0:
				low = minf(low, (skel.global_transform * skel.get_bone_global_pose(b).origin).y - model.position.y + base_y)
		if low < INF:
			drop = minf(0.0, ankle - low)
	ground_y = lerpf(ground_y, base_y + drop, 1.0 - exp(-dt * 20.0))
	model.position.y = ground_y
	_cast_body()


## A cartoony cast (hero.json "cast_big"): he crouches and leans back winding up, then springs up taller and
## thinner with a little hop and a lean into the throw as the spell leaves, and settles. The ultimate also spins
## him round once on the wind-up.
func _cast_body() -> void:
	if not fitted or not cfg.has("cast_big"):
		return
	var sy := 1.0
	var sxz := 1.0
	var hop := 0.0
	var lean := 0.0
	var spin := 0.0
	if state == "cast" and ap.is_playing():
		var pos := ap.current_animation_position
		var len := ap.current_animation_length
		if pos < cast_at:
			var w := pos / maxf(0.001, cast_at)
			var e := sin(w * PI / 2)
			sy = 1.0 - 0.14 * e
			sxz = 1.0 + 0.1 * e
			lean = -10.0 * e
			spin = cast_spin * w * w * (3 - 2 * w)
		else:
			var v := clampf((pos - cast_at) / maxf(0.05, len - cast_at), 0, 1)
			var e := pow(1.0 - v, 3)
			var up := sin(minf(1.0, v * 3.0) * PI)
			sy = 1.0 + 0.2 * e * (1.0 if v < 0.33 else 0.6)
			sxz = 1.0 - 0.08 * e
			hop = 0.22 * up
			lean = 12.0 * e
	model.scale = fit_scale * Vector3(sxz, sy, sxz)
	model.position.y += hop
	model.rotation.x += deg_to_rad(lean)
	model.rotation.y += spin


## How much more to turn the hero (about the vertical) so its barrel, `d` from the weapon to the Muzzle, points
## at `want_screen` as drawn on screen. That counts the barrel's own tilt up or down (the clip's), which turning
## the ground facing alone leaves off by up to ~35 degrees. Of the turns that line it up, the smallest.
func _barrel_turn(d: Vector3) -> float:
	var p := deg_to_rad(pitch)
	if anchor:
		d = anchor.global_basis.inverse() * d # into the turned frame the facings work in
	var best := 0.0
	var score := INF
	for i in range(-48, 49):
		var f := i * 0.025
		var x := d.x * cos(f) + d.z * sin(f)
		var z := -d.x * sin(f) + d.z * cos(f)
		var s := Vector2(x, z * sin(p) - d.y * cos(p)) # on screen, y down
		if s.length() < 0.01:
			continue
		var e := absf(angle_difference(s.angle(), want_screen)) + absf(f) * 0.02
		if e < score:
			score = e
			best = f
	return best


## Scales the model so it stands `tall` pixels, measured from its skeleton (head top to toes) once it is posed,
## and stands it on the origin.
func _fit() -> void:
	var top := -INF
	var low := INF
	# only the body's own bones count (an effect bone, like the Vanguard's BulwarkFX, can sit anywhere)
	var mixamo := skel.find_bone(cfg.get("lock_root", "mixamorig_Hips")) >= 0
	for i in skel.get_bone_count():
		if mixamo and not skel.get_bone_name(i).begins_with("mixamorig"):
			continue
		var y := (skel.global_transform * skel.get_bone_global_pose(i).origin).y
		top = maxf(top, y)
		low = minf(low, y)
	if top - low <= 0.001:
		return
	# the head-top bone sits inside the hair, so leave a little room above it
	model.scale *= 1.8 / ((top - low) * 1.08)
	if hover.is_empty():
		model.position.y -= low * 1.8 / ((top - low) * 1.08)
	fitted = true
	fit_scale = model.scale
	base_y = model.position.y
	ground_y = base_y
	var feet := INF
	for f in [cfg.get("foot", "mixamorig_LeftFoot"), cfg.get("foot_r", "mixamorig_RightFoot")]:
		var b := skel.find_bone(f)
		if b >= 0:
			feet = minf(feet, (skel.global_transform * skel.get_bone_global_pose(b).origin).y)
	ankle = feet if feet < INF and hover.is_empty() else 0.0
	walk_speed = _stride_speed(anims.walk) if anims.has("walk") and hover.is_empty() else 1.0
	run_speed = _stride_speed(anims.run) if anims.has("run") else 0.0
	if anims.has(state):
		ap.play(anims[state]) # measuring moved the player off the current clip


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


## Walks (or runs, if the hero has a "run" clip and is going fast) at `px_per_s` screen pixels of ground a second,
## with the clip keeping pace with the ground up to MAX_PACE. Backwards steps it in reverse.
func move(px_per_s: float, game_speed: float, backwards: bool, aiming: bool = false) -> void:
	if not hover.is_empty():
		# a hover has no feet to keep pace with the ground: it glides at the game's speed
		play("walk", game_speed)
		return
	var px_per_unit := tall / 1.8
	var what := "walkfire" if aiming and anims.has("walkfire") else "walk"
	var rate := px_per_s / (walk_speed * px_per_unit)
	if run_speed > 0.0 and rate > 1.4 and not aiming:
		what = "run"
		rate = px_per_s / (run_speed * px_per_unit)
	play(what, game_speed * clampf(rate, 0.3, float(cfg.get("max_pace", MAX_PACE))) * (-1.0 if backwards else 1.0))


## Where the gun tip is, in board pixels from the hero's feet.
func tip() -> Vector2:
	if muzzle == null:
		return Vector2(0, -tall * 0.6)
	if rig:
		return (rig.world_to_art(muzzle_at()) / art_per_unit - position) / scale.x
	return cam.unproject_position(muzzle_at()) / Q - FEET


## Where a 3D point shows, in this node's parent's units (the board's world): the gun tip is position + tip() * scale.
func to_parent(w: Vector3) -> Vector2:
	if rig:
		return rig.world_to_art(w) / art_per_unit
	return position + (cam.unproject_position(w) / Q - FEET) * scale


## The gun tip in the 3D world, from the skeleton's current pose. A weapon on a BoneAttachment3D (as in a .glb)
## only follows its bone once the frame's pose update has gone out, so reading the Muzzle node itself can be a
## frame or more behind a new shot's pose; this works it out from the bone instead.
func muzzle_at() -> Vector3:
	return _on_bone(muzzle)


## A point of the weapon (its Muzzle, or the weapon itself) in the 3D world, following the bone it rides on.
func _on_bone(p: Node3D) -> Vector3:
	if held:
		_hold()
		return p.global_position
	var n: Node = p.get_parent()
	while n and not n is BoneAttachment3D:
		n = n.get_parent()
	if n == null:
		return p.global_position
	var att: BoneAttachment3D = n
	var local := att.global_transform.affine_inverse() * p.global_position
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(att.bone_name)) * local


## Measures how fast a looping in-place clip would carry the hero (see walk_speed). Call once fitted.
func _stride_speed(clip: String) -> float:
	var a := ap.get_animation(clip)
	var foot := skel.find_bone(cfg.get("foot", "mixamorig_LeftFoot"))
	var hip := skel.find_bone(cfg.get("lock_root", "mixamorig_Hips"))
	if foot < 0 or hip < 0 or a.length <= 0:
		return 1.0
	var fwd := Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))
	if anchor:
		fwd = anchor.global_basis * fwd
	var lo := INF
	var hi := -INF
	for i in 40:
		ap.play(clip, 0.0)
		ap.seek(a.length * i / 40.0, true)
		var f := skel.get_bone_global_pose(foot).origin - skel.get_bone_global_pose(hip).origin
		var d := (skel.global_transform.basis * f).dot(fwd)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return maxf(0.05, 2.0 * (hi - lo) / a.length)
