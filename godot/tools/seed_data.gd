extends SceneTree
# One-time generator: writes every data file (.tres) from the original game's tables.

func col(x: int) -> Color:
	return Color.hex((x << 8) | 0xff)


func save(r: Resource, path: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(r, path)
	if err != OK:
		push_error("save failed " + path)
	r.take_over_path(path)
	return r


func U(d: Dictionary) -> UpgradeData:
	var u := UpgradeData.new()
	for k in d:
		if k == "also_pools" or k == "heroes":
			u.set(k, PackedStringArray(d[k]))
		else:
			u.set(k, d[k])
	return u


func L(items: Array) -> UpgradeList:
	var l := UpgradeList.new()
	var arr: Array[UpgradeData] = []
	for d in items:
		arr.append(U(d))
	l.items = arr
	return l


func _init() -> void:
	var rules := GameRules.new()
	rules.maps = [load("res://maps/sunset_outpost.tscn"), load("res://maps/neon_boardwalk.tscn"), load("res://maps/chroma_reactor.tscn"), load("res://maps/spiral_rift_garden.tscn")]
	var tw: Array[TowerData] = []
	for t in towers():
		tw.append(save(t, "res://data/towers/%s.tres" % t.id))
	rules.towers = tw
	var en: Array[EnemyData] = []
	for e in enemies():
		en.append(save(e, "res://data/enemies/%s.tres" % e.id))
	rules.enemies = en
	var he: Array[HeroData] = []
	for h in heroes():
		he.append(save(h, "res://data/heroes/%s.tres" % h.id))
	rules.heroes = he
	rules.spells = save(spells(), "res://data/spells.tres")
	rules.elements = save(elements(), "res://data/elements.tres")
	rules.fusions = save(fusions(), "res://data/fusions.tres")
	rules.recipes = save(recipes(), "res://data/recipes.tres")
	rules.perks = save(L(perks()), "res://data/lists/perks.tres")
	rules.ability_mods = save(L(ability_mods()), "res://data/lists/ability_mods.tres")
	rules.uniques = save(L(uniques()), "res://data/lists/uniques.tres")
	rules.curses = save(L(curses()), "res://data/lists/curses.tres")
	rules.heroics = save(L(heroics()), "res://data/lists/heroics.tres")
	rules.relics = save(L(relics()), "res://data/lists/relics.tres")
	rules.legendary_relics = save(L(legendary_relics()), "res://data/lists/legendary_relics.tres")
	rules.secret_relics = save(L(secret_relics()), "res://data/lists/secret_relics.tres")
	rules.tough = save(L(tough()), "res://data/lists/tough.tres")
	rules.challenges = save(L(challenges()), "res://data/lists/challenges.tres")
	rules.requirements = save(L(requirements()), "res://data/lists/requirements.tres")
	rules.shop = save(L(shop()), "res://data/lists/shop.tres")
	rules.global_meta = save(L(global_meta()), "res://data/lists/global_meta.tres")
	rules.tower_global = save(L(tower_global()), "res://data/lists/tower_global.tres")
	rules.specials = save(L(specials()), "res://data/lists/specials.tres")
	var txt := TextData.new()
	var simple: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/claude-0/simple.json"))
	simple["towerglobal:main"] = "Every tower is better at its main job."
	simple["towerglobal:cost"] = "Tower upgrades cost less."
	simple["towerglobal:range"] = "Towers reach farther."
	simple["towerglobal:speed"] = "Towers attack faster."
	txt.texts = simple
	rules.simple_texts = save(txt, "res://data/simple_texts.tres")
	save(rules, "res://data/rules.tres")
	print("seed done")
	quit()


# ---------------- towers ----------------
func P(id, name, tag, words: Array, desc, effect, mname, mdesc, meffect) -> TowerPath:
	var p := TowerPath.new()
	p.id = id; p.name = name; p.tag = tag; p.adjective = words[0]; p.noun = words[1]; p.title = words[2]
	p.desc = desc; p.effect = effect; p.mastery_name = mname; p.mastery_desc = mdesc; p.mastery_effect = meffect
	return p


func T(d: Dictionary, paths: Array, sig: Array, sp: Array, forms: Dictionary, art: Dictionary) -> TowerData:
	var t := TowerData.new()
	for k in d:
		t.set(k, d[k])
	var ps: Array[TowerPath] = []
	ps.assign(paths)
	t.paths = ps
	t.signature_name = sig[0]; t.signature_desc = sig[1]
	t.super_power_name = sp[0]; t.super_power_desc = sp[1]
	t.form_names = forms
	t.sheet = load("res://assets/towers/%s.png" % d.id)
	t.foot_y = art.oy; t.muzzle_y = art.my
	if art.has("pa"):
		t.shot_anchor = Vector2(art.pa[0], art.pa[1])
	t.shot_turn = art.get("turn", false)
	t.fx_anchor_y = art.get("fy", 0.5)
	t.fire_frame = art.get("fire", 0)
	return t


func towers() -> Array:
	return [
		T({ id = "arcane", name = "Arcane Bolt", cost = 50, dmg = 14.0, rate = 0.5, range = 120.0, color = col(0xff4fc0), element_tag = "arcane",
			info = "Fires quick magic bolts at one enemy at a time. Steady, reliable damage that is good against anything." }, [
			P("runes", "Weakening Runes", "power", ["Runic", "Glyph", "Runes"], "Hits mark enemies to take +4% damage from every source per point for 2s.", "t.mark += 0.04",
				"Arcane Mark", "Marks grow by another +20%, so marked enemies take +36% damage from everything.", "t.mark += 0.2"),
			P("hex", "Hex Brand", "arcane", ["Hexed", "Brand", "Hexes"], "Hits brand enemies. Every second a branded enemy pulses 2% more per point of all the damage it has taken so far, to itself and enemies within 60. Ignores armor.", "t.hex += 0.02",
				"Hex Nova", "Branded enemies explode when they die for 25% of all the damage they took, hitting enemies within 80.", "t.hex_nova = max(t.hex_nova, 0.25)"),
			P("focus", "Arcane Focus", "precision", ["Focused", "Lens", "Focus"], "Each hit in a row on the same enemy deals +10% more damage per point (5 stacks).", "t.ramp += 0.1",
				"Executioner", "Hits finish off non-boss enemies below 12% HP.", "t.execute += 0.12"),
			P("surge", "Mana Surge", "arcane", ["Surging", "Nova", "Mana"], "Every 5th shot deals triple damage; each point makes it come 1 shot sooner.", "t.surge = 6 - rank",
				"Mana Nova", "Every 6th shot also blasts every enemy in range for 50% damage.", "t.nova += 0.5"),
			P("quick", "Quickcast", "speed", ["Swift", "Repeater", "Haste"], "Fires 14% faster per point.", "t.rate *= 0.86",
				"Echo", "Every shot repeats a moment later for 40% damage.", "t.echo += 0.4"),
		], ["Spellweave", "Every 5th bolt also applies Hex Brand, even without points in it."],
		["Rift Collapse", "drags every enemy in range back along the path for 1.5s, hits them for 6× damage, and they take 30% more damage for 5s"],
		{ "012": "Doomglyph Obelisk", "013": "Hexstorm Spire", "014": "Curseweaver", "023": "Starpiercer", "024": "Spellblade Sentinel", "034": "Arcane Cataclysm", "123": "Voidbrand Monolith", "124": "Witchfire Lens", "134": "Plaguestar", "234": "Mana Gatling", "1234": "Eldritch Engine", "0234": "Archmage’s Lance", "0134": "Runic Maelstrom", "0124": "Grimoire of Ruin", "0123": "Sigil of the Void", "01234": "Arcanum Absolute" },
		{ oy = 38, my = 14, pa = [24, 31], turn = true, fy = 0.75, fire = 1 }),
		T({ id = "plasma", name = "Plasma Cannon", cost = 80, dmg = 24.0, rate = 1.4, range = 110.0, splash = 50.0, color = col(0x2fd6b0), element_tag = "burn",
			info = "Lobs slow plasma shells that explode on impact and hurt every enemy in the blast. Best against tight groups." }, [
			P("shells", "Bigger Shells", "burst", ["Shrapnel", "Mortar", "Shrapnel"], "+20% blast radius per point.", "t.splash *= 1.2",
				"Cluster Bomb", "Each shot also throws 2 bomblets at nearby enemies for 50% damage.", "t.cluster = 2"),
			P("hot", "Long Barrel", "power", ["Farshot", "Cannon", "Reach"], "+8% range per point.", "t.range *= 1.08",
				"Orbital Strike", "Every 4th shot is a huge blast: double radius, triple damage.", "t.orbital = 4"),
			P("burn", "Burning Ground", "burn", ["Blazing", "Pyre", "Embers"], "Hits burn for +30% of their damage over 2s per point.", "t.burn += 0.3",
				"Chain Reaction", "Enemies this tower kills explode for 20% of their max HP.", "t.death_blast += 0.2"),
			P("auto", "Autoloader", "speed", ["Rapid", "Autocannon", "Haste"], "Fires 14% faster per point.", "t.rate *= 0.86",
				"Double Tap", "Every shot fires again a moment later for 50% damage.", "t.echo += 0.5"),
			P("concuss", "Concussive Shells", "slow", ["Quaking", "Hammer", "Thunder"], "Blasts slow enemies by 10% per point for 1s.", "t.slow = max(t.slow, 0.1 * rank)\nt.slow_dur = max(t.slow_dur, 1)",
				"Gravity Well", "Every 5th shot drags enemies near the blast 40 steps back along the path.", "t.gravity += 40"),
		], ["Napalm Shells", "Explosions leave burning ground for 2s. Burns ignore armor."],
		["Supernova", "detonates everything in range for 10× damage and leaves the ground burning for 4s"],
		{ "012": "Inferno Mortar", "013": "Carpet Bomber", "014": "Meteor Hammer", "023": "Napalm Spitter", "024": "Magma Quake", "034": "Shockwave Battery", "123": "Hellfire Cannon", "124": "Sunfall Artillery", "134": "Thunder Howitzer", "234": "Cinder Gatling", "1234": "Solar Forge", "0234": "Firestorm Engine", "0134": "Siege Colossus", "0124": "Volcano Heart", "0123": "Armageddon Mortar", "01234": "Starfall Citadel" },
		{ oy = 40, my = 10, pa = [24, 24], fire = 2 }),
		T({ id = "frost", name = "Frost Pylon", cost = 60, dmg = 6.0, rate = 0.9, range = 100.0, slow = 0.45, level_bonus = "rate", color = col(0x9cf4dd), element_tag = "slow",
			info = "Hits weakly but slows enemies down, so the rest of your towers get more time to shoot. Pairs with everything." }, [
			P("deep", "Deep Freeze", "slow", ["Glacial", "Spire", "Winter"], "Slows 7% more per point (up to 85%).", "t.slow = min(0.85, t.slow + 0.07)",
				"Absolute Zero", "Every enemy in range is constantly slowed by 30%.", "t.zero = max(t.zero, 0.3)"),
			P("burst", "Frost Burst", "burst", ["Shattering", "Burst", "Ice"], "Shots burst and chill every enemy nearby; +20% burst size per point.", "t.splash = iff(t.splash > 0, t.splash * 1.2, 35)",
				"Flash Freeze", "Every 6th shot freezes enemies solid for 1.2s.", "t.freeze = 6"),
			P("linger", "Lingering Cold", "slow", ["Lingering", "Veil", "Stillness"], "Slows last 0.8s longer per point.", "t.slow_dur += 0.8",
				"Time Lock", "Every 8th shot stuns every enemy in range for 0.6s.", "t.time_lock += 0.6"),
			P("hypo", "Hypothermia", "arcane", ["Frigid", "Rime", "Hypothermia"], "Each hit adds a chill stack. At 9 stacks the enemy freezes solid for 0.8s (bosses 0.3s); each point needs 1 stack fewer.", "t.hypo = 9 - rank",
				"Cold Snap", "When Hypothermia freezes an enemy, the cold bursts out and freezes every enemy within 70 for 0.5s (bosses 0.2s).", "t.cold_snap = 1"),
			P("brittle", "Brittle", "precision", ["Brittle", "Fang", "Frailty"], "Slowed enemies take +8% damage from everything per point.", "t.brittle += 0.08",
				"Frostbite", "Hits on slowed enemies also burn them for 50% of the hit over 2s.", "t.frostfire += 0.5"),
		], ["Deep Freeze", "An enemy slowed for 3s straight freezes solid for 1s."],
		["Absolute Zero", "freezes every enemy in range for 2.5s (bosses 0.8s), and they take 40% more damage for 5s"],
		{ "012": "Glacier Heart", "013": "Blizzard Spire", "014": "Shatterfrost Spire", "023": "Eternal Winter", "024": "Frostbite Obelisk", "034": "Permafrost Tomb", "123": "Avalanche Totem", "124": "Crystal Storm", "134": "Hoarfrost Bloom", "234": "Stasis Crypt", "1234": "Polar Vortex", "0234": "Glacial Throne", "0134": "Winter’s Maw", "0124": "Diamond Dust Spire", "0123": "Ice Age Monolith", "01234": "Absolute Winter" },
		{ oy = 41, my = 16, pa = [25, 25], fire = 2 }),
		T({ id = "tesla", name = "Tesla Coil", cost = 90, dmg = 12.0, rate = 1.1, range = 105.0, chain = 3, color = col(0x4fd8ff), element_tag = "chain",
			info = "Fires lightning that jumps from enemy to enemy, losing a bit of power with each jump. Great for long lines of enemies." }, [
			P("arcs", "More Arcs", "chain", ["Forked", "Arc", "Storms"], "Lightning jumps to 1 more enemy per point.", "t.chain += 1",
				"Storm Call", "Every 4th shot calls lightning down on 3 random enemies in range.", "t.storm += 3"),
			P("volt", "Static Shock", "power", ["Charged", "Coil", "Voltage"], "Lightning jumps get a 4% chance per point to stun for 0.6s.", "t.stun += 0.04",
				"Overload", "Lightning jumps get another +15% stun chance (31% in all).", "t.stun += 0.15"),
			P("conduct", "Conductive", "chain", ["Conductive", "Conduit", "Currents"], "Jumps lose 7% less damage per point.", "t.chain_mul = min(0.95, t.chain_mul + 0.07)",
				"Ion Burst", "Every lightning jump explodes for 30% damage around it.", "t.chain_blast += 0.3"),
			P("bank", "Capacitor Bank", "speed", ["Overclocked", "Dynamo", "Haste"], "Fires 14% faster per point.", "t.rate *= 0.86",
				"Overcharge", "Every 10th shot deals +150% damage and stuns for 0.5s.", "t.overload += 1.5"),
			P("jump", "Arc Reach", "chain", ["Leaping", "Relay", "Reach"], "Lightning jumps 20% farther per point.", "t.chain_reach *= 1.2",
				"Arc Storm", "Shoots 1 more enemy and lightning jumps 2 more times.", "t.multi += 1\nt.chain += 2"),
		], ["Overcharge", "Chain lightning no longer loses power on each jump."],
		["Thunder God", "calls down 12 lightning bolts on enemies in range, each for 5× damage and a short stun"],
		{ "012": "Thunderhead", "013": "Storm Dynamo", "014": "Skyfork Tower", "023": "Ion Cascade", "024": "Leyline Relay", "034": "Static Tempest", "123": "Arc Reactor", "124": "Bolt Throne", "134": "Overvolt Pylon", "234": "Hyperion Coil", "1234": "Tesla Colossus", "0234": "Stormweb Array", "0134": "Fulgurite Spire", "0124": "Sky Breaker", "0123": "Lightning Cathedral", "01234": "Heart of the Storm" },
		{ oy = 38, my = 13, pa = [23.5, 16.5], fy = 0.75, fire = 3 }),
		T({ id = "beacon", name = "Rift Beacon", cost = 100, dmg = 0.0, rate = 1.0, range = 130.0, support = true, level_bonus = "range", color = col(0xffa0e0), element_tag = "power",
			info = "Never attacks. Every tower in its range deals +15% damage. Beacons don’t stack on the same tower (the strongest wins), so spread them out." }, [
			P("empower", "Empower", "power", ["Radiant", "Beacon", "Light"], "Buffed towers deal +8% more damage per point.", "t.b_dmg += 0.08",
				"Overdrive", "Buffed towers crit 10% of the time for triple damage.", "t.b_overdrive = 1"),
			P("haste", "Haste", "speed", ["Hastening", "Pulse", "Haste"], "Buffed towers fire 6% faster per point.", "t.b_rate += 0.06",
				"Tempo Link", "Every 10s, buffed towers fire at double speed for 3s.", "t.b_tempo = 1"),
			P("reach", "Reach", "precision", ["Far", "Lantern", "Reach"], "Buffed towers and the Beacon get +8% range per point.", "t.b_range += 0.08\nt.range *= 1.08",
				"Lighthouse", "Buffed towers can hit enemies within twice their range.", "t.b_light = 1"),
			P("sunder", "Sunder", "precision", ["Sundering", "Spike", "Sundering"], "Buffed towers ignore 8% armor per point.", "t.b_sunder += 0.08",
				"Armor Break", "Enemies hit by buffed towers lose 15% armor for 3s, stacking to 45%.", "t.b_break = 1"),
			P("btithe", "Tithe", "arcane", ["Gilded", "Shrine", "Fortune"], "Kills by buffed towers give +10% gold per point.", "t.b_gold += 0.1",
				"Gold Rush", "Each kill by a buffed tower has an 8% chance to drop a 25 gold coin. Walk your hero over it (coins left at the end of a wave are collected for you).", "t.b_rush = 1"),
		], ["Twin Signal", "Two Beacons can stack on the same tower."],
		["Ascension", "every tower within 260 fires twice as fast for 6s"],
		{ "012": "Warsong Spire", "013": "Battle Standard", "014": "Golden Fanfare", "023": "Dawnspear Lantern", "024": "Merchant’s Lighthouse", "034": "Conqueror’s Shrine", "123": "Tempo Lighthouse", "124": "Bazaar Bell", "134": "Siegebreaker Totem", "234": "Plunderer’s Lantern", "1234": "Guildhall Beacon", "0234": "Crusader’s Pharos", "0134": "Warlord’s Banner", "0124": "Golden Dawn", "0123": "Herald of War", "01234": "Eternal Lighthouse" },
		{ oy = 37, my = 22 }),
		T({ id = "anvil", name = "Grave Anvil", cost = 90, dmg = 40.0, rate = 1.6, range = 70.0, color = col(0xf6a14a), element_tag = "burst",
			info = "Slams the ground, crushing enemies that are not moving: blocked by your hero, stunned or frozen. The longer they stay still, the harder it hits. Moving enemies only take 30%." }, [
			P("crush", "Armor Crusher", "power", ["Crushing", "Anvil", "Ruin"], "Slams ignore 10% armor per point.", "t.sunder += 0.1",
				"Executioner’s Weight", "Stopped enemies below 15% HP are crushed instantly (not bosses).", "t.crush_exec = 0.15"),
			P("pin", "Pin", "slow", ["Pinning", "Spike", "Chains"], "Slams hold stopped enemies in place 0.3s longer per point (bosses half).", "t.pin += 0.3",
				"Shackle", "Every 4th slam roots every enemy in the area for 1s, moving or not (bosses 0.5s).", "t.shackle = true"),
			P("quake", "Quake", "burst", ["Quaking", "Hammer", "Tremors"], "+10 slam radius per point.", "t.range += 10",
				"Aftershock", "Each slam sends a second shockwave 0.5s later for 50% damage.", "t.after = true"),
			P("pressure", "Pressure", "precision", ["Grinding", "Press", "Pressure"], "+10% more damage per second stopped per point, and the cap rises by 25%.", "t.press += 0.1\nt.press_cap += 0.25",
				"Crushing Tide", "Pressure no longer resets when an enemy starts moving again; it fades over 3s instead.", "t.tide = true"),
			P("guardian", "Guardian", "slow", ["Guarding", "Bastion", "Wardens"], "Your hero takes 6% less damage per point from enemies it blocks within range.", "t.guard += 0.06",
				"Bulwark Pact", "While your hero blocks an enemy in range, the Anvil slams twice as fast.", "t.pact = true"),
		], ["Fault Line", "Slams travel along the path in both directions for 2 tiles."],
		["World Breaker", "slams every enemy in range for 8× damage and stuns them for 1.5s (bosses 0.5s)"],
		{ "012": "Tomb Hammer", "013": "Executioner’s Press", "014": "Oathkeeper", "023": "Earthsplitter", "024": "Bulwark Maul", "034": "Grinding Bastion", "123": "Gravelock", "124": "Warden’s Shackle", "134": "Iron Vise", "234": "Seismic Bastion", "1234": "Mountain’s Grip", "0234": "Doomhammer Forge", "0134": "Titan’s Judgment", "0124": "Worldbreaker", "0123": "Grave of Kings", "01234": "The Final Anvil" },
		{ oy = 39, my = 22, fire = 3 }),
		T({ id = "laser", name = "Prism Laser", cost = 110, dmg = 5.0, rate = 0.2, range = 115.0, beam = true, color = col(0xff5f6f), element_tag = "precision",
			info = "Holds a steady beam on one enemy. Every tick on the same target heats the beam up for more damage (up to +160%). Switching targets cools it down. Melts bosses and tanks." }, [
			P("chainl", "Chain Laser", "chain", ["Branching", "Prism", "Chains"], "The beam jumps to 1 more enemy per point at 60% of its damage (heat included).", "t.chain += 1\nt.chain_mul = max(t.chain_mul, 0.6)",
				"Prism Web", "Chained beams deal full damage and don’t weaken with each jump.", "t.chain_mul = 1\nt.chain_keep = true"),
			P("focusl", "Focusing Lens", "precision", ["Focused", "Lens", "Focus"], "Each tick on the same target adds +3% more heat damage per point.", "t.ramp += 0.03",
				"Meltdown", "At full heat the beam deals double damage.", "t.melt = true"),
			P("sink", "Heat Sink", "burn", ["Smoldering", "Core", "Embers"], "Holds 5 more heat stacks per point.", "t.ramp_max += 5",
				"Residual Heat", "Switching targets only halves the heat instead of resetting it.", "t.retain = true"),
			P("amp", "Phase Beam", "power", ["Blazing", "Emitter", "Power"], "The beam ignores 10% armor per point.", "t.sunder += 0.1",
				"Sear", "Hits burn for 40% of their damage over 2s.", "t.burn += 0.4"),
			P("lensr", "Long Lens", "precision", ["Farseeing", "Beam", "Reach"], "+10% range per point.", "t.range *= 1.1",
				"Piercing Beam", "The beam also burns through 3 enemies behind its target for 60% damage.", "t.pierce += 3"),
		], ["Overheat", "The beam heats up twice as fast."],
		["Heaven Lance", "a beam from orbit hits the toughest enemy in range for 30× damage and everything near it for 8×"],
		{ "012": "Prism Lattice", "013": "Arc Lancer", "014": "Spectrum Web", "023": "Refraction Core", "024": "Rainbow Reach", "034": "Photon Spear", "123": "Meltdown Eye", "124": "Searing Gaze", "134": "Sunbeam Lance", "234": "Deathray", "1234": "Solar Cannon", "0234": "Crystal Nexus", "0134": "Hyperbeam Array", "0124": "Kaleidoscope", "0123": "Fusion Prism", "01234": "Eye of the Sun" },
		{ oy = 36, my = 14 }),
		T({ id = "mortar", name = "Siege Mortar", cost = 130, dmg = 110.0, rate = 4.5, range = 320.0, splash = 60.0, lob = true, color = col(0xf9e6a2), element_tag = "burst",
			info = "Very long range. Lobs a slow, heavy shell that lands a few moments later and wrecks everything in the blast. Fires rarely, so pair it with towers that cover the gaps." }, [
			P("payload", "Salvage Shells", "power", ["Thundering", "Mortar", "Spoils"], "Kills by the mortar drop +1 gold per point.", "t.loot += 1",
				"Bunker Buster", "Every 3rd shell deals triple damage in a double-size blast.", "t.orbital = 3"),
			P("blast", "Wide Blast", "burst", ["Sprawling", "Crater", "Craters"], "+15% blast radius per point.", "t.splash *= 1.15",
				"Cluster Shells", "Each shell scatters 3 bomblets at nearby enemies for 50% damage.", "t.cluster = 3"),
			P("napalm", "Napalm", "burn", ["Burning", "Brazier", "Napalm"], "Blasts burn for 30% of their damage over 2s per point.", "t.burn += 0.3",
				"Firestorm", "Shells leave burning ground for 3s.", "t.firestorm = true"),
			P("reload", "Quick Reload", "speed", ["Rapid", "Battery", "Salvos"], "Fires 12% faster per point.", "t.rate *= 0.88",
				"Double Salvo", "Every shell is followed by a second one for 60% damage.", "t.salvo = 0.6"),
			P("shock", "Shockwave", "slow", ["Shaking", "Quake", "Tremors"], "Blasts slow enemies by 12% per point for 1.6s.", "t.slow = max(t.slow, 0.12 * rank)",
				"Earthquake", "Every 4th shell stuns everything in the blast for 0.8s (bosses 0.3s).", "t.quake_stun = true"),
		], ["Rocket Shells", "Shells fly 40% faster and their blast is 20% wider."],
		["Meteor Rain", "drops 10 meteors across its range, each dealing 4× damage in a wide blast"],
		{ "012": "Doomshell Battery", "013": "Bastion Buster", "014": "Crater Maker", "023": "Firebomb Nest", "024": "Scorched Earth", "034": "Rolling Barrage", "123": "Inferno Rain", "124": "Quake Mortar", "134": "Hailstorm Launcher", "234": "Hellrain Battery", "1234": "Ash Sky", "0234": "Brimstone Bastion", "0134": "Thunder Siege", "0124": "Cataclysm Cannon", "0123": "Ragnarok Battery", "01234": "End of Days" },
		{ oy = 40, my = 20, pa = [24, 25], turn = true, fire = 3 }),
	]


# ---------------- enemies ----------------
func E(d: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	for k in d:
		e.set(k, d[k])
	return e


func enemies() -> Array:
	return [
		E({ id = "grunt", name = "Grunt", hp = 55.0, speed = 52.0, gold = 5, lives = 1, atk = 8.0, radius = 9.0, color = col(0xff5d6c), info = "No special trait.", counter = "Anything works." }),
		E({ id = "runner", name = "Runner", hp = 35.0, speed = 100.0, gold = 4, lives = 1, atk = 5.0, radius = 7.0, color = col(0xffb35d), info = "Fast.", counter = "Slows and chain lightning." }),
		E({ id = "brute", name = "Brute", hp = 220.0, speed = 34.0, gold = 12, lives = 3, atk = 20.0, radius = 13.0, color = col(0xd14b8f), armor = 0.15, info = "15% armor.", counter = "Big hits, burns and Hex Brand ignore or shrug off armor." }),
		E({ id = "wraith", name = "Wraith", hp = 45.0, speed = 120.0, gold = 5, lives = 1, atk = 6.0, radius = 8.0, color = col(0x9ad8ff), unslow = true, first_wave = 6, per_wave = 2, info = "Very fast and can’t be slowed.", counter = "Stuns still work. Chain lightning and long range." }),
		E({ id = "phantom", name = "Phantom", hp = 70.0, speed = 70.0, gold = 7, lives = 2, atk = 10.0, radius = 9.0, color = col(0xc8b8ff), phase = true, first_wave = 7, per_wave = 2, info = "Only Defensive heroes can block it.", counter = "The Vanguard stops it. Everyone else has to shoot it down." }),
		E({ id = "splitter", name = "Splitter", hp = 150.0, speed = 45.0, gold = 8, lives = 2, atk = 14.0, radius = 12.0, color = col(0x7fe07f), split = 2, first_wave = 8, per_wave = 1, info = "Splits into 2 Runners when it dies.", counter = "Splash and chain damage clean up the pieces." }),
		E({ id = "juggernaut", name = "Juggernaut", hp = 600.0, speed = 26.0, gold = 25, lives = 4, atk = 35.0, radius = 16.0, color = col(0x9a7a66), armor = 0.3, unslow = true, first_wave = 9, per_wave = 1, info = "30% armor, huge HP and can’t be slowed.", counter = "Burns, Hex Brand, Brittle, Sunder and the Grave Anvil." }),
		E({ id = "shieldbearer", name = "Shieldbearer", hp = 260.0, speed = 38.0, gold = 15, lives = 3, atk = 18.0, radius = 13.0, color = col(0xd8b84a), armor = 0.2, shield_aura = 0.15, first_wave = 11, per_wave = 1, info = "20% armor and gives enemies within 70 +15% armor.", counter = "Kill it first; Sunder and Armor Break cut through." }),
		E({ id = "mender", name = "Mender", hp = 120.0, speed = 48.0, gold = 12, lives = 2, atk = 8.0, radius = 10.0, color = col(0x7dffb0), heal = 0.03, first_wave = 12, per_wave = 1, info = "Heals enemies within 70 for 3% of their max HP every second.", counter = "Focus it first. Sniper Spotter and Headhunter help." }),
		E({ id = "knight", name = "Rift Knight", hp = 1100.0, speed = 30.0, gold = 60, lives = 5, atk = 30.0, radius = 16.0, color = col(0xff2e4d), boss = true, armor = 0.25, cores = 1,
			power_name = "Shield Bash", power_every = 8.0, power_towers = 1, power_stun = 2.0, power_nearest = true,
			info = "25% armor. Shield Bash: every 8s stuns the nearest tower for 2s.", counter = "Spread your towers out." }),
		E({ id = "warden", name = "Rift Warden", hp = 3000.0, speed = 26.0, gold = 120, lives = 10, atk = 45.0, radius = 18.0, color = col(0xff2e4d), boss = true, big_boss = true, armor = 0.3, cores = 2,
			power_name = "Rift Lock", power_every = 10.0, power_towers = 2, power_stun = 3.0,
			info = "30% armor. Rift Lock: every 10s stuns 2 random towers for 3s. Summons Grunts at 75%, 50% and 25% HP.", counter = "Grounded makes stuns shorter." }),
		E({ id = "tyrant", name = "Rift Tyrant", hp = 9000.0, speed = 22.0, gold = 300, lives = 20, atk = 80.0, radius = 23.0, color = col(0xff2e4d), boss = true, big_boss = true, armor = 0.35, unslow = true, cores = 5,
			power_name = "Roar", power_every = 12.0, power_towers = 3, power_stun = 3.0, power_roar = true,
			info = "35% armor, can’t be slowed. Roar: every 12s stuns 3 towers and knocks your hero back. Enrages at 50% HP and summons 2 Juggernauts.", counter = "Stuns still work. Save your ability for the enrage." }),
	]


# ---------------- heroes ----------------
func A(d: Dictionary) -> AbilityData:
	var a := AbilityData.new()
	for k in d:
		a.set(k, d[k])
	return a


func H(d: Dictionary, ab: AbilityData, alt: AbilityData, meta: Array) -> HeroData:
	var h := HeroData.new()
	for k in d:
		h.set(k, d[k])
	h.ability = ab
	h.alt = alt
	var m: Array[UpgradeData] = []
	for x in meta:
		m.append(U(x))
	h.meta = m
	h.sheet = load("res://assets/heroes/%s.png" % d.id)
	return h


func heroes() -> Array:
	return [
		H({ id = "vanguard", name = "Vanguard", role = "Defensive", category = "defensive", color = col(0x5fe39a),
			desc = "A walking fortress. Huge HP, blocks every enemy that reaches it and stuns crowds.",
			hp = 340.0, dmg = 8.0, rate = 0.7, range = 80.0, block = 999, armor = 0.1, regen = 5.0, speed = 135.0 },
			A({ id = "slam", name = "Shield Slam", cd = 18.0, dmg = 30.0, r = 100.0, stun = 1.5, desc = "Deals {f0(a.dmg)} damage and stuns enemies within {f0(a.r)} for {f1(a.stun)}s." }),
			A({ id = "bulwark", name = "Bulwark Shield", cd = 18.0, dmg = 30.0, r = 110.0, dur = 5.0, desc = "Raises a shield that soaks {f0(a.dmg * 5 * iff(a.overflow, 1.5, 1))} damage for {f1(a.dur)}s. When it breaks or ends it bursts, hitting enemies within {f0(a.r)} for {f0(a.dmg)} plus 60% of what it soaked." }), [
			{ id = "ironhide", name = "Ironhide", cost = "60 + 50 * r", desc = "+{6 * r}% max HP", effect = "h.max_hp = round(h.max_hp * (1 + 0.06 * r))" },
			{ id = "bastion", name = "Bastion Plating", cost = "80 + 60 * r", desc = "Take {2 * r}% less damage", effect = "h.armor = min(0.75, h.armor + 0.02 * r)" },
			{ id = "seismic", name = "Seismic Training", cost = "80 + 60 * r", desc = "Shield Slam deals +{8 * r}% damage and stuns {f1(0.1 * r)}s longer", effect = "h.ab.dmg *= 1 + 0.08 * r\nh.ab.stun += 0.1 * r" },
			{ id = "medic", name = "Field Medic", cost = "100 + 80 * r", desc = "+{f1(0.6 * r)} HP regen per second", effect = "h.regen += 0.6 * r" },
		]),
		H({ id = "striker", name = "Striker", role = "Offensive", category = "offensive", color = col(0xff8a7a),
			desc = "Fast and deadly but fragile. Shreds enemies and blasts groups with Rift Nova.",
			hp = 180.0, dmg = 12.0, rate = 0.5, range = 115.0, block = 1, armor = 0.0, regen = 2.0, speed = 165.0 },
			A({ id = "nova", name = "Rift Nova", cd = 20.0, dmg = 40.0, r = 110.0, desc = "Deals {f0(a.dmg)} damage to every enemy within {f0(a.r)}." }),
			A({ id = "overdrive", name = "Overdrive", cd = 20.0, dur = 5.0, power = 1.0, desc = "For {f1(a.dur)}s you attack {pct(a.power)} faster." }), [
			{ id = "honed", name = "Honed Edge", cost = "60 + 50 * r", desc = "+{5 * r}% damage", effect = "h.dmg *= 1 + 0.05 * r" },
			{ id = "instinct", name = "Killer Instinct", cost = "80 + 60 * r", desc = "+{2 * r}% crit chance", effect = "h.crit += 0.02 * r" },
			{ id = "novam", name = "Nova Mastery", cost = "80 + 60 * r", desc = "Rift Nova deals +{6 * r}% damage and recharges {3 * r}% faster", effect = "h.ab.dmg *= 1 + 0.06 * r\nh.ab.cd *= 1 - 0.03 * r" },
			{ id = "fleet", name = "Fleet Foot", cost = "100 + 80 * r", desc = "+{3 * r}% move and attack speed", effect = "h.speed *= 1 + 0.03 * r\nh.rate /= 1 + 0.03 * r" },
		]),
		H({ id = "oracle", name = "Oracle", role = "Support", category = "support", color = col(0xb07cff),
			desc = "Empowers towers. Nearby towers deal +15% damage, Overclock Field makes them fire much faster, and towers use 4 upgrade paths of 3 bigger points instead of 3 paths of 4.",
			hp = 210.0, dmg = 7.0, rate = 0.6, range = 100.0, block = 2, armor = 0.0, regen = 3.0, speed = 150.0, aura = 0.15 },
			A({ id = "overclock", name = "Overclock Field", cd = 24.0, r = 170.0, dur = 6.0, power = 0.6, desc = "Towers within {f0(a.r)} fire {pct(a.power)} faster for {f1(a.dur)}s." }),
			A({ id = "stasis", name = "Stasis Field", cd = 24.0, r = 170.0, dur = 6.0, power = 0.6, desc = "Enemies within {f0(a.r)} of where you cast it are slowed {pct(min(0.85, a.power * 0.75))} for {f1(a.dur)}s." }), [
			{ id = "resonance", name = "Resonance", cost = "60 + 50 * r", desc = "Tower aura gives +{f1t(2.5 * r)}% more damage", effect = "h.aura += 0.025 * r" },
			{ id = "longclock", name = "Long Overclock", cost = "80 + 60 * r", desc = "Overclock Field lasts {f1(0.3 * r)}s longer", effect = "h.ab.dur += 0.3 * r" },
			{ id = "tithe", name = "Rift Tithe", cost = "80 + 60 * r", desc = "Start each run with +{15 * r} gold", stat_label = "Starting gold bonus", stat_value = "{15 * r}", effect = "run.gold += 15 * r" },
			{ id = "widesig", name = "Wide Signal", cost = "100 + 80 * r", desc = "All towers get +{f1t(1.5 * r)}% range", effect = "h.tower_range += 0.015 * r" },
		]),
		H({ id = "sniper", name = "Sniper", role = "Offensive", category = "offensive", color = col(0xffd36e),
			desc = "Hits anything on the map, but has to stand still and brace before every shot. Slow, heavy, precise.",
			hp = 170.0, dmg = 48.0, rate = 2.4, range = 9999.0, block = 1, armor = 0.0, regen = 2.0, speed = 140.0, brace = 1.2, crit = 0.1 },
			A({ id = "pierce", name = "Piercing Shot", cd = 16.0, mult = 4.0, w = 18.0, desc = "Fires a round through every enemy in a line toward your aim point (or the lead enemy) for {f1(a.mult)}× damage." }),
			A({ id = "strike", name = "Orbital Strike", cd = 16.0, mult = 5.0, r = 90.0, desc = "Calls a strike where your cursor is on the map (or the toughest enemy). After 0.8s it hits everything within {f0(a.r)} for {f1(a.mult)}× damage." }), [
			{ id = "rounds", name = "Heavy Rounds", cost = "60 + 50 * r", desc = "+{5 * r}% damage", effect = "h.dmg *= 1 + 0.05 * r" },
			{ id = "stance", name = "Steady Stance", cost = "80 + 60 * r", desc = "Brace {5 * r}% faster", effect = "h.brace *= 1 - 0.05 * r" },
			{ id = "hollow", name = "Hollow Points", cost = "80 + 60 * r", desc = "+{10 * r}% crit damage", effect = "h.crit_dmg += 0.1 * r" },
			{ id = "drills", name = "Piercing Drills", cost = "100 + 80 * r", desc = "Piercing Shot recharges {4 * r}% faster", effect = "h.ab.cd *= 1 - 0.04 * r" },
		]),
		H({ id = "wizard", name = "Wizard", role = "Special", category = "special", color = col(0x7fb2ff), spells = true,
			desc = "A spell caster with no auto-attack. Take 4 elements, ready them with Q W E R and left-click to cast at the cursor: one element, the same one twice for a stronger spell, or two different ones for a combination. An element mastered to level 10 can be readied three times for its ultimate. Spells cost mana, which flows during waves.",
			hp = 190.0, dmg = 0.0, rate = 1.0, range = 0.0, block = 1, armor = 0.0, regen = 2.0, speed = 140.0, mana = 100.0, mana_regen = 7.0 },
			A({ id = "spells", name = "Spellcraft", cd = 0.0 }), null, [
			{ id = "potency", name = "Spell Potency", cost = "60 + 50 * r", desc = "Spells deal +{5 * r}% damage", effect = "h.spell *= 1 + 0.05 * r" },
			{ id = "reservoir", name = "Arcane Reservoir", cost = "80 + 60 * r", desc = "+{10 * r} max mana", effect = "h.max_mana += 10 * r\nh.mana = h.max_mana" },
			{ id = "flow", name = "Mana Flow", cost = "100 + 80 * r", desc = "+{f1(0.6 * r)} mana per second", effect = "h.mana_regen += 0.6 * r" },
		]),
	]


# ---------------- hero upgrades ----------------
func perks() -> Array:
	var ability := ["seismic", "after", "daze", "core", "nfocus", "wide", "surge", "extend", "apround", "steady", "barrier", "adren", "redline", "payload"]
	var kinds := { "blade": "damage", "caliber": "damage", "headhunter": "damage", "crit": "crit", "critdmg": "crit", "clock": "speed", "chamber": "speed", "boots": "speed", "momentum": "speed",
		"plate": "hp", "fort": "hp", "reboot": "hp", "mend": "heal", "siphon": "heal", "arch": "cost", "engineer": "cost", "alchemy": "cost", "signal": "range", "reach": "range", "scope": "range",
		"arcpow": "damage", "manapool": "mana", "manaflow": "mana", "thrift": "mana", "reachsp": "range", "rime": "control", "zephyr": "control", "masonry": "wall", "bounces": "bounce" }
	var list := [
		{ id = "blade", pool = "offensive", name = "Plasma Blade", m = 0.2, desc = "+{pct(m)} hero damage.", effect = "h.dmg *= 1 + m" },
		{ id = "plate", pool = "defensive", name = "Rune Plating", m = 50.0, desc = "+{round(m)} max HP and a full heal.", effect = "h.max_hp += round(m)\nh.hp = h.max_hp" },
		{ id = "mend", pool = "defensive", name = "Nanite Mend", m = 3.0, desc = "+{f1(m)} HP regen per second.", effect = "h.regen += m" },
		{ id = "reboot", pool = "defensive", name = "Quick Reboot", m = 0.15, desc = "Respawn {pct(min(0.7, m))} faster and +{pct(m)} max HP.", effect = "h.respawn = max(2, h.respawn * (1 - min(0.7, m)))\nh.max_hp = round(h.max_hp * (1 + m))\nh.hp = min(h.max_hp, h.hp + h.max_hp * m)" },
		{ id = "arch", pool = "support", name = "Architect", m = 0.07, desc = "New towers cost {pct(min(0.5, m))} less to build.", effect = "h.cost_mul *= 1 - min(0.5, m)" },
		{ id = "engineer", pool = "support", name = "Engineer", m = 0.08, desc = "Tower upgrades (level-ups) cost {pct(min(0.5, m))} less.", effect = "h.lvl_mul *= 1 - min(0.5, m)" },
		{ id = "reach", pool = "support", name = "Long Reach", m = 0.2, desc = "+{pct(m)} build range and all towers get +{pct(m / 4)} range.", effect = "h.build_range *= 1 + m\nh.tower_range += m / 4" },
		{ id = "bounty", pool = "offensive", gold = true, name = "Bounty Sigil", m = 0.8, desc = "Enemies your hero kills drop +{max(1, round(m))} gold.", effect = "h.bounty += max(1, round(m))" },
		{ id = "tithe", pool = "defensive", also_pools = ["support"], gold = true, name = "War Tithe", m = 0.3, desc = "Every enemy killed by your towers or your hero drops +{max(1, round(m))} gold.", effect = "h.tithe += max(1, round(m))" },
		{ id = "siphon", pool = "defensive", name = "Siphon", m = 3.0, desc = "Heal {round(m)} HP for every kill.", effect = "h.siphon += round(m)" },
		{ id = "boots", pool = "any", attack_speed = true, name = "Rift Boots", m = 0.15, desc = "+{pct(m)} move speed and +{pct(m / 2)} attack speed.", effect = "h.speed *= 1 + m\nh.rate /= 1 + m / 2" },
		{ id = "taunt", pool = "vanguard", name = "Taunt", m = 2.0, desc = "After Shield Slam, enemies within 120 stop and attack you for {f1(m)}s.", effect = "h.taunt += m" },
		{ id = "shell", pool = "vanguard", name = "Hardlight Shell", m = 0.08, desc = "Take {pct(m)} less damage (up to 75%).", effect = "h.armor = min(0.75, h.armor + m)" },
		{ id = "thorns", pool = "vanguard", name = "Thorn Field", m = 8.0, desc = "Enemies you block take {round(m)} damage per second.", effect = "h.thorns += m" },
		{ id = "seismic", pool = "vanguard", name = "Seismic Power", m = 0.3, desc = "{h.ab.name} is +{pct(m)} stronger (damage{iff(h.ab.id == 'bulwark', ', shield size', '')}).", effect = "h.ab.dmg *= 1 + m" },
		{ id = "after", pool = "vanguard", name = "Aftershock", m = 0.1, desc = "{h.ab.name} recharges {pct(min(0.5, m))} faster.", effect = "h.ab.cd = max(6, h.ab.cd * (1 - min(0.5, m)))" },
		{ id = "daze", pool = "vanguard", ability = "slam", name = "Concussion", m = 0.4, desc = "Shield Slam stuns {f1(m)}s longer.", effect = "h.ab.stun += m" },
		{ id = "fort", pool = "defensive", name = "Fortify", m = 0.15, desc = "+{pct(m)} max HP.", effect = "h.max_hp = round(h.max_hp * (1 + m))\nh.hp = h.max_hp" },
		{ id = "crit", pool = "offensive", name = "Weak Point", m = 0.08, desc = "+{pct(m)} crit chance.", effect = "h.crit = min(0.75, h.crit + m)" },
		{ id = "critdmg", pool = "offensive", name = "Lethal Edge", m = 0.25, desc = "+{pct(m)} crit damage.", effect = "h.crit_dmg += m" },
		{ id = "bounce", pool = "striker", name = "Ricochet", m = 0.1, desc = "{iff(h.bounce_keep >= 0.999, 'Ricochets bounce 1 more time, still at full damage.', iff(h.bounce, 'Ricochets', 'Shots ricochet to 1 more enemy and') + ' keep ' + pct(iff(h.bounce_keep, min(1, h.bounce_keep + m), 0.4 + m)) + ' of their damage each bounce.')}", effect = "h.bounce = iff(h.bounce_keep >= 0.999, min(8, h.bounce + 1), max(1, h.bounce))\nh.bounce_keep = iff(h.bounce_keep, min(1, h.bounce_keep + m), 0.4 + m)" },
		{ id = "bounces", pool = "striker", name = "Extra Bounce", m = 1.0, after = "bounce", desc = "Ricochets bounce {max(1, round(m))} more time{iff(round(m) > 1, 's', '')}.", effect = "h.bounce = min(8, h.bounce + max(1, round(m)))" },
		{ id = "scope", pool = "striker", name = "Long Barrel", m = 0.12, desc = "+{pct(m)} attack range.", effect = "h.range *= 1 + m" },
		{ id = "clock", pool = "striker", name = "Overclock", m = 0.15, desc = "+{pct(m)} attack speed.", effect = "h.rate /= 1 + m" },
		{ id = "core", pool = "striker", ability = "nova", name = "Nova Core", m = 0.3, desc = "Rift Nova deals +{pct(m)} damage.", effect = "h.ab.dmg *= 1 + m" },
		{ id = "nfocus", pool = "striker", name = "Rift Focus", m = 0.1, desc = "{h.ab.name} recharges {pct(min(0.5, m))} faster.", effect = "h.ab.cd = max(6, h.ab.cd * (1 - min(0.5, m)))" },
		{ id = "wide", pool = "striker", ability = "nova", name = "Wide Nova", m = 0.12, desc = "Rift Nova radius +{pct(m)}.", effect = "h.ab.r *= 1 + m" },
		{ id = "momentum", pool = "striker", name = "Momentum", m = 0.03, desc = "Each kill by your hero gives +{pct(m)} attack speed for 4s, stacking up to 10 times.", effect = "h.momentum += m" },
		{ id = "rapid", pool = "oracle", min_rarity = "rare", name = "Rapid Construction", m = 0.6, desc = "Towers you build within your aura get their first {max(1, round(m))} level-up{iff(round(m) > 1, 's', '')} free.", effect = "h.rapid += max(1, round(m))" },
		{ id = "aura", pool = "oracle", name = "Commander Aura", m = 0.08, desc = "Towers near you deal +{pct(m)} more damage.", effect = "h.aura += m" },
		{ id = "signal", pool = "oracle", name = "Signal Boost", m = 0.15, desc = "Aura reaches {pct(m)} farther and all towers get +{pct(m / 3)} range.", effect = "h.aura_range *= 1 + m\nh.tower_range += m / 3" },
		{ id = "surge", pool = "oracle", name = "Power Surge", m = 0.15, desc = "{iff(h.ab.id == 'stasis', 'Stasis Field slows ' + pct(m * 0.75) + ' more.', 'Overclock Field speeds towers up ' + pct(m) + ' more.')}", effect = "h.ab.power += m" },
		{ id = "extend", pool = "oracle", name = "Extended Field", m = 1.5, desc = "{h.ab.name} lasts {f1(m)}s longer.", effect = "h.ab.dur += m" },
		{ id = "chill", pool = "oracle", name = "Chilling Presence", m = 0.08, desc = "Towers near you also slow enemies by {pct(m)}.", effect = "h.aura_slow = min(0.6, h.aura_slow + m)" },
		{ id = "interest", pool = "oracle", gold = true, name = "Investments", m = 0.012, desc = "Earn {pct(m)} interest on your gold after each wave.", effect = "h.interest += m" },
		{ id = "brace", pool = "sniper", name = "Quick Brace", m = 0.15, desc = "Brace {pct(min(0.6, m))} faster.", effect = "h.brace = max(0.25, h.brace * (1 - min(0.6, m)))" },
		{ id = "caliber", pool = "sniper", name = "Heavy Caliber", m = 0.25, desc = "+{pct(m)} hero damage.", effect = "h.dmg *= 1 + m" },
		{ id = "chamber", pool = "sniper", name = "Fast Chamber", m = 0.12, desc = "+{pct(m)} attack speed.", effect = "h.rate /= 1 + m" },
		{ id = "penetrate", pool = "sniper", name = "Penetrator", m = 1.0, desc = "Shots also hit {max(1, round(m))} enemy near the target for 50% damage.", effect = "h.pierce += max(1, round(m))" },
		{ id = "apround", pool = "sniper", name = "Armor-Piercing Rounds", m = 0.3, desc = "{h.ab.name} deals +{pct(m)} damage.", effect = "h.ab.mult *= 1 + m" },
		{ id = "spotter", pool = "sniper", name = "Spotter", m = 0.1, desc = "Your target takes +{pct(m)} damage from towers for 3s.", effect = "h.spotter += m" },
		{ id = "headhunter", pool = "sniper", name = "Headhunter", m = 0.25, desc = "+{pct(m)} hero damage to bosses.", effect = "h.headhunter += m" },
		{ id = "steady", pool = "sniper", name = "Steady Aim", m = 0.1, desc = "{h.ab.name} recharges {pct(min(0.5, m))} faster.", effect = "h.ab.cd = max(5, h.ab.cd * (1 - min(0.5, m)))" },
		{ id = "barrier", pool = "vanguard", ability = "bulwark", name = "Hardened Barrier", m = 1.0, desc = "Bulwark Shield lasts {f1(m)}s longer.", effect = "h.ab.dur += m" },
		{ id = "adren", pool = "striker", ability = "overdrive", name = "Adrenaline", m = 1.0, desc = "Overdrive lasts {f1(m)}s longer.", effect = "h.ab.dur += m" },
		{ id = "redline", pool = "striker", ability = "overdrive", name = "Redline", m = 0.25, desc = "Overdrive gives +{pct(m)} more attack speed.", effect = "h.ab.power += m" },
		{ id = "payload", pool = "sniper", ability = "strike", name = "Bigger Payload", m = 0.15, desc = "Orbital Strike blast is {pct(m)} wider.", effect = "h.ab.r *= 1 + m" },
		{ id = "arcpow", pool = "wizard", name = "Arcane Power", m = 0.15, desc = "Spells deal +{pct(m)} damage.", effect = "h.spell *= 1 + m" },
		{ id = "manapool", pool = "wizard", name = "Deep Reserves", m = 20.0, desc = "+{round(m)} max mana and a full refill.", effect = "h.max_mana += round(m)\nh.mana = h.max_mana" },
		{ id = "manaflow", pool = "wizard", name = "Mana Spring", m = 1.5, desc = "+{f1(m)} mana per second.", effect = "h.mana_regen += m" },
		{ id = "thrift", pool = "wizard", name = "Spell Thrift", m = 0.07, desc = "Spells cost {pct(min(0.5, m))} less mana (up to 50%).", effect = "h.spell_cost = max(0.5, h.spell_cost * (1 - min(0.5, m)))" },
		{ id = "reachsp", pool = "wizard", name = "Wide Casting", m = 0.1, desc = "Spells cover +{pct(m)} more area.", effect = "h.spell_r *= 1 + m" },
		{ id = "rime", pool = "wizard", needs = "freeze", name = "Rime", m = 0.3, desc = "Freezes last {f1(m)}s longer.", effect = "h.freeze_bonus += m" },
		{ id = "masonry", pool = "wizard", needs = "wall", name = "Masonry", m = 0.25, desc = "Stone walls have +{pct(m)} HP.", effect = "h.wall_bonus *= 1 + m" },
		{ id = "zephyr", pool = "wizard", needs = "push", name = "Zephyr", m = 0.2, desc = "Enemies you blow back are pushed {pct(m)} longer.", effect = "h.push_bonus *= 1 + m" },
	]
	var els := { "fire": ["Fire", "fire"], "water": ["Water", "water"], "earth": ["Earth", "earth"], "air": ["Air", "air"], "storm": ["Lightning", "lightning"], "nature": ["Nature", "nature"], "void": ["Void", "void"], "light": ["Light", "light"] }
	for el in els:
		list.append({ id = "att_" + el, pool = "wizard", element = el, name = els[el][0] + " Attunement", m = 0.12, desc = "Spells that use %s deal +{pct(m)} damage." % els[el][1], effect = "h.attune('%s', m)" % el })
	list.append({ id = "alchemy", pool = "support", name = "Alchemist", m = 0.15, desc = "Tower merges cost {pct(min(0.8, m))} less.", effect = "h.merge_mul *= 1 - min(0.8, m)" })
	for p in list:
		if p.has("ability") or ability.has(p.id):
			p.kind = "ability"
		elif p.get("gold", false):
			p.kind = "gold"
		else:
			p.kind = kinds.get(p.id, p.id)
	return list


func ability_mods() -> Array:
	var base := { vanguard = "slam", striker = "nova", oracle = "overclock", sniper = "pierce" }
	var out := []
	for x in [
		["vanguard", "rings", "rings", "Shockwave Rings", "Shield Slam sends out 3 expanding rings that each hit for 40% damage and push enemies back."],
		["vanguard", "magnet", "magnet", "Magnetic Slam", "Shield Slam reaches 50% farther and drags every enemy it hits back along the path."],
		["vanguard", "molten", "molten", "Molten Crater", "Shield Slam leaves a glowing crater for 4s that burns and slows enemies inside."],
		["vanguard", "echo", "echo", "Echo Slam", "A second slam hits 1s later for 50% damage."],
		["striker", "twin", "twin", "Twin Nova", "A second nova bursts on the toughest enemy on the map."],
		["striker", "hole", "hole", "Black Hole", "Rift Nova first holds enemies in a vortex for 1.5s, then explodes for 150% damage."],
		["striker", "chainN", "chain_n", "Chain Nova", "Every enemy Rift Nova kills sets off a smaller nova of its own."],
		["striker", "dash", "dash", "Nova Dash", "You dash toward the cursor before the nova, leaving a burning trail."],
		["oracle", "mobile", "mobile", "Mobile Field", "Overclock Field follows you around."],
		["oracle", "chrono", "chrono", "Chrono Field", "Enemies inside Overclock Field are slowed 30%, and tower shots inside it jump to 1 more enemy."],
		["oracle", "burst", "burst", "Overcharge Burst", "When Overclock Field ends, every tower inside fires one 3× damage shot."],
		["oracle", "prismF", "prism_f", "Prism Field", "Towers inside Overclock Field fire a bonus beam at a second enemy."],
		["sniper", "rail", "rail", "Railgun", "Piercing Shot is 3× wider and leaves a burning line for 3s."],
		["sniper", "bounce", "bounce", "Ricochet Round", "Piercing Shot bounces through 5 more enemies after its line."],
		["sniper", "cluster", "cluster", "Cluster Round", "Every enemy Piercing Shot hits explodes for 40% damage around it."],
		["vanguard", "spiked", "spiked", "Spiked Barrier", "While Bulwark Shield is up, enemies you block take 40 damage per second.", "bulwark"],
		["vanguard", "overflow", "overflow", "Overflowing Shield", "Bulwark Shield is 50% bigger, and whatever is left of it when it ends heals you.", "bulwark"],
		["striker", "bloodrush", "bloodrush", "Blood Rush", "Each kill during Overdrive extends it by 0.4s (up to 4s more).", "overdrive"],
		["striker", "afterimg", "afterimg", "Afterimage", "During Overdrive your attacks hit 2 more enemies.", "overdrive"],
		["oracle", "shatterS", "shatter_s", "Shattering Stasis", "Enemies inside Stasis Field take +25% damage from everything.", "stasis"],
		["oracle", "anchor", "anchor", "Rift Anchor", "Casting Stasis Field freezes every enemy inside it solid for 1.5s (bosses 0.5s).", "stasis"],
		["sniper", "carpet", "carpet", "Carpet Strike", "Orbital Strike drops 3 more blasts around the target for 50% damage.", "strike"],
		["sniper", "scorch", "scorch", "Scorched Earth", "Orbital Strike leaves burning ground for 4s.", "strike"],
		["sniper", "execR", "exec_r", "Execution Round", "Piercing Shot kills non-boss enemies below 30% HP, and each kill refunds 10% of its cooldown (up to 40% per shot)."],
	]:
		out.append({ id = x[1], pool = x[0], name = x[3], desc = x[4], effect = "h.ab.%s = true" % x[2], ability = x[5] if x.size() > 5 else base[x[0]], kind = "ability", min_rarity = "rare" })
	return out


func uniques() -> Array:
	var list := [
		{ id = "echo", pool = "wizard", rarity = "legendary", name = "Arcane Echo", desc = "Every 4th spell you cast repeats itself at 60% power.", effect = "h.echo = 4" },
		{ id = "archmage", pool = "wizard", rarity = "legendary", name = "Archmage", desc = "+25% spell damage and spells cost 15% less mana.", effect = "h.spell *= 1.25\nh.spell_cost *= 0.85" },
		{ id = "aegis", pool = "vanguard", rarity = "legendary", name = "Aegis Core", desc = "Take 20% less damage and gain 150 max HP.", effect = "h.max_hp += 50\nh.armor = min(0.75, h.armor + 0.2)\nh.max_hp += 100\nh.hp = h.max_hp" },
		{ id = "unbreak", pool = "vanguard", rarity = "legendary", name = "Unbreakable", desc = "Once per wave, a fatal blow leaves you at full HP instead.", effect = "h.unbreakable = true" },
		{ id = "exec", pool = "striker", rarity = "legendary", name = "Executioner", desc = "+20% damage. Your hits instantly finish non-boss enemies below 15% HP.", effect = "h.dmg *= 1.2\nh.execute = 0.15" },
		{ id = "stasisL", pool = "oracle", ability = "stasis", rarity = "legendary", name = "Frozen Moment", desc = "Stasis Field is 30% wider and every tower inside it fires 30% faster.", effect = "h.ab.r *= 1.3\nh.ab.haste = 0.3" },
		{ id = "storm", pool = "striker", rarity = "legendary", name = "Bullet Storm", desc = "Every 3rd attack hits every enemy in range.", effect = "h.bullet_storm = 3" },
		{ id = "master", pool = "oracle", rarity = "legendary", name = "Master Architect", desc = "All towers deal +25% damage, and new towers cost 20% less to build.", effect = "run.mod_tower_dmg += 0.25\nh.cost_mul *= 0.8" },
		{ id = "warp", pool = "oracle", ability = "overclock", rarity = "legendary", name = "Time Warp", desc = "Overclock Field also slows enemies inside it by 40%.", effect = "h.time_warp = 0.4" },
		{ id = "deadeye", pool = "sniper", rarity = "legendary", name = "Deadeye", desc = "Every 3rd shot is a guaranteed crit, and crits deal +50% more damage.", effect = "h.deadeye = 3\nh.crit_dmg += 0.5" },
		{ id = "overwatch", pool = "sniper", rarity = "legendary", name = "Overwatch", desc = "Your shots stun their target for 0.5s (bosses 0.2s).", effect = "h.shot_stun = 0.5" },
		{ id = "sun", pool = "any", rarity = "secret", name = "Second Sun", desc = "Your ability casts itself whenever it is ready, and recharges 25% faster.", effect = "h.auto_cast = true\nh.ab.cd = max(5, h.ab.cd * 0.75)" },
		{ id = "midas", pool = "any", rarity = "secret", name = "Midas Protocol", desc = "Enemies drop double gold.", effect = "run.mod_gold += 1" },
		{ id = "heart", pool = "any", rarity = "secret", name = "Rift Heart", desc = "All towers deal +30% damage and fire 30% faster.", effect = "run.mod_tower_dmg += 0.3\nrun.mod_tower_rate *= 0.7" },
	]
	for u in list:
		u.kind = "ability" if u.has("ability") else "unique:" + u.id
	return list


func curses() -> Array:
	return [
		{ id = "0", desc = "Enemies have {round(5 * k)}% more HP.", effect = "run.mod_enemy_hp += 0.05 * k" },
		{ id = "1", desc = "Lose {round(2 * k)} base HP.", effect = "run.lives = max(1, run.lives - round(2 * k))" },
		{ id = "2", desc = "Your hero loses {round(min(50, 10 * k))}% max HP.", effect = "h.max_hp = round(h.max_hp * (1 - min(0.5, 0.1 * k)))\nh.hp = min(h.hp, h.max_hp)" },
		{ id = "3", desc = "New towers cost {round(8 * k)}% more to build.", effect = "h.cost_mul *= 1 + 0.08 * k" },
		{ id = "4", desc = "Lose {round(60 * k)} gold.", effect = "run.gold = max(0, run.gold - round(60 * k))" },
		{ id = "5", desc = "Enemies move {round(4 * k)}% faster.", effect = "run.mod_enemy_speed += 0.04 * k" },
	]


func heroics() -> Array:
	return [
		{ id = "blades", heroes = [], name = "Orbiting Blades", desc = "{r + 1} blades circle your hero, each dealing {20 * r} damage per second to enemies they touch." },
		{ id = "retribution", heroes = ["vanguard"], name = "Retribution", desc = "Every 4s, a shockwave hits enemies within 110 of your hero for {20 * r} damage plus {30 * r}% of the damage you took since the last one." },
		{ id = "barrage", heroes = ["striker"], name = "Rift Barrage", desc = "Every 5s, fire {2 + 2 * r} homing rift missiles at enemies near your hero, each dealing 150% hero damage + {10 * r}." },
		{ id = "drone", heroes = ["striker", "oracle", "wizard"], name = "Turret Drone", desc = "{r} drone{s(r)} fly beside your hero and shoot the nearest enemy for {10 + 8 * r} damage." },
		{ id = "timestop", heroes = ["oracle", "sniper", "wizard"], name = "Time Stop", desc = "Every 25s, every enemy on the map freezes for {1 + r}s." },
		{ id = "wither", heroes = ["vanguard", "wizard"], name = "Withering Aura", desc = "Enemies within {90 + 20 * r} of your hero take {10 * r} damage per second and are slowed 20%." },
		{ id = "chainstrike", heroes = ["striker"], name = "Chain Strike", desc = "Your attacks jump to {1 + r} more enemies for 60% damage." },
		{ id = "goldrush", heroes = ["oracle"], name = "Gold Rush", desc = "Kills have a {8 * r}% chance to drop 15 bonus gold." },
		{ id = "phoenix", heroes = ["vanguard"], name = "Phoenix Rebirth", desc = "When knocked out, explode for {150 * r} damage and respawn in 2s." },
		{ id = "ricochet", heroes = ["sniper"], name = "Ricochet", desc = "Your shots bounce to {r} more enem{iff(r > 1, 'ies', 'y')} for 50% damage." },
		{ id = "marked", heroes = ["sniper"], name = "Marked for Death", desc = "Every 5th shot marks its target for 4s: marked enemies take +{20 * r}% damage from everything." },
	]


func relics() -> Array:
	return [
		{ id = "overcharger", name = "Overcharger", desc = "All towers deal +15% damage.", effect = "run.mod_tower_dmg += 0.15" },
		{ id = "cryocore", name = "Cryo Core", desc = "All slows are 15% stronger.", effect = "run.mod_slow += 0.15" },
		{ id = "treasury", name = "Rift Treasury", desc = "+25% gold from kills.", effect = "run.mod_gold += 0.25" },
		{ id = "lens", name = "Farsight Lens", desc = "All towers +12% range.", effect = "h.tower_range += 0.12" },
		{ id = "warbanner", offensive_only = true, name = "War Banner", desc = "Hero deals +25% damage.", effect = "h.dmg *= 1.25" },
		{ id = "repair", name = "Repair Drones", desc = "Restore 6 base HP.", repeat = true, effect = "run.lives += 6" },
		{ id = "capacitor", name = "Capacitor", desc = "Towers fire 10% faster.", effect = "run.mod_tower_rate *= 0.9" },
	]


func legendary_relics() -> Array:
	return [
		{ id = "starforge", rarity = "legendary", name = "Starforge", desc = "All towers deal +30% damage and get +10% range.", effect = "run.mod_tower_dmg += 0.3\nh.tower_range += 0.1" },
		{ id = "chrono", rarity = "legendary", name = "Chrono Engine", desc = "All towers fire 20% faster.", effect = "run.mod_tower_rate *= 0.8" },
		{ id = "phoenixcore", rarity = "legendary", name = "Phoenix Core", desc = "The first time your base would fall, it survives with 10 HP.", effect = "run.mod_phoenix = true" },
	]


func secret_relics() -> Array:
	return [
		{ id = "crown", rarity = "secret", name = "Rift Crown", desc = "Every tower you own gains 2 free levels of damage.", repeat = true, effect = "run.crown()" },
		{ id = "loop", rarity = "secret", name = "Infinity Loop", desc = "Your ability recharges twice as fast and your hero attacks 30% faster.", effect = "h.ab.cd = max(5, h.ab.cd / 2)\nh.rate *= 0.7" },
	]


func tough() -> Array:
	return [
		{ id = "hp", name = "Thick Hide", pts = 1, desc = "Enemies have 40% more HP." },
		{ id = "armor", name = "Plated", pts = 1, desc = "Enemies take 15% less damage (extra armor)." },
		{ id = "speed", name = "Quickened", pts = 1, desc = "Enemies move 20% faster." },
		{ id = "regen", name = "Regenerating", pts = 1, desc = "Enemies heal 2% of their max HP every second." },
		{ id = "horde", name = "Horde", pts = 1, desc = "25% more enemies." },
		{ id = "steady", name = "Steadfast", pts = 1, desc = "Slows are half as strong." },
	]


func challenges() -> Array:
	return [
		{ id = "swarm", name = "Swarm", pts = 1, desc = "Twice as many enemies, each with 35% less HP." },
		{ id = "blitz", name = "Blitz", pts = 2, desc = "Enemies move 40% faster." },
		{ id = "iron", name = "Iron Tide", pts = 2, desc = "Every enemy is a brute." },
		{ id = "lone", name = "Lone Hero", pts = 1, desc = "Towers deal 40% less damage. Your hero deals double." },
		{ id = "weak", name = "Dampened", pts = 2, desc = "Towers deal 25% less damage." },
		{ id = "benched", name = "Benched", pts = 1, desc = "Your hero can’t attack (abilities still work)." },
	]


func requirements() -> Array:
	return [
		{ id = "flawless", name = "Flawless", pts = 2, desc = "Lose no base HP." },
		{ id = "last", name = "Last Stand", pts = 3, desc = "If a single enemy gets through, you lose the run." },
		{ id = "timed", name = "Against the Clock", pts = 1, desc = "Clear the wave before the timer runs out." },
		{ id = "alive", name = "Unbroken", pts = 1, desc = "Your hero must not be knocked out." },
	]


func shop() -> Array:
	return [
		{ id = "conduit", shop_kind = "Tower", name = "Rift Conduit", price = 300, m = 0.2, desc = "All towers deal +{pct(m)} damage.", effect = "run.mod_tower_dmg += m" },
		{ id = "hyper", shop_kind = "Tower", name = "Hyperclock Array", price = 320, m = 0.12, desc = "All towers fire {pct(m)} faster.", effect = "run.mod_tower_rate *= 1 - min(0.5, m)" },
		{ id = "matrix", shop_kind = "Tower", name = "Farsight Matrix", price = 220, m = 0.12, desc = "All towers get +{pct(m)} range.", effect = "h.tower_range += m" },
		{ id = "codex", shop_kind = "Tower", name = "Mastery Codex", price = 450, m = 1.0, desc = "Every tower can use {f0(m)} more upgrade path{s(m)}.", effect = "run.path_bonus += m" },
		{ id = "primer", shop_kind = "Tower", name = "Path Primer", price = 260, m = 3.0, desc = "Your next {f0(m)} tower upgrades are free.", effect = "run.free_levels += m" },
		{ id = "breaker", shop_kind = "Tower", name = "Titanbreaker Rounds", price = 340, m = 0.3, desc = "All towers deal +{pct(m)} damage to bosses.", effect = "run.mod_boss_dmg += m" },
		{ id = "lattice", shop_kind = "Tower", name = "Cryo Lattice", price = 280, m = 0.1, desc = "Every tower hit also slows enemies by {pct(m)}.", effect = "run.mod_all_slow += m" },
		{ id = "ember", shop_kind = "Tower", name = "Ember Coating", price = 280, m = 0.25, desc = "Every tower hit also burns for {pct(m)} of its damage over 2s.", effect = "run.mod_all_burn += m" },
		{ id = "titan", shop_kind = "Hero", name = "Titan Frame", price = 260, m = 0.4, desc = "Hero +{pct(m)} max HP and takes {pct(m / 2)} less damage.", effect = "h.max_hp = round(h.max_hp * (1 + m))\nh.hp = h.max_hp\nh.armor = min(0.8, h.armor + m / 2)" },
		{ id = "riftblade", shop_kind = "Hero", name = "Rift Blade", price = 280, m = 0.4, desc = "Hero +{pct(m)} damage and +{pct(m / 4)} crit chance.", effect = "h.dmg *= 1 + m\nh.crit = min(0.9, h.crit + m / 4)" },
		{ id = "chrono", shop_kind = "Hero", name = "Chrono Battery", price = 240, m = 0.25, desc = "Your ability recharges {pct(min(0.6, m))} faster.", effect = "h.ab.cd = max(4, h.ab.cd * (1 - min(0.6, m)))" },
		{ id = "soul", shop_kind = "Hero", name = "Soul Engine", price = 300, m = 2.0, desc = "Pick {f0(m)} hero upgrades right now.", effect = "run.pending_levels += m" },
		{ id = "contract", shop_kind = "Hero", name = "Bounty Contract", price = 220, m = 3.0, desc = "+{f0(m)} gold for every kill.", effect = "h.bounty += m" },
		{ id = "bulwark", shop_kind = "Hero", name = "Rift Bulwark", price = 200, m = 8.0, desc = "Your base gains {f0(m)} HP.", effect = "run.lives += m" },
	]


func global_meta() -> Array:
	return [
		{ id = "gold", name = "War Chest", cost = "50 + 40 * r", desc = "Start with +{15 * r} gold", stat_label = "Starting gold", stat_value = "{150 + 15 * r}" },
		{ id = "lives", name = "Reinforced Core", cost = "50 + 40 * r", desc = "Base starts with +{round(1.5 * r)} HP", stat_label = "Base HP", stat_value = "{20 + round(1.5 * r)}" },
		{ id = "reroll", name = "Fate Weaver", cost = "100 + 80 * r", desc = "+{r} upgrade reroll{s(r)} per run", stat_label = "Rerolls per run", stat_value = "{2 + r}" },
		{ id = "luck", name = "Lucky Star", cost = "120 + 100 * r", desc = "Rarer upgrades are {4 * r}% more likely", stat_label = "Rarer upgrade odds", stat_value = "+{4 * r}%" },
		{ id = "vet", name = "Veteran", cost = "240 + 200 * r", desc = "Start each run with {vet(r)} free hero upgrade{s(vet(r))}, and your hero gains {4 * r}% more XP", stat_label = "Free upgrades / XP gain", stat_value = "{vet(r)} / +{4 * r}%" },
		{ id = "fortune", name = "Fortune’s Favor", cost = "600 + 500 * r", desc = "Better upgrade odds: Rare and above {8 * r}% more likely, Common {4 * r}% less likely", stat_label = "Rare and above odds", stat_value = "+{8 * r}%" },
	]


func tower_global() -> Array:
	return [
		{ id = "main", name = "Main Effect", cost = "80 + 60 * r", desc = "Every tower's main effect is {4 * r}% stronger: damage for attacking towers, slow strength for the Frost Pylon, the damage buff for the Rift Beacon", stat_label = "Main effect", stat_value = "+{4 * r}%" },
		{ id = "cost", name = "Upgrade Cost Reduction", cost = "80 + 70 * r", desc = "Tower level-ups cost {f1t(2.5 * r)}% less", stat_label = "Level-up cost", stat_value = "-{f1t(2.5 * r)}%" },
		{ id = "range", name = "Attack Range", cost = "80 + 70 * r", desc = "All towers get +{2 * r}% range", stat_label = "Tower range", stat_value = "+{2 * r}%" },
		{ id = "speed", name = "Attack Speed", cost = "100 + 80 * r", desc = "All towers attack {2 * r}% faster", stat_label = "Tower attack speed", stat_value = "+{2 * r}%" },
	]


func specials() -> Array:
	return [
		{ id = "sovereign", rarity = "mythic", cores = 25, name = "Rift Sovereign", desc = "Start every run with a random Legendary upgrade for your hero." },
		{ id = "second", rarity = "mythic", cores = 30, name = "Second Chance", desc = "Once per run, when your base would fall, the wave restarts with your base at 10 HP." },
		{ id = "bazaar", rarity = "legendary", cores = 40, name = "Grand Bazaar", desc = "Boss shops show 9 items instead of 6, and the first item you buy in each is free." },
		{ id = "foundry", rarity = "legendary", cores = 50, name = "Ascendant Foundry", desc = "Every tower you build gets its first 2 level-ups free." },
		{ id = "pact", rarity = "secret", cores = 200, name = "Demon Pact", desc = "Demonic shops go from 1% to 10%, and every demonic curse is half as strong." },
		{ id = "bulwarkS", hero = "vanguard", rarity = "mythic", cores = 35, name = "Immortal Bulwark", desc = "Start each run with Aegis Core and Unbreakable, and Unbreakable can save you twice per wave." },
		{ id = "dancer", hero = "striker", rarity = "mythic", cores = 35, name = "Blade Dancer", desc = "Rift Nova casts itself every 8th kill by your hero, on top of its normal cooldown." },
		{ id = "conductor", hero = "oracle", rarity = "legendary", cores = 45, name = "Grand Conductor", desc = "Overclock Field is always on at half power across the whole map." },
		{ id = "oneshot", hero = "sniper", rarity = "legendary", cores = 45, name = "One Shot", desc = "The first shot of every wave deals 10× damage, and each kill gives your next brace a head start." },
	]


# ---------------- fusions and recipes ----------------
func fusions() -> FusionList:
	var l := FusionList.new()
	var arr: Array[FusionData] = []
	for x in [
		["chainreact", "Chain Reaction", ["burst", "burn"], "Enemies this tower kills explode for {round(8 * r * m)}% of their max HP.", "t.death_blast += 0.08 * m"],
		["frostfire", "Frostfire", ["slow", "burn"], "Hits on slowed enemies burn them for {round(30 * r * m)}% of the hit, and burning enemies are slowed.", "t.frostfire += 0.3 * m"],
		["echo", "Echo Shot", ["speed", "power"], "Every shot repeats a moment later for {round(15 * r * m)}% damage.", "t.echo += 0.15 * m"],
		["shatter", "Shatter", ["slow", "precision"], "Stunned or frozen enemies take +{round(25 * r * m)}% damage from this tower.", "t.shatter += 0.25 * m"],
		["gravity", "Gravity Well", ["burst", "slow"], "Every 5th shot drags enemies near the target {round(15 * r * m)} steps back along the path.", "t.gravity += 15 * m"],
		["execute", "Executioner", ["precision", "power"], "Hits finish off non-boss enemies below {round(4 * r * m)}% HP.", "t.execute = min(0.35, t.execute + 0.04 * m)"],
		["prism", "Prism Split", ["multi", "arcane"], "Each hit splits to {round(r * m)} nearby enemies for 40% damage.", "t.prism += m"],
		["storm", "Storm Call", ["chain", "power"], "Every 4th shot calls lightning on {round(r * m)} random enemies in range.", "t.storm += m"],
		["ionburst", "Ion Burst", ["chain", "burst"], "Lightning jumps explode for {round(10 * r * m)}% damage around them.", "t.chain_blast += 0.1 * m\nt.chain = iff(t.chain > 0, t.chain, 2)"],
		["timelock", "Time Lock", ["slow", "arcane"], "Every 8th shot stuns every enemy in range for {f2(0.15 * r * m)}s.", "t.time_lock += 0.15 * m"],
		["corrode", "Corrosion", ["burn", "precision"], "Hits melt armor: enemies take +{round(5 * r * m)}% damage from everything for 2s.", "t.mark += 0.05 * m"],
		["phase", "Phase Rounds", ["precision", "multi"], "Shots pass through and hit {round(r * m)} enemies behind the target for 60% damage.", "t.pierce += m"],
		["gilded", "Gilded Rounds", ["power", "arcane"], "Kills by this tower drop +{round(2 * r * m)} gold.", "t.loot += 2 * m"],
		["siphon", "Soul Siphon", ["arcane", "burn"], "Kills by this tower heal your hero {round(4 * r * m)} HP and give extra XP.", "t.leech += 4 * m"],
		["overload", "Overload", ["chain", "speed"], "Every 10th shot deals +{round(60 * r * m)}% damage and stuns for 0.5s.", "t.overload += 0.6 * m"],
		["nova", "Rift Nova", ["burst", "arcane"], "Every 6th shot blasts every enemy in range for {round(20 * r * m)}% damage.", "t.nova += 0.2 * m"],
		["tempo", "Tempo Field", ["speed", "multi"], "Each shot makes the next one {round(4 * r * m)}% faster, up to 5 stacks (resets on a miss).", "t.tempo += 0.04 * m"],
		["static", "Static Web", ["chain", "slow"], "Lightning and hits slow enemies by {round(6 * r * m)}% for 1.5s.", "t.slow = min(0.85, max(t.slow, 0.06 * m * (t.ups_of('static') + 1)))\nt.slow_dur = max(t.slow_dur, 1.5)"],
	]:
		var f := FusionData.new()
		f.id = x[0]; f.name = x[1]; f.tags = PackedStringArray(x[2]); f.desc = x[3]; f.effect = x[4]
		arr.append(f)
	l.items = arr
	return l


func recipes() -> RecipeList:
	var boons := {
		"arcane+frost": ["Frostbitten Strikes", "Your hero’s attacks slow enemies by 30%.", "h.boon_slow = 0.3"],
		"arcane+plasma": ["Starburst Rounds", "Your hero’s attacks explode, dealing 40% damage to nearby enemies.", "h.boon_splash = 0.4"],
		"arcane+tesla": ["Rail Lance", "Every 4th hero attack deals 4× damage.", "h.boon_rail = 4"],
		"frost+plasma": ["Steam Vent", "Enemies within 80 of your hero take 15 damage per second and are slowed 15%.", "h.boon_vent = 15"],
		"frost+tesla": ["Static Frost", "Your hero’s attacks jump to 2 more enemies for 50% damage and slow them.", "h.boon_chain = 2"],
		"plasma+tesla": ["Ion Discharge", "Every 6s, lightning strikes 4 random enemies for 60 damage plus double your hero damage.", "h.boon_ion = 6"],
	}
	var l := RecipeList.new()
	var arr: Array[RecipeData] = []
	for x in [
		["arcane+frost", "Rimeshard", 0xc9b8ff, "Fires rapid ice shards that slow every enemy they hit. Arcane speed with Frost control."],
		["arcane+plasma", "Starbolt", 0xff6fd8, "Fires fast bolts that explode on impact. Arcane speed with Plasma splash, so it shreds groups."],
		["arcane+tesla", "Railgun", 0x8affff, "Fires heavy bolts that arc to more enemies on hit. Huge single hits that also clear lines."],
		["frost+plasma", "Steam Engine", 0xe0e6ff, "Blasts scalding steam that splashes and slows every enemy caught in the cloud."],
		["frost+tesla", "Cryo Coil", 0x9af0ff, "Chain lightning that slows every enemy it jumps to. Locks down whole lines."],
		["plasma+tesla", "Ion Storm", 0xffd36e, "Explosive shells whose blast also throws lightning outward. The best crowd clearer."],
		["anvil+arcane", "Runehammer", 0xff8fa0, "Fires runic bolts that hit stopped enemies 50% harder. Pairs with blocking heroes and stuns."],
		["anvil+beacon", "War Drum", 0xffb07a, "Pounds enemies with heavy shots that hit stopped enemies 50% harder, and buffs nearby towers like a Beacon."],
		["anvil+frost", "Glacier Maul", 0xbfe8d8, "Slowing shots that hit stopped enemies 50% harder. Its own freezes set up its biggest hits."],
		["anvil+laser", "Forge Beam", 0xff8a5a, "Searing shots that heat up on one target and hit stopped enemies 50% harder."],
		["anvil+mortar", "Quake Cannon", 0xf2c27a, "Heavy long-range blasts that hurt groups and hit stopped enemies 50% harder."],
		["anvil+plasma", "Magma Hammer", 0xf08a4a, "Exploding shells that hit stopped enemies 50% harder."],
		["anvil+tesla", "Thunder Anvil", 0x9ad0ff, "Chain lightning that hits stopped enemies 50% harder."],
		["arcane+beacon", "Spellbanner", 0xff7fd0, "Fires fast magic bolts and buffs nearby towers like a Beacon."],
		["arcane+laser", "Prism Lance", 0xff6fa0, "Rapid bolts that heat up and hit harder the longer they stay on one enemy."],
		["arcane+mortar", "Starfall Battery", 0xffb0e0, "Long-range bolts that burst on impact and hurt everything nearby."],
		["beacon+frost", "Aurora Spire", 0xc0f0f0, "Slowing shots, and it buffs nearby towers like a Beacon."],
		["beacon+laser", "Sunlance Beacon", 0xff9fa8, "Shots that heat up on one target, and it buffs nearby towers like a Beacon."],
		["beacon+mortar", "Signal Battery", 0xfcd8c0, "Long-range explosive shots, and it buffs nearby towers like a Beacon."],
		["beacon+plasma", "Flare Beacon", 0x9fe8d0, "Exploding shells, and it buffs nearby towers like a Beacon."],
		["beacon+tesla", "Storm Banner", 0xa8e0ff, "Chain lightning, and it buffs nearby towers like a Beacon."],
		["frost+laser", "Cryo Lance", 0xd0c8f0, "Chilling shots that slow their target and heat up the longer they stay on it."],
		["frost+mortar", "Avalanche Mortar", 0xe0f0e8, "Long-range blasts that slow every enemy caught in them."],
		["laser+mortar", "Solar Battery", 0xffc090, "Long-range blasts that grow stronger with each hit on the same target."],
		["laser+plasma", "Fusion Torch", 0x7fe0c0, "Exploding shots that heat up the longer they hit the same enemy."],
		["laser+tesla", "Arc Lance", 0xb0a8ff, "Chain lightning that heats up on its main target."],
		["mortar+plasma", "Bombard", 0xd8f0b0, "Long-range shells with huge explosions. Wrecks crowds."],
		["mortar+tesla", "Thunder Battery", 0xd8e8ff, "Long-range blasts that throw chain lightning outward."],
		["arcane+frost+plasma+tesla", "Rift Singularity", 0xffffff, "Holds the power of all four towers: fast bolts, explosions, deep slows and chain lightning in every shot."],
		["arcane+frost+plasma", "Prism Reactor", 0xffa8f0, "Rapid exploding ice bolts that shred and slow whole groups."],
		["arcane+frost+tesla", "Aurora Lance", 0xa8e8ff, "Piercing frozen lightning that slows everything it jumps through."],
		["arcane+plasma+tesla", "Nova Battery", 0xffe08a, "Heavy bolts that explode and throw lightning across the field."],
		["frost+plasma+tesla", "Tempest Engine", 0xc8f5ff, "A storm of scalding, freezing, crackling blasts. Nothing in range moves fast."],
	]:
		var r := RecipeData.new()
		r.key = x[0]; r.name = x[1]; r.color = col(x[2]); r.desc = x[3]
		if boons.has(r.key):
			r.boon_name = boons[r.key][0]; r.boon_desc = boons[r.key][1]; r.boon_effect = boons[r.key][2]
		arr.append(r)
	l.items = arr
	return l


# ---------------- wizard ----------------
func elements() -> ElementList:
	var l := ElementList.new()
	var arr: Array[ElementData] = []
	for x in [["fire", "Fire", 0xff7a3d, 0, ""], ["water", "Water", 0x5fc8ff, 0, ""], ["earth", "Earth", 0xc8a26a, 0, ""], ["air", "Air", 0xd8f4ee, 0, ""],
		["storm", "Lightning", 0x9cf4dd, 400, "Chains between enemies and stuns them."], ["nature", "Nature", 0x7ee06a, 400, "Roots enemies in place and poisons them."],
		["void", "Void", 0xb07cff, 600, "Drags enemies back and makes them take more damage."], ["light", "Light", 0xf9e6a2, 600, "Piercing beams and heavy single hits, and some spells heal you."]]:
		var e := ElementData.new()
		e.id = x[0]; e.name = x[1]; e.color = col(x[2]); e.cost = x[3]; e.blurb = x[4]
		arr.append(e)
	l.items = arr
	return l


func S(d: Dictionary) -> SpellData:
	var s := SpellData.new()
	for k in d:
		var v = d[k]
		if k in ["color", "burn_color", "wall_color", "art_tint"]:
			v = col(v)
		elif k in ["art_fly_frames", "art_hit_frames"]:
			v = PackedInt32Array(v)
		elif k == "art_loop":
			v = Vector2i(v[0], v[1])
		s.set(k, v)
	return s


func spells() -> SpellList:
	var l := SpellList.new()
	var arr: Array[SpellData] = []
	var list := [
		{ runes = "fire", name = "Fireball", mana = 18.0, delivery = "launch", r = 55.0, dmg = 55.0, burn_time = 3.0, burn_dps = 14.0, color = 0xff7a3d, size = 4.0, ring_time = 0.4, boom = true,
			desc = "A fireball bursts for {f0(sp.dmg * p)} damage within {f0(sp.r * h.spell_r)} and leaves the ground burning for {f0(sp.burn_time)}s ({f0(sp.burn_dps * p)}/s).",
			art = "fireball", art_mode = "fly", art_fly_frames = [0, 1, 2, 3], art_hit_frames = [4, 5, 6, 7], art_r = 60.0, art_fps = 10.0 },
		{ runes = "water", name = "Frost Burst", mana = 22.0, r = 70.0, dmg = 15.0, freeze = 1.6, color = 0x9fe6ff, ring_time = 0.5,
			desc = "Freezes enemies within {f0(sp.r * h.spell_r)} solid for {f1(sp.freeze + h.freeze_bonus)}s and deals {f0(sp.dmg * p)} damage.",
			art = "frostburst", art_r = 70.0 },
		{ runes = "earth", name = "Stone Wall", mana = 28.0, delivery = "wall", wall_hp = 250.0, wall_hp_per_wave = 30.0, wall_time = 6.0,
			desc = "Raises a wall on the path nearest the cursor. It blocks enemies for {f0(sp.wall_time)}s or until its {f0((sp.wall_hp + sp.wall_hp_per_wave * wave) * h.wall_bonus)} HP runs out." },
		{ runes = "air", name = "Gust", mana = 18.0, r = 80.0, dmg = 10.0, push = 1.0, push_speed = 90.0, color = 0xd8f4ee, ring_time = 0.45, ring_fill = false,
			desc = "Blows enemies within {f0(sp.r * h.spell_r)} back along the path for {f1(sp.push * h.push_bonus)}s and deals {f0(sp.dmg * p)} damage.",
			art = "gust", art_r = 80.0, art_turn = true },
		{ runes = "fire+fire", name = "Greater Fireball", mana = 32.0, delivery = "launch", r = 85.0, dmg = 140.0, burn_time = 4.0, burn_dps = 25.0, color = 0xff5a2a, size = 7.0, ring_time = 0.5, shake = 0.008, boom = true,
			desc = "A huge fireball bursts for {f0(sp.dmg * p)} damage within {f0(sp.r * h.spell_r)} and leaves the ground burning for {f0(sp.burn_time)}s ({f0(sp.burn_dps * p)}/s).",
			art = "gfireball", art_mode = "fly", art_fly_frames = [0, 1, 2], art_hit_frames = [3, 4, 5, 6, 7], art_r = 90.0, art_fps = 11.0 },
		{ runes = "water+water", name = "Deep Freeze", mana = 40.0, r = 100.0, dmg = 30.0, freeze = 3.0, expose = 0.2, expose_time = 4.0, color = 0xdff6ff, ring_time = 0.7,
			desc = "Freezes enemies within {f0(sp.r * h.spell_r)} for {f1(sp.freeze + h.freeze_bonus)}s, deals {f0(sp.dmg * p)} damage, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s.",
			art = "deepfreeze", art_r = 100.0, art_dur = 3.0, art_loop = [5, 7] },
		{ runes = "earth+earth", name = "Great Wall", mana = 50.0, delivery = "wall", wall_hp = 650.0, wall_hp_per_wave = 60.0, wall_time = 9.0, wall_slam = 40.0,
			desc = "Raises a thick wall ({f0((sp.wall_hp + sp.wall_hp_per_wave * wave) * h.wall_bonus)} HP) for {f0(sp.wall_time)}s that slams nearby enemies for {f0(sp.wall_slam * p)} and stuns them 1s." },
		{ runes = "air+air", name = "Cyclone", mana = 32.0, r = 110.0, dmg = 25.0, push = 1.8, push_speed = 110.0, zone_time = 0.8, zone_vortex = true, color = 0xd8f4ee, ring_time = 0.0,
			desc = "Hurls enemies within {f0(sp.r * h.spell_r)} back for {f1(sp.push * h.push_bonus)}s and deals {f0(sp.dmg * p)} damage.",
			art = "cyclone", art_r = 110.0, art_dur = 1.1, art_loop = [3, 5] },
		{ runes = "fire+water", name = "Scalding Torrent", mana = 40.0, r = 85.0, dmg = 60.0, push = 0.7, push_speed = 100.0, expose = 0.25, expose_time = 5.0, color = 0xffb08a, ring_time = 0.5,
			desc = "A boiling wave pushes enemies within {f0(sp.r * h.spell_r)} back, deals {f0(sp.dmg * p)} damage, and they take {pct(sp.expose)} more damage from everything for {f0(sp.expose_time)}s.",
			art = "torrent", art_mode = "beam" },
		{ runes = "fire+earth", name = "Meteor", mana = 45.0, delivery = "delayed", delay = 0.7, r = 90.0, dmg = 170.0, stun = 1.2, stun_boss = 0.4, burn_time = 4.0, burn_dps = 20.0, color = 0xff7a3d, ring_time = 0.6, shake = 0.014, boom = true,
			desc = "After {f1(sp.delay)}s a meteor strikes for {f0(sp.dmg * p)} within {f0(sp.r * h.spell_r)}, stuns for {f1(sp.stun)}s, and leaves molten ground for {f0(sp.burn_time)}s ({f0(sp.burn_dps * p)}/s).",
			art = "meteor", art_mode = "meteor", art_r = 90.0 },
		{ runes = "fire+air", name = "Firestorm", mana = 40.0, delivery = "zone", r = 80.0, zone_time = 4.0, zone_dps = 40.0, zone_slow = 0.3, zone_vortex = true, color = 0xff7a3d,
			desc = "A whirling firestorm burns enemies within {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s ({f0(sp.zone_dps * p)}/s) and slows them {pct(sp.zone_slow)}.",
			art = "firestorm", art_r = 80.0, art_dur = 4.0, art_loop = [3, 5] },
		{ runes = "water+earth", name = "Quagmire", mana = 38.0, delivery = "zone", r = 95.0, zone_time = 6.0, zone_dps = 8.0, zone_slow = 0.65, color = 0x7a6a4a,
			desc = "Turns the ground within {f0(sp.r * h.spell_r)} to deep mud for {f0(sp.zone_time)}s: enemies are slowed {pct(sp.zone_slow)} and take {f0(sp.zone_dps * p)}/s.",
			art = "quagmire", art_r = 95.0, art_dur = 6.0, art_loop = [3, 6], art_low = true },
		{ runes = "water+air", name = "Blizzard", mana = 42.0, delivery = "zone", r = 100.0, zone_time = 5.0, zone_dps = 22.0, zone_slow = 0.45, zone_end_freeze = 1.2, color = 0xbfeaff,
			desc = "A blizzard rages within {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s ({f0(sp.zone_dps * p)}/s, {pct(sp.zone_slow)} slow), then freezes everything still inside for {f1(sp.zone_end_freeze + h.freeze_bonus)}s.",
			art = "blizzard", art_r = 100.0, art_dur = 5.0, art_loop = [2, 5] },
		{ runes = "earth+air", name = "Sandstorm", mana = 38.0, r = 90.0, push = 0.6, push_speed = 90.0, zone_time = 5.0, zone_dps = 16.0, zone_break = 0.2, color = 0xd8b878, ring_time = 0.0,
			desc = "A sandstorm within {f0(sp.r * h.spell_r)} blows enemies back for {f1(sp.push)}s, then for {f0(sp.zone_time)}s scours them ({f0(sp.zone_dps * p)}/s) and strips {pct(sp.zone_break)} armor.",
			art = "sandstorm", art_r = 90.0, art_dur = 5.0, art_loop = [2, 5] },
		{ runes = "fire+fire+fire", name = "Inferno", mana = 70.0, delivery = "launch", r = 140.0, dmg = 260.0, burn_time = 5.0, burn_dps = 45.0, burn_r = 0.85, burn_color = 0xff3d1a, color = 0xff3d1a, size = 10.0, ring_time = 0.8, shake = 0.02, boom = true,
			desc = "Engulfs everything within {f0(sp.r * h.spell_r)} for {f0(sp.dmg * p)} damage and sets the ground ablaze for {f0(sp.burn_time)}s ({f0(sp.burn_dps * p)}/s).",
			art = "inferno", art_mode = "fly", art_fly = "gfireball", art_r = 140.0, art_dur = 5.0, art_loop = [3, 5] },
		{ runes = "water+water+water", name = "Absolute Zero", mana = 70.0, delivery = "map", r = 400.0, dmg = 40.0, freeze = 2.5, expose = 0.3, expose_time = 5.0, color = 0xdff6ff, ring_time = 0.9, shake = 0.01,
			desc = "Freezes every enemy on the map for {f1(sp.freeze + h.freeze_bonus)}s, deals {f0(sp.dmg * p)} damage, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s.",
			art = "abszero", art_r = 170.0, art_fps = 10.0 },
		{ runes = "earth+earth+earth", name = "Earthquake", mana = 70.0, r = 220.0, dmg = 150.0, stun = 2.0, stun_boss = 0.6, color = 0xc8a26a, ring_time = 0.8, shake = 0.025, boom = true,
			desc = "Shakes the ground within {f0(sp.r * h.spell_r)}: {f0(sp.dmg * p)} damage and a {f0(sp.stun)}s stun.",
			art = "quake", art_r = 220.0, art_low = true },
		{ runes = "air+air+air", name = "Tempest", mana = 70.0, r = 200.0, dmg = 60.0, push = 2.5, push_speed = 140.0, zone_time = 1.2, zone_vortex = true, color = 0xd8f4ee, ring_time = 0.0,
			desc = "A tempest within {f0(sp.r * h.spell_r)} hurls enemies back for {f1(sp.push * h.push_bonus)}s and deals {f0(sp.dmg * p)} damage.",
			art = "tempest", art_r = 200.0, art_dur = 1.4, art_loop = [3, 5] },
		{ runes = "storm", name = "Spark Bolt", mana = 20.0, delivery = "chain", jumps = 3, dmg = 50.0, color = 0x9cf4dd,
			desc = "Lightning hits the enemy nearest the cursor for {f0(sp.dmg * p)} and jumps to {sp.jumps} more." },
		{ runes = "storm+storm", name = "Chain Lightning", mana = 36.0, delivery = "chain", jumps = 6, dmg = 110.0, root = 0.5, color = 0x9cf4dd,
			desc = "Lightning jumps through {sp.jumps + 1} enemies for {f0(sp.dmg * p)} each and stuns them {f1(sp.root)}s." },
		{ runes = "storm+storm+storm", name = "Thunderstorm", mana = 70.0, delivery = "strikes", r = 180.0, count = 20, gap = 0.25, dmg = 90.0, root = 0.3, color = 0x9cf4dd, ring_time = 5.0, ring_fill = false, shake = 0.008,
			desc = "For {f0(sp.count * sp.gap)}s, lightning strikes enemies within {f0(sp.r * h.spell_r)} every {f2(sp.gap)}s for {f0(sp.dmg * p)}, stunning them {f1(sp.root)}s.",
			art = "tempest", art_r = 180.0, art_dur = 5.0, art_loop = [3, 5] },
		{ runes = "nature", name = "Thorn Snare", mana = 20.0, r = 60.0, dmg = 10.0, root = 1.5, poison_dps = 14.0, poison_time = 4.0, color = 0x7ee06a, ring_time = 0.5,
			desc = "Vines root enemies within {f0(sp.r * h.spell_r)} for {f1(sp.root)}s and poison them ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s)." },
		{ runes = "nature+nature", name = "Bramble Field", mana = 36.0, delivery = "zone", r = 90.0, zone_time = 6.0, zone_dps = 22.0, zone_slow = 0.5, color = 0x5fb84a,
			desc = "Thick brambles cover {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s: enemies are slowed {pct(sp.zone_slow)} and take {f0(sp.zone_dps * p)}/s." },
		{ runes = "nature+nature+nature", name = "Wild Growth", mana = 70.0, r = 180.0, dmg = 30.0, root = 3.0, poison_dps = 40.0, poison_time = 6.0, heal = 0.4, color = 0x7ee06a, ring_time = 0.9, shake = 0.01,
			desc = "Roots every enemy within {f0(sp.r * h.spell_r)} for {f0(sp.root)}s, poisons them ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s), and heals you {pct(sp.heal)}." },
		{ runes = "void", name = "Void Bolt", mana = 18.0, delivery = "launch", r = 55.0, dmg = 45.0, expose = 0.2, expose_time = 4.0, color = 0xb07cff, size = 4.0, ring_time = 0.4,
			desc = "Hits enemies within {f0(sp.r * h.spell_r)} for {f0(sp.dmg * p)}, and they take {pct(sp.expose)} more damage from everything for {f0(sp.expose_time)}s." },
		{ runes = "void+void", name = "Singularity", mana = 42.0, delivery = "zone", r = 90.0, zone_time = 3.0, zone_dps = 30.0, zone_slow = 0.6, zone_vortex = true, implode_dmg = 120.0, color = 0x6a3cb0,
			desc = "A black hole within {f0(sp.r * h.spell_r)} slows enemies {pct(sp.zone_slow)} for {f0(sp.zone_time)}s ({f0(sp.zone_dps * p)}/s), then implodes for {f0(sp.implode_dmg * p)}.",
			art = "runeB", art_r = 90.0, art_dur = 3.0, art_loop = [2, 5], art_low = true },
		{ runes = "void+void+void", name = "Event Horizon", mana = 70.0, r = 200.0, dmg = 100.0, push = 2.0, push_speed = 130.0, expose = 0.35, expose_time = 6.0, color = 0xb07cff, ring_time = 0.9, ring_shrink = true, shake = 0.015,
			desc = "Drags every enemy within {f0(sp.r * h.spell_r)} back for {f1(sp.push * h.push_bonus)}s, deals {f0(sp.dmg * p)}, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s.",
			art = "runeB", art_r = 200.0, art_low = true, art_fps = 11.0 },
		{ runes = "light", name = "Radiant Lance", mana = 22.0, delivery = "line", length = 420.0, width = 14.0, dmg = 70.0, color = 0xf9e6a2,
			desc = "A beam of light pierces every enemy in a line for {f0(sp.dmg * p)}." },
		{ runes = "light+light", name = "Solar Flare", mana = 40.0, r = 80.0, dmg = 130.0, root = 1.0, heal = 0.15, pillar = true, color = 0xfff6c8, ring_time = 0.5,
			desc = "Blinds enemies within {f0(sp.r * h.spell_r)} ({f0(sp.root)}s stun) for {f0(sp.dmg * p)} damage and heals you {pct(sp.heal)}.",
			art = "runeA", art_r = 80.0, art_low = true, art_fps = 11.0 },
		{ runes = "light+light+light", name = "Judgment", mana = 70.0, delivery = "toughest", count = 5, gap = 0.12, dmg = 320.0, color = 0xf9e6a2, shake = 0.008,
			desc = "Pillars of light strike the {sp.count} toughest enemies on the map for {f0(sp.dmg * p)} each." },
		{ runes = "fire+storm", name = "Plasma Storm", mana = 42.0, r = 80.0, dmg = 90.0, root = 0.4, poison_dps = 20.0, poison_time = 3.0, fx_strikes = 4, fx_strike_gap = 0.08, color = 0xffb35c, ring_time = 0.5,
			desc = "Superheated lightning hits enemies within {f0(sp.r * h.spell_r)} for {f0(sp.dmg * p)}, stuns them {f1(sp.root)}s and sets them burning ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s).",
			art = "firestorm", art_r = 95.0, art_dur = 5.0, art_loop = [3, 5] },
		{ runes = "water+storm", name = "Conductive Surge", mana = 40.0, r = 90.0, dmg = 70.0, root = 1.2, fx_strikes = 5, fx_strike_gap = 0.06, color = 0x5fc8ff, ring_time = 0.5,
			desc = "Soaks enemies within {f0(sp.r * h.spell_r)} and electrifies them: {f0(sp.dmg * p)} damage and a {f1(sp.root)}s stun." },
		{ runes = "earth+storm", name = "Magnet Quake", mana = 40.0, r = 90.0, dmg = 80.0, root = 0.6, armor_break = 0.3, armor_break_time = 5.0, color = 0xc8a26a, ring_time = 0.6, shake = 0.008,
			desc = "Hits enemies within {f0(sp.r * h.spell_r)} for {f0(sp.dmg * p)}, stuns them {f1(sp.root)}s and strips {pct(sp.armor_break)} armor for {f0(sp.armor_break_time)}s.",
			art = "quake", art_r = 90.0, art_low = true, art_tint = 0xbff6ff },
		{ runes = "air+storm", name = "Thunderhead", mana = 44.0, delivery = "strikes", r = 100.0, count = 10, gap = 0.4, dmg = 55.0, push = 0.4, push_speed = 80.0, color = 0xd8f4ee, ring_time = 4.0, ring_fill = false,
			desc = "A storm cloud hangs over {f0(sp.r * h.spell_r)} for {f0(sp.count * sp.gap)}s, striking an enemy every {f1(sp.gap)}s for {f0(sp.dmg * p)} and blowing it back.",
			art = "tempest", art_r = 100.0, art_dur = 4.0, art_loop = [3, 5] },
		{ runes = "fire+nature", name = "Wildfire", mana = 40.0, delivery = "zone", r = 95.0, zone_time = 5.0, zone_dps = 32.0, zone_slow = 0.2, color = 0xff9a3d,
			desc = "Sets {f0(sp.r * h.spell_r)} ablaze for {f0(sp.zone_time)}s: {f0(sp.zone_dps * p)}/s and {pct(sp.zone_slow)} slow." },
		{ runes = "water+nature", name = "Overgrowth", mana = 38.0, r = 85.0, dmg = 20.0, root = 2.0, poison_dps = 16.0, poison_time = 5.0, color = 0x47d9c5, ring_time = 0.6,
			desc = "Roots enemies within {f0(sp.r * h.spell_r)} for {f0(sp.root)}s and poisons them ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s)." },
		{ runes = "earth+nature", name = "Thornwall", mana = 46.0, delivery = "wall", wall_hp = 420.0, wall_hp_per_wave = 45.0, wall_time = 7.0, wall_thorns = 30.0, wall_color = 0x5fb84a,
			desc = "Raises a thorny wall ({f0((sp.wall_hp + sp.wall_hp_per_wave * wave) * h.wall_bonus)} HP) for {f0(sp.wall_time)}s. Enemies next to it take {f0(sp.wall_thorns * p)}/s." },
		{ runes = "air+nature", name = "Pollen Cloud", mana = 36.0, delivery = "zone", r = 90.0, zone_time = 6.0, zone_dps = 18.0, zone_slow = 0.35, zone_break = 0.15, color = 0xd8e88a,
			desc = "A choking cloud over {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s: {pct(sp.zone_slow)} slow, {f0(sp.zone_dps * p)}/s, and strips {pct(sp.zone_break)} armor." },
		{ runes = "storm+nature", name = "Living Lightning", mana = 40.0, delivery = "chain", jumps = 7, dmg = 60.0, poison_dps = 12.0, poison_time = 4.0, color = 0x7ee06a,
			desc = "Lightning jumps through {sp.jumps + 1} enemies for {f0(sp.dmg * p)} each and poisons them ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s)." },
		{ runes = "fire+void", name = "Hellfire", mana = 44.0, delivery = "launch", r = 80.0, dmg = 120.0, burn_time = 6.0, burn_dps = 25.0, burn_color = 0x8a3cff, color = 0x8a3cff, size = 6.0, ring_time = 0.5, boom = true,
			desc = "Black flames hit enemies within {f0(sp.r * h.spell_r)} for {f0(sp.dmg * p)} and burn the ground for {f0(sp.burn_time)}s ({f0(sp.burn_dps * p)}/s).",
			art = "inferno", art_mode = "fly", art_fly = "gfireball", art_r = 80.0, art_dur = 6.0, art_loop = [3, 5], art_tint = 0xc9a0ff },
		{ runes = "water+void", name = "Abyssal Tide", mana = 40.0, r = 90.0, dmg = 50.0, push = 1.2, push_speed = 100.0, expose = 0.25, expose_time = 5.0, color = 0x4a5ad0, ring_time = 0.6,
			desc = "A dark wave pushes enemies within {f0(sp.r * h.spell_r)} back for {f1(sp.push * h.push_bonus)}s, deals {f0(sp.dmg * p)}, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s." },
		{ runes = "earth+void", name = "Gravity Well", mana = 42.0, delivery = "zone", r = 90.0, zone_time = 4.0, zone_dps = 15.0, zone_slow = 0.7, zone_vortex = true, zone_end_freeze = 1.0, color = 0x6a4ab0,
			desc = "Crushing gravity within {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s: {pct(sp.zone_slow)} slow and {f0(sp.zone_dps * p)}/s, then everything inside is pinned for {f1(sp.zone_end_freeze + h.freeze_bonus)}s." },
		{ runes = "air+void", name = "Vacuum", mana = 38.0, r = 100.0, dmg = 40.0, push = 1.5, push_speed = 110.0, expose = 0.15, expose_time = 4.0, color = 0xb07cff, ring_time = 0.6, ring_fill = false, ring_shrink = true,
			desc = "Sucks enemies within {f0(sp.r * h.spell_r)} back for {f1(sp.push * h.push_bonus)}s, deals {f0(sp.dmg * p)}, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s." },
		{ runes = "storm+void", name = "Dark Lightning", mana = 42.0, delivery = "chain", jumps = 5, dmg = 80.0, expose = 0.2, expose_time = 5.0, color = 0x8a3cff,
			desc = "Black lightning jumps through {sp.jumps + 1} enemies for {f0(sp.dmg * p)} each, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s." },
		{ runes = "nature+void", name = "Blight", mana = 38.0, delivery = "zone", r = 90.0, zone_time = 6.0, zone_dps = 25.0, zone_slow = 0.2, zone_break = 0.25, color = 0x6a8a3a,
			desc = "Rots the ground within {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s: {f0(sp.zone_dps * p)}/s, {pct(sp.zone_slow)} slow, and strips {pct(sp.zone_break)} armor." },
		{ runes = "fire+light", name = "Sunfire", mana = 42.0, delivery = "line", length = 460.0, width = 18.0, dmg = 120.0, poison_dps = 25.0, poison_time = 3.0, color = 0xffb35c,
			desc = "A blazing beam pierces every enemy in a line for {f0(sp.dmg * p)} and sets them burning ({f0(sp.poison_dps * p)}/s for {f0(sp.poison_time)}s)." },
		{ runes = "water+light", name = "Prism Rain", mana = 40.0, r = 100.0, dmg = 60.0, freeze = 1.0, heal = 0.1, color = 0xc8f0ff, ring_time = 0.6,
			desc = "Glittering rain over {f0(sp.r * h.spell_r)} deals {f0(sp.dmg * p)}, freezes enemies {f1(sp.freeze + h.freeze_bonus)}s, and heals you {pct(sp.heal)}." },
		{ runes = "earth+light", name = "Crystal Spire", mana = 44.0, delivery = "wall", wall_hp = 380.0, wall_hp_per_wave = 40.0, wall_time = 7.0, wall_slam = 80.0, wall_color = 0xf9e6a2,
			desc = "Raises a crystal wall ({f0((sp.wall_hp + sp.wall_hp_per_wave * wave) * h.wall_bonus)} HP) for {f0(sp.wall_time)}s that blasts nearby enemies for {f0(sp.wall_slam * p)} and stuns them 0.8s." },
		{ runes = "air+light", name = "Halo Wind", mana = 38.0, r = 100.0, dmg = 50.0, push = 1.0, push_speed = 90.0, root = 0.6, color = 0xfff6c8, ring_time = 0.5,
			desc = "A ring of light blows enemies within {f0(sp.r * h.spell_r)} back for {f1(sp.push * h.push_bonus)}s, deals {f0(sp.dmg * p)}, and blinds them {f1(sp.root)}s." },
		{ runes = "storm+light", name = "Divine Bolt", mana = 44.0, delivery = "divine", r = 120.0, dmg = 260.0, jumps = 3, color = 0xf9e6a2,
			desc = "A bolt from the heavens hits the toughest enemy near the cursor for {f0(sp.dmg * p)}, then jumps to {sp.jumps} more for half." },
		{ runes = "nature+light", name = "Bloom", mana = 40.0, delivery = "zone", r = 90.0, zone_time = 5.0, zone_dps = 20.0, zone_slow = 0.3, heal = 0.3, color = 0xf79bbe,
			desc = "Heals you {pct(sp.heal)} and blossoms over {f0(sp.r * h.spell_r)} for {f0(sp.zone_time)}s: {pct(sp.zone_slow)} slow and {f0(sp.zone_dps * p)}/s." },
		{ runes = "void+light", name = "Eclipse", mana = 46.0, r = 110.0, dmg = 150.0, root = 0.5, expose = 0.3, expose_time = 5.0, color = 0x101223, ring_time = 0.7, shake = 0.012,
			desc = "Darkness and light collide within {f0(sp.r * h.spell_r)}: {f0(sp.dmg * p)} damage, a {f1(sp.root)}s stun, and they take {pct(sp.expose)} more damage for {f0(sp.expose_time)}s.",
			art = "runeA", art_r = 110.0, art_low = true, art_tint = 0xd8c8ff },
	]
	for d in list:
		arr.append(S(d))
	l.items = arr
	return l
