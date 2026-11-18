## The Test Room: it opens from the main menu with every tower and endless gold, its panel spawns any enemy in any
## number, enemies that get through never end it, heroes and abilities swap in place, and nothing is saved.
## Prints TEST ROOM PASS or FAIL.
## godot --headless --path godot res://tests/test_room.tscn
## (with a screen: xvfb-run godot --path godot res://tests/test_room.tscn -- <out.png> saves a shot of the room)
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
	get_tree().create_timer(120).timeout.connect(func(): print("TEST ROOM TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var shards_before: int = Save.meta.shards
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames()
	var ui: Ui = main.ui
	var game: Game = main.game
	_check(not DB.map_order.has(DB.TEST_MAP), "the test room is not on the map choice")
	_check(DB.maps.has(DB.TEST_MAP) and DB.maps[DB.TEST_MAP].problem == "", "the test room map loads with a good path")
	ui.menus.start_test_room()
	await _frames(5)
	var S := game.S
	_check(ui.in_run() and S.test, "TEST ROOM starts a test run")
	_check(Array(S.loadout) == Array(DB.tower_order), "every tower is in the build bar")
	_check(ui.test_panel.visible, "the test panel shows")
	# endless gold
	var cell: Vector2i = game.build_cells()[40]
	game.place_tower(cell.x, cell.y, DB.tower_order[0])
	game.update(0.05)
	_check(S.gold >= Game.TEST_GOLD, "gold refills after building")
	_check(S.towers.size() == 1, "a tower can be built")
	# spawn every enemy type
	for e: EnemyData in DB.rules.enemies:
		game.test_spawn(e.id, 2, 5, 0.05)
	var want := DB.rules.enemies.size() * 2
	_check(S.spawn_q.size() == want, "the panel queues 2 of each of the %d enemy types" % DB.rules.enemies.size())
	var seen := {}
	for i in 200:
		game.update(0.05)
		for e: Enemy in S.enemies:
			seen[e.type] = true
	_check(seen.size() == DB.rules.enemies.size(), "every enemy type walked onto the road (%d of %d)" % [seen.size(), DB.rules.enemies.size()])
	var g: Enemy = null
	for e: Enemy in S.enemies:
		if e.type == "grunt":
			g = e
	if g:
		var d: EnemyData = DB.enemies.grunt
		_check(g.max > d.hp * 1.5, "wave 5 HP is applied (grunt %d HP vs %d base)" % [roundi(g.max), roundi(d.hp)])
	if ui.test_panel.visible and DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().size():
		S.paused = false
		await _frames(30)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	# leaks never end it, the Tyrant included
	game.test_clear()
	_check(S.enemies.is_empty() and S.spawn_q.is_empty(), "Clear enemies empties the board and the queue")
	game.spawn("tyrant", S.map.path_len - 5)
	game.spawn("grunt", S.map.path_len - 5)
	for i in 40:
		game.update(0.05)
	_check(not S.over and S.lives == Game.TEST_LIVES, "enemies reaching the base (even the Tyrant) don't end it")
	# the wave never ends on its own, and Space does nothing
	game.test_clear()
	game.update(0.05)
	game.start_wave()
	_check(S.wave_active and not S.need_choice and not S.need_shop, "an empty board doesn't end a wave or open a shop")
	# swap every hero and its other ability
	for k in DB.hero_order:
		game.test_swap_hero(k, false)
		ui.test_panel.render()
		_check(S.hero.cls == k and S.pending_levels == 0, "swaps to " + DB.heroes[k].name)
		var d: HeroData = DB.heroes[k]
		if d.alt and not d.spells:
			game.test_swap_hero(k, true)
			_check(S.hero.ab.name == d.alt.name, "  and to its other ability, " + d.alt.name)
		for i in 10:
			game.update(0.05)
	if DB.heroes.has("wizard"):
		S.test_els = Array(DB.el_order).slice(DB.el_order.size() - 2)
		game.test_swap_hero("wizard", false)
		_check(S.rune_keys.values() == S.test_els, "the Wizard takes any elements, locked ones too")
	await _frames(5)
	# leaving saves nothing
	ui.menus.confirm_quit()
	await _frames(3)
	_check(not ui.in_run() and ui.screen.visible, "leaving goes back to the main menu")
	_check(Save.meta.shards == shards_before, "no Rift Shards from the test room")
	print("TEST ROOM PASS" if fails == 0 else "TEST ROOM FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
