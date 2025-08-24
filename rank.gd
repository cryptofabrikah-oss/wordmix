extends Control

@onready var ranking_list = $Background/playerslist

# Exemplo de dados
var ranking_data = [
	{"name": "Jogador1", "score": 15040, "avatar": "res://assets/avatar1.png"},
	{"name": "Jogador2", "score": 12000, "avatar": "res://assets/avatar2.png"},
	{"name": "Jogador3", "score": 9800,  "avatar": "res://assets/avatar3.png"},
	{"name": "Jogador4", "score": 3500,  "avatar": "res://assets/avatar4.png"},
	{"name": "Jogador5", "score": 3499,  "avatar": "res://assets/avatar5.png"},
	{"name": "Jogador6", "score": 3386,  "avatar": "res://assets/avatar6.png"},
	{"name": "Jogador7", "score": 3100,  "avatar": "res://assets/avatar7.png"},
	{"name": "Jogador8", "score": 2988,  "avatar": "res://assets/avatar8.png"},
	{"name": "Jogador9", "score": 2977,  "avatar": "res://assets/avatar9.png"},
	{"name": "Jogador10", "score": 2500,  "avatar": "res://assets/avatar9.png"}
]


func _ready():
	update_ranking()

func update_ranking():
	# Limpa a lista antes de recriar
	for child in ranking_list.get_children():
		child.queue_free()

	var pos = 1
	for player in ranking_data:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10) # espaço horizontal
	
		# Posição
		var pos_lbl = Label.new()
		pos_lbl.text = str(pos)
		pos_lbl.custom_minimum_size = Vector2(40, 0)  # largura fixa
		pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(pos_lbl)

		# Avatar
		var avatar = TextureRect.new()
		avatar.texture = load(player["avatar"])
		avatar.custom_minimum_size = Vector2(32, 32)
		row.add_child(avatar)

		# Nome
		var name_lbl = Label.new()
		name_lbl.text = player["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.custom_minimum_size = Vector2(230, 0) 
		row.add_child(name_lbl)

		# Score
		var score_lbl = Label.new()
		score_lbl.text = str(player["score"])
		score_lbl.custom_minimum_size = Vector2(10, 0) 
		row.add_child(score_lbl)

		ranking_list.add_child(row)
		pos += 1
		
