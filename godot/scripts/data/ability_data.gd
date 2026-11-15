## A hero ability. `desc` is a template: {...} parts are worked out from `a` (this ability).
@tool
class_name AbilityData
extends Resource

@export var id := ""
@export var name := ""
@export var cd := 18.0
@export var dmg := 0.0
@export var r := 0.0
@export var stun := 0.0
@export var dur := 0.0
@export var power := 0.0
@export var mult := 0.0
@export var w := 0.0
## Seconds into the hero's cast animation before the ability takes effect (the Vanguard's shield comes down or
## goes up then). 0 = at once.
@export var release := 0.0
@export_group("Shield Slam")
## Enemies in front that take the full hit and the stun (the nearest ones to where the shield lands).
@export var targets := 1
## Share of the hero's armor added to the full hit (dmg + armor * armor_mul).
@export var armor_mul := 0.0
## How far the shockwave runs on down the path after the first hit (field units, 40 = one square).
@export var reach := 0.0
## The shockwave's slow on everything else it passes, and how long it lasts.
@export var slow := 0.0
@export var slow_t := 0.0
## Shield gained: a base amount plus this much for every enemy hit.
@export var shield := 0.0
@export var shield_per := 0.0
@export_group("")
@export_multiline var desc := ""
