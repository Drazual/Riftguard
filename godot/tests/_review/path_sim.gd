## Tower path balance harness. Headless, from the repo root:
##   godot --headless --path godot res://tests/_review/path_sim.tscn -- <tower> [combos|singles]
## combos: every 3-path build at level 13 (4/4/4). singles: each path alone at level 5 (4 points), plus "none".
## Prints one line per build: RES,<tower>,<paths>,<scenario values...>
## Scenarios (anvil differs): boss = stationary Warden dps over 30 s; bosswalk = total damage to a walking Warden;
## swarm = 60 Grunts (wave 30, 4x HP); armored = 20 Bastions (wave 25, 2x HP); fast = 60 Runners (wave 30, 4x HP).
## Anvil: boss_block, swarm_block (Vanguard holding the lane, invulnerable), bosswalk, swarm, armored.
## Frost/Beacon: values are the damage of two maxed reference towers (Arcane hex+surge+quick, Plasma hot+burn+auto) beside them.
## Env OVR="tesla.dmg=34;disc.rate=2.0" overrides TowerData numbers for a quick what-if.
extends Node

var g: Game
var S
const DT := 1.0 / 30
var tower_type := "arcane"
var mode := "combos"
var refs := []

func _add_ref(type: String, combo: Array, near: Tower) -> void:
	var cells: Array = g.build_cells()
	var reach := 120.0
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for c in cells:
		if g.build_problem(c.x, c.y, type) != "":
			continue
		var p: Vector2 = g.cell_pos(c.x, c.y)
		var dd := p.distance_to(near.pos())
		if dd < 40:
			continue
		if dd < bd:
			bd = dd
			best = c
	g.place_tower(best.x, best.y, type)
	var t: Tower = S.towers[-1]
	S.free_levels = 999
	for id in combo:
		for o in g.tower_options(t):
			if o.id == id:
				for i in 4:
					g.level_tower(t, o)
	refs.append(t)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	tower_type = args[0] if args.size() > 0 else "arcane"
	mode = args[1] if args.size() > 1 else "combos"
	seed(42)
	for kv in OS.get_environment("OVR").split(";", false):
		var p := kv.split("=")
		DB.towers[p[0].split(".")[0]].set(p[0].split(".")[1], float(p[1]))
	g = Game.new()
	add_child(g)
	g.start_test_room("vanguard")
	S = g.S
	var paths: Array = g.tower_paths(tower_type)
	var ids := paths.map(func(p): return p.id)
	var combos := []
	if mode == "singles":
		for i in ids.size():
			combos.append([ids[i]])
		combos.append([])
	else:
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				for c in range(b + 1, ids.size()):
					combos.append([ids[a], ids[b], ids[c]])
	var scen := ["boss", "bosswalk", "swarm", "armored", "fast"]
	if tower_type == "anvil":
		scen = ["boss_block", "swarm_block", "bosswalk", "swarm", "armored"]
	for combo in combos:
		var row := []
		for sc in scen:
			row.append(_run(combo, sc))
		print("RES,%s,%s,%s" % [tower_type, "+".join(combo) if combo.size() else "none", ",".join(row.map(func(v): return "%.0f" % v))])
	print("SIM DONE")
	get_tree().quit()


func _best_cell(r: float) -> Vector2i:
	var cells: Array = g.build_cells()
	var pts := []
	var d := 0.0
	while d < S.map.path_len:
		pts.append(S.map.pos_at(d, 0))
		d += 6.0
	var best := Vector2i(-1, -1)
	var bs := -1
	for c in cells:
		if g.build_problem(c.x, c.y, tower_type) != "":
			continue
		var p: Vector2 = g.cell_pos(c.x, c.y)
		var n := 0
		for q in pts:
			if p.distance_to(q) <= r:
				n += 1
		if n > bs:
			bs = n
			best = c
	return best


func _setup(combo: Array) -> Tower:
	for t in S.towers.duplicate():
		S.towers.erase(t)
	S.bought = {}
	var d: TowerData = DB.towers[tower_type]
	var cell := _best_cell(minf(d.range, 160.0))
	g.place_tower(cell.x, cell.y, tower_type)
	var t: Tower = S.towers[-1]
	S.free_levels = 999
	var opts: Array = g.tower_options(t)
	var target_lvl := 1
	for id in combo:
		for o in opts:
			if o.id == id:
				for i in 4:
					g.level_tower(t, o)
	# fill remaining levels (singles mode) - none: singles test at level 5
	return t


func _run(combo: Array, sc: String) -> float:
	g.test_clear()
	S.zones = [] if "zones" in S else S.zones
	var t := _setup(combo)
	refs = []
	if tower_type in ["frost", "beacon"]:
		_add_ref("arcane", ["hex", "surge", "quick"], t)
		_add_ref("plasma", ["hot", "burn", "auto"], t)
	var h = S.hero
	h.stun_t = 1e9
	h.hp = 1e12
	h.max_hp = 1e12
	h.dmg = 0.0
	var block: bool = sc.ends_with("_block")
	if block:
		var dd: float = S.map.path_dist(t.pos())
		var p: Vector2 = _closest_path_point(t.pos())
		h.x = p.x
		h.y = p.y
	else:
		h.x = -2000
		h.y = -2000
	var base := sc.replace("_block", "")
	var dur := 30.0
	var wave := 15
	S.wave = wave
	if base == "bosswalk":
		g.spawn("warden", 0.0)
		var e = S.enemies[-1]
		e.hp *= 1000
		e.max *= 1000
		e.pow_t = 1e9
	if base == "boss":
		g.spawn("warden", _closest_d(t.pos()))
		var e = S.enemies[-1]
		e.hp *= 1000
		e.max *= 1000
		if not block:
			e.speed = 0
		e.pow_t = 1e9
		dur = 30.0
	t.dmg_total = 0
	for r in refs:
		r.dmg_total = 0
	var q := []
	if base == "swarm":
		S.wave = 30
		q = ["grunt", 60, 0.25, 4.0]
	elif base == "armored":
		S.wave = 25
		q = ["bastion", 20, 1.0, 2.0]
	elif base == "fast":
		S.wave = 30
		q = ["runner", 60, 0.25, 4.0]
	var spawned := 0
	var st := 0.0
	var time := 0.0
	while time < 45.0 if (q.size() or base == "bosswalk") else time < dur:
		if q.size() and spawned < q[1]:
			st -= DT
			if st <= 0:
				st = q[2]
				g.spawn(q[0], 0.0)
				S.enemies[-1].hp *= q[3]
				S.enemies[-1].max *= q[3]
				spawned += 1
		S.pending_levels = 0
		S.pending_heroic = 0
		S.pending_boon = ""
		S.need_shop = false
		S.need_choice = false
		S.paused = false
		S.hero.xp = 0
		g.update(DT)
		time += DT
		if base.begins_with("boss"):
			for e in S.enemies:
				if e.boss:
					e.pow_t = 1e9
	var tot: float = t.dmg_total
	for r in refs:
		tot += r.dmg_total
	if base == "boss":
		return tot / dur
	return tot


func _closest_d(p: Vector2) -> float:
	var best := 0.0
	var bd := 1e9
	var d := 0.0
	while d < S.map.path_len:
		var q: Vector2 = S.map.pos_at(d, 0)
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = d
		d += 3.0
	return best


func _closest_path_point(p: Vector2) -> Vector2:
	return S.map.pos_at(_closest_d(p), 0)
