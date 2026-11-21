## Hard and Challenge waves, Lone Tower and flag bearers (Nov 2026), on a bare Game (no UI).
## Hard brings exactly one enemy buff; Challenge stacks two or three modifiers that never clash; modifiers rarely
## repeat; each modifier does what its card says; Lone Tower lets only the picked tower deal damage; a flag bearer is a
## buffed, recoloured enemy that drops a quest, and quests run over several waves with a reward or a penalty.
## Headless: godot --headless --path godot res://tests/wave_modes.tscn
extends Node

var fails := 0
var g: Game
var S: Run
var modals: Array = []


func _check(ok: bool, what: String) -> void:
	print(("  ok  " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _fresh(map_id := "plaza") -> void:
	g.new_run(map_id)
	g.start_run("vanguard", Array(DB.tower_order).slice(0, 5))
	S = g.S
	S.gold = 99999


func _place(n: int, type := "") -> Array:
	var out := []
	var cells := g.build_cells()
	for c in cells:
		if out.size() >= n:
			break
		var tp: String = type if type != "" else DB.tower_order[out.size() % 3]
		if g.build_problem(c.x, c.y, tp) == "":
			g.place_tower(c.x, c.y, tp)
			out.append(S.towers[S.towers.size() - 1])
	return out


func _mode(tough: Array, debuffs := []) -> void:
	S.mode = { kind = "challenge", name = "Test", tough = tough, debuffs = debuffs }


func _ready() -> void:
	get_tree().create_timer(120).timeout.connect(func(): print("WAVE MODES TIMEOUT"); get_tree().quit(1))
	seed(11)
	g = Game.new()
	add_child(g)
	g.modal.connect(func(kind, d): modals.append([kind, d]))
	Save.meta = Save.default_meta()
	Save._fill()
	_fresh()

	# ---- the offers ----
	_place(4)
	S.wave = 12
	var seen := {}
	var offered := 0
	var hard_ok := true
	var chal_ok := true
	var clash := false
	var legend := 0
	for i in 60:
		g.offer_wave_choice()
		var o: Array = g.wave_opts
		var hard: Dictionary = o[1]
		hard_ok = hard_ok and hard.kind == "hard" and (hard.tough as Array).size() == 1 and (hard.get("debuffs", []) as Array).is_empty()
		var c: Dictionary = o[2]
		if c.kind == "challenge":
			var n: int = (c.tough as Array).size() + (c.debuffs as Array).size()
			chal_ok = chal_ok and n >= 2 and n <= 3
		if c.kind == "legendary":
			legend += 1
			chal_ok = chal_ok and (c.tough as Array).size() == 2 and (c.debuffs as Array).size() == 2 and c.req != ""
		for opt in o:
			var ids: Array = opt.get("tough", []) + opt.get("debuffs", [])
			for id in ids:
				clash = clash or g._clashes(id, ids)
				seen[id] = seen.get(id, 0) + 1
				offered += 1
		S.paused = false
	_check(hard_ok, "Hard always brings exactly one enemy buff and no handicap")
	_check(chal_ok, "Challenge brings 2-3 modifiers; Legendary brings 2 buffs, 2 handicaps and a goal")
	_check(not clash, "no card ever stacks clashing modifiers")
	_check(seen.size() >= 24, "60 wave choices show at least 24 different modifiers (%d of %d)" % [seen.size(), g.R.tough.items.size() + g.R.challenges.items.size()])
	var top := 0
	for k in seen:
		top = maxi(top, seen[k])
	_check(top <= offered / 8, "no modifier hogs the offers (most common %d of %d)" % [top, offered])
	_check(legend >= 1 and legend <= 15, "Legendary waves are rare (%d of 60)" % legend)
	var hr: Dictionary = g.wave_reward(13, "hard", false, 3)
	var nr: Dictionary = g.wave_reward(13, "normal")
	var cr: Dictionary = g.wave_reward(13, "challenge", false, 6)
	_check(hr.gold > nr.gold and cr.gold > hr.gold and cr.perk, "harder waves pay more (normal %d, hard %d, challenge %d + upgrade)" % [nr.gold, hr.gold, cr.gold])

	# ---- the enemy buffs ----
	S.wave = 8
	_mode([])
	S.enemies.clear()
	g.spawn("brute")
	var base: Enemy = S.enemies[0]
	_mode(["hp", "armor", "unslow", "unstun", "ghost", "anchored"])
	g.spawn("brute")
	g.spawn("grunt")
	var b2: Enemy = S.enemies[1]
	var gr: Enemy = S.enemies[2]
	_check(is_equal_approx(b2.max, base.max * 2.0 * g.R.anchored_hp), "Thick Hide doubles HP (and Anchored adds 30%%): %d vs %d" % [b2.max, base.max])
	_check(is_equal_approx(b2.armor, minf(0.85, base.armor * 2)) and is_equal_approx(gr.armor, g.R.tough_armor), "Plated doubles armor and gives unarmored enemies some")
	g.slow_enemy(gr, 0.5, 2.0, true)
	_check(gr.slow == 0.0, "Unshakable: no slow works at all")
	_check(gr.unstun and gr.unblockable and gr.pushback_immune, "Unstoppable, Ethereal and Anchored")
	S.enemies.clear()
	_mode([])
	var q0: int = g.make_wave(8, S.mode).size()
	_mode(["horde"])
	var qh: int = g.make_wave(8, S.mode).size()
	_mode(["escort"])
	var qe: Array = g.make_wave(8, S.mode)
	_check(qh >= int(q0 * 1.45), "Horde brings 50%% more enemies (%d vs %d)" % [qh, q0])
	_check(qe.count("knight") >= 2, "Escorted adds two Rift Knights")
	_mode(["brood"])
	g.spawn("grunt")
	var gb: Enemy = S.enemies[0]
	g.damage(gb, 99999, null, 1)
	_check(S.enemies.filter(func(e): return e.type == "runner").size() == 2, "Brood: a dead enemy splits into 2 Runners")
	S.enemies.clear()

	# ---- the handicaps ----
	var ts: Array = S.towers
	var t0: Tower = ts[0]
	_mode([])
	var r0 := g.t_range(t0)
	var hr0 := g.hero_range(S.hero)
	_mode([], ["short"])
	_check(is_equal_approx(g.t_range(t0), r0 * 0.5) and is_equal_approx(g.hero_range(S.hero), hr0 * 0.5), "Short Sight halves tower and hero range")
	_mode([], ["lockdown"])
	_check(g.build_problem(0, 0, DB.tower_order[0]).begins_with("Lockdown"), "Lockdown: no building")
	_mode([], ["poor"])
	g.spawn("grunt")
	var gold0 := S.gold
	g.damage(S.enemies[0], 99999, null, 1)
	_check(S.gold == gold0, "Lean Times: kills give no gold")
	S.enemies.clear()
	_mode([], ["fragile"])
	g.spawn("brute")
	var lives0 := S.lives
	g._leak(S.enemies[0])
	_check(S.lives == lives0 - 2 * DB.enemies.brute.lives, "Fragile Base: a leak costs double base HP (%d -> %d)" % [lives0, S.lives])
	S.lives = lives0
	S.enemies.clear()
	_mode([], ["silenced"])
	S.hero.ab.t = 0
	g.use_ability()
	_check(S.hero.ab.t == 0, "Silenced: the ability can't be used")
	_mode([], ["burnout"])
	S.mode.off = t0
	_check(g.tower_off(t0) and not g.tower_off(ts[1]), "Burnout shuts down only the named tower")
	var lines := g.mode_lines(S.mode)
	_check(lines[0].rule.contains(g.tower_name(t0)), "Burnout's card names the tower (%s)" % lines[0].rule)

	# ---- Lone Tower ----
	S.wave_active = false
	modals.clear()
	g.wave_opts = [{ kind = "challenge", name = "Challenge", tough = [], debuffs = ["lonetower"], reward = g.wave_reward(9, "challenge", false, 4) }]
	g.choose_mode(0)
	_check(modals.size() == 1 and modals[0][0] == "lone_pick" and (modals[0][1].towers as Array).size() >= 2, "choosing Lone Tower asks which tower")
	g.set_lone_tower(ts[1])
	_check(S.lone_tower == ts[1], "the picked tower is the lone tower")
	g.spawn("grunt")
	var e: Enemy = S.enemies[0]
	var hp0 := e.hp
	g.damage(e, 10, t0)
	_check(e.hp == hp0, "another tower deals no damage")
	g.damage(e, 10, null)
	_check(e.hp == hp0, "the hero deals no damage")
	g.damage(e, 10, ts[1], 1)
	_check(is_equal_approx(hp0 - e.hp, 10 * g.R.lone_pick_dmg), "the lone tower deals double (%.1f)" % (hp0 - e.hp))
	_check(is_equal_approx(g.t_range(ts[1]), g.t_range(t0) / g.t_range(t0) * ts[1].range * (1 + S.hero.tower_range) * g.R.lone_pick_range) or g.t_range(ts[1]) > ts[1].range, "the lone tower reaches further")
	S.enemies.clear()

	# ---- flag bearers ----
	_fresh()
	_place(3)
	S.wave = 3
	var any_early := false
	for i in 300:
		g.roll_flag_bearer()
		any_early = any_early or S.flag_in >= 0
	_check(not any_early, "no flag bearers in the first map's first 5 waves")
	S.wave = 9
	S.spawn_q = g.make_wave(10, S.mode)
	var rolled := 0
	for i in 2000:
		g.roll_flag_bearer()
		rolled += int(S.flag_in >= 0)
	_check(rolled > 50 and rolled < 160, "about 5%% of waves have a flag bearer (%d of 2000)" % rolled)
	S.flag_in = 0
	_mode([])
	S.mode.kind = "normal"
	g.spawn("grunt")
	g.spawn("grunt")
	var fb: Enemy = S.enemies[0]
	var plain: Enemy = S.enemies[1]
	_check(fb.flag and not plain.flag, "only one enemy becomes the flag bearer")
	_check(fb.max > plain.max * 2 and fb.color != plain.color, "the flag bearer is buffed and recoloured")
	g.damage(fb, 999999, null, 1)
	_check(S.quest_drop != null, "killing it drops a quest")
	S.hero.x = S.quest_drop.x + 200
	S.hero.y = S.quest_drop.y
	S.enemies.clear()
	S.wave_active = false
	g.update(1.0 / 30)
	_check(S.quest_drop != null, "the quest stays on the ground until the hero comes")
	modals.clear()
	S.hero.x = S.quest_drop.x
	S.hero.y = S.quest_drop.y
	S.hero.tx = null
	g.update(1.0 / 30)
	_check(S.quest_drop == null and S.quest_offer != null and modals.any(func(m): return m[0] == "quest"), "walking over it offers the quest")
	_check(S.quest_offer.need >= 3, "a quest takes several waves (%d)" % S.quest_offer.need)
	g.answer_quest(false)
	_check(S.quest == null and S.quest_offer == null, "a quest can be thrown away")

	# accept a build ban, break it: the penalty lands
	S.quest_offer = g.make_quest()
	S.quest_offer.id = "nobuild"
	S.quest_offer.penalty = { k = "gold", v = 0.4, label = "lose 40% of your gold" }
	g.answer_quest(true)
	S.gold = 1000
	_place(1)
	var paid := g.tower_cost(DB.tower_order[0])
	_check(S.quest == null and S.gold <= floorf((1000 - paid) * 0.6) + 1, "building during No New Ground fails it and takes 40%% of the gold (%d)" % S.gold)

	# accept Miser and see it through: the reward comes after its waves, not before
	S.quest_offer = g.make_quest()
	S.quest_offer.id = "miser"
	S.quest_offer.need = 3
	S.quest_offer.reward = { k = "towers", v = 0.12, label = "+12% tower damage" }
	g.answer_quest(true)
	var tb := S.tower_bonus
	for w in 3:
		var msgs := []
		S.wave += 1
		g.quest_wave_end(msgs)
		if w < 2:
			_check(S.quest != null and S.tower_bonus == tb, "after %d wave(s) the quest is still running" % (w + 1))
	_check(S.quest == null and is_equal_approx(S.tower_bonus, tb + 0.12), "after 3 waves Miser pays out")

	print("WAVE MODES PASS" if fails == 0 else "WAVE MODES FAIL (%d)" % fails)
	get_tree().quit(1 if fails else 0)
