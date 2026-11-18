## The game opens on the main menu, and its buttons reach the map choice, Heroes and Towers, with Back returning
## to the menu. Prints START MENU PASS or FAIL.
## godot --headless --path godot res://tests/start_menu.tscn
## (with a screen: xvfb-run godot --path godot res://tests/start_menu.tscn -- <out.png> saves the menu)
extends Node

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): print("START MENU TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames()
	var ui: Ui = main.ui
	var menus: Menus = ui.menus
	_check(ui.screen.visible and not ui.in_run(), "opens on the main menu")
	_check(main.find_children("*", "HomeBase", true, false).is_empty(), "no walkable home base")
	var args := OS.get_cmdline_user_args()
	if args.size() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0])
	menus.show_map_select()
	await _frames()
	_check(ui.screen.visible, "PLAY opens the map choice")
	menus.back()
	await _frames()
	_check(ui.screen.visible and not ui.in_run(), "Back returns to the menu")
	menus.show_heroes()
	await _frames()
	_check(ui.screen.visible, "HEROES opens the Heroes page")
	ui._esc_back()
	await _frames()
	_check(ui.screen.visible and not ui.in_run(), "Esc on Heroes returns to the menu")
	menus.show_towers()
	await _frames()
	_check(ui.screen.visible, "TOWERS opens the Towers page")
	menus.back()
	await _frames()
	menus.new_run("canal")
	menus.start_run("vanguard", ["arcane", "plasma", "laser", "frost", "tesla", "mortar"])
	await _frames(5)
	_check(ui.in_run() and not ui.screen.visible, "a run starts from the menu")
	print("START MENU PASS" if fails == 0 else "START MENU FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
