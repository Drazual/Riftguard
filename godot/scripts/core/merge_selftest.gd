## Checks every merge model in a real run, in the editor (tests/merge_models.tscn) or in a built game
## (Riftguard.exe -- --merge-selftest). For each of the 7 recipes it maxes two parents along different paths, merges
## them, and checks: MergeArt finds the recipe's GLB, the board draws it through Merge3D (not the plinth), both accent
## masks load, the colours start as the parents' paths, and picking 1, 2 and 3 fusions moves the glow, trim and
## detail to those paths' colours (the most points lead, ties to the one picked first).
## Prints "MERGE SELFTEST <recipe> PASS|FAIL ..." per recipe and "MERGE SELFTEST DONE fails=N", then quits (code 1 on
## any failure).
class_name MergeSelftest
extends Node

const RECIPES := {
	"arcane+frost": "rimeshard.glb",
	"arcane+laser": "prism_lance.glb",
	"arcane+tesla": "railgun.glb",
	"frost+tesla": "cryo_coil.glb",
	"frost+plasma": "cryo_cannon.glb",
	"mortar+plasma": "bombard.glb",
	"plasma+tesla": "ion_storm.glb",
}
## Two runs cover all 7 recipes (a run carries 4 tower types).
const RUNS := [
	["arcane", "frost", "laser", "tesla"],
	["plasma", "mortar", "frost", "tesla"],
]

var main: Main
var fails := 0
var quit_when_done := true


static func wanted() -> bool:
	return OS.get_cmdline_user_args().has("--merge-selftest")


func _ready() -> void:
	get_tree().create_timer(600).timeout.connect(func():
		print("MERGE SELFTEST TIMEOUT")
		get_tree().quit(1))
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _close(g: Game) -> void:
	for i in 20:
		main.ui.close_modal()
		if g.S != null:
			if g.S.pending_boon != "":
				g.take_boon()
			if g.S.paused and g.wave_opts.size() > 0:
				g.choose_mode(0)
		await get_tree().process_frame


func _run() -> void:
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	MergeArt.clear_cache()
	var g := main.game
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	var done := {}
	for loadout in RUNS:
		main.ui.menus.new_run("canal")
		main.ui.menus.start_run("gale", loadout)
		await _frames(10)
		await _close(g)
		g.S.gold = 9999999
		var spot_i := 0
		for key: String in RECIPES:
			if done.has(key):
				continue
			var pair := key.split("+")
			if not (loadout.has(pair[0]) and loadout.has(pair[1])):
				continue
			done[key] = true
			await _recipe(g, key, pair, spot_i)
			spot_i += 1
		g.end_run(false, true)
		await _close(g)
	for key in RECIPES:
		if not done.has(key):
			_line(key, false, "never tested")
	print("MERGE SELFTEST DONE fails=%d" % fails)
	if quit_when_done:
		get_tree().quit(1 if fails else 0)


func _line(key: String, ok: bool, why: String) -> void:
	print("MERGE SELFTEST %s %s %s" % [key, "PASS" if ok else "FAIL", why])
	if not ok:
		fails += 1


func _place(g: Game, type: String, d: float) -> Tower:
	var spot := g.pos_at(d)
	var best := Vector2i(-1, -1)
	for c in g.build_cells():
		if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
			best = c
	if best.x < 0:
		return null
	g.place_tower(best.x, best.y, type)
	return g.S.towers[g.S.towers.size() - 1]


## Levels t to the top, preferring its options from `start` on (so two parents take different paths).
func _max(g: Game, t: Tower, start: int) -> void:
	var guard := 0
	while t.lvl < g.R.max_level and guard < 30:
		guard += 1
		var opts := g.tower_options(t)
		var picked = null
		for k in opts.size():
			var o: Dictionary = opts[(start + k) % opts.size()]
			if g.path_state(t, o) == "open":
				picked = o
				break
		if picked == null:
			break
		g.level_tower(t, picked)


func _cols_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not (a[i] as Color).is_equal_approx(b[i]):
			return false
	return true


func _recipe(g: Game, key: String, pair: Array, i: int) -> void:
	var S := g.S
	var b := main.board
	var d0 := S.map.path_len * (0.25 + 0.12 * i)
	var ta := _place(g, pair[0], d0)
	var tb := _place(g, pair[1], d0 + 60)
	if ta == null or tb == null:
		_line(key, false, "could not place the parents")
		return
	_max(g, ta, 0)
	_max(g, tb, 2)
	var ca := PathColors.for_tower(ta)
	var cb := PathColors.for_tower(tb)
	if ta.order == tb.order:
		_line(key, false, "the parents took the same paths")
		return
	g.try_merge(tb, ta)
	await _frames(3)
	await _close(g)
	var m: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == key:
			m = t
	if m == null:
		_line(key, false, "the merge did not happen")
		return
	var spec := MergeArt.resolve(m)
	if spec.is_empty():
		_line(key, false, "MergeArt.resolve is empty (plinth)")
		return
	var want: String = RECIPES[key]
	if str(spec.glb).get_file() != want:
		_line(key, false, "wrong model %s (want %s)" % [spec.glb, want])
		return
	await _frames(4)
	var v = m.get_meta("view") if m.has_meta("view") else null
	if not (v is Merge3D) or not is_instance_valid(v) or not b._merge_model(m):
		_line(key, false, "no Merge3D view (the plinth is drawn)")
		return
	var view: Merge3D = v
	if view.mask_a == null or view.mask_b == null:
		_line(key, false, "a mask did not load (a %s, b %s)" % [view.mask_a != null, view.mask_b != null])
		return
	if view.mats.is_empty():
		_line(key, false, "no recolour material")
		return
	# the parents' colours, in recipe-key order: mask A is the first type, mask B the second
	var first_is_a: bool = pair[0] == ta.type
	var pa: Array = ca if first_is_a else cb
	var pb: Array = cb if first_is_a else ca
	var mat := view.mats[0]
	var look := func() -> Array:
		return [[mat.get_shader_parameter("a_trim"), mat.get_shader_parameter("a_glow"), mat.get_shader_parameter("a_detail")],
			[mat.get_shader_parameter("b_trim"), mat.get_shader_parameter("b_glow"), mat.get_shader_parameter("b_detail")]]
	var l0: Array = look.call()
	if not (_cols_eq(l0[0], pa) and _cols_eq(l0[1], pb)):
		_line(key, false, "the colours are not the parents' paths (%s vs %s / %s)" % [l0, pa, pb])
		return
	# picks: 1, 2 and 3 fusions, each moving into its zone; then a second point makes the 3rd one lead
	var opts := g.tower_options(m)
	var picks: Array = []
	for o in opts:
		if picks.size() < 3 and g.path_state(m, o) == "open":
			picks.append(o)
	if picks.size() < 3:
		_line(key, false, "fewer than 3 fusions to pick")
		return
	var tagc := func(o: Dictionary) -> Color: return PathColors.for_path(m, o.id)
	for n in 3:
		g.level_tower(m, picks[n])
		await _frames(2)
		await _close(g)
		var l: Array = look.call()
		var glow: Color = tagc.call(picks[0])
		var trim: Color = tagc.call(picks[1]) if n >= 1 else pa[0]
		var detail: Color = tagc.call(picks[2]) if n >= 2 else pa[2]
		var trim_b: Color = tagc.call(picks[1]) if n >= 1 else pb[0]
		var detail_b: Color = tagc.call(picks[2]) if n >= 2 else pb[2]
		if not (_cols_eq(l[0], [trim, glow, detail]) and _cols_eq(l[1], [trim_b, glow, detail_b])):
			_line(key, false, "after %d fusion(s) the colours are %s (want glow %s, trim %s, detail %s)" % [n + 1, l, glow, trim, detail])
			return
	if m.lvl < g.R.max_level and g.path_state(m, picks[2]) == "open":
		g.level_tower(m, picks[2])
		await _frames(2)
		await _close(g)
		var l: Array = look.call()
		if not (l[0][1] as Color).is_equal_approx(tagc.call(picks[2])):
			_line(key, false, "a second point did not move %s to the glow" % picks[2].id)
			return
	_line(key, true, "%s, masks a+b, parent colours, then %s / %s / %s" % [want, picks[0].id, picks[1].id, picks[2].id])
