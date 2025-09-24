extends Control

@onready var gold_label: Label = $endggame_panel/goldcontainer/container/Gold
@onready var crystals_label: Label = $endggame_panel/crystalcontainer/container/Crystals
@onready var btn_new_game: Button = $endggame_panel/newgamecontainer/container/NewGameButton
@onready var btn_exit_game: Button = $endggame_panel/ExitButton
@onready var status_label: Label = $endggame_panel/HBoxContainer/status

# Pontos e gold ganhos nesta rodada
var gold_earned: int = 0
var crystals_earned: int = 0
var status_end: String = ""

func _ready():
	# Atualiza os labels com as recompensas ganhas
	_update_rewards_display()
	status_label.text = status_end
	# Conecta os botoes
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_exit_game.pressed.connect(_on_exit_pressed)

func _update_rewards_display():
	"""Atualiza a exibição das recompensas ganhas na partida"""
	gold_label.text = str(gold_earned)
	crystals_label.text = str(crystals_earned)
	
	# Debug para verificar se os valores estão sendo recebidos
	print("💰 Recompensas da partida:")
	print("   Gold ganho: ", gold_earned)
	print("   Cristais ganhos: ", crystals_earned)

func _on_new_game_pressed():
	# Vai para a cena principal
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_exit_pressed():
	# Volta para o menu Start
	get_tree().change_scene_to_file("res://scenes/Start.tscn")
