class_name BeamLayer
extends Node2D
## Gale's Air Stream beam (effects/gale_air_beam) drawn across the whole board. The hero's own viewport is a small
## box around it, so the beam, which reaches the screen edge, can't be drawn there. This layer looks into the same 3D
## world as the hero (so the beam can follow the shield's BashPoint) through a board-sized orthographic camera that
## matches the hero's camera exactly: same angle and scale, shifted so the hero lands where it stands on the board.
## Only the beam is on this camera's layer, and the hero's camera leaves it out. It renders only while a beam is on.
## The beam is cosmetic: Game.air_stream owns who it hits and for how much.

const AIR_BEAM := preload("res://effects/gale_air_beam/air_beam.tscn")
const EDGE := preload("res://effects/gale_air_beam/camera_edge.gd")
const LAYER := 1 << 19 # the render layer only the beam is on
const MUZZLE := "GaleTankRig/Skeleton3D/mixamorig_LeftHand/Shield/BashPoint"
const RADIUS := 0.46 # the beam's width at the model's source scale (CLAUDE_NOTES)
const OVERSCAN := 0.8 # how far past the screen edge its soft tip runs, at source scale
const DURATION := 0.5 # then a 0.14 s fade (the effect's own)
const SHARP := 2 # rendered at 2x the board's base art size

var hero: Hero3D
var view: Vector2 # the board's visible size, in world pixels
var px := 1.0 # Board.PX: world pixels are this many screen pixels (the hero's own pixels are 1 / PX of a world pixel)
var vp: SubViewport
var cam: Camera3D
var pic: Sprite2D
var beam: GaleAirBeam
var muzzle: Node3D
var fires := 0 # beams fired so far, and the hero's clip time at the last one (for the tests)
var fired_clip := -1.0


func setup(h: Hero3D, board_view: Vector2, board_px: float) -> void:
	hero = h
	view = board_view
	px = board_px
	muzzle = hero.model.get_node_or_null(MUZZLE)
	vp = SubViewport.new()
	vp.size = Vector2i(view * px * SHARP)
	vp.transparent_bg = true
	vp.world_3d = hero.vp.find_world_3d()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = hero.cam.rotation
	cam.cull_mask = LAYER
	cam.near = hero.cam.near
	cam.far = hero.cam.far
	vp.add_child(cam)
	cam.current = true
	hero.cam.cull_mask &= ~LAYER
	pic = Sprite2D.new()
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = view / Vector2(vp.size)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.visible = false
	add_child(pic)
	_follow()


## True when this hero's model has the beam's clip and muzzle.
static func fits(h: Hero3D) -> bool:
	return h != null and h.ap.has_animation("air_beam_cast") and h.model.get_node_or_null(MUZZLE) != null


## Lines this camera up with the hero's: the hero's viewport (BOX, feet at FEET, in its own pixels) sits at the
## hero's spot on the board, so the board's centre is that many units over from the hero camera's centre.
func _follow() -> void:
	var upp := hero.cam.size / Hero3D.BOX.y # units per hero pixel
	var unit := upp / hero.scale.x # units per world pixel (the hero is drawn at 1 / PX on the board)
	cam.size = view.y * unit
	var centre := hero.position + (Hero3D.BOX / 2 - Hero3D.FEET) * hero.scale.x
	var off := view / 2 - centre
	var b := hero.cam.global_transform.basis
	cam.global_position = hero.cam.global_position + b.x * off.x * unit - b.y * off.y * unit


## Fires the beam from the shield toward `dir` (on the ground, board axes: x right, y down the map), its aim locked;
## it follows the shield's position for its 0.5 s, then fades.
func fire(dir: Vector2, k: float) -> void:
	stop()
	if muzzle == null or dir == Vector2.ZERO:
		return
	fires += 1
	fired_clip = hero.ap.current_animation_position
	_follow()
	# the same turn Hero3D.face gives the model for this direction on screen
	var screen := Vector2(dir.x, dir.y * k)
	var g := Vector2(screen.x, screen.y / sin(deg_to_rad(Hero3D.PITCH)))
	var aim := Vector3(g.x, 0, g.y).normalized()
	var s: float = hero.fit_scale.x
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pic.visible = true
	var length := EDGE.length_to_edge(cam, muzzle.global_position, aim, OVERSCAN * s)
	if length <= 0.0:
		# starting off screen: no beam to see (the hit still lands, Game.air_stream owns it)
		_idle()
		return
	beam = AIR_BEAM.instantiate()
	vp.add_child(beam) # the world's root: unscaled, not on the bone
	for n in beam.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = LAYER
	beam.radius_m = RADIUS * s
	beam.finished.connect(_idle)
	beam.activate(muzzle.global_position, aim, length, DURATION, muzzle)


## Ends a beam at once (the hero was knocked out, or is gone).
func stop() -> void:
	if beam and is_instance_valid(beam):
		beam.finish(true)
	beam = null
	_idle()


func _idle() -> void:
	beam = null
	if pic:
		pic.visible = false
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(_dt: float) -> void:
	if beam and is_instance_valid(beam) and hero and is_instance_valid(hero):
		_follow()
