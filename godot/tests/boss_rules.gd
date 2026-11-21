## Boss rules (Nov 2026): the Rift Tyrant's Roar stuns the hero for 1s and never throws it back (or off Hold); the
## Tyrant getting through ends the run even with a Phoenix Core or Second Chance; the hero panel shows armor pen for the
## damage heroes (Striker, Sniper) and armor for everyone else. Headless: godot --headless --path godot res://tests/boss_rules.tscn
extends Node

var fails := 0
var main: Main
var g: Game
var S: Run


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


## All the text in a control and its children.
func _text(n: Node) -> String:
	var s := ""
	if n is Label or n is Button:
		s += n.text + "\n"
	elif n is RichTextLabel:
		s += n.get_parsed_text() + "\n"
	for c in n.get_children():
		s += _text(c)
	return s


func _ready() -> void:
	get_tree().create_timer(120).timeout.connect(func(): print("BOSS RULES TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var meta0: Dictionary = Save.meta.duplicate(true)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await _frames()
	main.ui.menus.start_test_room()
	await _frames(5)
	g = main.game
	S = g.S

	# Roar: a 1s stun, no throw, Hold stays on
	g.test_swap_hero("vanguard", false)
	g.test_clear()
	await _frames(3)
	var h := S.hero
	h.x = 400.0
	h.y = 400.0
	h.tx = null
	h.hold = true
	g.spawn("tyrant", 300.0)
	var ty: Enemy = S.enemies.back()
	ty.speed = 0.0
	ty.x = h.x + 40
	ty.y = h.y
	g.boss_power(ty, ty.data)
	_check(h.x == 400.0 and h.y == 400.0 and h.hold, "Roar doesn't throw the hero or knock it off Hold (%.0f, %.0f, hold %s)" % [h.x, h.y, h.hold])
	var t := 0.0
	while t < 1.05:
		g.update(0.05)
		t += 0.05
	_check(absf(h.stun_t - (1.0 - 0.05)) < 0.06 and h.x == 400.0, "Roar stuns the hero for about 1s (%.2f left just after it lands)" % h.stun_t)
	h.hold = false
	g.test_clear()

	# the Tyrant at the gate ends the run, Phoenix Core and Second Chance or not
	S.test = false
	S.mod_phoenix = true
	S.second_chance = true
	S.lives = 50
	g.spawn("tyrant", 10.0)
	var ended := g._leak(S.enemies.back())
	_check(ended and S.lives == 0 and S.over and S.mod_phoenix and S.second_chance, "the Tyrant getting through ends the run (lives %d, over %s, Phoenix and Second Chance unused)" % [S.lives, S.over])
	# a normal enemy still meets the Phoenix Core
	S.over = false
	S.lives = 1
	g.spawn("grunt", 10.0)
	var e: Enemy = S.enemies.back()
	e.lives = 5
	g._leak(e)
	_check(S.lives == 10 and not S.mod_phoenix, "the Phoenix Core still saves the base from anything else (lives %d)" % S.lives)
	S.test = true
	S.over = false
	S.lives = Game.TEST_LIVES
	Save.meta = meta0
	Save.save_meta()

	# the hero panel: armor pen for the damage heroes, armor for the rest
	for k in ["striker", "sniper", "vanguard", "gale", "oracle", "wizard"]:
		if not DB.heroes.has(k):
			continue
		g.test_swap_hero(k, false)
		g.test_clear()
		S.hero.armor_pen = 70.0
		main.ui._panel_show("hero")
		main.ui.render_hero()
		await _frames(2)
		var txt := _text(main.ui.hero_card)
		var pen := txt.contains("Armor pen")
		var arm := txt.contains("Armor\n") or RegEx.create_from_string("(?m)^Armor$").search(txt) != null
		var dmg: bool = k in ["striker", "sniper"]
		_check(pen == dmg and arm != dmg, "%s's stats show %s" % [k, "armor pen (not armor)" if dmg else "armor (not armor pen)"] + ("" if pen == dmg and arm != dmg else " — pen %s, armor %s" % [pen, arm]))

	print("BOSS RULES PASS" if fails == 0 else "BOSS RULES FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
