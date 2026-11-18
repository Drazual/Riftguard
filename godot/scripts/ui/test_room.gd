## The Test Room's panel, over the left edge of the map: spawn any enemy (as many as you like, with the HP of any
## wave), clear the board, swap heroes and their abilities (or the Wizard's elements) and refill the ability.
class_name TestRoomPanel
extends PanelContainer

const W := 250.0

var ui: Ui
var game: Game
var open := true
var count_box: SpinBox
var wave_box: SpinBox
var gap_box: SpinBox
var queue_lbl: Label
var body: VBoxContainer
# kept across redraws so the numbers you typed stay
var count := 10
var wave := 1
var gap := 0.5


func _init(u: Ui) -> void:
	ui = u
	game = u.game
	theme_type_variation = "Card"
	anchor_left = 0
	anchor_right = 0
	offset_left = 10
	offset_top = 10
	offset_right = 10 + W
	visible = false


## Shows the panel in a Test Room run (and hides it everywhere else), drawn fresh.
func render() -> void:
	var S := game.S
	visible = S != null and S.test and S.hero != null and not S.over
	if not visible:
		return
	_read_numbers()
	Kit.clear(self)
	var v := Kit.vbox(6)
	add_child(v)
	var top := Kit.hbox(6)
	var title := Kit.label("TEST ROOM", 15, Kit.TECH, Kit.display_bold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(Kit.button("Hide" if open else "Show", func():
		open = not open
		render()))
	v.add_child(top)
	if not open:
		offset_bottom = offset_top
		return
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(W - 24, minf(560, ui.board.size.y - 70))
	v.add_child(sc)
	body = Kit.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_spawn_part()
	body.add_child(HSeparator.new())
	_hero_part()


func _spawn_part() -> void:
	body.add_child(Kit.h3("Spawn enemies"))
	count_box = _number("How many", 1, 1000, 1, count)
	wave_box = _number("HP of wave", 1, 99, 1, wave)
	gap_box = _number("Seconds apart", 0.05, 5, 0.05, gap)
	body.add_child(Kit.muted("Click an enemy to send that many down the road.", 11))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for e: EnemyData in DB.rules.enemies:
		var bt := Kit.button(e.name, _spawn.bind(e.id))
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.clip_text = true
		bt.add_theme_font_size_override("font_size", 12)
		if e.boss:
			bt.add_theme_color_override("font_color", Color("#ff8a9a"))
		var info := e.info
		Kit.tip_on(bt, func(): return Kit.b(e.name) + "\n" + Kit.c("%d HP · speed %d · %s" % [roundi(e.hp), roundi(e.speed), info], Kit.MUTED), "below")
		g.add_child(bt)
	body.add_child(g)
	var row := Kit.hbox(6)
	row.add_child(Kit.button("Clear enemies", func():
		game.test_clear()
		_sync_queue()))
	queue_lbl = Kit.label("", 11, Kit.MUTED)
	queue_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(queue_lbl)
	body.add_child(row)
	_sync_queue()


func _hero_part() -> void:
	var S := game.S
	var h := S.hero
	body.add_child(Kit.h3("Hero"))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for k in DB.hero_order:
		var d: HeroData = DB.heroes[k]
		var bt := Kit.button(d.name, func():
			game.test_swap_hero(k, false)
			render(), "OnButton" if h.cls == k else "")
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.add_theme_font_size_override("font_size", 12)
		g.add_child(bt)
	body.add_child(g)
	var d: HeroData = h.data
	if d.spells:
		_elements_part()
	else:
		body.add_child(Kit.h3("Ability"))
		for pair in [[d.ability, false], [d.alt, true]]:
			var ab: AbilityData = pair[0]
			if ab == null:
				continue
			var on := h.ab.name == ab.name
			var bt := Kit.button(ab.name + "  ·  %ss" % UiText.f1t(ab.cd), func():
				game.test_swap_hero(d.id, pair[1])
				render(), "OnButton" if on else "")
			bt.add_theme_font_size_override("font_size", 12)
			Kit.tip_on(bt, func(): return UiText.ab_text(Ability.from_data(ab)), "below")
			body.add_child(bt)
	body.add_child(Kit.button("Refill ability, mana and HP", game.test_ready_ability))


## The Wizard: take any 4 elements (locked ones too). They go on Q W E R in the order taken.
func _elements_part() -> void:
	var S := game.S
	var n := Progress.SLOT_KEYS.size()
	body.add_child(Kit.h3("Elements · %d of %d" % [S.test_els.size(), n]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	for el in DB.el_order:
		var E: ElementData = DB.elements[el]
		var i := S.test_els.find(el)
		var label: String = E.name + ("  " + Progress.SLOT_KEYS[i].to_upper() if i >= 0 else "")
		var bt := Kit.button(label, func():
			var l: Array = S.test_els.duplicate()
			if l.has(el):
				if l.size() > 1:
					l.erase(el)
			elif l.size() < n:
				l.append(el)
			else:
				ui.toast("The Wizard takes %d elements: click a taken one to drop it first." % n)
				return
			S.test_els = l
			game.test_swap_hero("wizard", false)
			render(), "OnButton" if i >= 0 else "")
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bt.add_theme_font_size_override("font_size", 12)
		bt.add_theme_color_override("font_color", E.color)
		g.add_child(bt)
	body.add_child(g)


func _number(name: String, lo: float, hi: float, step: float, at: float) -> SpinBox:
	var row := Kit.hbox(6)
	var l := Kit.label(name, 12, Kit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step
	sb.value = at
	sb.custom_minimum_size = Vector2(96, 0)
	sb.select_all_on_focus = true
	var le := sb.get_line_edit()
	# Enter keeps the number and hands the keyboard back to the game
	le.text_submitted.connect(func(_t): le.release_focus())
	row.add_child(sb)
	body.add_child(row)
	return sb


## Reads the boxes, including a number typed but not yet confirmed with Enter (the enemy buttons don't take focus).
func _read_numbers() -> void:
	if count_box == null or not is_instance_valid(count_box):
		return
	for sb: SpinBox in [count_box, wave_box, gap_box]:
		var t := sb.get_line_edit().text.strip_edges()
		if t.is_valid_float():
			sb.value = float(t)
	count = int(count_box.value)
	wave = int(wave_box.value)
	gap = gap_box.value


func _spawn(type: String) -> void:
	_read_numbers()
	for sb: SpinBox in [count_box, wave_box, gap_box]:
		sb.get_line_edit().release_focus()
	game.test_spawn(type, count, wave, gap)
	ui.toast("%d × %s queued (wave %d HP)." % [count, DB.enemies[type].name, wave])
	_sync_queue()


func _sync_queue() -> void:
	if queue_lbl == null or not is_instance_valid(queue_lbl) or game.S == null:
		return
	var alive := game.live_enemies().size()
	queue_lbl.text = "%d on the road · %d waiting" % [alive, game.S.spawn_q.size()]


func _process(_dt: float) -> void:
	if visible and open:
		_sync_queue()
