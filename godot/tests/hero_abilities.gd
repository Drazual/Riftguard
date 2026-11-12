## Checks this round's hero balance changes in a real run (headless):
## the Striker's Rift Nova grows with its hero damage, Armor Piercing lets its shots through armor, Piercing Shot
## starts at 2.0x, and the Sniper's Radiation Field upgrade leaves a field after Orbital Strike that hurts and
## slows for 4s. godot --headless --path godot res://tests/hero_abilities.tscn
extends Node

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _run(hero: String, alt: bool) -> Main:
	Save.meta.abilities = Save.meta.get("abilities", {})
	Save.meta.abilities[hero] = "alt" if alt else "main"
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run(hero, ["plasma"])
	for i in 5:
		await get_tree().process_frame
	return main


func _perk(g: Game, id: String, m := -1.0) -> void:
	for p in g.R.perks.items:
		if p.id == id:
			Fx.run(p.effect, { h = g.S.hero, run = g.S, m = p.m if m < 0 else m })
			return
	_check(false, "perk " + id + " exists")


func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): print("ABIL TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	# Striker: Rift Nova scales with hero damage
	var m := await _run("striker", false)
	var g := m.game
	var h := g.S.hero
	_check(h.ab.id == "nova", "striker has Rift Nova")
	var n0 := g.nova_dmg(h, h.ab)
	h.dmg *= 2
	var n1 := g.nova_dmg(h, h.ab)
	_check(absf(n1 - 2 * n0) < 0.01, "nova %.0f -> %.0f when hero damage doubles" % [n0, n1])
	# Armor Piercing: shots ignore 20% of armor per pick
	g.start_wave()
	g.spawn("brute", g.S.map.path_len * 0.3)
	var e: Enemy = g.S.enemies[g.S.enemies.size() - 1]
	e.armor = 0.5
	var a0 := g.armor_of(e, null, h.armor_pen)
	_perk(g, "armorpen")
	_check(h.armor_pen > 0.19, "armor_pen %.2f after Armor Piercing" % h.armor_pen)
	var a1 := g.armor_of(e, null, h.armor_pen)
	_check(a1 < a0, "armor against the hero %.2f -> %.2f" % [a0, a1])
	var hp := e.hp
	g.damage(e, 100, null, 0, false, h.armor_pen)
	_check(absf((hp - e.hp) - 100 * (1 - a1)) < 0.5, "a 100 hit deals %.0f" % (hp - e.hp))
	m.queue_free()
	await get_tree().process_frame
	# Sniper: Piercing Shot 2.0x
	m = await _run("sniper", false)
	_check(m.game.S.hero.ab.id == "pierce" and is_equal_approx(m.game.S.hero.ab.mult, 2.0), "Piercing Shot %.1fx" % m.game.S.hero.ab.mult)
	m.queue_free()
	await get_tree().process_frame
	# Sniper with Orbital Strike: Radiation Field
	m = await _run("sniper", true)
	g = m.game
	h = g.S.hero
	_check(h.ab.id == "strike", "sniper alt is Orbital Strike")
	_perk(g, "radfield")
	_check(is_equal_approx(h.ab.rad_t, 4.0), "radiation field lasts %.1fs" % h.ab.rad_t)
	g.start_wave()
	for k in 4:
		g.spawn("grunt", g.S.map.path_len * 0.35 + k * 6)
	var tgt: Enemy = g.S.enemies[g.S.enemies.size() - 1]
	g.S.pointer = tgt.pos()
	h.ab.t = 0
	g.use_ability()
	if g.S.strike_ready:
		g.use_ability() # the first press only shows where it lands
	print("strike ready ", g.S.strike_ready, " cooldown ", h.ab.t)
	await get_tree().create_timer(1.2).timeout
	var rad := g.S.zones.filter(func(z): return z.get("rad", false))
	_check(rad.size() == 1, "a radiation field is on the ground")
	if rad.size():
		_check(rad[0].slow > 0 and rad[0].dps > 0, "it slows %.0f%% and burns %.1f/s" % [rad[0].slow * 100, rad[0].dps])
	await get_tree().create_timer(4.0).timeout
	_check(g.S.zones.filter(func(z): return z.get("rad", false)).is_empty(), "gone after 4s")
	print("ABILITIES DONE, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
