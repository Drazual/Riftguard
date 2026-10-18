## A fusion effect: merged towers learn 5 of these as their paths, matched to their parents' tags.
## desc uses r (points) and m (1, or 1.5 for super towers); effect uses t and m.
@tool
class_name FusionData
extends Resource

@export var id := ""
@export var name := ""
@export var tags: PackedStringArray = []
@export_multiline var desc := ""
@export_multiline var effect := ""
