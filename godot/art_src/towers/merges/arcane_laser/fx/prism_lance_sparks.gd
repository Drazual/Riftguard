class_name PrismLanceSparks
extends Node2D
## Prism Lance's arcane sparks: magenta rune-sparks that burst off the beam's impact point and arc to nearby
## enemies, popping when they land. One node can hold any number of sparks; it stays on the board (no "f" meta, so
## the board's reaper leaves it alone) and draws nothing when idle. Pure visuals: the game picks the targets and
## deals the damage, either at once or in the on_hit callback (called when a spark lands).
##
##   sparks.burst(impact, [e1_pos, e2_pos], heat, func(i): ...)   # sparks to each target, more and bigger with heat
##   sparks.spawn_spark(from, to, heat, on_hit, delay)            # one spark
##   sparks.tick(game_dt)                                         # optional: step in game time (else _process)

signal spark_hit(at: Vector2)

const FLIGHT_MIN := 0.16
const FLIGHT_MAX := 0.38
const SPEED := 700.0 # board px/s, for the flight time
const POP := 0.2
const EMBER := 0.25

var driven := false
var sparks: Array[Dictionary] = []
var pops: Array[Dictionary] = []
var embers: Array[Dictionary] = []
var _t := 0.0


func _init() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


## Sparks from `from` (the impact point) to every position in `targets`. Per target: 1 spark at low heat, 2 from
## heat 0.4, 3 from heat 0.8 (only the first of each calls on_hit(index)). Plus a crown of embers at the impact.
## Returns how many sparks were made.
func burst(from: Vector2, targets: Array, heat: float, on_hit := Callable()) -> int:
	var h := clampf(heat, 0.0, 1.0)
	var per := 1 + (1 if h >= 0.4 else 0) + (1 if h >= 0.8 else 0)
	var n := 0
	for i in targets.size():
		for k in per:
			var cb := on_hit.bind(i) if on_hit.is_valid() and k == 0 else Callable()
			spawn_spark(from, targets[i], h, cb, 0.035 * k + 0.02 * i)
			n += 1
	for i in 3 + int(round(6.0 * h)):
		var ang := randf() * TAU
		embers.append({ p = from, v = Vector2.from_angle(ang) * randf_range(40.0, 90.0 + 80.0 * h) + Vector2(0, -30), t = 0.0, heat = h })
	queue_redraw()
	return n


## One spark from `from` to `to` on a curved path, after `delay` seconds.
func spawn_spark(from: Vector2, to: Vector2, heat: float, on_hit := Callable(), delay := 0.0) -> void:
	var d := to - from
	var l := d.length()
	var nrm := Vector2(-d.y, d.x) / l if l > 0.01 else Vector2.UP
	var side := -1.0 if randf() < 0.5 else 1.0
	var c := (from + to) * 0.5 + nrm * side * l * randf_range(0.22, 0.42) + Vector2(0, -l * 0.25 - 8.0)
	sparks.append({ a = from, c = c, b = to, t = -delay, T = clampf(0.1 + l / SPEED, FLIGHT_MIN, FLIGHT_MAX), heat = clampf(heat, 0.0, 1.0), cb = on_hit, spin = randf() * TAU })
	queue_redraw()


func busy() -> bool:
	return not (sparks.is_empty() and pops.is_empty() and embers.is_empty())


func tick(dt: float) -> void:
	driven = true
	_step(dt)


func _process(dt: float) -> void:
	if not driven:
		_step(dt)


func _step(dt: float) -> void:
	if not busy():
		return
	_t += dt
	for s in sparks:
		s.t += dt
	for s in sparks.filter(func(s): return s.t >= s.T):
		pops.append({ p = s.b, t = 0.0, heat = s.heat, seed = randf() * TAU })
		var cb: Callable = s.cb
		if cb.is_valid():
			cb.call()
		spark_hit.emit(s.b)
	sparks = sparks.filter(func(s): return s.t < s.T)
	for p in pops:
		p.t += dt
	pops = pops.filter(func(p): return p.t < POP)
	for e in embers:
		e.t += dt
		e.p += e.v * dt
		e.v *= 0.9
		e.v.y += 160.0 * dt
	embers = embers.filter(func(e): return e.t < EMBER)
	queue_redraw()


static func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


func _draw() -> void:
	for s in sparks:
		if s.t < 0:
			continue
		var h: float = s.heat
		var col := Color(1.0, 0.25 + 0.1 * (1.0 - h), 0.78)
		var u: float = s.t / s.T
		u = u * u * (1.6 - 0.6 * u) # a little slow off the impact, then fast in
		var head := _bez(s.a, s.c, s.b, u)
		var bright := 0.7 + 0.3 * h
		# the trail
		var prev := _bez(s.a, s.c, s.b, maxf(0.0, u - 0.4))
		for j in range(1, 9):
			var uu := maxf(0.0, u - 0.4 + 0.4 * j / 8.0)
			var p := _bez(s.a, s.c, s.b, uu)
			var k := j / 8.0
			draw_line(prev, p, Color(col, 0.55 * k * bright), (1.0 + 2.5 * h) * k + 0.8)
			prev = p
		# the head: a glow and a turning rune diamond
		var sz := 2.5 + 2.5 * h
		draw_circle(head, sz * 2.0, Color(col, 0.14 * bright))
		var rot: float = s.spin + _t * 14.0
		var pts := PackedVector2Array()
		for q in 4:
			var r := sz * (1.35 if q % 2 == 0 else 0.75)
			pts.append(head + Vector2.from_angle(rot + q * PI / 2) * r)
		draw_colored_polygon(pts, Color(col.lerp(Color.WHITE, 0.35), 0.95 * bright))
		draw_circle(head, sz * 0.45, Color(1, 1, 1, bright))
	for p in pops:
		var q: float = p.t / POP
		var h: float = p.heat
		var col := Color(1.0, 0.3, 0.8)
		var e := 1.0 - (1.0 - q) * (1.0 - q) * (1.0 - q)
		draw_arc(p.p, (4.0 + 7.0 * h) * e + 1.0, 0, TAU, 20, Color(col, 0.85 * (1.0 - q)), 1.5 + h)
		draw_circle(p.p, (2.5 + 2.5 * h) * (1.0 - q), Color(1, 0.85, 0.97, 0.85 * (1.0 - q)))
		for i in 4 + int(round(4.0 * h)):
			var v := Vector2.from_angle(p.seed + TAU * i / (4 + int(round(4.0 * h))))
			draw_line(p.p + v * (3.0 + 10.0 * e), p.p + v * (6.0 + (8.0 + 8.0 * h) * e), Color(col.lerp(Color.WHITE, 0.4), 1.0 - q), 1.2)
	for e in embers:
		var q: float = e.t / EMBER
		draw_circle(e.p, 1.0 + 1.0 * e.heat, Color(1.0, 0.45, 0.85, 1.0 - q))
