## Checks the board doesn't move or resize while the Wizard readies runes (the rune bar's text changing length
## used to wrap the bottom bar onto a second row and squash the map). Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/rune_bar.tscn
extends Node


func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): print("RUNE TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("wizard", ["plasma", "frost", "tesla", "laser"])
	for i in 10:
		await get_tree().process_frame
	var g := main.game
	var rect := func() -> Rect2: return (main.board as Control).get_global_rect() if main.board is Control else Rect2(main.board.global_position, Vector2.ZERO)
	var bar: Control = main.ui.build_bar
	var r0: Rect2 = rect.call()
	var b0 := bar.size
	print("start board ", r0, " bar ", b0)
	var moved := 0
	var keys: Array = g.S.rune_keys.keys()
	for combo in [[0], [0, 1], [2, 2], [3], [4, 5], [6, 7], [1]]:
		g.S.runes = []
		g.S.el_cd = {}
		for i in combo:
			g.ready_rune(keys[i % keys.size()])
		for i in 4:
			await get_tree().process_frame
		var r: Rect2 = rect.call()
		print("runes ", g.S.runes, " board ", r, " bar ", bar.size)
		if not r.is_equal_approx(r0) or not bar.size.is_equal_approx(b0):
			moved += 1
	print("RUNE DONE: the board moved %d times" % moved)
	get_tree().quit(1 if moved else 0)
