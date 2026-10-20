extends SceneTree
# One-time generator: builds res://ui/theme.tres, the look of every menu, panel and button.
# After this, edit res://ui/theme.tres in the Godot editor (Theme editor) instead.

const VOID := Color("#0b0f1c")
const PANEL := Color("#141a2e")
const PANEL2 := Color("#1c2440")
const LINE := Color("#2a3459")
const TEXT := Color("#e6e9f5")
const MUTED := Color("#8d95b8")
const TECH := Color("#4fd8e8")
const ARCANE := Color("#b07cff")


func _init() -> void:
	var th := Theme.new()
	var body: FontFile = load("res://assets/fonts/Barlow-Regular.ttf")
	var semi: FontFile = load("res://assets/fonts/Barlow-SemiBold.ttf")
	var ox: FontFile = load("res://assets/fonts/Oxanium.ttf")
	var display := FontVariation.new()
	display.base_font = ox
	display.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 600 }
	ResourceSaver.save(display, "res://ui/display_font.tres")
	var display_bold := FontVariation.new()
	display_bold.base_font = ox
	display_bold.variation_opentype = { TextServerManager.get_primary_interface().name_to_tag("wght"): 700 }
	ResourceSaver.save(display_bold, "res://ui/display_bold_font.tres")
	display = load("res://ui/display_font.tres")
	display_bold = load("res://ui/display_bold_font.tres")
	th.default_font = body
	th.default_font_size = 15

	# pixel-frame buttons (9-slice), one image per state
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxTexture.new()
		var img := "pressed" if st == "pressed" else ("hover" if st == "hover" else ("disabled" if st == "disabled" else "normal"))
		sb.texture = load("res://assets/ui/btn_%s.png" % img)
		sb.texture_margin_left = 16
		sb.texture_margin_right = 16
		sb.texture_margin_top = 6
		sb.texture_margin_bottom = 6
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		sb.content_margin_top = 7
		sb.content_margin_bottom = 7
		th.set_stylebox(st, "Button", StyleBoxEmpty.new() if st == "focus" else sb)
	th.set_font("font", "Button", display)
	th.set_font_size("font_size", "Button", 14)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", TEXT)
	th.set_color("font_disabled_color", "Button", Color("#a58ad8"))
	th.set_constant("h_separation", "Button", 8)
	# the main action ("go") button: lit frame, glowing text
	th.add_type("GoButton")
	th.set_type_variation("GoButton", "Button")
	th.set_stylebox("normal", "GoButton", th.get_stylebox("hover", "Button"))
	th.set_stylebox("hover", "GoButton", th.get_stylebox("pressed", "Button"))
	th.set_color("font_color", "GoButton", Color.WHITE)
	th.set_color("font_outline_color", "GoButton", Color(0.2, 0.9, 0.95, 0.35))
	th.set_constant("outline_size", "GoButton", 3)
	th.set_font("font", "GoButton", display_bold)
	# toggled-on buttons (selected tower in the build bar, Pause while paused)
	th.add_type("OnButton")
	th.set_type_variation("OnButton", "Button")
	th.set_stylebox("normal", "OnButton", th.get_stylebox("pressed", "Button"))
	th.set_stylebox("hover", "OnButton", th.get_stylebox("pressed", "Button"))
	th.set_color("font_color", "OnButton", Color.WHITE)
	th.set_color("font_hover_color", "OnButton", Color.WHITE)
	# flat panel buttons (roster tabs, small links)
	th.add_type("FlatButton")
	th.set_type_variation("FlatButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := _box(PANEL if st != "hover" else PANEL2, TECH if st == "hover" else LINE, 1, 5)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		th.set_stylebox(st, "FlatButton", sb)
	th.set_stylebox("focus", "FlatButton", StyleBoxEmpty.new())

	# panels
	th.set_stylebox("panel", "PanelContainer", _box(PANEL, LINE, 1, 6, 12))
	th.add_type("Card")
	th.set_type_variation("Card", "PanelContainer")
	th.set_stylebox("panel", "Card", _box(PANEL, LINE, 1, 6, 12))
	th.add_type("Bar")
	th.set_type_variation("Bar", "PanelContainer")
	th.set_stylebox("panel", "Bar", _box(Color(0.078, 0.102, 0.18, 0.92), LINE, 1, 8, 6))
	th.add_type("TopBar")
	th.set_type_variation("TopBar", "PanelContainer")
	th.set_stylebox("panel", "TopBar", _box(Color(0.11, 0.14, 0.25, 0.92), LINE, 1, 8, 8))
	th.add_type("Modal")
	th.set_type_variation("Modal", "PanelContainer")
	th.set_stylebox("panel", "Modal", _box(PANEL, LINE, 1, 8, 20))
	th.add_type("Tip")
	th.set_type_variation("Tip", "PanelContainer")
	var tip := _box(Color(0.078, 0.102, 0.18, 0.97), LINE, 1, 6, 10)
	tip.shadow_color = Color(0, 0, 0, 0.4)
	tip.shadow_size = 12
	th.set_stylebox("panel", "Tip", tip)
	th.add_type("Toast")
	th.set_type_variation("Toast", "PanelContainer")
	var toast := _box(Color(0.043, 0.059, 0.11, 0.92), LINE, 1, 4, 8)
	toast.border_width_left = 3
	toast.border_color = LINE
	th.set_stylebox("panel", "Toast", toast)
	th.add_type("BoardFrame")
	th.set_type_variation("BoardFrame", "PanelContainer")
	var bf := _box(Color("#080b15"), LINE, 1, 8, 0)
	th.set_stylebox("panel", "BoardFrame", bf)

	# text
	th.set_color("font_color", "Label", TEXT)
	th.add_type("Muted")
	th.set_type_variation("Muted", "Label")
	th.set_color("font_color", "Muted", MUTED)
	th.set_font_size("font_size", "Muted", 13)
	th.add_type("H1")
	th.set_type_variation("H1", "Label")
	th.set_font("font", "H1", display_bold)
	th.set_font_size("font_size", "H1", 26)
	th.add_type("H3")
	th.set_type_variation("H3", "Label")
	th.set_font("font", "H3", display)
	th.set_font_size("font_size", "H3", 15)
	th.set_color("font_color", "H3", MUTED)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("normal_font", "RichTextLabel", body)
	th.set_font("bold_font", "RichTextLabel", semi)
	th.set_font("mono_font", "RichTextLabel", display)
	th.set_font_size("normal_font_size", "RichTextLabel", 15)
	th.set_font_size("bold_font_size", "RichTextLabel", 15)
	th.set_font_size("mono_font_size", "RichTextLabel", 15)
	th.set_constant("line_separation", "RichTextLabel", 2)

	# inputs
	for st in ["normal", "hover", "pressed", "disabled"]:
		th.set_stylebox(st, "OptionButton", _box(PANEL if st != "hover" else PANEL2, TECH if st == "hover" else LINE, 1, 5, 8))
	th.set_font("font", "OptionButton", body)
	th.set_stylebox("panel", "PopupMenu", _box(PANEL, LINE, 1, 4, 6))
	# a slider's track is as tall as its stylebox margins, so they need some height or only the knob shows
	var track := _box(PANEL2, LINE, 1, 3, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", track)
	var grab := _box(TECH, TECH, 0, 3, 0)
	grab.content_margin_top = 3
	grab.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", grab)
	th.set_stylebox("grabber_area_highlight", "HSlider", grab)
	var sc := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 3, 0)
	th.set_stylebox("scroll", "VScrollBar", sc)
	th.set_stylebox("grabber", "VScrollBar", _box(LINE, LINE, 0, 3, 0))
	th.set_stylebox("grabber_highlight", "VScrollBar", _box(MUTED, MUTED, 0, 3, 0))
	th.set_stylebox("grabber_pressed", "VScrollBar", _box(TECH, TECH, 0, 3, 0))
	th.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	th.set_color("font_color", "CheckBox", TEXT)
	ResourceSaver.save(th, "res://ui/theme.tres")
	quit()


func _box(bg: Color, border: Color, w: int, radius: int, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb
