## The pop-ups the game opens during a run: hero upgrades, boons, heroic powers, the boss shop,
## the wave choice and the end-of-run summary. The game emits `modal(kind, data)` and this builds the window.
class_name Dialogs
extends RefCounted

var ui: Ui
var game: Game


func _init(u: Ui) -> void:
	ui = u
	game = u.game


func open(kind: String, data: Dictionary) -> void:
	match kind:
		"level_up": level_up(data)
		"boon": boon(data)
		"heroic": heroic(data)
		"shop": shop(data)
		"wave_choice": wave_choice(data)
		"end": end(data)
		"secret": secret(data)


func _title(box: VBoxContainer, text: String, col := Kit.TEXT) -> void:
	box.add_child(Kit.head(text, 26, col))


func _lead(box: VBoxContainer, bb: String) -> void:
	box.add_child(Kit.rich(bb, 15, Kit.MUTED))


## A wrapping row of choice cards, three to a line.
func _choices(box: VBoxContainer, cols := 3) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(g)
	return g


func _card(rar_id: String, demonic := false) -> Choice:
	var col: Color = Kit.RAR.get(rar_id, Kit.LINE)
	var ch := Choice.new(Kit.LINE if rar_id == "common" else col, Color("#1a0d14") if demonic else Kit.PANEL)
	if demonic:
		ch.accent = Kit.DANGER
		ch.glow = Color(Kit.DANGER, 0.25)
	elif rar_id in ["mythic", "legendary", "secret", "secret_mythic", "secret_legendary", "developer", "heroic"]:
		ch.glow = Color(col, 0.18)
	ch.custom_minimum_size = Vector2(190, 0)
	ch.size_flags_vertical = Control.SIZE_FILL
	ch._style()
	return ch


func _path(text: String, col := Kit.MUTED) -> String:
	return Kit.c(Kit.d(text.to_upper()), col)


# ---------- hero upgrades ----------
func level_up(data: Dictionary) -> void:
	var box := ui.open_modal(720)
	_title(box, "Hero upgrade")
	_lead(box, "Level %d. Choose one. Rarer upgrades are stronger. Demonic ones are twice as strong but carry a curse." % data.lvl)
	var g := _choices(box)
	var offers: Array = data.offers
	for i in offers.size():
		var o: Dictionary = offers[i]
		var r: Dictionary = o.rarity
		var ch := _card(r.id, o.demonic)
		var col: Color = Kit.RAR.get(r.id, Kit.MUTED)
		ch.add(_path(("Demonic " if o.demonic else "") + r.name + " · " + game.pool_name(o), col), 12)
		ch.add(Kit.b(o.perk.name), 16, Kit.TEXT)
		ch.add(game.perk_desc(o), 13, Kit.MUTED)
		if o.get("bonus"):
			ch.add(Kit.c("Plus Rare %s: %s" % [o.bonus.perk.name, game.perk_desc(o.bonus)], Kit.RAR.get("rare", Kit.MUTED)), 12)
		if not DB.is_simple():
			ch.add(Kit.c(UiText.preview_run(game, func(): game.apply_offer(o), o.perk.name), Kit.TECH), 12)
		if o.demonic:
			ch.add(Kit.c("Curse: " + game.curse_desc(o), Kit.DANGER), 12)
		var n := game.owned_count(o.perk.id)
		if n:
			ch.add(Kit.c("Owned ×%d" % n, Kit.GOLD), 12)
		ch.pressed.connect(func():
			ui.close_modal()
			game.pick_offer(i)
			ui.render_build_bar()
			ui.render_hero())
		g.add_child(ch)
	var row := Kit.hbox()
	var rr := Kit.button("Reroll offers (%d left)" % data.rerolls, func():
		ui.close_modal()
		game.reroll_offers())
	rr.disabled = data.rerolls <= 0
	row.add_child(rr)
	box.add_child(row)


func boon(data: Dictionary) -> void:
	var rec: RecipeData = data.recipe
	var box := ui.open_modal(520)
	_title(box, "Resonance")
	_lead(box, "Your new %s resonates with your hero and awakens a power." % rec.name)
	var g := _choices(box, 1)
	var ch := _card("heroic")
	ch.add(_path("Inspired by " + rec.name, Kit.HEROIC), 12)
	ch.add(Kit.b(rec.boon_name), 16, Kit.TEXT)
	ch.add(data.desc, 13, Kit.MUTED)
	ch.pressed.connect(func():
		ui.close_modal()
		game.take_boon())
	g.add_child(ch)


func heroic(data: Dictionary) -> void:
	var fresh: Array = data.fresh
	var owned: Array = data.owned
	var box := ui.open_modal(760)
	_title(box, "Heroic power")
	_lead(box, "The boss dropped a heroic power. Take a new one%s." % (", or empower one you already have (up to rank 3)" if owned.size() else ""))
	var g := _choices(box, mini(4, fresh.size() + owned.size()))
	var S := game.S
	for x: UpgradeData in fresh:
		var ch := _card("heroic")
		ch.add(_path("Heroic · New", Kit.HEROIC), 12)
		ch.add(Kit.b(x.name), 16, Kit.TEXT)
		ch.add(DB.tx("heroic:" + x.id, game.heroic_desc(x, 1)), 13, Kit.MUTED)
		ch.pressed.connect(func():
			ui.close_modal()
			game.pick_heroic(x))
		g.add_child(ch)
	for x: UpgradeData in owned:
		var r: int = S.heroics[x.id]
		var ch := _card("heroic")
		ch.add(_path("Empower · Rank %d → %d" % [r, r + 1], Kit.HEROIC), 12)
		ch.add(Kit.b(x.name), 16, Kit.TEXT)
		ch.add("Makes it stronger." if DB.is_simple() else game.heroic_desc(x, r + 1), 13, Kit.MUTED)
		ch.pressed.connect(func():
			ui.close_modal()
			game.pick_heroic(x))
		g.add_child(ch)


# ---------- the boss shop ----------
func shop(data: Dictionary) -> void:
	var demonic: bool = data.demonic
	var S := game.S
	var leave := func():
		ui.close_modal()
		game.leave_shop()
	var box := ui.open_modal(780, leave)
	_title(box, "☠ Demonic Bazaar" if demonic else "Rift Bazaar", Kit.DANGER if demonic else Kit.TEXT)
	_lead(box, ("A demonic merchant has opened shop. Half of these are demonic: twice as strong, with a curse." if demonic
		else "The boss dropped a key to the Rift Bazaar. Everything here is sold only in this shop.")
		+ " You have " + Kit.b(Kit.c("%d gold" % floori(S.gold), Kit.GOLD)) + ".")
	var g := _choices(box)
	var items: Array = data.items
	for i in items.size():
		var x: Dictionary = items[i]
		var price := game.shop_price(x)
		var ch := _card("common", x.dem)
		ch.disabled = x.sold or S.gold < price
		ch.add(_path(("Demonic " if x.dem else "") + x.it.shop_kind, Kit.DANGER if x.dem else Kit.MUTED), 12)
		ch.add(Kit.b(x.it.name), 16, Kit.TEXT)
		ch.add(game.shop_desc(x), 13, Kit.MUTED)
		if not x.sold and not DB.is_simple():
			ch.add(Kit.c(UiText.preview_run(game, func(): Fx.run(x.it.effect, { m = x.m, run = S, h = S.hero }), x.it.name), Kit.TECH), 12)
		if x.curse:
			ch.add(Kit.c("Curse: " + DB.tx("curse:" + x.curse.id, Fx.text(x.curse.desc, { k = x.k, run = S, h = S.hero })), Kit.DANGER), 12)
		ch.add(Kit.c("Bought" if x.sold else ("Free" if price == 0 else "%d gold" % price), Kit.GOLD), 13)
		ch.pressed.connect(func(): game.buy(i)) # buying re-opens the shop with the new state
		g.add_child(ch)
	var row := Kit.hbox()
	row.add_child(Kit.go("Leave shop", leave))
	box.add_child(row)


# ---------- choosing the next wave ----------
func wave_choice(data: Dictionary) -> void:
	# The first time, explain Hard and Challenge waves, then ask again once the tip is closed.
	if ui.menus.first_tip("waves", func(): game.S.need_choice = true):
		return
	var opts: Array = data.opts
	var box := ui.open_modal(780)
	_title(box, "Choose wave %d" % data.n)
	_lead(box, ("A boss leads this wave. " if data.boss else "")
		+ "Hard waves make enemies tougher for a little gold. Challenge waves also add a handicap and a goal: meet the goal to earn the reward.")
	var g := _choices(box)
	var line_col := { tough = Kit.HEROIC, debuff = Kit.DANGER, req = Kit.OK }
	for i in opts.size():
		var o: Dictionary = opts[i]
		var rar: String = o.get("rarity", "")
		var acc: Color = Kit.RAR[rar] if rar != "" else ({ hard = Kit.HEROIC, challenge = Kit.ARCANE }.get(o.kind, Kit.LINE) as Color)
		var ch := Choice.new(acc, Kit.PANEL)
		if rar != "":
			ch.glow = Color(acc, 0.2)
			ch._style()
		ch.custom_minimum_size = Vector2(200, 0)
		ch.add(Kit.b(o.name), 16, Kit.TEXT)
		if o.kind == "normal":
			ch.add("A standard wave.", 13, Kit.MUTED)
		else:
			for l in game.mode_lines(o):
				ch.add("• " + Kit.b(Kit.c(("Must: " if l.k == "req" else "") + l.name, line_col.get(l.k, Kit.TEXT))) + " " + l.rule, 13, Kit.MUTED)
		var rw = o.get("reward")
		ch.add(Kit.c(((("If you succeed: " if o.get("req", "") != "" else "Reward: ") + rw.label) if rw else "Reward: the usual wave bonus"), Kit.GOLD), 13)
		ch.pressed.connect(func():
			ui.close_modal()
			game.choose_mode(i)
			ui.render_build_bar()
			ui.render_mode_banner())
		g.add_child(ch)


# ---------- the end of a run ----------
## A secret hero was just unlocked.
func secret(data: Dictionary) -> void:
	var d: HeroData = DB.heroes[data.hero]
	var box := ui.open_modal(560, func(): _close_secret())
	box.add_child(Kit.rich(_path("Secret unlocked", Kit.PINK), 13))
	var row := Kit.hbox(16)
	var pic := Menus.Portrait.make(data.hero, 3)
	row.add_child(pic)
	var tv := Kit.vbox(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(Kit.head("A new hero: " + d.name + "!", 28, d.color))
	tv.add_child(Kit.rich("All that wind you whipped up as the Wizard woke something. %s, the %s brawler, has joined your roster. Pick %s on the hero screen in your next run." % [Kit.b(d.name), d.role.to_lower(), d.name], 15, Kit.MUTED))
	row.add_child(tv)
	box.add_child(row)
	var r := Kit.hbox()
	r.add_child(Kit.go("AWESOME", func(): _close_secret()))
	box.add_child(r)
	Sound.play("level")


func _close_secret() -> void:
	ui.close_modal()
	if game.S:
		game.S.paused = false


func end(data: Dictionary) -> void:
	var S := game.S
	var won: bool = data.won
	var map_id := S.map_id
	ui.render_mode_banner()
	var box := ui.open_modal(720)
	_title(box, "The rift is sealed" if won else ("Run ended" if data.quit else "The base has fallen"), Kit.GOLD if won else Kit.TEXT)
	_lead(box, "%s on %s as a level %d %s." % ["You held all %d waves" % game.max_wave if won else "You reached wave %d" % S.wave,
		S.map.scene.map_name, S.hero.lvl, DB.heroes[S.hero.cls].name])
	if not won and S.lose_reason != "":
		box.add_child(Kit.rich(S.lose_reason, 15, Kit.DANGER))
	var gain := Kit.c(Kit.d("+◆ %d Rift Shards" % data.shards), Kit.ARCANE) + Kit.c(" (%d total)" % Save.meta.shards, Kit.MUTED)
	if data.cores:
		gain += "  ·  " + Kit.c(Kit.d("+⬢ %d Boss Cores" % data.cores), Kit.HEROIC) + Kit.c(" (%d total)" % int(Save.meta.get("cores", 0)), Kit.MUTED)
	box.add_child(Kit.rich(gain, 17))
	var tk := 0
	for k in S.kills.towers:
		tk += int(S.kills.towers[k])
	box.add_child(Kit.muted("Your hero: %d kills, %d takedowns. Towers: %d kills." % [S.kills.hero, S.takedowns.hero, tk]))
	if data.mastery.size():
		var tags := Kit.flow(6)
		for m in data.mastery:
			var col: Color = m.color if m.color != null else Kit.TEXT
			tags.add_child(Kit.tag(Kit.c("%s: mastery %d → %d%s" % [m.name, m.a, m.b, " · triple rune open" if m.get("triple", false) else ""], col)))
		box.add_child(tags)
	for s in data.new_songs:
		var c := Kit.card(10)
		var v := Kit.vbox(4)
		c.add_child(v)
		v.add_child(Kit.rich(_path("New song unlocked", Kit.PINK), 12))
		v.add_child(Kit.rich(Kit.b(s.name), 16))
		var row := Kit.hbox()
		var bt: Button
		bt = Kit.go("Play it now", func():
			Save.settings.music_on = true
			Sound.play_song(s.id)
			bt.text = "Playing"
			bt.disabled = true)
		row.add_child(bt)
		v.add_child(row)
		box.add_child(c)
	var rows: Array = S.log.slice(-6)
	if rows.size():
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 3)
		for h in ["Wave", "Mode", "Lives lost", "Hero dmg", "Top tower"]:
			grid.add_child(Kit.label(h, 13, Kit.MUTED, Kit.display))
		for w in rows:
			var top = w.towers[0] if w.towers.size() else null
			for cell in [str(w.wave), str(w.mode), str(w.lives_lost), str(w.hero_dmg), "%s (%d)" % [top.name, top.dmg] if top else "-"]:
				grid.add_child(Kit.label(cell, 14))
		var wrap := PanelContainer.new()
		wrap.add_theme_stylebox_override("panel", Kit.box_style(Kit.PANEL2, Kit.LINE, 1, 6, 10))
		wrap.add_child(grid)
		box.add_child(wrap)
	var btns := Kit.hbox()
	btns.add_child(Kit.go("Play again", func(): ui.menus.new_run(map_id)))
	btns.add_child(Kit.button("Main menu", func(): ui.menus.show_menu()))
	box.add_child(btns)
