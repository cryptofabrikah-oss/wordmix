extends Control

@onready var btn_new_game: Button = $NewGameButton
@onready var btn_exit_game: Button = $ExitButton

func _ready():
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_exit_game.pressed.connect(_on_new_game_pressed)

func _on_new_game_pressed():
	# Carrega novamente a cena principal (main.tscn)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
