## A list of upgrades (hero perks, relics, shop items...).
@tool
class_name UpgradeList
extends Resource

@export var items: Array[UpgradeData] = []

func find(id: String) -> UpgradeData:
	for u in items:
		if u.id == id:
			return u
	return null
