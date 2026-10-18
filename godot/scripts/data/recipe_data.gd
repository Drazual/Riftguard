## A hybrid (two base towers) or super tower (towers inside two hybrids). `key` lists the base towers, sorted.
@tool
class_name RecipeData
extends Resource

@export var key := ""
@export var name := ""
@export var color := Color.WHITE
@export_multiline var desc := ""
@export_group("Resonance boon (hero power awakened by merging)")
@export var boon_name := ""
@export_multiline var boon_desc := ""
@export_multiline var boon_effect := ""
