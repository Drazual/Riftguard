class_name StyleRig
extends Node3D
## The shared look of every live 3D model: ONE orthographic camera at the scenery's own angle, one key light and the
## palette's ambient, cast shadows on a shadow-only ground receiver, a contact shadow blob under each model, and the
## shared toon material with its outline (toon_model.gdshader, outline.gdshader). Used by the style test scene
## (StyleWorld) and by the board's live 3D layer (Live3D). Add it as the only child of a SubViewport with its own
## 3D world; the viewport's size sets the render resolution.
##
## Coordinates: "art" pixels are the whole board's 2x scenery art (1536x832, the board's base 768x416 at 2x). The
## camera looks down 30 degrees (Ocean Drive's 2:1 isometric ground, sin 30 = 0.5) turned 45 degrees so 3D square
## footprints line up with the painted diamond tiles, and the middle of the view is the world's origin.
## Models stand upright (never tilted to the camera) and are placed where the board would draw them.

const ART := Vector2(1536, 832)
const BASE := Vector2(768, 416)
const UNIT := 0.03 # world metres per art pixel (a 1.8 m hero stands 1.8 * cos(30) / UNIT = 52 art px = 26 board px)
const PITCH := 30.0
const YAW := 45.0
const TOON := preload("res://scripts/style/toon_model.gdshader")
const OUTLINE := preload("res://scripts/style/outline.gdshader")
const CUTOUT := preload("res://scripts/style/cutout.gdshader")
const BLOB := preload("res://scripts/style/blob.gdshader")

var settings: StyleSettings
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var catcher: MeshInstance3D # the ground's shadow-only receiver
var models: Node3D
var _blobs: Array[MeshInstance3D] = []
var _styled: Array[Node] = [] # roots re-styled when stylize is turned on or off


## transparent: the view has no background of its own (it is drawn over the board's 2D scenery).
func _init(s: StyleSettings, transparent := false) -> void:
	settings = s
	name = "StyleRig"
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if transparent else Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i in [1, 2])
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(-deg_to_rad(PITCH), deg_to_rad(YAW), 0)
	cam.size = ART.y * UNIT
	cam.near = 0.5
	cam.far = 200.0
	cam.position = cam.basis.z * 60.0 # backed off along the view from the ground point in the middle
	add_child(cam)
	cam.current = true
	models = Node3D.new()
	models.name = "Models"
	add_child(models)
	catcher = MeshInstance3D.new()
	catcher.mesh = ground_mesh()
	catcher.rotation.y = deg_to_rad(YAW)
	catcher.position.y = 0.002
	catcher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := StandardMaterial3D.new()
	cm.shadow_to_opacity = true
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cm.render_priority = -1
	catcher.material_override = cm
	add_child(catcher)


## A rectangle on the ground, turned with the camera, that fills the view (and a margin, for zoomed-out shadows).
static func ground_mesh(margin := 1.0) -> PlaneMesh:
	var pm := PlaneMesh.new()
	pm.size = Vector2(ART.x * UNIT, ART.y * UNIT / sin(deg_to_rad(PITCH))) * margin
	return pm


## World metres across one render pixel.
func px_m() -> float:
	var vp := get_viewport()
	return UNIT * ART.y / (vp.size.y if vp else ART.y)


## Adds a live model (any Node3D whose origin is at its feet) to the world, styled and with a contact shadow blob.
## Returns the anchor to move it with (place / place_art). radius: the blob's size in metres. turned: the anchor is
## turned with the camera, so the model's own frame is the old per-model camera's (x right on screen, +z toward the
## viewer), which is what Hero3D's facing works in.
func add_model(root: Node3D, radius := 0.45, turned := false) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = String(root.name) + "Anchor"
	if turned:
		anchor.rotation.y = deg_to_rad(YAW)
	models.add_child(anchor)
	if root.get_parent():
		root.reparent(anchor, false)
	else:
		anchor.add_child(root)
	if radius > 0.0:
		var blob := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(radius * 2, radius * 2)
		blob.mesh = pm
		blob.position.y = 0.004
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bm := ShaderMaterial.new()
		bm.shader = BLOB
		blob.material_override = bm
		blob.name = "ContactShadow"
		anchor.add_child(blob)
		_blobs.append(blob)
		_blob_params(blob)
	add_styled(root)
	return anchor


## Styles a model root now and whenever stylize changes.
func add_styled(root: Node) -> void:
	_styled.append(root)
	style_node(root)


func _blob_params(b: MeshInstance3D) -> void:
	(b.material_override as ShaderMaterial).set_shader_parameter("color", Color(settings.shadow_color.darkened(0.6), settings.contact_shadow))
	b.visible = settings.contact_shadow > 0.0


## Puts a model anchor at an art point, on the render's pixel grid if pixel_snap is on.
func place_art(anchor: Node3D, art: Vector2) -> void:
	var g := art_to_ground(art)
	anchor.position = snap(g) if settings.pixel_snap else g


## The turn (about the vertical, in the world) that faces a direction on screen (0 = right, PI/2 = down the screen).
func face_yaw(screen_angle: float) -> float:
	var s := Vector2(cos(screen_angle), sin(screen_angle) / sin(deg_to_rad(PITCH)))
	return atan2(s.x, s.y) + deg_to_rad(YAW)


## A ground point moved onto the render's pixel grid (across the screen by whole pixels, and up and down the screen
## by whole pixels too, which on the ground is 1 / sin(pitch) as far).
func snap(g: Vector3) -> Vector3:
	var tx := px_m()
	var r := cam.basis.x
	var fwd := Vector3(-cam.basis.z.x, 0, -cam.basis.z.z).normalized()
	var a := snappedf(g.dot(r), tx)
	var b := snappedf(g.dot(fwd), tx / sin(deg_to_rad(PITCH)))
	return r * a + fwd * b + Vector3.UP * g.y


## The ground point (y = 0) under an art pixel.
func art_to_ground(a: Vector2) -> Vector3:
	var d := (a - ART / 2) * UNIT
	var b := cam.basis
	var p := cam.position + b.x * d.x - b.y * d.y
	var f := -b.z
	return p + f * (-p.y / f.y)


## A point standing `up` metres over the ground at an art pixel's foot, as the art draws it.
func art_to_world(a: Vector2, up := 0.0) -> Vector3:
	return art_to_ground(a) + Vector3.UP * up


## Where a world point shows, in art pixels (from the camera's own transform, so it works out of the tree too).
func world_to_art(w: Vector3) -> Vector2:
	var l := cam.transform.affine_inverse() * w
	return ART / 2 + Vector2(l.x, -l.y) / UNIT


## An upright plane that cuts the models out where a 2D sprite drawn under them stands in front: a "cut-out".
## Placed with set_cutout. Its alpha is the sprite's (or a disc when it has no texture).
func add_cutout(label := "Cutout") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	mi.mesh = qm
	mi.name = label
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = CUTOUT
	m.render_priority = 120
	mi.material_override = m
	mi.rotation.y = deg_to_rad(YAW)
	add_child(mi)
	return mi


## Stands a cut-out on the ground line at art y `key`, covering the art rect `r` on screen. tex: the sprite's texture
## (null for a disc), region: the part of it shown (UV, as position and size).
func set_cutout(mi: MeshInstance3D, r: Rect2, key: float, tex: Texture2D = null, region := Rect2(0, 0, 1, 1)) -> void:
	var c := cos(deg_to_rad(PITCH))
	var g := art_to_ground(Vector2(r.get_center().x, key))
	# heights on an upright plane rise on screen by cos(pitch) per metre: put its bottom edge where the sprite's is
	var bottom := (key - r.end.y) * UNIT / c
	var h := r.size.y * UNIT / c
	mi.position = g + Vector3.UP * (bottom + h / 2)
	mi.scale = Vector3(maxf(r.size.x * UNIT, 0.001), maxf(h, 0.001), 1)
	var m := mi.material_override as ShaderMaterial
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("use_tex", tex != null)
	m.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))


## Pushes the settings into the renderer and every styled material.
func apply() -> void:
	var s := settings
	env.ambient_light_color = s.shadow_color
	env.ambient_light_energy = s.shadow_energy
	env.tonemap_exposure = s.exposure
	env.glow_enabled = s.glow > 0.0
	env.glow_intensity = s.glow
	env.glow_hdr_threshold = s.glow_threshold
	env.glow_bloom = 0.0
	sun.rotation_degrees = Vector3(s.light_pitch, s.light_yaw + YAW, 0)
	sun.light_energy = s.light_energy
	sun.light_color = s.light_color
	sun.shadow_enabled = s.cast_shadows
	var cm: StandardMaterial3D = catcher.material_override
	cm.albedo_color = Color(s.shadow_color.darkened(0.55), s.shadow_strength)
	catcher.visible = s.cast_shadows and s.shadow_strength > 0.0
	_blobs = _blobs.filter(func(b): return is_instance_valid(b))
	for b in _blobs:
		_blob_params(b)
	_styled = _styled.filter(func(r): return is_instance_valid(r))
	for r in _styled:
		if bool(r.get_meta("styled", false)) != s.stylize:
			style_node(r)
		elif s.stylize:
			for m in toons_of(r):
				_toon_params(m)
				_apply_overrides(r, m)
				_outline_params(m)


## The toon materials on a styled model.
func toons_of(root: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for n in [root] + root.find_children("*", "MeshInstance3D", true, false):
		if n is MeshInstance3D and n.mesh:
			for i in n.mesh.get_surface_count():
				var m = n.get_surface_override_material(i)
				if m is ShaderMaterial and m.shader == TOON:
					out.append(m)
	return out


func _toon_params(m: ShaderMaterial) -> void:
	var s := settings
	m.set_shader_parameter("palette_strength", s.palette_strength)
	m.set_shader_parameter("keep_accents", s.keep_accents)
	m.set_shader_parameter("band_edge", s.band_edge)
	m.set_shader_parameter("band_soft", s.band_soft)
	m.set_shader_parameter("highlight", s.highlight)
	m.set_shader_parameter("highlight_size", s.highlight_size)
	m.set_shader_parameter("rim_color", s.rim_color)
	m.set_shader_parameter("rim", s.rim)
	m.set_shader_parameter("lift", s.lift)
	m.set_shader_parameter("normal_detail", s.normal_detail)
	m.set_shader_parameter("simplify", s.simplify)
	m.set_shader_parameter("exposure", 1.0)


## A styled root can carry "style_overrides" (hero.json): shader uniforms that replace the global StyleSettings
## on that model only. Gale's painted atlas sets lift 0 and simplify 1 so the plates are not flattened.
func _apply_overrides(root: Node, m: ShaderMaterial) -> void:
	var o: Variant = root.get_meta("style_overrides", {})
	if not o is Dictionary:
		return
	for k in o:
		m.set_shader_parameter(k, o[k])


## Two hulls on a toon material: a bright rim pixel outside a dark ink pixel (settings.outline / settings.rim).
## Either width of 0 sinks that hull fully behind the model so it disappears.
func _outline_params(toon: ShaderMaterial) -> void:
	var edge: ShaderMaterial = toon.next_pass
	var ink: ShaderMaterial = edge.next_pass
	var px := px_m()
	var rim_px := 1.0 if settings.rim > 0.02 else 0.0
	var outer := settings.outline + rim_px
	edge.set_shader_parameter("width", outer * px)
	edge.set_shader_parameter("behind", 0.7 if outer > 0.0 else 1000.0)
	# stay under the glow threshold so the rim is a hard pixel, not a bloom smear
	edge.set_shader_parameter("color", settings.rim_color * minf(settings.rim, 1.0) * 0.85)
	ink.set_shader_parameter("width", settings.outline * px)
	ink.set_shader_parameter("behind", 0.4 if settings.outline > 0.0 else 1000.0)
	ink.set_shader_parameter("color", settings.outline_color)


## Swaps a model's plain opaque materials for the shared toon material (settings.stylize), or back to the ones it
## had. Kept as they are: ShaderMaterials (effects like Gale's wind), transparent and unshaded materials, so
## emission, transparency and effect shaders survive. Reversible: the originals are kept on the mesh.
func style_node(root: Node) -> void:
	var on := settings.stylize
	root.set_meta("styled", on)
	for n in [root] + root.find_children("*", "MeshInstance3D", true, false):
		if not n is MeshInstance3D:
			continue
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		if not mi.has_meta("style_orig"):
			var orig := []
			for i in mi.mesh.get_surface_count():
				orig.append(mi.get_surface_override_material(i))
			mi.set_meta("style_orig", orig)
		var orig: Array = mi.get_meta("style_orig")
		for i in mini(orig.size(), mi.mesh.get_surface_count()):
			if not on:
				mi.set_surface_override_material(i, orig[i])
				continue
			var src := orig[i] as Material if orig[i] else mi.mesh.surface_get_material(i)
			var toon := _toon_from(src)
			if toon:
				_apply_overrides(root, toon)
				var clip: float = root.get_meta("clip_below", -1000.0)
				toon.set_shader_parameter("clip_below", clip)
				toon.next_pass.set_shader_parameter("clip_below", clip)
				toon.next_pass.next_pass.set_shader_parameter("clip_below", clip)
				mi.set_surface_override_material(i, toon)


func _toon_from(src: Material) -> ShaderMaterial:
	if not src is BaseMaterial3D:
		return null
	var b: BaseMaterial3D = src
	if b.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] \
			or b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		return null
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo_color", b.albedo_color)
	if b.albedo_texture:
		m.set_shader_parameter("albedo_tex", b.albedo_texture)
		m.set_shader_parameter("use_albedo_tex", true)
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter("alpha_scissor", b.alpha_scissor_threshold)
	if b.normal_enabled and b.normal_texture:
		m.set_shader_parameter("normal_tex", b.normal_texture)
		m.set_shader_parameter("use_normal", true)
	if b.emission_enabled:
		m.set_shader_parameter("emission_color", b.emission)
		m.set_shader_parameter("emission_energy", b.emission_energy_multiplier)
		if b.emission_texture:
			m.set_shader_parameter("emission_tex", b.emission_texture)
			m.set_shader_parameter("use_emission_tex", true)
	m.set_shader_parameter("uv_scale", Vector2(b.uv1_scale.x, b.uv1_scale.y))
	m.set_shader_parameter("uv_offset", Vector2(b.uv1_offset.x, b.uv1_offset.y))
	_toon_params(m)
	# bright outer pixel, then the dark ink on top of its inner part (see _outline_params)
	var edge := ShaderMaterial.new()
	edge.shader = OUTLINE
	var ink := ShaderMaterial.new()
	ink.shader = OUTLINE
	edge.next_pass = ink
	m.next_pass = edge
	_outline_params(m)
	return m
