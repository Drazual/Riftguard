class_name Live3D
extends Node2D
## The board's one shared live 3D layer (the unified art style, StyleSettings / StyleRig): every live 3D model on the
## board (heroes, towers that have a model, wizard walls, Gale's beam and Air Strike) is drawn by ONE orthographic
## camera at the scenery's own angle into ONE low-resolution, transparent SubViewport, lit by one key light with the
## palette's shadows, and that picture is laid over the board's 2D world (between the depth-sorted units and the
## overlays), pixel for pixel with the scenery at res_scale 2. It is a child of the board's world, so zoom, pan and
## shake move it with everything else.
##
## Depth: the 2D sprites under it (buildings, props, enemies, towers without a model) get "cut-outs": upright planes
## standing on their ground line in the 3D world, shaped like the sprite, that clear the 3D picture wherever the
## sprite stands in front of a model, so it shows through. That is the board's y-sort, per pixel.
##
## Board world coordinates (Board.world's units) map to the art pixels StyleRig works in by PER.

const PER := Board.PX * 2.0 # art pixels (the whole board's 1536x832) per board world unit
const VIEW := Vector2(Board.W, Board.VH) # the board's world, in its units
const COMPOSITE := """
shader_type canvas_item;
render_mode blend_premul_alpha;
// the 3D picture's colour is already multiplied by its alpha (drawn over a clear background), and glow adds light
// around bright parts where the alpha stays clear
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
"""

var settings: StyleSettings
var vp: SubViewport
var rig: StyleRig
var pic: Sprite2D
var f := 2 # the board's art resolution (Board.F): 2 for the painted maps, 1 for the pixel-art ones
var _cuts := {} # 2D node -> its cut-out


func _init(s: StyleSettings) -> void:
	settings = s
	name = "Live3D"
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED # the pixel finish comes from the low-res grid
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	rig = StyleRig.new(settings, true)
	vp.add_child(rig)
	pic = Sprite2D.new()
	pic.centered = false
	pic.texture = vp.get_texture()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = COMPOSITE
	m.shader = sh
	pic.material = m
	add_child(pic)
	_size()


## The render's size: res_scale x the board's base 768x416, matched to the board's own art resolution (F = 1 maps
## are drawn at 768x416, so the render is halved there to stay one render pixel per board pixel).
func _size() -> void:
	var want := Vector2i((StyleRig.BASE * settings.res_scale * f / 2.0).round())
	want = want.max(Vector2i(64, 32))
	if vp.size != want:
		vp.size = want
	pic.scale = VIEW / Vector2(vp.size)


func set_res(board_f: int) -> void:
	f = board_f
	_size()
	rig.apply()


## Pushes the settings in (after a change in the Settings menu).
func apply() -> void:
	_size()
	rig.apply()


## Board world point -> art pixel, and the ground under it.
func ground(p: Vector2) -> Vector3:
	return rig.art_to_ground(p * PER)


## Where a 3D point shows on the board, in world units.
func to_world(w: Vector3) -> Vector2:
	return rig.world_to_art(w) / PER


## Puts a model's anchor on the board world point `p` (its feet), on the render's pixel grid.
func place(anchor: Node3D, p: Vector2) -> void:
	rig.place_art(anchor, p * PER)


## The turn, in a turned anchor's frame (x right on screen, +z toward the viewer), that faces a direction on the board
## (x right, y down the screen, as drawn).
static func face(screen: Vector2) -> float:
	var g := Vector2(screen.x, screen.y / sin(deg_to_rad(StyleRig.PITCH)))
	return atan2(g.x, g.y)


static var _dirs := {}
## The art_src folder a tower's baked turret came from (its tower.json "out" is the turret's file name), or "".
static func tower_dir(d: TowerData) -> String:
	if d == null or d.turret == null:
		return ""
	var out := d.turret.resource_path.get_file().get_basename()
	if _dirs.is_empty():
		_dirs[""] = ""
		for f in DirAccess.get_directories_at("res://art_src/towers"):
			var p := "res://art_src/towers/%s/tower.json" % f
			if FileAccess.file_exists(p):
				var c = JSON.parse_string(FileAccess.get_file_as_string(p))
				if c is Dictionary and c.has("model"):
					_dirs[c.get("out", f)] = "res://art_src/towers/" + f
	return _dirs.get(out, "")


# ---------- cut-outs ----------
## Gives a 2D sprite in the board's depth-sorted layer a cut-out, so the 3D models behind it are hidden by it.
## Sprite2D and AnimatedSprite2D use their own picture (uncentred, as the board draws them). Anything else is a
## disc: radius r around a point `lift` world units over its feet (an enemy's body).
## feet: the node whose position is its ground line (a sprite nested under a hero's node), else the sprite's own.
func cut(n: Node2D, r := 0.0, lift := 0.0, feet: Node2D = null) -> void:
	if _cuts.has(n):
		var c: Dictionary = _cuts[n]
		c.r = r
		c.lift = lift
		return
	_cuts[n] = { mi = rig.add_cutout("Cut_" + String(n.name)), r = r, lift = lift, key = Vector4.INF, feet = feet }


## Moves every cut-out to its sprite (call once a frame, after the board has placed them).
func sync_cuts() -> void:
	for n in _cuts.keys():
		var c: Dictionary = _cuts[n]
		var mi: MeshInstance3D = c.mi
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			mi.queue_free()
			_cuts.erase(n)
			continue
		mi.visible = n.is_visible_in_tree()
		if not mi.visible:
			continue
		var tex: Texture2D = null
		var off := Vector2.ZERO
		if n is Sprite2D:
			tex = n.texture
			off = n.offset
		elif n is AnimatedSprite2D:
			var a: AnimatedSprite2D = n
			if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
				tex = a.sprite_frames.get_frame_texture(a.animation, a.frame)
			off = a.offset
		var r: Rect2
		var region := Rect2(0, 0, 1, 1)
		# the sprite in the board world's units (it can sit under a scaled parent, like a hero's picture)
		var xf: Transform2D = (get_parent() as Node2D).get_global_transform().affine_inverse() * n.get_global_transform()
		var feet: Node2D = c.feet if c.feet and is_instance_valid(c.feet) else n
		var foot_y: float = feet.position.y if feet != n else xf.origin.y
		if tex:
			var sz := tex.get_size()
			r = Rect2(xf * off, sz * xf.get_scale())
			if tex is AtlasTexture:
				var at: AtlasTexture = tex
				var full := at.atlas.get_size()
				region = Rect2(at.region.position / full, at.region.size / full)
				tex = at.atlas
		else:
			var rr: float = c.r
			r = Rect2(n.position + Vector2(-rr, -c.lift - rr), Vector2(rr, rr) * 2)
		var key := Vector4(r.position.x, r.position.y, r.size.x + foot_y, r.size.y)
		if key == c.key and tex == c.get("tex"):
			continue
		c.key = key
		c.tex = tex
		rig.set_cutout(mi, Rect2(r.position * PER, r.size * PER), foot_y * PER, tex, region)


# ---------- towers ----------
## A tower drawn live from its 3D model (art_src/towers/<dir>/tower.json, the same file tools/render_tower.gd bakes
## its sprites from): the turret turns to any angle, the fire clip plays as it shoots, and shots leave its Muzzle.
class LiveTower extends Node2D:
	var live: Live3D
	var cfg: Dictionary
	var model: Node3D
	var anchor: Node3D
	var ap: AnimationPlayer
	var yaw_node: Node3D
	var pitch_node: Node3D
	var muzzle: Node3D
	var idle := ""
	var fire := ""
	var yaw := 0.0
	var want_yaw := 0.0
	var accent_mask: Texture2D
	var accent_mask_b: Texture2D
	var _asig := ""

	## dir: the tower's art_src folder. k: the baked sprite's scale on the board, in world units per frame pixel
	## (TowerData.turret_scale / Board.PX): the model shows as wide as the sprite did (tower.json "wide" pixels).
	func setup(l: Live3D, dir: String, k: float) -> void:
		live = l
		cfg = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tower.json")))
		model = (load(dir.path_join(cfg.model)) as PackedScene).instantiate()
		_arm(float(cfg.get("wide", 60.0)) * k, 1.0, true)
		_load_masks(dir.path_join(String(cfg.model)))

	## A hybrid or super GLB. cfg_in is the folder's tower.json (or {}). extra_scale is 1.15 when a super reuses
	## a hybrid model. False when the file does not load; the board then keeps the placeholder.
	func setup_merge(l: Live3D, glb: String, cfg_in: Dictionary, wide: float, extra_scale: float) -> bool:
		live = l
		model = MergeArt.instantiate(glb)
		if model == null:
			return false
		cfg = cfg_in.duplicate(true)
		_fill_cfg()
		_arm(wide, extra_scale, false)
		_load_masks(glb)
		return true

	func _fill_cfg() -> void:
		if str(cfg.get("yaw", "")) == "":
			var yaw_n := _named(["Yaw", "Turret"])
			cfg["yaw"] = str(model.get_path_to(yaw_n)) if yaw_n else ""
		if str(cfg.get("pitch", "")) == "":
			var pitch_n := _named(["Pitch", "Gun", "Barrel"])
			cfg["pitch"] = str(model.get_path_to(pitch_n)) if pitch_n else ""
		if str(cfg.get("muzzle", "")) == "":
			var muz_n := _named(["Muzzle", "BuffPoint"])
			cfg["muzzle"] = muz_n.name if muz_n else "Muzzle"
		if not cfg.get("anims") is Dictionary:
			cfg["anims"] = {"idle": "idle", "fire": "fire"}

	func _named(names: Array) -> Node:
		for n in names:
			var found := model.find_child(String(n), true, false)
			if found:
				return found
		return null

	## force_aim: base towers always pose the pitch node from tower.json "aim" (0 when it has none).
	func _arm(wide: float, extra_scale: float, force_aim: bool) -> void:
		var yaw_path := str(cfg.get("yaw", ""))
		var pitch_path := str(cfg.get("pitch", ""))
		yaw_node = model.get_node_or_null(NodePath(yaw_path)) if yaw_path != "" else null
		pitch_node = model.get_node_or_null(NodePath(pitch_path)) if pitch_path != "" else null
		muzzle = model.find_child(str(cfg.get("muzzle", "Muzzle")), true, false)
		ap = model.find_child("AnimationPlayer", true, false)
		anchor = live.rig.add_model(model, 0.55, true)
		if muzzle and cfg.has("muzzle_scale"):
			muzzle.scale *= float(cfg.muzzle_scale)
		var anims: Dictionary = cfg.get("anims", {})
		idle = str(anims.get("idle", ""))
		fire = str(anims.get("fire", ""))
		if ap:
			# the game turns and tilts the turret: the clips' own yaw and pitch keys are dropped (as the baker does)
			for lib_name in ap.get_animation_library_list():
				var lib: AnimationLibrary = ap.get_animation_library(lib_name).duplicate(true)
				ap.remove_animation_library(lib_name)
				ap.add_animation_library(lib_name, lib)
				for a in lib.get_animation_list():
					var anim := lib.get_animation(a)
					for ti in range(anim.get_track_count() - 1, -1, -1):
						var path := String(anim.track_get_path(ti)).get_slice(":", 0)
						if path == str(cfg.get("yaw", "-")) or path == str(cfg.get("pitch", "-")):
							anim.remove_track(ti)
			if fire == "" or not ap.has_animation(fire):
				if ap.has_animation("fire"):
					fire = "fire"
				elif ap.has_animation("attack"):
					fire = "attack"
			if idle == "" or not ap.has_animation(idle):
				if ap.has_animation("idle"):
					idle = "idle"
			if idle != "" and ap.has_animation(idle):
				ap.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
				ap.play(idle)
			if fire != "" and ap.has_animation(fire) and fire != idle:
				ap.get_animation(fire).loop_mode = Animation.LOOP_NONE
		if pitch_node and (force_aim or cfg.has("aim")):
			pitch_node.rotation = Vector3(float(cfg.get("aim", 0.0)), 0, 0)
		yaw = PI * 0.0 # facing the camera (+z), the towers' resting facing
		want_yaw = yaw
		_turn()
		_fit(wide)
		if not is_equal_approx(extra_scale, 1.0):
			model.scale *= extra_scale

	func _load_masks(glb: String) -> void:
		accent_mask = MergeArt.load_mask(glb, "_accent_mask.png", model, "accent_mask")
		accent_mask_b = MergeArt.load_mask(glb, "_accent_mask_b.png", model, "accent_mask_b")

	## The tower's own 3 path colours, in investment order. No mask: the material is left exactly as stylize made it.
	func set_path_colors(colors: Array) -> void:
		set_accents(colors, [], Color.WHITE, 0.0)

	## parent_cols: [parent A colours, parent B colours]. body: the recipe colour, mixed over the albedo.
	func set_merge_look(parent_cols: Array, body: Color) -> void:
		var a: Array = parent_cols[0] if parent_cols.size() > 0 and parent_cols[0] is Array else []
		var b: Array = parent_cols[1] if parent_cols.size() > 1 and parent_cols[1] is Array else []
		set_accents(a, b, body, MergeArt.BODY)

	func set_accents(a: Array, b: Array, body: Color, strength: float) -> void:
		if model == null or live == null:
			return
		if accent_mask == null and accent_mask_b == null and strength <= 0.0:
			return
		var sig := _cols_sig(a) + "/" + _cols_sig(b) + "/" + body.to_html() + "/" + str(snappedf(strength, 0.001))
		if sig == _asig:
			return
		_asig = sig
		var fill := body if strength > 0.0 else Color.WHITE
		live.rig.set_accents(model, accent_mask, _triplet(a, fill), accent_mask_b, _triplet(b, fill), body, strength)

	func _cols_sig(cols: Array) -> String:
		var s := ""
		for c in cols:
			if c is Color:
				s += (c as Color).to_html()
		return s

	func _triplet(cols: Array, fallback: Color) -> Array[Color]:
		var out: Array[Color] = []
		for c in cols:
			if c is Color:
				out.append(c)
			if out.size() == 3:
				break
		while out.size() < 3:
			out.append(fallback)
		return out

	## Scales the model so its base shows `wide` world units across facing the camera, as the baked sprites do.
	func _fit(wide: float) -> void:
		var lo := INF
		var hi := -INF
		for n in model.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			if not mi.is_visible_in_tree() or mi.mesh == null:
				continue
			var xf := mi.global_transform
			var b := mi.get_aabb()
			for i in 8:
				var x := live.to_world(xf * b.get_endpoint(i)).x
				lo = minf(lo, x)
				hi = maxf(hi, x)
		if hi > lo:
			model.scale *= wide / (hi - lo)

	func _turn() -> void:
		if yaw_node:
			yaw_node.rotation = Vector3(0, yaw, 0)

	## Turns the turret toward a direction on the board as drawn (x right, y down the screen).
	func aim(screen: Vector2) -> void:
		if screen.length() > 0.5:
			want_yaw = Live3D.face(screen)

	func shoot() -> void:
		if ap and ap.has_animation(fire):
			ap.play(fire, 0.05)
			ap.seek(0.0, true)
			if fire != idle and ap.has_animation(idle):
				ap.queue(idle)

	func set_speed(s: float) -> void:
		if ap:
			ap.speed_scale = s

	## Where shots leave, in board world units.
	func muzzle_at() -> Vector2:
		return live.to_world(muzzle.global_position) if muzzle else position + Vector2(0, -14)

	func _process(dt: float) -> void:
		yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-dt * 14.0))
		_turn()
		anchor.visible = is_visible_in_tree()
		live.place(anchor, position)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and anchor and is_instance_valid(anchor):
			anchor.queue_free()
