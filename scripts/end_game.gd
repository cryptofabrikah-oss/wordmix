extends Control

@onready var gold_label: Label = $Gold
@onready var btn_new_game: Button = $NewGameButton
@onready var btn_exit_game: Button = $ExitButton

# Pontos e gold ganhos nesta rodada
var points_earned: int = 0
var gold_earned: int = 0

func _ready():
	gold_label.text = str(gold_earned)
	
	# Conecta os botões
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_exit_game.pressed.connect(_on_exit_pressed)

func _on_new_game_pressed():
	# Vai para a cena principal
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_exit_pressed():
	# Volta para o menu Start
	get_tree().change_scene_to_file("res://scenes/Start.tscn")
