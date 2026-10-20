## A map. Paint the road, water and ground on the Ground layer and decorations on the Props layer.
## The road must be one connected line of path tiles. Enemies enter at the path tile nearest the Spawn
## marker and walk to the other end, where your base stands. Water and props can't be built on.
@tool
class_name MapScene
extends Node2D

## Save id (keeps best waves and wins). Don't change it after release.
@export var id := ""
@export var map_name := ""
@export var tier := "Level 1"
## The tileset look used for the road colours: sunset, boardwalk, reactor or garden.
@export_enum("sunset", "boardwalk", "reactor", "garden") var theme := "sunset"
## A finished picture of the whole board (768x416, the grid starting 32 pixels down) drawn instead of the
## painted tiles, road and props. The Ground and Props layers then only say where the road, water and
## blocked tiles are, so keep them matching the picture.
@export var backdrop: Texture2D
@export var waves := 20
@export var shard_mult := 1.0
@export var enemy_hp := 1.0
## Everything costs this much more (towers, level-ups, merges, the shop).
@export var price := 1.0
## Extra armor for armored enemies.
@export var armor_bonus := 0.0
## Special enemies show up this many waves early.
@export var early_specials := 0
## Boss Cores from the final Tyrant (0 = normal).
@export var tyrant_cores := 0
## After each wave the top damage tower deals half damage next wave.
@export var drain := false
@export_multiline var desc := ""
