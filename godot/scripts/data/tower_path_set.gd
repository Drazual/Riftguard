## Hero Shrine paths for one hero. The Shrine offers the set that matches the hero you picked
## (the one with an empty `hero` is used for any hero without its own set).
@tool
class_name TowerPathSet
extends Resource

## Hero id (vanguard, gale, striker, ...), or empty for the fallback set.
@export var hero := ""
@export var paths: Array[TowerPath] = []
