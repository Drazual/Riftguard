## The menu screens: main menu, map and hero select, the Heroes and Towers upgrade pages, music, the stats
## log and settings, plus the first-time tips.
class_name Menus
extends RefCounted

const FIRST_TIPS := {
	menu = ["Welcome to Riftguard", "Enemies pour out of the rift and walk to your base. Stop them with towers and a hero you control.\n\nEvery run earns [b]Rift Shards[/b], even a lost one. Spend them on the [b]Heroes[/b] and [b]Towers[/b] pages to get stronger for the next run. Press [b]Play[/b] to start."],
	maps = ["Choose a map", "Start with the first map. Beating a map unlocks the next one. Harder maps have more waves and pay more shards."],
	hero = ["Choose your hero", "Your hero walks the map, fights, and builds towers for you. Tanks block enemies, offensive heroes deal damage, support heroes boost your towers.\n\nEach hero has two abilities. Pick the one you want at the top before you go on."],
	loadout = ["Choose your towers", "Pick the towers you can build this run. Each one gets a number key (1, 2, 3...) as a shortcut. You can’t change them once the run starts."],
	heroes = ["Heroes page", "Every hero is open from the start. Spend Rift Shards on permanent upgrades for each one. Boss Cores, dropped by bosses, buy the big special upgrades.\n\nRefund buttons give your shards back if you want to try a different build."],
	towers = ["Towers page", "Every tower is open from the start. Buy upgrades that make them stronger in every run. The tabs along the side switch towers. Below the upgrades you can see every form and merge you’ve discovered."],
	music = ["Music", "Pick the song that plays on the menus and in runs, build a playlist to play in order or shuffle, or loop one song. Beating maps unlocks more songs."],
	log = ["Stats log", "Your recent runs: how far you got, what you lost and which towers did the most damage. Copy the full log to share it."],
	run = ["Your first run", "[b]Build:[/b] pick a tower in the bar below (or press its number) and click a free tile. Your hero walks over to build it.\n\n[b]Move:[/b] right-click the map to send your hero somewhere. [b]Q[/b] uses its ability.\n\n[b]Upgrade:[/b] click a tower to level it up. Each level adds a point to one of its paths, and each path’s price only rises with its own points.\n\nPress [b]Space[/b] to start a wave, [b]P[/b] to pause, and [b]Esc[/b] to back out of anything."],
	waves = ["Hard and Challenge waves", "From now on you pick how hard each wave is.\n\n[b]Hard[/b] makes the enemies tougher (more HP, armor, speed and so on) for a little extra gold.\n\n[b]Challenge[/b] makes them tougher, adds a handicap, and sets a goal like “lose no base HP”. Meet the goal to earn the reward. The goal stays at the top of the screen while the wave runs."],
	merge = ["Merging towers", "You have two maxed towers that can merge. Merging [b]uses up both towers and gives you one[/b] much stronger hybrid where the second one stood.\n\nEvery tower type can merge with every other, so there are dozens of hybrids, and two maxed hybrids can merge again into a super tower for 20,000 gold, which unleashes a signature power from each tower inside it every few seconds. The paths each tower took decide what its hybrid can learn, so the same pair can turn out differently every run.\n\nSelect a maxed tower and press [b]Merge[/b], then click the other one."],
}

var ui: Ui
var game: Game
var sb_open := { main = true, pick = false, more = false }
var music_screen: Control = null


func _init(u: Ui) -> void:
	ui = u
	game = u.game


func shards_tag() -> String:
	return Kit.c("◆ %d Rift Shards" % int(Save.meta.shards), Kit.TECH) + "   " + Kit.c("⬢ %d Boss Cores" % int(Save.meta.get("cores", 0)), Kit.GOLD)


## A screen title row: heading, shards, then buttons (the last is Back).
func head(box: VBoxContainer, title: String, back: Callable, extra: Array = [], shards := true) -> void:
	var h := Kit.hbox(12)
	var t := Kit.head(title, 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if shards:
		var s := Kit.rich(shards_tag(), 15)
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		s.size_flags_horizontal = Control.SIZE_SHRINK_END
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(s)
	for b in extra:
		h.add_child(b)
	h.add_child(Kit.button("BACK", back))
	box.add_child(h)


func lead(box: VBoxContainer, bb: String) -> void:
	box.add_child(Kit.rich(bb, 16, Kit.MUTED))


## First-time help: each page explains itself the first time you open it. Returns true if it showed.
func first_tip(id: String, after := Callable()) -> bool:
	if Save.meta.tips.get(id, false) or not FIRST_TIPS.has(id) or ui.modal_open():
		return false
	Save.meta.tips[id] = true
	Save.save_meta()
	var in_run := ui.in_run()
	if in_run:
		game.S.paused = true
	var done := func():
		ui.close_modal()
		if in_run:
			game.S.paused = game.S.user_pause
		if after.is_valid():
			after.call()
	var box := ui.open_modal(560, done)
	box.add_child(Kit.head(FIRST_TIPS[id][0], 24))
	box.add_child(Kit.rich(FIRST_TIPS[id][1], 15, Kit.MUTED))
	var row := Kit.hbox()
	row.add_child(Kit.go("GOT IT", done))
	box.add_child(row)
	return true


func queue_tip(id: String) -> void:
	first_tip.call_deferred(id)


# ---------- main menu ----------
func show_menu() -> void:
	game.S = null
	ui.close_modal()
	var box := ui.show_screen()
	Sound.start()
	var c := Kit.vbox(14)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.custom_minimum_size = Vector2(0, ui.get_viewport_rect().size.y - 90)
	box.add_child(c)
	var title := Kit.rich("[center]" + Kit.c("RIFT", Kit.TECH) + Kit.c("GUARD", Kit.ARCANE) + "[/center]", 96)
	title.add_theme_font_override("normal_font", Kit.display_bold)
	title.add_theme_constant_override("outline_size", 0)
	c.add_child(title)
	c.add_child(Kit.rich("[center]Hold the rift. Earn Rift Shards every run to make your heroes and towers stronger.[/center]", 17, Kit.MUTED))
	c.add_child(Kit.rich("[center]" + shards_tag() + "[/center]", 16))
	var col := Kit.vbox(8)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.custom_minimum_size = Vector2(260, 0)
	col.add_child(Kit.go("PLAY", show_map_select))
	col.add_child(Kit.button("HEROES", func(): show_heroes()))
	col.add_child(Kit.button("TOWERS", func(): show_towers()))
	col.add_child(Kit.button("MUSIC", show_music))
	col.add_child(Kit.button("SETTINGS", show_settings))
	col.add_child(Kit.button("STATS LOG", show_log))
	col.add_child(Kit.button("QUIT", func(): ui.get_tree().quit()))
	c.add_child(col)
	c.add_child(Kit.rich("[center]Version %s[/center]" % ProjectSettings.get_setting("application/config/version"), 12, Kit.MUTED))
	var upd: Control = Updater.status_control() if Updater.has_method("status_control") else null
	if upd:
		c.add_child(upd)
	var reset := Kit.button("It’s like I’m new", reset_everything, "FlatButton")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.add_theme_color_override("font_color", Kit.MUTED)
	c.add_child(reset)
	queue_tip("menu")


func reset_everything() -> void:
	var box := ui.open_modal(560, ui.close_modal)
	box.add_child(Kit.head("It’s like I’m new", 24))
	box.add_child(Kit.rich("This erases [b]everything[/b]: shards, unlocks, upgrades, discoveries, stats and settings. The game restarts as if you had never played.", 15, Kit.MUTED))
	var row := Kit.hbox()
	var go := Kit.button("ERASE EVERYTHING", func():
		Save.reset_everything()
		Sound.apply()
		show_menu())
	go.add_theme_color_override("font_color", Kit.DANGER)
	row.add_child(go)
	row.add_child(Kit.go("CANCEL", ui.close_modal))
	box.add_child(row)


func show_map_select() -> void:
	queue_tip("maps")
	var box := ui.show_screen(show_menu)
	head(box, "Choose a map", show_menu)
	lead(box, "Beat a map to unlock the next one. Harder maps have more waves and pay more Rift Shards.")
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for i in DB.map_order.size():
		var k: String = DB.map_order[i]
		var m: MapScene = DB.maps[k].scene
		var open := Save.map_unlocked(k)
		var best = Save.meta.best.get(k)
		var ch := Choice.new()
		ch.custom_minimum_size = Vector2(0, 150)
		ch.add(Kit.c("%s · %d WAVES · ×%s SHARDS" % [m.tier.to_upper(), m.waves, UiText.f1t(m.shard_mult)], Kit.MUTED), 11)
		ch.add(Kit.head(m.map_name, 20, Kit.ARCANE))
		ch.add(DB.tx("map:" + k, m.desc), 14)
		if open:
			ch.add(Kit.c(("Best: wave %d%s" % [best.wave, " (beaten)" if best.won else ""]) if best is Dictionary else "Not played yet", Kit.GOLD), 13)
		else:
			ch.add(Kit.c("Locked: beat %s to unlock" % DB.maps[DB.map_order[i - 1]].scene.map_name, Kit.DANGER), 13)
		ch.disabled = not open
		ch.pressed.connect(new_run.bind(k))
		g.add_child(ch)
	box.add_child(g)


# ---------- a new run: hero and towers ----------
func new_run(map_id: String) -> void:
	game.new_run(map_id)
	ui.top_map.text = DB.maps[map_id].scene.map_name
	show_hero_select()


var _hs := {}


func show_hero_select() -> void:
	var last = Save.meta.get("loadout")
	var hero: String = last.hero if last is Dictionary and DB.heroes.has(last.get("hero", "")) and Progress.hero_open(last.hero) else "vanguard"
	var need := mini(game.R.loadout_size, DB.tower_order.size())
	var picks := []
	if last is Dictionary and last.get("towers") is Array:
		for k in last.towers:
			if DB.towers.has(k) and picks.size() < game.R.loadout_size:
				picks.append(k)
	for k in DB.tower_order:
		if picks.size() < need and not picks.has(k):
			picks.append(k)
	_hs = { hero = hero, picks = picks, need = need, step = "hero" }
	_render_hs()


func _render_hs() -> void:
	var st := _hs
	var y := ui.screen_scroll.scroll_vertical if ui.screen.visible else 0
	queue_tip("hero" if st.step == "hero" else "loadout")
	if st.step == "hero":
		var box := ui.show_screen(func():
			game.S = null
			show_map_select())
		var next := func():
			st.step = "towers"
			_render_hs()
			ui.screen_scroll.scroll_vertical = 0
		head(box, "Choose your hero", func():
			game.S = null
			show_map_select(), [Kit.go("NEXT: TOWERS", next)], false)
		lead(box, "%s · %d waves. Step 1 of 2: pick the hero you’ll play." % [game.S.map.scene.map_name, game.max_wave])
		_ability_row(box, st.hero, _render_hs)
		for cat in UiText.CATEGORIES:
			var list := Array(DB.hero_order).filter(func(k): return DB.heroes[k].category == cat[0])
			if list.is_empty():
				continue
			box.add_child(Kit.h3(cat[1]))
			var g := _grid(3)
			for k in list:
				var d: HeroData = DB.heroes[k]
				if not Progress.hero_open(k):
					g.add_child(_locked_hero_card())
					continue
				var ch := Choice.new(d.color)
				ch.picked = st.hero == k
				var top := Kit.hbox(10)
				var tv := Kit.vbox(4)
				tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				tv.add_child(Kit.label("%s · %s" % [d.role.to_upper(), UiText.hero_mastery_text(k).to_upper()], 11, d.color, Kit.display))
				tv.add_child(Kit.head(d.name, 20, d.color))
				tv.add_child(Kit.rich(DB.tx("hero:" + k, d.desc), 13, Kit.MUTED))
				top.add_child(tv)
				var pic := Portrait.make(k, 1.5)
				pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				top.add_child(pic)
				ch.add(top)
				ch.add("HP %d · %s" % [int(d.hp), ("Mana %d · No auto-attack" % int(d.mana)) if d.mana else ("Damage %s · %s" % [UiText.f0(d.dmg), "Whole-map range" if d.range >= 9999 else "Blocks " + UiText.block_text(d.block).to_lower()])], 13)
				ch.add("Each level: " + DB.tx("role:" + d.category, UiText.ROLE_LEVEL.get(d.category, "")), 12)
				ch.add(Kit.c(("Spells: %d elements, then left-click" % Progress.wiz_loadout().size()) if d.spells else "Ability: " + DB.hero_ability(k).name, Kit.GOLD), 13)
				ch.pressed.connect(func():
					st.hero = k
					_render_hs())
				g.add_child(ch)
			box.add_child(g)
		var row := Kit.hbox()
		row.add_child(Kit.go("NEXT: TOWERS", next))
		box.add_child(row)
		ui.screen_scroll.set_deferred("scroll_vertical", y)
		return
	var box := ui.show_screen(func():
		st.step = "hero"
		_render_hs())
	var start := func():
		if st.picks.is_empty():
			return
		if st.picks.size() >= st.need:
			start_run(st.hero, st.picks)
			return
		# Fewer towers is allowed as a challenge, but confirm so it never happens by accident.
		var m := ui.open_modal(560, ui.close_modal)
		m.add_child(Kit.head("Only %d of %d towers?" % [st.picks.size(), st.need], 24))
		m.add_child(Kit.rich("You picked %d tower%s: %s. You can’t add more once the run starts." % [st.picks.size(), "s" if st.picks.size() > 1 else "", ", ".join(st.picks.map(func(k): return DB.towers[k].name))], 15, Kit.MUTED))
		var r := Kit.hbox()
		r.add_child(Kit.go("START WITH %d" % st.picks.size(), func():
			ui.close_modal()
			start_run(st.hero, st.picks)))
		r.add_child(Kit.button("GO BACK AND PICK MORE", ui.close_modal))
		m.add_child(r)
	var go_top := Kit.go("START RUN", start)
	go_top.disabled = st.picks.is_empty()
	head(box, "Choose your towers · %d/%d" % [st.picks.size(), st.need], func():
		st.step = "hero"
		_render_hs(), [go_top], false)
	var hd: HeroData = DB.heroes[st.hero]
	lead(box, "Step 2 of 2: pick up to %d towers to bring with your %s. Bringing fewer makes the run harder." % [st.need, Kit.b(Kit.c(hd.name, hd.color))])
	var g := _grid(3)
	for k in DB.tower_order:
		var d: TowerData = DB.towers[k]
		var on: bool = st.picks.has(k)
		var ch := Choice.new(d.color)
		ch.picked = on
		var sub: String = ("Key %d" % (st.picks.find(k) + 1)) if on else ("Support" if d.support else "%d gold" % d.cost)
		if Save.tower_meta(k).get("sig", 0):
			sub += " · " + d.signature_name
		ch.add(Kit.c(sub.to_upper(), d.color), 11)
		ch.add(Kit.head(d.name, 19, d.color))
		ch.add(DB.tx("tower:" + k, d.info), 13)
		ch.pressed.connect(func():
			if st.picks.has(k):
				st.picks.erase(k)
			elif st.picks.size() < game.R.loadout_size:
				st.picks.append(k)
			else:
				ui.toast("You can bring %d towers. Remove one first." % game.R.loadout_size)
			_render_hs())
		g.add_child(ch)
	box.add_child(g)
	var row := Kit.hbox(10)
	var go := Kit.go("START RUN", start)
	go.disabled = st.picks.is_empty()
	row.add_child(go)
	if st.picks.size() and st.picks.size() < st.need:
		var warn := Kit.label("Only %d of %d towers picked." % [st.picks.size(), st.need], 13, Kit.GOLD)
		warn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(warn)
	box.add_child(row)
	ui.screen_scroll.set_deferred("scroll_vertical", y)


func _grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


## The picked hero's two abilities (or the Wizard's elements), so you can swap before the run.
func _ability_row(box: VBoxContainer, hero: String, redraw: Callable) -> void:
	var d: HeroData = DB.heroes[hero]
	if d.spells:
		box.add_child(Kit.h3(d.name + " · spells"))
		var c := Kit.card()
		var v := Kit.vbox(8)
		c.add_child(v)
		elements_ui(v, redraw)
		v.add_child(spellbook(Progress.book_hero(), Progress.wiz_loadout(), Array(DB.el_order).filter(Progress.el_open), "pick"))
		box.add_child(c)
		return
	box.add_child(Kit.h3(d.name + " ability · pick one"))
	box.add_child(_ability_picks(hero, redraw))


func _ability_picks(hero: String, redraw: Callable) -> Control:
	var d: HeroData = DB.heroes[hero]
	var g := _grid(2)
	for pair in [["base", d.ability], ["alt", d.alt]]:
		var ab: AbilityData = pair[1]
		if ab == null:
			continue
		var on := DB.hero_ability(hero) == ab
		var ch := Choice.new()
		ch.picked = on
		ch.add(Kit.c(("EQUIPPED" if on else "CLICK TO EQUIP") + " · %ss COOLDOWN" % UiText.f1t(ab.cd), Kit.MUTED), 11)
		ch.add(Kit.head(ab.name, 18, Kit.ARCANE))
		ch.add(UiText.ab_text(Ability.from_data(ab)), 13)
		ch.pressed.connect(func():
			Save.meta.abilities[hero] = pair[0]
			Save.save_meta()
			redraw.call())
		var tip_ab := Ability.from_data(ab)
		Kit.tip_on(ch, func():
			var h := Hero.new()
			h.dmg = d.dmg
			h.ab = tip_ab
			h.data = d
			return UiText.ability_tip(null, h))
		g.add_child(ch)
	return g


func start_run(hero: String, towers: Array) -> void:
	ui.hide_screen()
	game.start_run(hero, towers)
	ui.refresh_run_panels()
	queue_tip("run")


# ---------- the Wizard's elements and spellbook ----------
func elements_ui(v: VBoxContainer, redraw: Callable) -> void:
	var load := Progress.wiz_loadout()
	var n := Progress.SLOT_KEYS.size()
	var ta: int = game.R.triple_at
	v.add_child(Kit.h3("Elements · taking %d of %d" % [load.size(), n]))
	v.add_child(Kit.muted("Click an element to take it or leave it behind; taken elements are bound in order to %s. Each element gains mastery from the mana you spend on spells that use it. At mastery %d it can be readied three times for its ultimate, and it unlocks the element below it." % [" ".join(Progress.SLOT_KEYS).to_upper(), ta]))
	var g := _grid(4)
	# the four starting elements on top, each with the element it unlocks right below it
	var order: Array = Progress.BASE_ELS.duplicate()
	for base in Progress.BASE_ELS:
		var kid := ""
		for el in DB.el_order:
			if DB.elements[el].parent == base:
				kid = el
		order.append(kid)
	for el in DB.el_order:
		if not order.has(el):
			order.append(el)
	for el in order:
		if el == "":
			g.add_child(Control.new())
			continue
		var E: ElementData = DB.elements[el]
		var i := load.find(el)
		var m := Progress.el_mastery(el)
		var ch := Choice.new(E.color if i >= 0 else Kit.LINE)
		ch.pad = 8
		ch.add(Kit.label(E.name, 15, E.color, Kit.display_bold))
		if Progress.el_open(el):
			ch.add(("Key " + Progress.SLOT_KEYS[i].to_upper()) if i >= 0 else "Left behind", 12)
			var fill := minf(1, float(m.pts - m.prev) / maxf(1, m.next - m.prev)) if m.next > 0 else 1.0
			ch.add(Kit.meter(fill, Kit.GOLD, 5))
			ch.add("Mastery %d%s" % [m.lvl, " · triple rune" if m.lvl >= ta else ""], 11)
			ch.pressed.connect(func():
				var l := Progress.wiz_loadout()
				if l.has(el):
					if l.size() > 1:
						l.erase(el)
				elif l.size() < n:
					l.append(el)
				else:
					ui.toast("You can take %d elements: click a taken element to leave it behind first." % n)
					return
				Save.meta.wiz_load = l
				Save.save_meta()
				redraw.call())
		else:
			var need: int = game.R.element_unlock_at
			var par: String = E.parent
			var pm := Progress.el_mastery(par) if par != "" else m
			ch.modulate = Color(1, 1, 1, 0.8)
			ch.add(E.blurb, 11)
			ch.add(Kit.meter(minf(1, float(pm.lvl) / need), DB.elements[par].color if par != "" else Kit.GOLD, 5))
			ch.add(Kit.c("Locked: reach %s mastery %d (now %d)" % [DB.elements[par].name if par != "" else "?", need, pm.lvl], Kit.MUTED), 11)
			ch.disabled = true
		g.add_child(ch)
	v.add_child(g)
	v.add_child(lean(Progress.spells_for(load)))


## What a spell does, read from its description: damage is offense, walls and healing are defense, and
## push-back, slows, freezes, stuns, roots and "takes more damage" are utility.
func spell_lean(k: String) -> Dictionary:
	var t := Progress.spell_desc(k, Progress.book_hero(), 1.0).to_lower()
	var util := RegEx.create_from_string("push|blow|hurl|drag|pull|slow|freez|stun|root|more damage|mud|back along").search(t) != null
	var def := RegEx.create_from_string("wall|heal|shield").search(t) != null
	var t2 := RegEx.create_from_string("\\d+% more damage").sub(t, "", true)
	var off := RegEx.create_from_string("\\d+(?:\\.\\d+)? damage|\\d+/s|deals|strikes|slams|burns|smites").search(t2) != null
	var w := { off = 1.0 if off else 0.0, def = 1.2 if def else 0.0, util = 1.0 if util else 0.0 }
	var n: float = w.off + w.def + w.util
	if n == 0:
		n = 1
	return { off = w.off / n, def = w.def / n, util = w.util / n }


## A triangle with Offense, Defense and Utility at its corners and a dot where the spells' mix sits.
func lean(keys: Array) -> Control:
	var L := { off = 0.0, def = 0.0, util = 0.0 }
	for k in keys:
		var l := spell_lean(k)
		for x in L:
			L[x] += l[x]
	var n := maxf(1, keys.size())
	var o: float = L.off / n
	var dd: float = L.def / n
	var u: float = L.util / n
	var h := Kit.hbox(14)
	var tri := LeanTriangle.new()
	tri.mix = Vector3(o, dd, u)
	tri.custom_minimum_size = Vector2(192, 154)
	h.add_child(tri)
	var p := Kit.muted("Your %d spells lean %s offense (damage), %s defense (walls, healing) and %s utility (push-back, slows, freezes, extra damage taken)." % [keys.size(), Kit.b(UiText.pct(o)), Kit.b(UiText.pct(dd)), Kit.b(UiText.pct(u))])
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(p)
	return h


## Spellbook: the spells your chosen elements can cast first, then the rest of the elements you own.
func spellbook(h: Hero, load: Array, owned: Array, at := "main") -> Control:
	var ready := Progress.spells_for(load)
	var rest := Progress.spells_for(owned).filter(func(k): return not ready.has(k))
	var ults := owned.map(func(e): return e + "+" + e + "+" + e).filter(func(k): return DB.spells.has(k) and not ready.has(k) and not rest.has(k))
	var v := Kit.vbox(6)
	var row := func(k: String, list: VBoxContainer) -> void:
		var s: SpellData = DB.spells[k]
		var dots := ""
		for e in k.split("+"):
			dots += Kit.c("●", DB.elements[e].color)
		list.add_child(Kit.rich(dots + "  " + Kit.b(s.name) + "  " + Kit.c("%d mana" % int(s.mana), Kit.MUTED) + "\n" + Kit.c(Progress.spell_desc(k, h, h.spell), Kit.MUTED), 13))
	var main_list := Kit.vbox(6)
	var more_list := Kit.vbox(6)
	var toggle := func(key: String, label: String, list: Control) -> Button:
		var b := Kit.button(("▾ " if sb_open[key] else "▸ ") + label, func(): pass, "FlatButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			sb_open[key] = not sb_open[key]
			list.visible = sb_open[key]
			b.text = ("▾ " if sb_open[key] else "▸ ") + label)
		list.visible = sb_open[key]
		return b
	v.add_child(toggle.call(at, "Spellbook · %d spells with your elements" % ready.size(), main_list))
	for k in ready:
		row.call(k, main_list)
	v.add_child(main_list)
	if rest.size() or ults.size():
		main_list.add_child(toggle.call("more", "Other spells (%d)" % (rest.size() + ults.size()), more_list))
		more_list.add_child(Kit.muted("Spells that need an element you left behind, and three-rune ultimates, which open when an element reaches mastery %d." % game.R.triple_at))
		for k in rest:
			row.call(k, more_list)
		for k in ults:
			var el: String = k.split("+")[0]
			var m := Progress.el_mastery(el)
			var dots := ""
			for e in k.split("+"):
				dots += Kit.c("●", DB.elements[e].color)
			more_list.add_child(Kit.rich(dots + "  " + Kit.c(DB.spells[k].name, Kit.MUTED) + "  " + Kit.c("%s mastery %d/%d" % [DB.elements[el].name, m.lvl, game.R.triple_at], Kit.MUTED), 13))
		main_list.add_child(more_list)
	return v


# ---------- the Heroes and Towers pages ----------
func spent_on(defs: Array, obj) -> int:
	var n := 0
	for d: UpgradeData in defs:
		for r in Save.rank(obj, d.id):
			n += UiText.meta_cost(d, r)
	return n


func refund_value(kind: String, hero := "") -> int:
	var M := Save.meta
	match kind:
		"hero": return spent_on(DB.heroes[hero].meta, M.heroes[hero])
		"global": return spent_on(game.R.global_meta.items, M.global)
		"towerglobal": return spent_on(game.R.tower_global.items, M.tower_global)
	var n := 0
	for x: UpgradeData in game.R.specials.items:
		if x.hero == hero and M.specials.get(x.id, false):
			n += x.cores
	return n


func refund_btn(kind: String, hero: String, redraw: Callable) -> Control:
	var v := refund_value(kind, hero)
	if not v:
		return Control.new()
	return Kit.button("Refund %s %d" % ["⬢" if kind == "special" else "◆", v], func():
		var M := Save.meta
		var val := refund_value(kind, hero)
		match kind:
			"hero":
				M.shards += val
				M.heroes[hero] = {}
			"global":
				M.shards += val
				M.global = {}
			"towerglobal":
				M.shards += val
				M.tower_global = {}
			_:
				M.cores += val
				for x: UpgradeData in game.R.specials.items:
					if x.hero == hero:
						M.specials.erase(x.id)
		Save.save_meta()
		redraw.call(), "FlatButton")


func section(box: Control, title: String, extra: Control = null, col := Kit.MUTED) -> void:
	var h := Kit.hbox(10)
	h.add_child(Kit.h3(title, col))
	if extra:
		h.add_child(extra)
	box.add_child(h)


## One permanent upgrade with its buy button.
func meta_row(def: UpgradeData, obj: Dictionary, key: String, id: String, redraw: Callable) -> Control:
	var r := Save.rank(obj, def.id)
	var maxed := r >= def.max_rank
	var cost := UiText.meta_cost(def, r)
	var h := Kit.hbox(12)
	var v := Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.rich(Kit.b(def.name) + "  " + Kit.c("%d/%d" % [r, def.max_rank], Kit.MUTED), 15))
	var easy_key := ("herometa:" + id + ":" + def.id) if key == "hero" else ("global:" + def.id)
	if DB.is_simple() and DB.simple_texts.has(easy_key):
		v.add_child(Kit.muted(DB.simple_texts[easy_key]))
	else:
		v.add_child(Kit.muted(Fx.text(def.desc, { r = r }) if r else "Not bought"))
		if not maxed:
			v.add_child(Kit.rich(UiText.meta_delta(def, key, id, r), 12, Kit.OK))
	h.add_child(v)
	var b := Kit.button("Maxed" if maxed else "◆ %d" % cost, func():
		var rr := Save.rank(obj, def.id)
		var cc := UiText.meta_cost(def, rr)
		if Save.meta.shards < cc or rr >= def.max_rank:
			return
		Save.meta.shards -= cc
		obj[def.id] = rr + 1
		Save.save_meta()
		Sound.play("click")
		redraw.call())
	b.disabled = maxed or Save.meta.shards < cost
	b.custom_minimum_size = Vector2(110, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return _row_box(h)


func _row_box(c: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.box_style(Color(0, 0, 0, 0.12), Kit.LINE, 1, 6, 8))
	p.add_child(c)
	return p


func special_row(x: UpgradeData, redraw: Callable) -> Control:
	var own := bool(Save.meta.specials.get(x.id, false))
	var col: Color = Kit.RAR.get(x.rarity, Kit.PINK)
	var h := Kit.hbox(12)
	var v := Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.rich(Kit.b(Kit.c(x.name, col)) + "  " + Kit.c(DB.rar[x.rarity].name.to_upper() if DB.rar.has(x.rarity) else "", col), 15))
	v.add_child(Kit.muted(DB.tx("special:" + x.id, x.desc)))
	h.add_child(v)
	var b := Kit.button("Owned" if own else "⬢ %d" % x.cores, func():
		if Save.meta.specials.get(x.id, false) or Save.meta.cores < x.cores:
			return
		Save.meta.cores -= x.cores
		Save.meta.specials[x.id] = true
		Save.save_meta()
		Sound.play("level")
		redraw.call())
	b.disabled = own or Save.meta.get("cores", 0) < x.cores
	b.custom_minimum_size = Vector2(110, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return _row_box(h)


## Every path a Hero Shrine can offer, once each.
func _all_hero_paths(d: TowerData) -> Array:
	var out := []
	for ps in d.hero_paths:
		if DB.heroes.has(ps.hero) and not Progress.hero_open(ps.hero):
			continue
		for p in ps.paths:
			if not out.has(p):
				out.append(p)
	return out


## A secret hero that hasn't been unlocked: a dark, unnamed card.
func _locked_hero_card() -> Control:
	var ch := Choice.new(Kit.LINE)
	ch.add(Kit.label("SECRET HERO", 11, Kit.MUTED, Kit.display))
	var lt := Kit.head("I got pushback about this hero being locked", 20, Kit.MUTED)
	lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ch.add(lt)
	ch.add("Someone is waiting to be found. Keep playing and you might unlock them.", 13)
	ch.disabled = true
	ch.modulate = Color(1, 1, 1, 0.7)
	return ch


func show_heroes(sel := "vanguard") -> void:
	if not Progress.hero_open(sel):
		sel = "vanguard"
	queue_tip("heroes")
	var redraw := func(): show_heroes(sel)
	var y := ui.screen_scroll.scroll_vertical if ui.screen.visible else 0
	var box := ui.show_screen(show_menu)
	head(box, "Heroes", show_menu)
	var d: HeroData = DB.heroes[sel]
	var cols := Kit.hbox(12)
	var roster := Kit.vbox(6)
	roster.custom_minimum_size = Vector2(240, 0)
	for cat in UiText.CATEGORIES:
		roster.add_child(Kit.h3(cat[1]))
		var list := Array(DB.hero_order).filter(func(k): return DB.heroes[k].category == cat[0])
		if list.is_empty():
			roster.add_child(Kit.muted("More heroes coming."))
		for k in list:
			if not Progress.hero_open(k):
				var lk := _roster_btn("I got pushback about this hero being locked", "Secret hero · locked", Kit.MUTED, false, func(): ui.toast("A secret hero. Keep playing to find out how to unlock it."))
				roster.add_child(lk)
				continue
			roster.add_child(_roster_btn(DB.heroes[k].name, "%s · %s" % [DB.hero_ability(k).name if not DB.heroes[k].spells else "Spellcraft", UiText.hero_mastery_text(k)], DB.heroes[k].color, k == sel, func(): show_heroes(k)))
	cols.add_child(roster)
	var c := Kit.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Kit.vbox(8)
	c.add_child(v)
	var top := Kit.hbox(12)
	top.add_child(Portrait.make(sel, 3))
	var tv := Kit.vbox(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Kit.head("%s · %s" % [d.name, d.role], 20, d.color))
	tv.add_child(Kit.muted(DB.tx("hero:" + sel, d.desc), 14))
	top.add_child(tv)
	v.add_child(top)
	var rows := [["HP", UiText.f0(d.hp)]]
	if d.mana:
		rows.append(["Mana", "%d (+%s/s)" % [int(d.mana), UiText.f1t(d.mana_regen)]])
	else:
		rows += [["Damage", UiText.f0(d.dmg)], ["Attacks/s", UiText.f2(1 / d.rate)], ["Range", "Whole map" if d.range >= 9999 else UiText.f0(d.range)]]
	rows += [["Blocks", UiText.block_text(d.block)], ["Move speed", UiText.f0(d.speed)]]
	if d.brace: rows.append(["Brace time", UiText.f1t(d.brace) + "s"])
	if d.crit: rows.append(["Crit chance", UiText.pct(d.crit)])
	if not d.mana: rows.append(["Crit damage", "150%"])
	v.add_child(Kit.stats(rows, 3))
	section(v, "Stats")
	var M := Save.meta
	var srow := []
	var rn: String = Progress.ROLE_NAME[d.category]
	if rn != "kills":
		srow.append(["Total " + rn, str(int(round(Progress.hero_stat(sel))))])
	var won := 0
	for m in DB.map_order:
		if (M.wins.heroes.get(sel, {}) as Dictionary).get(m, false):
			won += 1
	srow += [["Total kills", str(int(M.kills.heroes.get(sel, 0)))], ["Total takedowns", str(int(M.takedowns.heroes.get(sel, 0)))], ["Runs", str(int(M.played.get(sel, 0)))], ["Maps beaten", "%d/%d" % [won, DB.map_order.size()]]]
	v.add_child(Kit.stats(srow, 3))
	if d.spells:
		elements_ui(v, redraw)
		v.add_child(Kit.muted(UiText.ability_text(game, Progress.book_hero())))
		v.add_child(spellbook(Progress.book_hero(), Progress.wiz_loadout(), Array(DB.el_order).filter(Progress.el_open)))
	else:
		v.add_child(UiText.mastery_box("heroes", sel))
		section(v, "Ability · pick one")
		v.add_child(_ability_picks(sel, redraw))
	section(v, d.name + " upgrades", refund_btn("hero", sel, redraw))
	for def in d.meta:
		v.add_child(meta_row(def, M.heroes[sel], "hero", sel, redraw))
	section(v, "Special upgrades · Boss Cores", refund_btn("special", sel, redraw), Kit.PINK)
	v.add_child(Kit.muted("Bought once with Boss Cores, which bosses drop. Game-changing, and expensive."))
	for x: UpgradeData in game.R.specials.items:
		if x.hero == sel:
			v.add_child(special_row(x, redraw))
	cols.add_child(c)
	box.add_child(cols)
	var all := Kit.card()
	var av := Kit.vbox(8)
	all.add_child(av)
	section(av, "All heroes", refund_btn("global", "", redraw))
	for def in game.R.global_meta.items:
		av.add_child(meta_row(def, M.global, "global", "", redraw))
	section(av, "Special upgrades for all heroes", refund_btn("special", "", redraw), Kit.PINK)
	for x: UpgradeData in game.R.specials.items:
		if x.hero == "":
			av.add_child(special_row(x, redraw))
	box.add_child(all)
	ui.screen_scroll.set_deferred("scroll_vertical", y)


func _roster_btn(name: String, sub: String, col: Color, on: bool, cb: Callable) -> Control:
	var ch := Choice.new(col if on else Kit.LINE, Kit.PANEL2 if on else Kit.PANEL)
	ch.pad = 10
	ch.add(Kit.c(sub.to_upper(), Kit.MUTED), 10)
	var nl := Kit.label(name, 16, col, Kit.display_bold)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ch.add(nl)
	ch.pressed.connect(cb)
	return ch


func show_towers(sel := "arcane") -> void:
	queue_tip("towers")
	var redraw := func(): show_towers(sel)
	var y := ui.screen_scroll.scroll_vertical if ui.screen.visible else 0
	var box := ui.show_screen(show_menu)
	head(box, "Towers", show_menu)
	lead(box, "Before each run you bring your hero and %d towers. Upgrades here are permanent." % game.R.loadout_size)
	var d: TowerData = DB.towers[sel]
	var M := Save.meta
	var TM: Dictionary = M.towers[sel]
	var cols := Kit.hbox(12)
	var roster := Kit.vbox(6)
	roster.custom_minimum_size = Vector2(240, 0)
	for k in DB.tower_order:
		var t: TowerData = DB.towers[k]
		roster.add_child(_roster_btn(t.name, "%s · Mastery %d" % ["Support" if t.support else "%d gold" % t.cost, Progress.mastery_of("towers", k).lvl], t.color, k == sel, func(): show_towers(k)))
	cols.add_child(roster)
	var c := Kit.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Kit.vbox(8)
	c.add_child(v)
	v.add_child(Kit.head(d.name, 20, d.color))
	v.add_child(Kit.muted(DB.tx("tower:" + sel, d.info), 14))
	var rows := []
	if d.hero_buff:
		rows.append(["Hero buff", "+10% damage, 5% less damage taken"])
	elif d.support:
		rows.append(["Buff", "+15% damage"])
	else:
		rows += [["Damage", UiText.f0(d.dmg)], ["Shots/s", UiText.f2(1 / d.rate)]]
	rows += ([] if d.hero_buff else [["Range", UiText.f0(d.range)]]) + [["Cost", str(d.cost)], ["Main effect", UiText.main_effect(sel)]]
	v.add_child(Kit.stats(rows, 3))
	section(v, "Stats")
	var won := 0
	for m in DB.map_order:
		if (M.wins.towers.get(sel, {}) as Dictionary).get(m, false):
			won += 1
	v.add_child(Kit.stats([["Total kills", str(int(M.kills.towers.get(sel, 0)))], ["Total takedowns", str(int(M.takedowns.towers.get(sel, 0)))], ["Maps beaten with it", "%d/%d" % [won, DB.map_order.size()]]], 3))
	v.add_child(UiText.mastery_box("towers", sel))
	section(v, "Paths")
	for ps: TowerPathSet in d.hero_paths:
		if DB.heroes.has(ps.hero) and not Progress.hero_open(ps.hero):
			continue
		var who: String = DB.heroes[ps.hero].name if DB.heroes.has(ps.hero) else "Other heroes"
		v.add_child(Kit.rich(Kit.b(who) + "  " + Kit.c(", ".join(ps.paths.map(func(p): return p.name)), Kit.MUTED), 14))
	for p: TowerPath in (_all_hero_paths(d) if d.hero_paths.size() else d.paths):
		v.add_child(Kit.rich(Kit.b(p.name) + "  " + Kit.c(DB.tx("path:" + sel + ":" + p.id, p.desc), Kit.MUTED) + "\n" + Kit.c("Mastery: %s. %s" % [p.mastery_name, DB.tx("mastery:" + sel + ":" + p.id, p.mastery_desc)], Kit.ARCANE), 14))
	# the Hero Shrine has no Signature, merges or named forms
	if not d.hero_buff:
		section(v, "Boss Core upgrade", null, Kit.PINK)
		var has_sig := bool(TM.get("sig", 0))
		var sh := Kit.hbox(12)
		var sv := Kit.vbox(2)
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.add_child(Kit.rich(Kit.b(Kit.c("Signature: " + d.signature_name, Kit.PINK)) + "  " + Kit.c("MYTHIC", Kit.PINK), 15))
		sv.add_child(Kit.muted(DB.tx("sig:" + sel, d.signature_desc)))
		sh.add_child(sv)
		var sb := Kit.button("Owned" if has_sig else "⬢ %d" % game.R.signature_cores, func():
			if TM.get("sig", 0) or M.cores < game.R.signature_cores:
				return
			M.cores -= game.R.signature_cores
			TM.sig = 1
			Save.save_meta()
			Sound.play("level")
			redraw.call())
		sb.disabled = has_sig or M.get("cores", 0) < game.R.signature_cores
		sb.custom_minimum_size = Vector2(110, 0)
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sh.add_child(sb)
		v.add_child(_row_box(sh))
		section(v, "Discoveries")
		v.add_child(Kit.muted("Hidden until you find them in a run."))
		var recipes := game.R.recipes.items.filter(func(r): return Array(r.key.split("+")).has(sel) and r.key.split("+").size() == 2)
		var found := recipes.filter(func(r): return Save.codex.get(r.key, false))
		var mlist := Kit.vbox(4)
		mlist.add_child(Kit.label("Merges: %d/%d found" % [found.size(), recipes.size()], 15, Kit.TEXT, Kit.display))
		for r: RecipeData in recipes:
			var p := r.key.split("+")
			var other: String = p[1] if p[0] == sel else p[0]
			if Save.codex.get(r.key, false):
				mlist.add_child(Kit.rich(Kit.b(Kit.c(r.name, Kit.TECH)) + "  " + Kit.c("%s + %s. %s" % [d.name, DB.towers[other].name, DB.tx("recipe:" + r.key, r.desc)], Kit.MUTED), 13))
			else:
				mlist.add_child(Kit.rich(Kit.b("???") + "  " + Kit.c("Merge a level %d %s with another tower type to discover this." % [game.R.max_level, d.name], Kit.MUTED), 13))
		v.add_child(mlist)
		var forms: Array = d.form_names.keys()
		var ffound := forms.filter(func(k): return M.forms.get(sel + ":" + k, false))
		var flist := Kit.vbox(4)
		flist.add_child(Kit.label("Path combinations: %d/%d found" % [ffound.size(), forms.size()], 15, Kit.TEXT, Kit.display))
		var more := Kit.vbox(4)
		more.visible = false
		var fb := Kit.button("▸ Show", func(): pass, "FlatButton")
		fb.pressed.connect(func():
			more.visible = not more.visible
			fb.text = "▾ Hide" if more.visible else "▸ Show")
		fb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		flist.add_child(fb)
		for k in forms:
			if M.forms.get(sel + ":" + k, false):
				var names := []
				for ch in k:
					names.append(d.paths[int(ch)].name)
				more.add_child(Kit.rich(Kit.b(Kit.c(d.form_names[k], Kit.TECH)) + "  " + Kit.c(" + ".join(names), Kit.MUTED), 13))
			else:
				more.add_child(Kit.rich(Kit.b("???") + "  " + Kit.c("Level a %s with %d paths to discover this form." % [d.name, k.length()], Kit.MUTED), 13))
		flist.add_child(more)
		v.add_child(flist)
	cols.add_child(c)
	box.add_child(cols)
	var all := Kit.card()
	var av := Kit.vbox(8)
	all.add_child(av)
	section(av, "All towers", refund_btn("towerglobal", "", redraw))
	for def in game.R.tower_global.items:
		av.add_child(meta_row(def, M.tower_global, "towerglobal", "", redraw))
	box.add_child(all)
	ui.screen_scroll.set_deferred("scroll_vertical", y)


# ---------- music ----------
func show_music() -> void:
	queue_tip("music")
	var box := ui.show_screen(show_menu)
	head(box, "Music", show_menu, [], false)
	lead(box, "Pick the background music. It plays on the menus and during runs.")
	var cur := Sound.current()
	var playing: bool = Sound.is_playing() and Save.settings.get("music_on", true)
	var now := Kit.card()
	var nv := Kit.vbox(8)
	now.add_child(nv)
	nv.add_child(Kit.label("NOW PLAYING" if playing else "PAUSED", 11, Kit.MUTED, Kit.display))
	nv.add_child(Kit.head(cur.name, 20, Kit.ARCANE))
	var seek_row := Kit.hbox(10)
	var t0 := Kit.label("0:00", 13, Kit.MUTED)
	var seek := HSlider.new()
	seek.min_value = 0
	seek.max_value = 1
	seek.step = 0.001
	seek.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seek.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t1 := Kit.label("0:00", 13, Kit.MUTED)
	seek_row.add_child(t0)
	seek_row.add_child(seek)
	seek_row.add_child(t1)
	nv.add_child(seek_row)
	var dragging := [false]
	seek.drag_started.connect(func(): dragging[0] = true)
	seek.drag_ended.connect(func(_c):
		dragging[0] = false
		if Sound.length() > 0:
			Sound.seek(seek.value * Sound.length()))
	var tick := Timer.new()
	tick.wait_time = 0.25
	tick.autostart = true
	tick.timeout.connect(func():
		var L := Sound.length()
		t0.text = _clock(Sound.position())
		t1.text = _clock(L)
		if L > 0 and not dragging[0]:
			seek.set_value_no_signal(Sound.position() / L))
	nv.add_child(tick)
	var row := Kit.hbox()
	var redraw := func(): (func(): if ui.screen.visible and music_screen == box: show_music()).call_deferred()
	row.add_child(Kit.button("PREVIOUS", func():
		if Sound.position() > 3:
			Sound.seek(0)
		else:
			Sound.next_song(-1)
		Save.settings.music_on = true
		Sound.apply()
		redraw.call()))
	row.add_child(Kit.go("PAUSE" if playing else "PLAY", func():
		if playing:
			Save.settings.music_on = false
			Save.save_settings()
			Sound.pause()
		else:
			Save.settings.music_on = true
			Sound.play_song(cur.id)
		redraw.call()))
	row.add_child(Kit.button("NEXT", func():
		Save.settings.music_on = true
		Sound.next_song()
		redraw.call()))
	nv.add_child(row)
	box.add_child(now)
	box.add_child(Kit.h3("Songs"))
	box.add_child(Kit.muted("Click a song to play it. Ticked songs make up your playlist, which the play mode moves through in order or shuffled. \"Loop one song\" repeats the song that is playing.", 14))
	var g := _grid(3)
	var pl := Sound.playlist()
	for i in Sound.songs.size():
		var s: Dictionary = Sound.songs[i]
		var open := Sound.song_open(s)
		var v := Kit.vbox(6)
		var ch := Choice.new()
		ch.picked = s.id == cur.id
		ch.add(Kit.c("TRACK %d" % (i + 1), Kit.MUTED), 11)
		ch.add(Kit.head(s.name, 18, Kit.ARCANE))
		ch.add(("Locked: beat %s to unlock" % DB.maps[s.unlock].scene.map_name) if not open else (("Playing" if playing else "Selected") if s.id == cur.id else "Click to play"), 13)
		ch.disabled = not open
		ch.pressed.connect(func():
			Save.settings.music_on = true
			Sound.play_song(s.id)
			redraw.call())
		v.add_child(ch)
		if open:
			var cb := CheckBox.new()
			cb.text = "In playlist"
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = pl.any(func(x): return x.id == s.id)
			cb.toggled.connect(func(on: bool):
				var ids := Sound.playlist().map(func(x): return x.id).filter(func(id): return id != s.id)
				if on:
					ids.append(s.id)
				Save.settings.playlist = Sound.songs.filter(func(x): return ids.has(x.id)).map(func(x): return x.id)
				Save.save_settings()
				Sound.apply()
				redraw.call())
			v.add_child(cb)
		g.add_child(v)
	box.add_child(g)
	var set := Kit.card()
	var sv := Kit.vbox(8)
	set.add_child(sv)
	sv.add_child(_check("Music", Save.settings.get("music_on", true), func(on):
		Save.settings.music_on = on
		Save.save_settings()
		Sound.play_song(cur.id)
		redraw.call()))
	sv.add_child(_slider("Master volume", Save.settings.get("master", 0.2), func(x):
		Save.settings.master = x
		Save.save_settings()
		Sound.apply()))
	sv.add_child(_slider("Music volume", Save.settings.get("music_volume", 0.5), func(x):
		Save.settings.music_volume = x
		Save.save_settings()
		Sound.apply()))
	var modes := Sound.MODES.keys()
	sv.add_child(_select("Play mode", modes.map(func(k): return Sound.MODES[k]), modes.find(Save.settings.get("music_mode", "all")), func(i):
		Save.settings.music_mode = modes[i]
		Save.save_settings()
		Sound.apply()))
	box.add_child(set)
	music_screen = box


func _clock(t: float) -> String:
	return "%d:%02d" % [int(t / 60), int(fmod(t, 60))]


func _setting_row(name: String, ctl: Control) -> Control:
	var h := Kit.hbox(12)
	var l := Kit.label(name, 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ctl)
	return h


func _check(name: String, on: bool, cb: Callable) -> Control:
	var c := CheckBox.new()
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	return _setting_row(name, c)


func _slider(name: String, v: float, cb: Callable, on_release := Callable()) -> Control:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(200, 16)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	if on_release.is_valid():
		s.drag_ended.connect(func(_c): on_release.call())
	var h := Kit.hbox(10)
	h.add_child(s)
	var pct := Kit.label("%d%%" % roundi(v * 100), 13, Kit.MUTED)
	pct.custom_minimum_size = Vector2(40, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	s.value_changed.connect(func(x): pct.text = "%d%%" % roundi(x * 100))
	return _setting_row(name, h)


func _select(name: String, items: Array, at: int, cb: Callable) -> Control:
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = maxi(0, at)
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(cb)
	return _setting_row(name, o)


# ---------- stats log ----------
func show_log() -> void:
	queue_tip("log")
	var box := ui.show_screen(show_menu)
	var runs: Array = Save.meta.runs.duplicate()
	runs.reverse()
	head(box, "Stats log", show_menu, [Kit.button("COPY FULL LOG", func():
		DisplayServer.clipboard_set(JSON.stringify(Save.meta.runs, " "))
		ui.toast("Log copied."))], false)
	lead(box, "Your last %d runs, newest first. Click a run for the details. Copy the full log to share it for balancing." % runs.size())
	if runs.is_empty():
		box.add_child(Kit.muted("No runs yet."))
	var widths := [150, 110, 60, 70, 80, 220, 80]
	var head_row := Kit.hbox(12)
	for i in 7:
		var l := Kit.label(["Map", "Hero", "Wave", "Result", "Lives lost", "Top damage", "Shards"][i].to_upper(), 11, Kit.MUTED, Kit.display)
		l.custom_minimum_size = Vector2(widths[i], 0)
		head_row.add_child(l)
	if runs.size():
		var hp := MarginContainer.new()
		hp.add_theme_constant_override("margin_left", 32)
		hp.add_child(head_row)
		box.add_child(hp)
	for r in runs:
		var c := Kit.card(8)
		var v := Kit.vbox(6)
		c.add_child(v)
		var mp = DB.maps.get(r.get("map", ""))
		var cells := [mp.scene.map_name if mp else str(r.get("map", "")), DB.heroes[r.hero].name if DB.heroes.has(r.get("hero", "")) else str(r.get("hero", "")),
			str(int(r.get("wave", 0))), "Won" if r.get("won", false) else "Lost", str(int(r.get("lives_lost", r.get("livesLost", 0)))),
			str(r.get("top", "")) if str(r.get("top", "")) != "" else "-", "◆ %d" % int(r.get("shards", 0))]
		var row := Kit.hbox(12)
		var arrow := Kit.label("▸", 14, Kit.MUTED)
		arrow.custom_minimum_size = Vector2(20, 0)
		row.add_child(arrow)
		for i in 7:
			var col: Color = Kit.OK if (i == 3 and r.get("won", false)) else (Kit.TECH if i == 6 else Kit.TEXT)
			var l := Kit.label(cells[i], 14, col)
			l.custom_minimum_size = Vector2(widths[i], 0)
			l.clip_text = true
			row.add_child(l)
		var bt := Button.new()
		bt.flat = true
		bt.focus_mode = Control.FOCUS_NONE
		bt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bt.custom_minimum_size = Vector2(0, 26)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for ch in row.get_children():
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bt.add_child(row)
		v.add_child(bt)
		var more := Kit.vbox(8)
		more.visible = false
		v.add_child(more)
		bt.pressed.connect(func():
			if more.get_child_count() == 0:
				_run_details(more, r)
			more.visible = not more.visible
			arrow.text = "▾" if more.visible else "▸")
		box.add_child(c)


## The drop-down of one logged run. Older runs logged fewer numbers, so missing ones are worked out from the waves or skipped.
func _run_details(v: VBoxContainer, r: Dictionary) -> void:
	var waves: Array = r.get("waves", [])
	var hero_dmg := 0.0
	var tower_dmg := 0.0
	var gold := 0.0
	var kos := 0
	var kills := 0
	var times := []
	for w in waves:
		hero_dmg += float(w.get("hero_dmg", 0))
		tower_dmg += float(w.get("tower_dmg", 0))
		gold += float(w.get("gold", 0))
		kos += int(w.get("hero_kos", 0))
		kills += int(w.get("kills", 0))
		if w.get("cleared", false):
			times.append(float(w.get("seconds", 0)))
	if tower_dmg == 0 and r.get("towers") is Array:
		for t in r.towers:
			tower_dmg += float(t.get("dmg", 0))
	var f0 := func(x: float) -> String: return UiText.f0(x)
	var clock := func(sec: float) -> String: return "%d:%02d" % [int(sec) / 60, int(sec) % 60]
	var rows := [["Total damage", f0.call(hero_dmg + tower_dmg)], ["Hero damage", f0.call(hero_dmg)], ["Tower damage", f0.call(tower_dmg)]]
	if r.has("kills_hero"):
		rows += [["Hero kills", str(int(r.kills_hero))], ["Tower kills", str(int(r.get("kills_towers", 0)))], ["Hero takedowns", str(int(r.get("takedowns", 0)))]]
	else:
		rows.append(["Kills", str(kills)])
	rows += [["Total kills", str(int(r.get("kills_hero", 0)) + int(r.get("kills_towers", 0)) if r.has("kills_hero") else kills)], ["Gold earned", f0.call(gold)], ["Hero knockouts", str(kos)]]
	if int(r.get("blocked", 0)):
		rows.append(["Damage blocked", str(int(r.blocked))])
	if times.size():
		var total := 0.0
		for t in times:
			total += t
		rows += [["Avg wave clear", clock.call(total / times.size())], ["Fastest wave", clock.call(times.min())], ["Slowest wave", clock.call(times.max())]]
	if r.has("run_seconds"):
		rows.append(["Run length", clock.call(float(r.run_seconds))])
	if waves.size():
		rows.append(["Damage per wave", f0.call((hero_dmg + tower_dmg) / waves.size())])
	rows += [["Hero level", str(int(r.get("hero_lvl", 1)))], ["Ability", str(r.get("ability", "-"))], ["Boss Cores", str(int(r.get("cores", 0)))]]
	v.add_child(Kit.stats(rows, 3))
	v.add_child(Kit.muted("Wave times are game time, so fast-forward doesn’t change them.", 12))
	var lists := [["Upgrades", r.get("upgrades", [])], ["Relics", r.get("relics", [])], ["Boons", r.get("boons", [])]]
	var hx = r.get("heroics", {})
	if hx is Dictionary and hx.size():
		lists.append(["Heroic powers", hx.keys().map(func(k): return "%s %s" % [k, "I".repeat(int(hx[k]))])])
	for pair in lists:
		if (pair[1] as Array).size():
			v.add_child(Kit.rich(Kit.b(pair[0] + ": ") + Kit.c(", ".join(pair[1]), Kit.MUTED), 13))
	if r.get("towers") is Array and r.towers.size():
		var ts: Array = r.towers.duplicate()
		ts.sort_custom(func(a, b): return a.dmg > b.dmg)
		v.add_child(Kit.rich(Kit.b("Towers by damage: ") + Kit.c(", ".join(ts.slice(0, 8).map(func(t): return "%s (%s dmg, %d kills)" % [t.name, UiText.f0(t.dmg), int(t.get("kills", 0))])), Kit.MUTED), 13))
	if waves.size():
		var g := GridContainer.new()
		g.columns = 7
		g.add_theme_constant_override("h_separation", 16)
		g.add_theme_constant_override("v_separation", 2)
		for h in ["Wave", "Mode", "Time", "Kills", "Lives lost", "Hero dmg", "Tower dmg"]:
			g.add_child(Kit.label(h.to_upper(), 10, Kit.MUTED, Kit.display))
		for w in waves:
			g.add_child(Kit.label(str(int(w.get("wave", 0))), 12))
			g.add_child(Kit.label(str(w.get("mode", "")), 12, Kit.MUTED))
			g.add_child(Kit.label(clock.call(float(w.get("seconds", 0))), 12))
			g.add_child(Kit.label(str(int(w.get("kills", 0))), 12))
			g.add_child(Kit.label(str(int(w.get("lives_lost", 0))), 12, Kit.DANGER if int(w.get("lives_lost", 0)) else Kit.TEXT))
			g.add_child(Kit.label(UiText.f0(float(w.get("hero_dmg", 0))), 12))
			g.add_child(Kit.label(UiText.f0(float(w.get("tower_dmg", 0))) if w.has("tower_dmg") else "-", 12))
		v.add_child(g)


# ---------- settings ----------
## Settings: from the main menu, or mid-run with Esc / the gear button (which pauses the game).
func show_settings() -> void:
	var in_run := ui.in_run()
	if in_run:
		if ui.modal_open():
			return
		game.S.paused = true
	var box := ui.open_modal(560, close_settings)
	ui.settings_open = true
	box.add_child(Kit.head("Paused" if in_run else "Settings", 24))
	var st := Save.settings
	box.add_child(_check("Music", st.get("music_on", true), func(on):
		st.music_on = on
		Save.save_settings()
		if on:
			Sound.start()
		Sound.apply()))
	box.add_child(_slider("Master volume", st.get("master", 0.2), func(x):
		st.master = x
		Save.save_settings()
		Sound.apply()))
	box.add_child(_slider("Music volume", st.get("music_volume", 0.5), func(x):
		st.music_volume = x
		Save.save_settings()
		Sound.apply()))
	box.add_child(_slider("Sound effects volume", st.get("volume", 0.6), func(x):
		st.volume = x
		Save.save_settings()
		Sound.apply(), func(): Sound.play("level")))
	box.add_child(_check("Mute sound effects", st.get("muted", false), func(on):
		st.muted = on
		Save.save_settings()
		Sound.apply()))
	box.add_child(_check("Fullscreen", st.get("fullscreen", true), func(on):
		st.fullscreen = on
		Save.save_settings()
		Main.apply_window()))
	box.add_child(_check("Move the hero with WASD / arrow keys", game.key_move, func(on):
		game.key_move = on
		st.keys = on
		game.held.clear()
		ui.held_keys.clear()
		Save.save_settings()
		if ui.in_run():
			ui.render_build_bar()
		ui.toast("WASD / arrow movement " + ("on." if on else "off."))))
	box.add_child(_select("Sniper’s Piercing Shot aims at", ["The aim point (F), or the lead enemy", "Wherever your cursor is"], 1 if st.get("pierce_cursor", false) else 0, func(i):
		st.pierce_cursor = i == 1
		Save.save_settings()
		if ui.in_run():
			ui.render_build_bar()))
	box.add_child(_select("Explanations", ["Detailed: exact numbers", "Simple: just the idea"], 1 if DB.is_simple() else 0, func(i):
		st.simple = i == 1
		Save.save_settings()
		if ui.in_run():
			ui.render_inspector()
			ui.render_hero()
			ui.render_enemy_codex()))
	var row := Kit.flow(8)
	row.add_child(Kit.go("RESUME" if in_run else "DONE", close_settings))
	if in_run:
		row.add_child(Kit.button("RESTART RUN", func():
			var id := game.S.map_id
			ui.close_modal()
			game.S.paused = false
			game.end_run(false, true)
			ui.close_modal()
			new_run(id)))
		row.add_child(Kit.button("MAIN MENU", confirm_quit))
	row.add_child(Kit.button("QUIT GAME", func(): ui.get_tree().quit()))
	box.add_child(row)
	ui.settings_open = true


func close_settings() -> void:
	ui.close_modal()
	if ui.in_run():
		game.S.paused = game.S.user_pause


func confirm_quit() -> void:
	if game.S.over:
		show_menu()
		return
	game.S.paused = true
	var stay := func():
		ui.close_modal()
		game.S.paused = game.S.user_pause
	var box := ui.open_modal(520, stay)
	box.add_child(Kit.head("Leave this run?", 24))
	box.add_child(Kit.rich("You'll still earn Rift Shards for the waves you cleared.", 15, Kit.MUTED))
	var row := Kit.hbox()
	row.add_child(Kit.go("KEEP PLAYING", stay))
	row.add_child(Kit.button("END RUN", func():
		game.S.paused = false
		game.end_run(false, true)))
	box.add_child(row)


## A hero's menu art: its south-facing idle frames, zoomed, bobbing between the two.
class Portrait extends TextureRect:
	var frames: Array[AtlasTexture] = []
	var t := 0.0
	var i := 0

	static func make(id: String, z: float) -> Portrait:
		var p := Portrait.new()
		var tex: Texture2D = DB.heroes[id].sheet
		for row in [0, 1]:
			var a := AtlasTexture.new()
			a.atlas = tex
			a.region = Rect2(4 * 48, row * 48, 48, 48)
			p.frames.append(a)
		p.texture = p.frames[0]
		p.custom_minimum_size = Vector2(48, 48) * z
		p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return p

	func _process(dt: float) -> void:
		t += dt
		if t >= 0.35:
			t = 0.0
			i = 1 - i
			texture = frames[i]


## The spell-mix triangle.
class LeanTriangle extends Control:
	var mix := Vector3(1, 0, 0)

	func _draw() -> void:
		var A := Vector2(80, 12) + Vector2(16, 4)
		var B := Vector2(14, 124) + Vector2(16, 4)
		var C := Vector2(146, 124) + Vector2(16, 4)
		draw_colored_polygon(PackedVector2Array([A, B, C]), Color(Kit.ARCANE, 0.08))
		draw_polyline(PackedVector2Array([A, B, C, A]), Kit.LINE.lightened(0.2), 1.5)
		for p in [[A, (B + C) / 2], [B, (A + C) / 2], [C, (A + B) / 2]]:
			draw_line(p[0], p[1], Color(Kit.LINE, 0.8), 1)
		var dot: Vector2 = A * mix.x + B * mix.y + C * mix.z
		draw_circle(dot, 6, Kit.GOLD)
		var f := Kit.display
		draw_string(f, A + Vector2(-26, -2), "Offense", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Kit.MUTED)
		draw_string(f, B + Vector2(-20, 18), "Defense", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Kit.MUTED)
		draw_string(f, C + Vector2(-20, 18), "Utility", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Kit.MUTED)
