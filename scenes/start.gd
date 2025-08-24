extends Control

@onready var start_btn = $VBoxContainer/StartB
@onready var market_btn = $BottonBar/Market
@onready var rank_btn = $BottonBar/Rank
@onready var inventory_btn = $BottonBar/Inventory
@onready var playerselect_btn = $VBoxContainer/PLayerB

func _ready():
	market_btn.pressed.connect(_on_market_pressed)
	rank_btn.pressed.connect(_on_rank_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	playerselect_btn.pressed.connect(_on_player_pressed)

#novo jogo
func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

#ranking semanal
func _on_rank_pressed():
	get_tree().change_scene_to_file("res://scenes/Rank.tscn")

#marketplace
func _on_market_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

#inventory	
func _on_inventory_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_player_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	
