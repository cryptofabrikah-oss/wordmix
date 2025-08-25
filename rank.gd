extends Control

@onready var ranking_list = $Mainpanel/playerslist

# Exemplo de dados
var ranking_data = [
	{"name": "Jogador1", "score": 15040, "avatar": "res://assets/avatar1.png"},
	{"name": "Jogador2", "score": 12000, "avatar": "res://assets/avatar2.png"},
	{"name": "Jogador3", "score": 9800,  "avatar": "res://assets/avatar3.png"},
	{"name": "Jogador4", "score": 3500,  "avatar": "res://assets/avatar4.png"},
	{"name": "Jogador5", "score": 3499,  "avatar": "res://assets/avatar5.png"},
	{"name": "Jogador6", "score": 3386,  "avatar": "res://assets/avatar6.png"},
	{"name": "Jogador7", "score": 3100,  "avatar": "res://assets/avatar7.png"},
]


func _ready():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)   # fundo escuro
	style.border_color = Color8(200, 180, 60, 255)      # borda dourada
	style.set_border_width_all(10)              # bordas arredondadas
	style.set_corner_radius_all(8)
	style.bg_color = Color8(40, 20, 0, 255)  # laranja escuro sólido
	
	$Mainpanel.add_theme_stylebox_override("panel", style)

	update_ranking()
	
	
func update_ranking():
	# Limpa a lista antes de recriar
	for child in ranking_list.get_children():
		child.queue_free()
	
	var pos = 1
	for player in ranking_data:
		# Cada linha vai ser um PanelContainer (pra poder ter fundo)
		var row_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9) # fundo escuro semi-transparente
		style.border_color = Color(0.8, 0.8, 0.8)  # borda clara
		style.set_corner_radius_all(10)
		style.set_expand_margin_all(5)
		style.set_border_width_all(5)
		row_panel.add_theme_stylebox_override("panel", style)

		# HBox dentro do Panel
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		
		# Posição
		var pos_lbl = Label.new()
		pos_lbl.text = str(pos)
		pos_lbl.custom_minimum_size = Vector2(40, 0)
		pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_make_lbl_style(pos_lbl, Color(1, 0.84, 0)) # dourado
		row.add_child(pos_lbl)

		# Avatar
		var avatar = TextureRect.new()
		avatar.texture = load(player["avatar"])
		avatar.custom_minimum_size = Vector2(32, 32)
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(avatar)

		# Nome
		var name_lbl = Label.new()
		name_lbl.text = player["name"]
		name_lbl.custom_minimum_size = Vector2(230, 0)
		_make_lbl_style(name_lbl, Color(1, 0.84, 0))
		row.add_child(name_lbl)

		# Score
		var score_lbl = Label.new()
		score_lbl.text = str(player["score"])
		score_lbl.custom_minimum_size = Vector2(100, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_make_lbl_style(score_lbl, Color(1, 0.84, 0))
		row.add_child(score_lbl)

		# Monta linha
		row_panel.add_child(row)
		ranking_list.add_child(row_panel)
		pos += 1


func _make_lbl_style(lbl: Label, color: Color) -> void:
	lbl.add_theme_color_override("font_color", color)
	# você pode usar uma fonte pixel art carregada via .tres ou .ttf aqui
