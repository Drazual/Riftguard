extends SceneTree
# One-time generator: builds the 4 tilesets and map scenes from the original game's map data.

const C := 40
const COLS := 24
const ROWS := 15
var META := {}

const MAPS := {
	"verdant": { file = "sunset_outpost", name = "Sunset Outpost", theme = "sunset", tier = "Level 1", waves = 20, shard = 1.0, props = 15, desc = "The standard run. No modifiers.",
		path = [[-1,3],[5,3],[5,11],[10,11],[10,5],[15,5],[15,11],[20,11],[20,6],[23,6]], water = [] },
	"ironhold": { file = "neon_boardwalk", name = "Neon Boardwalk", theme = "boardwalk", tier = "Level 2", waves = 25, shard = 1.5, hp = 1.4, price = 1.3, props = 14, water = [[0,14,24,1]],
		desc = "Enemies have 40% more HP and everything costs 30% more.",
		path = [[-1,11],[3,11],[3,2],[8,2],[8,8],[12,8],[12,2],[17,2],[17,11],[21,11],[21,5],[23,5]] },
	"warped": { file = "chroma_reactor", name = "Chroma Reactor", theme = "reactor", tier = "Level 3", waves = 30, shard = 2.0, drain = true, props = 14, water = [[13,0,2,2],[22,13,2,2]],
		desc = "After each wave, the tower that dealt the most damage is drained and deals half damage for the next wave only.",
		path = [[-1,2],[7,2],[7,6],[2,6],[2,12],[11,12],[11,4],[16,4],[16,12],[21,12],[21,2],[23,2]] },
	"maelstrom": { file = "spiral_rift_garden", name = "Spiral Rift Garden", theme = "garden", tier = "Level 4", waves = 35, shard = 2.5, hp = 1.8, armor = 0.1, early = 2, cores = 8, props = 12, water = [],
		desc = "A long spiral into a base in the middle. Rift Storm: enemies have 80% more HP, armored enemies get +10% armor, and special enemies show up 2 waves early. The final Tyrant drops 8 Boss Cores.",
		path = [[-1,13],[22,13],[22,1],[1,1],[1,10],[18,10],[18,4],[5,4],[5,7],[13,7]] },
}


func _init() -> void:
	META = JSON.parse_string(FileAccess.get_file_as_string("/tmp/claude-0/atlas_meta.json"))
	DirAccess.make_dir_recursive_absolute("res://maps/tilesets")
	for th in META:
		_tileset(th)
	for id in MAPS:
		_map(id)
	quit()


func _tileset(th: String) -> void:
	var m: Dictionary = META[th]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 24)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "kind")
	ts.set_custom_data_layer_type(0, TYPE_STRING)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/maps/%s_tiles.png" % th)
	src.texture_region_size = Vector2i(32, 24)
	ts.add_source(src, 0)
	var tiles: Array = m.tiles
	for i in tiles.size():
		src.create_tile(Vector2i(i, 0))
		var n: String = tiles[i]
		var kind := "ground"
		if n.begins_with("d"):
			kind = "deco"
		elif n == "water" or n == "path":
			kind = n
		src.get_tile_data(Vector2i(i, 0), 0).set_custom_data("kind", kind)
	var ps := TileSetAtlasSource.new()
	ps.texture = load("res://assets/maps/%s_props.png" % th)
	ps.texture_region_size = Vector2i(36, 50)
	ts.add_source(ps, 1)
	for i in (m.props as Array).size():
		var at := Vector2i(i % 8, i / 8)
		ps.create_tile(at)
		var td := ps.get_tile_data(at, 0)
		td.texture_origin = Vector2i(0, 13)
		td.set_custom_data("kind", "prop")
	ResourceSaver.save(ts, "res://maps/tilesets/%s.tres" % th)


func _map(id: String) -> void:
	var M: Dictionary = MAPS[id]
	var th: String = M.theme
	var meta: Dictionary = META[th]
	var tiles: Array = meta.tiles
	# path cells, waypoints
	var wp := []
	for p in M.path:
		wp.append(Vector2(p[0] * C + C / 2.0, p[1] * C + C / 2.0))
	var path := {}
	for i in wp.size() - 1:
		var c0 := int(floor(wp[i].x / C)); var r0 := int(floor(wp[i].y / C))
		var c1 := int(floor(wp[i + 1].x / C)); var r1 := int(floor(wp[i + 1].y / C))
		while true:
			if c0 >= 0:
				path[Vector2i(c0, r0)] = true
			if c0 == c1 and r0 == r1:
				break
			c0 += signi(c1 - c0); r0 += signi(r1 - r0)
	var base: Vector2 = wp[wp.size() - 1]
	var water := {}
	for w in M.water:
		for c in range(w[0], w[0] + w[2]):
			for r in range(w[1], w[1] + w[3]):
				if not path.has(Vector2i(c, r)):
					water[Vector2i(c, r)] = true
	var near_path := func(c: int, r: int, d: int) -> bool:
		for dc in range(-d, d + 1):
			for dr in range(-d, d + 1):
				if path.has(Vector2i(c + dc, r + dr)):
					return true
		return false
	var sc := int(floor((base.x - 80) / C))
	var sr := int(floor((base.y - 60 if base.y > 120 else base.y + 60) / C))
	var open := []
	for r in ROWS:
		for c in COLS:
			if not water.has(Vector2i(c, r)) and not near_path.call(c, r, 1) and Vector2(c - sc, r - sr).length() > 2:
				open.append(Vector2i(c, r))
	open.sort_custom(func(a, b): return Hash32.cell(a.x, a.y, 7) < Hash32.cell(b.x, b.y, 7))
	var props := []
	for p in open:
		if props.size() >= M.props:
			break
		var ok := true
		for q in props:
			if max(absi(q.x - p.x), absi(q.y - p.y)) < 3:
				ok = false
				break
		if ok:
			props.append(p)
	props.sort_custom(func(a, b): return a.y < b.y)
	# scene
	var root := Node2D.new()
	root.set_script(load("res://scripts/data/map_scene.gd"))
	root.name = M.file.to_pascal_case()
	root.id = id
	root.map_name = M.name
	root.tier = M.tier
	root.theme = th
	root.waves = M.waves
	root.shard_mult = M.shard
	root.enemy_hp = M.get("hp", 1.0)
	root.price = M.get("price", 1.0)
	root.armor_bonus = M.get("armor", 0.0)
	root.early_specials = M.get("early", 0)
	root.tyrant_cores = M.get("cores", 0)
	root.drain = M.get("drain", false)
	root.desc = M.desc
	var ts: TileSet = load("res://maps/tilesets/%s.tres" % th)
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = ts
	root.add_child(ground)
	ground.owner = root
	var weights: Array = meta.weights
	var tot := 0.0
	for w in weights:
		tot += w
	var ndeco: int = meta.deco
	var deco := func(c: int, r: int) -> bool:
		return ndeco > 0 and not path.has(Vector2i(c, r)) and not water.has(Vector2i(c, r)) and Hash32.cell(c, r, 2) < 0.11
	for r in ROWS:
		for c in COLS:
			var k := Vector2i(c, r)
			var name := ""
			if path.has(k):
				name = "path"
			elif water.has(k) and tiles.has("water"):
				name = "water"
			else:
				var x := Hash32.cell(c, r, 1) * tot
				var g := 0
				while x > weights[g]:
					x -= weights[g]
					g += 1
				if deco.call(c, r) and not deco.call(c - 1, r) and not deco.call(c, r - 1):
					name = "d" + str(int(floor(Hash32.cell(c, r, 3) * ndeco)))
				else:
					name = "g" + str(g)
			ground.set_cell(k, 0, Vector2i(tiles.find(name), 0))
	var player := TileMapLayer.new()
	player.name = "Props"
	player.tile_set = ts
	root.add_child(player)
	player.owner = root
	var np: int = (meta.props as Array).size()
	var order := range(np)
	order.sort_custom(func(a, b): return Hash32.cell(a, id.length(), 9) < Hash32.cell(b, id.length(), 9))
	for i in props.size():
		var pi: int = order[i % order.size()]
		player.set_cell(props[i], 1, Vector2i(pi % 8, pi / 8))
	var spawn := Marker2D.new()
	spawn.name = "Spawn"

	# the first tile on the map, in tile-layer pixels
	var p0: Array = M.path[0]
	var p1: Array = M.path[1]
	var fc: int = 0 if p0[0] < 0 else p0[0]
	spawn.position = Vector2(fc * 32 + 16, p0[1] * 24 + 12)
	root.add_child(spawn)
	spawn.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "res://maps/%s.tscn" % M.file)
	print("map ", id, " path ", path.size(), " props ", props.size())
