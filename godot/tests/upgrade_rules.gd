## The tower upgrade rebalance's rules (tests/_review, UPGRADE_CHANGES_SPEC): Brittle is a damage amp only (armor is
## cut by shred), burns stack 3 per tower, the Beacon pick ignores gold, merges keep the better "every Nth shot", Disc
## hybrids carry their Disc paths, Crushing Tide fades in 3s, Rocket Shells fly 1.4x as fast, Pin has a cooldown and
## Flash Freeze holds bosses 0.4s. Headless: godot --headless --path godot res://tests/upgrade_rules.tscn
extends Node

var fails := 0
var g: Game
var S: Run


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


## A tower of `type` on a free build cell near `at` (or anywhere).
func _place(type: String, at := Vector2(-1, -1)) -> Tower:
	var best := Vector2i(-1, -1)
	for c in g.build_cells():
		if g.build_problem(c.x, c.y, type) != "":
			continue
		if best.x < 0 or at.x >= 0 and g.cell_pos(c.x, c.y).distance_to(at) < g.cell_pos(best.x, best.y).distance_to(at):
			best = c
	g.place_tower(best.x, best.y, type)
	return S.towers[S.towers.size() - 1]


func _max(t: Tower) -> void:
	var guard := 0
	while t.lvl < g.R.max_level and guard < 20:
		var picked = null
		for o in g.tower_options(t):
			if g.path_state(t, o) == "open":
				picked = o
				break
		if picked == null:
			break
		g.level_tower(t, picked)
		guard += 1


## A still enemy of `type` a little way down the road, with lots of HP.
func _dummy(type: String, d := 300.0) -> Enemy:
	g.spawn(type, d)
	var e: Enemy = S.enemies[S.enemies.size() - 1]
	e.speed = 0.0
	e.max = 1e7
	e.hp = 1e7
	return e


func _ready() -> void:
	get_tree().create_timer(120).timeout.connect(func(): print("UPGRADE RULES TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames()
	main.ui.menus.start_test_room()
	await _frames(5)
	g = main.game
	S = g.S
	S.hero.x = -500
	S.hero.ko = 999.0

	# X1: Brittle only amplifies; armor stays unless something shreds it
	var arc := _place("arcane")
	var w := _dummy("warden")
	w.brittle = 0.24
	w.brittle_t = 5.0
	var a := g.armor_of(w, arc)
	var hp0 := w.hp
	g.damage(w, 100.0, arc)
	_check(a > 0.4 and absf((hp0 - w.hp) - 100.0 * 1.24 * (1.0 - a)) < 0.01, "X1: a brittle Warden keeps its armor (%.2f) and takes %.1f of 100 (want %.1f)" % [a, hp0 - w.hp, 124.0 * (1.0 - a)])
	g.shred_enemy(w, 0.2, 2.0)
	_check(absf(g.armor_of(w, arc) - (a - 0.2)) < 0.001, "X1: shred cuts armor (%.2f -> %.2f)" % [a, g.armor_of(w, arc)])
	g.test_clear()

	# X3: Frostfire burns stack up to 3 per tower
	var fr := _place("frost")
	fr.frostfire = 0.5
	var e := _dummy("grunt")
	e.slow_t = 10.0
	e.slow = 0.3
	for i in 4:
		g.apply_hit(fr, e, 100.0)
	var mine := e.burns.filter(func(b): return b.src == fr)
	var dps := 0.0
	for b in mine:
		dps += b.dps
	_check(mine.size() == 3 and absf(dps - 3 * 25.0) < 0.01, "X3: 4 Frostfire hits keep 3 burn stacks, %.0f burn dps (want 75)" % dps)
	_check(g.is_burning(e), "X3: a burning enemy counts as burning")
	g.test_clear()

	# X4: the strongest Beacon ignores gold
	var t4 := _place("arcane", Vector2(480, 300))
	var tithe := _place("beacon", t4.pos())
	var emp := _place("beacon", t4.pos())
	tithe.b_dmg = 0.15
	tithe.b_gold = 0.4
	emp.b_dmg = 0.47
	g.compute_buffs()
	_check(t4.buff != null and (t4.buff.from as Array).has(emp) and not (t4.buff.from as Array).has(tithe),
		"X4: a tower between a Tithe 4/4 and an Empower 4/4 Beacon takes the Empower one")
	for t in [t4, tithe, emp]:
		S.towers.erase(t)
	S.gold = Game.TEST_GOLD

	# X5: merges keep the better "every Nth shot"
	var pa := _place("plasma")
	var mo := _place("mortar")
	_max(pa)
	_max(mo)
	pa.orbital = 4
	mo.orbital = 3
	pa.surge = 0
	mo.surge = 5
	g.try_merge(pa, mo)
	var m5: Tower = S.towers.filter(func(t): return t.hybrid).back() if S.towers.any(func(t): return t.hybrid) else null
	_check(m5 != null and int(m5.orbital) == 3 and int(m5.surge) == 5, "X5: orbital 4 + 3 merges to every 3rd, surge 0 + 5 keeps 5 (%s, %s)" % [m5.orbital if m5 else -1, m5.surge if m5 else -1])
	if m5:
		S.towers.erase(m5)

	# X6: Disc hybrids carry Long Flight, Searing Path and Heavy Edge
	var di := _place("disc")
	var ar := _place("arcane")
	_max(di)
	_max(ar)
	di.disc_hits = 14.0 # Long Flight 4/4
	di.disc_trail = 0.32 # Searing Path 4/4
	di.disc_boss_bonus = 0.4
	di.disc_heavy = false
	g.try_merge(ar, di)
	var m6: Tower = S.towers.filter(func(t): return t.hybrid).back() if S.towers.any(func(t): return t.hybrid) else null
	_check(m6 != null and int(m6.pierce) == 7 and m6.brittle >= 0.32 - 1e-6 and absf(m6.boss_bonus - 0.4) < 1e-6,
		"X6: Disc (Long Flight + Searing Path 4/4) merges to pierce 7, brittle 0.32, boss +40%% (%s, %s, %s)" % [m6.pierce if m6 else -1, m6.brittle if m6 else -1, m6.boss_bonus if m6 else -1])
	if m6:
		S.towers.erase(m6)
	S.gold = Game.TEST_GOLD

	# X7: Crushing Tide fades over exactly 3s
	var an := _place("anvil")
	an.tide = true
	an.pin = 0.0
	g.test_clear()
	var ct := _dummy("grunt", 100.0)
	ct.speed = 20.0
	ct.still_t = 2.0
	var tt := 0.0
	var at29 := -1.0
	while tt < 3.1:
		g.update(0.05)
		tt += 0.05
		if absf(tt - 2.9) < 0.026:
			at29 = ct.still_t
	_check(at29 > 0.0 and ct.still_t == 0.0, "X7: Crushing Tide still holds some pressure at 2.9s (%.2f) and none at 3.1s (%.2f)" % [at29, ct.still_t])
	# Rocket Shells: 40% faster
	S.sig["mortar"] = true
	var mt := _place("mortar")
	var tgt := _dummy("grunt")
	g.lob_shell(mt, tgt, 1.0)
	_check(absf(S.shells.back().T - Game.SHELL_TIME / 1.4) < 1e-6, "X7: Rocket Shells take %.3fs (want %.3f)" % [S.shells.back().T, Game.SHELL_TIME / 1.4])
	S.sig.erase("mortar")
	g.test_clear()

	# Pin can't hold the same enemy again for 2s after it ends
	an.pin = 0.6
	var pe := _dummy("grunt")
	pe.stun_t = 0.1
	g.anvil_slam(an, [pe], 1.0)
	var first := pe.stun_t
	pe.stun_t = 0.1
	g.anvil_slam(an, [pe], 1.0)
	_check(absf(first - 0.6) < 1e-6 and absf(pe.stun_t - 0.1) < 1e-6 and pe.pin_cd > 2.5, "Pin: pinned 0.6s, then not again while its cooldown runs (%.2f, %.2f, cd %.2f)" % [first, pe.stun_t, pe.pin_cd])
	g.test_clear()

	# Flash Freeze: 1.2s, bosses 0.4s
	var ff := _place("frost")
	var boss := _dummy("warden")
	var grunt := _dummy("grunt", 200.0)
	g.apply_hit(ff, boss, 1.0, true)
	g.apply_hit(ff, grunt, 1.0, true)
	_check(absf(boss.stun_t - 0.4) < 1e-6 and absf(grunt.stun_t - 1.2) < 1e-6, "Flash Freeze holds a boss %.1fs and a grunt %.1fs" % [boss.stun_t, grunt.stun_t])

	print("UPGRADE RULES PASS" if fails == 0 else "UPGRADE RULES FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
