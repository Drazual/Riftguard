## Map progression (Nov 2026): the first map has 20 waves and each map after it 5 more; each later map's waves start
## tougher than the one before (Ocean Drive: costs +15%, Brutes from wave 1); special enemies come in a few per map
## (none a later map introduces turn up early); and a wave that brings a type the player hasn't been introduced to
## opens the new-enemy window. Headless: godot --headless --path godot res://tests/map_progression.tscn
extends Node

var fails := 0
var g: Game
var intros := []


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


## The enemy types in waves 1..n of a fresh run on `map` (several tries, since special picks are random).
func _types_by_wave(map: String) -> Dictionary:
	g.new_run(map)
	g.start_run("vanguard", Array(DB.tower_order).slice(0, 5))
	var out := {}
	for n in range(1, g.S.map.scene.waves + 1):
		var seen := {}
		for i in 6:
			for k in g.make_wave(n, {}):
				seen[k] = true
		out[n] = seen
	return out


func _first(by: Dictionary, k: String) -> int:
	for n in by.keys():
		if by[n].has(k):
			return n
	return 0


func _ready() -> void:
	seed(7)
	g = Game.new()
	add_child(g)
	g.modal.connect(func(kind, d): if kind == "enemy_intro": intros.append(d.types))
	Save.meta = Save.default_meta()
	Save._fill()
	var order := DB.map_order
	var prev := 0.0
	for i in order.size():
		var sc: MapScene = DB.maps[order[i]].scene
		_check(sc.waves == 20 + 5 * i, "%s (map %d) has %d waves (want %d)" % [sc.map_name, i + 1, sc.waves, 20 + 5 * i])
		g.new_run(order[i])
		var a := g.level_of(1)
		var b := g.level_of(sc.waves)
		_check(a > prev or i == 0, "%s's wave 1 plays like wave %.1f, tougher than the map before (%.1f), climbing to %.1f" % [sc.map_name, a, prev, b])
		_check(i == 0 or b > a, "  and its waves climb")
		prev = a
	_check(is_equal_approx(DB.maps[order[1]].scene.price, 1.15), "map 2 costs 15%% more (x%.2f)" % DB.maps[order[1]].scene.price)
	g.new_run(order[0])
	_check(is_equal_approx(g.level_of(7), 7.0), "the first map's waves play at their own number")

	var p1 := _types_by_wave(order[0])
	for k in ["phantom", "splitter", "bastion", "anchor", "shieldbearer", "mender"]:
		_check(_first(p1, k) == 0, "%s never comes on the first map" % k)
	_check(_first(p1, "wraith") == 12, "the first map brings Wraiths at wave 12 (%d)" % _first(p1, "wraith"))
	_check(_first(p1, "runner") == 3 and _first(p1, "brute") == 6, "the first map brings Runners at 3 and Brutes at 6 (%d, %d)" % [_first(p1, "runner"), _first(p1, "brute")])
	var p2 := _types_by_wave(order[1])
	_check(p2[1].has("brute") and p2[1].has("wraith"), "map 2 has Brutes and Wraiths from wave 1")
	_check(_first(p2, "phantom") == 10, "map 2 introduces Phantoms at 10 (%d)" % _first(p2, "phantom"))
	_check(_first(p2, "splitter") == 0 and _first(p2, "mender") == 0, "map 2 has no Splitters or Menders (later maps bring them)")
	for i in order.size():
		_check(DB.maps[order[i]].scene.new_enemies.size() <= 1, "%s brings in at most one new enemy" % DB.maps[order[i]].scene.map_name)
	var last := _types_by_wave(order[order.size() - 1])
	var all_in := true
	for k in DB.special_enemies:
		all_in = all_in and _first(last, k) > 0
	_check(all_in, "every special enemy comes on the last map")

	# the new-enemy window: once per type, as its wave starts
	Save.meta.intro = {}
	g.new_run(order[0])
	g.start_run("vanguard", Array(DB.tower_order).slice(0, 5))
	intros.clear()
	g.start_wave()
	_check(intros.size() == 1 and intros[0] == ["grunt"], "wave 1 introduces the Grunt (%s)" % [intros])
	for k in intros[0] if intros.size() else []:
		Save.meta.intro[k] = true
	g.S.wave_active = false
	g.S.spawn_q.clear()
	intros.clear()
	g.S.wave = 2
	g.start_wave()
	_check(intros.size() == 1 and not intros[0].has("grunt") and intros[0].has("runner"), "wave 3 introduces the Runner, not the Grunt again (%s)" % [intros])

	# the map cards say how hard each map is
	for k in order:
		print("     %s: %s" % [k, Menus.map_rules(DB.maps[k].scene)])
	var leaks := false
	for k in order:
		for e in DB.special_enemies:
			leaks = leaks or Menus.map_rules(DB.maps[k].scene).contains(DB.enemies[e].name)
	_check(not leaks and Menus.map_rules(DB.maps[order[1]].scene).contains("15% more"), "the map cards give prices but never name the enemies a map brings")

	print("MAP PROGRESSION PASS" if fails == 0 else "MAP PROGRESSION FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
