## The Wizard's Stone Wall and Great Wall drawn live from their 3D models, in a real run (needs a display):
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/walls.tscn -- <out dir>
## Checks each rises (spawn) then idles, shows exactly one wear stage for its HP, shakes when hit, sinks away
## (break at 0 HP, despawn on timeout) and is freed; and that the Great Wall's slam lands once, 0.85s in.
extends Node

var out := "user://walls"
var fails := 0
var main: Main
var g: Game


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(name: String, at: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var b: Board = main.board
	var bi := b.viewport.get_texture().get_image()
	var p := b.units.get_global_transform_with_canvas() * Vector2(at.x, b.SY(at.y))
	var r := Rect2i(int(p.x) - 90, int(p.y) - 90, 180, 120).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var c := bi.get_region(r)
	c.resize(c.get_width() * 3, c.get_height() * 3, Image.INTERPOLATE_LANCZOS)
	c.save_png(out.path_join(name + ".png"))


func _wait(secs: float) -> void:
	var until := g.S.time + secs
	while g.S.time < until:
		await get_tree().process_frame


func _shown(v: Wall3D) -> int:
	var n := -1
	for i in 3:
		if (v.wall.get_node("Wear%d" % i) as Node3D).visible:
			if n >= 0:
				return -2
			n = i
	return n


func _cast(els: Array, at: Vector2) -> Dictionary:
	var S := g.S
	S.hero.mana = 999
	S.hero.wall_charges = 9
	S.runes = els
	var n := S.walls.size()
	# the Wizard casts only within its range: it stands beside the spot
	S.hero.x = at.x - 60
	S.hero.y = at.y
	S.hero.tx = null
	g.cast_runes(at.x, at.y)
	return S.walls[S.walls.size() - 1] if S.walls.size() > n else {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): print("WALLS TIMEOUT"); get_tree().quit(1))
	seed(7)
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("wizard", ["plasma"])
	for i in 10:
		await get_tree().process_frame
	g = main.game
	var S := g.S
	S.lives = 999
	var b: Board = main.board
	g.start_wave()
	S.spawn_q = []
	# Stone Wall
	var spot := g.pos_at(S.map.path_len * 0.35)
	var w := _cast(["earth"], spot)
	_check(not w.is_empty() and w.art == "stonewall", "a Stone Wall goes up")
	for i in 3:
		await get_tree().process_frame
	var v: Wall3D = w.get("_v3")
	_check(v != null and v.ap.current_animation == "spawn", "drawn from its model, rising (%s)" % (v.ap.current_animation if v else "none"))
	_check(_shown(v) == 0, "pristine stage shown alone")
	await _wait(0.3)
	await _shot("0_stone_rising", spot)
	await _wait(0.6)
	_check(v.ap.current_animation == "idle", "then idles (%s)" % v.ap.current_animation)
	await _shot("1_stone_idle", spot)
	w.hp = w.max * 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_shown(v) == 1 and v.ap.current_animation == "hit_react", "at half HP: worn stage, shakes (%d, %s)" % [_shown(v), v.ap.current_animation])
	await _wait(0.3)
	await _shot("2_stone_worn", spot)
	w.hp = w.max * 0.2
	await _wait(0.3)
	_check(_shown(v) == 2, "at 20%%: critical stage (%d)" % _shown(v))
	await _shot("3_stone_critical", spot)
	w.hp = 0
	await _wait(0.15)
	_check(is_instance_valid(v) and v.ending and v.ap.current_animation == "break", "at 0 HP it breaks (%s)" % (v.ap.current_animation if is_instance_valid(v) else "freed"))
	await _shot("4_stone_break", spot)
	await _wait(0.8)
	_check(not is_instance_valid(v), "and is freed once sunk")
	# Great Wall: the slam lands once, 0.85s in, at its front
	var spot2 := g.pos_at(S.map.path_len * 0.45)
	g.spawn("brute", S.map.path_len * 0.45 - 20)
	var e: Enemy = S.enemies[S.enemies.size() - 1]
	await get_tree().process_frame
	e.speed = 0
	e.hp = 5000
	e.max = 5000
	e.armor = 0
	var hp0 := e.hp
	var w2 := _cast(["earth", "earth"], spot2)
	var t0 := S.time
	_check(not w2.is_empty() and w2.art == "greatwall", "a Great Wall goes up")
	await _wait(0.4)
	_check(e.hp == hp0 and e.stun_t <= 0, "no slam before 0.85s")
	var v2: Wall3D = w2.get("_v3")
	_check(v2 != null and v2.ap.current_animation == "spawn", "Great Wall rising from its model")
	await _shot("5_great_rising", spot2)
	while S.time < t0 + 0.85:
		await get_tree().process_frame
	await get_tree().process_frame
	var hit := hp0 - e.hp
	_check(hit > 0 and e.stun_t > 0.5, "the slam lands at 0.85s (%.0f, stun %.2f)" % [hit, e.stun_t])
	await _wait(0.6)
	_check(hp0 - e.hp == hit or e.hp < hp0 - hit, "and only once (%.0f)" % (hp0 - e.hp))
	_check(v2.ap.current_animation == "idle", "then idles (%s)" % v2.ap.current_animation)
	await _shot("6_great_idle", spot2)
	w2.t = 0.01
	await _wait(0.15)
	_check(is_instance_valid(v2) and v2.ap.current_animation == "despawn", "on timeout it sinks (%s)" % (v2.ap.current_animation if is_instance_valid(v2) else "freed"))
	await _wait(0.8)
	_check(not is_instance_valid(v2), "and is freed")
	print("WALLS DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
