## An enemy's picture for the new-enemy window: its 3D model live (walking, facing the viewer) when the type has one
## (EnemyData.model_dir), else the disc the board draws for it, big, with its armor, boss and anchor rings.
class_name EnemyPic
extends Control

var d: EnemyData
var tex: TextureRect


static func make(data: EnemyData, px := 132.0) -> EnemyPic:
	var p := EnemyPic.new()
	p.d = data
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Enemy3D.has_model(data):
		var live := Enemy3D.new()
		p.add_child(live)
		live.setup(data.model_dir, data.radius)
		live.visible = false # only its render is shown, as this picture's texture
		live.vp.size = live.vp.size * 4 # the same framing, sharper
		live.yaw = live._face(Vector2(0.35, 1.0))
		live.model.rotation.y = live.yaw
		live.play("walk", 0.8, 0.0)
		p.tex = TextureRect.new()
		p.clip_contents = true
		# the render leaves room for a swung tail and the death fall: zoom in on the body
		p.tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		var z := px * 0.55
		p.tex.offset_left = -z
		p.tex.offset_right = z
		p.tex.offset_top = -z * 1.3
		p.tex.offset_bottom = z * 0.7
		p.tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		p.tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p.tex.texture = live.vp.get_texture()
		p.tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		p.add_child(p.tex)
	return p


func _draw() -> void:
	# a soft floor glow behind either kind
	var c := size / 2
	var r := minf(size.x, size.y) * 0.42
	draw_circle(c + Vector2(0, r * 0.1), r, Color(d.color, 0.12))
	if tex:
		return
	# the board's disc, scaled up: bigger types stay bigger
	var er := r * clampf(d.radius / 14.0, 0.45, 0.9)
	var al := 0.45 if d.phase else 1.0
	draw_circle(c, er + 3, Color(0.063, 0.071, 0.137, al))
	draw_circle(c, er, Color(d.color, al))
	draw_circle(c - Vector2(er, er) * 0.35, er * 0.35, Color(1, 1, 1, 0.15 if d.phase else 0.35))
	if d.armor > 0:
		draw_arc(c, er, 0, TAU, 48, Color("#b8c0d8", 0.85), 2 + d.armor * 16)
	if d.boss:
		draw_arc(c, er + 8, 0, TAU, 64, Color("#f2c14e"), 4)
	elif d.pushback_immune:
		draw_arc(c, er + 6, 0, TAU, 64, Color("#3a4256", 0.95), 6)
