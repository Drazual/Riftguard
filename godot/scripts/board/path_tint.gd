class_name PathTint
extends RefCounted
## Path colours on the base (non-merged) towers. Each base model has <model>_accent_mask.png next to its GLB (UV0;
## R = zone 1 trim, G = zone 2 glow + emission, B = zone 3 details; the same convention as the merges,
## docs/merge-art.md). The baked turret sprites carry the same zones in res://assets/towers/<out>_mask.png, baked by
## tools/render_tower.gd "mask" into the colour sheet's exact layout, so one canvas shader recolours any frame.
## The Rift Beacon draws live (Beacon3D), so its body material is swapped for the spatial version instead.
## A zone takes its path's colour once that path is bought (the 1st, 2nd and 3rd path invested, PathColors.for_tower);
## until then it keeps the model's own colours, so an unupgraded tower looks exactly as before.
## Pure visuals: the board calls sprite() / Beacon3D.set_path_colors() every sync; the work is skipped until the
## colours change, so buying a path recolours the tower live.

const CANVAS := """
shader_type canvas_item;
// tower_pixel.gdshader's chunky 1x look (one sample per block x block screen block), plus the path colours
uniform float block = 1.0;
uniform sampler2D mask_tex : filter_linear;
uniform vec4 trim = vec4(1.0, 1.0, 1.0, 0.0); // a = 1 once the zone's path is bought
uniform vec4 glow = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 detail = vec4(1.0, 1.0, 1.0, 0.0);
uniform float glow_add = 0.3;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 mid = (floor(FRAGCOORD.xy / block) + 0.5) * block;
	vec2 per_px = vec2(dFdx(UV.x), dFdy(UV.y));
	vec2 uv = UV + (mid - FRAGCOORD.xy) * per_px;
	vec4 base = texture(TEXTURE, uv);
	vec4 m = texture(mask_tex, uv);
	vec3 w = m.rgb * m.a * vec3(trim.a, glow.a, detail.a);
	// a zone keeps a shade of the pixel under it, so the paint still has the model's shading and detail
	float sh = 0.30 + 1.25 * dot(base.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = base.rgb;
	c = mix(c, trim.rgb * sh, w.r);
	c = mix(c, detail.rgb * sh, w.b);
	c = mix(c, glow.rgb * sh, w.g);
	c += glow.rgb * w.g * glow_add; // the glow zone stays lit
	COLOR = vec4(min(c, vec3(1.0)), base.a) * tint;
}
"""

const SPATIAL := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear, repeat_enable;
uniform bool has_normal = false;
uniform bool has_orm = false;
uniform bool has_emission = false;
uniform float emission_energy = 1.0;
uniform vec4 trim : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 glow : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 detail : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float glow_energy = 2.0;
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	vec4 m = texture(mask_tex, UV);
	vec3 w = m.rgb * vec3(trim.a, glow.a, detail.a);
	float sh = 0.30 + 1.25 * dot(base, vec3(0.2126, 0.7152, 0.0722));
	vec3 c = base;
	c = mix(c, trim.rgb * sh, w.r);
	c = mix(c, detail.rgb * sh, w.b);
	c = mix(c, glow.rgb * sh, w.g);
	ALBEDO = c;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	if (has_orm) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ROUGHNESS = orm.g;
		METALLIC = orm.b;
	} else {
		ROUGHNESS = 0.6;
	}
	vec3 baked = has_emission ? texture(emission_tex, UV).rgb * emission_energy : vec3(0.0);
	EMISSION = baked * (1.0 - w.g) + glow.rgb * w.g * glow_energy;
}
"""

static var _canvas: Shader
static var _spatial: Shader
static var _masks := {} # sheet name -> its mask Texture2D, or null when there is none


## The tower's 3 zone colours: path colours in investment order, alpha 0 for a zone whose path isn't bought yet.
static func colors(t: Tower) -> Array[Color]:
	var cols := PathColors.for_tower(t)
	var n := mini(3, t.order.size())
	for i in 3:
		cols[i].a = 1.0 if i < n else 0.0
	return cols


## A baked turret sprite (AnimatedSprite2D of TowerData.turret): binds its mask sheet the first time (in place of
## the board's tower_px, whose chunky look this shader keeps: block is the board's F), then pushes the tower's
## colours when they change. No mask sheet: the sprite is left exactly as it was.
static func sprite(s: CanvasItem, d: TowerData, t: Tower, block: float) -> void:
	if d == null or d.turret == null:
		return
	var out := d.turret.resource_path.get_file().get_basename()
	if not _masks.has(out):
		_masks[out] = MergeArt.load_tex("res://assets/towers/%s_mask.png" % out)
	var mask: Texture2D = _masks[out]
	if mask == null:
		return
	if not s.has_meta("tint_on"):
		if _canvas == null:
			_canvas = Shader.new()
			_canvas.code = CANVAS
		var m := ShaderMaterial.new()
		m.shader = _canvas
		m.set_shader_parameter("mask_tex", mask)
		s.material = m
		s.remove_meta("tint_sig")
		s.set_meta("tint_on", true)
		s.set_meta("tint_block", -1.0)
	if float(s.get_meta("tint_block")) != block:
		s.set_meta("tint_block", block)
		(s.material as ShaderMaterial).set_shader_parameter("block", block)
	push([s.material], s, colors(t))


## Swaps every atlas-textured surface under root for the spatial recolour material (one per source material) and
## returns them; the mask is <glb>_accent_mask.png. Empty when there's no mask (the model is left as it was).
static func spatial(root: Node, glb: String) -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var mask := MergeArt.load_mask(glb, "_accent_mask.png", root, "accent_mask")
	if mask == null:
		return mats
	if _spatial == null:
		_spatial = Shader.new()
		_spatial.code = SPATIAL
	var made := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as StandardMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			if not made.has(src):
				var m := ShaderMaterial.new()
				m.shader = _spatial
				m.set_shader_parameter("albedo_tex", src.albedo_texture)
				m.set_shader_parameter("mask_tex", mask)
				if src.normal_enabled and src.normal_texture:
					m.set_shader_parameter("normal_tex", src.normal_texture)
					m.set_shader_parameter("has_normal", true)
				var orm: Texture2D = src.roughness_texture if src.roughness_texture else src.metallic_texture
				if orm:
					m.set_shader_parameter("orm_tex", orm)
					m.set_shader_parameter("has_orm", true)
				if src.emission_enabled and src.emission_texture:
					m.set_shader_parameter("emission_tex", src.emission_texture)
					m.set_shader_parameter("has_emission", true)
					m.set_shader_parameter("emission_energy", src.emission_energy_multiplier)
				made[src] = m
				mats.append(m)
			mi.set_surface_override_material(i, made[src])
	return mats


## Pushes the 3 zone colours onto materials, once per change (holder keeps the last signature in its meta).
static func push(mats: Array, holder: Object, cols: Array[Color]) -> void:
	var sig := _sig(cols)
	if str(holder.get_meta("tint_sig", "")) == sig:
		return
	holder.set_meta("tint_sig", sig)
	for m: ShaderMaterial in mats:
		m.set_shader_parameter("trim", cols[0])
		m.set_shader_parameter("glow", cols[1])
		m.set_shader_parameter("detail", cols[2])


static func _sig(cols: Array[Color]) -> String:
	var s := ""
	for c in cols:
		s += c.to_html(true)
	return s
