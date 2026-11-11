## Gale and Oracle rule changes in real runs:
##  - Gale's Air Strike is aimed by hand like Piercing Shot (hold Q, see the trail and who it catches, let go to fire).
##  - Bruiser Form doubles Gale's base damage too, so "+X% of base damage" upgrades grow with it.
##  - Hold the Line (Gale, Bruiser Form only) holds more enemies, and Bruiser Form keeps it.
##  - The cheaper-towers upgrade (Architect) is gone.
##  - With the Oracle, towers use 3 paths of 4 points like every hero; a path's mastery comes at its 3rd point.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/gale_oracle.tscn -- <out dir>
extends Node

var out := "user://gale_oracle"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _perk(id: String) -> UpgradeData:
	var list: UpgradeList = load("res://data/lists/perks.tres")
	for p in list.items:
		if p.id == id:
			return p
	return null


func _start(hero: String, towers: Array) -> void:
	if main:
		main.queue_free()
		await _frames(2)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run(hero, towers)
	await _frames(10)
	main.game.S.gold = 999999


func _place(g: Game, type: String) -> Tower:
	for c in g.build_cells():
		if g.build_problem(c.x, c.y, type) == "":
			g.place_tower(c.x, c.y, type)
			return g.S.towers[g.S.towers.size() - 1]
	return null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(200).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	# --- Architect is gone ---
	var perks: UpgradeList = load("res://data/lists/perks.tres")
	_check(perks.items.all(func(p): return p.id != "arch"), "no Architect (cheaper towers) upgrade in the pool")
	_check(perks.items.all(func(p): return not p.effect.contains("cost_mul")), "no hero upgrade lowers tower build cost")
	# --- Gale with Air Strike (equipped in the hero screen) ---
	if not Save.meta.has("abilities"):
		Save.meta.abilities = {}
	var had = Save.meta.abilities.get("gale", null)
	Save.meta.abilities["gale"] = "alt"
	await _start("gale", ["arcane", "tesla", "mortar", "frost"])
	var g := main.game
	var S := g.S
	var h := S.hero
	_check(h.ab.id == "stream", "Gale has Air Strike (%s)" % h.ab.id)
	if h.ab.id == "stream":
		_check(g.held_aim(h), "Air Strike is a held-aim ability")
		S.pointer = h.pos() + Vector2(200, 0)
		_check(g.pierce_aim_start(), "holding Q starts aiming Air Strike")
		_check(S.pierce_aiming, "the board shows its trail while aiming")
		var shown := g.strike_line(h, h.ab, S.pointer)
		_check(shown is Array, "the preview lists who it would catch (%d)" % shown.size())
		await _frames(3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("air_strike_aim.png"))
		var aim_at := h.pos() + Vector2(0, -150)
		S.pointer = h.pos() + Vector2(200, 0) # the cursor moved on, but the shot goes where Q was let go
		g.pierce_aim_fire(aim_at)
		_check(not S.pierce_aiming, "letting go fires")
		_check(h.ab.t > 0, "Air Strike went on cooldown")
		_check(h.stream_dir.dot(Vector2(0, -1)) > 0.99, "it fired exactly where it was aimed (%s)" % h.stream_dir)
	# --- Bruiser Form and Hold the Line ---
	var hold := _perk("holdline")
	_check(hold != null, "Hold the Line exists")
	var knuckles := _perk("knuckles")
	if hold:
		_check(not g.dmg_ok(hold), "Hold the Line isn't offered before Bruiser Form (Gale holds everything then)")
	var b0 := h.base_dmg
	var d0 := h.dmg
	h.bruiser_form()
	_check(is_equal_approx(h.base_dmg, b0 * 2.0), "Bruiser Form doubles base damage (%.1f -> %.1f)" % [b0, h.base_dmg])
	_check(is_equal_approx(h.dmg, d0 * 2.0), "and damage (%.1f -> %.1f)" % [d0, h.dmg])
	var blk := h.block
	_check(blk == DB.rules.bruiser_block, "Bruiser holds %d" % blk)
	if knuckles:
		var before := h.dmg
		g.apply_offer(g.make_offer(knuckles, "perk", DB.rar["common"], false))
		_check(is_equal_approx(h.dmg - before, b0 * 2.0 * knuckles.m * DB.rar["common"].mult), "Iron Knuckles now adds 8%% of the doubled base (+%.2f)" % (h.dmg - before))
	if hold:
		_check(g.dmg_ok(hold), "Hold the Line is offered in Bruiser Form")
		g.apply_offer(g.make_offer(hold, "perk", DB.rar["common"], false))
		_check(h.block == blk + 1, "Hold the Line: holds one more (%d -> %d)" % [blk, h.block])
		# taken before the form: the form keeps it
		var h2 := Hero.new()
		h2.block = 999
		h2.block_add = 2
		h2.bruiser_form()
		_check(h2.block == DB.rules.bruiser_block + 2, "Bruiser Form keeps extra holds taken earlier (%d)" % h2.block)
	# --- Oracle: 3 paths of 4, mastery at 3 ---
	await _start("oracle", ["arcane", "tesla", "mortar", "frost"])
	g = main.game
	S = g.S
	_check(g.path_limit() == 3, "Oracle: 3 paths per tower (%d)" % g.path_limit())
	_check(g.path_max() == 4, "Oracle: 4 levels per path (%d)" % g.path_max())
	_check(g.mastery_at() == 3, "Oracle: mastery at the 3rd level")
	var t := _place(g, "arcane")
	var opts: Array = g.tower_options(t)
	var o: Dictionary = opts[0]
	var got := []
	for i in 4:
		var cur := g.tower_options(t).filter(func(x): return x.id == o.id)
		if cur.is_empty():
			break
		g.level_tower(t, cur[0])
		print("  point ", t.ups_of(o.id), " rank ", t.rk.get(o.id, 0))
	_check(t.ups_of(o.id) == 4, "a path takes 4 points with the Oracle (%d)" % t.ups_of(o.id))
	_check(int(t.rk.get(o.id, 0)) == 4, "each point is one rank (rank %d)" % int(t.rk.get(o.id, 0)))
	_check(g.path_state(t, o) == "maxed", "the path is maxed at 4")
	# the 4th path stays locked after 3
	var t2 := _place(g, "tesla")
	var p2: Array = g.tower_options(t2)
	for k in 3:
		g.level_tower(t2, p2[k])
	_check(g.path_state(t2, p2[3]) == "locked", "a 4th path stays locked with the Oracle")
	# without the Oracle the mastery is still at 4
	await _start("gale", ["arcane", "tesla"])
	_check(main.game.mastery_at() == 4 and main.game.path_limit() == 3, "other heroes: mastery at 4, 3 paths")
	if had == null:
		Save.meta.abilities.erase("gale")
	else:
		Save.meta.abilities["gale"] = had
	print("GALE ORACLE DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
