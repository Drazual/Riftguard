class_name HomeBase
extends Control
## The home base: a small walkable town the start button leads to. You walk around as your hero (the one you last
## played, the Striker at first) and walk into a building to open its menu: the hero building opens the Heroes
## screen, the tower building the Towers screen. Esc still opens the main menu. Drawn in the board's 3/4 view
## (32x24 ground tiles, the live 3D hero through Hero3D), with placeholder buildings and tiles from the maps.

const W := 768 # the base's size in board pixels (one screen, like a map)
const H := 416
const SHARP := 2 # rendered at 2x, so the 2x building art and the hero's own 2x render stay crisp
const TILE := Vector2(32, 24)
const SPR := "res://assets/maps/map1_miami/spr/"
const START := Vector2(384, 330) # where the hero stands when the base opens (feet, board pixels)
const PAD_R := Vector2(30, 14)
const BIG := 0.8 # the two buildings are drawn bigger than on their map, as the base's landmarks # a door pad's half-size (an ellipse on the ground)

## The buildings: the art (placeholder sprites from the Ocean Drive map, drawn at half size), where its ground
## line sits (bottom-centre), its sign, and the menu its door opens.
const BUILDINGS := [
	{ id = "heroes", tex = "bld_hotel_11.png", at = Vector2(190, 200), sign = "HEROES", col = Color(1.0, 0.45, 0.8) },
	{ id = "towers", tex = "bld_techshop_00.png", at = Vector2(580, 200), sign = "TOWERS", col = Color(0.35, 0.95, 1.0) },
]
## Decoration around the plaza, from the maps' prop sheets and sprites: [file, feet position].
const DECOR := [
	["palm_planter_a_23.png", Vector2(70, 150)], ["palm_planter_b_46.png", Vector2(712, 152)],
	["lamp_31.png", Vector2(300, 214)], ["lamp_42.png", Vector2(468, 214)],
	["fountain_plaza_17.png", Vector2(384, 238)], ["bench_39.png", Vector2(150, 300)],
	["bench_56.png", Vector2(620, 300)], ["palm_planter_plaza_14.png", Vector2(60, 380)],
	["palm_planter_plaza_93.png", Vector2(712, 386)], ["vending_33.png", Vector2(690, 228)],
	["phone_booth_34.png", Vector2(84, 230)], ["trash_22.png", Vector2(328, 300)],
]

signal enter(id: String) # walked into a building's door

var vp: SubViewport
var world: Node2D
var units: Node2D # y-sorted: buildings, props and the hero
var pads: Node2D
var view: TextureRect
var hint: Label
var hero: Hero3D
var hero_id := ""
var feet := START
var goal = null # a clicked spot to walk to (Vector2), or null
var speed := 116.0 # board pixels a second (the hero's own speed)
var blocks: Array[Rect2] = [] # ground the hero can't walk on (building footprints, the fountain)
var doors := {} # id -> the door pad's centre
var inside := "" # the door the hero stands on (it opens once per visit)
var active := false
var t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Kit.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	vp = SubViewport.new()
	vp.size = Vector2i(W * SHARP, H * SHARP)
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	world = Node2D.new()
	world.scale = Vector2(SHARP, SHARP)
	vp.add_child(world)
	_ground()
	pads = Node2D.new()
	pads.draw.connect(_draw_pads)
	world.add_child(pads)
	units = Node2D.new()
	units.y_sort_enabled = true
	world.add_child(units)
	for d in DECOR:
		_sprite(d[0], d[1])
	for b in BUILDINGS:
		var s := _sprite(b.tex, b.at, BIG)
		var sz: Vector2 = s.texture.get_size() * BIG
		# the footprint: the lower part of the sprite's diamond, so the hero can walk up to the door
		blocks.append(Rect2(b.at.x - sz.x * 0.42, b.at.y - sz.y * 0.36, sz.x * 0.84, sz.y * 0.34))
		doors[b.id] = b.at + Vector2(0, 16)
		var l := Label.new()
		l.text = b.sign
		l.add_theme_font_override("font", Kit.display_bold)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", b.col)
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.12))
		l.add_theme_constant_override("outline_size", 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(120, 18)
		l.position = Vector2(b.at.x - 60, b.at.y - sz.y - 14)
		world.add_child(l)
	blocks.append(Rect2(384 - 30, 238 - 14, 60, 18)) # the fountain
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	hint = Label.new()
	hint.text = "WASD or click to walk   ·   walk into a building to open it   ·   Esc for the menu"
	hint.add_theme_font_override("font", Kit.display)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Kit.TEXT)
	hint.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.08))
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34
	hint.offset_bottom = -12
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


## The ground: the boardwalk tile set's sand all over, with a plaza of the reactor set's floor tiles in the middle
## and walkways to the doors (both are map tile sets; picked at random within each set, weighted like the maps).
func _ground() -> void:
	var sand := TileMapLayer.new()
	sand.tile_set = load("res://maps/tilesets/boardwalk.tres")
	world.add_child(sand)
	var plaza := TileMapLayer.new()
	plaza.tile_set = load("res://maps/tilesets/reactor.tres")
	world.add_child(plaza)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := int(ceil(W / TILE.x))
	var rows := int(ceil(H / TILE.y))
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var p := (Vector2(c) + Vector2(0.5, 0.5)) * TILE
			var deco := rng.randf() < 0.08
			sand.set_cell(c, 0, Vector2i(rng.randi_range(2, 3) if deco else (1 if rng.randf() < 0.25 else 0), 0))
			# the plaza: an oval in the middle, and a walkway up to each door
			var in_plaza := ((p - Vector2(384, 268)) / Vector2(300, 120)).length() < 1.0
			for b in BUILDINGS:
				if absf(p.x - b.at.x) < 40 and p.y > b.at.y - 4 and p.y < b.at.y + 90:
					in_plaza = true
			if in_plaza:
				plaza.set_cell(c, 0, Vector2i(rng.randi_range(0, 1) if rng.randf() < 0.85 else 4, 0))


func _sprite(file: String, at: Vector2, k := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SPR + file)
	s.centered = false
	s.scale = Vector2(k, k) # 2x art: 0.5 is the size it has on its map
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	units.add_child(s)
	return s


func _draw_pads() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for b in BUILDINGS:
		var c: Vector2 = doors[b.id]
		var col: Color = b.col
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(c + Vector2(cos(a) * PAD_R.x, sin(a) * PAD_R.y))
		pads.draw_colored_polygon(pts, Color(col, 0.16 + 0.12 * pulse))
		pads.draw_polyline(pts, Color(col, 0.7 + 0.3 * pulse), 1.5, true)


## Shows the base with `id` as the hero you walk around as (it keeps where you stood, unless it's a new hero).
func open(id: String) -> void:
	visible = true
	active = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if hero_id != id or hero == null or not is_instance_valid(hero):
		hero_id = id
		if hero and is_instance_valid(hero):
			hero.queue_free()
		hero = null
		var d: HeroData = DB.heroes[id]
		speed = d.speed * Board.PX
		if d.model_dir != "":
			hero = Hero3D.new()
			units.add_child(hero)
			hero.setup(d.model_dir)
			hero.face(PI / 2, true)
		feet = START
	goal = null
	_place()


## Hides the base (a run starts).
func close() -> void:
	visible = false
	active = false
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## True while you can walk around (no menu screen or pop-up over the base).
func live() -> bool:
	var u := get_parent() as Ui
	return visible and active and not (u and (u.screen.visible or u.modal_open()))


func _place() -> void:
	if hero:
		hero.position = feet


## Where a point on this control lands in the base (board pixels).
func to_base(p: Vector2) -> Vector2:
	var r := view.size
	var s := minf(r.x / W, r.y / H)
	var off := (r - Vector2(W, H) * s) / 2
	return (p - view.position - off) / s


func _gui_input(ev: InputEvent) -> void:
	if not live():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		goal = to_base(ev.position)
		accept_event()


func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	pads.queue_redraw()
	# (under a menu screen it isn't seen, so it doesn't render)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live() else SubViewport.UPDATE_DISABLED
	if not live():
		if hero:
			hero.play("idle")
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		goal = null
	elif goal != null:
		var to: Vector2 = goal - feet
		if to.length() < 3:
			goal = null
		else:
			dir = to
	step(dir, dt)


## Walks `dir` (on screen, any length) for `dt` seconds: the ground is squashed (3/4 view), so going up or down the
## screen covers it at K of the speed, like on the board. Stops at buildings and the edges.
func step(dir: Vector2, dt: float) -> void:
	if dir == Vector2.ZERO:
		if hero:
			hero.play("idle")
		_doors()
		return
	var u := dir.normalized()
	var v := u * speed * dt * Vector2(1, Board.K)
	var to := _walkable(feet + v)
	if to == feet:
		# slide along whatever is in the way
		to = _walkable(feet + Vector2(v.x, 0))
		if to == feet:
			to = _walkable(feet + Vector2(0, v.y))
	var moved := to != feet
	feet = to
	if hero:
		hero.face(u.angle())
		if moved:
			hero.move(speed, 1.0, false)
		else:
			hero.play("idle")
	if not moved:
		goal = null
	_place()
	_doors()


func _walkable(p: Vector2) -> Vector2:
	var q := Vector2(clampf(p.x, 16, W - 16), clampf(p.y, 120, H - 8))
	for r in blocks:
		if r.has_point(q):
			return feet
	return q


## Opens a building's menu as the hero steps onto its door pad (once: step off and back on to open it again).
func _doors() -> void:
	var at := ""
	for id in doors:
		if ((feet - doors[id]) / PAD_R).length() <= 1.0:
			at = id
	if at != "" and at != inside:
		inside = at
		goal = null
		enter.emit(at)
	elif at == "":
		inside = ""
