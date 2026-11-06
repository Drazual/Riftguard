class_name Wall3D
extends Node2D
## A wizard's wall (Stone Wall, Great Wall) drawn live from its 3D model, like Hero3D draws heroes: rendered every
## frame into a small transparent viewport by an orthographic camera at the board's angle. The wall never aims or
## turns once placed: it stands across the path, its front toward the enemies coming. It rises (spawn), breathes
## (idle), shakes when hit (hit_react) and sinks into the ground when it times out (despawn) or breaks (break).
## Its look wears down with its HP: three stages (Wear0..2), exactly one shown.
## The game owns everything else: where it stands, its HP, blocking, its slam and how long it lasts.

const PITCH := Hero3D.PITCH
const K := 0.75 # Board.K
const Q := 2 # rendered at 2x board pixels, drawn at half size
const BOX := Vector2(150, 120) # the viewport in board pixels
const FOOT := Vector2(75, 84) # where the wall's base centre lands in the viewport
## Board pixels per model metre: the heroes' scale (a 1.8 m hero is 26 px tall), times SIZE, so a wall spans the
## path about as wide as the painted walls did.
const SIZE := 0.75
const END_TIME := 0.55 # despawn and break both sink in this long

## The clip-to-ground shader: the models rise out of and sink into the ground, so whatever is below it (under the
## footprint's front edge on screen) is cut off. corners: the footprint's four base corners in UV.
const CLIP := """
shader_type canvas_item;
uniform vec2 c0; uniform vec2 c1; uniform vec2 c2; uniform vec2 c3;
float edge(vec2 a, vec2 b, float x, float y) {
	if (x < min(a.x, b.x) || x > max(a.x, b.x) || abs(b.x - a.x) < 1e-5) return y;
	return max(y, mix(a.y, b.y, (x - a.x) / (b.x - a.x)));
}
void fragment() {
	float low = -1.0;
	low = edge(c0, c1, UV.x, low); low = edge(c1, c2, UV.x, low);
	low = edge(c2, c3, UV.x, low); low = edge(c3, c0, UV.x, low);
	vec4 c = texture(TEXTURE, UV);
	if (low >= 0.0 && UV.y > low + 0.004) c.a = 0.0;
	COLOR = c * COLOR;
}
"""

var vp: SubViewport
var cam: Camera3D
var model: Node3D
var ap: AnimationPlayer
var wall: Node3D # the animated visual (holds the wear stages)
var pic: Sprite2D
var stage := -1
var ending := false
var ended_at := 0.0
var base := Rect2() # the footprint on the ground (x across, z front), in model metres


## path: the .glb. yaw: the turn about the vertical (radians) that puts the wall's front (+Z) toward the enemies.
func setup(path: String, yaw: float) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(BOX * Q)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	Hero3D.clean_light(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var p := deg_to_rad(PITCH)
	cam.rotation = Vector3(-p, 0, 0)
	var units_per_px := 1.8 * cos(p) / 26.0 / SIZE
	cam.size = BOX.y * units_per_px
	cam.position = Vector3(0, sin(p), cos(p)) * 20.0
	cam.position += Vector3(0, cos(p), -sin(p)) * (FOOT.y - BOX.y / 2) * units_per_px
	cam.position += Vector3.RIGHT * -(FOOT.x - BOX.x / 2) * units_per_px
	cam.near = 0.1
	cam.far = 60.0
	vp.add_child(cam)
	cam.current = true
	model = (load(path) as PackedScene).instantiate()
	vp.add_child(model)
	model.rotation.y = yaw
	ap = model.find_child("AnimationPlayer", true, false)
	wall = model.find_child("Wall", true, false)
	# the wear stages are exported at scale zero (a .glb can't hide a node): all at full size, one shown
	for i in 3:
		var s := wall.get_node_or_null("Wear%d" % i) as Node3D
		if s:
			s.scale = Vector3.ONE
	set_hp(1.0)
	# the game draws its own shock ring for the slam, and a flat ring at ground level would be cut by the clip
	var shock := model.find_child("GroundShock", true, false) as Node3D
	if shock:
		shock.visible = false
	base = _footprint()
	pic = Sprite2D.new()
	pic.texture = vp.get_texture()
	pic.centered = false
	pic.scale = Vector2.ONE / Q
	pic.position = -FOOT
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CLIP
	mat.shader = sh
	pic.material = mat
	add_child(pic)
	_clip_corners()
	ap.play("spawn")
	ap.queue("idle")


## The base of the pristine wall, from its meshes (model space, so before the turn).
func _footprint() -> Rect2:
	var box := AABB()
	var first := true
	var w0 := wall.get_node_or_null("Wear0")
	for n in (w0 if w0 else wall).find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		var xf := model.global_transform.affine_inverse() * mi.global_transform
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


func _clip_corners() -> void:
	var mat := pic.material as ShaderMaterial
	var pts := [Vector2(base.position.x, base.position.y), Vector2(base.end.x, base.position.y),
		Vector2(base.end.x, base.end.y), Vector2(base.position.x, base.end.y)]
	for i in 4:
		var g: Vector3 = model.global_transform * Vector3(pts[i].x, 0, pts[i].y)
		mat.set_shader_parameter("c%d" % i, cam.unproject_position(g) / Vector2(vp.size))


## Shows the wear stage for this share of HP left: above 66% pristine, above 33% worn, else critical.
func set_hp(ratio: float) -> void:
	var sel := 0 if ratio > 0.66 else (1 if ratio > 0.33 else 2)
	if sel == stage:
		return
	stage = sel
	for i in 3:
		var s := wall.get_node_or_null("Wear%d" % i) as Node3D
		if s:
			s.visible = i == sel
	var flare := wall.find_child("CrystalFlare", true, false) as Node3D
	if flare:
		flare.visible = sel < 2
	var glint := wall.find_child("CrestGlint", true, false) as Node3D
	if glint:
		glint.visible = sel < 2


## A small shake when it takes a hit (not while rising or sinking, nor over one already playing).
func hit() -> void:
	if ending or ap.current_animation in ["spawn", "hit_react"]:
		return
	ap.play("hit_react")
	ap.queue("idle")


## Keeps its clips in step with the game's speed (the Great Wall's slam lands 0.85s into the game's time).
func set_speed(s: float) -> void:
	ap.speed_scale = s


## Sinks it into the ground: "break" when it was destroyed, else "despawn". Frees itself once it's under.
func finish(broken: bool) -> void:
	if ending:
		return
	ending = true
	ap.play("break" if broken and ap.has_animation("break") else "despawn")


func _process(_dt: float) -> void:
	if ending and not ap.is_playing():
		queue_free()
