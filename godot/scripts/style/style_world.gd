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

const ART := StyleRig.ART
const BASE := StyleRig.BASE
const UNIT := StyleRig.UNIT
const PITCH := StyleRig.PITCH
const YAW := StyleRig.YAW

var settings: StyleSettings
var vp: SubViewport
var view: TextureRect
var rig: StyleRig
var cam: Camera3D
var ground: MeshInstance3D
var scenery: Node3D
var models: Node3D
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
	rig = StyleRig.new(settings)
	vp.add_child(rig)
	cam = rig.cam
	models = rig.models
	scenery = Node3D.new()
	scenery.name = "Scenery"
	rig.add_child(scenery)
	ground = MeshInstance3D.new()
	ground.mesh = StyleRig.ground_mesh()
	ground.rotation.y = deg_to_rad(YAW)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(ground)
	resized.connect(_layout)


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()
	apply()


func _vp_size() -> Vector2i:
	return Vector2i((BASE * settings.res_scale).round())


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


## Adds a live model (any Node3D whose origin is at its feet), styled and with a contact shadow blob (StyleRig).
func add_model(root: Node3D, radius := 0.45, turned := false) -> Node3D:
	return rig.add_model(root, radius, turned)


## Puts a model anchor at a board field point (as the board draws it), on the pixel grid if pixel_snap is on.
func place(anchor: Node3D, field: Vector2) -> void:
	rig.place_art(anchor, field_to_art(field))


func place_art(anchor: Node3D, art: Vector2) -> void:
	rig.place_art(anchor, art)


func face_yaw(screen_angle: float) -> float:
	return rig.face_yaw(screen_angle)


func snap(g: Vector3) -> Vector3:
	return rig.snap(g)


static func field_to_art(f: Vector2) -> Vector2:
	return Vector2(f.x, Board.TOP + f.y * Board.K) * Board.PX * 2.0


static func art_to_field(a: Vector2) -> Vector2:
	var b := a / (2.0 * Board.PX)
	return Vector2(b.x, (b.y - Board.TOP) / Board.K)


## The ground point (y = 0) under an art pixel.
func art_to_ground(a: Vector2) -> Vector3:
	return rig.art_to_ground(a)


## Where a world point shows, in art pixels.
func world_to_art(w: Vector3) -> Vector2:
	return rig.world_to_art(w)


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
	rig.apply()
