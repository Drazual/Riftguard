class_name StarboltFX
extends Node2D
## Starbolt (arcane+plasma) board FX, drawn in 2D on the board's effects layer (board.top), in board pixels.
##   shoot(from, to, flight, on_hit, power, nova)  one fast magenta bolt with a teal core and a sparkly trail flies from
##                                                  the star to `to`. nova = the bigger "supernova" bolt (every 4th shot).
##   splash(at, radius, power)                     the small star-shaped plasma splash where a normal bolt lands
##                                                  (`at` is the ground point; radius is the game's splash radius)
##   supernova(at, radius, power, linger)          the big blast: white-teal flash, double shock ring, an 8-ray star,
##                                                  then tiny stars fall around it for ~0.7 s. linger > 0 also draws a
##                                                  faint twinkling field on the ground for that long (its damage, if
##                                                  any, is the game's)
##   busy(), tick(game_dt)                          after the first tick() it no longer runs on _process: game time drives it
## Ground shapes use the board's ground squash K (0.75).

signal hit(at: Vector2)

const K := 0.75
const TRAIL_T := 0.07 # seconds of trail kept behind a bolt (time-based, so it looks the same at any tick rate)
const SPLASH_T := 0.32
const NOVA_T := 0.55
const STAR_FALL := 0.7 # the falling stars arrive over this long
const ARCANE := Color(1.0, 0.31, 0.75) # Arcane Bolt #FF4FC0
const HOT := Color(1.0, 0.62, 0.90)
const TEAL := Color(0.18, 0.84, 0.69) # Plasma Cannon #2FD6B0
const CORE := Color(0.62, 1.0, 0.95)
const WHITE := Color(1.0, 0.98, 1.0)

var bolts: Array = [] # {a, b, t, T, cb, pw, nova, trail, wob}
var bursts: Array = [] # {p, r, t, pw, nova, rot}
var stars: Array = [] # falling stars {from, to, t, delay, T, s, rot, landed}
var sparks: Array = [] # trail glitter and splash sparkles {p, v, g, t, T, s, c}
var fields: Array = [] # lingering supernova fields {p, r, t, T}
var _driven := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 5
	_rng.seed = 4242


func shoot(from: Vector2, to: Vector2, flight := 0.2, on_hit := Callable(), power := 1.0, nova := false) -> void:
	bolts.append({ a = from, b = to, t = 0.0, T = maxf(0.03, flight), cb = on_hit, pw = power * (1.35 if nova else 1.0), nova = nova,
		trail = [[from, 0.0]], wob = _rng.randf_range(0.0, TAU), drop = 0.0 })


func splash(at: Vector2, radius := 50.0, power := 1.0) -> void:
	bursts.append({ p = at, r = radius, t = 0.0, pw = power, nova = false, rot = _rng.randf() * TAU })
	for i in 6:
		var ang := _rng.randf() * TAU
		sparks.append({ p = at + Vector2(0, -6), v = Vector2(cos(ang), sin(ang) * K) * _rng.randf_range(40, 90) + Vector2(0, -30), g = 120.0,
			t = 0.0, T = _rng.randf_range(0.22, 0.34), s = 1.6, c = CORE if i % 2 == 0 else HOT })


func supernova(at: Vector2, radius := 90.0, power := 1.0, linger := 0.0, n_stars := 12) -> void:
	bursts.append({ p = at, r = radius, t = 0.0, pw = power, nova = true, rot = _rng.randf() * TAU })
	for i in n_stars:
		var ang := TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) / n_stars
		var d := radius * sqrt(_rng.randf_range(0.15, 0.95))
		var to := at + Vector2(cos(ang) * d, sin(ang) * d * K)
		stars.append({ from = to + Vector2(_rng.randf_range(-14, 14), -_rng.randf_range(90, 130)), to = to, t = 0.0,
			delay = 0.08 + STAR_FALL * float(i) / n_stars * _rng.randf_range(0.6, 1.0), T = _rng.randf_range(0.24, 0.34),
			s = _rng.randf_range(6.0, 8.0), rot = _rng.randf() * TAU, landed = false })
	for i in 14:
		var ang := _rng.randf() * TAU
		sparks.append({ p = at + Vector2(0, -8), v = Vector2(cos(ang), sin(ang) * K) * _rng.randf_range(70, 160) + Vector2(0, -50), g = 160.0,
			t = 0.0, T = _rng.randf_range(0.3, 0.5), s = 2.0, c = CORE if i % 3 else WHITE })
	if linger > 0.0:
		fields.append({ p = at, r = radius * 0.75, t = 0.0, T = linger })


func busy() -> bool:
	return bolts.size() + bursts.size() + stars.size() + sparks.size() + fields.size() > 0


func tick(dt: float) -> void:
	_driven = true
	_step(dt)


func _process(dt: float) -> void:
	if not _driven:
		_step(dt)


func _bolt_pos(b: Dictionary) -> Vector2:
	var u: float = clampf(b.t / b.T, 0.0, 1.0)
	var d: Vector2 = b.b - b.a
	return b.a + d * u + Vector2(0, -d.length() * 0.035 * 4.0 * u * (1.0 - u)) # a very slight arc


func _step(dt: float) -> void:
	if dt <= 0:
		return
	for b in bolts.duplicate():
		b.t += dt
		var p := _bolt_pos(b)
		b.trail.append([p, b.t])
		while b.trail.size() > 2 and b.t - b.trail[1][1] > TRAIL_T:
			b.trail.remove_at(0)
		b.drop += dt
		var every: float = 0.012 if b.nova else 0.02
		while b.drop >= every: # sparkles shed along the trail
			b.drop -= every
			sparks.append({ p = p + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3)) * b.pw, v = Vector2(_rng.randf_range(-12, 12), _rng.randf_range(-8, 14)),
				g = 30.0, t = 0.0, T = _rng.randf_range(0.14, 0.26), s = _rng.randf_range(1.0, 1.8) * b.pw, c = CORE if _rng.randf() < 0.5 else HOT })
		if b.t >= b.T:
			bolts.erase(b)
			hit.emit(b.b)
			if b.cb.is_valid():
				b.cb.call()
	for s in stars.duplicate():
		s.t += dt
		s.rot += dt * 5.0
		if not s.landed and s.t >= s.delay + s.T:
			s.landed = true
			for i in 3:
				var ang := _rng.randf() * TAU
				sparks.append({ p = s.to, v = Vector2(cos(ang), sin(ang) * K) * 35.0 + Vector2(0, -20), g = 60.0, t = 0.0, T = 0.2, s = 1.2, c = CORE })
		if s.t >= s.delay + s.T + 0.25:
			stars.erase(s)
	for c in sparks.duplicate():
		c.t += dt
		c.v.y += c.g * dt
		c.p += c.v * dt
		if c.t >= c.T:
			sparks.erase(c)
	for b in bursts.duplicate():
		b.t += dt
		if b.t >= (NOVA_T if b.nova else SPLASH_T):
			bursts.erase(b)
	for f in fields.duplicate():
		f.t += dt
		if f.t >= f.T:
			fields.erase(f)
	queue_redraw()


func _draw() -> void:
	for f in fields:
		_draw_field(f)
	for b in bursts:
		_draw_burst(b)
	for s in stars:
		_draw_falling(s)
	for c in sparks:
		var a: float = 1.0 - c.t / c.T
		_star(c.p, c.s * (0.6 + 0.4 * a), 0.0, Color(c.c, 0.9 * a), 4, 0.3)
	for b in bolts:
		_draw_bolt(b)


func _draw_bolt(b: Dictionary) -> void:
	var p := _bolt_pos(b)
	var tr: Array = []
	for q in b.trail:
		tr.append(q[0])
	if b.trail.size() >= 2 and b.t - b.trail[0][1] > TRAIL_T:
		var a0: Array = b.trail[0]
		var a1: Array = b.trail[1]
		var u: float = clampf((b.t - TRAIL_T - a0[1]) / maxf(0.0001, a1[1] - a0[1]), 0.0, 1.0)
		tr[0] = (a0[0] as Vector2).lerp(a1[0], u)
	var dirv: Vector2 = (b.b - b.a).normalized()
	if tr.size() >= 2:
		var d: Vector2 = tr[-1] - tr[-2]
		if d.length() > 0.01:
			dirv = d.normalized()
	var pw: float = b.pw
	var n := tr.size()
	for i in range(1, n): # magenta ribbon with a teal thread down its middle
		var k: float = float(i) / float(n)
		draw_line(tr[i - 1], tr[i], Color(ARCANE, 0.55 * k), (1.5 + 3.0 * k) * pw)
		draw_line(tr[i - 1], tr[i], Color(CORE, 0.8 * k), (0.6 + 1.0 * k) * pw)
	var nrm := Vector2(-dirv.y, dirv.x)
	var L := 14.0 * pw
	var W := 3.8 * pw
	draw_circle(p, 7.5 * pw, Color(ARCANE, 0.3))
	draw_colored_polygon(PackedVector2Array([p + dirv * L * 0.7, p + nrm * W, p - dirv * L * 0.5, p - nrm * W]), ARCANE)
	draw_colored_polygon(PackedVector2Array([p + dirv * L * 0.5, p + nrm * W * 0.45, p - dirv * L * 0.3, p - nrm * W * 0.45]), CORE)
	_star(p, 6.0 * pw, b.t * 14.0 + b.wob, Color(WHITE, 0.95), 4, 0.25)
	if b.nova: # the supernova bolt carries a spinning four-point star and a halo
		draw_circle(p, 12.0 * pw, Color(CORE, 0.2))
		_star(p, 11.0 * pw, -b.t * 10.0, Color(CORE, 0.85), 4, 0.22)


func _draw_burst(b: Dictionary) -> void:
	var T: float = NOVA_T if b.nova else SPLASH_T
	var q: float = b.t / T
	var e: float = 1.0 - pow(1.0 - q, 3.0)
	var f: float = 1.0 - q
	var pw: float = b.pw
	var c: Vector2 = b.p - Vector2(0, 8.0 * pw) # the burst sits around the body, the rings on the ground
	if not b.nova:
		var r: float = b.r
		_ellipse_line(b.p, r * (0.35 + 0.65 * e), Color(TEAL, 0.8 * f), 2.0, K)
		_ellipse_line(b.p, r * (0.25 + 0.5 * e), Color(ARCANE, 0.55 * f), 1.2, K)
		if q < 0.35:
			draw_circle(c, 9.0 * pw * (1.0 - q / 0.35 * 0.4), Color(WHITE, 0.85 * (1.0 - q / 0.35)))
		_star(c, (10.0 + 22.0 * e) * pw, b.rot, Color(CORE, 0.95 * f), 4, 0.18) # the star-shaped splash
		_star(c, (6.0 + 12.0 * e) * pw, b.rot + PI / 4.0, Color(ARCANE, 0.8 * f), 4, 0.22)
		return
	var R: float = b.r
	if q < 0.3:
		var fq: float = q / 0.3
		draw_circle(c, R * (0.25 + 0.35 * fq), Color(WHITE, 0.85 * (1.0 - fq)))
		draw_circle(c, R * (0.4 + 0.4 * fq), Color(CORE, 0.35 * (1.0 - fq)))
	_ellipse_line(b.p, R * (0.3 + 0.75 * e), Color(CORE, 0.9 * f), 3.0 * pw, K)
	_ellipse_line(b.p, R * (0.2 + 0.6 * e), Color(ARCANE, 0.75 * f), 2.0, K)
	_ellipse_line(b.p, R * (0.1 + 0.95 * e), Color(TEAL, 0.45 * f), 1.2, K)
	_star(c, R * (0.25 + 0.55 * e), b.rot, Color(CORE, 0.95 * f), 4, 0.12)
	_star(c, R * (0.18 + 0.4 * e), b.rot + PI / 4.0, Color(HOT, 0.85 * f), 4, 0.14)


func _draw_falling(s: Dictionary) -> void:
	if s.t < s.delay:
		return
	var u: float = clampf((s.t - s.delay) / s.T, 0.0, 1.0)
	var p: Vector2 = (s.from as Vector2).lerp(s.to, u * u) # falls faster as it comes down
	if not s.landed:
		var back: Vector2 = (s.from - s.to).normalized()
		draw_line(p, p + back * 28.0, Color(ARCANE, 0.5), 4.0)
		draw_line(p, p + back * 18.0, Color(WHITE, 0.8), 1.6)
		_star(p, s.s * 1.45, s.rot, Color(ARCANE, 0.95), 4, 0.34) # magenta rim, so it reads on light ground
		_star(p, s.s, s.rot, Color(WHITE, 1.0), 4, 0.3)
		_star(p, s.s * 0.55, s.rot, Color(TEAL, 1.0), 4, 0.3)
	else:
		var a: float = 1.0 - clampf((s.t - s.delay - s.T) / 0.25, 0.0, 1.0)
		_star(s.to, s.s * (1.3 + 1.8 * (1.0 - a)), s.rot, Color(ARCANE, 0.7 * a), 4, 0.25)
		_star(s.to, s.s * (1.0 + 1.5 * (1.0 - a)), s.rot, Color(CORE, 0.9 * a), 4, 0.25)


func _draw_field(f: Dictionary) -> void:
	var q: float = f.t / f.T
	var a: float = minf(1.0, f.t / 0.15) * (1.0 - smoothstep(0.7, 1.0, q))
	_ellipse_fill(f.p, f.r, Color(CORE, 0.10 * a), K)
	_ellipse_line(f.p, f.r, Color(CORE, 0.3 * a), 1.0, K)
	for i in 6: # twinkles
		var ang: float = TAU * i / 6.0 + f.t * 0.8
		var tw: float = 0.5 + 0.5 * sin(f.t * 9.0 + i * 1.7)
		var p: Vector2 = f.p + Vector2(cos(ang), sin(ang) * K) * f.r * (0.35 + 0.15 * (i % 3))
		_star(p, 4.0 * tw, 0.0, Color(ARCANE, 0.7 * a * tw), 4, 0.3)
		_star(p, 2.6 * tw, 0.0, Color(WHITE, 0.9 * a * tw), 4, 0.3)


## A filled n-point star: points at radius r, waist at r * waist.
func _star(p: Vector2, r: float, rot: float, col: Color, n := 4, waist := 0.25) -> void:
	if r < 0.3:
		return
	var pts := PackedVector2Array()
	for i in 2 * n:
		var rr := r if i % 2 == 0 else r * waist
		var ang := rot + PI * i / n - PI / 2.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, col)


func _ellipse_line(c: Vector2, r: float, col: Color, w: float, squash: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * squash))
	draw_polyline(pts, col, w, true)


func _ellipse_fill(c: Vector2, r: float, col: Color, squash: float) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var ang := TAU * i / 32.0
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * squash))
	draw_colored_polygon(pts, col)
