## Screenshots of the first build-bar tooltip of a run, frame by frame, to check it never shows as a big empty box.
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/tip.tscn -- <out dir>
extends Node

var out := "user://tip"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(60).timeout.connect(func(): print("TIP TIMEOUT"); get_tree().quit(1))
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("vanguard", ["arcane", "plasma", "laser", "frost", "tesla", "mortar"])
	for i in 10:
		await get_tree().process_frame
	var bt: Control = main.ui.build_bar.get_child(1)
	bt.mouse_entered.emit()
	for f in 6:
		await RenderingServer.frame_post_draw
		print("frame ", f, " tip visible ", main.ui.tip.visible, " alpha ", main.ui.tip.modulate.a, " size ", main.ui.tip.size, " label ", main.ui.tip_label.size)
		get_viewport().get_texture().get_image().save_png(out.path_join("f%d.png" % f))
	get_tree().quit()
