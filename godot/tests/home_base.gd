## The start button and the home base (needs a display for the live hero):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/home_base.tscn -- <out dir>
## Checks: the game opens on a start screen; START leads into the base as the Striker (no hero played yet); walking
## moves the hero and buildings block it; each building's door opens its menu, whose Back and Esc return to the base;
## Esc in the base opens the main menu and Esc there comes back; a run hides the base.
extends Node

var out := "user://home_base"
var fails := 0
var main: Main
var ui: Ui
var home: HomeBase


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _esc() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ui._key(ev)
	await _frames(2)


## Walks the hero toward `to` (as a click would) until it gets there or is stopped.
func _walk(to: Vector2, max_s := 6.0) -> void:
	home.goal = to
	var until := Time.get_ticks_msec() + max_s * 1000
	while Time.get_ticks_msec() < until and home.goal != null and home.live():
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(240).timeout.connect(func(): print("HOME TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.meta.erase("loadout")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	ui = main.ui
	home = ui.home
	await _frames(5)
	_check(ui.screen.visible and not home.visible, "opens on the start screen")
	await _shot("0_start")
	ui.menus.go_home()
	await _frames(20)
	_check(home.visible and home.live() and not ui.screen.visible, "START leads into the home base")
	_check(home.hero_id == "striker" and home.hero != null, "walking as the Striker (%s)" % home.hero_id)
	await _shot("1_base")
	# walking: it moves, and a building stops it
	var f0 := home.feet
	home.goal = f0 + Vector2(-60, 0)
	await _frames(4)
	_check(home.hero.state == "walk" or home.hero.state == "run", "the hero walks (%s)" % home.hero.state)
	await _walk(f0 + Vector2(-60, 0), 2.0)
	_check(home.feet.x < f0.x - 55, "walks to where you click (%.0f -> %.0f)" % [f0.x, home.feet.x])
	# a building's wall: straight up into the hero building from beside its door, it stops short
	var hb: Vector2 = HomeBase.BUILDINGS[0].at
	home.feet = hb + Vector2(70, 20)
	home.inside = ""
	await _walk(hb + Vector2(-20, -30), 2.0)
	_check(home.blocks[0].has_point(home.feet) == false, "buildings block the way")
	# the hero building's door: the Heroes screen
	home.feet = HomeBase.START
	home.inside = ""
	await _walk(home.doors.heroes)
	_check(ui.screen.visible and ui.menus.hub, "the hero building opens the Heroes screen")
	await _shot("2_heroes")
	await _esc()
	_check(home.live() and not ui.screen.visible, "Esc goes back to the base")
	# standing on the door doesn't open it again; stepping off and on does
	await _frames(5)
	_check(home.live(), "stays in the base while still on the door")
	await _walk(home.doors.heroes + Vector2(0, 60))
	await _walk(home.doors.heroes)
	_check(ui.screen.visible, "stepping back on opens it again")
	ui.menus.back()
	await _frames(2)
	_check(home.live(), "Back goes back to the base")
	# the tower building
	await _walk(home.doors.heroes + Vector2(0, 60))
	await _walk(home.doors.towers)
	_check(ui.screen.visible and ui.menus.hub, "the tower building opens the Towers screen")
	await _shot("3_towers")
	await _esc()
	await _walk(home.doors.towers + Vector2(0, 70))
	await _shot("4_base_walked")
	# the rift gate: the map choice, and Back returns to the base
	await _walk(home.doors.start)
	_check(ui.screen.visible and ui.menus.hub, "the rift gate opens the map choice")
	await _shot("4b_start_run")
	ui.menus.back()
	await _frames(2)
	_check(home.live(), "Back from the map choice goes back to the base")
	await _walk(home.doors.start + Vector2(0, 90))
	# the hero building switches who you play as
	await _walk(home.doors.heroes + Vector2(0, 60))
	await _walk(home.doors.heroes)
	ui.menus.show_heroes("vanguard")
	await _frames(2)
	await _shot("4c_play_as")
	ui.menus.set_home_hero("vanguard")
	ui.menus.go_home()
	await _frames(3)
	_check(home.live() and home.hero_id == "vanguard" and home.hero != null, "PLAY AS in the hero building switches your hero (%s)" % home.hero_id)
	await _walk(home.doors.heroes + Vector2(0, 70))
	await _shot("4d_as_vanguard")
	# Esc in the base: the main menu; Esc there: back to the base
	await _esc()
	_check(ui.screen.visible and not ui.menus.hub, "Esc in the base opens the main menu")
	await _shot("5_menu")
	await _esc()
	_check(home.live(), "Esc in the main menu goes back to the base")
	# a run hides it
	ui.menus.new_run("canal")
	ui.menus.start_run("gale", ["plasma"])
	await _frames(5)
	_check(not home.visible and ui.in_run(), "a run hides the base")
	# after playing Gale, the base has you walk as Gale
	main.game.S.over = true
	ui.menus.show_menu()
	await _esc()
	_check(home.live() and home.hero_id == "gale", "then you walk the base as the hero you played (%s)" % home.hero_id)
	print("HOME DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
