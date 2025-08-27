extends Node

var points: int = 0
var gold: int = 0
var crystal: int = 0
var player_name: String = "Hell Sun"


# Adiciona uma quantidade de pontos
func add_points(amount: int) -> void:
	points += amount

# Adiciona uma quantidade de gold
func add_gold(amount: int) -> void:
	gold += amount
