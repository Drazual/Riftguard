## A clickable card: upgrade picks, map and hero choices, shop items, tower paths.
class_name Choice
extends PanelContainer

signal pressed

var body: VBoxContainer
var accent := Kit.LINE
var bg := Kit.PANEL
var glow := Color(0, 0, 0, 0)
var pad := 12
var disabled := false:
	set(v):
		disabled = v
		_style()
var picked := false:
	set(v):
		picked = v
		_style()
var _hover := false


func _init(acc := Kit.LINE, back := Kit.PANEL) -> void:
	accent = acc
	bg = back
	body = Kit.vbox(4)
	add_child(body)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_entered.connect(func():
		_hover = true
		_style())
	mouse_exited.connect(func():
		_hover = false
		_style())
	_style()


## Adds a line to the card (BBCode text or any control).
func add(x, size := 13, col := Kit.MUTED) -> Control:
	var n: Control = x if x is Control else Kit.rich(str(x), size, col)
	body.add_child(n)
	_ignore(n)
	return n


func _ignore(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in n.get_children():
		_ignore(ch)


## Path cards set meta "swatch" so the hover tip shows the same colour chip as the button.
func _make_custom_tooltip(for_text: String) -> Object:
	if not has_meta("swatch"):
		return null
	var box := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(16, 16)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.color = get_meta("swatch")
	row.add_child(chip)
	var lab := Label.new()
	lab.text = for_text
	row.add_child(lab)
	return box


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not disabled:
		accept_event()
		Sound.play("click")
		pressed.emit()


func _style() -> void:
	var border := accent
	if picked:
		border = Kit.TECH
	elif _hover and not disabled:
		border = Kit.TECH if accent == Kit.LINE else accent.lightened(0.25)
	var sb := Kit.box_style(bg if not picked else Kit.PANEL2, border, 2 if picked or accent != Kit.LINE else 1, 6, pad)
	if glow.a > 0:
		sb.shadow_color = glow
		sb.shadow_size = 10
	add_theme_stylebox_override("panel", sb)
	modulate.a = 0.45 if disabled else 1.0
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
