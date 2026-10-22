## A Wizard spell. `runes` is the element combination, e.g. "fire" or "fire+water" or "fire+fire+fire".
## Damage numbers are multiplied by spell power (p). `desc` is a template that can use this spell's own
## numbers as sp (e.g. {f0(sp.dmg * p)}), the hero as h (h.spell_r, h.freeze_bonus, h.push_bonus,
## h.wall_bonus), p and wave, so editing a number also updates the text.
@tool
class_name SpellData
extends Resource

@export var runes := ""
@export var name := ""
@export var mana := 20.0
@export_multiline var desc := ""
## How it is delivered.
@export_enum("area", "launch", "delayed", "map", "chain", "line", "strikes", "toughest", "zone", "wall", "divine") var delivery := "area"
## Radius (x the hero's spell area).
@export var r := 60.0
## Damage on impact (x power).
@export var dmg := 0.0
@export var delay := 0.0
@export_group("On every enemy hit")
@export var freeze := 0.0
@export var stun := 0.0
## Stun on bosses (usually a third).
@export var stun_boss := 0.0
## Root (bosses 30%).
@export var root := 0.0
@export var push := 0.0
@export var push_speed := 90.0
## Push back only this many enemies, nearest the cast point first (0 = every enemy hit).
@export var push_max := 0
@export var poison_dps := 0.0
@export var poison_time := 0.0
## Takes more damage from everything.
@export var expose := 0.0
@export var expose_time := 0.0
@export var armor_break := 0.0
@export var armor_break_time := 0.0
@export_group("Chains, lines, strikes")
@export var jumps := 0
@export var count := 0
@export var gap := 0.0
@export var length := 0.0
@export var width := 0.0
@export_group("Ground zone")
@export var zone_time := 0.0
@export var zone_dps := 0.0
@export var zone_slow := 0.0
@export var zone_vortex := false
@export var zone_end_freeze := 0.0
@export var zone_break := 0.0
## Burning ground left behind.
@export var burn_time := 0.0
## Burning ground radius, as a share of the spell's radius.
@export var burn_r := 0.8
@export var burn_dps := 0.0
@export var burn_color := Color(0, 0, 0, 0)
@export var implode_dmg := 0.0
@export_group("Wall")
@export var wall_hp := 0.0
@export var wall_hp_per_wave := 0.0
@export var wall_time := 0.0
@export var wall_slam := 0.0
@export var wall_thorns := 0.0
@export var wall_color := Color(0, 0, 0, 0)
@export_group("Other")
## Heals the hero this share of max HP.
@export var heal := 0.0
@export var color := Color.WHITE
@export var size := 4.0
@export var shake := 0.0
@export var ring_fill := true
@export var ring_shrink := false
@export var ring_time := 0.5
## Extra lightning bolts drawn for show.
@export var fx_strikes := 0
@export var fx_strike_gap := 0.0
@export var pillar := false
@export var boom := false
@export_group("Painted effect")
## Animation in fx_spells.png (empty = drawn circles).
@export var art := ""
@export_enum("area", "fly", "meteor", "beam") var art_mode := "area"
@export var art_fly := ""
@export var art_fly_frames: PackedInt32Array = []
@export var art_hit_frames: PackedInt32Array = []
@export var art_r := 0.0
@export var art_fps := 13.0
@export var art_dur := 0.0
@export var art_loop := Vector2i(-1, -1)
@export var art_tint := Color.WHITE
@export var art_low := false
@export var art_turn := false
