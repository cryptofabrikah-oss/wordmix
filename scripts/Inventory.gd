extends Control

# Referências dos nós
@onready var back_button = $Mainpanel/BackButton
@onready var gold_label = $Mainpanel/TopBar/Resources/GoldContainer/GoldHBox/GoldLabel
@onready var crystal_label = $Mainpanel/TopBar/Resources/CrystalContainer/CrystalHBox/CrystalLabel

# Labels de status dos personagens
@onready var aprendiz_status = $Mainpanel/ScrollContainer/CharacterGrid/AprendizCard/VBoxContainer/StatusLabel
@onready var mago_status = $Mainpanel/ScrollContainer/CharacterGrid/MagoCard/VBoxContainer/StatusLabel
@onready var arqueiro_status = $Mainpanel/ScrollContainer/CharacterGrid/ArqueiroCard/VBoxContainer/StatusLabel
@onready var mercador_status = $Mainpanel/ScrollContainer/CharacterGrid/MercadorCard/VBoxContainer/StatusLabel
@onready var guerreiro_status = $Mainpanel/ScrollContainer/CharacterGrid/GuerreiroCard/VBoxContainer/StatusLabel

# Cards dos personagens para aplicar estilos
@onready var aprendiz_card = $Mainpanel/ScrollContainer/CharacterGrid/AprendizCard
@onready var mago_card = $Mainpanel/ScrollContainer/CharacterGrid/MagoCard
@onready var arqueiro_card = $Mainpanel/ScrollContainer/CharacterGrid/ArqueiroCard
@onready var mercador_card = $Mainpanel/ScrollContainer/CharacterGrid/MercadorCard
@onready var guerreiro_card = $Mainpanel/ScrollContainer/CharacterGrid/GuerreiroCard

func _ready():
	# Conectar sinais
	back_button.pressed.connect(_on_back_pressed)
	
	# Aplicar estilo padronizado ao botao de voltar
	_apply_back_button_style()
	
	# Atualizar interface
	_update_resources_display()
	_update_character_status()

func _update_resources_display():
	"""Atualiza a exibicao de gold e cristais"""
	gold_label.text = str(Global.gold)
	crystal_label.text = str(Global.crystal)

func _update_character_status():
	"""Atualiza o status dos personagens baseado no que foi desbloqueado"""
	# Aprendiz sempre desbloqueado (personagem padrão)
	aprendiz_status.text = "DESBLOQUEADO"
	aprendiz_status.add_theme_color_override("font_color", Color(0, 1, 0, 1))
	_apply_unlocked_card_style(aprendiz_card)
	
	# Verifica se cada personagem foi desbloqueado
	if Global.unlocked_characters.has(1):
		mago_status.text = "DESBLOQUEADO"
		mago_status.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		_apply_unlocked_card_style(mago_card)
	else:
		mago_status.text = "BLOQUEADO"
		mago_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		_apply_locked_card_style(mago_card)
	
	if Global.unlocked_characters.has(2):
		arqueiro_status.text = "DESBLOQUEADO"
		arqueiro_status.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		_apply_unlocked_card_style(arqueiro_card)
	else:
		arqueiro_status.text = "BLOQUEADO"
		arqueiro_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		_apply_locked_card_style(arqueiro_card)
	
	if Global.unlocked_characters.has(3):
		mercador_status.text = "DESBLOQUEADO"
		mercador_status.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		_apply_unlocked_card_style(mercador_card)
	else:
		mercador_status.text = "BLOQUEADO"
		mercador_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		_apply_locked_card_style(mercador_card)
	
	if Global.unlocked_characters.has(4):
		guerreiro_status.text = "DESBLOQUEADO"
		guerreiro_status.add_theme_color_override("font_color", Color(0, 1, 0, 1))
		_apply_unlocked_card_style(guerreiro_card)
	else:
		guerreiro_status.text = "BLOQUEADO"
		guerreiro_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		_apply_locked_card_style(guerreiro_card)

func _apply_unlocked_card_style(card: Panel):
	"""Aplica estilo para personagens desbloqueados"""
	var unlocked_style = StyleBoxFlat.new()
	unlocked_style.bg_color = Color(0.2, 0.01, 0.05, 0.98)
	unlocked_style.border_color = Color(1, 0.843137, 0, 1)
	unlocked_style.set_border_width_all(3)
	unlocked_style.set_corner_radius_all(15)
	
	card.add_theme_stylebox_override("panel", unlocked_style)

func _apply_locked_card_style(card: Panel):
	"""Aplica estilo para personagens bloqueados"""
	var locked_style = StyleBoxFlat.new()
	locked_style.bg_color = Color(0, 0, 0, 0.9)
	locked_style.border_color = Color(0.5, 0.5, 0.5, 1)
	locked_style.set_border_width_all(2)
	locked_style.set_corner_radius_all(10)
	
	card.add_theme_stylebox_override("panel", locked_style)
	
	# Aplicar opacidade reduzida ao card inteiro
	card.modulate = Color(1, 1, 1, 0.5)

func _apply_back_button_style():
	# Estilo padronizado do botão de voltar (igual ao market e ranking)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color.hex(0x100101FF)      # fundo vermelho quase preto
	back_style.border_color = Color(1, 0.84, 0)   # borda dourada
	back_style.set_border_width_all(5)
	back_style.set_corner_radius_all(10)

	# Aplica ao botão em todos os estados
	back_button.add_theme_stylebox_override("normal", back_style)
	back_button.add_theme_stylebox_override("hover", back_style)
	back_button.add_theme_stylebox_override("pressed", back_style)
	back_button.add_theme_stylebox_override("disabled", back_style)

func _on_back_pressed():
	"""Volta para a tela inicial"""
	get_tree().change_scene_to_file("res://scenes/Start.tscn")

func _show_character_info(character_id: int):
	"""Mostra informacoes detalhadas do personagem"""
	if character_id < 0 or character_id >= Global.avatar_names.size():
		return
	
	var character_name = Global.avatar_names[character_id]
	var ability_description = ""
	
	# Descrições das habilidades
	match character_id:
		0:
			ability_description = "Personagem básico sem habilidades especiais."
		1:
			ability_description = "Habilidade: Revela uma letra aleatória da palavra no início do jogo."
		2:
			ability_description = "Habilidade: Ganha uma tentativa extra para adivinhar a palavra."
		3:
			ability_description = "Habilidade: Ganha o dobro de gold ao completar uma partida."
		4:
			ability_description = "Habilidade: Ganha 50% mais pontos ao completar uma partida."
		_:
			ability_description = "Informações não disponíveis."
	
	# Cria um popup com as informações
	var popup = AcceptDialog.new()
	popup.title = character_name
	popup.dialog_text = ability_description
	popup.size = Vector2(400, 200)
	
	# Centraliza o popup
	popup.popup_window = false
	popup.anchors_preset = Control.PRESET_CENTER
	
	add_child(popup)
	popup.popup_centered()
	
	# Remove o popup quando fechado
	popup.confirmed.connect(func(): popup.queue_free())
	popup.canceled.connect(func(): popup.queue_free())
