class_name Beacon3D
extends Node2D
## The Rift Beacon drawn live from its 3D model (art_src/towers/rift_beacon, through its RiftBeaconVisual wrapper),
## in its own smooth render like Hero3D and Wall3D: the rings spin, buff_pulse() flashes it each time the aura
## ticks, and its ground ring (the wrapper's AuraRing) is drawn the size of the tower's buff range.
## Two cameras look at the one model world: one draws the tower (in the board's depth-sorted layer), the other
## only the flat aura ring, at the ground's own tilt (Board.K), into a ground layer under every unit.
## Pure visuals: the game owns the range, the buff and when it ticks.

const SCENE := "res://art_src/towers/rift_beacon/fx/rift_beacon.tscn"
const PITCH := Hero3D.PITCH
const Q := 2 # rendered at 2x board pixels, drawn at half size
const BOX := Vector2(110, 110) # the tower's viewport, in board pixels
const FOOT := Vector2(55, 96) # where the tower's base centre lands in it
const WIDE := 50.0 # how wide the tower shows, in board pixels (about the old sprite's width)
const MODEL_W := 1.9 # the model's width in metres (CLAUDE_NOTES)
const RING_LAYER := 2 # render layer of the aura ring: only the ground camera sees it

var vp: SubViewport
var cam: Camera3D
var vis: Node3D # the RiftBeaconVisual
var pic: Sprite2D
var ring_vp: SubViewport
var ring_cam: Camera3D
var ring_pic: Sprite2D
var radius := 0.0 # the aura's radius on the board, in board world units
var ring_at := Vector2.ZERO # the aura's centre on the board (the tower's tile), in board world units
var _upp := 0.0 # model metres per board pixel


static func available() -> bool:
	return ResourceLoader.exists(SCENE)


## ground: the node the aura ring is drawn in (under the units). radius: the buff range in board world units.
func setup(ground: Node2D, range_r: float) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(BOX * Q)
	vp.transparent_bg = true
	vp.world_3d = World3D.new() # its own world, shared with the ring's camera below
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	Hero3D.clean_light(vp)
	var p := deg_to_rad(PITCH)
	_upp = 1.8 * cos(p) / 26.0 # the heroes' scale: a 1.8 m hero is 26 board pixels tall
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation = Vector3(-p, 0, 0)
	cam.size = BOX.y * _upp
	cam.position = Vector3(0, sin(p), cos(p)) * 20.0
	cam.position += Vector3(0, cos(p), -sin(p)) * (FOOT.y - BOX.y / 2) * _upp
	cam.position += Vector3.RIGHT * -(FOOT.x - BOX.x / 2) * _upp
	cam.near = 0.1
	cam.far = 60.0
	cam.cull_mask = 1
	vp.add_child(cam)
	cam.current = true
	vis = (load(SCENE) as PackedScene).instantiate()
	vis.scale = Vector3.ONE * (WIDE * _upp / MODEL_W)
	vp.add_child(vis)
	var aura := vis.get_node("AuraRing") as MeshInstance3D
	aura.layers = RING_LAYER
	pic = Sprite2D.new()
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = Vector2.ONE / Q
	pic.position = -FOOT
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(pic)
	# the aura ring: the same world, seen from straight along the ground's tilt so it lies exactly on the range
	ring_vp = SubViewport.new()
	ring_vp.transparent_bg = true
	ring_vp.world_3d = vp.world_3d
	ring_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(ring_vp)
	ring_cam = Camera3D.new()
	ring_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	ring_cam.near = 0.1
	ring_cam.far = 60.0
	ring_cam.cull_mask = RING_LAYER
	ring_vp.add_child(ring_cam)
	ring_cam.current = true
	ring_pic = Sprite2D.new()
	ring_pic.texture = ring_vp.get_texture()
	ring_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# the ring's shader is additive, so its viewport holds light with no alpha: add it onto the ground the same way
	var rm := ShaderMaterial.new()
	var rs := Shader.new()
	rs.code = "shader_type canvas_item;\nrender_mode blend_add;\nvoid fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0) * vec4(1.0, 1.0, 1.0, COLOR.a); }\n"
	rm.shader = rs
	ring_pic.material = rm
	ground.add_child(ring_pic)
	# the ring covers the whole buff range here (much wider than the delivery's 3 m), over bright painted ground:
	# a thinner edge and a softer master level keep it from washing out to white
	var rmat := aura.material_override as ShaderMaterial
	if rmat:
		rmat.set_shader_parameter("edge_width", 0.015)
		rmat.set_shader_parameter("intensity", 0.35)
	set_radius(range_r)
	vis.play_spawn()


## Sizes the wrapper's ground ring to the buff range (board world units) and fits the ground camera around it.
func set_radius(r: float) -> void:
	if is_equal_approx(r, radius):
		return
	radius = r
	var px := r * Board.PX # the radius in board pixels
	var m := px * _upp # ... in metres
	vis.aura_radius = m / vis.scale.x
	# the camera looks down at asin(K), so the ground's depth is squashed by K, like the board's own range rings
	var q := asin(Board.K)
	var side := px * 2.0 + 12.0
	ring_vp.size = Vector2i(ceili(side), ceili(side * Board.K))
	ring_cam.rotation = Vector3(-q, 0, 0)
	ring_cam.size = ring_vp.size.y * _upp
	ring_cam.position = Vector3(0, sin(q), cos(q)) * 30.0
	ring_pic.scale = Vector2.ONE / Board.PX # board pixels, in the ground layer's world units


## Every time the aura applies its buff.
func pulse() -> void:
	vis.buff_pulse()


func set_aura_visible(on: bool) -> void:
	vis.show_aura = on
	ring_pic.visible = on and is_visible_in_tree()


func set_speed(s: float) -> void:
	var ap: AnimationPlayer = vis.anim
	if ap:
		vis.spin_speed = s
		ap.speed_scale = s


func _process(_dt: float) -> void:
	# the ring is centred on the tower's tile, like the board's own range rings
	if ring_pic and is_instance_valid(ring_pic):
		ring_pic.position = ring_at
		ring_pic.visible = vis.show_aura and is_visible_in_tree()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and ring_pic and is_instance_valid(ring_pic):
		ring_pic.queue_free()
