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
const AIR_STRIKE := preload("res://effects/gale_air_strike/air_strike.tscn")
const MUZZLE := "GaleTankRig/Skeleton3D/mixamorig_LeftHand/Shield/BashPoint"
const STRIKE_POINT := "GaleTankRig/AirStrikePoint" # where Air Strike's slam lets go (on the ground by the shield)
const STRIKE_BEAM := 0.42 # Air Strike's beam width, at source scale (the effect's own)
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
var strike_point: Node3D
var strike: GaleAirStrike # Air Strike's trail, waiting to blast (or blasting)
var fires := 0 # beams fired so far, and the hero's clip time at the last one (for the tests)
var fired_clip := -1.0
var strikes := 0 # Air Strikes laid so far, the clip time, origin and length of the last (for the tests)
var strike_clip := -1.0
var strike_from := Vector3.ZERO
var strike_len := 0.0
## The unified style: the hero is drawn in the board's one shared 3D world (Hero3D.rig), so the beam is drawn there
## too, by the board's one camera (no viewport or camera of its own here).
var shared := false


func setup(h: Hero3D, board_view: Vector2, board_px: float) -> void:
	hero = h
	view = board_view
	px = board_px
	muzzle = hero.model.get_node_or_null(MUZZLE)
	strike_point = hero.model.get_node_or_null(STRIKE_POINT)
	if hero.rig:
		shared = true
		cam = hero.rig.cam
		return
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


## True when this hero's model has the beam's clip and muzzle (or Air Strike's clip and its point).
static func fits(h: Hero3D) -> bool:
	return h != null and ((h.ap.has_animation("air_beam_cast") and h.model.get_node_or_null(MUZZLE) != null) or can_strike(h))


## True when this hero's model has Air Strike's clip and the point its slam lets go from.
static func can_strike(h: Hero3D) -> bool:
	return h != null and h.ap.has_animation("air_strike") and h.model.get_node_or_null(STRIKE_POINT) != null


## Lines this camera up with the hero's: the hero's viewport (BOX, feet at FEET, in its own pixels) sits at the
## hero's spot on the board, so the board's centre is that many units over from the hero camera's centre.
func _follow() -> void:
	if shared:
		return
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
	var aim := _aim(dir, k)
	var s: float = hero.fit_scale.x
	_show()
	var length := EDGE.length_to_edge(cam, muzzle.global_position, aim, OVERSCAN * s)
	if length <= 0.0:
		# starting off screen: no beam to see (the hit still lands, Game.air_stream owns it)
		_idle()
		return
	beam = AIR_BEAM.instantiate()
	_root().add_child(beam) # the world's root: unscaled, not on the bone
	if not shared:
		for n in beam.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).layers = LAYER
	beam.radius_m = RADIUS * s
	beam.finished.connect(_idle)
	beam.activate(muzzle.global_position, aim, length, DURATION, muzzle)


## The ground-direction of a board direction `dir` (x right, y down the map), as Hero3D.face turns the model for it
## (in the shared world, through the turned frame the hero stands in).
func _aim(dir: Vector2, k: float) -> Vector3:
	var screen := Vector2(dir.x, dir.y * k)
	var g := Vector2(screen.x, screen.y / sin(deg_to_rad(hero.pitch)))
	var a := Vector3(g.x, 0, g.y).normalized()
	return (hero.anchor.global_basis * a).normalized() if shared else a


## The 3D node the beam and the strike are added to.
func _root() -> Node:
	return hero.rig if shared else vp


func _show() -> void:
	if shared:
		return
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pic.visible = true


## Air Strike lets go: from AirStrikePoint, toward `dir` (board axes), the trail runs to the screen edge, locked there
## (it doesn't follow Gale after this). `width` and `delay` are the ability's (world pixels, seconds). After `delay`
## the whole trail blasts once and calls `on_blast`; the game owns what that hits. Driven by tick() at game speed.
func strike_at(dir: Vector2, k: float, width: float, delay: float, on_blast: Callable) -> bool:
	stop()
	if strike_point == null or dir == Vector2.ZERO:
		return false
	_follow()
	var aim := _aim(dir, k)
	var s: float = hero.fit_scale.x
	var from := strike_point.global_position
	_show()
	var length := EDGE.length_to_edge(cam, from, aim, OVERSCAN * s)
	if length <= 0.0:
		_idle()
		return false
	strikes += 1
	strike_clip = hero.ap.current_animation_position
	strike_from = from
	strike_len = length
	strike = AIR_STRIKE.instantiate()
	_root().add_child(strike) # the world's root: unscaled, not on the hero
	# the ability's width, from world units to metres (the shared world: art pixels per unit times metres per pixel)
	strike.path_radius = width * (hero.art_per_unit * StyleRig.UNIT if shared else hero.cam.size / Hero3D.BOX.y / hero.scale.x)
	strike.beam_radius = STRIKE_BEAM * s
	strike.blast_triggered.connect(func(_a, _b, _r): on_blast.call(), CONNECT_ONE_SHOT)
	strike.finished.connect(func(): strike = null; _idle())
	if not strike.activate(from, aim, length, 0.0, delay):
		strike.queue_free()
		_idle()
		return false
	strike.set_process(false) # tick() runs its clock, so it keeps to game speed and stops on pause
	if not shared:
		for n in strike.find_children("*", "VisualInstance3D", true, false):
			(n as VisualInstance3D).layers = LAYER
	return true


## Runs Air Strike's clock by `dt` game seconds.
func tick(dt: float) -> void:
	if strike and is_instance_valid(strike):
		strike._process(dt)


## Ends a beam or a waiting Air Strike at once (the hero was knocked out, or is gone): no blast comes after.
func stop() -> void:
	if beam and is_instance_valid(beam):
		beam.finish(true)
	beam = null
	if strike and is_instance_valid(strike):
		strike.cancel()
	strike = null
	_idle()


func _idle() -> void:
	beam = null
	strike = null
	if pic:
		pic.visible = false
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(_dt: float) -> void:
	# (an Air Strike's trail is locked to the ground where it was laid, so the camera holds still while it shows)
	if beam and is_instance_valid(beam) and not (strike and is_instance_valid(strike)) and hero and is_instance_valid(hero):
		_follow()
