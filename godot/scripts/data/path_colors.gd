## Tag colours for tower paths, shared by the path buttons and the live 3D accent masks.
## Edit the colours in res://data/path_colors.tres. A path's own `color` (alpha above 0) replaces its tag.
##
## for_tower() returns 3 colours in the order the paths were invested (Tower.order). Fewer than 3 paths
## are padded with the tower's own colour. The 4th path (Oracle) still has a swatch; the mask only has 3 zones.
## Two chosen paths with the same tag are shifted lighter or darker by that path's index in the tower's list,
## so they stay distinct. The shift is SHADE[index]: index 0 darkest, index 4 lightest.
@tool
class_name PathColors
extends Resource

const PATH := "res://data/path_colors.tres"
const TAGS: Array[String] = ["power", "speed", "burst", "burn", "slow", "chain", "precision", "arcane", "multi"]
## Lightness added to a shared tag, by the path's index in the tower's path list (0-4).
const SHADE: Array[float] = [-0.20, -0.10, 0.0, 0.12, 0.24]

@export var power := Color("#FF4A4A")
@export var speed := Color("#FFD84A")
@export var burst := Color("#FF8A2E")
@export var burn := Color("#FF5A1F")
@export var slow := Color("#6EC8FF")
@export var chain := Color("#3CF0FF")
@export var precision := Color("#E6D8FF")
@export var arcane := Color("#FF4FC0")
@export var multi := Color("#6CF07A")

static var _data: PathColors
static var _game: Game


static func data() -> PathColors:
	if _data == null:
		_data = load(PATH) as PathColors
	if _data == null:
		_data = PathColors.new()
	return _data


func of(tag: String) -> Color:
	if tag in TAGS:
		return get(tag)
	return power


static func of_tag(tag: String) -> Color:
	return data().of(tag)


## The colour a path shows on its own (codex, build tip): the override, or the tag colour, unshaded.
static func of_path(p: TowerPath) -> Color:
	if p.color.a > 0.001:
		return p.color
	return of_tag(p.tag)


## 3 colours in investment order. Empty slots are the tower's base colour.
static func for_tower(t: Tower) -> Array[Color]:
	var map := _color_map(t, t.order)
	var out: Array[Color] = []
	for id in t.order:
		if out.size() == 3:
			break
		out.append(map.get(id, t.color))
	while out.size() < 3:
		out.append(t.color)
	return out


## The swatch for one path option. A path not yet bought is coloured as it will be once it is.
static func for_path(t: Tower, id: String) -> Color:
	var ids: Array = []
	for x in t.order:
		ids.append(x)
	if not ids.has(id):
		ids.append(id)
	return _color_map(t, ids).get(id, t.color)


static func tag_of(t: Tower, o: Dictionary) -> String:
	if o.get("path"):
		return o.path.tag
	var f = o.get("fusion")
	if f and f.tags.size():
		return String(f.tags[0])
	return "power"


static func _color_map(t: Tower, ids: Array) -> Dictionary:
	var cat := _catalog(t)
	var counts := {}
	for id in ids:
		if not cat.has(id):
			continue
		var tag: String = cat[id].tag
		counts[tag] = int(counts.get(tag, 0)) + 1
	var map := {}
	for id in ids:
		if not cat.has(id) or map.has(id):
			continue
		var e: Dictionary = cat[id]
		var c: Color = e.override
		if c.a <= 0.001:
			c = data().of(e.tag)
			if int(counts.get(e.tag, 0)) >= 2:
				c = _shade(c, int(e.index))
		map[id] = c
	return map


static func _shade(base: Color, index: int) -> Color:
	var o: float = SHADE[clampi(index, 0, SHADE.size() - 1)]
	if o < 0.0:
		return base.darkened(-o)
	if o > 0.0:
		return base.lightened(o)
	return base


static func _catalog(t: Tower) -> Dictionary:
	var out := {}
	if t.hybrid:
		for i in t.fusions.size():
			var f: FusionData = t.fusions[i]
			var tag := "power"
			if f.tags.size():
				tag = String(f.tags[0])
			out[f.id] = {tag = tag, index = i, override = Color(0, 0, 0, 0)}
		return out
	var paths: Array = []
	var g := _find_game()
	if g:
		paths = g.tower_paths(t.type)
	elif DB.towers.has(t.type):
		paths = DB.towers[t.type].paths
	for i in paths.size():
		var p: TowerPath = paths[i]
		out[p.id] = {tag = p.tag, index = i, override = p.color}
	return out


static func _find_game() -> Game:
	if _game and is_instance_valid(_game):
		return _game
	_game = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_game = _scan(tree.root)
	return _game


static func _scan(n: Node) -> Game:
	if n is Game:
		return n
	for c in n.get_children():
		var g := _scan(c)
		if g:
			return g
	return null
