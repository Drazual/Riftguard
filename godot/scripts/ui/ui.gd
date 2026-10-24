## The game window: the top bar, the board, the side panel and build bar during a run, plus the menu
## screens, pop-up windows, tooltips and messages drawn over everything. Menus live in menus.gd and the
## in-run pop-ups in dialogs.gd; this file holds the layout, the in-run panels and the keys.
class_name Ui
extends Control

static var me: Ui

const MOVE_KEYS := { KEY_W: "up", KEY_UP: "up", KEY_S: "down", KEY_DOWN: "down", KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right" }

var game: Game
var board: Board
var menus: Menus
var dialogs: Dialogs

# layout
var top_map: Label
var top_wave: Label
var top_lives: Label
var top_gold: Label
var top_lvl: Label
var hp_meter: Kit.Meter
var xp_meter: Kit.Meter
var build_bar: HFlowContainer
var corner_bar: HBoxContainer
var hero_card: PanelContainer
var inspector: PanelContainer
var codex_box: VBoxContainer
var enemy_box: VBoxContainer
var toast_box: PanelContainer
var toast_label: RichTextLabel
var toast_t := 0.0
var mode_banner: PanelContainer
var boss_bar: VBoxContainer
var boss_name: Label
var boss_fill: Kit.Meter
var boss_warn: Label
var pause_veil: Control
var screen: Control
var screen_body: VBoxContainer
var screen_scroll: ScrollContainer
var screen_back := Callable()
var modal_layer: Control
var modal_box: PanelContainer
var modal_body: VBoxContainer
var modal_esc := Callable()
var settings_open := false
var tip: PanelContainer
var tip_label: RichTextLabel
var ability_btn: Button
var ability_fill: ColorRect
var rune_btns := {}
var rune_cast: RichTextLabel
var mana_meter: Kit.Meter
var wall_meter: Kit.Meter
var mode_timer: Label

var hud_t := 0.0
var hero_t := 0
var last_bar_gold := -1.0
var last_insp_gold := -1.0
var held_keys := {}
var codex_open := false
var enemies_open := false


func _init() -> void:
	me = self


func setup(g: Game, b: Board) -> void:
	game = g
	board = b
	menus = Menus.new(self)
	dialogs = Dialogs.new(self)
	_build()
	game.toast.connect(toast)
	game.changed.connect(_on_changed)
	game.modal.connect(dialogs.open)
	board.tower_hover.connect(func(t: Tower, at: Vector2):
		if t:
			show_tip(UiText.tower_tip(game, t), Rect2(at, Vector2.ZERO), "below")
		else:
			hide_tip())


func S() -> Run:
	return game.S


func in_run() -> bool:
	return game.S != null and game.S.hero != null and not game.S.over


# ---------- layout ----------
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Smooth filtering keeps text clean when the window is scaled; the board and portraits stay pixel-sharp.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var bg := ColorRect.new()
	bg.color = Kit.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	add_child(margin)
	var root := Kit.vbox(8)
	margin.add_child(root)
	root.add_child(_top_bar())
	var mid := Kit.hbox(8)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	var left := Kit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(left)
	left.add_child(_board_frame())
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Bar"
	build_bar = Kit.flow(6)
	bar.add_child(build_bar)
	left.add_child(bar)
	mid.add_child(_side())
	# overlays
	screen = _screen_layer()
	add_child(screen)
	modal_layer = _modal_layer()
	add_child(modal_layer)
	tip = PanelContainer.new()
	tip.theme_type_variation = "Tip"
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip.custom_minimum_size = Vector2(300, 0)
	tip_label = Kit.rich("", 13)
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.add_child(tip_label)
	add_child(tip)


func _top_bar() -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = "TopBar"
	var h := Kit.hbox(22)
	p.add_child(h)
	var brand := Kit.rich(Kit.c("RIFT", Kit.TECH) + Kit.c("GUARD", Kit.ARCANE), 22)
	brand.add_theme_font_override("normal_font", Kit.display_bold)
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(brand)
	var stat := func(name: String, col: Color) -> Label:
		var s := Kit.hbox(6)
		var k := Kit.label(name.to_upper(), 11, Kit.MUTED, Kit.display)
		k.size_flags_vertical = Control.SIZE_SHRINK_END
		s.add_child(k)
		var v := Kit.label("-", 18, col, Kit.display_bold)
		s.add_child(v)
		h.add_child(s)
		return v
	top_map = stat.call("Map", Kit.TEXT)
	top_wave = stat.call("Wave", Kit.TEXT)
	top_lives = stat.call("Base", Kit.DANGER)
	top_gold = stat.call("Gold", Kit.GOLD)
	var hb := Kit.hbox(8)
	hb.custom_minimum_size = Vector2(220, 0)
	top_lvl = stat.call("Hero", Kit.TEXT)
	top_lvl.get_parent().reparent(hb)
	var meters := Kit.vbox(3)
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_meter = Kit.meter(0, Kit.OK, 15)
	hp_meter.font_size = 11
	xp_meter = Kit.meter(0, Kit.ARCANE)
	meters.add_child(hp_meter)
	meters.add_child(xp_meter)
	hb.add_child(meters)
	h.add_child(hb)
	var gear := Kit.button("⚙", func():
		if in_run():
			menus.show_settings())
	gear.tooltip_text = "Settings and menu (Esc)"
	h.add_child(gear)
	return p


func _board_frame() -> Control:
	var frame := PanelContainer.new()
	frame.theme_type_variation = "BoardFrame"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.clip_contents = true
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(area)
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.add_child(board)
	# pause veil
	pause_veil = Kit.vbox(6)
	pause_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_veil.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.04, 0.08, 0.35)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(veil)
	var pl := Kit.head("PAUSED", 34, Color.WHITE)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_veil.add_child(pl)
	var ps := Kit.label("Press P or Resume to continue. You can still build, upgrade and sell towers.", 13, Kit.MUTED)
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_veil.add_child(ps)
	area.add_child(pause_veil)
	pause_veil.set_meta("veil", veil)
	pause_veil.visible = false
	veil.visible = false
	# boss bar
	boss_bar = Kit.vbox(4)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.offset_left = -260
	boss_bar.offset_right = 260
	boss_bar.offset_top = 48
	boss_name = Kit.label("", 13, Color("#ff8a9a"), Kit.display)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar.add_child(boss_name)
	boss_fill = Kit.meter(1, Color("#ff2e4d"), 10)
	boss_fill.back = Color(1, 0.18, 0.3, 0.15)
	boss_bar.add_child(boss_fill)
	boss_warn = Kit.label("Boss approaching your base!", 15, Color.WHITE, Kit.display)
	boss_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var warn_bg := Kit.box_style(Color(1, 0.18, 0.3, 0.85), Color(0, 0, 0, 0), 0, 4, 3)
	boss_warn.add_theme_stylebox_override("normal", warn_bg)
	boss_bar.add_child(boss_warn)
	boss_bar.visible = false
	area.add_child(boss_bar)
	# mode banner
	mode_banner = PanelContainer.new()
	mode_banner.anchor_left = 0.5
	mode_banner.anchor_right = 0.5
	mode_banner.offset_left = -300
	mode_banner.offset_right = 300
	mode_banner.offset_top = 8
	mode_banner.visible = false
	area.add_child(mode_banner)
	# toast
	toast_box = PanelContainer.new()
	toast_box.theme_type_variation = "Toast"
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.anchor_left = 1
	toast_box.anchor_right = 1
	toast_box.offset_left = -330
	toast_box.offset_right = -10
	toast_box.offset_top = 58
	toast_label = Kit.rich("", 13)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(toast_label)
	toast_box.visible = false
	area.add_child(toast_box)
	# pause, game speed and the wave button, in the top right corner of the map
	var corner := PanelContainer.new()
	corner.theme_type_variation = "Bar"
	corner.anchor_left = 1
	corner.anchor_right = 1
	corner.offset_right = -10
	corner.offset_top = 10
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner_bar = Kit.hbox(6)
	corner.add_child(corner_bar)
	area.add_child(corner)
	return frame


func _side() -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(340, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# keep room for the scroll bar so the board doesn't shift when a tall inspector appears or goes
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	var v := Kit.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	hero_card = Kit.card()
	v.add_child(hero_card)
	inspector = Kit.card()
	v.add_child(inspector)
	var cx := Kit.card()
	codex_box = Kit.vbox(4)
	cx.add_child(codex_box)
	v.add_child(cx)
	var ex := Kit.card()
	enemy_box = Kit.vbox(4)
	ex.add_child(enemy_box)
	v.add_child(ex)
	return sc


func _screen_layer() -> Control:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	var bg := ColorRect.new()
	bg.color = Kit.VOID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.add_child(bg)
	var glow := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.0)
	grad.fill_to = Vector2(1.1, 0.9)
	var gr := Gradient.new()
	gr.set_color(0, Color("#141b36"))
	gr.set_color(1, Color(Kit.VOID, 0))
	grad.gradient = gr
	glow.texture = grad
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(glow)
	screen_scroll = ScrollContainer.new()
	screen_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(screen_scroll)
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_scroll.add_child(center)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 28)
	m.add_theme_constant_override("margin_bottom", 40)
	m.custom_minimum_size = Vector2(1100, 0)
	center.add_child(m)
	screen_body = Kit.vbox(12)
	m.add_child(screen_body)
	return s


func _modal_layer() -> Control:
	var l := Control.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.055, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_child(cc)
	modal_box = PanelContainer.new()
	modal_box.theme_type_variation = "Modal"
	cc.add_child(modal_box)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.name = "Scroll"
	modal_box.add_child(sc)
	modal_body = Kit.vbox(10)
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(modal_body)
	return l


# ---------- screens and pop-ups ----------
## Clears and shows the full-window menu screen; returns its content box. Esc runs `back`.
func show_screen(back := Callable()) -> VBoxContainer:
	close_modal()
	hide_tip()
	Kit.clear(screen_body)
	screen.visible = true
	screen_back = back
	screen_scroll.scroll_vertical = 0
	return screen_body


func hide_screen() -> void:
	screen.visible = false
	screen_back = Callable()


## Clears and shows a pop-up window; returns its content box. Esc runs `esc` (if any).
func open_modal(width := 640.0, esc := Callable()) -> VBoxContainer:
	hide_tip()
	Kit.clear(modal_body)
	modal_layer.visible = true
	modal_esc = esc
	settings_open = false
	modal_box.custom_minimum_size = Vector2(width, 0)
	(modal_box.get_node("Scroll") as ScrollContainer).custom_minimum_size = Vector2.ZERO
	_fit_modal.call_deferred()
	return modal_body


## Sizes the pop-up to its content, up to the window height (then it scrolls). Wrapped text only knows its
## height once it has a width, so this measures again after the layout has run.
func _fit_modal() -> void:
	var sc: ScrollContainer = modal_box.get_node("Scroll")
	sc.scroll_vertical = 0
	if sc.custom_minimum_size.y == 0:
		modal_box.modulate.a = 0 # hidden until measured, so it doesn't flash at the wrong size
	for i in 2:
		await get_tree().process_frame
		if not modal_layer.visible:
			return
		var want := modal_body.get_combined_minimum_size().y
		sc.custom_minimum_size = Vector2(0, minf(want, get_viewport_rect().size.y - 72))
	modal_box.modulate.a = 1


func refit_modal() -> void:
	_fit_modal.call_deferred()


func close_modal() -> void:
	modal_layer.visible = false
	modal_esc = Callable()
	settings_open = false


func modal_open() -> bool:
	return modal_layer.visible


func toast(msg: String) -> void:
	if toast_label.text != msg or not toast_box.visible:
		toast_label.text = msg
		toast_box.visible = true
	toast_t = 3.0


func show_tip(bb: String, rect: Rect2, where := "below") -> void:
	tip_label.text = bb
	tip.visible = true
	tip.size = Vector2(300, 0)
	tip.reset_size()
	await get_tree().process_frame
	if not tip.visible:
		return
	var ts := tip.size
	var vs := get_viewport_rect().size
	var x := rect.position.x + rect.size.x / 2 - ts.x / 2
	var y := rect.position.y - ts.y - 8 if where == "above" else rect.end.y + 12
	if y < 8:
		y = rect.end.y + 12
	tip.position = Vector2(clampf(x, 8, vs.x - ts.x - 8), clampf(y, 8, vs.y - ts.y - 8))


func hide_tip() -> void:
	tip.visible = false


# ---------- per frame ----------
func tick(dt: float) -> void:
	if toast_t > 0:
		toast_t -= dt
		if toast_t <= 0:
			toast_box.visible = false
	if game.S and game.S.hero:
		var held := {}
		for k in held_keys:
			held[MOVE_KEYS[k]] = true
		game.held = held
	hud_t -= dt
	if hud_t <= 0:
		hud_t = 0.1
		update_hud()


func update_hud() -> void:
	var S := game.S
	var h: Hero = S.hero if S else null
	if h == null:
		boss_bar.visible = false
		mode_banner.visible = false
		_veil(false)
		return
	if S.over:
		_veil(false)
	_mode_timer()
	var boss: Enemy = null
	for e: Enemy in S.enemies:
		if not e.dead and e.boss and (boss == null or e.max > boss.max):
			boss = e
	boss_bar.visible = boss != null
	if boss:
		boss_name.text = DB.enemies[boss.type].name + (" · if it reaches your base, the run is lost" if Game.BIG_BOSS.has(boss.type) else " · costs %d base HP if it gets through" % DB.enemies[boss.type].lives)
		boss_fill.frac = maxf(0, boss.hp) / boss.max
		var danger := Game.BIG_BOSS.has(boss.type) and boss.d / S.map.path_len >= 0.75
		boss_warn.visible = danger
		if danger:
			boss_warn.modulate.a = 0.6 + 0.4 * sin(S.time * 12)
		boss_bar.offset_top = 110 if mode_banner.visible else 48
	top_map.text = S.map.scene.map_name
	top_wave.text = "%d/%d" % [S.wave, game.max_wave]
	top_lives.text = str(S.lives)
	top_gold.text = str(int(floor(S.gold)))
	top_lvl.text = ("KO %ds" % ceili(h.ko)) if h.ko > 0 else "Lv %d" % h.lvl
	hp_meter.frac = h.hp / h.max_hp
	hp_meter.over = h.shield / h.max_hp if h.shield > 0 else 0.0
	hp_meter.text = hp_text(h)
	xp_meter.frac = h.xp / h.next
	ability_meter()
	if floori(S.gold) != floori(last_bar_gold):
		render_build_bar()
	if S.sel != null and floori(S.gold) != floori(last_insp_gold) and S.merge_from == null:
		render_inspector()
	hero_t -= 1
	if hero_t <= 0:
		hero_t = 3
		render_hero()


## "350/420" plus the shield when there is one: "350/420 + 90 shield".
func hp_text(h: Hero) -> String:
	var s := "%d/%d" % [ceili(maxf(0, h.hp)), roundi(h.max_hp)]
	if h.shield > 0:
		s += "  +%d shield" % ceili(h.shield)
	return s


func _veil(on: bool) -> void:
	pause_veil.visible = on
	pause_veil.get_meta("veil").visible = on


func _on_changed(what: String) -> void:
	if game.S == null or game.S.hero == null:
		return
	match what:
		"build_bar": render_build_bar()
		"inspector": render_inspector()
		"hero": render_hero()
		"codex": render_codex()
		"enemy_codex": render_enemy_codex()
		"mode": render_mode_banner()
		"runes": render_runes()


# ---------- in-run panels ----------
func render_build_bar() -> void:
	var S := game.S
	if S == null or S.hero == null:
		return
	Kit.clear(build_bar)
	rune_btns.clear()
	ability_btn = null
	rune_cast = null
	mana_meter = null
	wall_meter = null
	var mode_tag: String = (" · " + S.mode.name) if S.mode.kind != "normal" else ""
	for i in S.loadout.size():
		var k: String = S.loadout[i]
		var d: TowerData = DB.towers[k]
		var cost := game.tower_cost(k)
		var bt := Button.new()
		bt.focus_mode = Control.FOCUS_NONE
		bt.theme_type_variation = "OnButton" if S.build == k else ""
		bt.disabled = S.gold < cost
		var h := Kit.hbox(8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw := ColorRect.new()
		sw.color = d.color
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var txt := Kit.rich("%s  %s  %s" % [d.name, Kit.c(cost, Kit.GOLD if S.build != k else Color.WHITE), Kit.c(i + 1, Kit.MUTED)], 14)
		txt.add_theme_font_override("normal_font", Kit.display)
		txt.autowrap_mode = TextServer.AUTOWRAP_OFF
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(txt)
		_ignore_mouse(h)
		bt.add_child(h)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.offset_right = -14
		bt.custom_minimum_size = Vector2(txt.get_content_width() + 18 + 12 + 8 + 18 + 14, 34)
		bt.pressed.connect(game.select_build.bind(k))
		Kit.tip_on(bt, func(): return UiText.build_tip(game, k), "above")
		build_bar.add_child(bt)
		_fit_bar_button.call_deferred(bt, txt)
	if S.hero.data.spells:
		_rune_bar()
	else:
		ability_btn = Kit.button(("Fire %s  Q" if S.strike_ready else "%s  Q") % S.hero.ab.name, func(): game.use_ability(), "OnButton" if S.strike_ready else "")
		ability_fill = ColorRect.new()
		ability_fill.color = Color(0.69, 0.49, 1, 0.45)
		ability_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ability_fill.show_behind_parent = false
		ability_btn.add_child(ability_fill)
		ability_btn.move_child(ability_fill, 0)
		Kit.tip_on(ability_btn, func(): return UiText.ability_tip(game, S.hero), "above")
		build_bar.add_child(ability_btn)
	if game.can_hold():
		var hb := Kit.button(("Holding" if S.hero.hold else "Hold") + "  H", game.toggle_hold, "OnButton" if S.hero.hold else "")
		Kit.tip_on(hb, func(): return Kit.b("Hold position") + "  " + Kit.c("H", Kit.GOLD) + "\n" + Kit.c("Locks your hero in place so right-clicks, movement keys and taps don’t move it. Press H again to move.", Kit.MUTED), "above")
		build_bar.add_child(hb)
	if S.hero.cls == "sniper" and game.pierce_cursor():
		var cb := Kit.button("Aim: cursor", func(): toast("Piercing Shot follows your cursor. Switch to aim points in Settings."))
		build_bar.add_child(cb)
	elif S.hero.cls == "sniper":
		var ab := Kit.button(("Aim set" if S.aim != null else "Aim") + "  F", func():
			if S.aim != null:
				S.aim = null
				toast("Aim point cleared.")
				render_build_bar()
			else:
				toast("Point at the board and press F to set an aim point."), "OnButton" if S.aim != null else "")
		Kit.tip_on(ab, func(): return Kit.b("Aim point") + "  " + Kit.c("F", Kit.GOLD) + "\n" + Kit.c("Point at the board and press F: Piercing Shot always fires from your Sniper toward that spot, wherever it stands. Press F on the point (or click this button) to clear it.", Kit.MUTED), "above")
		build_bar.add_child(ab)
	Kit.clear(corner_bar)
	var wl := Kit.label("WAVE %d/%d%s" % [S.wave, game.max_wave, mode_tag.to_upper()], 13, Kit.TEXT, Kit.display)
	wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corner_bar.add_child(wl)
	corner_bar.add_child(Kit.button(("Resume" if S.user_pause else "Pause") + "  P", game.toggle_pause, "OnButton" if S.user_pause else ""))
	corner_bar.add_child(Kit.button("%d×" % S.speed, func():
		S.speed = 1 if S.speed == 3 else S.speed + 1
		render_build_bar()))
	var wave_txt: String = "Wave running" if S.wave_active else ("Start wave %d  Space" % (S.wave + 1))
	var wb := Kit.go(wave_txt, game.start_wave)
	wb.disabled = S.wave_active or S.over
	corner_bar.add_child(wb)
	_veil(S.user_pause and not S.over)
	ability_meter()
	render_runes()
	last_bar_gold = S.gold


func _fit_bar_button(bt: Button, txt: RichTextLabel) -> void:
	if is_instance_valid(bt) and is_instance_valid(txt):
		bt.custom_minimum_size.x = txt.get_content_width() + 18 + 12 + 8 + 18 + 4


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore_mouse(ch)


func _rune_bar() -> void:
	var S := game.S
	var box := Kit.hbox(4)
	# in the tree first, so the buttons pick up the FlatButton style from the UI theme
	build_bar.add_child(box)
	for k in S.rune_keys:
		var el: ElementData = DB.elements[S.rune_keys[k]]
		var bt := Kit.button("%s  %s" % [el.name, k.to_upper()], game.ready_rune.bind(k), "FlatButton")
		box.add_child(bt)
		var sb: StyleBoxFlat = bt.get_theme_stylebox("normal").duplicate()
		sb.border_color = el.color
		bt.add_theme_stylebox_override("normal", sb)
		var sbh: StyleBoxFlat = sb.duplicate()
		sbh.bg_color = Kit.PANEL2
		bt.add_theme_stylebox_override("hover", sbh)
		bt.add_theme_color_override("font_color", el.color)
		bt.add_theme_color_override("font_hover_color", el.color.lightened(0.2))
		var cd := ColorRect.new()
		cd.color = el.color
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.anchor_top = 1
		cd.anchor_bottom = 1
		cd.offset_top = -3
		bt.add_child(cd)
		bt.set_meta("cd", cd)
		bt.set_meta("el", S.rune_keys[k])
		rune_btns[k] = bt
	var tip_fn := func() -> String:
		var r = game.resolve_runes(S.runes)
		var t := Kit.b("Runes") + "\n"
		if r:
			t += Kit.b(r.spell.name) + ": " + Kit.c(Progress.spell_desc(r.key, S.hero, game.spell_pow(S.hero), game.wave_no()), Kit.MUTED)
		else:
			t += Kit.c(UiText.ability_text(game, S.hero), Kit.MUTED)
		return t + "\n" + Kit.c("Mana %d/%d · +%s/s" % [floori(S.hero.mana), roundi(S.hero.max_mana), UiText.f1(S.hero.mana_regen)], Kit.MUTED)
	Kit.tip_on(box, tip_fn, "above")
	rune_cast = Kit.rich("", 13)
	rune_cast.autowrap_mode = TextServer.AUTOWRAP_OFF
	rune_cast.custom_minimum_size = Vector2(170, 0)
	rune_cast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(rune_cast)
	mana_meter = Kit.meter(0, Color("#5fa8ff"))
	mana_meter.custom_minimum_size = Vector2(70, 6)
	mana_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(mana_meter)
	if S.hero.can.get("wall", false):
		# wall charges: "Walls 3/5", the bar fills as the next charge comes back
		wall_meter = Kit.meter(0, Color("#c8a46a"))
		wall_meter.custom_minimum_size = Vector2(84, 16)
		wall_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Kit.tip_on(wall_meter, func(): return Kit.b("Wall charges") + "\n" + Kit.c("Each wall spell uses a charge (plus its mana). Up to %d; one comes back every %ss during a wave." % [DB.rules.wall_charges, UiText.f1(game.wall_recharge_time(S.hero))], Kit.MUTED), "above")
		box.add_child(wall_meter)


func render_runes() -> void:
	var S := game.S
	if rune_cast == null or not is_instance_valid(rune_cast) or S == null or S.hero == null:
		return
	var r = game.resolve_runes(S.runes)
	var dots := ""
	for x in S.runes:
		dots += Kit.c("●", DB.elements[x].color) + " "
	if r:
		rune_cast.text = dots + Kit.b(r.spell.name) + " " + Kit.c("%d mana · left-click" % ceili(r.mana * S.hero.spell_cost), Kit.MUTED)
	else:
		rune_cast.text = dots + Kit.c("Ready runes with " + " ".join(S.rune_keys.keys()).to_upper(), Kit.MUTED)


## The ability button empties when used and refills as the cooldown runs down; resting runes dim.
func ability_meter() -> void:
	var S := game.S
	if S == null or S.hero == null:
		return
	var h := S.hero
	if mana_meter and is_instance_valid(mana_meter) and h.max_mana:
		mana_meter.frac = h.mana / h.max_mana
	if wall_meter and is_instance_valid(wall_meter):
		var full := h.wall_charges >= DB.rules.wall_charges
		wall_meter.frac = 1.0 if full else h.wall_t / game.wall_recharge_time(h)
		wall_meter.text = "Walls %d/%d" % [h.wall_charges, DB.rules.wall_charges]
	for k in rune_btns:
		var bt: Button = rune_btns[k]
		if not is_instance_valid(bt):
			continue
		var left: float = S.el_cd.get(bt.get_meta("el"), 0.0) - S.time
		bt.modulate.a = 0.45 if left > 0 else 1.0
		var cd: ColorRect = bt.get_meta("cd")
		cd.visible = left > 0
		cd.anchor_right = 1 - left / DB.rules.element_rest if left > 0 else 1.0
	if ability_btn and is_instance_valid(ability_btn) and ability_fill:
		var a := h.ab
		var fill := (1 - a.t / a.cd) if a.t > 0 and a.cd > 0 else 1.0
		ability_fill.position = Vector2(14, 5)
		ability_fill.size = Vector2(maxf(0, (ability_btn.size.x - 28) * fill), ability_btn.size.y - 10)
		ability_fill.visible = a.t > 0


func render_inspector() -> void:
	var S := game.S
	if S == null or S.hero == null:
		return
	Kit.clear(inspector)
	var v := Kit.vbox(6)
	inspector.add_child(v)
	var t: Tower = S.sel
	if t == null or not S.towers.has(t):
		S.sel = null
		if S.build != "":
			v.add_child(Kit.h3("Placing"))
			v.add_child(Kit.rich(UiText.build_tip(game, S.build), 13))
			v.add_child(Kit.muted("Left-click a tile to build. Right-click or press R to cancel."))
			return
		v.add_child(Kit.h3("Tower"))
		v.add_child(Kit.muted("Hover a tower to see what it does. Pick one, then left-click a free tile. If it's out of reach, your hero walks over and builds it.", 14))
		v.add_child(Kit.muted(("Towers level up to %d. Each level adds a point to one of 5 paths. A tower uses 3 paths of 4 points (with the Oracle, 4 paths of 3 bigger points). A path's last point unlocks its mastery, and at level %d the tower ascends into a form named after its paths. "
			+ "Two different level %d towers merge into a hybrid (merging costs %d gold), and two level %d hybrids merge into a super tower (%s gold) with signature powers.") % [DB.rules.max_level, DB.rules.max_level, DB.rules.max_level,
			DB.rules.merge_cost, DB.rules.max_level, _thousands(DB.rules.super_cost)], 14))
		return
	var R := game.R
	var sell := game.sell_value(t)
	var opts := game.tower_options(t)
	var can_merge := t.lvl >= R.max_level and not t.is_super
	var lim := game.path_limit()
	v.add_child(Kit.h3("%s · %sLv %d/%d" % [game.tower_name(t), game.tower_kind(t), t.lvl, R.max_level], t.color))
	var blurb := game.tower_blurb(t)
	if t.hybrid:
		blurb += " Contains " + " + ".join(Array(t.parents).map(func(p): return DB.towers[p].name)) + "."
	v.add_child(Kit.muted(blurb, 14))
	if t.stun_t > 0:
		v.add_child(Kit.rich(Kit.c("Stunned by a boss: %ss left." % UiText.f1(t.stun_t), Kit.DANGER), 14))
	var rows := []
	if t.hero_buff:
		rows.append(["Hero damage", "+" + UiText.pct(t.hb_dmg)])
		rows.append(["Hero armor", "+" + UiText.pct(t.hb_armor)])
	elif t.support:
		rows.append(["Buff", "+" + UiText.pct(t.b_dmg)])
	else:
		rows.append(["Damage", UiText.dmg_with_buff(game, t)])
		rows.append(["Slams/s" if t.type == "anvil" else "Shots/s", UiText.f2(1 / (t.rate * S.mod_tower_rate))])
	rows += ([] if t.hero_buff else [["Range", UiText.f0(game.t_range(t))]]) + [["Spent", str(t.spent)], ["Kills", str(t.kills)], ["Takedowns", str(t.takedowns)]]
	v.add_child(Kit.stats(rows))
	if not t.support and not t.hero_buff and t.type != "anvil":
		v.add_child(_aim_row(t.aim, func(a: String): game.set_aim(t, a)))
	if not DB.is_simple():
		v.add_child(Kit.rich(UiText.bullets(UiText.tower_traits(game, t)), 13))
	if S.merge_from == t:
		v.add_child(Kit.muted("Tap another level %d %s to merge with. Tap anywhere else to cancel." % [R.max_level, "hybrid" if t.hybrid else "tower of a different type"], 14))
	if t.lvl < R.max_level:
		var note := "Paths used: %d/%d" % [t.order.size(), lim]
		if not t.hybrid and t.order.size() == 2:
			note += " · A 3rd path gives it a new name"
		if t.free_ups:
			note += " · %d free level-up%s" % [t.free_ups, "s" if t.free_ups > 1 else ""]
		note += ". Each level: %s Level %d %s: %s" % [game.level_text(t), R.max_level, "perfects it" if t.hybrid else "ascends it into its final form", game.ascend_text(t)]
		v.add_child(Kit.muted(note))
	else:
		var note := "Max level."
		if can_merge:
			note += " Merge it with another level %d %s." % [R.max_level, "hybrid to make a super tower" if t.hybrid else "tower of a different type to make a hybrid"]
		v.add_child(Kit.muted(note))
	var ups := Kit.vbox(6)
	for o in opts:
		var state := game.path_state(t, o)
		if state == "locked":
			continue
		var n := t.ups_of(o.id)
		var lc := game.level_cost(t, o)
		var open := state == "open" and t.lvl < R.max_level
		var ch := Choice.new(Kit.GOLD if state == "maxed" else Kit.LINE)
		ch.pad = 9
		ch.add(Kit.rich(Kit.c(o.name, Kit.GOLD if state == "maxed" else Kit.TECH) + "  " + Kit.c("%d/%d" % [n, game.path_max()], Kit.MUTED), 14))
		ch.add("Maxed." if state == "maxed" else game.path_desc(o), 12)
		if open and not DB.is_simple():
			ch.add(Kit.c(UiText.preview_level(game, t, o), Kit.OK), 12)
		if o.path and o.path.mastery_name != "":
			var mn: String = ("★ Mastered: " if n >= game.path_max() else "Mastery at %d: " % game.path_max()) + o.path.mastery_name + ". " + DB.tx("mastery:" + t.type + ":" + o.id, o.path.mastery_desc)
			ch.add(Kit.c(mn, Kit.ARCANE), 11)
		if open:
			var price := Kit.rich(Kit.c(("%d gold" % lc) if lc else "Free", Kit.GOLD), 12)
			price.autowrap_mode = TextServer.AUTOWRAP_OFF
			price.size_flags_horizontal = Control.SIZE_SHRINK_END
			ch.add(price)
		ch.disabled = S.gold < lc or not open
		ch.pressed.connect(game.level_tower.bind(t, o))
		ups.add_child(ch)
	v.add_child(ups)
	var row := Kit.hbox(6)
	if can_merge:
		var mb := Kit.button("%s · %d" % ["Super merge" if t.hybrid else "Merge", game.merge_cost(t)], func():
			S.merge_from = t
			render_inspector()
			toast(("Pick another level %d hybrid." if t.hybrid else "Pick a level %d tower of another type.") % R.max_level))
		mb.disabled = S.gold < game.merge_cost(t)
		row.add_child(mb)
	row.add_child(Kit.button("Sell · +%d  R" % sell, game.sell_selected))
	v.add_child(row)
	last_insp_gold = S.gold
	_merge_tip()


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Once two maxed towers on the field could merge, explain merging (once ever).
func _merge_tip() -> void:
	var S := game.S
	if Save.meta.tips.get("merge", false):
		return
	var done := S.towers.filter(func(t): return t.lvl >= game.R.max_level and not t.is_super)
	for i in done.size():
		for j in range(i + 1, done.size()):
			if game.merge_problem(done[i], done[j]) == "":
				menus.first_tip.call_deferred("merge")
				return


func render_codex() -> void:
	Kit.clear(codex_box)
	var head := Kit.button(("▾ " if codex_open else "▸ ") + "MERGE CODEX AND CONTROLS", func():
		codex_open = not codex_open
		render_codex(), "FlatButton")
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	codex_box.add_child(head)
	if not codex_open:
		return
	for r: RecipeData in game.R.recipes.items:
		var p := r.key.split("+")
		var h := Kit.hbox(10)
		if Save.codex.get(r.key, false):
			h.add_child(Kit.label(r.name, 14, Kit.TECH))
			h.add_child(Kit.spacer())
			h.add_child(Kit.label("%s + %s" % [DB.towers[p[0]].name, DB.towers[p[1]].name], 13, Kit.MUTED))
			h.tooltip_text = r.desc
		else:
			h.add_child(Kit.label("???", 14))
			h.add_child(Kit.spacer())
			h.add_child(Kit.label("Undiscovered", 13, Kit.MUTED))
		codex_box.add_child(h)
	codex_box.add_child(Kit.muted("Right-click to move the hero, or use WASD / arrows when movement keys are on. Stand on the path to block enemies. Left-click to build and select. 1–5 pick a tower, R cancel placing or sell the selected tower, Q hero ability, H hold position (Vanguard, Sniper), F Sniper aim point, T change the selected tower’s target, Space start wave, Esc settings."))


func render_enemy_codex() -> void:
	Kit.clear(enemy_box)
	var head := Kit.button(("▾ " if enemies_open else "▸ ") + "ENEMIES", func():
		enemies_open = not enemies_open
		render_enemy_codex(), "FlatButton")
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	enemy_box.add_child(head)
	if not enemies_open:
		return
	for e: EnemyData in game.R.enemies:
		if Save.meta.seen.get(e.id, false):
			enemy_box.add_child(Kit.rich(Kit.b(Kit.c(e.name, e.color)) + "  " + Kit.c(DB.tx("enemy:" + e.id, e.info) + (" Can’t be pushed back." if e.pushback_immune or e.boss else ""), Kit.MUTED) + "\n" + Kit.c("Counter: " + e.counter, Kit.GOLD), 13))
		else:
			enemy_box.add_child(Kit.rich("???  " + Kit.c("Not met yet", Kit.MUTED), 13))


## The targeting buttons (First, Last, Strongest, Closest) for a tower or the Sniper; `pick` gets the choice.
func _aim_row(current: String, pick: Callable) -> Control:
	var aims := Kit.flow(4)
	aims.add_child(Kit.label("Target  T", 12, Kit.MUTED))
	for a in Game.AIMS:
		var ab := Kit.button(Game.AIM_NAMES[a], func(): pick.call(a), "OnButton" if current == a else "")
		ab.add_theme_font_size_override("font_size", 12)
		# the hero card and inspector rebuild often during a wave, so act on the press, not the release
		ab.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		Kit.tip_on(ab, func(): return { first = "The enemy farthest along the path.", last = "The enemy nearest the entrance.", strong = "The enemy with the most HP.",
			close = "The nearest enemy." }[a])
		aims.add_child(ab)
	return aims


func render_hero() -> void:
	var S := game.S
	if S == null or S.hero == null:
		return
	var h := S.hero
	var d := h.data
	Kit.clear(hero_card)
	var v := Kit.vbox(6)
	hero_card.add_child(v)
	v.add_child(Kit.h3("%s · %s · Lv %d%s" % [d.name, d.role, h.lvl, " · Knocked out" if h.ko > 0 else ""], d.color))
	var ab_line := ""
	if d.spells:
		ab_line = Kit.b(Kit.c("Spellcraft", Kit.TEXT)) + ": " + UiText.ability_text(game, h)
	else:
		ab_line = Kit.b(Kit.c(h.ab.name, Kit.TEXT)) + (" (%ss)" % UiText.f0(h.ab.cd) if h.ab.cd else "") + ": " + UiText.ability_text(game, h)
		var mods := UiText.mods_of(h)
		if mods.size():
			ab_line += "\n" + Kit.c("Upgrades:", Kit.PINK) + " " + ", ".join(mods.map(func(m): return m.name))
	if h.hold:
		ab_line += "\n" + Kit.c("Holding position (H)", Kit.GOLD)
	var abl := Kit.muted(ab_line)
	Kit.tip_on(abl, func(): return UiText.ability_tip(game, h))
	v.add_child(abl)
	if h.cls == "sniper":
		v.add_child(_aim_row(h.target, game.set_hero_aim))
	var f := func(x: float) -> String: return UiText.f0(x)
	var rows := [["Damage", f.call(game.hero_dmg())], ["Kills", str(S.kills.hero)], ["Takedowns", str(S.takedowns.hero)]]
	if d.category == "defensive":
		rows.append(["Damage blocked", f.call(S.blocked)])
	elif d.category == "support":
		rows.append(["Assisted kills", str(S.assists)])
	if h.max_mana:
		rows += [["Mana", "%d/%s" % [floori(h.mana), f.call(h.max_mana)]], ["Mana/s", UiText.f1(h.mana_regen)], ["Spell damage", UiText.pct(game.spell_pow(h))], ["Spell cost", UiText.pct(h.spell_cost)],
			["Triple runes", ", ".join(Array(S.triples).map(func(e): return DB.elements[e].name)) if S.triples.size() else "None"]]
	else:
		rows += [["Attacks/s", UiText.f2(1 / h.rate)], ["Range", "Whole map" if h.range >= 9999 else f.call(h.range)], ["Bounces", str(int(h.bounce))], ["Crit chance", UiText.pct(h.crit)],
			["Crit damage", UiText.pct(h.crit_dmg)]]
	if h.brace:
		rows.append(["Brace", UiText.f2(h.brace) + "s"])
	rows += [["Armor", UiText.pct(h.armor)], ["Blocks", UiText.block_text(h.block)], ["Regen/s", UiText.f1(h.regen)], ["Respawn", UiText.f1(h.respawn) + "s"],
		["Build range", f.call(h.build_range)], ["Move speed", f.call(h.speed)]]
	if h.aura: rows.append(["Tower aura", "+" + UiText.pct(h.aura)])
	if h.bounty: rows.append(["Hero kill gold", "+" + UiText.pct(h.bounty)])
	if h.tithe: rows.append(["Kill gold (all)", "+" + UiText.pct(h.tithe)])
	if h.mom_stacks: rows.append(["Momentum", "%d×" % h.mom_stacks])
	if h.interest: rows.append(["Interest", UiText.pct(h.interest)])
	# the full stat sheet folds away (remembered between runs)
	var open := bool(Save.settings.get("hero_stats_open", true))
	var fold := Kit.button(("▾ " if open else "▸ ") + "Hero stats", func():
		Save.settings.hero_stats_open = not bool(Save.settings.get("hero_stats_open", true))
		Save.save_settings()
		render_hero(), "FlatButton")
	fold.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(fold)
	var sheet := Kit.vbox(6)
	sheet.visible = open
	v.add_child(sheet)
	sheet.add_child(Kit.stats(rows))
	var lv := "%s (%d level%s so far): %s" % [Kit.b(Kit.c("Level bonus", Kit.GOLD)), h.lvl - 1, "" if h.lvl == 2 else "s", DB.tx("role:" + d.category, UiText.ROLE_LEVEL.get(d.category, "none") + " per level.")]
	if h.xp_gain:
		lv += " XP gain +%s." % UiText.pct(h.xp_gain)
	sheet.add_child(Kit.muted(lv))
	var tags := Kit.flow(4)
	for x: UpgradeData in game.R.heroics.items:
		var r: int = S.heroics.get(x.id, 0)
		if r:
			var tg := Kit.tag(Kit.c("%s %s" % [x.name, "I".repeat(r)], Kit.HEROIC), Kit.HEROIC)
			Kit.tip_on(tg, func(): return DB.tx("heroic:" + x.id, game.heroic_desc(x, r)))
			tags.add_child(tg)
	for k in S.boons:
		var rec: RecipeData = DB.recipes[k]
		var tg := Kit.tag(Kit.c("✦ " + rec.boon_name, Kit.HEROIC), Kit.HEROIC)
		Kit.tip_on(tg, func(): return DB.tx("boon:" + k, rec.boon_desc))
		tags.add_child(tg)
	# the same upgrade picked again stacks into one tag (Fast Chambers ×6), coloured by its rarest copy
	var stacks := {}
	var order := []
	for o in S.picks:
		var key: String = o.perk.id + ("!" if o.demonic else "")
		if not stacks.has(key):
			stacks[key] = []
			order.append(key)
		stacks[key].append(o)
	var rank_of := func(o) -> int: return Kit.RAR.keys().find(o.rarity.id)
	for key in order:
		var list: Array = stacks[key]
		var top: Dictionary = list[0]
		for o in list:
			if rank_of.call(o) > rank_of.call(top):
				top = o
		var col: Color = Kit.RAR.get(top.rarity.id, Kit.TEXT)
		var label: String = ("☠ " if top.demonic else "") + top.perk.name + (" ×%d" % list.size() if list.size() > 1 else "")
		var tg := Kit.tag(Kit.c(label, Kit.TEXT if top.rarity.id == "common" else col), Kit.DANGER if top.demonic else (Kit.LINE if top.rarity.id == "common" else col), Color("#2a1220") if top.demonic else Kit.PANEL2)
		Kit.tip_on(tg, func(): return "\n".join(list.map(func(o): return (o.rarity.name + ": " if list.size() > 1 else "") + game.perk_desc(o) + ((" Curse: " + game.curse_desc(o)) if o.demonic else ""))))
		tags.add_child(tg)
	for r: UpgradeData in S.relics:
		var tg := Kit.tag(Kit.c(r.name, Kit.GOLD), Kit.GOLD)
		Kit.tip_on(tg, func(): return game.relic_desc(r))
		tags.add_child(tg)
	if tags.get_child_count() == 0:
		v.add_child(Kit.muted("No upgrades yet. Kill enemies to level up."))
	else:
		v.add_child(tags)


## Top-middle reminder of the chosen Hard or Challenge wave: its goal and every buff or handicap.
func render_mode_banner() -> void:
	var S := game.S
	var m = S.mode if S and S.hero else null
	var on: bool = m != null and m.kind != "normal" and not S.over
	mode_banner.visible = on
	mode_timer = null
	if not on:
		return
	var border: Color = { hard = Color("#ff9f43"), challenge = Color("#c77dff"), legendary = Color("#c77dff"), secret = Color("#c77dff") }.get(m.kind, Kit.LINE)
	var title: Color = { hard = Color("#ffb36b"), challenge = Color("#d9a8ff"), legendary = Color("#ffb84d"), secret = Kit.GOLD }.get(m.kind, Kit.TEXT)
	mode_banner.add_theme_stylebox_override("panel", Kit.box_style(Color(0.043, 0.059, 0.11, 0.88), border, 1, 6, 6))
	Kit.clear(mode_banner)
	var v := Kit.vbox(2)
	mode_banner.add_child(v)
	var t := Kit.label(m.name + ("" if S.wave_active else " · next wave"), 13, title, Kit.display)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if m.get("req", "") != "":
		var q: UpgradeData = game.R.requirements.find(m.req)
		var hb := Kit.hbox(6)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		var g := Kit.label(("✗ Failed: " if S.req_failed else "Goal: ") + DB.tx("req:" + q.id, q.desc), 12, Kit.DANGER if S.req_failed else Color.WHITE)
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(g)
		if m.req == "timed":
			mode_timer = Kit.label("", 12, Kit.GOLD)
			hb.add_child(mode_timer)
		v.add_child(hb)
	var mods := []
	for l in game.mode_lines(m):
		if l.k != "req":
			mods.append(l.name)
	var ml := Kit.label("   ".join(mods), 12, Kit.MUTED)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.tooltip_text = "\n".join(game.mode_lines(m).map(func(l): return l.name + ": " + l.rule))
	ml.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(ml)
	_mode_timer()


func _mode_timer() -> void:
	var S := game.S
	if mode_timer == null or not is_instance_valid(mode_timer) or S == null:
		return
	var left := maxf(0, S.req_limit - (S.time - S.ws.start)) if S.wave_active and S.ws else 0.0
	mode_timer.text = ("%ds left" % ceili(left)) if S.wave_active else ""


func refresh_run_panels() -> void:
	render_build_bar()
	render_inspector()
	render_codex()
	render_enemy_codex()
	render_hero()
	render_mode_banner()


# ---------- keys ----------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey:
		_key(ev)


func _key(ev: InputEventKey) -> void:
	var S := game.S
	if not ev.pressed:
		held_keys.erase(ev.keycode)
		return
	if ev.keycode == KEY_ESCAPE:
		if _esc_back():
			get_viewport().set_input_as_handled()
		return
	if S == null or S.hero == null or modal_open() or screen.visible:
		return
	var k := ev.keycode
	get_viewport().set_input_as_handled()
	if k == KEY_P and not ev.echo:
		game.toggle_pause()
		return
	# the Wizard: Q W E R ready runes, and it never moves with the keyboard
	if S.hero.data.spells:
		var lk := OS.get_keycode_string(k).to_lower()
		if S.rune_keys.has(lk):
			if not ev.echo:
				game.ready_rune(lk)
			return
		if MOVE_KEYS.has(k):
			return
	if game.key_move and MOVE_KEYS.has(k):
		held_keys[k] = true
		return
	if k >= KEY_1 and k <= KEY_9:
		var i := k - KEY_1
		if i < S.loadout.size():
			game.select_build(S.loadout[i])
	elif k == KEY_R:
		if (not S.paused or S.user_pause) and not S.over and not game.cancel_placing():
			game.sell_selected()
	elif k == KEY_Q:
		game.use_ability()
	elif k == KEY_H:
		game.toggle_hold()
	elif k == KEY_F:
		game.toggle_aim()
	elif k == KEY_T:
		game.cycle_aim()
	elif k == KEY_SPACE:
		if not ev.echo:
			game.start_wave()


## Esc backs out one step: a pop-up's back/close button, then a menu screen's Back, then the in-run steps.
func _esc_back() -> bool:
	if settings_open:
		menus.close_settings()
		return true
	if modal_open():
		if modal_esc.is_valid():
			modal_esc.call()
		return true
	if screen.visible:
		if screen_back.is_valid():
			screen_back.call()
		return true
	if in_run():
		if not game.esc_step():
			menus.show_settings()
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held_keys.clear()
