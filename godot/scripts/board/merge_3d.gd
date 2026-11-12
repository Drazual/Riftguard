class_name Merge3D
extends Node2D
## A hybrid or super tower drawn live from its own GLB (art_src/towers/merges/<key>/, found by MergeArt) in its own
## smooth render, like Beacon3D, Hero3D and Wall3D. This is the default look: the shared low-res layer (Live3D) is
## only used when the old unified-style test is on.
## The turret turns smoothly to any angle toward its target, `spawn` plays when it is built and then `idle` loops,
## `fire` plays on every shot, and the two accent masks paint the parents' path colours onto it (docs/merge-art.md,
## the delivery's CLAUDE_NOTES.md): mask A is the first parent's paths, mask B the second's, R trim, G glow, B detail.
## Pure visuals: the game owns aiming, shooting and the colours.

const PITCH := Hero3D.PITCH
const Q := 2 # rendered at 2x board pixels, drawn at half size
const TURRET_SCALE := 0.5 # tower.json "wide" is measured like a base turret's, at TowerData.turret_scale's default
## How far the plain body moves toward the recipe colour (the notes' "light tint"; the masked zones keep the paths)
const BODY := 0.2
const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_emission = false;
uniform float emission_energy = 3.0;
// the masks are data (no source_color), in the atlas's UV
uniform sampler2D mask_a : filter_linear, repeat_enable;
uniform sampler2D mask_b : filter_linear, repeat_enable;
uniform bool use_a = false;
uniform bool use_b = false;
uniform vec4 a_trim : source_color = vec4(1.0);
uniform vec4 a_glow : source_color = vec4(1.0);
uniform vec4 a_detail : source_color = vec4(1.0);
uniform vec4 b_trim : source_color = vec4(1.0);
uniform vec4 b_glow : source_color = vec4(1.0);
uniform vec4 b_detail : source_color = vec4(1.0);
uniform vec4 recipe : source_color = vec4(1.0);
uniform float body_mix = 0.2;
uniform float glow_energy = 2.0;
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec4 a = use_a ? texture(mask_a, UV) : vec4(0.0);
	vec4 b = use_b ? texture(mask_b, UV) : vec4(0.0);
	// a zone keeps a shade of the texel under it, so the paint still has the model's detail
	float sh = 0.30 + 1.25 * dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = mix(base, base * recipe.rgb, body_mix);
	c = mix(c, a_trim.rgb * sh, a.r);
	c = mix(c, b_trim.rgb * sh, b.r);
	c = mix(c, a_detail.rgb * sh, a.b);
	c = mix(c, b_detail.rgb * sh, b.b);
	c = mix(c, a_glow.rgb * sh, a.g);
	c = mix(c, b_glow.rgb * sh, b.g * (1.0 - 0.5 * a.g)); // the shared core: half and half
	ALBEDO = c;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = 0.6;
	}
	// the glow zones' path colours replace the baked emission there; baked glow elsewhere stays
	float glow_cover = clamp(max(a.g, b.g), 0.0, 1.0);
	vec3 baked = has_emission ? texture(emission_tex, UV).rgb * emission_energy : vec3(0.0);
	EMISSION = baked * (1.0 - glow_cover) + (a.g * a_glow.rgb + b.g * b_glow.rgb * (1.0 - 0.5 * a.g)) * glow_energy;
}
"""

var vp: SubViewport
var cam: Camera3D
var model: Node3D
var yaw_node: Node3D
var pitch_node: Node3D
var muzzle: Node3D
var ap: AnimationPlayer
var cfg := {}
var glb := ""
var idle := ""
var fire := ""
var box := Vector2(120, 120) # the viewport, in board pixels
var foot := Vector2(60, 100) # where the model's base centre lands in it
var yaw := 0.0
var want_yaw := 0.0
var mats: Array[ShaderMaterial] = [] # the body's recolour materials (one set per tower)
var mask_a: Texture2D
var mask_b: Texture2D
var _upp := 0.0 # model metres per board pixel
var _sig := ""
var driven := false # stepped by the board in game time (tick), not by the engine's clock


## spec: MergeArt.resolve(t). False when the model does not load (the board keeps the plinth).
func setup(spec: Dictionary) -> bool:
	glb = str(spec.get("glb", ""))
	model = MergeArt.instantiate(glb)
	if model == null:
		return false
	cfg = (spec.get("cfg", {}) as Dictionary).duplicate(true)
	var p := deg_to_rad(PITCH)
	_upp = 1.8 * cos(p) / 26.0 # the heroes' scale: a 1.8 m hero is 26 board pixels tall
	yaw_node = _node(str(cfg.get("yaw", "")), ["Yaw", "Turret"])
	pitch_node = _node(str(cfg.get("pitch", "")), ["Pitch", "Gun", "Barrel"])
	muzzle = _node(str(cfg.get("muzzle", "")), ["Muzzle", "BuffPoint"])
	ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# size: tower.json "wide" (board pixels like a base turret's) across the model's footprint, the parts that
	# don't turn; the box fits the gun turned any way
	var rest := _bounds(model, yaw_node, false)
	var full := _bounds(model, null, true)
	var foot_w := maxf(rest.size.x, 0.2) if rest.size != Vector3.ZERO else maxf(full.size.x, 0.2)
	var wide := float(cfg.get("wide", 52.0)) * TURRET_SCALE * float(spec.get("scale", 1.0))
	var s := wide * _upp / foot_w
	model.scale = Vector3.ONE * s
	var reach := 0.0
	for x in [full.position.x, full.end.x]:
		for z in [full.position.z, full.end.z]:
			reach = maxf(reach, Vector2(x, z).length())
	var k := s / _upp # board pixels per model metre
	var h := full.end.y * 1.2 # headroom over the top for effects that reach past the mesh (bolts, charge rings, recoil)
	box = Vector2(ceilf(2 * reach * k + 10), ceilf((h * cos(p) + 2 * reach * sin(p)) * k + 10))
	foot = Vector2(box.x / 2, box.y - reach * sin(p) * k - 5)
	vp = SubViewport.new()
	vp.size = Vector2i(box * Q)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	Hero3D.clean_light(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(-p, 0, 0)
	cam.size = box.y * _upp
	cam.position = Vector3(0, sin(p), cos(p)) * 20.0
	cam.position += Vector3(0, cos(p), -sin(p)) * (foot.y - box.y / 2) * _upp
	cam.position += Vector3.RIGHT * -(foot.x - box.x / 2) * _upp
	cam.near = 0.1
	cam.far = 60.0
	vp.add_child(cam)
	cam.current = true
	vp.add_child(model)
	_recolour_body()
	mask_a = MergeArt.load_mask(glb, "_accent_mask.png", model, "accent_mask")
	mask_b = MergeArt.load_mask(glb, "_accent_mask_b.png", model, "accent_mask_b")
	if pitch_node and cfg.has("aim"):
		pitch_node.rotation.x = float(cfg.aim)
	_arm_clips()
	var pic := Sprite2D.new()
	pic.name = "Pic"
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = Vector2.ONE / Q
	pic.position = -foot
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(pic)
	return true


## A node by tower.json path (from the model root), else the first of these names anywhere in it. "-": none.
func _node(path: String, names: Array) -> Node3D:
	if path == "-":
		return null # tower.json says this tower has no such node (a tower that doesn't aim)
	if path != "":
		var n := model.get_node_or_null(NodePath(path))
		if n == null:
			n = model.find_child(path.get_file(), true, false)
		if n is Node3D:
			return n
	for nm in names:
		var f := model.find_child(String(nm), true, false)
		if f is Node3D:
			return f
	return null


## The model's mesh bounds at rest, in its own unscaled space. With skip set, parts under that node are left out.
func _bounds(root: Node3D, skip: Node, fx_too: bool) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if skip and (mi == skip or skip.is_ancestor_of(mi)):
			continue
		if not fx_too and mi.mesh and mi.mesh.get_surface_count() > 0:
			var m := mi.get_active_material(0) as StandardMaterial3D
			if m and m.albedo_texture == null:
				continue # glow and effect meshes (no texture) don't count toward the footprint
		var xf := Transform3D.IDENTITY
		var at: Node = mi
		while at and at != root:
			xf = (at as Node3D).transform * xf
			at = at.get_parent()
		var bb := xf * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


## The textured body material becomes one recolour material per tower (the effect materials keep their own).
func _recolour_body() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	var made := {}
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			if not made.has(src):
				var m := ShaderMaterial.new()
				m.shader = sh
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				if src.normal_enabled and src.normal_texture:
					m.set_shader_parameter("normal_tex", src.normal_texture)
					m.set_shader_parameter("has_normal", true)
				var orm: Texture2D = src.roughness_texture if src.roughness_texture else src.metallic_texture
				if orm:
					m.set_shader_parameter("orm_tex", orm)
					m.set_shader_parameter("has_orm", true)
				if src.emission_enabled and src.emission_texture:
					m.set_shader_parameter("emission_tex", src.emission_texture)
					m.set_shader_parameter("has_emission", true)
					m.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
				m.set_shader_parameter("body_mix", BODY)
				made[src] = m
				mats.append(m)
			mi.set_surface_override_material(i, made[src])


func _arm_clips() -> void:
	if ap == null:
		return
	var anims: Dictionary = cfg.get("anims", {}) if cfg.get("anims") is Dictionary else {}
	idle = str(anims.get("idle", "idle"))
	fire = str(anims.get("fire", "fire"))
	if not ap.has_animation(fire):
		fire = "attack" if ap.has_animation("attack") else ""
	if not ap.has_animation(idle):
		idle = ""
	# the game turns and tilts the gun: any clip keys on those nodes are dropped
	var own := [model.get_path_to(yaw_node) if yaw_node else NodePath("-"), model.get_path_to(pitch_node) if pitch_node else NodePath("-")]
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name).duplicate(true) as AnimationLibrary
		ap.remove_animation_library(lib_name)
		ap.add_animation_library(lib_name, lib)
		for a in lib.get_animation_list():
			var anim := lib.get_animation(a)
			for ti in range(anim.get_track_count() - 1, -1, -1):
				var path := String(anim.track_get_path(ti)).get_slice(":", 0)
				if path == String(own[0]) or path == String(own[1]):
					anim.remove_track(ti)
	if idle != "":
		ap.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
	ap.animation_finished.connect(func(n: StringName):
		if String(n) != idle and idle != "":
			ap.play(idle))
	var spawn := str(anims.get("spawn", "spawn"))
	if ap.has_animation(spawn):
		ap.play(spawn)
	elif idle != "":
		ap.play(idle)


## The parents' path colours: [parent A's three, parent B's three]; recipe: the merge's own colour (body tint).
func set_look(parent_cols: Array, recipe: Color) -> void:
	var a := _triplet(parent_cols[0] if parent_cols.size() > 0 and parent_cols[0] is Array else [], recipe)
	var b := _triplet(parent_cols[1] if parent_cols.size() > 1 and parent_cols[1] is Array else [], recipe)
	var sig := "%s|%s|%s" % [a, b, recipe]
	if sig == _sig:
		return
	_sig = sig
	for m in mats:
		m.set_shader_parameter("use_a", mask_a != null)
		m.set_shader_parameter("use_b", mask_b != null)
		if mask_a:
			m.set_shader_parameter("mask_a", mask_a)
		if mask_b:
			m.set_shader_parameter("mask_b", mask_b)
		m.set_shader_parameter("a_trim", a[0])
		m.set_shader_parameter("a_glow", a[1])
		m.set_shader_parameter("a_detail", a[2])
		m.set_shader_parameter("b_trim", b[0])
		m.set_shader_parameter("b_glow", b[1])
		m.set_shader_parameter("b_detail", b[2])
		m.set_shader_parameter("recipe", recipe)


func _triplet(cols: Array, fallback: Color) -> Array[Color]:
	var out: Array[Color] = []
	for c in cols:
		if c is Color and out.size() < 3:
			out.append(c)
	while out.size() < 3:
		out.append(fallback)
	return out


## Turns toward a direction on the board as drawn (x right, y down the screen).
func aim(screen: Vector2) -> void:
	if screen.length() < 1:
		return
	var g := Vector2(screen.x, screen.y / sin(deg_to_rad(PITCH)))
	want_yaw = atan2(g.x, g.y)


func shoot() -> void:
	if ap and fire != "":
		ap.stop()
		ap.play(fire)


func set_speed(s: float) -> void:
	if ap and not driven:
		ap.speed_scale = s


## The board steps the model in game time (dt already scaled by the game's speed, 0 while paused), so the fire
## clip's shot moment lines up with the game's held shot (Game.merge_lead) even when frames run slow.
func tick(game_dt: float) -> void:
	if not driven:
		driven = true
		if ap:
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			ap.speed_scale = 1.0
	if ap and game_dt > 0:
		ap.advance(game_dt)
	_turn(game_dt)


## Where the muzzle shows, in this node's units (board pixels from the tower's base), for shots and flashes.
func muzzle_at() -> Vector2:
	if muzzle == null or cam == null:
		return Vector2.ZERO
	return cam.unproject_position(muzzle.global_position) / Q - foot


func _process(dt: float) -> void:
	if not driven:
		_turn(dt * (ap.speed_scale if ap else 1.0))


func _turn(dt: float) -> void:
	if yaw_node == null or dt <= 0:
		return
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-10.0 * dt))
	yaw_node.rotation.y = yaw
