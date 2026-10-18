## The game's root: creates the rules (Game), the board renderer and the interface, then ticks them every frame.
class_name Main
extends Node

var game: Game
var board: Board
var ui: Ui


func _ready() -> void:
	apply_window()
	game = Game.new()
	game.name = "Game"
	add_child(game)
	board = Board.new()
	board.name = "Board"
	ui = Ui.new()
	ui.name = "Ui"
	ui.setup(game, board)
	add_child(ui)
	board.bind(game)
	ui.menus.show_menu()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	game.update(dt)
	board.sync(dt)
	ui.tick(dt)


## Fullscreen or windowed, from the settings.
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full: bool = Save.settings.get("fullscreen", true)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
