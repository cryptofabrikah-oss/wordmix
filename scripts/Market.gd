extends Control

# Referências dos nós
@onready var back_button = $Mainpanel/BackButton
@onready var gold_label = $Mainpanel/TopBar/Resources/GoldContainer/GoldHBox/GoldLabel
@onready var crystal_label = $Mainpanel/TopBar/Resources/CrystalContainer/CrystalHBox/CrystalLabel

# Botões de compra
@onready var mago_buy_button = $Mainpanel/ScrollContainer/CharacterGrid/MagoCard/VBoxContainer/BuyButton
@onready var arqueiro_buy_button = $Mainpanel/ScrollContainer/CharacterGrid/ArqueiroCard/VBoxContainer/BuyButton
@onready var mercador_buy_button = $Mainpanel/ScrollContainer/CharacterGrid/MercadorCard/VBoxContainer/BuyButton
@onready var guerreiro_buy_button = $Mainpanel/ScrollContainer/CharacterGrid/GuerreiroCard/VBoxContainer/BuyButton

# Preços dos personagens
var character_prices = {
	1: {"type": "crystal", "amount": 75},  # Mago - cristal (habilidade muito útil)
	2: {"type": "gold", "amount": 750},    # Arqueiro - gold (habilidade moderada)
	3: {"type": "gold", "amount": 250},    # Mercador - gold (habilidade econômica)
	4: {"type": "crystal", "amount": 25}   # Guerreiro - cristal (habilidade de ranking)
}

func _ready():
	# Conectar sinais
	back_button.pressed.connect(_on_back_pressed)
	mago_buy_button.pressed.connect(_on_character_buy_pressed.bind(1))
	arqueiro_buy_button.pressed.connect(_on_character_buy_pressed.bind(2))
	mercador_buy_button.pressed.connect(_on_character_buy_pressed.bind(3))
	guerreiro_buy_button.pressed.connect(_on_character_buy_pressed.bind(4))
	
	# Aplicar estilo padronizado ao botao de voltar
	_apply_back_button_style()
	
	# Atualizar interface
	_update_resources_display()
	_update_character_availability()

func _update_resources_display():
	"""Atualiza a exibicao de gold e cristais"""
	gold_label.text = str(Global.gold)
	crystal_label.text = str(Global.crystal)

func _update_character_availability():
	"""Atualiza a disponibilidade dos personagens baseado no que ja foi comprado"""
	# Verifica se cada personagem já foi desbloqueado
	if Global.unlocked_characters.has(1):
		mago_buy_button.text = "ADQUIRIDO"
		mago_buy_button.disabled = true
	
	if Global.unlocked_characters.has(2):
		arqueiro_buy_button.text = "ADQUIRIDO"
		arqueiro_buy_button.disabled = true
	
	if Global.unlocked_characters.has(3):
		mercador_buy_button.text = "ADQUIRIDO"
		mercador_buy_button.disabled = true
	
	if Global.unlocked_characters.has(4):
		guerreiro_buy_button.text = "ADQUIRIDO"
		guerreiro_buy_button.disabled = true

func _on_character_buy_pressed(character_id: int):
	"""Processa a compra de um personagem"""
	# Verifica se o personagem já foi comprado
	if Global.unlocked_characters.has(character_id):
		_show_message("Você já possui este personagem!")
		return
	
	# Obtém informações do preço
	var price_info = character_prices[character_id]
	var currency_type = price_info["type"]
	var amount = price_info["amount"]
	
	# Verifica se o jogador tem recursos suficientes
	var has_enough_resources = false
	if currency_type == "gold":
		has_enough_resources = Global.gold >= amount
	elif currency_type == "crystal":
		has_enough_resources = Global.crystal >= amount
	
	if not has_enough_resources:
		var currency_name = "gold" if currency_type == "gold" else "cristais"
		_show_message("Você não tem %s suficiente!" % currency_name)
		return
	
	# Processa a compra
	if currency_type == "gold":
		Global.gold -= amount
	elif currency_type == "crystal":
		Global.crystal -= amount
	
	# Desbloqueia o personagem
	Global.unlock_character(character_id)
	
	# Atualiza a interface
	_update_resources_display()
	_update_character_availability()
	
	# Mostra mensagem de sucesso
	var character_name = Global.avatar_names[character_id]
	_show_message("%s adquirido com sucesso!" % character_name)

func _show_message(text: String):
	"""Exibe uma mensagem temporaria para o jogador"""
	# Cria um label temporário para mostrar a mensagem
	var message_label = Label.new()
	message_label.text = text
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Posiciona no centro da tela
	message_label.anchors_preset = Control.PRESET_CENTER
	message_label.position = Vector2(-100, -50)
	message_label.size = Vector2(200, 100)
	
	add_child(message_label)
	
	# Remove a mensagem após 2 segundos
	await get_tree().create_timer(2.0).timeout
	message_label.queue_free()

func _apply_back_button_style():
	# Estilo padronizado do botão de voltar (igual ao ranking)
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
