## A hero. Base stats here; per-hero permanent upgrades are in `meta`.
@tool
class_name HeroData
extends Resource

@export var id := ""
@export var name := ""
@export var role := "Offensive"
@export_enum("offensive", "defensive", "support", "special") var category := "offensive"
@export var color := Color.WHITE
@export_multiline var desc := ""
@export var hp := 200.0
@export var dmg := 10.0
## Seconds between attacks.
@export var rate := 0.6
## 9999 = the whole map.
@export var range := 100.0
## How many enemies it can hold at once (999 = all).
@export var block := 1
@export var armor := 0.0
@export var regen := 2.0
@export var speed := 140.0
@export var aura := 0.0
## Seconds it must stand still before each shot (Sniper).
@export var brace := 0.0
@export var crit := 0.0
## How far each normal hit pushes the enemy back along the path (Gale).
@export var knock := 0.0
@export var mana := 0.0
@export var mana_regen := 0.0
## Casts spells instead of attacking (Wizard).
@export var spells := false
## A secret hero: shown as locked until its unlock is earned (Gale: push enemies back as the Wizard).
@export var secret := false
@export var ability: AbilityData
@export var alt: AbilityData
## Permanent upgrades bought with Rift Shards on the Heroes page.
@export var meta: Array[UpgradeData] = []
## The hero's animations: idle_N, walk_N and fire_N for each facing N (0 = north, then clockwise).
@export var frames: SpriteFrames
## How big a `frames` pixel is on the board. Rendered heroes are drawn at 2x (128px frames) and shown at 0.5, smoothed,
## so they keep their detail on big screens and match the painted map; hand-made pixel sheets stay at 1.
@export var art_scale := 1.0
## A folder with a hero.json (see tools/render_hero.md): the hero is drawn live from that 3D model on the board
## (Hero3D) instead of from `frames`, turning to any angle. `frames` still shows in the menus.
@export_dir var model_dir := ""
## 10 rows (idle 1-2, walk 1-4, fire 1-4) by 8 facings of 48px frames (the source of the animations above).
## The Striker's sheet is 64px frames instead: rows 0-7 idle, 8-15 walk, 16-21 fire, one column per facing.
@export var sheet: Texture2D
## Optional bullet sprites for the hero's normal shot (bullet_N per facing, hit, crit, flash_a/flash_b/flash_o).
## Without it the shot is drawn as a tracer line.
@export var shot_fx: SpriteFrames
## How fast its bullets fly, in board units a second (its hits land when they arrive). 0 = Game.HERO_SHOT_SPEED.
@export var shot_speed := 0.0
## A melee hero's hits land this many seconds into its attack animation (the Vanguard's shield bash), not at once.
@export var hit_time := 0.0
## Where the gun tip is in each facing (0 = north, clockwise), in pixels of a `frames` frame. Shots start here.
@export var muzzle := PackedVector2Array()
## Split-layer heroes (the Striker): on the board the body plays these animations instead of `frames`, and a
## separate gun layer (`gun`) turns freely to the exact angle of the target. `frames` still shows in the menus.
## The body only uses idle_N and walk_N, so the legs keep walking while it shoots.
@export var body_frames: SpriteFrames
## The gun and arms, drawn pointing right (east). Without it the hero is one sprite and `muzzle` is used.
@export var gun: Texture2D
## The pixel of `gun` it turns around (the shoulder end), and the pixel the bullets leave from (the tip).
@export var gun_pivot := Vector2(1, 3.5)
@export var gun_tip := Vector2(22, 3.5)
## Where the gun's pivot sits on the body in each facing (0 = north, clockwise), in pixels of a `body_frames` frame.
@export var shoulder := PackedVector2Array()
## Optional effects for the gun layer, drawn pointing right and turned to match: "flash" (the muzzle flash, its
## centre on the gun tip) and "bullet". Without it the 8-direction bullets and flashes of `shot_fx` are used.
@export var gun_fx: SpriteFrames
## How far the body's shoulders move in each frame (facing-major: the idle frames then the walk frames of facing 0,
## then facing 1, ...), in pixels, so the gun rides the walk instead of floating. Empty = the gun stays put.
@export var body_bob := PackedVector2Array()
## The angle the gun is carried at between shots, in degrees on screen (0 = right, 90 = down), per facing (0 = north,
## clockwise). A low-ready slant reads better than pointing straight ahead, above all facing the camera.
@export var carry := PackedFloat32Array()
