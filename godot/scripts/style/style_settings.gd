class_name StyleSettings
extends Resource
## The one place the live-3D look is tuned. Everything here is visual only: no gameplay reads it.
## Pixel scale (res_scale), palette tint, shadow lift, rim, outline, glow and exposure all live on this resource.
## The Settings menu edits the saved subset (SAVED); scenes/style_test.tscn edits a live copy of all of them.
## Save.settings.style3d (see enabled) is the old-look switch: off puts each hero back in its own smooth viewport
## and the towers back on their baked sprites.

## The low-res render's size, as a multiple of the board's base 768x416. 2 = one render pixel per pixel of the
## 2x scenery art (Ocean Drive's density). Lower is chunkier; the result is upscaled with nearest-neighbour.
@export_range(0.5, 4.0, 0.25) var res_scale := 2.0
## Upscale to the window by whole multiples when the window is big enough (black bars), instead of stretching.
@export var integer_scale := true
## Turn the stylized model material on (off = the models' own materials, as the game draws them today).
@export var stylize := true
## How far model colours are pulled toward the palette ramp (navy shadows, peach/cream lights). 0 = their own colours.
@export_range(0.0, 1.0, 0.01) var palette_strength := 0.35
## Saturated colours (neon trim) keep this much of their own hue whatever palette_strength is.
@export_range(0.0, 1.0, 0.01) var keep_accents := 0.8
## Light bands: where the lit side starts (N.L) and how soft the step is.
@export_range(-1.0, 1.0, 0.01) var band_edge := 0.05
@export_range(0.0, 0.5, 0.01) var band_soft := 0.06
## Specular highlight: how strong and how tight (a single hard spot, not PBR sheen).
@export_range(0.0, 2.0, 0.01) var highlight := 0.3
@export_range(0.0, 1.0, 0.01) var highlight_size := 0.25
## Colour and brightness of the unlit side (the ambient): the references' navy/purple shadows.
@export var shadow_color := Color(0.27, 0.22, 0.48)
@export_range(0.0, 2.0, 0.01) var shadow_energy := 0.85
## The key light: one direction for every model (the scenery is painted lit from the upper left).
@export var light_yaw := -35.0
@export var light_pitch := -50.0
@export_range(0.0, 3.0, 0.01) var light_energy := 0.9
@export var light_color := Color(1.0, 0.94, 0.86)
## Cast shadows from models onto the ground (a shadow-only receiver), and their strength.
@export var cast_shadows := true
@export_range(0.0, 1.0, 0.01) var shadow_strength := 0.45
## Soft contact shadow blob under each model's feet.
@export_range(0.0, 1.0, 0.01) var contact_shadow := 0.5
## Near-black albedo (Gale's charcoal armor) is raised to this luminance before the palette tint, so a dark
## model stays a dark shape instead of a hole. 0 = the texture's own blacks. Bright accents above this are left.
@export_range(0.0, 0.6, 0.01) var lift := 0.34
## Rim: a hard cyan edge on the silhouette, plus one extra render pixel of that colour outside the ink outline,
## so the same model reads on navy roads and on peach stone.
@export var rim_color := Color(0.4, 0.95, 1.0)
@export_range(0.0, 2.0, 0.01) var rim := 1.1
## Dark outline around models (inverted hull), in render pixels. 0 = none. The rim adds a bright pixel outside it.
@export_range(0.0, 3.0, 0.25) var outline := 1.0
@export var outline_color := Color(0.07, 0.05, 0.14)
## How much of the models' normal maps to keep, and how many mip levels blurrier their textures are read
## (simplified surfaces: fine texture detail turns to noise at a few centimetres a pixel).
@export_range(0.0, 1.0, 0.01) var normal_detail := 0.0
@export_range(0.0, 4.0, 0.1) var simplify := 3.2
## Glow from emissive parts and effects (bright pixels only), and the brightness it starts at.
@export_range(0.0, 2.0, 0.01) var glow := 0.6
@export_range(0.0, 4.0, 0.01) var glow_threshold := 1.0
## Overall exposure of the 3D models (the scenery is unlit and never changes).
@export_range(0.2, 2.0, 0.01) var exposure := 1.08
## Snap moving models to the render's pixel grid along the ground, so they don't shimmer between pixels.
@export var pixel_snap := true

## The knobs the Settings menu shows and saves (Save.settings.style), over these defaults.
const SAVED := ["res_scale", "palette_strength", "shadow_strength", "contact_shadow", "glow", "outline", "rim", "lift", "stylize"]


## The player's saved style (Save.settings.style), over the defaults.
static func saved() -> StyleSettings:
	var s := StyleSettings.new()
	var d: Dictionary = Save.settings.get("style", {})
	for k in SAVED:
		if d.has(k):
			s.set(k, d[k])
	return s


func save() -> void:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	Save.settings.style = d
	Save.save_settings()


## The unified 3D style is on. It is off in the game (the pixel filter blurred the models): each hero is drawn in its
## own smooth viewport with studio light, and the towers use their baked sprites. The code stays for the style test
## scenes, which switch it on with Save.settings.style3d_test; the old style3d setting is ignored.
static func enabled() -> bool:
	return bool(Save.settings.get("style3d_test", false))
