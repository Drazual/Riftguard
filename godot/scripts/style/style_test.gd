extends Control
## The art-style test scene: a road, a building, Gale and one tower in the shared low-res 3D renderer (StyleWorld),
## at real gameplay size, with the style settings on a side panel. Isolated: the game doesn't use any of it yet.
##   godot --path godot res://scenes/style_test.tscn
## Click to send Gale somewhere (checks mouse targeting through the upscaled render). Space: pause the patrol.
## B: a cyan beam across the road and the pavement (on by default). Tab: hide the panel. R: resize the window.
## Every piece is an existing asset; the legend says which, and what is only a stand-in.

const GROUND := "res://assets/maps/map1_miami/ground.png"
const BUILDING := "res://assets/maps/map1_miami/spr/bld_techshop_91.png"
const GALE := "res://art_src/heroes/gale_tank"
const TOWER := "res://art_src/towers/arcane"
const AIR_BEAM := preload("res://effects/gale_air_beam/air_beam.tscn")
const EDGE := preload("res://effects/gale_air_beam/camera_edge.gd")
## Where things stand, in art pixels (the 1536x832 scenery art): the building's top-left and ground line, the
## tower's base, Gale's patrol (a loop passing behind the building, then in front of it on the road).
const BUILDING_TL := Vector2(626, 396)
const BUILDING_KEY := 560.0
const TOWER_AT := Vector2(900, 556)
const PATROL := [Vector2(560, 512), Vector2(820, 512), Vector2(820, 610), Vector2(560, 610)]
const BEAM_FROM := Vector2(300, 600)
const BEAM_TO := Vector2(1240, 760)

var settings := StyleSettings.new()
var world: StyleWorld
var hero: Hero3D
var gale: Node3D # Gale's anchor in the world
var tower: Node3D
var tower_yaw: Node3D
var tower_ap: AnimationPlayer
var beam: GaleAirBeam
var at := PATROL[0] # Gale's feet, art pixels
var leg := 1
var goal = null # a clicked art point
var paused := false
var speed := 130.0 # art pixels a second
var panel: PanelContainer
var legend: Label
var mark: Control # where the mouse lands in the world, drawn at native resolution


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	world = StyleWorld.new(settings)
	add_child(world)
	world.set_ground(load(GROUND))
	world.add_sprite(load(BUILDING), BUILDING_TL, BUILDING_KEY, 1.0, "Building")
	_gale()
	_tower()
	_beam()
	mark = Control.new()
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(_draw_mark)
	add_child(mark)
	_legend()
	_panel()
	world.apply()


func _gale() -> void:
	hero = Hero3D.new()
	add_child(hero)
	hero.setup(GALE, 26.0, world.rig) # drawn in the shared world, its position in art pixels
	hero.position = at
	gale = hero.anchor
	world.place_art(gale, at)


func _tower() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TOWER.path_join("tower.json")))
	var m: Node3D = (load(TOWER.path_join(cfg.model)) as PackedScene).instantiate()
	m.name = "ArcaneBolt"
	tower_yaw = m.get_node_or_null(cfg.get("yaw", ""))
	tower_ap = m.find_child("AnimationPlayer", true, false)
	tower = world.add_model(m, 0.75)
	world.place_art(tower, TOWER_AT)
	if tower_ap and tower_ap.has_animation(cfg.anims.idle):
		tower_ap.play(cfg.anims.idle)


## A steady Air Stream beam across the dark road and the light pavement, to check cyan glow on both.
func _beam() -> void:
	beam = AIR_BEAM.instantiate()
	world.models.add_child(beam)
	beam.auto_free = false
	var a := world.art_to_ground(BEAM_FROM) + Vector3.UP * 0.5
	var b := world.art_to_ground(BEAM_TO) + Vector3.UP * 0.5
	beam.activate(a, (b - a).normalized(), a.distance_to(b), 1.0)
	beam.set_process(false)
	beam.preview_at(0.3, 1.0)


func _process(dt: float) -> void:
	# Gale walks the patrol (or to a clicked point), facing where it goes; the tower turret follows Gale
	var to: Vector2 = goal if goal != null else PATROL[leg]
	var d := to - at
	var moving := not paused and d.length() > 2.0
	if moving:
		var step := minf(d.length(), speed * dt)
		at += d.normalized() * step
		hero.face(d.angle())
		hero.move(speed / 2.0, 1.0, false)
	else:
		if goal != null:
			goal = null
		elif not paused:
			leg = (leg + 1) % PATROL.size()
		hero.play("idle")
	hero.position = at
	world.place_art(gale, at)
	if tower_yaw:
		var g := gale.global_position - tower.global_position
		tower_yaw.global_rotation.y = atan2(g.x, g.z)
	mark.queue_redraw()


func _draw_mark() -> void:
	var p := get_local_mouse_position()
	var a := world.local_to_art(p - world.position)
	if a.x < 0 or a.y < 0 or a.x > StyleWorld.ART.x or a.y > StyleWorld.ART.y:
		return
	# round trip: art pixel -> ground -> back to the screen, so a ring off the cursor means targeting is off
	var back := world.art_to_local(world.world_to_art(world.art_to_ground(a))) + world.position
	mark.draw_arc(back, 9, 0, TAU, 24, Color(0.3, 1, 0.95, 0.9), 1.5)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		goal = world.local_to_art(ev.position - world.position)


func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_SPACE:
			paused = not paused
		KEY_TAB:
			panel.visible = not panel.visible
			legend.visible = panel.visible
		KEY_B:
			beam.visible = not beam.visible
		KEY_R:
			var s := DisplayServer.window_get_size()
			DisplayServer.window_set_size(Vector2i(1280, 800) if s.x > 1400 else Vector2i(1600, 900))


## The beam's length to the screen edge from Gale's shield height, through the actual gameplay camera and its
## low-res viewport (camera_edge.gd), for the test.
func edge_length(from_art: Vector2, dir: Vector3) -> float:
	return EDGE.length_to_edge(world.cam, world.art_to_ground(from_art) + Vector3.UP * 0.5, dir)


func _legend() -> void:
	legend = Label.new()
	legend.text = "STYLE TEST (not the game)\n" \
		+ "Road + sidewalk: Ocean Drive ground.png (existing)\n" \
		+ "Building: Ocean Drive bld_techshop_91 (existing sprite)\n" \
		+ "Gale: live 3D, new-shield model (existing)\n" \
		+ "Tower: Arcane Bolt, live 3D model (existing; the game bakes it to sprites today)\n" \
		+ "Cyan beam: Gale's air beam effect (existing), held on for the glow check\n" \
		+ "Stand-ins: contact shadows are a procedural blob; no new art yet"
	legend.add_theme_font_size_override("font_size", 13)
	legend.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	legend.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	legend.add_theme_constant_override("outline_size", 6)
	legend.position = Vector2(14, 10)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(legend)


func _panel() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-300, 10)
	panel.custom_minimum_size = Vector2(290, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.12, 0.85)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Style settings"
	v.add_child(title)
	for b in ["stylize", "integer_scale", "pixel_snap", "cast_shadows"]:
		var c := CheckBox.new()
		c.text = b.replace("_", " ")
		c.button_pressed = settings.get(b)
		c.toggled.connect(func(on: bool): settings.set(b, on); world.apply())
		v.add_child(c)
	for row in [["res_scale", 0.5, 4.0, 0.25], ["palette_strength", 0, 1, 0.01], ["keep_accents", 0, 1, 0.01],
			["shadow_strength", 0, 1, 0.01], ["contact_shadow", 0, 1, 0.01], ["shadow_energy", 0, 2, 0.01],
			["light_energy", 0, 3, 0.01], ["band_edge", -1, 1, 0.01], ["highlight", 0, 2, 0.01], ["rim", 0, 2, 0.01],
			["outline", 0, 3, 0.25], ["normal_detail", 0, 1, 0.01], ["simplify", 0, 4, 0.1], ["glow", 0, 2, 0.01],
			["glow_threshold", 0, 4, 0.01], ["exposure", 0.2, 2, 0.01]]:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(118, 0)
		l.add_theme_font_size_override("font_size", 12)
		var key: String = row[0]
		var sl := HSlider.new()
		sl.min_value = row[1]
		sl.max_value = row[2]
		sl.step = row[3]
		sl.value = settings.get(key)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%s %s" % [key.replace("_", " "), str(snappedf(sl.value, row[3]))]
		sl.value_changed.connect(func(x: float):
			settings.set(key, x)
			l.text = "%s %s" % [key.replace("_", " "), str(snappedf(x, row[3]))]
			world.apply())
		h.add_child(l)
		h.add_child(sl)
		v.add_child(h)
