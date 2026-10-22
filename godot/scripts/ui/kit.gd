## Small helpers that build the menus and panels in code, in the look set by res://ui/theme.tres.
## Text uses BBCode ([b], [color=#hex]) so words can be coloured inside a sentence.
class_name Kit
extends RefCounted

const VOID := Color("#0b0f1c")
const PANEL := Color("#141a2e")
const PANEL2 := Color("#1c2440")
const LINE := Color("#2a3459")
const TEXT := Color("#e6e9f5")
const MUTED := Color("#8d95b8")
const ARCANE := Color("#b07cff")
const TECH := Color("#4fd8e8")
const GOLD := Color("#f2c14e")
const DANGER := Color("#ff5d6c")
const OK := Color("#5fe39a")
const HEROIC := Color("#ffb35d")
const PINK := Color("#ff6fd8")
const RAR := { common = Color("#aab2d4"), uncommon = Color("#5fe39a"), rare = Color("#5fa8ff"), mythic = Color("#ff6fd8"), legendary = Color("#f2c14e"),
	secret = Color("#b07cff"), secret_mythic = Color("#ff9cf0"), secret_legendary = Color("#ffe08a"), developer = Color("#4dffd2"), heroic = Color("#ffb35d") }

static var display: Font = preload("res://ui/display_font.tres")
static var display_bold: Font = preload("res://ui/display_bold_font.tres")


static func hexs(c: Color) -> String:
	return "#" + c.to_html(false)


## [color] BBCode.
static func c(text, col: Color) -> String:
	return "[color=%s]%s[/color]" % [hexs(col), str(text)]


static func b(text) -> String:
	return "[b]%s[/b]" % str(text)


## Display-font text (headings, numbers) inside BBCode.
static func d(text) -> String:
	return "[code]%s[/code]" % str(text)


static func esc(text: String) -> String:
	return text.replace("[", "[lb]")


static func pct(v: float) -> String:
	return str(int(round(v * 100))) + "%"


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func flow(sep := 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


static func label(text: String, size := 15, col := TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	return l


## A heading in the display font.
static func head(text: String, size := 22, col := TEXT) -> Label:
	return label(text, size, col, display_bold)


## A small upper-case section title, like the cards' h3.
static func h3(text: String, col := MUTED) -> Label:
	return label(text.to_upper(), 14, col, display)


## Wrapped rich text that grows to fit.
static func rich(bb: String, size := 15, col := TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("mono_font_size", size)
	r.add_theme_color_override("default_color", col)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.text = bb
	return r


static func muted(bb: String, size := 13) -> RichTextLabel:
	return rich(bb, size, MUTED)


static func button(text: String, cb: Callable, kind := "") -> Button:
	var bt := Button.new()
	bt.text = text
	if kind != "":
		bt.theme_type_variation = kind
	bt.focus_mode = Control.FOCUS_NONE
	bt.pressed.connect(cb)
	return bt


static func go(text: String, cb: Callable) -> Button:
	return button(text, cb, "GoButton")


static func card(pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	if pad != 12:
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel").duplicate()
		sb.set_content_margin_all(pad)
		p.add_theme_stylebox_override("panel", sb)
	return p


static func box_style(bg: Color, border: Color, w := 1, radius := 6, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


## Label/value rows, two to a line.
static func stats(rows: Array, cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 3)
	for r in rows:
		var h := hbox(8)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k := label(str(r[0]), 14, MUTED)
		h.add_child(k)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sp)
		var v := rich(str(r[1]), 14)
		v.fit_content = true
		v.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.size_flags_horizontal = Control.SIZE_SHRINK_END
		h.add_child(v)
		g.add_child(h)
	return g


static func tag(bb: String, border := LINE, bg := PANEL2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(bg, border, 1, 3, 3))
	var r := rich(bb, 12)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(r)
	return p


static func meter(frac: float, col: Color, h := 6.0) -> Meter:
	var m := Meter.new()
	m.frac = frac
	m.fill = col
	m.custom_minimum_size = Vector2(60, h)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return m


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


static func clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


## Shows a tooltip while the pointer is over the control. text_fn returns BBCode ("" for none).
static func tip_on(ctl: Control, text_fn: Callable, where := "below") -> void:
	ctl.mouse_entered.connect(func():
		var t: String = text_fn.call()
		if t != "" and Ui.me:
			Ui.me.show_tip(t, ctl.get_global_rect(), where))
	ctl.mouse_exited.connect(func():
		if Ui.me:
			Ui.me.hide_tip())


## A bar that fills from the left.
class Meter extends Control:
	var frac := 0.0:
		set(v):
			frac = v
			queue_redraw()
	var fill := Color.WHITE:
		set(v):
			fill = v
			queue_redraw()
	var back := PANEL2
	## A see-through second bar drawn over the fill (the hero's shield), as a share of the full width.
	var over := 0.0:
		set(v):
			over = v
			queue_redraw()
	var over_color := Color(0.37, 0.66, 1.0, 0.55)
	## Text drawn in the middle of the bar (empty for none).
	var text := "":
		set(v):
			if v != text:
				text = v
				queue_redraw()
	var font_size := 11

	func _draw() -> void:
		var r := minf(3, size.y / 2)
		draw_style_box(Kit.box_style(back, back, 0, int(r), 0), Rect2(Vector2.ZERO, size))
		var w := size.x * clampf(frac, 0, 1)
		if w > 0.5:
			draw_style_box(Kit.box_style(fill, fill, 0, int(r), 0), Rect2(0, 0, maxf(w, r * 2), size.y))
		var ow := size.x * clampf(over, 0, 1)
		if ow > 0.5:
			draw_style_box(Kit.box_style(over_color, over_color, 0, int(r), 0), Rect2(0, 0, maxf(ow, r * 2), size.y))
		if text != "":
			var f := Kit.display_bold
			var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var pos := Vector2((size.x - ts.x) / 2, (size.y + font_size * 0.72) / 2)
			draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0, 0, 0, 0.8))
			draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
