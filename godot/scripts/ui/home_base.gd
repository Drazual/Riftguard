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
	# the rift gate: walk in to choose a map and start a run (Ocean Drive's portal, at its own size)
	{ id = "start", tex = "portal_68.png", at = Vector2(384, 176), sign = "START RUN", col = Color(1.0, 0.82, 0.35), k = 0.5 },
]
## Decoration around the plaza, from the maps' prop sheets and sprites: [file, feet position, scale (0.5 = its map
## size), solid (the hero walks around it)]. Palms sway and every sign's neon pulses (the maps' own neon shader).
const DECOR := [
	["lamp_31.png", Vector2(300, 214)], ["lamp_42.png", Vector2(468, 214)],
	["fountain_plaza_17.png", Vector2(384, 238)], ["bench_39.png", Vector2(150, 300)],
	["bench_56.png", Vector2(620, 300)], ["vending_33.png", Vector2(690, 228)],
	["phone_booth_34.png", Vector2(84, 230)], ["trash_22.png", Vector2(328, 300)],
	# the left and right edges: palms, neon signs and flower beds
	["palm_planter_a_23.png", Vector2(28, 168)], ["neon_sign_a_40.png", Vector2(46, 214)],
	["flower_plaza_44.png", Vector2(40, 272), 0.5, true], ["palm_planter_b_46.png", Vector2(102, 262)],
	["neon_sign_b_41.png", Vector2(26, 330)], ["palm_planter_a_52.png", Vector2(66, 352)],
	["palm_planter_a_47.png", Vector2(740, 168)], ["neon_sign_a_73.png", Vector2(726, 286)],
	["flower_plaza_62.png", Vector2(728, 250), 0.5, true], ["palm_planter_b_54.png", Vector2(668, 258)],
	["phone_booth_34.png", Vector2(748, 340)], ["palm_planter_a_69.png", Vector2(704, 352)],
	["lamp_53.png", Vector2(230, 300)], ["lamp_77.png", Vector2(538, 300)],
	["flower_tile_08.png", Vector2(300, 352), 0.5, true], ["flower_tile_113.png", Vector2(468, 352), 0.5, true],
	# the promenade along Ocean Drive: palms and lamps on the kerb
	["palm_planter_a_23.png", Vector2(120, 384)], ["lamp_45.png", Vector2(200, 384)],
	["palm_planter_b_46.png", Vector2(270, 384)], ["palm_planter_a_47.png", Vector2(498, 384)],
	["lamp_32.png", Vector2(568, 384)], ["palm_planter_b_54.png", Vector2(640, 384)],
]
## The skyline behind the plaza: buildings along the back, drawn under the sunset (feet x, file).
const SKYLINE := [
	[18, "bld_apartments_05.png"], [96, "bld_nightclub_06.png"], [176, "bld_palmhotel_07.png"],
	[286, "bld_theater_30.png"], [482, "bld_records_04.png"], [592, "bld_arcade_13.png"],
	[676, "bld_apartments_81.png"], [752, "bld_motel_55.png"],
]
const SKY_H := 132.0 # the sunset band at the top of the base (board pixels)
const ROAD_Y := 388.0 # Ocean Drive runs along the bottom, below this line
const WALK_LOW := 376.0 # the hero walks down to the kerb, not onto the road

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
var signs: Array[Label] = [] # the buildings' neon signs (they flicker now and then)
var cars: Node2D # Ocean Drive's traffic
var car_list: Array = [] # { node, lane, speed }
var _rng := RandomNumberGenerator.new()
const NEON := preload("res://scripts/board/map_neon.gdshader")
const SKY_SHADER := """
shader_type canvas_item;
// A Miami sunset over the base: a violet-to-coral sky, a striped retro sun sinking behind the rift gate, stars
// twinkling at the top, thin cloud streaks drifting and two searchlights sweeping. Fades into the ground at the bottom.
uniform vec2 size = vec2(768.0, 132.0);
uniform vec2 sun = vec2(384.0, 92.0);
uniform float sun_r = 64.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = UV * size;
	float y = UV.y;
	vec3 top = vec3(0.07, 0.03, 0.18);
	vec3 mid = vec3(0.42, 0.08, 0.42);
	vec3 low = vec3(1.0, 0.42, 0.38);
	vec3 c = mix(top, mid, smoothstep(0.0, 0.55, y));
	c = mix(c, low, smoothstep(0.45, 1.0, y));
	// stars, only up high
	vec2 cell = floor(p / 6.0);
	float h = hash(cell);
	if (h > 0.965 && y < 0.45) {
		float tw = 0.5 + 0.5 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		vec2 f = fract(p / 6.0) - 0.5;
		c += vec3(0.9, 0.85, 1.0) * tw * smoothstep(0.22, 0.0, length(f)) * (1.0 - y / 0.45);
	}
	// the sun: yellow to hot pink, cut by stripes that slide down and widen toward the horizon
	vec2 d = p - sun;
	float r = length(d);
	if (r < sun_r) {
		float k = clamp((d.y + sun_r) / (2.0 * sun_r), 0.0, 1.0);
		vec3 sc = mix(vec3(1.0, 0.93, 0.45), vec3(1.0, 0.25, 0.55), k);
		float band = fract((d.y / sun_r) * 4.0 - TIME * 0.18);
		float gap = smoothstep(0.0, 1.0, k * 1.6 - 0.35) * 0.55;
		float cut = (d.y > -sun_r * 0.15 && band < gap) ? 0.0 : 1.0;
		c = mix(c, sc, cut * smoothstep(sun_r, sun_r - 1.5, r));
	}
	c += vec3(1.0, 0.4, 0.5) * 0.35 * smoothstep(sun_r * 2.2, sun_r, r); // the glow around it
	// cloud streaks drifting across in front of the sun
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float cy = size.y * (0.38 + 0.13 * fi);
		float band2 = exp(-pow((p.y - cy) / 2.2, 2.0));
		float xs = sin((p.x + TIME * (6.0 + fi * 3.0) + fi * 200.0) / (60.0 + fi * 20.0)) * 0.5 + 0.5;
		c = mix(c, vec3(0.3, 0.06, 0.32), band2 * smoothstep(0.35, 0.9, xs) * 0.7);
	}
	// searchlights: two beams from below, swinging slowly
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		vec2 o = vec2(size.x * (0.18 + 0.64 * fi), size.y + 20.0);
		float a = 0.35 * sin(TIME * (0.35 + 0.1 * fi) + fi * 2.0) + (fi > 0.5 ? 0.25 : -0.25);
		vec2 dir = vec2(sin(a), -cos(a));
		vec2 q = p - o;
		float along = dot(q, dir);
		float across = abs(q.x * dir.y - q.y * dir.x);
		float beam = smoothstep(4.0 + along * 0.08, 0.0, across) * step(0.0, along) * (1.0 - smoothstep(60.0, 190.0, along));
		c += vec3(0.55, 0.85, 1.0) * beam * 0.22;
	}
	COLOR = vec4(c, 1.0 - smoothstep(0.86, 1.0, y));
}
"""


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
	_sky()
	_road()
	pads = Node2D.new()
	pads.draw.connect(_draw_pads)
	world.add_child(pads)
	units = Node2D.new()
	units.y_sort_enabled = true
	world.add_child(units)
	for d in DECOR:
		var k: float = d[2] if d.size() > 2 else 0.5
		var sp := _sprite(d[0], d[1], k)
		if d.size() > 3 and d[3]:
			var sz: Vector2 = sp.texture.get_size() * k
			blocks.append(Rect2(d[1].x - sz.x * 0.4, d[1].y - sz.y * 0.45, sz.x * 0.8, sz.y * 0.45))
	for b in SKYLINE:
		_sprite(b[1], Vector2(b[0], 126), 0.5).modulate = Color(0.86, 0.8, 0.96) # a little hazy, behind
	_life()
	for b in BUILDINGS:
		var k: float = b.get("k", BIG)
		var s := _sprite(b.tex, b.at, k)
		var sz: Vector2 = s.texture.get_size() * k
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
	signs.clear()
	for c in world.get_children():
		if c is Label:
			signs.append(c)
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	hint = Label.new()
	hint.text = "WASD or click to walk   ·   walk into a building to open it   ·   the rift gate starts a run   ·   Esc for the menu"
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


## The sunset band across the top (SKY_SHADER), over the ground's top rows and behind the skyline.
func _sky() -> void:
	var r := ColorRect.new()
	r.size = Vector2(W, SKY_H)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	m.shader = sh
	m.set_shader_parameter("size", Vector2(W, SKY_H))
	r.material = m
	world.add_child(r)


## Ocean Drive along the bottom: asphalt, a pink neon kerb, dashed lane lines, and traffic driving both ways.
func _road() -> void:
	var road := Node2D.new()
	road.draw.connect(func():
		road.draw_rect(Rect2(0, ROAD_Y, W, H - ROAD_Y), Color(0.13, 0.08, 0.2))
		road.draw_rect(Rect2(0, ROAD_Y - 3, W, 3), Color(0.95, 0.75, 0.78))
		road.draw_line(Vector2(0, ROAD_Y), Vector2(W, ROAD_Y), Color(1.0, 0.3, 0.75, 0.9), 1.5)
		var mid := ROAD_Y + (H - ROAD_Y) * 0.5
		for x in range(0, W, 28):
			road.draw_line(Vector2(x, mid), Vector2(x + 14, mid), Color(1.0, 0.85, 0.4, 0.8), 1.2))
	world.add_child(road)
	cars = Node2D.new()
	cars.z_index = 1 # in front of the kerb's palms (it's nearer than anything the hero can reach)
	world.add_child(cars)
	_rng.seed = 11
	for i in 5:
		_add_car(i % 2, _rng.randf_range(0, W))


const CAR_COLS := [Color(1.0, 0.35, 0.75), Color(0.35, 0.95, 1.0), Color(1.0, 0.85, 0.4), Color(0.75, 0.5, 1.0), Color(0.98, 0.98, 1.0)]
const HUE := """
shader_type canvas_item;
// the taxi sprite repainted: its yellow body takes the car's colour, everything else stays
uniform vec4 body : source_color = vec4(1.0, 0.35, 0.75, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float y = clamp((min(c.r, c.g) - c.b) * 2.0, 0.0, 1.0); // how yellow
	c.rgb = mix(c.rgb, body.rgb * max(c.r, c.g), y);
	COLOR = c * COLOR;
}
"""
## A car on Ocean Drive (the map's taxi, repainted): lane 0 drives right along the far side, lane 1 left on the near.
func _add_car(lane: int, x: float) -> void:
	var s := Sprite2D.new()
	s.texture = load(SPR + "taxi_61.png")
	s.scale = Vector2(0.42, 0.42)
	s.flip_h = lane == 1
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HUE
	m.shader = sh
	m.set_shader_parameter("body", CAR_COLS[_rng.randi() % CAR_COLS.size()])
	s.material = m
	# headlights and tail lights, a soft glow ahead and a red dot behind
	var glow := Node2D.new()
	glow.draw.connect(func():
		var f := -1.0 if lane == 1 else 1.0
		for i in 6:
			glow.draw_circle(Vector2(f * (14 + i * 4), 2), 3.0 + i * 1.2, Color(1.0, 0.95, 0.7, 0.10 - i * 0.014))
		glow.draw_circle(Vector2(-f * 14, 1), 1.6, Color(1.0, 0.2, 0.3, 0.9)))
	s.add_child(glow)
	glow.scale = Vector2.ONE / 0.42
	s.position = Vector2(x, ROAD_Y + (7.0 if lane == 0 else 20.0))
	cars.add_child(s)
	car_list.append({ node = s, lane = lane, speed = _rng.randf_range(55, 95) })


## The small life: fountain spray, neon motes drifting up over the plaza.
func _life() -> void:
	var spray := CPUParticles2D.new()
	spray.position = Vector2(384, 224)
	spray.amount = 40
	spray.lifetime = 1.1
	spray.direction = Vector2(0, -1)
	spray.spread = 14
	spray.initial_velocity_min = 34
	spray.initial_velocity_max = 48
	spray.gravity = Vector2(0, 80)
	spray.scale_amount_min = 1.0
	spray.scale_amount_max = 1.8
	spray.color = Color(0.6, 0.95, 1.0, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.75, 1.0, 1.0, 0.95))
	ramp.set_color(1, Color(0.45, 0.75, 1.0, 0.0))
	spray.color_ramp = ramp
	world.add_child(spray)
	var motes := CPUParticles2D.new()
	motes.position = Vector2(W / 2.0, 340)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(W / 2.0, 120)
	motes.amount = 46
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.direction = Vector2(0, -1)
	motes.spread = 25
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 6
	motes.initial_velocity_max = 14
	motes.scale_amount_min = 0.8
	motes.scale_amount_max = 1.6
	var mr := Gradient.new()
	mr.set_color(0, Color(1.0, 0.4, 0.85, 0.0))
	mr.add_point(0.3, Color(1.0, 0.45, 0.85, 0.8))
	mr.add_point(0.7, Color(0.4, 0.95, 1.0, 0.7))
	mr.set_color(mr.get_point_count() - 1, Color(0.4, 0.95, 1.0, 0.0))
	motes.color_ramp = mr
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = add
	world.add_child(motes)


func _sprite(file: String, at: Vector2, k := 0.5) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(SPR + file)
	s.centered = false
	s.scale = Vector2(k, k) # 2x art: 0.5 is the size it has on its map
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.position = at
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var m := ShaderMaterial.new()
	m.shader = NEON
	m.set_shader_parameter("period", 4.0)
	if file.begins_with("palm"):
		m.set_shader_parameter("sway", 0.03)
		m.set_shader_parameter("sway_phase", fmod(at.x * 0.013 + at.y * 0.007, 1.0))
	elif file.begins_with("portal"):
		# Ocean Drive's portal ring (its layout's ring, relative to the sprite)
		m.set_shader_parameter("ring", Vector2(124.9, 79.4))
		m.set_shader_parameter("ring_r", Vector2(45.4, 65.2))
	s.material = m
	units.add_child(s)
	return s


func _draw_pads() -> void:
	# the rift gate hums: neon rings roll out from it across the plaza floor, fading as they spread
	var gate: Vector2 = doors.get("start", Vector2(384, 192))
	for k in 3:
		var u := fmod(t / 3.6 + k / 3.0, 1.0)
		var rr := Vector2(40, 18) + Vector2(330, 150) * u
		var col := Color(1.0, 0.45, 0.85).lerp(Color(0.4, 0.95, 1.0), u)
		var ring := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			ring.append(gate + Vector2(cos(a) * rr.x, sin(a) * rr.y))
		pads.draw_polyline(ring, Color(col, 0.28 * (1.0 - u) * smoothstep(0.0, 0.08, u)), 1.5, true)
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
	for c in car_list:
		var n: Sprite2D = c.node
		n.position.x += (c.speed if c.lane == 0 else -c.speed) * dt
		if n.position.x > W + 40:
			n.position.x = -40
		elif n.position.x < -40:
			n.position.x = W + 40
	# the signs buzz like old neon: now and then one flickers for a moment
	for i in signs.size():
		var l := signs[i]
		var ph := fmod(t * 0.37 + i * 0.29, 1.0)
		var off := ph > 0.93 and fmod(t * 23.0 + i, 1.0) < 0.45
		l.modulate.a = 0.55 if off else 0.92 + 0.08 * sin(t * 3.0 + i)
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
	var q := Vector2(clampf(p.x, 16, W - 16), clampf(p.y, 120, WALK_LOW))
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
