extends SceneTree
# One-time generator: builds the SpriteFrames for towers, heroes and spell effects from their sheets
# and links them in the data files. Run: godot --headless --path . -s res://tools/make_art.gd


func _init() -> void:
	for id in ["anvil", "arcane", "beacon", "disc", "frost", "laser", "mortar", "plasma", "tesla"]:
		_tower(id)
	for id in ["oracle", "sniper", "striker", "vanguard", "wizard"]:
		_hero(id)
	_fx()
	quit()


func _frame(tex: Texture2D, i: int, cols: int, w: int, h: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2((i % cols) * w, (i / cols) * h, w, h)
	return a


func _anim(sf: SpriteFrames, tex: Texture2D, name: String, frames: Array, fps: float, loop: bool, cols := 6, w := 48, h := 48) -> void:
	sf.add_animation(name)
	sf.set_animation_speed(name, fps)
	sf.set_animation_loop(name, loop)
	for f in frames:
		sf.add_frame(name, _frame(tex, f, cols, w, h))


func _tower(id: String) -> void:
	var tex: Texture2D = load("res://assets/towers/%s.png" % id)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	_anim(sf, tex, "idle", range(0, 6), 8, true)
	_anim(sf, tex, "attack", range(6, 12), 24, false)
	_anim(sf, tex, "recover", range(12, 18), 16, false)
	_anim(sf, tex, "shot", [18], 1, false)
	_anim(sf, tex, "fx", range(18, 24), 24, false)
	_anim(sf, tex, "hit", range(19, 24), 20, false)
	if id == "laser":
		_anim(sf, tex, "beam", [20, 21, 22, 21], 16, true)
	var path := "res://art/towers/%s.tres" % id
	ResourceSaver.save(sf, path)
	var d: TowerData = load("res://data/towers/%s.tres" % id)
	d.frames = load(path)
	ResourceSaver.save(d)


func _hero(id: String) -> void:
	var tex: Texture2D = load("res://assets/heroes/%s.png" % id)
	var d: HeroData = load("res://data/heroes/%s.tres" % id)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fire_rows := [6, 7, 8, 9] if d.spells else [7, 8, 9]
	for face in 8:
		_anim(sf, tex, "idle_%d" % face, [0, 1].map(func(r): return r * 8 + face), 3, true, 8)
		_anim(sf, tex, "walk_%d" % face, [2, 3, 4, 5].map(func(r): return r * 8 + face), 9, true, 8)
		_anim(sf, tex, "fire_%d" % face, fire_rows.map(func(r): return r * 8 + face), 12, false, 8)
	var path := "res://art/heroes/%s.tres" % id
	ResourceSaver.save(sf, path)
	d.frames = load(path)
	ResourceSaver.save(d)


func _fx() -> void:
	var tex: Texture2D = load("res://assets/fx/fx_spells.png")
	var names := ["fireball", "frostburst", "stonewall", "gust", "gfireball", "deepfreeze", "greatwall", "cyclone", "torrent", "meteor",
		"firestorm", "quagmire", "blizzard", "sandstorm", "inferno", "abszero", "runeA", "quake", "runeB", "tempest"]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in names.size():
		_anim(sf, tex, names[row], range(row * 8, row * 8 + 8), 13, false, 8, 128, 116)
	ResourceSaver.save(sf, "res://art/fx/spells.tres")
