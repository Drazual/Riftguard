extends SceneTree
# Builds maps/test_room.tscn: a plain grass field with one simple U-shaped road, used by the Test Room.
# godot --headless --path godot -s res://tools/build_test_room.gd

const COLS := 24
const ROWS := 15
# Road corners (columns, rows): in on the left, across, down, and back to the base.
const PATH := [Vector2i(0, 3), Vector2i(20, 3), Vector2i(20, 11), Vector2i(9, 11)]
const GRASS := Vector2i(0, 0)
const GRASS_ALT := Vector2i(1, 0)
const ROAD := Vector2i(7, 0)


func _init() -> void:
	var root := MapScene.new()
	root.name = "TestRoom"
	root.id = "test_room"
	root.map_name = "Test Room"
	root.tier = "Test"
	root.theme = "sunset"
	root.waves = 999
	root.desc = "A sandbox for trying out enemies, heroes and towers. Nothing here is saved."
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = load("res://maps/tilesets/sunset.tres")
	root.add_child(ground)
	ground.owner = root
	var road := {}
	for i in PATH.size() - 1:
		var a: Vector2i = PATH[i]
		var b: Vector2i = PATH[i + 1]
		var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
		var p := a
		road[p] = true
		while p != b:
			p += step
			road[p] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			var at := ROAD if road.has(cell) else (GRASS_ALT if rng.randf() < 0.18 else GRASS)
			ground.set_cell(cell, 0, at)
	var spawn := Marker2D.new()
	spawn.name = "Spawn"
	spawn.position = Vector2(PATH[0].x * 32 + 16, PATH[0].y * 24 + 12)
	root.add_child(spawn)
	spawn.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, "res://maps/test_room.tscn")
	print("test_room.tscn saved" if err == OK else "save failed: %d" % err)
	root.free()
	quit()
