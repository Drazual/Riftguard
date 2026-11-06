## Screenshots of building on a free-build map (the square snap grid and the hovered square) and of zooming in toward
## a point and panning. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/zoom.tscn -- <out dir>
extends Node

var out := "user://zoom"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(60).timeout.connect(func(): print("ZOOM TIMEOUT"); get_tree().quit(1))
	seed(7)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("vanguard", ["arcane", "plasma", "laser", "frost", "tesla", "mortar"])
	for i in 10:
		await get_tree().process_frame
	var g := main.game
	var S := g.S
	var b: Board = main.board
	S.gold = 5000
	# the free grid squares nearest the hero: build on one, point at the next
	var open := g.snap_cells().filter(func(c): return g.build_problem(c.x, c.y, "plasma") == "")
	var hp := Vector2(S.hero.x, S.hero.y)
	open.sort_custom(func(a, c): return g.cell_pos(a.x, a.y).distance_to(hp) < g.cell_pos(c.x, c.y).distance_to(hp))
	g.place_tower(open[0].x, open[0].y, "plasma")
	S.build = "plasma"
	var t0 := g.cell_pos(open[0].x, open[0].y)
	var spot: Vector2i = open.filter(func(c): return absf(g.cell_pos(c.x, c.y).x - t0.x) > 60)[0]
	var at := g.cell_pos(spot.x, spot.y) + Vector2(5, Game.FOOT_DY - 6)
	_point(b, at)
	print("hover ", S.hover, " open0 ", open[0], " towers ", S.towers.size(), " pending ", S.pending_build, " hero ", hp, " at ", at, " cellat ", g.cell_at(at.x, at.y))
	await _shot("00_build", S)
	# zoom in on the hero; the field point under the pointer must stay put
	var scr := _screen_of(b, at)
	var before := b.to_field(scr)
	b.zoom_by(2.0, scr)
	var after := b.to_field(scr)
	print("zoom ", b.zoom, " field under pointer before ", before, " after ", after)
	assert(before.distance_to(after) < 1.0)
	_point(b, at)
	await _shot("01_zoom2", S)
	b.pan_by(Vector2(-300, 0))
	await _shot("02_panned", S)
	b.zoom_by(10.0, scr)
	print("max zoom ", b.zoom)
	await _shot("03_max", S)
	b.zoom_by(0.01, scr)
	print("min zoom ", b.zoom, " cam ", b.cam)
	await _shot("04_out", S)
	get_tree().quit()


## The board-control point over field point p (searched, since only to_field exists).
func _screen_of(b: Board, p: Vector2) -> Vector2:
	var q := Vector2(b.size / 2)
	for i in 60:
		var f := b.to_field(q)
		q += (p - f) * Vector2(0.5, 0.4)
	return q


func _point(b: Board, p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _screen_of(b, p)
	b._gui_input(ev)


func _shot(name: String, _S, wait := 4) -> void:
	for i in wait:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
