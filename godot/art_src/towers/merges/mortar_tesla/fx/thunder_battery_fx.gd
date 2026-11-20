class_name ThunderBatteryFX
extends Node2D
## Thunder Battery's board effects, drawn in 2D like Ion Storm's (IonStormFX): the charged lightning ball leaves the
## mortar's mouth very fast on a low, short lob, and lands in a big crackling blast sized to the splash. One shared
## node on board.top holds every tower's balls; it has no "f" meta, so the board's reaper leaves it alone. Pure
## visuals: the game owns targets and damage (Game.thunder_ball).
##
##   fx.charge(get_points, secs, power)               # coil-tip arcs into a growing ball at the mouth while it charges
##   fx.shoot(muzzle, landing, flight, power, lob_k)   # the ball; lob_k = apex height as a share of the distance
##   fx.blast(landing, splash_px, power)               # flash, shock ring, radial bolts, rim crackle, sparks
##   fx.tick(game_dt)                                  # step in game time (else it runs on _process)
## power (0.5..2, default 1) scales size and brightness (1.3x on an orbital "big" shot).

const K := 0.75 # Board.K: the ground's vertical squash, for blast rings
const BLAST := 0.55
const FLASH := 0.07
const BOLTS := 8
const TESLA := Color(0.31, 0.85, 1.0) # Tesla Coil
const PALE := Color(0.85, 0.91, 1.0) # Thunder Battery #D8E8FF
const COPPER := Color(0.85, 0.48, 0.22) # the barrel winding

var driven := false
var charges: Array[Dictionary] = []
var balls: Array[Dictionary] = []
var blasts: Array[Dictionary] = []
var _t := 0.0
var _jit := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_rng.randomize()


## The charge-up, drawn over the model so it reads at board scale. get_points() is called every step and returns
## { at = the mouth's screen point, tips = [each coil tip's screen point] } (the model's CoilTip nodes, so the arcs
## stay on the tips as the turret turns), or null when the tower is gone, which ends it.
func charge(get_at: Callable, secs := 0.6, power := 1.0) -> void:
	charges.append({ at = get_at, t = 0.0, T = maxf(0.05, secs), pw = power, seed = _rng.randf() * 100.0, p = Vector2.ZERO, tips = [] })
	_place(charges[-1])
	queue_redraw()


func _place(c: Dictionary) -> void:
	var w = (c.at as Callable).call() if (c.at as Callable).is_valid() else null
	if w == null:
		c.t = c.T
	elif w is Dictionary:
		c.p = w.at
		c.tips = w.get("tips", [])
	else:
		c.p = w


func shoot(from: Vector2, to: Vector2, flight := 0.15, power := 1.0, lob_k := 0.12) -> void:
	balls.append({ a = from, b = to, t = 0.0, T = maxf(0.04, flight), pw = power, lob = lob_k, trail = [from], seed = _rng.randf() * 100.0 })
	queue_redraw()


func blast(at: Vector2, radius := 80.0, power := 1.0) -> void:
	var bolts := []
	for i in BOLTS:
		bolts.append({ ang = TAU * i / BOLTS + _rng.randf_range(-0.3, 0.3), l = _rng.randf_range(0.75, 1.05), seed = _rng.randf() * 100.0 })
	var bits := []
	for i in 12 + int(8 * power):
		bits.append({ v = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.5, 1.1) * radius * 1.9, s = _rng.randf_range(1.5, 3.2) * power })
	var rim := []
	for i in 9:
		rim.append(_rng.randf() * TAU)
	blasts.append({ p = at, r = radius, t = 0.0, pw = power, bolts = bolts, bits = bits, rim = rim })
	queue_redraw()


func busy() -> bool:
	return not (balls.is_empty() and blasts.is_empty() and charges.is_empty())


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
	_jit += dt
	for c in charges:
		c.t += dt
		_place(c)
	charges = charges.filter(func(c): return c.t < c.T)
	for s in balls:
		s.t += dt
		s.trail.append(_ball_pos(s))
		if s.trail.size() > 8:
			s.trail.pop_front()
	balls = balls.filter(func(s): return s.t < s.T)
	for b in blasts:
		b.t += dt
	blasts = blasts.filter(func(b): return b.t < BLAST)
	if _jit >= 1.0 / 30.0:
		_jit = 0.0 # lightning re-jags at 30 fps
		for c in charges:
			c.seed = _rng.randf() * 100.0
		for b in blasts:
			for bo in b.bolts:
				bo.seed = _rng.randf() * 100.0
	queue_redraw()


func _ball_pos(s: Dictionary) -> Vector2:
	var u: float = clampf(s.t / s.T, 0.0, 1.0)
	var d: Vector2 = s.b - s.a
	return s.a + d * u + Vector2(0, -minf(50.0, d.length() * s.lob) * 4.0 * u * (1.0 - u))


static func _jag(a: Vector2, b: Vector2, n: int, amp: float, seed: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var nrm := Vector2(-d.y, d.x).normalized()
	for i in n + 1:
		var q := float(i) / n
		var off := 0.0 if i == 0 or i == n else sin(seed * 12.9898 + i * 78.233) * amp * sin(PI * q)
		pts.append(a.lerp(b, q) + nrm * off)
	return pts


func _draw() -> void:
	# ---- charges: three coil arcs reach in to a ball of lightning that swells at the mouth
	for c in charges:
		var u: float = clampf(c.t / c.T, 0.0, 1.0)
		var pw: float = c.pw
		var p: Vector2 = c.p
		var r := (1.2 + 2.6 * u * u) * minf(pw, 1.2) # kept small so the coils and their tips stay visible
		var fl := 0.75 + 0.25 * sin(float(c.seed) * 7.0)
		draw_circle(p, r * 2.2, Color(TESLA, 0.08 + 0.14 * u * fl))
		draw_circle(p, r * 1.5, Color(TESLA, 0.25 + 0.3 * u))
		draw_circle(p, r, Color(0.92, 0.98, 1.0, 0.5 + 0.5 * u))
		var tips: Array = c.tips
		for k in tips.size():
			var tip: Vector2 = tips[k]
			# each coil's tip flares as the charge builds (staggered like the model's coil glows)
			var uk := clampf((u - 0.06 * k) / 0.8, 0.0, 1.0)
			draw_circle(tip, (1.2 + 2.3 * uk) * pw, Color(TESLA, 0.25 + 0.35 * uk))
			draw_circle(tip, (0.6 + 1.0 * uk) * pw, Color(1, 1, 1, 0.6 + 0.4 * uk * fl))
			# the arc starts exactly on the tip and runs into the ball
			if uk > 0.08:
				var n := clampi(int(tip.distance_to(p) / 5.0), 3, 8)
				var pts := _jag(tip, p, n, 2.5, float(c.seed) + k * 3.1)
				draw_polyline(pts, Color(TESLA, 0.35 * uk), 3.0)
				draw_polyline(pts, Color(PALE, 0.9 * uk * fl), 1.0)
		for k in 2:
			var a1 := float(c.seed) + k * PI
			draw_polyline(_jag(p + Vector2.from_angle(a1) * r * 1.2, p + Vector2.from_angle(a1 + 1.7) * r * 2.3, 3, 2.0, float(c.seed) + k), Color(PALE, 0.8 * u), 1.0)
	# ---- balls: a white-hot core in a cyan glow wrapped in crackling arcs, with a streaking trail
	for s in balls:
		var p := _ball_pos(s)
		var pw: float = s.pw
		var tr: Array = s.trail
		for i in range(1, tr.size()):
			var k := float(i) / tr.size()
			draw_line(tr[i - 1], tr[i], Color(TESLA, 0.35 * k), (2.0 + 5.0 * k) * pw)
			draw_line(tr[i - 1], tr[i], Color(PALE, 0.7 * k), (1.0 + 1.5 * k) * pw)
		var r := 5.0 * pw
		draw_circle(p, r * 2.6, Color(TESLA, 0.14))
		draw_circle(p, r * 1.6, Color(TESLA, 0.5))
		draw_circle(p, r, Color(0.92, 0.98, 1.0, 1.0))
		for k in 4:
			var a0: float = _t * 11.0 + k * TAU / 4 + float(s.seed)
			var arc := _jag(p + Vector2.from_angle(a0) * r * 1.1, p + Vector2.from_angle(a0 + 1.5) * r * 2.2, 4, 3.0, _t * 30.0 + k + s.seed)
			draw_polyline(arc, Color(PALE, 0.95), 1.3)
	# ---- blasts: white flash, cyan fireball, shock rings, 8 bolts out to the rim, rim crackle, sparks
	for b in blasts:
		var q: float = b.t / BLAST
		var r: float = b.r
		var pw: float = b.pw
		var p: Vector2 = b.p
		var e := 1.0 - pow(1.0 - minf(1.0, q / 0.55), 3.0) # the ring reaches the full radius at ~0.3 s
		var fade := 1.0 - q
		if b.t < FLASH:
			var f: float = 1.0 - b.t / FLASH
			draw_circle(p, r * 0.2 * pw, Color(1, 1, 1, 0.4 * f))
			_fill_ellipse(p, r * 0.55, Color(TESLA, 0.12 * f))
		_fill_ellipse(p, r * (0.35 + 0.65 * e), Color(TESLA, 0.07 * fade))
		draw_circle(p, r * 0.12 * pw, Color(PALE, 0.4 * fade * fade))
		_ellipse(p, r * e, Color(PALE, 0.85 * fade), 2.2 * pw)
		_ellipse(p, r * e * 1.03, Color(TESLA, 0.35 * fade), 5.0 * pw)
		_ellipse(p, r * e * 0.7, Color(TESLA.lightened(0.3), 0.45 * fade), 1.5)
		if q < 0.5:
			var bf := 1.0 - q / 0.5
			for bo in b.bolts:
				var ang: float = bo.ang
				var tip: Vector2 = p + Vector2(cos(ang), sin(ang) * K) * r * float(bo.l) * minf(1.0, e * 1.3)
				var pts := _jag(p, tip, clampi(int(r / 12.0), 5, 12), 5.0 + 2.0 * pw, bo.seed)
				draw_polyline(pts, Color(TESLA, 0.35 * bf), 4.0 * pw)
				draw_polyline(pts, Color(1, 1, 1, 0.9 * bf), 1.4 * pw)
				if pts.size() > 4:
					var m := pts[pts.size() / 2]
					var br := _jag(m, m + (tip - p).normalized().rotated(0.6 if int(bo.seed) % 2 == 0 else -0.6) * r * 0.3, 3, 3.0, bo.seed + 5.0)
					draw_polyline(br, Color(PALE, 0.7 * bf), 1.2)
		if q < 0.75:
			var rf := 1.0 - q / 0.75
			for a0 in b.rim:
				var c := p + Vector2(cos(a0), sin(a0) * K) * r * e
				var c2 := p + Vector2(cos(a0 + 0.45), sin(a0 + 0.45) * K) * r * e
				draw_polyline(_jag(c, c2, 4, 5.0, _t * 40.0 + a0), Color(PALE, rf), 1.5)
		for bit in b.bits:
			var v: Vector2 = bit.v
			var bp: Vector2 = p + Vector2(v.x, v.y * K) * e * 0.55 + Vector2(0, -18.0 * sin(PI * minf(1.0, q * 1.4)))
			draw_circle(bp, bit.s * fade, Color(COPPER.lightened(0.3) if int(bit.s * 10.0) % 4 == 0 else TESLA.lightened(0.4), fade))


func _ellipse(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * K))
	draw_polyline(pts, col, w)


func _fill_ellipse(c: Vector2, r: float, col: Color) -> void:
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * K))
	draw_colored_polygon(pts, col)
