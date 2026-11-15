class_name Enemy3D
extends Node2D
## An enemy drawn live from a rigged 3D model (EnemyData.model_dir: a folder with enemy.json and the .glb), in its own
## small smooth render like Hero3D, Merge3D and Wall3D (or, with the old unified-style test on, in the shared Live3D
## layer). It faces the way it runs and plays a clip for whatever is happening to it: run (paced to its real speed,
## so a slow slows the clip by the same share, and frost creeps over it), stun, frozen (Rimeshard), knockback (pushed
## or pulled), attack (held up by a hero, whom it turns to face, or a wall), and death, which plays out after the
## enemy has left the game, before the body sinks into the ground.
## Pure visuals: the board's Crowd (below) makes one per enemy, moves it, and lets it go.

const PITCH := Hero3D.PITCH
const Q := 2 # rendered at 2x board pixels, drawn at half size
const HERO_PX := 26.0 # a 1.8 m hero is 26 board pixels tall: models share that scale
## Frost over the model while it's slowed or frozen: an icy crust on the surfaces that face up and out, and a pale
## rim, laid over its own material (material_overlay). Crust grows with `frost` (0 to 1).
const FROST := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
varying vec3 n_model;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	n_model = NORMAL;
}
void fragment() {
	float n = noise(UV * 48.0) * 0.55 + noise(UV * 140.0) * 0.45;
	float up = clamp(n_model.y * 0.6 + 0.45, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// the crust spreads from the up-facing parts as frost rises; crystals sparkle where the fine noise peaks
	float crust = smoothstep(1.05 - frost * 0.9, 1.25 - frost * 0.7, n + up * 0.6);
	float sparkle = step(0.93, noise(UV * 260.0)) * frost;
	ALBEDO = mix(vec3(0.66, 0.86, 1.0), vec3(0.96, 0.99, 1.0), n);
	ROUGHNESS = 0.2;
	SPECULAR = 0.9;
	EMISSION = vec3(0.35, 0.6, 0.85) * (rim * 0.7 + sparkle) * frost;
	ALPHA = clamp(crust * 0.9 + rim * 0.55 * frost + sparkle, 0.0, 0.95) * min(1.0, frost * 3.0);
}
"""
static var _frost_shader: Shader
const DEATH_HOLD := 0.6 # seconds the body lies still after the death clip, before it sinks
const SINK := 0.45 # seconds to sink into the ground

static var _cfgs := {} # model dir -> enemy.json

var cfg: Dictionary
var anims: Dictionary
var model: Node3D
var ap: AnimationPlayer
var vp: SubViewport # its own render (null in the shared layer)
var pic: Sprite2D
var live: Live3D # the shared layer, when the unified-style test is on
var anchor: Node3D
var top := 20.0 # how tall it shows on the board, in board pixels (for the health bar)
var yaw := 0.0
var want_yaw := 0.0
var state := ""
var last := Vector2.INF
var frost := 0.0 # how frosted it shows (eases toward the slow)
var frost_mat: ShaderMaterial
var dead_t := -1.0 # time since it died, -1 while alive
var _h := 1.5 # its height in metres


## True when this enemy type has a model to draw.
static func has_model(d: EnemyData) -> bool:
	return d != null and d.model_dir != "" and not _cfg(d.model_dir).is_empty()


static func _cfg(dir: String) -> Dictionary:
	if not _cfgs.has(dir):
		var p := dir.path_join("enemy.json")
		var c = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
		_cfgs[dir] = c if c is Dictionary else {}
	return _cfgs[dir]


## dir: the model folder. r: the enemy's radius (9 is normal size; bigger types of the same model stand taller).
## shared: the Live3D layer to stand in, or null for its own render.
func setup(dir: String, r: float, shared: Live3D = null) -> void:
	cfg = _cfg(dir)
	anims = cfg.get("anims", {})
	model = (load(dir.path_join(cfg.model)) as PackedScene).instantiate()
	ap = model.find_child("AnimationPlayer", true, false)
	var bb := AABB()
	for n in model.find_children("*", "MeshInstance3D", true, false):
		bb = bb.merge((n as MeshInstance3D).get_aabb())
	_h = float(cfg.get("height", 1.5)) * clampf(r / 9.0, 0.6, 2.5)
	if bb.size.y > 0.01:
		model.scale = Vector3.ONE * (_h / bb.size.y)
	for s in ["idle", "walk", "stun", "frozen"]:
		_loop(s, Animation.LOOP_LINEAR)
	for s in ["knockback", "attack", "death"]:
		_loop(s, Animation.LOOP_NONE)
	if _frost_shader == null:
		_frost_shader = Shader.new()
		_frost_shader.code = FROST
	frost_mat = ShaderMaterial.new()
	frost_mat.shader = _frost_shader
	for n in model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = frost_mat
	frost_mat.set_shader_parameter("frost", 0.0)
	var p := deg_to_rad(PITCH)
	var upp := 1.8 * cos(p) / HERO_PX # metres per board pixel
	top = _h * cos(p) / upp
	if shared:
		live = shared
		anchor = live.rig.add_model(model, 0.3 * _h / 1.5, true)
	else:
		# a box that fits the tail swung any way and the body fallen over in death
		var reach := _h * 0.75 / upp
		var box := Vector2(ceilf(2 * reach + 6), ceilf(top + reach * sin(p) * 2 + 8))
		var foot := Vector2(box.x / 2, box.y - reach * sin(p) - 3)
		vp = SubViewport.new()
		vp.size = Vector2i(box * Q)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		Hero3D.clean_light(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.rotation = Vector3(-p, 0, 0)
		cam.size = box.y * upp
		cam.position = Vector3(0, sin(p), cos(p)) * 20.0
		cam.position += Vector3(0, cos(p), -sin(p)) * (foot.y - box.y / 2) * upp
		cam.position += Vector3.RIGHT * -(foot.x - box.x / 2) * upp
		cam.near = 0.1
		cam.far = 60.0
		vp.add_child(cam)
		cam.current = true
		vp.add_child(model)
		_paint(model)
		pic = Sprite2D.new()
		pic.texture = vp.get_texture()
		pic.centered = false
		pic.scale = Vector2.ONE / Q
		pic.position = -foot
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(pic)
	yaw = _face(Vector2(-1, 0.3)) # until it first moves
	want_yaw = yaw
	play("walk", 1.0, 0.0)


func _loop(s: String, mode: int) -> void:
	var clip: String = anims.get(s, "")
	if clip != "" and ap.has_animation(clip):
		ap.get_animation(clip).loop_mode = mode


## Smooth texture filtering on its own copies of the materials (as Hero3D does).
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


## The turn that faces a direction on the board as drawn (x right, y down the screen), through the camera's tilt.
func _face(screen: Vector2) -> float:
	if live:
		return Live3D.face(screen)
	var g := Vector2(screen.x, screen.y / sin(deg_to_rad(PITCH)))
	return atan2(g.x, g.y)


func play(s: String, rate: float, blend := 0.12) -> void:
	var clip: String = anims.get(s, "")
	if clip == "" or not ap.has_animation(clip):
		return
	ap.speed_scale = rate
	if state == s:
		return
	state = s
	ap.play(clip, blend)


## One frame for a living enemy standing at this node's position (board world units). speed: the game's speed (0
## while paused); dt: real seconds; hero: where the hero stands (board world units), or INF.
func tick(e: Enemy, speed: float, dt: float, hero := Vector2.INF) -> void:
	var gdt := dt * speed
	var moved := Vector2.ZERO if last == Vector2.INF else position - last
	last = position
	var pushed := (e.push_t > 0 or e.pull_t > 0) and not e.pushback_immune
	var frozen := e.rime_frz > 0
	# face the way it walks (not while thrown backwards, dragged, stunned or frozen)
	if moved.length() > 0.02 and not pushed and e.stun_t <= 0 and not frozen:
		want_yaw = _face(moved)
	var slowed := e.slow_t > 0 and e.slow > 0.01
	# the run keeps pace with how fast it really moves: a 40% slow plays the clip 40% slower
	var pace := clampf(e.speed / float(cfg.get("walk_speed", 52.0)), 0.4, 2.5) * ((1.0 - e.slow) if slowed else 1.0)
	if frozen:
		play("frozen", speed, 0.05)
	elif e.stun_t > 0:
		play("stun", speed)
	elif pushed:
		play("knockback", speed, 0.06)
	elif e.blocked:
		# held up: claw at what's in the way, over and over, facing the hero when it's the hero
		if hero != Vector2.INF and position.distance_to(hero) < 60.0:
			want_yaw = _face(hero - position)
		play("attack", speed * (1.0 - e.slow if slowed else 1.0))
		if not ap.is_playing():
			state = ""
			play("attack", speed * (1.0 - e.slow if slowed else 1.0))
	elif moved.length() > 0.01 or speed <= 0.0:
		play("walk", speed * pace)
	else:
		play("idle", speed)
	# frost creeps over it while slowed (more for a stronger slow) and covers it while frozen, with a slight icy tint
	var want := 1.0 if frozen else (clampf(0.35 + 0.6 * e.slow, 0.0, 0.75) if slowed else 0.0)
	frost = move_toward(frost, want, gdt * (4.0 if want > frost else 1.5))
	frost_mat.set_shader_parameter("frost", frost)
	modulate = Color.WHITE.lerp(Color(0.8, 0.92, 1.15), frost)
	_turn(gdt)


func _turn(gdt: float) -> void:
	yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-gdt * 10.0))
	model.rotation.y = yaw
	if anchor:
		anchor.visible = is_visible_in_tree()
		live.place(anchor, position)


## Starts the death; then call dying() each frame until it returns false (and free it).
func die(speed: float) -> void:
	dead_t = 0.0
	state = ""
	if anims.has("death"):
		play("death", speed, 0.05)


func dying(speed: float, dt: float) -> bool:
	ap.speed_scale = speed
	dead_t += dt * speed
	var clip: String = anims.get("death", "")
	var length := ap.get_animation(clip).length if clip != "" and ap.has_animation(clip) else 0.0
	var sink := (dead_t - length - DEATH_HOLD) / SINK
	if sink > 0.0:
		model.position.y = -sink * _h * 0.5
		modulate.a = clampf(1.0 - sink, 0.0, 1.0)
	_turn(0.0)
	return sink < 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and anchor and is_instance_valid(anchor):
		anchor.queue_free()


## The board's set of model enemies: one Enemy3D per living enemy whose type has a model, in the board's depth-sorted
## layer at its feet; the killed ones stay to play their death out.
class Crowd:
	var views := {} # Enemy -> Enemy3D
	var dying: Array[Enemy3D] = []

	## The model view of an enemy, or null.
	func view_of(e: Enemy) -> Enemy3D:
		var v = views.get(e)
		return v if v != null and is_instance_valid(v) else null

	## enemies: the run's. at(e): the board point of its feet. layer: the depth-sorted node to stand them in. live:
	## the shared layer (or null). px: board pixels per world unit. hero: where the hero stands, or INF. light: called with each new view's viewport (the map's lighting), may be empty.
	func sync(enemies: Array, at: Callable, layer: Node2D, live: Live3D, speed: float, dt: float, px: float, light: Callable, hero := Vector2.INF) -> void:
		var seen := {}
		for e: Enemy in enemies:
			if e.dead or not Enemy3D.has_model(e.data):
				continue
			seen[e] = true
			var v := view_of(e)
			if v == null or (v.live != live):
				if v:
					v.queue_free()
				v = Enemy3D.new()
				v.name = "Enemy3D"
				v.scale = Vector2.ONE / px
				layer.add_child(v)
				v.setup(e.data.model_dir, e.r, live)
				if v.vp and light.is_valid():
					light.call(v.vp)
				views[e] = v
			v.position = at.call(e)
			v.tick(e, speed, dt, hero)
		# gone from the game: killed ones play their death, the rest (reached the base, a wave restart) just go
		for e in views.keys():
			if seen.has(e):
				continue
			var v := view_of(e)
			views.erase(e)
			if v == null:
				continue
			if e.dead and e.hp <= 0.0 and v.anims.has("death"):
				v.die(speed)
				dying.append(v)
			else:
				v.queue_free()
		for v in dying.duplicate():
			if not is_instance_valid(v):
				dying.erase(v)
			elif not v.dying(speed, dt):
				v.queue_free()
				dying.erase(v)

	## Drops every model (a new run, or the look changing).
	func clear() -> void:
		for v in views.values():
			if is_instance_valid(v):
				v.queue_free()
		for v in dying:
			if is_instance_valid(v):
				v.queue_free()
		views.clear()
		dying.clear()
