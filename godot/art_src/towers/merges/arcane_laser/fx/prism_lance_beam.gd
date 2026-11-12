class_name PrismLanceBeam
extends Node2D
## Prism Lance's sustained beam, drawn on the board in 2D like the base Prism Laser's beam (Board._laser_beam), from
## the model's Muzzle (Board.merge_muzzle) to the target. Pure visuals: the game owns targets, heat and damage.
##
##   var b := PRISM_BEAM.instantiate()   # res://art_src/towers/merges/arcane_laser/fx/prism_lance_beam.tscn
##   board.top.add_child(b)
##   b.start(muzzle, target)             # the beam's front runs out to the target in 0.07 s
##   every frame: b.set_ends(muzzle, target); b.heat = t.stacks / t.ramp_max; b.tick(game_dt)  (or leave driven off)
##   b.stop()                            # fades in 0.12 s, then emits `faded` (stop(true) also frees it)
## Width at heat 0 is `width_px` (the glow's full width, board pixels); heat 1 is WIDTH_HOT times that.

signal faded

const SHADER := preload("res://art_src/towers/merges/arcane_laser/fx/prism_lance_beam.gdshader")
const WIDTH_HOT := 1.8
const GROW := 0.07 # s for the front to reach the target
const FADE := 0.12 # s to fade out after stop()

@export_range(0.0, 1.0) var heat := 0.0
@export var width_px := 14.0
var from := Vector2.ZERO
var to := Vector2(100, 0)
var on := false
## Stepped by the game (tick) instead of the engine's clock, so it pauses and speeds up with the game.
var driven := false

var _t := 0.0
var _grow := 0.0
var _fade := 0.0
var _free_after := false
var _mesh: MeshInstance2D
var _mat: ShaderMaterial
var _caps: Node2D


func _init() -> void:
	_mesh = MeshInstance2D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	_mesh.mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mesh.material = _mat
	add_child(_mesh)
	_caps = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_caps.material = add
	_caps.draw.connect(_draw_caps)
	add_child(_caps)
	visible = false


func start(a: Vector2, b: Vector2) -> void:
	from = a
	to = b
	on = true
	_grow = 0.0
	_fade = 1.0
	visible = true
	_apply()


## A new target while the beam is on: the front runs out again (the heat is the game's to reset).
func retarget(b: Vector2) -> void:
	to = b
	_grow = 0.0


func set_ends(a: Vector2, b: Vector2) -> void:
	from = a
	to = b


func stop(free_after := false) -> void:
	on = false
	_free_after = free_after


func tick(dt: float) -> void:
	driven = true
	_step(dt)


func _process(dt: float) -> void:
	if not driven:
		_step(dt)


func _step(dt: float) -> void:
	if not visible:
		return
	_t += dt
	if on:
		_grow = minf(1.0, _grow + dt / GROW)
	else:
		_fade -= dt / FADE
		if _fade <= 0.0:
			_fade = 0.0
			visible = false
			faded.emit()
			if _free_after:
				queue_free()
			return
	_apply()


## The beam's colour at a heat (cold laser cyan -> #FF6FA0 -> hot arcane magenta), for matching effects.
static func heat_color(h: float) -> Color:
	var cold := Color(0.25, 0.86, 1.0)
	var warm := Color(1.0, 0.435, 0.627)
	var hot := Color(1.0, 0.16, 0.72)
	return cold.lerp(warm, h * 2.0) if h < 0.5 else warm.lerp(hot, h * 2.0 - 1.0)


func _width() -> float:
	return width_px * (1.0 + (WIDTH_HOT - 1.0) * clampf(heat, 0.0, 1.0))


func _apply() -> void:
	var d := to - from
	var full := d.length()
	var l := maxf(0.5, full * _grow)
	var dir := d / full if full > 0.001 else Vector2.RIGHT
	_mesh.position = from + dir * l * 0.5
	_mesh.rotation = dir.angle()
	_mesh.scale = Vector2(l, _width())
	_mat.set_shader_parameter("heat", clampf(heat, 0.0, 1.0))
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("length_px", l)
	_mat.set_shader_parameter("fade", _fade)
	_caps.queue_redraw()


func _draw_caps() -> void:
	var h := clampf(heat, 0.0, 1.0)
	var c := heat_color(h)
	var fl := 1.0 + (0.08 + 0.15 * h) * sin(_t * 61.0)
	var a := _fade
	# the emitter flare on the crystal tip
	var r0 := (3.5 + 3.0 * h) * fl
	_caps.draw_circle(from, r0 * 2.0, Color(c, 0.18 * a))
	_caps.draw_circle(from, r0, Color(c, 0.55 * a))
	_caps.draw_circle(from, r0 * 0.45, Color(1, 1, 1, 0.9 * a))
	if _grow < 1.0:
		return
	# the impact: a hot glow, a white core and turning rays (more and longer as it heats)
	var r1 := (5.0 + 6.0 * h) * fl
	_caps.draw_circle(to, r1 * 2.2, Color(c, 0.16 * a))
	_caps.draw_circle(to, r1, Color(c, 0.5 * a))
	_caps.draw_circle(to, r1 * 0.45, Color(1, 1, 1, 0.85 * a))
	var rays := 4 + int(round(3.0 * h))
	for i in rays:
		var ang := _t * (3.0 + 4.0 * h) + TAU * i / rays
		var ln := (7.0 + 10.0 * h) * (0.75 + 0.25 * sin(_t * 23.0 + i * 1.7))
		var v := Vector2.from_angle(ang)
		_caps.draw_line(to + v * r1 * 0.4, to + v * (r1 * 0.4 + ln), Color(c.lerp(Color.WHITE, 0.35), 0.75 * a), 1.5 + h)
