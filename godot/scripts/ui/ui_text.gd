## The words the panels and tooltips show: what a tower does, "current -> new" previews, ability texts.
class_name UiText
extends RefCounted

const ROLE_LEVEL := {
	offensive = "+2% damage, +1% range, +1.5% attack speed",
	defensive = "+3% max HP, +0.5% damage reduction, +0.2% of max HP as regen per second",
	support = "+1% range and aura reach, +1% XP gain",
	special = "+4% spell damage, +3 max mana, +0.15 mana per second",
}
const CATEGORIES := [["offensive", "Offensive"], ["defensive", "Defensive"], ["support", "Support"], ["special", "Special"]]


static func pct(v: float) -> String:
	return str(int(round(v * 100))) + "%"


static func f0(v: float) -> String:
	return str(int(round(v)))


static func f1(v: float) -> String:
	return "%.1f" % v


static func f2(v: float) -> String:
	return "%.2f" % v


static func block_text(n: int) -> String:
	return "All" if n >= Game.ALL_BLOCK else str(n)


static func main_effect(k: String) -> String:
	return "slow strength" if k == "frost" else ("damage buff" if k == "beacon" else "damage")


# ---------- what a tower does ----------
static func traits(g: Game, t: Tower) -> Array:
	var S := g.S
	var out := ["Shoots the enemy closest to your base" + (", plus %d more at once." % int(t.multi) if t.multi else ".")]
	if t.splash: out.append("Explodes on hit, damaging all enemies within %s." % f0(t.splash))
	if t.slow: out.append("Slows enemies by %d%% for %ss." % [int(round(minf(0.85, t.slow + S.mod_slow) * 100)), f1(t.slow_dur if t.slow_dur else 1.6)])
	if t.chain: out.append("Lightning jumps to %d more enemies at %s damage, less each jump." % [int(t.chain), pct(t.chain_mul if t.chain_mul else 0.7)])
	if t.burn: out.append("Burns enemies for %s of hit damage over 2s." % pct(t.burn))
	if t.ramp and not t.beam: out.append("Gains +%s damage per hit in a row on the same enemy (5 stacks)." % pct(t.ramp))
	if t.surge: out.append("Every %dth shot deals triple damage." % int(t.surge))
	if t.brittle: out.append("Slowed enemies take +%s damage from everything." % pct(t.brittle))
	if t.mark: out.append("Marks enemies to take +%s damage for 2s." % pct(t.mark))
	if t.cluster: out.append("Throws %d bomblets per shot." % int(t.cluster))
	if t.orbital: out.append("Every %dth shot is a huge triple-damage blast." % int(t.orbital))
	if t.freeze: out.append("Every %dth shot freezes enemies for 1.2s." % int(t.freeze))
	if t.zero: out.append("Constantly slows every enemy in range by %s." % pct(t.zero))
	if t.beam: out.append("Beam heat: +%s damage per tick on the same target, up to %d ticks (+%s).%s%s" % [pct(t.ramp), int(t.ramp_max), pct(t.ramp * t.ramp_max),
		" Double damage at full heat." if t.melt else "", " Keeps half its heat when switching." if t.retain else ""])
	if t.lob: out.append("Lobs shells up to %s away; they land a moment later.%s%s%s" % [f0(g.t_range(t)), (" A second shell follows for %s." % pct(t.salvo)) if t.salvo else "",
		" Leaves burning ground." if t.firestorm else "", " Every 4th shell stuns." if t.quake_stun else ""])
	if t.hypo: out.append("Hits add chill stacks; at %d stacks the enemy freezes for 0.8s (bosses 0.3s)%s" % [int(t.hypo), " and the freeze bursts to enemies within 70." if t.cold_snap else "."])
	if t.stun: out.append("Lightning jumps have a %s chance to stun." % pct(t.stun))
	if t.prism: out.append("Hits split to %s nearby enemies for 40%% damage." % f0(t.prism))
	if t.execute: out.append("Finishes non-boss enemies below %s HP." % pct(t.execute))
	if t.nova: out.append("Every 6th shot blasts everything in range for %s damage." % pct(t.nova))
	if t.echo: out.append("Shots echo for %s damage." % pct(t.echo))
	if t.death_blast: out.append("Kills explode for %s of max HP." % pct(t.death_blast))
	if t.gravity: out.append("Every 5th shot drags enemies %s back." % f0(t.gravity))
	if t.time_lock: out.append("Every 8th shot stuns everything in range for %ss." % f2(t.time_lock))
	if t.shatter: out.append("Stunned enemies take +%s damage from it." % pct(t.shatter))
	if t.frostfire: out.append("Slowed enemies burn for %s of each hit." % pct(t.frostfire))
	if t.storm: out.append("Every 4th shot calls lightning on %s enemies." % f0(t.storm))
	if t.chain_blast: out.append("Lightning jumps explode for %s damage." % pct(t.chain_blast))
	if t.overload: out.append("Every 10th shot deals +%s damage and stuns." % pct(t.overload))
	if t.pierce: out.append("Shots pierce %s enemies behind the target." % f0(t.pierce))
	if t.loot: out.append("Kills drop +%s gold." % f0(t.loot))
	if t.leech: out.append("Kills heal your hero %s HP." % f0(t.leech))
	if t.tempo: out.append("Each shot speeds up the next by %s (5 stacks)." % pct(t.tempo))
	if t.hex: out.append("Brands enemies: every second they pulse %s of all damage they took to themselves and enemies within 60." % pct(t.hex))
	if t.hex_nova: out.append("Branded enemies explode on death for %s of the damage they took." % pct(t.hex_nova))
	if t.buff:
		var bf: Dictionary = t.buff
		out.append("Beacon buff: +%s damage%s%s%s." % [pct(bf.dmg), (", +%s fire rate" % pct(bf.rate)) if bf.rate else "", (", +%s range" % pct(bf.range)) if bf.range else "",
			(", ignores %s armor" % pct(bf.sunder)) if bf.sunder else ""])
	return out


static func support_traits(g: Game, t: Tower) -> Array:
	var out := ["Buffs every tower within %s. Buffed towers deal +%s damage." % [f0(g.t_range(t)), pct(t.b_dmg)]]
	if t.b_rate: out.append("Buffed towers fire %s faster." % pct(t.b_rate))
	if t.b_range: out.append("Buffed towers get +%s range." % pct(t.b_range))
	if t.b_sunder: out.append("Buffed towers ignore %s armor." % pct(t.b_sunder))
	if t.b_gold: out.append("Kills by buffed towers give +%s gold." % pct(t.b_gold))
	if t.b_overdrive: out.append("Overdrive: buffed towers crit 10% of the time for triple damage.")
	if t.b_tempo: out.append("Tempo Link: every 10s, buffed towers fire twice as fast for 3s.")
	if t.b_light: out.append("Lighthouse: buffed towers hit enemies within twice their range.")
	if t.b_break: out.append("Armor Break: hits from buffed towers strip 15% armor for 3s (up to 45%).")
	if t.b_rush: out.append("Gold Rush: kills by buffed towers can drop 25 gold coins.")
	if g.S:
		var n := 0
		for x in g.S.towers:
			if x.buff and (x.buff.get("from", []) as Array).has(t):
				n += 1
		out.append("Buffing %d tower(s)." % n)
	return out


static func anvil_traits(g: Game, t: Tower) -> Array:
	var out := ["Slams every %ss, hitting every enemy within %s. Moving enemies take 30%%." % [f1(t.rate * g.S.mod_tower_rate), f0(g.t_range(t))],
		"Stopped enemies (blocked, stunned, frozen) take +%s more per second stopped, up to +%s." % [pct(t.press), pct(t.press_cap)]]
	if t.pin: out.append("Holds stopped enemies in place %ss longer." % f1(t.pin))
	if t.guard: out.append("Your hero takes %s less damage from enemies it blocks in range." % pct(t.guard))
	if t.crush_exec: out.append("Crushes stopped enemies below %s HP." % pct(t.crush_exec))
	if t.shackle: out.append("Every 4th slam roots everything in range for 1s.")
	if t.after: out.append("Each slam has a 50% aftershock.")
	if t.tide: out.append("Pressure fades over 3s instead of resetting.")
	if t.pact: out.append("Slams twice as fast while your hero blocks an enemy in range.")
	if t.buff: out.append("Beacon buff: +%s damage." % pct(t.buff.dmg))
	return out


static func tower_traits(g: Game, t: Tower) -> Array:
	return support_traits(g, t) if t.support else (anvil_traits(g, t) if t.type == "anvil" else traits(g, t))


static func bullets(lines: Array, col := Kit.MUTED) -> String:
	var out := ""
	for l in lines:
		out += Kit.c("• ", Kit.LINE.lightened(0.3)) + Kit.c(l, col) + "\n"
	return out.strip_edges()


static func dmg_with_buff(g: Game, t: Tower) -> String:
	var d := t.dmg * g.S.mod_tower_dmg
	if t.buff:
		return "%s → %s %s" % [f0(d), f0(d * (1 + t.buff.dmg)), Kit.c("(Beacon)", Kit.MUTED)]
	return f0(d)


static func build_tip(g: Game, k: String) -> String:
	var d: TowerData = DB.towers[k]
	var t := g.new_tower(k, 0, 0)
	var s := Kit.b(d.name) + "  " + Kit.c("%d gold" % g.tower_cost(k), Kit.GOLD) + "\n" + Kit.c(DB.tx("tower:" + k, d.info), Kit.MUTED) + "\n"
	s += Kit.c(("Buff +" + pct(t.b_dmg)) if d.support else ("Damage %s · %s shots/s" % [f0(t.dmg), f2(1 / d.rate)]), Kit.TEXT) + Kit.c(" · Range %s" % f0(d.range), Kit.TEXT) + "\n"
	if not DB.is_simple():
		var tr := tower_traits(g, t) if (d.support or k == "anvil") else traits(g, t).slice(1)
		if tr.size():
			s += bullets(tr) + "\n"
	s += Kit.c("Buying one raises its price 50% and every other tower's 15%.", Kit.MUTED) + "\n"
	if g.S.sig.get(k, false):
		s += Kit.c("Signature: %s. %s" % [d.signature_name, DB.tx("sig:" + k, d.signature_desc)], Kit.PINK) + "\n"
	var names := []
	for p in d.paths:
		names.append(p.name)
	s += Kit.c("Paths: %s. Pick up to %d of them (%d with the Oracle) as it levels to %d." % [", ".join(names), DB.rules.path_limit, DB.rules.path_limit + 1, DB.rules.max_level], Kit.MUTED)
	return s


static func tower_tip(g: Game, t: Tower) -> String:
	var S := g.S
	var ups := []
	var opts := g.tower_options(t)
	for id in t.order:
		for u in opts:
			if u.id == id:
				ups.append("%s %d/%d" % [u.name, t.ups_of(id), g.path_max()])
	var kind := " · Super" if t.is_super else (" · Hybrid" if t.hybrid else "")
	var s := Kit.b(g.tower_name(t)) + "  " + Kit.c("Lv %d/%d%s" % [t.lvl, DB.rules.max_level, kind], Kit.GOLD) + "\n"
	if t == S.drained:
		s += Kit.c("Drained: half damage this wave.", Kit.DANGER) + "\n"
	s += Kit.c(g.tower_blurb(t), Kit.MUTED) + "\n"
	s += Kit.c("Damage dealt: %d total, %d this wave · Kills: %d · Takedowns: %d" % [int(round(t.dmg_total)), int(round(t.dmg_wave)), t.kills, t.takedowns], Kit.MUTED) + "\n"
	s += (("Buff +" + pct(t.b_dmg)) if t.support else ("Damage %s · %s shots/s" % [dmg_with_buff(g, t), f2(1 / (t.rate * S.mod_tower_rate))])) + " · Range " + f0(g.t_range(t))
	if not DB.is_simple():
		s += "\n" + bullets(tower_traits(g, t))
	if ups.size():
		s += "\n" + Kit.c("Paths: " + ", ".join(ups), Kit.MUTED)
	return s


# ---------- "current -> new" previews ----------
static func fmt(v: float, k: String) -> String:
	match k:
		"p": return str(int(round(v * 100))) + "%"
		"s": return "%.1fs" % v
		"r": return "%.2f/s" % v
		"x": return "%.1f×" % v
	if absf(v) >= 10 or absf(v - round(v)) < 0.05:
		return str(int(round(v)))
	return "%.1f" % v


static func hero_stats(g: Game, h: Hero) -> Array:
	if g:
		g.sync_aura(h)
	var a := h.ab
	var an := a.name if a else ""
	return [
		["Damage", h.dmg, "n"], ["Attacks", 1 / h.rate, "r"], ["Max HP", h.max_hp, "n"], ["Armor", h.armor, "p"], ["Regen/s", h.regen, "n"],
		["Crit chance", h.crit, "p"], ["Crit damage", h.crit_dmg, "p"], ["Targets", 1 + h.multi, "n"], ["Range", minf(9999, h.range), "n"],
		["Move speed", h.speed, "n"], ["Blocks", mini(h.block, Game.ALL_BLOCK - 1), "n"], ["Respawn", h.respawn, "s"], ["Build range", h.build_range, "n"],
		["Tower aura", h.aura, "p"], ["Aura reach", h.aura_range, "n"], ["Aura slow", h.aura_slow, "p"], ["Heal per kill", h.siphon, "n"],
		["Hero kill gold", h.bounty, "n"], ["Kill gold (all)", h.tithe, "n"], ["Thorns/s", h.thorns, "n"], ["Taunt", h.taunt, "s"],
		["Momentum per kill", h.momentum, "p"], ["Free level-ups near you", h.rapid, "n"], ["Spotter", h.spotter, "p"], ["Boss damage", h.headhunter, "p"],
		["Interest", h.interest, "p"], ["XP gain", h.xp_gain, "p"], ["Brace time", h.brace, "s"], ["Extra hits", h.pierce, "n"], ["Tower range", h.tower_range, "p"],
		["Tower build cost", h.cost_mul, "p"], ["Level-up cost", h.lvl_mul, "p"], ["Merge cost", h.merge_mul, "p"], ["Boss stun reduction", minf(0.8, h.grounded), "p"],
		["Execute below", h.execute, "p"], ["Max mana", h.max_mana, "n"], ["Mana/s", h.mana_regen, "n"], ["Spell damage", h.spell, "p"], ["Spell size", h.spell_r, "p"],
		["Spell cost", h.spell_cost, "p"],
		[an + " damage", a.dmg if a else 0.0, "n"], [an + " cooldown", a.cd if a else 0.0, "s"], [an + " radius", a.r if a else 0.0, "n"],
		[an + " stun", a.stun if a else 0.0, "s"], [an + " duration", a.dur if a else 0.0, "s"], [an + " speed-up", a.power if a else 0.0, "p"], [an + " damage", a.mult if a else 0.0, "x"],
	]


static func run_stats(g: Game) -> Array:
	var S := g.S
	return [
		["All tower damage", S.mod_tower_dmg, "p"], ["All tower fire rate", 1 / S.mod_tower_rate, "p"], ["Kill gold", S.mod_gold, "p"],
		["Base HP", S.lives, "n"], ["Gold", S.gold, "n"], ["Paths per tower", g.path_limit(), "n"], ["Free tower upgrades", S.free_levels, "n"],
		["Tower boss damage", S.mod_boss_dmg, "p"], ["Hero upgrades to pick", S.pending_levels, "n"], ["Hit slow", S.mod_all_slow, "p"], ["Hit burn", S.mod_all_burn, "p"],
		["Enemy HP", S.mod_enemy_hp, "p"], ["Enemy speed", S.mod_enemy_speed, "p"],
	]


static func tower_stats(g: Game, t: Tower) -> Array:
	var S := g.S
	return [
		["Damage", 0.0 if t.support else t.dmg * S.mod_tower_dmg, "n"], ["Shots", 0.0 if t.support else 1 / (t.rate * S.mod_tower_rate), "r"], ["Range", t.range * (1 + S.hero.tower_range), "n"],
		["Blast radius", t.splash, "n"], ["Slow", t.slow, "p"], ["Slow time", t.slow_dur, "s"], ["Jumps", t.chain, "n"], ["Jump power", t.chain_mul, "p"],
		["Jump reach", t.chain_reach, "n"], ["Extra targets", t.multi, "n"], ["Damage per hit in a row", t.ramp, "p"], ["Max heat stacks", t.ramp_max if t.beam else 0.0, "n"], ["Triple shot every", t.surge, "n"],
		["Burn", t.burn, "p"], ["Brittle", t.brittle, "p"], ["Mark", t.mark, "p"], ["Bomblets", t.cluster, "n"], ["Huge blast every", t.orbital, "n"],
		["Freeze every", t.freeze, "n"], ["Chill stacks to freeze", t.hypo, "n"], ["Aura slow", t.zero, "p"], ["Stun chance", t.stun, "p"], ["Prism splits", t.prism, "n"], ["Execute below", t.execute, "p"],
		["Nova", t.nova, "p"], ["Echo", t.echo, "p"], ["Death blast", t.death_blast, "p"], ["Drag back", t.gravity, "n"], ["Time lock", t.time_lock, "s"],
		["Shatter", t.shatter, "p"], ["Frostfire", t.frostfire, "p"], ["Storm bolts", t.storm, "n"], ["Ion burst", t.chain_blast, "p"], ["Overload", t.overload, "p"],
		["Pierce", t.pierce, "n"], ["Kill gold", t.loot, "n"], ["Kill heal", t.leech, "n"], ["Tempo", t.tempo, "p"], ["Hex pulse", t.hex, "p"], ["Hex Nova", t.hex_nova, "p"],
		["Buff damage", t.b_dmg if t.support else 0.0, "p"], ["Buff fire rate", t.b_rate, "p"], ["Buff range", t.b_range, "p"], ["Armor ignored", t.b_sunder, "p"],
		["Buff kill gold", t.b_gold, "p"], ["Pressure per second", t.press if t.type == "anvil" else 0.0, "p"], ["Pressure cap", t.press_cap if t.type == "anvil" else 0.0, "p"],
		["Pin", t.pin, "s"], ["Hero damage taken", 1 - t.guard if t.type == "anvil" else 0.0, "p"], ["Crush below", t.crush_exec, "p"],
	]


static func delta_text(a: Array, b: Array, name: String) -> String:
	var out := []
	for i in a.size():
		var v := float(a[i][1])
		var w := float(b[i][1])
		var k: String = a[i][2]
		if absf(v - w) > 1e-9 and fmt(v, k) != fmt(w, k):
			out.append("%s %s → %s" % [a[i][0], fmt(v, k), fmt(w, k)])
	return " · ".join(out) if out.size() else "New: " + name


## Runs an upgrade on copies of the hero and run numbers and reports what changed.
static func preview_run(g: Game, apply: Callable, name: String) -> String:
	var S := g.S
	var keep_h := S.hero
	var keep := S.copy_mods()
	var before := hero_stats(g, S.hero) + run_stats(g)
	S.hero = keep_h.copy()
	apply.call()
	var after := hero_stats(g, S.hero) + run_stats(g)
	S.hero = keep_h
	S.restore_mods(keep)
	return delta_text(before, after, name)


static func preview_level(g: Game, t: Tower, o: Dictionary) -> String:
	var before := tower_stats(g, t)
	var res := g.preview_level(t, o)
	var txt := delta_text(before, tower_stats(g, res.tower), o.name)
	if res.mastered:
		txt += " · New: " + o.path.mastery_name
	return txt


# ---------- the hero's ability ----------
static func ability_text(g: Game, h: Hero) -> String:
	if h.data and h.data.spells:
		var keys := []
		if g and g.S and g.S.hero == h and not g.S.over:
			for k in g.S.rune_keys:
				keys.append("%s (%s)" % [k.to_upper(), DB.elements[g.S.rune_keys[k]].name.to_lower()])
		else:
			var load := Progress.wiz_loadout()
			for i in load.size():
				keys.append("%s (%s)" % [Progress.SLOT_KEYS[i].to_upper(), DB.elements[load[i]].name.to_lower()])
		return ("Ready elements with %s, then left-click to cast at the cursor. Same element twice: a stronger spell. Two elements: a combination spell. Three of an element mastered to level %d: its ultimate. "
			+ "Elements you cast rest for %ss. Spells cost mana, which flows only during waves; clearing a wave refills 30%% of it.") % [", ".join(keys), DB.rules.triple_at, f1t(DB.rules.element_rest)]
	return ab_text(h.ab)


static func ab_text(a: Ability) -> String:
	if a == null or a.id == "":
		return ""
	if DB.is_simple() and DB.simple_texts.has("ability:" + a.id):
		return DB.simple_texts["ability:" + a.id]
	return Fx.text(a.desc, { a = a })


static func f1t(v: float) -> String:
	return ("%.1f" % v).trim_suffix(".0")


static func ability_tip(g: Game, h: Hero) -> String:
	var a := h.ab
	if h.data and h.data.spells:
		return Kit.b("Spellcraft") + "\n" + Kit.c(ability_text(g, h), Kit.MUTED) + "\n" + Kit.c("Esc clears readied runes. Right-click or left-click empty ground to move.", Kit.MUTED)
	var rows := []
	match a.id:
		"slam": rows = [["Damage", f0(a.dmg)], ["Radius", f0(a.r * (1.5 if a.magnet else 1.0))], ["Stun", f1(a.stun) + "s"]]
		"nova": rows = [["Damage", f0(a.dmg)], ["Radius", f0(a.r)]]
		"overclock": rows = [["Radius", f0(a.r)], ["Towers fire faster", pct(a.power)], ["Lasts", f1(a.dur) + "s"]]
		"bulwark": rows = [["Shield", f0(a.dmg * 5 * (1.5 if a.overflow else 1.0))], ["Burst", f0(a.dmg) + " + 60% soaked"], ["Lasts", f1(a.dur) + "s"]]
		"overdrive": rows = [["Attack speed", "+" + pct(a.power)], ["Lasts", f1(a.dur) + "s"]]
		"strike": rows = [["Damage", ("%s (%s× hero damage)" % [f0(h.dmg * a.mult), f1(a.mult)]) if h.dmg else f1(a.mult) + "× hero damage"], ["Radius", f0(a.r)]]
		"stasis": rows = [["Radius", f0(a.r)], ["Slow", pct(minf(0.85, a.power * 0.75))], ["Lasts", f1(a.dur) + "s"]]
		"pierce": rows = [["Damage per enemy", ("%s (%s× hero damage)" % [f0(h.dmg * a.mult), f1(a.mult)]) if h.dmg else f1(a.mult) + "× hero damage"], ["Width", f0(a.w * (3.0 if a.rail else 1.0))]]
	rows.append(["Cooldown", f1(a.cd) + "s"])
	var s := Kit.b(a.name) + "  " + Kit.c("Q", Kit.GOLD) + "\n" + Kit.c(ab_text(a), Kit.MUTED)
	if not DB.is_simple():
		s += "\n" + " · ".join(rows.map(func(r): return "%s: %s" % [r[0], Kit.b(r[1])]))
	var mods := mods_of(h)
	for m in mods:
		s += "\n" + Kit.c(m.name + ":", Kit.PINK) + " " + Kit.c(DB.tx("mod:" + m.id, m.desc), Kit.MUTED)
	var extra := ""
	match a.id:
		"slam": extra = ("After the slam, enemies within 120 attack you for %ss (bosses half)." % f1(h.taunt)) if h.taunt else ""
		"pierce": extra = "Press F to set an aim point and it always fires that way. Press F on the point to clear it."
		"strike": extra = "Point at the map and press Q: the strike lands on your cursor."
	if extra != "":
		s += "\n" + Kit.c(extra, Kit.MUTED)
	return s


static func mods_of(h: Hero) -> Array:
	var out := []
	for m in DB.rules.ability_mods.items:
		if h.ab and h.ab.has_mod(m.id):
			out.append(m)
	return out


# ---------- mastery ----------
static func mastery_box(kind: String, k: String) -> Control:
	var m := Progress.mastery_of(kind, k)
	var fill := minf(1, float(m.kills - m.prev) / maxf(1, m.next - m.prev)) if m.next > 0 else 1.0
	var note := ""
	if m.capped:
		note = "Capped at %d: beat %s with %s to keep leveling." % [m.cap, DB.maps[m.next_map].scene.map_name if m.next_map != "" else "", "this tower built" if kind == "towers" else "this hero"]
	elif m.next > 0:
		if kind != "heroes":
			var left: int = m.next - m.kills
			note = "%d more kill%s to level %d." % [left, "" if left == 1 else "s", m.lvl + 1]
		else:
			var cat: String = DB.heroes[k].category
			var left := int(ceil(m.next * Progress.ROLE_PER[cat] - Progress.hero_stat(k)))
			note = ("%d more damage blocked to level %d." % [left, m.lvl + 1]) if cat == "defensive" else ("%d more %s%s to level %d." % [left, {offensive = "kill", support = "assisted kill", special = "kill"}[cat], "" if left == 1 else "s", m.lvl + 1])
	else:
		note = "Max mastery."
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box_style(Color(0, 0, 0, 0), Kit.LINE, 1, 8, 8))
	var v := Kit.vbox(4)
	p.add_child(v)
	var top := Kit.hbox()
	top.add_child(Kit.label("Mastery %d" % m.lvl, 15, Kit.GOLD, Kit.display))
	top.add_child(Kit.spacer())
	top.add_child(Kit.label("Cap %d/%d" % [m.cap, DB.rules.mastery_max], 13, Kit.MUTED))
	v.add_child(top)
	v.add_child(Kit.meter(fill, Kit.GOLD, 8))
	v.add_child(Kit.muted(note))
	return p


static func hero_mastery_text(k: String) -> String:
	if DB.heroes[k].spells:
		var best := 0
		for el in DB.el_order:
			best = maxi(best, Progress.el_mastery(el).lvl)
		return "Best element mastery %d" % best
	return "Mastery %d" % Progress.mastery_of("heroes", k).lvl


# ---------- menu upgrades ----------
static func meta_cost(def: UpgradeData, r: int) -> int:
	return int(Fx.value(def.cost, { r = r }, 0))


static func meta_delta(def: UpgradeData, key: String, id: String, r: int) -> String:
	if def.stat_label != "":
		return "%s %s → %s" % [def.stat_label, Fx.text(def.stat_value, { r = r }), Fx.text(def.stat_value, { r = r + 1 })]
	if key == "hero":
		var a := Hero.make(id, Vector2(400, 300))
		var b := Hero.make(id, Vector2(400, 300))
		if r:
			Fx.run(def.effect, { h = a, run = null, r = r })
		Fx.run(def.effect, { h = b, run = null, r = r + 1 })
		return delta_text(hero_stats(null, a), hero_stats(null, b), def.name)
	return Fx.text(def.desc, { r = r + 1 })
