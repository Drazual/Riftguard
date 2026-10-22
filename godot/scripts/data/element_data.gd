## A Wizard element.
@tool
class_name ElementData
extends Resource

@export var id := ""
@export var name := ""
@export var color := Color.WHITE
## Rift Shards to buy (0 = known from the start). Unused when `parent` is set.
@export var cost := 0
## Unlocked by reaching this element's mastery (rules `element_unlock_at`), e.g. Fire unlocks Lightning.
@export var parent := ""
@export_multiline var blurb := ""
