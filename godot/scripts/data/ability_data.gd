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
@export_multiline var desc := ""
