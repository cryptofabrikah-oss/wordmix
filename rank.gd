extends Control

@onready var ranking_list = $Mainpanel/playerslist

var ranking_data = [
	{"name": "Luca", "score": 15040, "avatar": "res://assets/avatar1.png"},
	{"name": "Hans", "score": 12000, "avatar": "res://assets/avatar1.png"},
	{"name": "Hellsun", "score": 9800,  "avatar": "res://assets/avatar1.png"},
	{"name": "Nick", "score": 3500,  "avatar": "res://assets/avatar1.png"},
	{"name": "Inferno G.", "score": 3499,  "avatar": "res://assets/avatar1.png"},
	{"name": "Zoey", "score": 2567,  "avatar": "res://assets/avatar1.png"},

]


func _ready():
	var style = StyleBoxFlat.new()

	style.border_color = Color(1, 0.84, 0)   # borda dourada
	style.set_border_width_all(5)              # bordas arredondadas
	style.set_corner_radius_all(8)
	style.bg_color = Color8(40, 20, 0, 255)  # laranja escuro sólido
	
	$Mainpanel.add_theme_stylebox_override("panel", style)

	update_ranking()
	
	
func update_ranking():
	# Limpa a lista antes de recriar
	for child in ranking_list.get_children():
		child.queue_free()
	
	ranking_list.add_theme_constant_override("separation", 30)
	
	var pos = 1
	for player in ranking_data:
		# Cada linha vai ser um PanelContainer (pra poder ter fundo)
		var row_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color.hex(0x100101FF) # fundo escuro semi-transparente
		style.border_color = Color(1, 0.84, 0) # borda clara
		style.set_corner_radius_all(10)
		style.set_expand_margin_all(5)
		style.set_border_width_all(5)
		row_panel.add_theme_stylebox_override("panel", style)
		
		# HBox dentro do Panel
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 30)
		
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
