## A base tower. Edit its numbers in the Inspector. Paths are the 5 upgrade paths it can level along.
@tool
class_name TowerData
extends Resource

@export var id := ""
@export var name := ""
@export var cost := 50
@export var dmg := 10.0
## Seconds between shots.
@export var rate := 1.0
@export var range := 100.0
@export var splash := 0.0
@export_range(0.0, 0.85) var slow := 0.0
@export var chain := 0
## Never attacks; buffs towers in range instead.
@export var support := false
## Holds a beam on one target that heats up.
@export var beam := false
## Lobs slow shells that land a moment later.
@export var lob := false
## What every level-up adds on top of the path point: dmg, rate or range (see GameRules).
@export_enum("dmg", "rate", "range") var level_bonus := "dmg"
@export_enum("power", "arcane", "precision", "speed", "burst", "burn", "slow", "chain", "multi") var element_tag := "power"
@export var color := Color.WHITE
@export_multiline var info := ""
@export var paths: Array[TowerPath] = []
@export_group("Signature (Boss Core upgrade)")
@export var signature_name := ""
@export_multiline var signature_desc := ""
@export_group("Super tower power")
@export var super_power_name := ""
@export_multiline var super_power_desc := ""
@export_group("Ascended form names")
## Key: the positions (0-4) of the paths used, in order, e.g. "013". Value: the form's name.
@export var form_names: Dictionary = {}
@export_group("Art")
## The tower's animations (idle, attack, recover, shot, fx, hit; the laser also has beam). Open the file to
## change frames or speeds in the SpriteFrames editor.
@export var frames: SpriteFrames
## 6x4 sheet of 48px frames: idle, attack, recover, hit effect (the source of the animations above).
@export var sheet: Texture2D
## Pixel row in the frame where the tower's base sits.
@export var foot_y := 38.0
## Height of the muzzle above the base, in frame pixels.
@export var muzzle_y := 14.0
## Projectile anchor inside its frame.
@export var shot_anchor := Vector2(24, 24)
## Turn the projectile to face its flight.
@export var shot_turn := false
## Anchor of the hit effect (0..1 of the frame height).
@export var fx_anchor_y := 0.5
## Attack frame (0-5) where the shot leaves.
@export var fire_frame := 0
