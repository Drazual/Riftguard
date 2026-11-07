class_name StyleWorld
extends Control
## One shared low-resolution 3D world for the whole board (the style test; not used by the game yet).
##
## Everything that isn't UI is drawn here by ONE orthographic camera, into ONE SubViewport sized res_scale x the
## board's base 768x416, then upscaled to the window with nearest-neighbour (by whole multiples when it fits):
##  - the ground (roads, sidewalks): the painted ground image on a flat, unlit quad on the ground plane, laid out so
##    it lands on screen pixel for pixel;
##  - fixed-angle scenery (buildings, props): unlit upright planes standing on their ground line, facing the
##    camera, stretched by 1 / cos(pitch) so they also land pixel for pixel. Standing upright (not flat on the
##    ground and not tilted to the camera) is what gives correct depth: a model behind a building's ground line is
##    hidden by it from feet to head, a model in front draws over it, exactly like the board's y-sort but per pixel;
##  - live 3D models (heroes, towers, effects), lit by one key light, shadowed onto a shadow-only ground receiver,
##    with a contact shadow blob under each, and (optionally) the shared toon material (toon_model.gdshader).
## Painted scenery is never lit (no double lighting); only the models are.
##
## Coordinates: "art" pixels are the 2x scenery art's (1536x832 for the whole board, Board's base x2); board field
## points convert to art pixels as the board draws them (art = 2 * PX * (x, TOP + y * K)). The camera's pitch is the
## scenery's own: Ocean Drive's ground is 2:1 isometric, so the camera looks down 30 degrees (sin 30 = 0.5 squash),
## turned 45 degrees so 3D footprints line up with the painted diamond tiles. Gameplay's own K (0.75) is untouched:
## models are placed where the board would draw them, so ranges and movement don't change.

const ART := Vector2(1536, 832) # the scenery art's size (the board's base 768x416 at 2x)
const BASE := Vector2(768, 416)
const UNIT := 0.03 # world metres per art pixel (a 1.8 m hero stands 1.8 * cos(30) / UNIT = 52 art px = 26 board px)
const PITCH := 30.0 # degrees the camera looks down: the scenery's 2:1 isometric ground
const YAW := 45.0 # degrees the camera turns about the vertical: 3D square footprints match the painted diamonds
const TOON := preload("res://scripts/style/toon_model.gdshader")
const OUTLINE := preload("res://scripts/style/outline.gdshader")

var settings: StyleSettings
var vp: SubViewport
var view: TextureRect
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var ground: MeshInstance3D
var catcher: MeshInstance3D # the ground's shadow-only receiver
var scenery: Node3D
var models: Node3D
var _toons: Array[ShaderMaterial] = []
var _outlines: Array[ShaderMaterial] = []
var _blobs: Array[MeshInstance3D] = []
var _styled: Array[Node] = [] # roots passed to add_model, re-styled when stylize is turned on or off
var scale_px := 1.0 # physical window pixels per render pixel, after layout


func _init(s: StyleSettings = null) -> void:
	settings = s if s else StyleSettings.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_DISABLED # the pixel finish comes from the low-res grid; AA would blur it
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = _vp_size()
	add_child(vp)
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	_world()
	resized.connect(_layout)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()
	apply()


func _vp_size() -> Vector2i:
	return Vector2i((BASE * settings.res_scale).round())


func _world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, i in [1, 2])
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 80.0
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(-deg_to_rad(PITCH), deg_to_rad(YAW), 0)
	cam.size = ART.y * UNIT
	cam.near = 0.5
	cam.far = 200.0
	# the ground point at the middle of the view is the world's origin; the camera backs off along its view
	cam.position = -cam.basis.z * -60.0
	vp.add_child(cam)
	cam.current = true
	scenery = Node3D.new()
	scenery.name = "Scenery"
	vp.add_child(scenery)
	models = Node3D.new()
	models.name = "Models"
	vp.add_child(models)
	# the ground quad and its shadow receiver: a rectangle on the ground, turned with the camera, that fills the view
	var size := Vector2(ART.x * UNIT, ART.y * UNIT / sin(deg_to_rad(PITCH)))
	var pm := PlaneMesh.new()
	pm.size = size
	ground = MeshInstance3D.new()
	ground.mesh = pm
	ground.rotation.y = deg_to_rad(YAW)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(ground)
	catcher = MeshInstance3D.new()
	catcher.mesh = pm
	catcher.rotation.y = deg_to_rad(YAW)
	catcher.position.y = 0.002
	catcher.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := StandardMaterial3D.new()
	cm.shadow_to_opacity = true
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cm.render_priority = -1
	catcher.material_override = cm
	vp.add_child(catcher)


## The painted ground (the whole board's, ART sized), drawn unlit and unfiltered.
func set_ground(tex: Texture2D) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED # sprites dip below the ground line; nothing hides them
	m.render_priority = -2
	ground.material_override = m


## A fixed-angle scenery sprite (building, prop) at `tl` (its top-left, art pixels), standing on the ground line at
## art y `key` (the line it sorts at). `k`: the art's own scale (0.5 for half size). Returns the plane.
func add_sprite(tex: Texture2D, tl: Vector2, key: float, k := 1.0, label := "") -> MeshInstance3D:
	var c := math_cos()
	var sz := tex.get_size() * k
	var qm := QuadMesh.new()
	qm.size = Vector2(sz.x * UNIT, sz.y * UNIT / c)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	var mi := MeshInstance3D.new()
	mi.mesh = qm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = label if label != "" else tex.resource_path.get_file().get_basename()
	var cx := tl.x + sz.x / 2
	var g := art_to_ground(Vector2(cx, key))
	# heights on the plane rise on screen by cos(pitch) per metre: put its bottom edge where the art's is
	var bottom := (key - (tl.y + sz.y)) * UNIT / c
	mi.position = g + Vector3.UP * (bottom + qm.size.y / 2)
	mi.rotation.y = deg_to_rad(YAW)
	scenery.add_child(mi)
	return mi


func math_cos() -> float:
	return cos(deg_to_rad(PITCH))


## Adds a live model (any Node3D whose origin is at its feet) to the world, styled and with a contact shadow blob.
## Returns the anchor to move it with (place / place_art). `radius`: the blob's size in metres.
func add_model(root: Node3D, radius := 0.45) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = root.name + "Anchor"
	models.add_child(anchor)
	if root.get_parent():
		root.reparent(anchor, false)
	else:
		anchor.add_child(root)
	var blob := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2, radius * 2)
	blob.mesh = pm
	blob.position.y = 0.004
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bm := ShaderMaterial.new()
	bm.shader = _blob_shader()
	blob.material_override = bm
	anchor.add_child(blob)
	_blobs.append(blob)
	_styled.append(root)
	style_node(root)
	return anchor


var _blob: Shader
func _blob_shader() -> Shader:
	if _blob == null:
		_blob = Shader.new()
		_blob.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
uniform vec4 color : source_color = vec4(0.1, 0.07, 0.2, 0.5);
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(0.55, 1.0, d));
}"""
	return _blob


## Puts a model anchor at a board field point (as the board draws it), on the pixel grid if pixel_snap is on.
func place(anchor: Node3D, field: Vector2) -> void:
	place_art(anchor, field_to_art(field))


func place_art(anchor: Node3D, art: Vector2) -> void:
	var g := art_to_ground(art)
	anchor.position = snap(g) if settings.pixel_snap else g


## Turns a model to face a direction on screen (0 = right, PI/2 = down the screen), standing upright: the turn is
## worked out through the camera's pitch and yaw, the model is never tilted toward the camera.
func face_yaw(screen_angle: float) -> float:
	var s := Vector2(cos(screen_angle), sin(screen_angle) / sin(deg_to_rad(PITCH)))
	return atan2(s.x, s.y) + deg_to_rad(YAW)


## A ground point moved onto the render's pixel grid (across the screen by whole pixels, and up and down the screen
## by whole pixels too, which on the ground is 1 / sin(pitch) as far).
func snap(g: Vector3) -> Vector3:
	var tx := UNIT * ART.y / vp.size.y # metres across per render pixel
	var r := cam.global_basis.x
	var fwd := Vector3(-cam.global_basis.z.x, 0, -cam.global_basis.z.z).normalized()
	var a := snappedf(g.dot(r), tx)
	var b := snappedf(g.dot(fwd), tx / sin(deg_to_rad(PITCH)))
	return r * a + fwd * b


static func field_to_art(f: Vector2) -> Vector2:
	return Vector2(f.x, Board.TOP + f.y * Board.K) * Board.PX * 2.0


static func art_to_field(a: Vector2) -> Vector2:
	var b := a / (2.0 * Board.PX)
	return Vector2(b.x, (b.y - Board.TOP) / Board.K)


## The ground point (y = 0) under an art pixel.
func art_to_ground(a: Vector2) -> Vector3:
	var d := (a - ART / 2) * UNIT
	var b := cam.global_basis if cam.is_inside_tree() else cam.basis
	var p := (cam.global_position if cam.is_inside_tree() else cam.position) + b.x * d.x - b.y * d.y
	var f := -b.z
	return p + f * (-p.y / f.y)


## Where a world point shows, in art pixels.
func world_to_art(w: Vector3) -> Vector2:
	return cam.unproject_position(w) * ART.x / vp.size.x


## A point in this control (e.g. a mouse event's position) -> art pixels, through the upscaled render's rect.
func local_to_art(p: Vector2) -> Vector2:
	return (p - view.position) / view.size * ART


func art_to_local(a: Vector2) -> Vector2:
	return view.position + a / ART * view.size


## The render rect: by whole physical-pixel multiples when the window is big enough (else the largest fit), centred
## and on whole physical pixels. Controls here are in canvas units, which canvas_items stretch scales to the window.
func _layout() -> void:
	if not is_inside_tree():
		return
	var win := Vector2(get_viewport().get_visible_rect().size)
	var ph := Vector2(get_tree().root.size) # the window's real pixels (canvas_items stretch scales canvas units to them)
	var per := ph / win # physical pixels per canvas unit
	var avail := size * per
	var vs := Vector2(vp.size)
	var s := minf(avail.x / vs.x, avail.y / vs.y)
	if settings.integer_scale and s >= 1.0:
		s = floorf(s)
	scale_px = s
	var px := (vs * s).round()
	var at := ((avail - px) / 2).floor()
	view.position = at / per
	view.size = px / per


## Pushes the settings into the renderer and every styled material.
func apply() -> void:
	var s := settings
	if vp.size != _vp_size():
		vp.size = _vp_size()
		_layout()
	# the painted 2x art is shown pixel for pixel at res_scale 2 and up; below that it is shrunk, so it is filtered
	# (nearest would drop whole rows of its pixels and make the tile lines crawl)
	var f := BaseMaterial3D.TEXTURE_FILTER_NEAREST if s.res_scale >= 2.0 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for mi in [ground] + scenery.get_children():
		if mi is MeshInstance3D and mi.material_override is BaseMaterial3D:
			(mi.material_override as BaseMaterial3D).texture_filter = f
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
	for b in _blobs:
		if is_instance_valid(b):
			(b.material_override as ShaderMaterial).set_shader_parameter("color", Color(s.shadow_color.darkened(0.6), s.contact_shadow))
			b.visible = s.contact_shadow > 0.0
	for m in _toons:
		_toon_params(m)
	for m in _outlines:
		_outline_params(m)
	for m in _toons:
		m.set_shader_parameter("exposure", 1.0)
	var want := s.stylize
	for r in _styled:
		if is_instance_valid(r) and bool(r.get_meta("styled", false)) != want:
			style_node(r)


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
	m.set_shader_parameter("normal_detail", s.normal_detail)
	m.set_shader_parameter("simplify", s.simplify)
	m.set_shader_parameter("exposure", 1.0)


## The outline hull: settings.outline whole render pixels wide (0 hides it by sinking it fully behind the model).
func _outline_params(m: ShaderMaterial) -> void:
	var px := UNIT * ART.y / vp.size.y
	m.set_shader_parameter("width", settings.outline * px)
	m.set_shader_parameter("behind", 0.25 if settings.outline > 0.0 else 1000.0)
	m.set_shader_parameter("color", settings.outline_color)


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
		for i in mi.mesh.get_surface_count():
			if not on:
				mi.set_surface_override_material(i, orig[i])
				continue
			var src := orig[i] as Material if orig[i] else mi.mesh.surface_get_material(i)
			var toon := _toon_from(src)
			if toon:
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
	_toons.append(m)
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	_outline_params(o)
	_outlines.append(o)
	m.next_pass = o
	return m
