class_name StyleSettings
extends Resource
## The art-style knobs for the shared live-3D renderer (StyleWorld). Everything here is visual only: no gameplay
## reads it. The style test scene (scenes/style_test.tscn) edits a live copy from its side panel.

## The low-res render's size, as a multiple of the board's base 768x416. 2 = one render pixel per pixel of the
## 2x scenery art (Ocean Drive's density). Lower is chunkier; the result is upscaled with nearest-neighbour.
@export_range(0.5, 4.0, 0.25) var res_scale := 2.0
## Upscale to the window by whole multiples when the window is big enough (black bars), instead of stretching.
@export var integer_scale := true
## Turn the stylized model material on (off = the models' own materials, as the game draws them today).
@export var stylize := true
## How far model colours are pulled toward the palette ramp (navy shadows, peach/cream lights). 0 = their own colours.
@export_range(0.0, 1.0, 0.01) var palette_strength := 0.25
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
@export_range(0.0, 2.0, 0.01) var shadow_energy := 0.75
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
## Rim light on the edge away from the key, so dark silhouettes read on the dark road.
@export var rim_color := Color(1.0, 0.45, 0.85)
@export_range(0.0, 2.0, 0.01) var rim := 0.35
## Dark outline around models (inverted hull), in render pixels. 0 = none.
@export_range(0.0, 3.0, 0.25) var outline := 1.0
@export var outline_color := Color(0.11, 0.07, 0.2)
## How much of the models' normal maps to keep, and how many mip levels blurrier their textures are read
## (simplified surfaces: fine texture detail turns to noise at a few centimetres a pixel).
@export_range(0.0, 1.0, 0.01) var normal_detail := 0.0
@export_range(0.0, 4.0, 0.1) var simplify := 1.5
## Glow from emissive parts and effects (bright pixels only), and the brightness it starts at.
@export_range(0.0, 2.0, 0.01) var glow := 0.6
@export_range(0.0, 4.0, 0.01) var glow_threshold := 1.0
## Overall exposure of the 3D models (the scenery is unlit and never changes).
@export_range(0.2, 2.0, 0.01) var exposure := 1.0
## Snap moving models to the render's pixel grid along the ground, so they don't shimmer between pixels.
@export var pixel_snap := true
