class_name CryoCannonFX
extends Node2D
## Cryo Cannon (frost+plasma) board FX, drawn in 2D on the board's effects layer (board.top), board pixels.
##   shoot(from, to, flight, on_hit, power)  the ice-plasma ball flies from the crown tip to `to` (short arc, frost sparkle trail)
##   burst(at, radius, power)                it explodes: white flash, plasma + ice rings, a starburst of ice spikes, flying shards
##   patch(at, radius, dur, power) -> int    the frozen ice patch: icy ground decal with cracks + ice spikes that sprout,
##                                           glitter for `dur` seconds, then shatter (shards fly) and the ice melts away
##   shatter(id), busy(), tick(game_dt)      (after the first tick() it no longer runs on _process: game time drives it)
## Positions are board px. Ground shapes use the board's ground squash K (0.75).

signal hit(at: Vector2)
signal shattered(at: Vector2, radius: float) # a patch ended (time out or shatter()); hook for the optional shard-burst damage

const K := 0.75
const BURST := 0.40
const ARC := 0.10 # the ball's upward bulge, as a share of the flight distance
const GROW := 0.30 # spikes sprout over this long (staggered)
const BREAK := 0.38 # shatter + melt at the end
const FROST := Color(0.61, 0.96, 0.87) # Frost Pylon #9CF4DD
const ICE := Color(0.55, 0.85, 1.0)
const ICE_D := Color(0.30, 0.55, 0.85)
const PLASMA := Color(0.18, 0.84, 0.69) # Plasma Cannon #2FD6B0
const CRYO := Color(0.88, 0.90, 1.0) # recipe #E0E6FF

var balls: Array = []
var bursts: Array = []
var patches: Array = []
var sparks: Array = [] # loose frost glitter + flying shards
var _driven := false
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 5
	_rng.seed = 4119


func shoot(from: Vector2, to: Vector2, flight := 0.25, on_hit := Callable(), power := 1.0) -> void:
	balls.append({ a = from, b = to, t = 0.0, T = maxf(0.05, flight), cb = on_hit, pw = power, emit = 0.0, rot = _rng.randf() * TAU })


func burst(at: Vector2, radius := 50.0, power := 1.0) -> void:
	var spikes := []
	for i in 8:
		spikes.append({ ang = TAU * i / 8.0 + _rng.randf_range(-0.25, 0.25), l = _rng.randf_range(0.55, 0.85) })
	bursts.append({ p = at, r = radius, t = 0.0, pw = power, spikes = spikes })
	for i in 8 + int(5 * power):
		var ang := _rng.randf() * TAU
		var sp := _rng.randf_range(0.8, 1.3) * radius * 2.6
		sparks.append({ p = at + Vector2(0, -6), v = Vector2(cos(ang), sin(ang) * K) * sp + Vector2(0, -60), g = 380.0, t = 0.0,
			T = _rng.randf_range(0.3, 0.45), s = _rng.randf_range(1.8, 3.0) * power, rot = _rng.randf() * TAU, w = _rng.randf_range(-12, 12), shard = true })


func patch(at: Vector2, radius := 45.0, dur := 1.6, power := 1.0) -> int:
	# an irregular icy outline, crack lines from the centre, and ice spikes sprouting at random spots inside
	var rim := PackedFloat32Array()
	for i in 24:
		rim.append(_rng.randf_range(0.86, 1.04))
	var cracks := []
	for i in 5 + int(2 * power):
		var ang := _rng.randf() * TAU
		var pts := [Vector2.ZERO]
		var d := 0.0
		while d < 0.8:
			d += _rng.randf_range(0.18, 0.3)
			ang += _rng.randf_range(-0.45, 0.45)
			pts.append(Vector2(cos(ang), sin(ang) * K) * minf(d, 0.85))
		cracks.append(pts)
	var spikes := []
	var n := 8 + int(4 * power)
	for i in n:
		var ang := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 0.78
		if i == 0:
			d = 0.0
		var h := _rng.randf_range(0.42, 0.70) * (1.3 if d < 0.25 else 1.0)
		spikes.append({ o = Vector2(cos(ang), sin(ang) * K) * d, h = h, w = h * _rng.randf_range(0.26, 0.34), tilt = _rng.randf_range(-0.35, 0.35),
			delay = _rng.randf_range(0.0, GROW * 0.6) + d * 0.12, side = _rng.randf() < 0.55, ph = _rng.randf() })
	spikes.sort_custom(func(a, b): return a.o.y < b.o.y) # back to front
	var id := _next_id
	_next_id += 1
	patches.append({ id = id, p = at, r = radius, t = 0.0, T = maxf(0.5, dur), pw = power, rim = rim, cracks = cracks, spikes = spikes, brk = -1.0 })
	return id


## Ends a patch early (its zone was removed or the run reset): the spikes shatter now.
func shatter(id: int) -> void:
	for c in patches:
		if c.id == id and c.brk < 0:
			_break(c)


func busy() -> bool:
	return balls.size() + bursts.size() + patches.size() + sparks.size() > 0


func tick(dt: float) -> void:
	_driven = true
	_step(dt)


func _process(dt: float) -> void:
	if not _driven:
		_step(dt)


func _break(c: Dictionary) -> void:
	c.brk = 0.0
	shattered.emit(c.p, c.r)
	for s in c.spikes:
		var base: Vector2 = c.p + s.o * c.r
		for k in 4:
			var ang := _rng.randf_range(-PI * 0.95, -PI * 0.05)
			var sp := _rng.randf_range(60, 130)
			sparks.append({ p = base - Vector2(0, s.h * c.r * _rng.randf_range(0.2, 0.8)), v = Vector2(cos(ang) * sp, sin(ang) * sp * 0.8), g = 420.0,
				t = 0.0, T = _rng.randf_range(0.30, 0.45), s = _rng.randf_range(2.2, 3.4) * c.pw, rot = _rng.randf() * TAU, w = _rng.randf_range(-14, 14), shard = true })


func _step(dt: float) -> void:
	if dt <= 0:
		return
	for s in balls.duplicate():
		s.t += dt
		s.emit += dt
		while s.emit > 0.02:
			s.emit -= 0.02
			var ang := _rng.randf() * TAU
			sparks.append({ p = _ball_pos(s) + Vector2(cos(ang), sin(ang)) * 5.0 * s.pw, v = Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-5, 20)),
				g = 0.0, t = 0.0, T = 0.30, s = 1.6 * s.pw, rot = ang, w = 6.0, shard = _rng.randf() < 0.5 })
		if s.t >= s.T:
			balls.erase(s)
			hit.emit(s.b)
			if s.cb.is_valid():
				s.cb.call()
	for w in sparks.duplicate():
		w.t += dt
		w.v.y += w.g * dt
		w.p += w.v * dt
		w.rot += w.w * dt
		if w.t >= w.T:
			sparks.erase(w)
	for b in bursts.duplicate():
		b.t += dt
		if b.t >= BURST:
			bursts.erase(b)
	for c in patches.duplicate():
		c.t += dt
		if c.brk < 0 and c.t >= c.T - BREAK:
			_break(c)
		if c.brk >= 0:
			c.brk += dt
			if c.brk >= BREAK:
				patches.erase(c)
	queue_redraw()


func _ball_pos(s: Dictionary) -> Vector2:
	var u: float = clampf(s.t / s.T, 0.0, 1.0)
	var d: Vector2 = s.b - s.a
	return s.a + d * u + Vector2(0, -d.length() * ARC * 4.0 * u * (1.0 - u))


func _draw() -> void:
	for c in patches: # ground level first
		_draw_patch_ground(c)
	for c in patches:
		_draw_patch_spikes(c)
	for b in bursts:
		_draw_burst(b)
	for w in sparks:
		var q: float = w.t / w.T
		var a := 1.0 - q
		if w.shard:
			_diamond(w.p, w.s * (1.0 - 0.4 * q), w.rot, Color(0.93, 0.99, 1.0, 0.98 * a))
			draw_line(w.p + Vector2(0, -w.s * 1.6).rotated(w.rot), w.p + Vector2(0, w.s * 1.6).rotated(w.rot), Color(ICE_D, 0.8 * a), 1.0)
		else:
			draw_circle(w.p, w.s * 0.7, Color(FROST, 0.8 * a))
	for s in balls:
		_draw_ball(_ball_pos(s), s.pw, s.t, s.rot)


func _draw_ball(p: Vector2, pw: float, t: float, rot: float) -> void:
	var fl := 0.9 + 0.1 * sin(t * 55.0)
	draw_circle(p, 11.0 * pw * fl, Color(ICE, 0.22))
	draw_circle(p, 7.8 * pw, Color(PLASMA, 0.55))
	# crystalline ice shell: a turning hexagon with six little spikes
	var hexp := PackedVector2Array()
	var r := 6.6 * pw
	for i in 7:
		var ang := rot + t * 9.0 + TAU * i / 6.0
		hexp.append(p + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(hexp.slice(0, 6), Color(ICE, 0.55))
	draw_polyline(hexp, Color(0.9, 0.98, 1.0, 0.95), 1.2, true)
	for i in 6:
		var ang := rot + t * 9.0 + TAU * i / 6.0
		var d := Vector2(cos(ang), sin(ang))
		draw_line(p + d * r, p + d * (r + 3.2 * pw), Color(0.92, 0.99, 1.0, 0.9), 1.2)
	draw_circle(p, 3.6 * pw, Color(0.75, 1.0, 0.95, 0.95))
	draw_circle(p, 2.2 * pw, Color(1, 1, 1, 1))


func _draw_burst(b: Dictionary) -> void:
	var q: float = b.t / BURST
	var e := 1.0 - pow(1.0 - q, 3.0)
	var p: Vector2 = b.p
	var r: float = b.r
	var pw: float = b.pw
	var f := 1.0 - q
	if q < 0.35:
		var fq := q / 0.35
		draw_circle(p + Vector2(0, -4), r * (0.22 + 0.25 * fq) * pw, Color(1, 1, 1, 0.9 * (1.0 - fq)))
		draw_circle(p + Vector2(0, -4), r * (0.32 + 0.3 * fq) * pw, Color(PLASMA, 0.40 * (1.0 - fq)))
	_ellipse(p, r * (0.35 + 0.65 * e), Color(PLASMA, 0.85 * f), 3.0 * pw)
	_ellipse(p, r * (0.25 + 0.62 * e), Color(ICE, 0.8 * f), 1.8)
	# starburst of ice spikes shooting out along the ground, then breaking off
	var g := minf(1.0, q / 0.45)
	for sk in b.spikes:
		var dir := Vector2(cos(sk.ang), sin(sk.ang) * K)
		var tip: Vector2 = p + dir * r * sk.l * (0.3 + 0.7 * g)
		var nrm := Vector2(-dir.y, dir.x).normalized() * 2.6 * pw
		var a := 0.95 * (1.0 if q < 0.55 else (1.0 - q) / 0.45)
		draw_colored_polygon(PackedVector2Array([p + nrm, tip, p - nrm]), Color(0.80, 0.95, 1.0, a))
		draw_line(p, tip, Color(1, 1, 1, a), 1.0)


func _draw_patch_ground(c: Dictionary) -> void:
	var t: float = c.t
	var p: Vector2 = c.p
	var r: float = c.r
	var a := minf(1.0, t / 0.12)
	var melt := 0.0
	if c.brk >= 0:
		melt = c.brk / BREAK
		a *= 1.0 - melt
	var rr := r * (0.55 + 0.45 * minf(1.0, t / 0.18)) * (1.0 - 0.15 * melt)
	var pts := PackedVector2Array()
	var n: int = c.rim.size()
	for i in n:
		var ang := TAU * i / n
		pts.append(p + Vector2(cos(ang), sin(ang) * K) * rr * c.rim[i])
	draw_colored_polygon(pts, Color(ICE_D, 0.30 * a))
	var inner := PackedVector2Array()
	for v in pts:
		inner.append(p + (v - p) * 0.72 + Vector2(-rr * 0.06, -rr * 0.05))
	draw_colored_polygon(inner, Color(0.78, 0.93, 1.0, 0.28 * a))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(0.92, 0.99, 1.0, 0.75 * a), 1.6, true)
	for cr in c.cracks:
		var cp := PackedVector2Array()
		for v in cr:
			cp.append(p + v * rr)
		draw_polyline(cp, Color(1, 1, 1, 0.55 * a), 1.0, true)
	# frost glitter twinkling on the ice
	for s in c.spikes:
		var k := fmod(t * 1.3 + s.ph, 1.0)
		var tw := sin(PI * k)
		var gp: Vector2 = p + (s.o + Vector2(0.18, 0.06)) * rr
		var z := 2.2 * tw
		draw_line(gp - Vector2(z, 0), gp + Vector2(z, 0), Color(1, 1, 1, 0.85 * a * tw), 1.0)
		draw_line(gp - Vector2(0, z), gp + Vector2(0, z), Color(1, 1, 1, 0.85 * a * tw), 1.0)


func _draw_patch_spikes(c: Dictionary) -> void:
	var t: float = c.t
	var r: float = c.r
	for s in c.spikes:
		var u := clampf((t - s.delay) / (GROW * 0.6), 0.0, 1.0)
		if u <= 0.0:
			continue
		var g := _back(u)
		if c.brk >= 0:
			g *= maxf(0.0, 1.0 - c.brk / (BREAK * 0.5)) # snap away in the first half of the break
			if g <= 0.0:
				continue
		var base: Vector2 = c.p + s.o * r
		_spike(base, s.h * r * g, s.w * r * g, s.tilt, 1.0)
		if s.side: # a smaller crystal leaning out of the same root
			_spike(base + Vector2(s.w * r * 0.45, 1.0), s.h * r * g * 0.55, s.w * r * g * 0.6, s.tilt + 0.55, 0.9)


## One ice spike: a lit face and a shaded face meeting at a white ridge, standing up from the ground point.
func _spike(base: Vector2, h: float, w: float, tilt: float, a: float) -> void:
	if h < 0.5:
		return
	var up := Vector2(sin(tilt), -cos(tilt))
	var tip := base + up * h
	var l := base + Vector2(-w * 0.5, 0)
	var rgt := base + Vector2(w * 0.5, 0)
	var mid := base + Vector2(w * 0.08, w * 0.12)
	draw_colored_polygon(PackedVector2Array([l, tip, mid]), Color(0.80, 0.95, 1.0, 0.95 * a))
	draw_colored_polygon(PackedVector2Array([mid, tip, rgt]), Color(0.42, 0.70, 0.95, 0.95 * a))
	draw_line(mid, tip, Color(1, 1, 1, 0.9 * a), 1.0)
	draw_polyline(PackedVector2Array([l, tip, rgt]), Color(0.20, 0.42, 0.70, 0.6 * a), 1.0)


func _back(u: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)


func _diamond(p: Vector2, s: float, rot: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6).rotated(rot), p + Vector2(s, 0).rotated(rot), p + Vector2(0, s * 1.6).rotated(rot), p + Vector2(-s, 0).rotated(rot)]), col)


func _ellipse(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var ang := TAU * i / 40.0
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * K))
	draw_polyline(pts, col, w, true)
