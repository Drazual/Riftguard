## A map read from its scene: the path traced from the painted path tiles, water, props and the base.
class_name MapInfo
extends RefCounted

const C := 40.0
const COLS := 24
const ROWS := 15

var id := ""
var scene: MapScene # an instance, kept for its tile layers
var ground: TileMapLayer
var props_layer: TileMapLayer
var wp: Array[Vector2] = [] # path corners in world units, from off the map to the base
var seg: Array = [] # {a, b, len, start}
var path_len := 0.0
var path_seq: Array[Vector2i] = [] # every path tile in order
var path_cells := {} # Vector2i -> true
var water_cells := {}
var prop_cells := {} # Vector2i -> atlas coords
var blocked := {}
var base := Vector2.ZERO
var problem := "" # why the map can't be played, if its path is broken
## A hand-painted map (MapScene.art_layout): the layout data, the path as free points instead of tiles, and
## build pads instead of the build grid. A pad is the cell (index, SPOT_ROW), so towers still key on a cell.
const SPOT_ROW := -1000
var art := {}
var art_dir := ""
var free_path := false
var spots: Array[Vector2] = [] # where a tower on each pad stands (field units)
var pad_centres: Array[Vector2] = [] # the middle of each pad on the ground
var hero_at = null


static func load_scene(ps: PackedScene) -> MapInfo:
	var m := MapInfo.new()
	m.scene = ps.instantiate()
	m.id = m.scene.id
	m.ground = m.scene.get_node_or_null("Ground")
	m.props_layer = m.scene.get_node_or_null("Props")
	if m.scene.art_layout != "":
		m._read_art(m.scene.art_layout)
	else:
		m._read()
	return m


func _read_art(path: String) -> void:
	var j = load(path)
	if not (j is JSON) or not (j.data is Dictionary):
		problem = "Can't read the map layout " + path
		return
	art = j.data
	art_dir = path.get_base_dir() + "/"
	free_path = true
	wp.clear()
	for p in art.path:
		wp.append(Vector2(p[0], p[1]))
	for pad in art.pads:
		spots.append(Vector2(pad.tower[0], pad.tower[1]))
		pad_centres.append(Vector2(pad.centre[0], pad.centre[1]))
	if art.has("hero"):
		hero_at = Vector2(art.hero[0], art.hero[1])
	if wp.size() < 2:
		problem = "The path needs at least 2 points."
		return
	_segments()


func kind_at(cell: Vector2i) -> String:
	if ground == null:
		return ""
	var td := ground.get_cell_tile_data(cell)
	if td == null:
		return ""
	var k = td.get_custom_data("kind")
	return k if k is String else ""


func _read() -> void:
	for r in ROWS:
		for c in COLS:
			var cell := Vector2i(c, r)
			var k := kind_at(cell)
			if k == "path":
				path_cells[cell] = true
			elif k == "water":
				water_cells[cell] = true
	if props_layer:
		for cell in props_layer.get_used_cells():
			if cell.x >= 0 and cell.y >= 0 and cell.x < COLS and cell.y < ROWS and not path_cells.has(cell):
				prop_cells[cell] = props_layer.get_cell_atlas_coords(cell)
	for k in water_cells:
		blocked[k] = true
	for k in prop_cells:
		blocked[k] = true
	_trace()


# Follows the path tiles from the one nearest the Spawn marker to the far end (the base), going straight
# where it can, so lanes painted side by side don't get mixed up.
func _trace() -> void:
	if path_cells.is_empty():
		problem = "This map has no path tiles."
		return
	var start: Vector2i = path_cells.keys()[0]
	var spawn: Node2D = scene.get_node_or_null("Spawn")
	if spawn:
		var sc := Vector2(spawn.position.x / 32.0, spawn.position.y / 24.0)
		var best := INF
		for cell in path_cells:
			var dd := (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(sc)
			if dd < best:
				best = dd
				start = cell
	var seen := { start: true }
	path_seq = [start]
	var dir := Vector2i.ZERO
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	while true:
		var cur: Vector2i = path_seq[path_seq.size() - 1]
		var nxt = null
		if dir != Vector2i.ZERO and path_cells.has(cur + dir) and not seen.has(cur + dir):
			nxt = cur + dir
		else:
			for d in dirs:
				if path_cells.has(cur + d) and not seen.has(cur + d):
					nxt = cur + d
					dir = d
					break
		if nxt == null:
			break
		seen[nxt] = true
		path_seq.append(nxt)
	if path_seq.size() < 2:
		problem = "The path needs at least 2 tiles."
		return
	if seen.size() < path_cells.size():
		push_warning("Map %s: %d path tiles aren't connected to the path from the spawn and are ignored." % [id, path_cells.size() - seen.size()])
		for cell in path_cells.keys():
			if not seen.has(cell):
				path_cells.erase(cell)
	# corners, starting one tile outside the map in front of the first tile
	var first: Vector2i = path_seq[0]
	var d0: Vector2i = path_seq[1] - first
	var cells: Array[Vector2i] = [first - d0]
	for i in range(0, path_seq.size()):
		var a: Vector2i = path_seq[i]
		if i == path_seq.size() - 1:
			cells.append(a)
		elif i > 0 and (path_seq[i + 1] - a) != (a - path_seq[i - 1]):
			cells.append(a)
	wp.clear()
	for cl in cells:
		wp.append(Vector2(cl.x * C + C / 2, cl.y * C + C / 2))
	_segments()


func _segments() -> void:
	seg.clear()
	path_len = 0.0
	for i in wp.size() - 1:
		var l := wp[i].distance_to(wp[i + 1])
		seg.append({ a = wp[i], b = wp[i + 1], len = l, start = path_len })
		path_len += l
	base = wp[wp.size() - 1]


func pos_at(d: float) -> Vector2:
	if seg.is_empty() or d > path_len:
		return base
	# binary search: hand-painted paths have many short segments
	var lo := 0
	var hi := seg.size() - 1
	while lo < hi:
		var mid := (lo + hi) >> 1
		if d <= seg[mid].start + seg[mid].len:
			hi = mid
		else:
			lo = mid + 1
	var s: Dictionary = seg[lo]
	return s.a.lerp(s.b, (d - s.start) / s.len) if s.len > 0 else s.b


func hero_start() -> Vector2:
	if hero_at != null:
		return hero_at
	return Vector2(base.x - 80, base.y - 60 if base.y > 120 else base.y + 60)
