## Free tower placement on a map with a build mask (Ocean Drive): towers go on open ground and nowhere else.
## Run: godot --headless --path godot res://tests/placement.tscn -- [map]
extends Node

var game: Game
var fails := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "canal"
	game = Game.new()
	add_child(game)
	game.new_run(map_id)
	game.start_run(DB.hero_order[0], Array(DB.tower_order).slice(0, 5))
	var S := game.S
	S.gold = 99999
	var m := S.map
	_check("the map uses free placement", game.free_build() and not game.has_pads())
	_check("the layout has no pads", m.spots.is_empty() and m.pad_centres.is_empty())
	var type: String = DB.tower_order[0]
	# the middle of the loop: the open ground furthest from the road inside the city
	var mid := Vector2i(-1, -1)
	var md := -1.0
	for c in game.build_cells():
		var d := m.path_dist(game.cell_pos(c.x, c.y))
		var p := game.cell_pos(c.x, c.y)
		if d > md and p.x > 300 and p.x < 660 and p.y > 150 and p.y < 450:
			md = d
			mid = c
	_check("there is open ground in the middle (%s, %.0f from the road)" % [game.cell_pos(mid.x, mid.y), md], mid.x >= 0 and md > 60)
	_check("the middle is buildable", game.build_problem(mid.x, mid.y, type) == "")
	# the road itself: a point on the path, and one just beside it on the curb
	var on_road := m.pos_at(m.path_len * 0.5)
	var rc := game.cell_at(on_road.x, on_road.y + Game.FOOT_DY)
	_check("the road is refused: " + game.build_problem(rc.x, rc.y, type), game.build_problem(rc.x, rc.y, type) == "Too close to the road.")
	var curbs := 0 # a tower's foot just off the asphalt, on the curb: too close
	for j in m.build_h:
		for i in m.build_w:
			var d := m.path_dist(game.cell_pos(i, j) + Vector2(0, Game.FOOT_DY))
			if d > 13 and d < 17 and game.cell_pos(i, j).x > 40 and game.cell_pos(i, j).x < 920:
				curbs += 1
				if game.build_problem(i, j, type) != "Too close to the road.":
					_check("the curb at %s is refused: %s" % [game.cell_pos(i, j), game.build_problem(i, j, type)], false)
	_check("the curb is refused all along the road (%d spots)" % curbs, curbs > 100)
	# buildings and the edges of the map
	var bld := _first_code(m, 3, Rect2(100, 380, 760, 200)) # the row of buildings along the bottom
	_check("a building is refused: " + game.build_problem(bld.x, bld.y, type), bld.x >= 0 and game.build_problem(bld.x, bld.y, type).begins_with("That's the edge"))
	for p in [Vector2(5, 250), Vector2(955, 250), Vector2(480, 4), Vector2(480, 596)]:
		var ec := game.cell_at(p.x, p.y + Game.FOOT_DY)
		_check("the edge at %s is refused" % p, game.build_problem(ec.x, ec.y, type).begins_with("That's the edge"))
	var obj := _first_code(m, 2, Rect2(0, 0, 960, 600)) # the portal or the arch
	_check("the portal/arch is refused: " + game.build_problem(obj.x, obj.y, type), obj.x >= 0 and game.build_problem(obj.x, obj.y, type) == "Something is in the way.")
	# other towers: the same spot and one just beside it are refused, one a tower's width away is fine
	game.place_tower(mid.x, mid.y, type)
	_check("a tower went down in the middle", S.towers.size() == 1 and game.tower_at(mid.x, mid.y) != null)
	_check("the same spot is refused", game.build_problem(mid.x, mid.y, type) == "Too close to another tower.")
	var next := Vector2i(mid.x + 5, mid.y) # 20 units over
	_check("an overlapping spot is refused: " + game.build_problem(next.x, next.y, type), game.build_problem(next.x, next.y, type) == "Too close to another tower.")
	var far := Vector2i(mid.x + 10, mid.y) # 40 units over
	_check("a spot a tower's width away is fine: " + game.build_problem(far.x, far.y, type), game.build_problem(far.x, far.y, type) == "")
	# pointing at the tower's body picks it, pointing at open ground picks a new spot under the pointer
	var t: Tower = S.towers[0]
	_check("pointing at a tower picks it", game.cell_at(t.x, t.y - 30) == Vector2i(t.c, t.r))
	var g2 := game.cell_at(t.x + 60, t.y + Game.FOOT_DY)
	_check("pointing at open ground picks the spot under the pointer", game.cell_pos(g2.x, g2.y).distance_to(Vector2(t.x + 60, t.y)) <= 3)
	# hero walk-to-build: a click out of reach sends the hero over, and it builds on arrival
	S.hero.x = 60
	S.hero.y = 300
	S.build = type
	var fx := game.cell_pos(far.x, far.y)
	game.handle_click(fx.x, fx.y + Game.FOOT_DY)
	_check("a far click queues a walk-to-build", S.pending_build != null and S.pending_build.c == far.x and S.pending_build.r == far.y)
	for i in 600:
		game.update(1.0 / 30)
		if S.towers.size() == 2:
			break
	_check("the hero walked over and built it", S.towers.size() == 2 and game.tower_at(far.x, far.y) != null)
	print("PLACEMENT %s" % ("OK" if fails == 0 else "FAILED %d" % fails))
	get_tree().quit(1 if fails else 0)


func _first_code(m: MapInfo, code: int, area: Rect2) -> Vector2i:
	for j in m.build_h:
		for i in m.build_w:
			var p := Vector2((i + 0.5) * m.build_step, (j + 0.5) * m.build_step)
			if area.has_point(p) and m.build_code(p) == code:
				return Vector2i(i, j)
	return Vector2i(-1, -1)


func _check(what: String, ok: bool) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1
