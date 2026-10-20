## Draws a run: the baked ground, towers, the hero, enemies, shots and spell effects, plus the overlay
## (ranges, HP bars, rings). The rules live in Game; this only reads its state (S) and turns mouse input
## into Game calls.
##
## The board is pixel art in a 3/4 view. The game logic uses a flat 960x600 field; only the drawing is tilted.
## A 40-unit tile is 32 art pixels wide and 24 tall (K = 0.75). Things standing on the ground stay upright and
## are drawn above their foot point. Everything is drawn into a 768x416 pixel canvas that is scaled up crisply.
class_name Board
extends TextureRect

signal tower_hover(t: Tower, at: Vector2) # t is null when the pointer leaves a tower

const PX := 0.8
const C := 40.0
const COLS := 24
const ROWS := 15
const W := 960.0
const H := 600.0
const TILE := 32
const K := 0.75
const TH := 24
const TOP := 40.0
const BOT := 30.0
const VH := 520.0 # H * K + TOP + BOT
const ART_W := 768
const ART_H := 416
const FOOT := 9.0 # a tower's base sits this far below its tile's centre on screen
const BEAM_LEN := 29.0
const PAL := { ink = Color("#101223"), deep = Color("#24243D"), dusk = Color("#3B3561"), violet = Color("#625080"), mist = Color("#9B8BA5") }
## Road looks per map theme. The road is drawn pixel by pixel from its centre line, so tiles join without seams.
const PATH_STYLE := {
	sunset = { fill = "#f79b9e", speck = "#f9b3b2", rim = "#d9737f", curb = "#f9e6a2", curbLo = "#f6c177", edge = "#101223", dash = "#9cf4dd" },
	boardwalk = { fill = "#2b2a42", speck = "#3b3561", rim = "#1c1b2e", curb = "#f9e6a2", curbLo = "#e3b98a", edge = "#101223", dash = "#f6c177" },
	reactor = { fill = "#2b2a42", speck = "#3b3561", rim = "#1c1b2e", curb = "#f6c177", curbLo = "#c9905a", edge = "#101223", dash = "#f9e6a2" },
	garden = { fill = "#f9e6a2", speck = "#f0d9e8", rim = "#f6c177", curb = "#3b3561", curbLo = "#24243d", edge = "#101223", stud = "#47d9c5" },
}
## Spell effects (art/fx/spells.tres): the ground line of each effect inside its 128x116 frame.
const FX_GROUND := { fireball = 58, frostburst = 58, stonewall = 92, gust = 58, gfireball = 58, deepfreeze = 84, greatwall = 98, cyclone = 58, torrent = 62,
	meteor = 79, firestorm = 93, quagmire = 72, blizzard = 64, sandstorm = 75, inferno = 87, abszero = 72, runeA = 64, quake = 64, runeB = 60, tempest = 64 }
const FX_FW := 128.0
const FX_FH := 116.0
const FX_W := 115.0 # painted width of a full-size effect, in frame pixels
const WALL_W := 76.0 # a wall's width on the board
const HERO_FEET := 43.0
const FACE_COL := [2, 3, 4, 5, 6, 7, 0, 1] # sector (E, SE, S, ... clockwise) to facing
const MAX_BURSTS := 60

var game: Game
var viewport: SubViewport
var world: Node2D
var ground: Sprite2D
var flat: Node2D # ground-plane drawing: world coordinates squashed by K
var low: Node2D # low spell effects, under everything standing
var units: Node2D # towers, the hero, walls and effects, sorted by depth
var over: Node2D # upright overlay: bars, rings, cores
var top: Node2D # shots, beams, bursts
var spell_frames: SpriteFrames = preload("res://art/fx/spells.tres")
var ground_for = null
var frame_no := 0
var tip_tower: Tower = null
var shake_t := 0.0
var shake_amt := 0.0
var shake_dur := 0.0
var hero_spr: AnimatedSprite2D = null
var hero_state := {}
var bursts := 0
var _tex_cache := {}


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(ART_W, ART_H)
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var bg := ColorRect.new()
	bg.color = PAL.ink
	bg.size = Vector2(ART_W, ART_H)
	viewport.add_child(bg)
	world = Node2D.new()
	world.scale = Vector2(PX, PX)
	viewport.add_child(world)
	ground = Sprite2D.new()
	ground.centered = false
	ground.scale = Vector2(1 / PX, 1 / PX)
	world.add_child(ground)
	flat = _layer("Flat", _draw_flat)
	flat.position = Vector2(0, TOP)
	flat.scale = Vector2(1, K)
	low = Node2D.new()
	world.add_child(low)
	units = Node2D.new()
	units.y_sort_enabled = true
	world.add_child(units)
	over = _layer("Overlay", _draw_over)
	top = Node2D.new()
	world.add_child(top)
	texture = viewport.get_texture()
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP


func _layer(n: String, fn: Callable) -> Node2D:
	var l := Node2D.new()
	l.name = n
	l.draw.connect(fn)
	world.add_child(l)
	return l


func bind(g: Game) -> void:
	game = g
	game.shake.connect(func(i: float, ms: float):
		if Save.settings.get("shake", true):
			shake_amt = i
			shake_dur = ms / 1000.0
			shake_t = shake_dur)


static func SY(y: float) -> float:
	return TOP + y * K


func _S() -> Run:
	return game.S if game else null


# ---------- input ----------
## A point on the board control -> a point on the flat field.
func to_field(p: Vector2) -> Vector2:
	var s := minf(size.x / ART_W, size.y / ART_H)
	var off := (size - Vector2(ART_W, ART_H) * s) / 2
	var art := (p - off) / s
	var sx := art.x / PX
	var sy := art.y / PX
	return Vector2(sx, (sy - TOP) / K)


func _gui_input(ev: InputEvent) -> void:
	var S := _S()
	if S == null or S.hero == null:
		return
	if ev is InputEventMouseButton and ev.pressed:
		var p := to_field(ev.position)
		_hide_tip()
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			game.handle_right(p.x, p.y)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			game.handle_click(p.x, p.y, false)
		accept_event()
	elif ev is InputEventScreenTouch and ev.pressed:
		var p := to_field(ev.position)
		game.handle_click(p.x, p.y, true)
		accept_event()
	elif ev is InputEventMouseMotion:
		var p := to_field(ev.position)
		S.hover = game.cell_at(p.x, p.y)
		S.pointer = p
		var t: Tower = null
		if not S.paused or S.user_pause:
			t = game.pick_tower(S.hover.x, S.hover.y)
		if t:
			tip_tower = t
			tower_hover.emit(t, get_global_mouse_position())
		elif tip_tower:
			_hide_tip()


func _hide_tip() -> void:
	if tip_tower:
		tip_tower = null
		tower_hover.emit(null, Vector2.ZERO)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		var S := _S()
		if S:
			S.hover = null
			S.pointer = null
		_hide_tip()


# ---------- per frame ----------
func sync(dt: float) -> void:
	frame_no += 1
	var S := _S()
	if S and S.map and ground_for != S.map:
		bake_ground(S.map)
	if shake_t > 0:
		shake_t -= dt
		var a := shake_amt * ART_W * (shake_t / shake_dur if shake_dur > 0 else 0.0)
		viewport.canvas_transform = Transform2D(0, Vector2(randf_range(-a, a), randf_range(-a, a)))
	elif viewport.canvas_transform.origin != Vector2.ZERO:
		viewport.canvas_transform = Transform2D.IDENTITY
	var speed := 0.0
	if S and not S.paused and not S.over:
		speed = S.speed
	_sync_towers(S, speed)
	_sync_hero(S, dt, speed)
	_sync_shots(S, dt, speed)
	_sync_art(S)
	_reap(units)
	_reap(low)
	_reap(top)
	flat.queue_redraw()
	over.queue_redraw()


## Removes sprites whose game object went away this frame (a landed shot plays its hit where it landed).
func _reap(layer: Node) -> void:
	for n in layer.get_children():
		if n.has_meta("f") and int(n.get_meta("f")) != frame_no:
			var p = n.get_meta("shot") if n.has_meta("shot") else null
			if p != null and p.done and _S() and _S().hero:
				_burst(p.k, Vector2(p.x, SY(p.y) - body_lift(p.target)), "hit")
			n.queue_free()


func _seen(n: Node) -> void:
	n.set_meta("f", frame_no)


func _frames_of(type: String) -> SpriteFrames:
	var d: TowerData = DB.towers.get(type)
	return d.frames if d else null


func is_sprite_tower(t: Tower) -> bool:
	return not t.hybrid and _frames_of(t.type) != null


func muzzle_lift(t: Tower) -> float:
	var d: TowerData = DB.towers.get(t.type)
	if d == null or d.frames == null:
		return 14.0
	return (d.foot_y - d.muzzle_y) / PX - FOOT


func body_lift(e) -> float:
	return e.r * 0.9 - 4 if e is Enemy else 12.0


func _sync_towers(S: Run, speed: float) -> void:
	if S == null or S.hero == null:
		return
	for t: Tower in S.towers:
		if not is_sprite_tower(t):
			continue
		var d: TowerData = DB.towers[t.type]
		var s: AnimatedSprite2D = t.get_meta("view") if t.has_meta("view") else null
		if s == null or not is_instance_valid(s):
			s = AnimatedSprite2D.new()
			s.sprite_frames = d.frames
			s.centered = false
			s.scale = Vector2(1 / PX, 1 / PX)
			s.set_meta("shot", null)
			s.set_meta("st", t.shot_at)
			s.set_meta("ht", t.fired_at)
			s.animation_finished.connect(func():
				s.play("recover" if s.animation == "attack" else "idle"))
			s.play("idle")
			units.add_child(s)
			t.set_meta("view", s)
		_seen(s)
		# the beacon has no shots: it pulses while a wave is on
		if t.support and S.wave_active and S.time - t.fired_at > 3:
			t.shot_at = S.time
			t.fired_at = S.time
			t.hit_at = t.pos()
		s.position = Vector2(t.x, SY(t.y))
		s.offset = Vector2(-24, -d.foot_y + FOOT * PX)
		s.modulate = Color("#666677") if t.stun_t > 0 else (Color("#c9a8ff") if t.curse_t > 0 else Color.WHITE)
		s.speed_scale = speed
		if t.shot_at != s.get_meta("st"):
			s.set_meta("st", t.shot_at)
			if not (s.is_playing() and s.animation == "attack"):
				s.play("attack")
		if t.fired_at != s.get_meta("ht"):
			s.set_meta("ht", t.fired_at)
			if t.hit_at != null and t.type == "mortar":
				_burst(t.type, Vector2(t.hit_at.x, SY(t.hit_at.y)), "hit")
			elif t.type == "anvil" or t.type == "beacon":
				_burst(t.type, Vector2(t.x, SY(t.y) + FOOT - 4), "fx")
		if t.beam:
			_laser_beam(S, t, d)


func _beam_sprite(frames: SpriteFrames) -> AnimatedSprite2D:
	var b := AnimatedSprite2D.new()
	b.sprite_frames = frames
	b.centered = false
	b.offset = Vector2(-24, -25.5)
	b.play("beam")
	top.add_child(b)
	return b


## A beam sprite stretched and turned between two screen points.
func _stretch(b: AnimatedSprite2D, a: Vector2, z: Vector2, width: float) -> void:
	b.position = (a + z) / 2
	b.rotation = (z - a).angle() - PI / 2
	b.scale = Vector2(width / PX, a.distance_to(z) / BEAM_LEN)


## The laser's beam runs from its orb to its target and thickens as it heats up on one target.
func _laser_beam(S: Run, t: Tower, d: TowerData) -> void:
	var e = t.last_target
	var on: bool = e != null and not e.dead and t.stun_t <= 0 and S.time - t.fired_at < 0.35 and S.enemies.has(e)
	if not on or not d.frames.has_animation("beam"):
		return
	var b: AnimatedSprite2D = t.get_meta("beam") if t.has_meta("beam") else null
	if b == null or not is_instance_valid(b):
		b = _beam_sprite(d.frames)
		t.set_meta("beam", b)
	_seen(b)
	b.speed_scale = 1.0
	_stretch(b, Vector2(t.x, SY(t.y) - muzzle_lift(t)), Vector2(e.x, SY(e.y) - body_lift(e)), 1 + 0.6 * minf(1, t.stacks / maxf(1, t.ramp_max)))


# The hero walks while moving, fires toward its target and idles otherwise, in 8 facings. The facing only
# changes once the direction is clearly past the edge of its sector, so walking along a diagonal never flickers.
func _sync_hero(S: Run, dt: float, speed: float) -> void:
	var h: Hero = S.hero if S else null
	if h == null or h.ko > 0 or S.over or h.data.frames == null:
		if hero_spr and is_instance_valid(hero_spr):
			hero_spr.visible = false
			if h == null:
				hero_spr.queue_free()
				hero_spr = null
		return
	var s := hero_spr
	if s == null or not is_instance_valid(s) or s.sprite_frames != h.data.frames:
		if s and is_instance_valid(s):
			s.queue_free()
		s = AnimatedSprite2D.new()
		s.sprite_frames = h.data.frames
		s.centered = false
		s.scale = Vector2(1 / PX, 1 / PX)
		s.offset = Vector2(-24, -HERO_FEET + 3 * PX)
		units.add_child(s)
		hero_spr = s
		hero_state = { sector = 2, lx = h.x, ly = h.y, move_t = 0.0, fired = h.atk_at, anim = "" }
		s.animation_finished.connect(func(): hero_state.anim = "")
		s.play("idle_4")
	var st := hero_state
	s.visible = true
	var mx: float = h.x - st.lx
	var my: float = h.y - st.ly
	st.lx = h.x
	st.ly = h.y
	if Vector2(mx, my).length() > 0.01:
		st.move_t = 0.12
	else:
		st.move_t -= dt * speed
	var moving: bool = st.move_t > 0
	var firing := S.time - h.atk_at < 0.25
	# face the target while shooting, else the way it's walking (on screen, so the tilt counts)
	var v := Vector2.ZERO
	if firing:
		v = Vector2(h.aim_x - h.x, (h.aim_y - h.y) * K)
	elif moving:
		v = Vector2(mx, my * K)
	if v != Vector2.ZERO:
		var ang := v.angle()
		var cur: float = st.sector * PI / 4
		var off := absf(fposmod(ang - cur + PI, TAU) - PI)
		if off > PI / 8 + 0.14:
			st.sector = posmod(int(round(ang / (PI / 4))), 8)
	var face: int = FACE_COL[st.sector]
	if h.atk_at != st.fired:
		st.fired = h.atk_at
		st.anim = "fire"
		s.play("fire_%d" % face)
	var want: String = "fire" if st.anim == "fire" else ("walk" if moving else "idle")
	var k := "%s_%d" % [want, face]
	# turning keeps the step it was on, so the walk cycle doesn't restart
	if s.animation != k:
		var at := s.frame if String(s.animation).begins_with(want) else 0
		s.play(k)
		s.set_frame_and_progress(mini(at, s.sprite_frames.get_frame_count(k) - 1), 0.0)
	# the walk cycle keeps pace with the hero's real speed; firing keeps up with fast attackers
	var m := 1.0
	if want == "walk":
		m = clampf(h.speed / 145, 0.6, 1.6)
	elif want == "fire":
		m = maxf(1, 0.25 / maxf(0.05, h.rate))
	s.speed_scale = speed * m
	s.position = Vector2(h.x, SY(h.y) + 0.0005)


func _burst(k: String, at: Vector2, anim: String) -> void:
	var S := _S()
	if bursts >= MAX_BURSTS or S == null or S.paused or S.over:
		return
	var d: TowerData = DB.towers.get(k)
	if d == null or d.frames == null or not d.frames.has_animation(anim):
		return
	bursts += 1
	var f := AnimatedSprite2D.new()
	f.sprite_frames = d.frames
	f.centered = false
	f.offset = Vector2(-24, -48 * d.fx_anchor_y)
	f.scale = Vector2(1 / PX, 1 / PX)
	f.position = at
	f.speed_scale = S.speed
	top.add_child(f)
	f.animation_finished.connect(func():
		bursts -= 1
		f.queue_free())
	f.play(anim)


func _sync_shots(S: Run, dt: float, speed: float) -> void:
	if S == null or S.hero == null:
		return
	for b in top.get_children():
		if b is AnimatedSprite2D and not b.has_meta("f"):
			b.speed_scale = speed
	for p in S.proj:
		if p.wait > 0:
			continue
		var d: TowerData = DB.towers.get(p.k)
		if d == null or d.frames == null:
			continue
		var lift0: float = muzzle_lift(p.src) if p.src is Tower else body_lift(p.src)
		# height eases from where the shot left to the target's middle
		var lift: float = lift0 * (1 - p.u) + body_lift(p.target) * p.u
		var sp: AnimatedSprite2D = p.get("_v")
		if sp == null or not is_instance_valid(sp):
			sp = AnimatedSprite2D.new()
			sp.sprite_frames = d.frames
			sp.animation = "shot"
			sp.centered = false
			sp.offset = -d.shot_anchor
			sp.scale = Vector2(1 / PX, 1 / PX)
			sp.set_meta("shot", p)
			top.add_child(sp)
			p._v = sp
		_seen(sp)
		sp.position = Vector2(p.x, SY(p.y) - lift)
		if d.shot_turn:
			sp.rotation = atan2(SY(p.y1) - body_lift(p.target) - (SY(p.y0) - lift0), p.x1 - p.x0) - PI / 2
	# the Chain Laser's short hops between enemies
	var lf := _frames_of("laser")
	if lf:
		for b in S.beams:
			var sp: AnimatedSprite2D = b.get("_v")
			if sp == null or not is_instance_valid(sp):
				sp = _beam_sprite(lf)
				b._v = sp
			_seen(sp)
			sp.speed_scale = maxf(speed, 0.0)
			_stretch(sp, Vector2(b.x0, SY(b.y0) - 10), Vector2(b.e.x, SY(b.e.y) - body_lift(b.e)), 0.7)
	# mortar shells ride their arc, nose along the flight
	for sh in S.shells:
		if not is_sprite_tower(sh.tw) or sh.wait > 0 or sh.done:
			continue
		var d: TowerData = DB.towers[sh.tw.type]
		var sp: AnimatedSprite2D = sh.get("_v")
		if sp == null or not is_instance_valid(sp):
			sp = AnimatedSprite2D.new()
			sp.sprite_frames = d.frames
			sp.animation = "shot"
			sp.centered = false
			sp.offset = -d.shot_anchor
			sp.scale = Vector2(1 / PX, 1 / PX)
			sp.set_meta("lift", muzzle_lift(sh.tw))
			top.add_child(sp)
			sh._v = sp
		_seen(sp)
		var lift: float = sp.get_meta("lift")
		var u: float = sh.t / sh.T
		var y0 := SY(sh.y0)
		var y1 := SY(sh.y1)
		var A := minf(140, Vector2(sh.x1 - sh.x0, y1 - y0).length() * 0.4)
		var x: float = sh.x0 + (sh.x1 - sh.x0) * u
		var y := y0 + (y1 - y0) * u - A * sin(PI * u) - lift * (1 - u)
		var vx: float = sh.x1 - sh.x0
		var vy := y1 - y0 - A * PI * cos(PI * u) + lift
		sp.position = Vector2(x, y)
		sp.rotation = atan2(vy, vx) - PI / 2


# ---------- spell effects ----------
## The frame of a spell effect, from game time (so it pauses and speeds up with the game). null = not started, -1 = over.
func art_frame(S: Run, it: Dictionary):
	var el: float = S.time - it.t0
	var fr: Array = it.get("frames", [0, 1, 2, 3, 4, 5, 6, 7])
	if fr.is_empty():
		fr = [0, 1, 2, 3, 4, 5, 6, 7]
	var fps: float = it.get("fps", 13.0)
	if not fps:
		fps = 13.0
	if el < 0:
		return null
	if it.get("fly", false) or it.get("meteor", false):
		return -1 if el >= it.dur else fr[int(el * 14) % fr.size()]
	var lp = it.get("loop")
	if lp is Vector2i and lp.x >= 0:
		var a: int = lp.x
		var b: int = lp.y
		var t_in := a / fps
		var t_out := (7 - b) / fps
		var end := maxf(it.get("dur", 0.0), t_in + t_out)
		if el >= end:
			return -1
		if el < t_in:
			return int(el * fps)
		if el > end - t_out:
			return mini(7, b + 1 + int((el - (end - t_out)) * fps))
		var seq := []
		for i in range(a, b + 1):
			seq.append(i)
		for i in range(b - 1, a, -1):
			seq.append(i)
		return seq[int((el - t_in) * 8) % seq.size()]
	var i := int(el * fps)
	return -1 if i >= fr.size() else fr[i]


func _fx_sprite(parent: Node) -> AnimatedSprite2D:
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = spell_frames
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # painted effects are scaled to each spell's size, so smooth them
	parent.add_child(sp)
	return sp


## Places a spell-effect sprite: origin (ox, oy) as 0..1 of its frame.
func _fx_place(sp: AnimatedSprite2D, a: String, f: int, origin: Vector2, pos: Vector2, scl: Vector2, rot := 0.0, flip_y := false) -> void:
	sp.animation = a
	sp.frame = f
	sp.offset = -origin * Vector2(FX_FW, FX_FH)
	sp.position = pos
	sp.scale = scl
	sp.rotation = rot
	sp.flip_v = flip_y
	if flip_y:
		sp.offset.y = -(1 - origin.y) * FX_FH


func _sync_art(S: Run) -> void:
	if S == null or S.hero == null:
		return
	var keep := []
	for it: Dictionary in S.art:
		var f = art_frame(S, it)
		if typeof(f) == TYPE_INT and f == -1:
			continue
		keep.append(it)
		var a: String = it.a
		if not spell_frames.has_animation(a):
			continue
		var parent: Node = units
		if it.get("fly", false) or it.get("meteor", false) or it.get("beam", false):
			parent = top
		elif it.get("low", false):
			parent = low
		var sp: AnimatedSprite2D = it.get("_v")
		if sp == null or not is_instance_valid(sp):
			sp = _fx_sprite(parent)
			it._v = sp
		_seen(sp)
		if f == null:
			sp.visible = false
			continue
		sp.visible = true
		var tint = it.get("tint")
		sp.modulate = tint if tint is Color else Color.WHITE
		var gy: float = FX_GROUND.get(a, 58) / FX_FH
		if it.get("fly", false):
			var q := minf(1, (S.time - it.t0) / it.dur)
			var p0 := _fly_pos(it, q)
			var p1 := _fly_pos(it, minf(1, q + 0.03))
			var ang := (p1 - p0).angle()
			var k: float = 0.45 * it.size
			_fx_place(sp, a, f, Vector2(0.72, 0.5), p0, Vector2(k, k), ang, absf(ang) > PI / 2)
		elif it.get("meteor", false):
			var q := minf(1, (S.time - it.t0) / it.dur)
			var e := q * q
			var sz: float = it.size
			_fx_place(sp, a, f, Vector2(0.78, 0.72), Vector2(it.x - 130 * sz * (1 - e), SY(it.y) - 230 * sz * (1 - e)), Vector2(0.7 * sz, 0.7 * sz))
		elif it.get("beam", false):
			var p0 := Vector2(it.x1, SY(it.y1) - 12)
			var p1 := Vector2(it.x2, SY(it.y2) - 4)
			var ang := (p1 - p0).angle()
			var L := p0.distance_to(p1) + 50
			_fx_place(sp, a, f, Vector2(0.5, gy), (p0 + p1) / 2 + Vector2(cos(ang), sin(ang)) * 25, Vector2(maxf(0.6, L / (FX_W - 10)), 1), ang, absf(ang) > PI / 2)
		elif it.has("wall"):
			var w: Dictionary = it.wall
			var s0 := WALL_W / FX_W
			_fx_place(sp, a, f, Vector2(0.5, gy), Vector2(w.x, SY(w.y)), Vector2(s0 * 0.5 if w.across else s0, s0))
		else:
			var k: float = 2 * it.r / FX_W
			var ang = it.get("ang")
			_fx_place(sp, a, f, Vector2(0.5, 0.5 if ang != null else gy), Vector2(it.x, SY(it.y) + 0.01), Vector2(k, k), ang if ang != null else 0.0, ang != null and absf(ang) > PI / 2)
	S.art = keep
	# walls standing on the path: built up over half a second, then held, darkening as they crack
	for w: Dictionary in S.walls:
		var a: String = w.get("art", "stonewall")
		if not spell_frames.has_animation(a):
			continue
		var sp: AnimatedSprite2D = w.get("_v")
		if sp == null or not is_instance_valid(sp):
			sp = _fx_sprite(units)
			w._v = sp
		_seen(sp)
		var f := mini(7, int((S.time - w.born) * 16))
		var k := maxf(0, w.hp / w.max)
		var s0 := WALL_W / FX_W
		var shade := 0.7 + 0.3 * k
		var col = w.get("color")
		sp.modulate = (col as Color).lightened(0.25) if col is Color else Color(shade, shade, shade)
		_fx_place(sp, a, f, Vector2(0.5, FX_GROUND.get(a, 92) / FX_FH), Vector2(w.x, SY(w.y)), Vector2(s0 * 0.5 if w.across else s0, s0))


func _fly_pos(it: Dictionary, q: float) -> Vector2:
	return Vector2(it.x1 + (it.x2 - it.x1) * q, SY(it.y1 + (it.y2 - it.y1) * q) - 18 * (1 - q) - 16 * sin(PI * q))


# ---------- drawing helpers ----------
static func ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


static func hx(v: int, a := 1.0) -> Color:
	return Color(((v >> 16) & 255) / 255.0, ((v >> 8) & 255) / 255.0, (v & 255) / 255.0, a)


func _circle(n: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	if r > 0:
		n.draw_circle(p, r, col)


func _ring(n: CanvasItem, p: Vector2, r: float, col: Color, w: float) -> void:
	if r > 0:
		n.draw_arc(p, r, 0, TAU, clampi(int(r * 0.8), 16, 96), col, maxf(w, 1 / PX))


func _arc(n: CanvasItem, p: Vector2, r: float, a0: float, a1: float, col: Color, w: float) -> void:
	if r > 0 and a1 != a0:
		n.draw_arc(p, r, a0, a1, clampi(int(r * absf(a1 - a0) * 0.15), 8, 96), col, maxf(w, 1 / PX))


func _line(n: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	n.draw_line(a, b, col, maxf(w, 1 / PX))


func _ellipse(n: CanvasItem, p: Vector2, w: float, h: float, col: Color, fill := true, lw := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32
		pts.append(p + Vector2(cos(a) * w / 2, sin(a) * h / 2))
	if fill:
		n.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		n.draw_polyline(pts, col, maxf(lw, 1 / PX))


func _rrect_pts(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) / 2)
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + r.size - Vector2(rad, rad), r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for i in 4:
		for j in 5:
			var a := -PI / 2 + (i + j / 4.0) * PI / 2
			pts.append(cs[i] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _rrect(n: CanvasItem, r: Rect2, rad: float, col: Color, fill := true, w := 1.0) -> void:
	var pts := _rrect_pts(r, rad)
	if fill:
		n.draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		n.draw_polyline(pts, col, maxf(w, 1 / PX))


func _shadow(n: CanvasItem, x: float, y: float, w: float) -> void:
	_ellipse(n, Vector2(x, y), w, w * 0.45, hx(0x101223, 0.6))


# ---------- the ground plane (world coordinates, squashed by K) ----------
func _draw_flat() -> void:
	var g := flat
	var S := _S()
	if S == null or S.map == null:
		return
	var base := S.map.base
	_circle(g, base, 26, hx(0x4fd8e8, 0.15))
	_ring(g, base, 18, hx(0x4fd8e8), 2)
	var h := S.hero
	if h == null:
		return
	var hc: Color = h.data.color
	if S.stasis_t > 0:
		_circle(g, S.stasis_at, h.ab.r, hx(0x7fd4ff, 0.08))
		_ring(g, S.stasis_at, h.ab.r, hx(0x7fd4ff, 0.6), 2)
	if S.overclock_t > 0:
		_circle(g, S.overclock_at, h.ab.r, hx(0xb07cff, 0.06))
		_ring(g, S.overclock_at, h.ab.r, hx(0xb07cff, 0.5), 1)
	if h.aura and h.ko <= 0:
		_ring(g, h.pos(), h.aura_range, hx(0xb07cff, 0.12), 1)
	if S.build != "" and h.ko <= 0:
		_circle(g, h.pos(), h.build_range, hx(0x4fd8e8, 0.05))
		_ring(g, h.pos(), h.build_range, hx(0x4fd8e8, 0.35), 1)
		if S.hover != null:
			var hv: Vector2i = S.hover
			var ok := game.build_problem(hv.x, hv.y, S.build) == ""
			var near := ok and game.in_build_range(hv.x, hv.y)
			g.draw_rect(Rect2(hv.x * C, hv.y * C, C, C), hx(0xff5d6c if not ok else (0x5fe39a if near else 0xf2c14e), 0.25))
			if ok:
				var td: TowerData = DB.towers[S.build]
				_ring(g, Vector2(hv.x * C + C / 2, hv.y * C + C / 2), td.range * (1 + h.tower_range), ca(td.color, 0.4), 1)
	if S.pending_build != null:
		var pb: Dictionary = S.pending_build
		g.draw_rect(Rect2(pb.c * C + 4, pb.r * C + 4, C - 8, C - 8), ca(DB.towers[pb.type].color, 0.8), false, 2)
	var show_r: Tower = S.sel if S.sel != null else tip_tower
	if show_r and S.towers.has(show_r):
		_ring(g, show_r.pos(), game.t_range(show_r), ca(show_r.color, 0.5), 1)
	if S.merge_from != null:
		for t: Tower in S.towers:
			if t != S.merge_from and game.merge_problem(S.merge_from, t) == "":
				g.draw_rect(Rect2(t.x - 18, t.y - 18, 36, 36), hx(0xf2c14e, 0.8), false, 2)
	var beacon_col: Color = DB.towers.beacon.color if DB.towers.has("beacon") else Color.WHITE
	for t: Tower in S.towers:
		if t.buff:
			for b in t.buff.get("from", []):
				_line(g, b.pos(), t.pos(), ca(beacon_col, 0.18 + 0.1 * sin(S.time * 4)), 1)
	for t: Tower in S.towers:
		if t.warn_t > 0:
			_rrect(g, Rect2(t.x - 20, t.y - 20, 40, 40), 6, hx(0xff2e4d, 0.25 + 0.25 * sin(S.time * 30)))
		_shadow(g, t.x, t.y + FOOT / K, 42)
		if is_sprite_tower(t):
			_ellipse(g, Vector2(t.x, t.y + 4), 46, 34, ca(t.color, 1.0 if t == S.sel else 0.35), false, 2)
		if game.overclocked(t):
			_rrect(g, Rect2(t.x - 19, t.y - 19, 38, 38), 6, hx(0xb07cff, 0.9), false, 1)
		if t.is_super:
			var pulse := 0.5 + 0.5 * sin(S.time * 5)
			_circle(g, t.pos(), 30 + 4 * pulse, ca(t.color, 0.1 + 0.08 * pulse))
	for c in S.coins:
		_shadow(g, c.x, c.y, 12)
	for e: Enemy in S.enemies:
		if e.shield_aura:
			_ring(g, e.pos(), 70, hx(0xd8b84a, 0.25), 1)
		if e.heal:
			_ring(g, e.pos(), e.r + 6 + 4 * sin(S.time * 5), hx(0x7dffb0, 0.15 + 0.15 * sin(S.time * 5)), 2)
		if e.unslow:
			_line(g, game.pos_at(maxf(0, e.d - 18)), e.pos(), hx(0x4fa8ff, 0.35), e.r)
		_shadow(g, e.x, e.y + 4 / K, e.r * 2.2)
	if h.tx != null and h.ko <= 0:
		_ring(g, Vector2(h.tx, h.ty), 6, ca(hc, 0.5), 1)
	# Orbital Strike lands on the cursor: show where once it's readied
	if S.strike_ready and h.ko <= 0 and S.pointer != null:
		_ring(g, S.pointer, h.ab.r, hx(0xff5d6c, 0.75), 2)
		_circle(g, S.pointer, h.ab.r, hx(0xff5d6c, 0.08))
	# Piercing Shot in cursor mode: a faint line toward the cursor while it's charged
	if h.ab.id == "pierce" and game.pierce_cursor() and h.ko <= 0 and not (h.ab.t > 0) and S.pointer != null:
		var dv0: Vector2 = (S.pointer - h.pos()).normalized()
		_line(g, h.pos(), h.pos() + dv0 * 1400, hx(0xffd36e, 0.3), 1)
	if S.aim != null:
		var a: Vector2 = S.aim
		var ready := not (h.ab.t > 0)
		if h.ko <= 0:
			var dv := (a - h.pos()).normalized()
			_line(g, h.pos(), h.pos() + dv * 1400, hx(0xffd36e, 0.35 if ready else 0.15), 1)
		var gold := hx(0xffd36e, 0.95)
		_ring(g, a, 10, gold, 2)
		_line(g, a + Vector2(-15, 0), a + Vector2(-5, 0), gold, 2)
		_line(g, a + Vector2(5, 0), a + Vector2(15, 0), gold, 2)
		_line(g, a + Vector2(0, -15), a + Vector2(0, -5), gold, 2)
		_line(g, a + Vector2(0, 5), a + Vector2(0, 15), gold, 2)
	if h.ko <= 0:
		var HX := S.heroics
		if HX.get("wither", 0):
			_circle(g, h.pos(), 90 + 20 * HX.wither, hx(0x7a2e5a, 0.12))
		if h.range < 9999:
			_ring(g, h.pos(), h.range, ca(hc, 0.15), 1)
		if h.hold:
			g.draw_rect(Rect2(h.x - 17, h.y - 17, 34, 34), hx(0xf2c14e, 0.9), false, 2)
		_shadow(g, h.x, h.y, 30)
		# a ring on the ground under the hero fills as the ability recharges
		_ring(g, h.pos(), 17, ca(hc, 0.35), 2)
		if h.ab.t > 0:
			_arc(g, h.pos(), 17, -PI / 2, -PI / 2 + TAU * (1 - h.ab.t / h.ab.cd), hx(0xb07cff, 0.7), 2)
		else:
			_ring(g, h.pos(), 17, hx(0xb07cff, 0.9), 2)
	for z: Dictionary in S.zones:
		if z.get("quiet", false):
			continue
		var a := minf(1, z.t / z.T * 1.5)
		var pulse := 0.5 + 0.5 * sin(S.time * 10)
		var zc: Color = z.color
		if z.get("line", false):
			_line(g, Vector2(z.x1, z.y1), Vector2(z.x2, z.y2), ca(zc, 0.22 * a), z.r * 2)
			_line(g, Vector2(z.x1, z.y1), Vector2(z.x2, z.y2), ca(zc, 0.7 * a), 2)
		elif z.get("vortex", false):
			for i in 3:
				_ring(g, Vector2(z.x, z.y), z.r * (1 - fmod(S.time * 1.5 + i / 3.0, 1.0)), ca(zc, 0.8 * a), 2)
			_circle(g, Vector2(z.x, z.y), z.r * 0.3, Color(0, 0, 0, 0.4 * a))
		else:
			_circle(g, Vector2(z.x, z.y), z.r, ca(zc, (0.12 + 0.1 * pulse) * a))
			_ring(g, Vector2(z.x, z.y), z.r, ca(zc, 0.6 * a), 2)
	for e: Enemy in S.enemies:
		if e.taunt_t > 0 and h.ko <= 0:
			_line(g, e.pos(), h.pos(), hx(0xff5d6c, 0.5), 1)
	for e: Enemy in S.enemies:
		if Game.BIG_BOSS.has(e.type) and e.d / S.map.path_len >= 0.75:
			_ring(g, base, 44, hx(0xff2e4d, 0.5 + 0.5 * sin(S.time * 12)), 4)
			break
	for sh: Dictionary in S.shells:
		var u: float = 0.0 if sh.wait > 0 else sh.t / sh.T
		var gp := Vector2(sh.x0 + (sh.x1 - sh.x0) * u, sh.y0 + (sh.y1 - sh.y0) * u)
		_ring(g, Vector2(sh.x1, sh.y1), sh.tw.splash * (1.1 - 0.3 * u), hx(0xff5d6c, 0.25 + 0.4 * u), 1)
		_circle(g, gp, 4, Color(0, 0, 0, 0.35))
	# a wall spell readied: the path tile it will lock onto
	if h.cls == "wizard" and S.pointer != null and h.ko <= 0:
		var rr = game.resolve_runes(S.runes)
		if rr != null and rr.spell.delivery == "wall":
			var sp = game.wall_spot(S.pointer.x, S.pointer.y)
			if sp != null:
				g.draw_rect(Rect2(sp.x - C / 2, sp.y - C / 2, C, C), Color(1, 1, 1, 0.22))
				g.draw_rect(Rect2(sp.x - C / 2 + 1, sp.y - C / 2 + 1, C - 2, C - 2), Color(1, 1, 1, 0.65 + 0.35 * sin(S.time * 8)), false, 2)
	for f: Dictionary in S.fx:
		var a: float = f.t / f.T
		if f.get("quiet", false) and (f.k == "orb" or f.k == "line" or f.k == "ring"):
			continue
		if f.k == "pillar":
			_circle(g, Vector2(f.x, f.y), f.w * 2.5, ca(f.color, 0.4 * a))
		elif f.k == "ring":
			var r: float = f.r * (0.15 + 0.85 * a) if f.get("shrink", false) else f.r * (1.2 - a * 0.4)
			if f.get("fill", false):
				_circle(g, Vector2(f.x, f.y), r, ca(f.color, a * 0.2))
			_ring(g, Vector2(f.x, f.y), r, ca(f.color, a), 2)


# ---------- upright overlay (screen coordinates) ----------
func P(x: float, y: float, lift := 0.0) -> Vector2:
	return Vector2(x, SY(y) - lift)


func _draw_over() -> void:
	var o := over
	var S := _S()
	if S == null or S.map == null:
		return
	# the base: a crystal standing on its pad
	var bp := P(S.map.base.x, S.map.base.y)
	o.draw_rect(Rect2(bp.x - 5, bp.y - 22, 10, 22), hx(0x101223))
	o.draw_colored_polygon(PackedVector2Array([bp + Vector2(0, -30), bp + Vector2(-6, -14), bp + Vector2(6, -14)]), hx(0x4fd8e8))
	o.draw_colored_polygon(PackedVector2Array([bp + Vector2(-6, -14), bp + Vector2(6, -14), bp + Vector2(0, -4)]), hx(0x4fd8e8))
	o.draw_colored_polygon(PackedVector2Array([bp + Vector2(-1, -27), bp + Vector2(-4, -15), bp + Vector2(0, -15)]), Color(1, 1, 1, 0.6))
	var h := S.hero
	if h == null:
		return
	var hc: Color = h.data.color
	for t: Tower in S.towers:
		var art := is_sprite_tower(t)
		var tp := P(t.x, t.y)
		if not art:
			# plinth: top face plus a darker front face
			_rrect(o, Rect2(tp.x - 16, tp.y - 8, 32, 18), 5, hx(0x0a0d18))
			_rrect(o, Rect2(tp.x - 16, tp.y - 14, 32, 18), 5, hx(0x141a2e))
			_rrect(o, Rect2(tp.x - 16, tp.y - 14, 32, 24), 5, ca(t.color, 1.0 if t == S.sel else 0.6), false, 2)
		if t == S.drained:
			_line(o, tp + Vector2(-14, -24), tp + Vector2(14, 4), hx(0xff5d6c, 0.9), 2)
		var cy := tp.y - 12
		var cp := Vector2(tp.x, cy)
		if t.is_super:
			# a pulsing core with its base towers' colours in orbit, and a ring that fills as its next power charges
			var pulse := 0.5 + 0.5 * sin(S.time * 5)
			var k := 1 - maxf(0, t.sp_t) / maxf(0.01, game.R.super_cooldown)
			_circle(o, cp, 13 + 3 * pulse, ca(t.color, 0.3))
			_circle(o, cp, 8, t.color)
			_circle(o, cp, 3 + pulse, Color(1, 1, 1, 0.9))
			_arc(o, cp, 15, -PI / 2, -PI / 2 + TAU * k, hx(0xf2c14e, 0.9), 2)
			for i in t.parents.size():
				var an := S.time * 2.2 + i * TAU / t.parents.size()
				var pc: Color = DB.towers[t.parents[i]].color
				_circle(o, cp + Vector2(cos(an) * 20, sin(an) * 9), 2.5, pc)
			if t.ascend_t > 0:
				_ring(o, cp, 22 + 2 * pulse, hx(0xffd36e, 0.8), 1.5)
		elif t.hybrid:
			_circle(o, cp, 7, t.color)
			_ring(o, cp, 11, ca(t.color, 0.7), 2)
		if t.stun_t > 0:
			if not art:
				_rrect(o, Rect2(tp.x - 16, tp.y - 14, 32, 24), 5, Color(0, 0, 0, 0.45))
			var a0 := S.time * 6
			_arc(o, tp + Vector2(0, -14), 20, a0, a0 + 1.4, Color(1, 1, 1, 0.8), 2)
			_arc(o, tp + Vector2(0, -14), 24, -PI / 2, -PI / 2 + TAU * (t.stun_t / maxf(0.01, t.stun_max if t.stun_max else 1.0)), hx(0xff2e4d, 0.9), 3)
		if t.curse_t > 0:
			_ring(o, tp + Vector2(0, -6), 19 + sin(S.time * 5), hx(0xb07cff, 0.7), 1.5)
		# level pips: small dots under the base, gold then pink past level 5
		for i in t.lvl:
			_circle(o, Vector2(tp.x - 10 + (i % 5) * 5, tp.y + FOOT + 4 + (0 if i >= 5 else 3)), 1.6, hx(0xff6fd8 if i >= 5 else 0xf2c14e))
	for c in S.coins:
		var p := P(c.x, c.y, 6)
		_circle(o, p, 6, hx(0xf2c14e))
		_ring(o, p, 8 + 2 * sin(S.time * 6), Color(1, 1, 1, 0.8), 1)
	var has_anvil := S.towers.any(func(t): return t.type == "anvil")
	var anvil_col: Color = DB.towers.anvil.color if DB.towers.has("anvil") else Color.WHITE
	var frost_col: Color = DB.towers.frost.color if DB.towers.has("frost") else Color.WHITE
	for e: Enemy in S.enemies:
		var p := P(e.x, e.y, body_lift(e))
		if e.still_t > 0.5 and has_anvil:
			var n := mini(6, 2 + int(e.still_t))
			for i in n:
				var a := i * 2.4
				_line(o, p, p + Vector2(cos(a), sin(a)) * (e.r + 4 + e.still_t * 3), ca(anvil_col, 0.7), 1.5)
		var al := 0.45 if e.phase else 1.0
		_circle(o, p, e.r + 1.25, hx(0x101223, al))
		_circle(o, p, e.r, ca(e.color, al))
		_circle(o, p - Vector2(e.r, e.r) * 0.35, e.r * 0.35, Color(1, 1, 1, 0.15 if e.phase else 0.35))
		var arm := game.armor_of(e, null)
		if arm > 0:
			_ring(o, p, e.r, hx(0xb8c0d8, 0.85), 1 + arm * 8)
		if e.hex_t > 0:
			var a0 := S.time * 4
			_arc(o, p, e.r + 5, a0, a0 + 4, hx(0xb07cff, 0.9), 2)
		if e.stun_t > 0:
			_ring(o, p, e.r + 2, Color(1, 1, 1, 0.9), 2)
		elif e.slow:
			_ring(o, p, e.r + 2, ca(frost_col, 0.9), 2)
		if e.burn_t > 0:
			_circle(o, p - Vector2(0, e.r), 2.5, hx(0xff8a3d, 0.8))
		if e.fire_t > 0:
			# Fire spell burn: a flickering orange halo
			_ring(o, p, e.r + 1, hx(0xff5d1f, 0.55 + 0.35 * sin(S.time * 18 + e.d)), 2)
		if e.boss:
			_ring(o, p, e.r + 4, hx(0xf2c14e), 2)
		elif e.pushback_immune:
			# anchored: a thick dark iron band says it can't be pushed back
			_ring(o, p, e.r + 3, hx(0x3a4256, 0.95), 3)
		if e.mark_t > 0 or e.spot_t > 0:
			_ring(o, p, e.r + 7, hx(0xff2e4d, 0.9), 1.5)
		var w := e.r * 2 + 4
		o.draw_rect(Rect2(p.x - w / 2, p.y - e.r - 7, w, 3), Color(0, 0, 0, 0.6))
		o.draw_rect(Rect2(p.x - w / 2, p.y - e.r - 7, w * maxf(0, e.hp / e.max), 3), hx(0x5fe39a))
	var hp := P(h.x, h.y, 20)
	var htop := SY(h.y) - 47 # just above the head
	if h.ko > 0:
		_circle(o, hp, 13, hx(0x8d95b8, 0.3))
		_arc(o, hp, 17, -PI / 2, -PI / 2 + TAU * (1 - h.ko / h.respawn), ca(hc, 0.8), 3)
	else:
		var HX := S.heroics
		if h.brace:
			var ready := h.brace_t >= h.brace
			_arc(o, hp, 26, -PI / 2, -PI / 2 + TAU * minf(1, h.brace_t / h.brace), hx(0xffd36e, 0.95) if ready else hx(0x8d95b8, 0.6), 3 if ready else 2)
		if h.shield > 0:
			_circle(o, hp, 28, hx(0x9af0ff, 0.15))
			_arc(o, hp, 28, -PI / 2, -PI / 2 + TAU * h.shield / maxf(1, h.shield_max), hx(0x9af0ff, 0.9), 3)
		if h.od_t > 0:
			_ring(o, hp, 24, hx(0xff6f6f, 0.5 + 0.4 * sin(S.time * 20)), 2)
		if h.stun_t > 0:
			var a0 := S.time * 6
			for i in 3:
				var ang := a0 + i * TAU / 3
				_circle(o, Vector2(hp.x + cos(ang) * 14, htop - 6 + sin(ang) * 4), 2.5, hx(0xffd36e, 0.95))
		if h.weak_t > 0 or h.shred_t > 0 or h.drag_t > 0:
			_ring(o, hp, 21, hx(0xb07cff, 0.6 + 0.3 * sin(S.time * 6)), 1.5)
		o.draw_rect(Rect2(hp.x - 16, htop, 32, 4), Color(0, 0, 0, 0.6))
		o.draw_rect(Rect2(hp.x - 16, htop, 32 * h.hp / h.max_hp, 4), hx(0x5fe39a))
		if h.shield > 0:
			o.draw_rect(Rect2(hp.x - 16, htop, 32 * minf(1, h.shield / h.max_hp), 4), Color(0.37, 0.66, 1.0, 0.6))
		if h.max_mana:
			o.draw_rect(Rect2(hp.x - 16, htop + 5, 32, 3), Color(0, 0, 0, 0.6))
			o.draw_rect(Rect2(hp.x - 16, htop + 5, 32 * h.mana / h.max_mana, 3), hx(0x5fa8ff))
		if HX.get("blades", 0):
			var n: int = HX.blades + 1
			for i in n:
				var ang := S.time * 3 + i * TAU / n
				_circle(o, P(h.x + cos(ang) * 42, h.y + sin(ang) * 42, 10), 5, hx(0xe6e9f5))
		for i in int(HX.get("drone", 0)):
			o.draw_rect(Rect2(hp.x + (-28 if i else 20), htop + 4, 8, 8), hx(0x5fe39a))
	for sh: Dictionary in S.shells:
		if not is_sprite_tower(sh.tw):
			var u: float = 0.0 if sh.wait > 0 else sh.t / sh.T
			var gp := Vector2(sh.x0 + (sh.x1 - sh.x0) * u, sh.y0 + (sh.y1 - sh.y0) * u)
			var arc := minf(140, Vector2(sh.x1 - sh.x0, sh.y1 - sh.y0).length() * 0.4) * sin(PI * u)
			_circle(o, Vector2(gp.x, SY(gp.y) - arc), 5 + 2 * sh.mult, sh.tw.color)
	# wall HP shows above each wall
	for w: Dictionary in S.walls:
		var k := maxf(0, w.hp / w.max)
		var wt := SY(w.y) - 56
		o.draw_rect(Rect2(w.x - 15, wt, 30, 3), Color(0, 0, 0, 0.6))
		o.draw_rect(Rect2(w.x - 15, wt, 30 * k, 3), hx(0xc8a26a))
	# effect lines are shots and beams at chest height
	for f: Dictionary in S.fx:
		var a: float = f.t / f.T
		if f.get("quiet", false) and (f.k == "orb" or f.k == "line" or f.k == "ring"):
			continue
		var fc: Color = f.get("color", Color.WHITE)
		if f.k == "orb":
			var q := 1 - a
			var p := Vector2(f.x1 + (f.x2 - f.x1) * q, SY(f.y1 + (f.y2 - f.y1) * q) - 18 * (1 - q) - 40 * sin(PI * q) * 0.4)
			_circle(o, p, f.r * 1.8, ca(fc, 0.35))
			_circle(o, p, f.r, fc)
			_circle(o, p, f.r * 0.4, Color(1, 1, 1, 0.9))
		elif f.k == "line":
			var l1: float = f.l1 if f.get("l1") != null else 12.0
			_line(o, Vector2(f.x1, SY(f.y1) - l1), Vector2(f.x2, SY(f.y2) - 12), ca(fc, a), f.w)
		elif f.k == "pillar":
			# a beam straight down from the sky
			var y := SY(f.y)
			var w: float = f.w * (0.6 + 0.4 * a)
			o.draw_rect(Rect2(f.x - w * 1.6, y - 520, w * 3.2, 520), ca(fc, 0.35 * a))
			o.draw_rect(Rect2(f.x - w / 2, y - 520, w, 520), ca(fc, 0.8 * a))
			o.draw_rect(Rect2(f.x - w / 5, y - 520, w / 2.5, 520), Color(1, 1, 1, a))
		elif f.k == "bolt":
			# jagged lightning from above
			var seed: float = f.get("seed", 0.0)
			var p := Vector2(f.x + sin(seed) * 40, SY(f.y) - 320)
			for i in range(1, 8):
				var q := i / 7.0
				var nx: float = f.x if i == 7 else f.x + sin(seed + i * 7.3) * 26 * (1 - q)
				var np := Vector2(nx, p.y + (SY(f.y) - 8 - (SY(f.y) - 320)) / 7)
				_line(o, p, np, ca(fc, a * 0.6), 4)
				_line(o, p, np, Color(1, 1, 1, a), 1.5)
				p = np


# ---------- the ground, baked once per map ----------
func _tile_image(tex: Texture2D) -> Image:
	if _tex_cache.has(tex):
		return _tex_cache[tex]
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	_tex_cache[tex] = img
	return img


func bake_ground(m: MapInfo) -> void:
	ground_for = m
	ground.texture = ImageTexture.create_from_image(make_ground(m))


## Draws the board into an image at art resolution: the back wall, the painted tiles, the road, props and
## the platform's front face.
func make_ground(m: MapInfo) -> Image:
	var top := int(TOP * PX)
	if m.scene.backdrop:
		var bd := _tile_image(m.scene.backdrop).duplicate()
		if bd.get_size() != Vector2i(ART_W, ART_H):
			bd.resize(ART_W, ART_H, Image.INTERPOLATE_NEAREST)
		return bd
	var img := Image.create(ART_W, ART_H, false, Image.FORMAT_RGBA8)
	var px := func(x: int, y: int, w: int, h: int, col: Color) -> void:
		img.fill_rect(Rect2i(x, y, w, h), col)
	# back wall: the far edge of the plating rises into a panelled wall
	px.call(0, 0, COLS * TILE, top, PAL.ink)
	for c in COLS:
		var x := c * TILE
		px.call(x + 1, 6, TILE - 2, top - 8, PAL.deep)
		px.call(x + 1, 6, TILE - 2, 1, PAL.dusk)
		px.call(x + 1, 6, 1, top - 8, PAL.dusk)
		px.call(x + 6, 12, TILE - 12, 3, PAL.ink)
		if Hash32.edge(c, 0, 7) < 0.35:
			px.call(x + 8, 13, 4, 1, PAL.violet)
		px.call(x, top - 2, TILE, 2, PAL.ink)
	# painted ground tiles; road tiles get a plain ground tile under the drawn road
	var ts: TileSet = m.ground.tile_set if m.ground else null
	var grounds := [] # [atlas coords, weight]
	var tot := 0.0
	var src: TileSetAtlasSource = null
	if ts and ts.get_source_count():
		src = ts.get_source(ts.get_source_id(0)) as TileSetAtlasSource
		for i in src.get_tiles_count():
			var at := src.get_tile_id(i)
			var td := src.get_tile_data(at, 0)
			if td.get_custom_data("kind") == "ground":
				var wgt = td.get_custom_data("weight") if ts.get_custom_data_layer_by_name("weight") >= 0 else 1.0
				wgt = float(wgt) if wgt else 1.0
				grounds.append([at, wgt])
				tot += wgt
	var tiles_img: Image = _tile_image(src.texture) if src else null
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			var at := Vector2i(-1, -1)
			if m.ground and m.ground.get_cell_source_id(cell) >= 0:
				at = m.ground.get_cell_atlas_coords(cell)
			if m.path_cells.has(cell) or (at.x >= 0 and m.kind_at(cell) == "path"):
				at = Vector2i(-1, -1)
				if grounds.size():
					var x := Hash32.cell(c, r, 1) * tot
					var g := 0
					while g < grounds.size() - 1 and x > grounds[g][1]:
						x -= grounds[g][1]
						g += 1
					at = grounds[g][0]
			if at.x >= 0 and tiles_img:
				var reg := src.get_tile_texture_region(at)
				img.blit_rect(tiles_img, reg, Vector2i(c * TILE, top + r * TH))
			else:
				px.call(c * TILE, top + r * TH, TILE, TH, PAL.deep)
	# foam where water meets land
	var foam := Color("#9cf4dd")
	for k: Vector2i in m.water_cells:
		var c := k.x
		var r := k.y
		var y := top + r * TH
		var x := c * TILE
		var land := func(dc: int, dr: int) -> bool:
			var n := Vector2i(c + dc, r + dr)
			return n.x >= 0 and n.x < COLS and n.y >= 0 and n.y < ROWS and not m.water_cells.has(n)
		for i in range(0, TILE, 2):
			var w := 1 + (1 if (i * 7 + c * 3) % 5 == 0 else 0)
			if land.call(0, -1):
				px.call(x + i, y + (0 if Hash32.cell(c * TILE + i, r, 4) < 0.5 else 1), 2, w, foam)
			if land.call(0, 1):
				px.call(x + i, y + TH - 1 - (0 if Hash32.cell(c * TILE + i, r, 5) < 0.5 else 1), 2, 1, foam)
		for i in range(0, TH, 2):
			if land.call(-1, 0):
				px.call(x, y + i, 1 + (1 if Hash32.cell(c, r * TH + i, 6) < 0.5 else 0), 2, foam)
			if land.call(1, 0):
				px.call(x + TILE - 1 - (1 if Hash32.cell(c, r * TH + i, 7) < 0.5 else 0), y + i, 2, 2, foam)
	var links := path_links(m)
	_draw_path(img, top, PATH_STYLE.get(m.scene.theme, PATH_STYLE.reactor), links)
	# the spawn gate sits on the first road tile at the board's edge
	var entry_path := "res://assets/maps/%s_entry.png" % m.scene.theme
	if ResourceLoader.exists(entry_path):
		var ent := _tile_image(load(entry_path))
		for k: Vector2i in links:
			if links[k].first:
				img.blend_rect(ent, Rect2i(0, 0, mini(TILE, ent.get_width()), mini(TH, ent.get_height())), Vector2i(k.x * TILE, top + k.y * TH))
	# props, front to back, each with a soft shadow
	if m.props_layer and m.props_layer.tile_set:
		var pts := m.props_layer.tile_set
		var cells: Array = m.prop_cells.keys()
		cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
		for cell: Vector2i in cells:
			var sid := m.props_layer.get_cell_source_id(cell)
			if sid < 0:
				continue
			var ps := pts.get_source(sid) as TileSetAtlasSource
			if ps == null:
				continue
			var pimg := _tile_image(ps.texture)
			var reg := ps.get_tile_texture_region(m.props_layer.get_cell_atlas_coords(cell))
			var used := pimg.get_region(reg).get_used_rect()
			if used.size.x <= 0:
				continue
			var w := used.size.x
			var hh := used.size.y
			_blend_ellipse(img, Vector2(cell.x * TILE + TILE / 2.0, top + (cell.y + 1) * TH - 4), minf(14, w / 2.0), 4, Color(16 / 255.0, 18 / 255.0, 35 / 255.0, 0.45))
			img.blend_rect(pimg, Rect2i(reg.position + used.position, used.size), Vector2i(roundi(cell.x * TILE + (TILE - w) / 2.0), roundi(top + (cell.y + 1) * TH - hh - 2)))
	# front face of the platform, lit along its top edge
	var fy := top + ROWS * TH
	var bot := int(BOT * PX)
	px.call(0, fy, COLS * TILE, bot, PAL.dusk)
	px.call(0, fy, COLS * TILE, 1, PAL.mist)
	px.call(0, fy + 1, COLS * TILE, 1, PAL.violet)
	for c in COLS:
		var x := c * TILE
		px.call(x, fy + 2, 1, bot - 2, PAL.deep)
		px.call(x + 4, fy + 8, TILE - 8, 3, PAL.deep)
		if Hash32.edge(c, 99, 3) < 0.3:
			px.call(x + 6, fy + 9, 3, 1, PAL.mist)
	px.call(0, fy + bot - 3, COLS * TILE, 3, PAL.ink)
	return img


func _blend_ellipse(img: Image, c: Vector2, rx: float, ry: float, col: Color) -> void:
	for y in range(floori(c.y - ry), ceili(c.y + ry) + 1):
		for x in range(floori(c.x - rx), ceili(c.x + rx) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := (x + 0.5 - c.x) / rx
			var dy := (y + 0.5 - c.y) / ry
			if dx * dx + dy * dy <= 1:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(col))


## Which neighbours each road tile joins (the road enters from off the map and runs on past the base).
func path_links(m: MapInfo) -> Dictionary:
	var out := {}
	if m.path_seq.size() < 2:
		return out
	var seq: Array[Vector2i] = [m.path_seq[0] - (m.path_seq[1] - m.path_seq[0])]
	seq.append_array(m.path_seq)
	var names := { Vector2i(0, -1): "N", Vector2i(1, 0): "E", Vector2i(0, 1): "S", Vector2i(-1, 0): "W" }
	var off := func(v: Vector2i) -> bool: return v.x < 0 or v.y < 0 or v.x >= COLS or v.y >= ROWS
	for i in seq.size():
		var cell: Vector2i = seq[i]
		if off.call(cell):
			continue
		var nb := {}
		for j in [i - 1, i + 1]:
			if j >= 0 and j < seq.size():
				var dname = names.get(seq[j] - cell)
				if dname:
					nb[dname] = true
		if i == seq.size() - 1:
			nb["E" if nb.has("W") else ("W" if nb.has("E") else ("S" if nb.has("N") else "N"))] = true
		var key := ""
		for x in ["N", "E", "S", "W"]:
			if nb.has(x):
				key += x
		out[cell] = { key = key, first = i == 1 and off.call(seq[0]), last = i == seq.size() - 1 }
	return out


func _draw_path(img: Image, top: int, st: Dictionary, links: Dictionary) -> void:
	var col := {}
	for k in st:
		col[k] = Color(st[k])
	var arms := { N = Vector2(0, -1), E = Vector2(1, 0), S = Vector2(0, 1), W = Vector2(-1, 0) }
	var sq := float(TILE) / TH # stretch y so distances are measured on the flat ground
	var R := TILE / 2.0
	for cell: Vector2i in links:
		var c := cell.x
		var r := cell.y
		var dirs: String = links[cell].key
		for v in TH:
			for u in TILE:
				var dx := u + 0.5 - TILE / 2.0
				var dy := (v + 0.5 - TH / 2.0) * sq
				var dist := sqrt(dx * dx + dy * dy)
				var along = null
				for a in dirs:
					var ar: Vector2 = arms[a]
					if dx * ar.x + dy * ar.y < 0:
						continue
					var p := absf(dy if ar.x != 0 else dx)
					if p < dist:
						dist = p
						along = float(c * TILE + u) if ar.x != 0 else (r * TH + v) * sq
				if dist > R:
					continue
				var k := ""
				if dist > R - 1:
					k = "edge"
				elif dist > R - 3:
					k = "curb" if dist > R - 2 else "curbLo"
				elif dist > R - 5:
					k = "rim"
				else:
					k = "speck" if Hash32.cell(c * TILE + u, r * TH + v, 11) < 0.07 else "fill"
					if col.has("dash") and along != null and dist < 1.1 and fposmod(along, 14.0) < 7:
						k = "dash"
				if col.has("stud") and k == "curb" and along != null and fposmod(along, 16.0) < 2:
					k = "stud"
				img.set_pixel(u + c * TILE, v + r * TH + top, col[k])
