class_name IonStormFX
extends Node2D
## Ion Storm's board effects, drawn in 2D like the Tesla Coil's sky bolt (Board._sky_bolt): the ion shell leaps
## straight up out of the coil's plasma barrel, falls onto its landing spot, blows up in a plasma blast, and the
## blast throws chain lightning OUTWARD to nearby enemies. One shared node on board.top can hold every tower's
## shells; it has no "f" meta, so the board's reaper leaves it alone. Pure visuals: the game owns targets and damage.
##
##   fx.launch(muzzle, landing, 0.6, func(): ...)          # shell up then down; on_land runs when it lands
##   fx.blast(landing, splash_px, power)                   # the plasma explosion, sized to the splash radius
##   fx.fork(landing, [enemy chest positions], power, func(i): ...)   # outward lightning; on_hit(i) on arrival
##   fx.tick(game_dt)                                      # step in game time (else it runs on _process)
## power (0.5..2, default 1) scales size and brightness (e.g. 1.5 for a crit or a super).

signal landed(at: Vector2)

const SKY_UP := 0.35 # share of the flight spent going up (the Tesla Coil's sky bolt uses the same)
const SKY := 300.0 # how far above the screen point the shell turns over
const K := 0.75 # Board.K: the ground's vertical squash, for blast rings
const BLAST := 0.45
const FORK := 0.32
const FORK_TRAVEL := 0.06
const GOLD := Color(1.0, 0.83, 0.43) # Ion Storm #FFD36E
const PLASMA := Color(0.18, 0.84, 0.69) # Plasma Cannon
const TESLA := Color(0.31, 0.85, 1.0) # Tesla Coil

var driven := false
var shells: Array[Dictionary] = []
var blasts: Array[Dictionary] = []
var forks: Array[Dictionary] = []
var _t := 0.0
var _jit := 0.0


func _init() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func launch(from: Vector2, to: Vector2, flight := 0.6, on_land := Callable(), power := 1.0) -> void:
	shells.append({ a = from, b = to, t = 0.0, T = maxf(0.2, flight), cb = on_land, p = power, trail = [] })
	queue_redraw()


func blast(at: Vector2, radius := 50.0, power := 1.0) -> void:
	var bits := []
	for i in 10 + int(6 * power):
		bits.append({ v = Vector2.from_angle(randf() * TAU) * randf_range(0.4, 1.0) * radius * 2.2, s = randf_range(1.5, 3.0) * power })
	var rim := []
	for i in 6:
		rim.append(randf() * TAU)
	blasts.append({ p = at, r = radius, t = 0.0, pw = power, bits = bits, rim = rim })
	queue_redraw()


## Lightning from `from` (the blast centre) out to each target, starting together (staggered 0.02 s each).
func fork(from: Vector2, targets: Array, power := 1.0, on_hit := Callable(), delay := 0.0) -> void:
	for i in targets.size():
		var cb := on_hit.bind(i) if on_hit.is_valid() else Callable()
		forks.append({ a = from, b = targets[i], t = -delay - 0.02 * i, pw = power, cb = cb, hit = false, seed = randf() * 100.0 })
	queue_redraw()


func busy() -> bool:
	return not (shells.is_empty() and blasts.is_empty() and forks.is_empty())


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
	for s in shells:
		s.t += dt
		s.trail.append(_shell_pos(s))
		if s.trail.size() > 9:
			s.trail.pop_front()
	for s in shells.filter(func(s): return s.t >= s.T):
		var cb: Callable = s.cb
		landed.emit(s.b)
		if cb.is_valid():
			cb.call()
	shells = shells.filter(func(s): return s.t < s.T)
	for b in blasts:
		b.t += dt
	blasts = blasts.filter(func(b): return b.t < BLAST)
	for f in forks:
		f.t += dt
		if not f.hit and f.t >= FORK_TRAVEL:
			f.hit = true
			var cb: Callable = f.cb
			if cb.is_valid():
				cb.call()
	forks = forks.filter(func(f): return f.t < FORK)
	if _jit >= 1.0 / 30.0:
		_jit = 0.0 # lightning re-jags at 30 fps
		for f in forks:
			f.seed = randf() * 100.0
	queue_redraw()


func _shell_pos(s: Dictionary) -> Vector2:
	var u: float = s.t / s.T
	if u < SKY_UP:
		return s.a + Vector2(0, -SKY * ease(u / SKY_UP, 0.5))
	var top: Vector2 = s.b + Vector2(0, -SKY)
	return top.lerp(s.b, ease((u - SKY_UP) / (1 - SKY_UP), 1.3))


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
	# ---- shells: a gold-rimmed plasma orb wrapped in crackling arcs, with a trail
	for s in shells:
		var p := _shell_pos(s)
		var pw: float = s.p
		var tr: Array = s.trail
		for i in range(1, tr.size()):
			var k := float(i) / tr.size()
			draw_line(tr[i - 1], tr[i], Color(PLASMA, 0.5 * k), (2.0 + 5.0 * k) * pw)
		var r := 6.0 * pw
		draw_circle(p, r * 2.6, Color(GOLD, 0.16))
		draw_circle(p, r * 1.5, Color(PLASMA, 0.55))
		draw_circle(p, r, Color(0.75, 1.0, 0.92, 0.95))
		for k in 3:
			var a0 := _t * 9.0 + k * TAU / 3
			var arc := _jag(p + Vector2.from_angle(a0) * r * 1.2, p + Vector2.from_angle(a0 + 1.6) * r * 1.9, 4, 2.5, _t * 30.0 + k)
			draw_polyline(arc, Color(TESLA.lightened(0.35), 0.9), 1.2)
	# ---- blasts: white-gold flash, plasma fireball, a shock ring on the ground, plasma blobs, rim crackle
	for b in blasts:
		var q: float = b.t / BLAST
		var r: float = b.r
		var pw: float = b.pw
		var e := 1.0 - (1.0 - q) * (1.0 - q) * (1.0 - q)
		var p: Vector2 = b.p
		if q < 0.35:
			var f := 1.0 - q / 0.35
			draw_circle(p, r * (0.22 + 0.3 * q) * pw, Color(1, 0.97, 0.85, 0.75 * f))
			draw_circle(p, r * 0.55 * pw, Color(GOLD, 0.3 * f))
		draw_circle(p, r * (0.3 + 0.45 * e), Color(PLASMA, 0.22 * (1.0 - q)))
		_ellipse(p, r * e, Color(PLASMA.lightened(0.3), 0.9 * (1.0 - q)), 2.5 * pw)
		_ellipse(p, r * e * 0.8, Color(GOLD, 0.6 * (1.0 - q)), 1.5)
		for bit in b.bits:
			var v: Vector2 = bit.v
			var bp: Vector2 = p + Vector2(v.x, v.y * K) * e * 0.5
			draw_circle(bp, bit.s * (1.0 - q), Color(PLASMA.lightened(0.4), 1.0 - q))
		if q < 0.6:
			for a0 in b.rim:
				var c := p + Vector2(cos(a0), sin(a0) * K) * r * e
				var c2 := p + Vector2(cos(a0 + 0.5), sin(a0 + 0.5) * K) * r * e
				draw_polyline(_jag(c, c2, 4, 4.0, _t * 40.0 + a0), Color(TESLA.lightened(0.4), 1.0 - q / 0.6), 1.4)
	# ---- forks: outward chain lightning (wide tesla-blue glow + white core, like the sky bolt), pop at the target
	for f in forks:
		if f.t < 0:
			continue
		var pw: float = f.pw
		var grow := minf(1.0, f.t / FORK_TRAVEL)
		var fade := 1.0 - maxf(0.0, (f.t - FORK_TRAVEL) / (FORK - FORK_TRAVEL))
		var a: Vector2 = f.a
		var bb: Vector2 = a.lerp(f.b, grow)
		var n := clampi(int(a.distance_to(f.b) / 12.0), 4, 14)
		var pts := _jag(a, bb, n, 6.0 + 2.0 * pw, f.seed)
		draw_polyline(pts, Color(TESLA.lightened(0.35), 0.55 * fade), 5.0 * pw)
		draw_polyline(pts, Color(1, 1, 1, fade), 1.6 * pw)
		# a short side branch
		if pts.size() > 4:
			var m := pts[pts.size() / 2]
			var br := _jag(m, m + (bb - a).rotated(0.7 if int(f.seed) % 2 == 0 else -0.7).normalized() * 16.0 * pw, 3, 3.0, f.seed + 3.0)
			draw_polyline(br, Color(TESLA.lightened(0.5), 0.7 * fade), 1.2)
		if f.hit:
			var hq: float = (f.t - FORK_TRAVEL) / (FORK - FORK_TRAVEL)
			draw_circle(f.b, (5.0 + 3.0 * pw) * (1.0 - hq * 0.5), Color(TESLA, 0.35 * fade))
			draw_circle(f.b, 2.5 * pw * fade, Color(1, 1, 1, fade))
			for i in 5:
				var v := Vector2.from_angle(f.seed + i * TAU / 5)
				draw_line(f.b + v * 3.0, f.b + v * (6.0 + 8.0 * hq) * pw, Color(TESLA.lightened(0.5), fade), 1.2)


func _ellipse(c: Vector2, r: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * K))
	draw_polyline(pts, col, w)
