## Every merge model in a real run, headless: runs MergeSelftest (scripts/core/merge_selftest.gd) on a fresh Main.
## The same check runs in a built game with: Riftguard.exe -- --merge-selftest
## godot --headless --path godot res://tests/merge_models.tscn
extends Node


func _ready() -> void:
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	if main.has_node("MergeSelftest"):
		return
	var st := MergeSelftest.new()
	st.name = "MergeSelftest"
	st.main = main
	add_child(st)
