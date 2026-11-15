## Checks the reworked Shield Slam in a real run (headless): the enemy in front takes the full hit (armor + 100) and
## is stunned, the shockwave runs about 6 squares on down the path slowing and hitting the rest for half, bosses get
## half the stun and slow, the hero gains a shield that grows per enemy hit, the Taunt upgrade is gone and the new
## Vanguard upgrades work. godot --headless --path godot res://tests/vanguard_slam.tscn
extends Node

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _perk(g: Game, id: String, m := -1.0) -> void:
	for p in g.R.perks.items:
		if p.id == id:
			Fx.run(p.effect, { h = g.S.hero, run = g.S, m = p.m if m < 0 else m })
			return
	_check(false, "perk " + id + " exists")


func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func(): print("SLAM TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.meta.abilities = Save.meta.get("abilities", {})
	Save.meta.abilities["vanguard"] = "main"
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("vanguard", ["plasma"])
	for i in 5:
		await get_tree().process_frame
	var g := main.game
	var h := g.S.hero
	var a := h.ab
	_check(a.id == "slam", "vanguard has Shield Slam")
	_check(g.R.perks.items.filter(func(p): return p.id == "taunt").is_empty(), "the Taunt upgrade is gone")
	for id in ["broadside", "faultline", "aegisslam", "daze"]:
		var p = g.R.perks.items.filter(func(q): return q.id == id)
		_check(p.size() == 1 and p[0].pool == "vanguard" and p[0].ability == "slam", id + " is a Vanguard Shield Slam upgrade")
	print(Fx.text(a.desc, { a = a }))
	_check(is_equal_approx(g.slam_dmg(h, a), h.armor + 100), "full hit %.0f = armor %.0f + 100" % [g.slam_dmg(h, a), h.armor])
	h.auto_cast = false
	g.start_wave()
	g.S.enemies.clear()
	var P := g.S.map.path_len * 0.5
	var hp := g.pos_at(P)
	h.x = hp.x
	h.y = hp.y
	h.tx = null
	var mk := func(type: String, d: float) -> Enemy:
		g.spawn(type, d)
		var e: Enemy = g.S.enemies[g.S.enemies.size() - 1]
		e.speed = 0
		e.hp = 1e6
		e.max = 1e6
		e.armor = 0
		return e
	var front: Enemy = mk.call("grunt", P - 30)
	var mid: Enemy = mk.call("grunt", P - 120)
	var boss: Enemy = mk.call("knight", P - 200)
	var far: Enemy = mk.call("grunt", P - 330)
	var behind: Enemy = mk.call("grunt", P + 60)
	boss.armor = 0
	g.slam(h, a, 1.0, front.pos())
	_check(absf((1e6 - front.hp) - g.slam_dmg(h, a)) < 1.0, "front takes the full hit (%.0f)" % (1e6 - front.hp))
	_check(is_equal_approx(front.stun_t, a.stun), "front stunned %.1fs" % front.stun_t)
	_check(mid.stun_t <= 0 and mid.hp == 1e6, "nothing else hit at the moment of impact")
	var sh0 := h.shield
	_check(is_equal_approx(sh0, a.shield + a.shield_per), "shield %.0f right away (base + 1 hit)" % sh0)
	await get_tree().create_timer(0.8).timeout
	_check(mid.slow_t > 0 and mid.slow > 0 and mid.stun_t <= 0, "mid slowed %.0f%% for %.1fs, not stunned" % [mid.slow * 100, mid.slow_t])
	_check(absf((1e6 - mid.hp) - g.slam_dmg(h, a) * 0.5) < 1.0, "mid takes half (%.0f)" % (1e6 - mid.hp))
	_check(boss.slow_t > 0 and boss.slow_t <= a.slow_t * 0.5 + 0.01, "boss slowed for half as long (%.2fs)" % boss.slow_t)
	_check(far.hp == 1e6 and far.slow_t <= 0, "an enemy 7.5 squares on is out of reach")
	_check(behind.hp == 1e6, "an enemy behind the hero isn't hit")
	_check(h.shield > sh0 and is_equal_approx(h.shield_max, a.shield + 3 * a.shield_per), "shield grows with each hit (%.0f)" % h.shield_max)
	# bosses stunned half as long by the full hit
	boss.stun_t = 0
	g.slam(h, a, 1.0, boss.pos())
	await get_tree().process_frame
	# upgrades
	var t0 := a.targets
	_perk(g, "broadside")
	_check(a.targets == t0 + 1, "Broad Shield: %d targets" % a.targets)
	var r0 := a.reach
	_perk(g, "faultline")
	_check(is_equal_approx(a.reach, r0 + 40), "Fault Line: reach %.0f" % a.reach)
	var s0 := a.shield
	_perk(g, "aegisslam")
	_check(a.shield > s0, "Aegis Slam: shield %.0f" % a.shield)
	var st0 := a.stun
	var sl0 := a.slow_t
	_perk(g, "daze")
	_check(a.stun > st0 and a.slow_t > sl0, "Concussion: stun %.2f slow %.2f" % [a.stun, a.slow_t])
	g.S.enemies.clear()
	var e1: Enemy = mk.call("grunt", P - 25)
	var e2: Enemy = mk.call("knight", P - 45)
	e2.armor = 0
	g.slam(h, a, 1.0, e1.pos())
	_check(e1.stun_t > 0 and e2.stun_t > 0, "two enemies take the full hit with Broad Shield")
	_check(is_equal_approx(e2.stun_t, a.stun * 0.5), "boss stunned half as long (%.2f of %.2f)" % [e2.stun_t, a.stun])
	print(UiText.ability_tip(g, h))
	print("SLAM DONE, %d failed" % fails)
	get_tree().quit(1 if fails else 0)
