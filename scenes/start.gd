extends Control

# TopBar
@onready var gold_line = $TopBar/gold_line
@onready var crystal_line = $TopBar/crystal_line
@onready var gold_num: Label = $TopBar/gold_line/gold_num  # Label que mostra o gold
# CenterBox
@onready var start_btn = $CenterBox/StartB
@onready var playerselect_btn = $CenterBox/PLayerB
# BottomBar
@onready var market_btn = $BottonBar/Market
@onready var rank_btn = $BottonBar/Rank
@onready var inventory_btn = $BottonBar/Inventory

func _ready():
	# Conecta os sinais
	market_btn.pressed.connect(_on_market_pressed)
	rank_btn.pressed.connect(_on_rank_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	playerselect_btn.pressed.connect(_on_player_pressed)
	
	# Atualiza o gold ao abrir o menu
	_update_gold()

func _update_gold() -> void:
	if gold_num:
		gold_num.text = str(Global.gold)

# Opcional: atualizar dinamicamente a cada frame
# func _process(delta):
#     _update_gold()

# Novo jogo
func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Seleção de jogador
func _on_player_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Ranking semanal
func _on_rank_pressed():
	get_tree().change_scene_to_file("res://scenes/Rank.tscn")

# Marketplace
func _on_market_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Inventory
func _on_inventory_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
