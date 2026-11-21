## Event Horizon (Sniper legendary, Nov 2026): the ability opens a black hole that drags nearby enemies toward its
## middle and strips their armor; Sniper ability damage was halved and Radiation Field / AP Rounds give half as much.
## Headless: godot --headless --path godot res://tests/black_hole.tscn
extends Node

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var g := Game.new()
	add_child(g)
	Save.meta = Save.default_meta()
	Save._fill()
	g.new_run("plaza")
	g.start_run("sniper", Array(DB.tower_order).slice(0, 5))
	var S := g.S
	var u: UpgradeData = g.R.uniques.find("blackhole")
	_check(u != null and u.pool == "sniper" and u.rarity == "legendary", "Event Horizon is a Sniper legendary")
	_check(is_equal_approx(DB.heroes.sniper.ability.mult, 1.0) and is_equal_approx(DB.heroes.sniper.alt.mult, 2.25), "Sniper abilities deal half (Piercing 1x, Orbital 2.25x)")
	_check(is_equal_approx(g.R.perks.find("radfield").m, 0.15) and is_equal_approx(g.R.perks.find("apround").m, 0.15), "Radiation Field and AP Rounds give half as much")
	Fx.run(u.effect, { run = S, h = S.hero })
	_check(S.hero.black_hole, "picking it turns it on")
	var mid := S.map.path_len * 0.5
	var at: Vector2 = g.pos_at(mid, 0)
	S.wave_active = true
	S.spawn_q = []
	g.spawn("brute", mid - 100, 0)
	var e: Enemy = S.enemies[0]
	e.speed = 0.0
	var d0 := e.d
	var arm0 := g.armor_of(e, null)
	g.open_black_hole(at.x, at.y)
	for i in 30:
		g.update(1.0 / 30)
	_check(e.d > d0 + 40, "the hole drags the enemy toward its middle (%.0f -> %.0f, middle %.0f)" % [d0, e.d, mid])
	_check(arm0 > 0 and g.armor_of(e, null) <= maxf(0.0, arm0 - 0.3) + 0.001, "and strips its armor (%.2f -> %.2f)" % [arm0, g.armor_of(e, null)])
	for i in 100:
		g.update(1.0 / 30)
	_check(S.holes.is_empty(), "the hole closes after 3s")
	print("BLACK HOLE PASS" if fails == 0 else "BLACK HOLE FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
