class_name RimeshardFX
extends Node2D
## Rimeshard (arcane+frost) board FX, drawn in 2D on the board's effects layer (board.top), board pixels.
##   shoot(from, to, flight, on_hit, power)        one thin, fast ice shard flies from the crystal tip to `to`
##                                                  (magenta + ice-blue trail). Call it once per target in a volley.
##   volley(from, tos, speed, on_hit, power)        convenience: one shard per point in `tos`; on_hit is called with (index, at)
##   rime(id, at, stacks, radius)                   frost creeping over an enemy, 1..5 stacks (call every frame while it has
##                                                  stacks; an id that is not refreshed for FADE seconds fades out by itself)
##   freeze(id, at, dur, radius)                    the enemy is encased in ice for `dur` seconds (follows rime(id, ...) updates)
##   shatter(at, radius, power, tos, on_splinter, id) the ice bursts: white flash, ring, ice chunks, and one small magenta
##                                                  arcane splinter flies to each point in `tos`; on_splinter(index, at) on arrival
##   busy(), tick(game_dt)                          (after the first tick() it no longer runs on _process: game time drives it)
## Positions are board px. Ground shapes use the board's ground squash K (0.75).

signal hit(at: Vector2)

const K := 0.75
const FADE := 0.25 # a rime overlay that stops being refreshed fades out over this long
const SHATTER := 0.42
const SPLINTER_SPEED := 520.0
const TRAIL_T := 0.055 # seconds of trail kept behind a shard (time-based, so it looks the same at any tick rate)
const ARCANE := Color(1.0, 0.31, 0.75) # Arcane Bolt #FF4FC0
const ICE := Color(0.55, 0.88, 1.0)
const ICE_D := Color(0.28, 0.52, 0.85)
const RIME := Color(0.79, 0.72, 1.0) # recipe #C9B8FF
const WHITE := Color(0.95, 0.99, 1.0)

var shards: Array = [] # {a, b, t, T, cb, pw, trail, splinter}
var rimes: Dictionary = {} # id -> {p, n, r, age, seen, frz, frz_T, seed}
var bursts: Array = []
var chips: Array = [] # flying ice chunks / glitter
var _driven := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	z_index = 5
	_rng.seed = 7719


func shoot(from: Vector2, to: Vector2, flight := 0.15, on_hit := Callable(), power := 1.0) -> void:
	shards.append({ a = from, b = to, t = 0.0, T = maxf(0.03, flight), cb = on_hit, pw = power, trail = [[from, 0.0]], splinter = false,
		wob = _rng.randf_range(-1.0, 1.0) })


func volley(from: Vector2, tos: Array, speed := 1100.0, on_hit := Callable(), power := 1.0) -> void:
	for i in tos.size():
		var to: Vector2 = tos[i]
		var cb := Callable()
		if on_hit.is_valid():
			cb = on_hit.bind(i, to)
		shoot(from, to, from.distance_to(to) / maxf(1.0, speed), cb, power)


func rime(id: int, at: Vector2, stacks: int, radius := 9.0) -> void:
	var r: Dictionary = rimes.get(id, {})
	if r.is_empty():
		r = { p = at, n = 0, shown = 0.0, r = radius, age = 0.0, seen = 0.0, frz = 0.0, frz_T = 0.0, seed = _rng.randi() % 1000 }
		rimes[id] = r
	r.p = at
	r.r = radius
	r.seen = 0.0
	if stacks > r.n:
		_glitter(at, radius, 3) # a new stack lands: a little puff of frost
	r.n = clampi(stacks, 0, 5)


func freeze(id: int, at: Vector2, dur := 0.6, radius := 9.0) -> void:
	rime(id, at, 5, radius)
	var r: Dictionary = rimes[id]
	r.frz = maxf(0.001, dur)
	r.frz_T = r.frz
	_glitter(at, radius, 6)


func shatter(at: Vector2, radius := 9.0, power := 1.0, tos: Array = [], on_splinter := Callable(), id := -1) -> void:
	bursts.append({ p = at, r = radius, t = 0.0, pw = power, rot = _rng.randf() * TAU })
	for i in 10 + int(4 * power):
		var ang := _rng.randf() * TAU
		var sp := _rng.randf_range(70, 150) * power
		chips.append({ p = at + Vector2(0, -radius), v = Vector2(cos(ang), sin(ang) * 0.8) * sp + Vector2(0, -50), g = 360.0, t = 0.0,
			T = _rng.randf_range(0.30, 0.48), s = _rng.randf_range(1.8, 3.2) * power, rot = _rng.randf() * TAU, w = _rng.randf_range(-14, 14), chunk = true })
	for i in tos.size():
		var to: Vector2 = tos[i]
		var cb := Callable()
		if on_splinter.is_valid():
			cb = on_splinter.bind(i, to)
		var from := at + Vector2(0, -radius)
		var s := { a = from, b = to, t = 0.0, T = maxf(0.05, from.distance_to(to) / SPLINTER_SPEED), cb = cb, pw = 0.8, trail = [[from, 0.0]],
			splinter = true, wob = _rng.randf_range(-1.0, 1.0) }
		shards.append(s)
	# the rime on the shattered enemy is spent (pass its id; otherwise the overlay standing at `at` is used)
	for k in rimes:
		var r: Dictionary = rimes[k]
		if k == id or (id < 0 and r.p.distance_to(at) < 1.0):
			r.n = 0
			r.shown = 0.0
			r.frz = 0.0


func busy() -> bool:
	return shards.size() + bursts.size() + chips.size() + rimes.size() > 0


func tick(dt: float) -> void:
	_driven = true
	_step(dt)


func _process(dt: float) -> void:
	if not _driven:
		_step(dt)


func _glitter(at: Vector2, radius: float, n: int) -> void:
	for i in n:
		var ang := _rng.randf() * TAU
		chips.append({ p = at + Vector2(cos(ang), sin(ang)) * radius * 0.9 + Vector2(0, -radius), v = Vector2(cos(ang), sin(ang)) * 30.0 + Vector2(0, -25),
			g = 0.0, t = 0.0, T = 0.32, s = 1.4, rot = ang, w = 4.0, chunk = false })


func _shard_pos(s: Dictionary) -> Vector2:
	var u: float = clampf(s.t / s.T, 0.0, 1.0)
	var d: Vector2 = s.b - s.a
	var bulge := 0.10 if s.splinter else 0.02 # splinters hop in a small arc, shards fly nearly straight
	return s.a + d * u + Vector2(0, -d.length() * bulge * 4.0 * u * (1.0 - u))


func _step(dt: float) -> void:
	if dt <= 0:
		return
	for s in shards.duplicate():
		s.t += dt
		var p := _shard_pos(s)
		s.trail.append([p, s.t])
		while s.trail.size() > 2 and s.t - s.trail[1][1] > TRAIL_T:
			s.trail.remove_at(0)
		if s.t >= s.T:
			shards.erase(s)
			hit.emit(s.b)
			for i in 3:
				var ang := _rng.randf() * TAU
				chips.append({ p = s.b, v = Vector2(cos(ang), sin(ang) * 0.8) * 60.0, g = 160.0, t = 0.0, T = 0.2, s = 1.5, rot = ang, w = 8.0, chunk = true })
			if s.cb.is_valid():
				s.cb.call()
	for c in chips.duplicate():
		c.t += dt
		c.v.y += c.g * dt
		c.p += c.v * dt
		c.rot += c.w * dt
		if c.t >= c.T:
			chips.erase(c)
	for b in bursts.duplicate():
		b.t += dt
		if b.t >= SHATTER:
			bursts.erase(b)
	for id in rimes.keys():
		var r: Dictionary = rimes[id]
		r.age += dt
		r.seen += dt
		r.shown = move_toward(r.shown, float(r.n), dt * 8.0) # frost creeps up smoothly between stacks
		if r.frz > 0.0:
			r.frz = maxf(0.0, r.frz - dt)
		if r.seen > FADE or (r.n == 0 and r.shown <= 0.01 and r.frz <= 0.0):
			rimes.erase(id)
	queue_redraw()


func _draw() -> void:
	for id in rimes:
		_draw_rime(rimes[id])
	for b in bursts:
		_draw_burst(b)
	for c in chips:
		var q: float = c.t / c.T
		var a := 1.0 - q
		if c.chunk:
			_diamond(c.p, c.s * (1.0 - 0.4 * q), c.rot, Color(0.90, 0.97, 1.0, 0.95 * a))
		else:
			draw_line(c.p - Vector2(c.s * 1.5, 0), c.p + Vector2(c.s * 1.5, 0), Color(WHITE, 0.8 * a), 1.0)
			draw_line(c.p - Vector2(0, c.s * 1.5), c.p + Vector2(0, c.s * 1.5), Color(WHITE, 0.8 * a), 1.0)
	for s in shards:
		_draw_shard(s)


func _draw_shard(s: Dictionary) -> void:
	var p := _shard_pos(s)
	var tr: Array = []
	for q in s.trail:
		tr.append(q[0])
	if s.trail.size() >= 2 and s.t - s.trail[0][1] > TRAIL_T: # clip the oldest segment to exactly TRAIL_T
		var a0: Array = s.trail[0]
		var a1: Array = s.trail[1]
		var u: float = clampf((s.t - TRAIL_T - a0[1]) / maxf(0.0001, a1[1] - a0[1]), 0.0, 1.0)
		tr[0] = (a0[0] as Vector2).lerp(a1[0], u)
	var dirv: Vector2 = (s.b - s.a).normalized()
	if tr.size() >= 2:
		var d: Vector2 = tr[-1] - tr[-2]
		if d.length() > 0.01:
			dirv = d.normalized()
	var nrm := Vector2(-dirv.y, dirv.x)
	var pw: float = s.pw
	# two-tone trail: a magenta ribbon and an ice-blue ribbon twisting around each other
	var n := tr.size()
	for i in range(1, n):
		var k := float(i) / float(n)
		var tw := sin(k * 6.0 + s.t * 40.0 + s.wob) * 1.6 * pw
		var a0: Vector2 = tr[i - 1]
		var a1: Vector2 = tr[i]
		var w := (0.6 + 1.6 * k) * pw
		draw_line(a0 + nrm * tw, a1 + nrm * tw, Color(ARCANE, 0.75 * k), w)
		draw_line(a0 - nrm * tw, a1 - nrm * tw, Color(ICE, 0.85 * k), w)
	var L := (11.0 if not s.splinter else 7.0) * pw
	var W := (2.0 if not s.splinter else 2.2) * pw
	var tip := p + dirv * L * 0.6
	var tail := p - dirv * L * 0.4
	var body := Color(0.80, 0.95, 1.0) if not s.splinter else Color(1.0, 0.55, 0.88)
	draw_circle(p, 4.5 * pw, Color(ICE if not s.splinter else ARCANE, 0.25))
	draw_colored_polygon(PackedVector2Array([tip, p + nrm * W, tail, p - nrm * W]), body)
	draw_line(tail, tip, Color(1, 1, 1, 0.95), 1.0)


func _draw_rime(r: Dictionary) -> void:
	var f := clampf(r.shown / 5.0, 0.0, 1.0) # 0..1 of the body covered, creeping from the feet up
	var fade := 1.0 - clampf((r.seen - 0.05) / FADE, 0.0, 1.0)
	var p: Vector2 = r.p
	var rr: float = r.r
	var c := p - Vector2(0, rr) # body centre (enemies stand on p)
	if f > 0.0:
		# frost crust: a band of pale crystal over the lower part of the body that rises with the stacks
		var top := rr * (1.0 - 2.0 * f) # y offset (from body centre) of the frost line
		var R := rr * 1.08
		var pts := PackedVector2Array()
		if f >= 0.99:
			for i in 18:
				var ang := TAU * i / 18.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * R)
		else:
			var a0 := asin(clampf(top / R, -1.0, 1.0)) # the arc below the frost line runs a0 .. PI - a0 (y down)
			var steps := 14
			for i in steps + 1:
				var ang := lerpf(a0, PI - a0, float(i) / steps) # right -> bottom -> left
				pts.append(c + Vector2(cos(ang), sin(ang)) * R)
			var hw := R * cos(a0)
			var jag := 6
			for i in range(1, jag): # jagged frost line, left to right
				var x := -hw + 2.0 * hw * float(i) / jag
				pts.append(c + Vector2(x, top + (-2.0 if i % 2 == 0 else 1.2) * (0.6 + 0.4 * f)))
		draw_colored_polygon(pts, Color(0.82, 0.92, 1.0, (0.35 + 0.25 * f) * fade))
		# little ice crystals poking out along the crust
		var nsp := int(ceil(r.shown * 2.0))
		for i in nsp:
			var ang := PI * (0.15 + 0.7 * fposmod(float(i) * 0.618 + r.seed * 0.001, 1.0))
			var bp := c + Vector2(-cos(ang), sin(ang)) * rr
			var out := Vector2(-cos(ang), sin(ang)).rotated(-0.4 if i % 2 == 0 else 0.4)
			var h := rr * (0.45 + 0.25 * f)
			_spike(bp, bp + out * h, 1.6, fade)
		# rime pips: one tiny lilac diamond per stack, above the head
		for i in r.n:
			var x: float = (float(i) - (r.n - 1) * 0.5) * 4.2
			_diamond(p + Vector2(x, -rr * 2.0 - 5.0), 1.5, 0.0, Color(RIME if r.n < 5 else ARCANE, 0.95 * fade))
		if r.n >= 4 and r.frz <= 0.0: # one stack from shattering: the frost pulses magenta
			var pul := 0.5 + 0.5 * sin(r.age * 18.0)
			_ellipse_line(c, rr * 1.25, Color(ARCANE, 0.45 * pul * fade), 1.4, 1.0)
	if r.frz > 0.0:
		_draw_ice_block(c, rr, 1.0 - r.frz / maxf(r.frz_T, 0.001), fade)


func _draw_ice_block(c: Vector2, rr: float, q: float, fade: float) -> void:
	# a faceted ice block around the enemy (hexagonal prism seen from the board camera)
	var g := minf(1.0, q / 0.15) # snaps shut fast
	var w := rr * 1.45 * (0.7 + 0.3 * g)
	var h := rr * 1.7 * (0.7 + 0.3 * g)
	var pts := PackedVector2Array([c + Vector2(-w, -h * 0.55), c + Vector2(-w * 0.45, -h), c + Vector2(w * 0.45, -h), c + Vector2(w, -h * 0.55),
		c + Vector2(w, h * 0.55), c + Vector2(w * 0.45, h * 0.85), c + Vector2(-w * 0.45, h * 0.85), c + Vector2(-w, h * 0.55)])
	draw_colored_polygon(pts, Color(0.70, 0.88, 1.0, 0.55 * fade))
	var lit := PackedVector2Array([c + Vector2(-w, -h * 0.55), c + Vector2(-w * 0.45, -h), c + Vector2(0, -h * 0.6), c + Vector2(-w * 0.5, h * 0.2)])
	draw_colored_polygon(lit, Color(0.95, 0.99, 1.0, 0.45 * fade))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, Color(0.95, 1.0, 1.0, 0.9 * fade), 1.4, true)
	draw_line(c + Vector2(-w * 0.45, -h), c + Vector2(-w * 0.45, h * 0.85), Color(1, 1, 1, 0.35 * fade), 1.0)
	draw_line(c + Vector2(w * 0.45, -h), c + Vector2(w * 0.45, h * 0.85), Color(ICE_D, 0.5 * fade), 1.0)
	# cracks spread right before it shatters
	if q > 0.6:
		var k := (q - 0.6) / 0.4
		draw_line(c, c + Vector2(-w * 0.8, -h * 0.4) * k, Color(ARCANE, 0.8 * fade), 1.2)
		draw_line(c, c + Vector2(w * 0.7, -h * 0.7) * k, Color(ARCANE, 0.8 * fade), 1.2)
		draw_line(c, c + Vector2(w * 0.3, h * 0.8) * k, Color(ARCANE, 0.8 * fade), 1.2)


func _draw_burst(b: Dictionary) -> void:
	var q: float = b.t / SHATTER
	var e := 1.0 - pow(1.0 - q, 3.0)
	var c: Vector2 = b.p - Vector2(0, b.r)
	var r: float = b.r * 2.6 * b.pw
	var f := 1.0 - q
	if q < 0.3:
		var fq := q / 0.3
		draw_circle(c, r * (0.35 + 0.35 * fq), Color(1, 1, 1, 0.9 * (1.0 - fq)))
		draw_circle(c, r * (0.5 + 0.4 * fq), Color(ARCANE, 0.35 * (1.0 - fq)))
	_ellipse_line(b.p, r * (0.4 + 0.9 * e), Color(ICE, 0.85 * f), 2.4 * b.pw, K)
	_ellipse_line(b.p, r * (0.3 + 0.7 * e), Color(ARCANE, 0.7 * f), 1.4, K)
	# a star of ice spikes bursting outward from the body
	for i in 6:
		var ang: float = b.rot + TAU * i / 6.0
		var d := Vector2(cos(ang), sin(ang))
		_spike(c + d * r * 0.2 * e, c + d * r * (0.45 + 0.55 * e), 2.4 * b.pw, f)


func _spike(base: Vector2, tip: Vector2, w: float, a: float) -> void:
	var d := (tip - base)
	if d.length() < 0.5:
		return
	var n := Vector2(-d.y, d.x).normalized() * w
	draw_colored_polygon(PackedVector2Array([base + n, tip, base]), Color(0.86, 0.97, 1.0, 0.95 * a))
	draw_colored_polygon(PackedVector2Array([base, tip, base - n]), Color(0.45, 0.72, 0.96, 0.95 * a))
	draw_line(base, tip, Color(1, 1, 1, 0.9 * a), 1.0)


func _diamond(p: Vector2, s: float, rot: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.6).rotated(rot), p + Vector2(s, 0).rotated(rot), p + Vector2(0, s * 1.6).rotated(rot), p + Vector2(-s, 0).rotated(rot)]), col)


func _ellipse_line(c: Vector2, r: float, col: Color, w: float, squash: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var ang := TAU * i / 32.0
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * squash))
	draw_polyline(pts, col, w, true)
