class_name MapLight
extends RefCounted
## Blends the smooth 3D models (heroes, walls) and the baked sprites into the painted maps without changing how the
## models are drawn: three visual-only passes, all reading one light profile per map.
##  1. Lighting: models are lit like the painting (same upper-left key, warm sunlight, ambient and fill tinted by the
##     map's own shadow and neon colours) instead of neutral white studio light.
##  2. Ground: every unit's contact shadow is the map's painted shadow colour, soft-edged, instead of near-black.
##  3. Grade: one gentle colour pass over the whole board (scenery, sprites and models together): blacks lifted to
##     the map's darkest painted tone, a light tint toward its mid colour, a touch of bloom on bright neon.
## A map can tune its profile with a "light" block in its art layout (MapInfo.art); missing keys use DEFAULT.
## Save.settings.blend switches it (off = the plain look).

const DEFAULT := {
	# 1. the key light (direction matches the painting: lit from the upper left) and its colour
	"key_color": Color(1.0, 0.9, 0.8),
	"key_energy": 1.25,
	"key_rot": Vector3(-50, -35, 0),
	# ambient: the painting's shadows are mauve and lavender, never grey
	"ambient_color": Color(0.78, 0.66, 0.92),
	"ambient_energy": 0.9,
	# a neon fill from behind on the right, like the signs bouncing light onto everything
	"rim_color": Color(0.55, 0.85, 1.0),
	"rim_energy": 1.0,
	"rim_rot": Vector3(-20, 150, 0),
	# 2. contact shadows: the painted shadow colour and how strong
	"shadow_color": Color(0.24, 0.14, 0.36),
	"shadow_alpha": 0.5,
	# 3. the board grade
	"floor": Color(0.16, 0.1, 0.26), # what pure black becomes (the map's darkest painted tone)
	"lift": 0.55, # how far dark pixels move toward the floor (0 = untouched)
	"tint": Color(0.98, 0.78, 0.84), # the map's mid colour
	"tint_amount": 0.08,
	"bloom": 0.3, # extra glow on the brightest pixels
	"bloom_from": 0.8,
}


static func enabled() -> bool:
	return bool(Save.settings.get("blend", false))


## The light profile for a map (its art layout's "light" block over DEFAULT).
static func profile(art: Dictionary) -> Dictionary:
	var p := DEFAULT.duplicate()
	var over: Dictionary = art.get("light", {}) if art else {}
	for k in over:
		var v = over[k]
		if DEFAULT.get(k) is Color and v is String:
			v = Color(v)
		elif DEFAULT.get(k) is Vector3 and v is Array:
			v = Vector3(v[0], v[1], v[2])
		p[k] = v
	return p


## Replaces a model viewport's studio light (Hero3D.clean_light) with the map's light.
static func light(vp: Node, p: Dictionary) -> void:
	for n in vp.get_children():
		if n is WorldEnvironment or n is DirectionalLight3D:
			vp.remove_child(n)
			n.queue_free()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	# metal still needs something to reflect: a sky in the map's colours (not drawn, the background stays clear)
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = (p.ambient_color as Color).lerp(Color.WHITE, 0.3)
	sm.sky_horizon_color = (p.tint as Color)
	sm.ground_horizon_color = (p.tint as Color).darkened(0.3)
	sm.ground_bottom_color = (p.shadow_color as Color)
	var sky := Sky.new()
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient_color
	env.ambient_light_energy = p.ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = p.key_rot
	key.light_color = p.key_color
	key.light_energy = p.key_energy
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = p.rim_rot
	rim.light_color = p.rim_color
	rim.light_energy = p.rim_energy
	vp.add_child(rim)


const GRADE := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform vec3 floor_col = vec3(0.16, 0.1, 0.26);
uniform float lift = 0.55;
uniform vec3 tint = vec3(0.98, 0.78, 0.84);
uniform float tint_amount = 0.06;
uniform float bloom = 0.25;
uniform float bloom_from = 0.8;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// dark pixels slide toward the map's darkest painted tone, so a black model reads like the painted shadows
	float dark = 1.0 - smoothstep(0.0, 0.45, l);
	c = mix(c, max(c, floor_col + c * 0.6), dark * lift);
	// one shared tint over everything, scenery and models alike
	c = mix(c, c * tint * 1.12, tint_amount);
	// a soft glow from nearby bright pixels (a cheap blur from a lower mip level)
	vec3 b = textureLod(screen, SCREEN_UV, 2.5).rgb;
	float bl = dot(b, vec3(0.299, 0.587, 0.114));
	c += b * smoothstep(bloom_from, 1.0, bl) * bloom;
	COLOR = vec4(c, 1.0);
}
"""


## A full-board grade layer: a rect over the board world that reads what is drawn under it.
static func grade_rect(size: Vector2, p: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.name = "MapGrade"
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRADE
	m.shader = sh
	r.material = m
	set_grade(r, p)
	return r


static func set_grade(r: ColorRect, p: Dictionary) -> void:
	var m := r.material as ShaderMaterial
	var f: Color = p.floor
	var t: Color = p.tint
	m.set_shader_parameter("floor_col", Vector3(f.r, f.g, f.b))
	m.set_shader_parameter("lift", p.lift)
	m.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
	m.set_shader_parameter("tint_amount", p.tint_amount)
	m.set_shader_parameter("bloom", p.bloom)
	m.set_shader_parameter("bloom_from", p.bloom_from)
