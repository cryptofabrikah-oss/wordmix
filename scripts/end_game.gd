extends Control

@onready var gold_label: Label = $endggame_panel/goldcontainer/container/Gold
@onready var btn_new_game: Button = $endggame_panel/newgamecontainer/container/NewGameButton
@onready var btn_exit_game: Button = $endggame_panel/ExitButton
@onready var status_label: Label = $endggame_panel/HBoxContainer/status

# Pontos e gold ganhos nesta rodada
var points_earned: int = 0
var gold_earned: int = 0
var status_end: String = ""

func _ready():
	gold_label.text = str(gold_earned)
	status_label.text = status_end
	# Conecta os botões
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_exit_game.pressed.connect(_on_exit_pressed)

func _on_new_game_pressed():
	# Vai para a cena principal
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_exit_pressed():
	# Volta para o menu Start
	get_tree().change_scene_to_file("res://scenes/Start.tscn")
