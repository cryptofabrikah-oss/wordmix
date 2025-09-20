extends Control

@onready var avatar_buttons: Array[Button] = []
@onready var avatar_panels: Array[Panel] = []
@onready var back_button = $MainPanel/BackButton

func _ready():
	# Coleta todos os paineis e botoes de avatar
	for i in range(5):  # 0 a 4 avatares
		var avatar_panel = $MainPanel/ScrollContainer/AvatarGrid.get_child(i) as Panel
		var avatar_button = avatar_panel.get_child(0) as Button  # O botao e o primeiro filho do painel
		avatar_panels.append(avatar_panel)
		avatar_buttons.append(avatar_button)
		# Conecta o sinal de cada botao para mostrar informacoes
		avatar_button.pressed.connect(_on_avatar_info.bind(i))
	
	# Conecta o botao de voltar
	back_button.pressed.connect(_on_back_pressed)
	
	# Aplicar estilo padronizado ao botao de voltar
	_apply_back_button_style()
	
	# Atualiza a exibicao do inventario
	_update_inventory_display()

func _on_avatar_info(avatar_index: int):
	# Verifica se o personagem está desbloqueado
	if not Global.is_character_unlocked(avatar_index):
		return  # Não mostra informações de personagens bloqueados
	
	# Mostra informações do personagem (pode ser expandido futuramente)
	var character_name = Global.avatar_names[avatar_index]
	var character_effect = _get_character_effect_description(avatar_index)
	
	# Feedback visual temporário
	var panel = avatar_panels[avatar_index]
	panel.modulate = Color(1.3, 1.3, 1.0)  # Destaque amarelado
	await get_tree().create_timer(0.3).timeout
	panel.modulate = Color(1.0, 1.0, 1.0)  # Volta ao normal

func _get_character_effect_description(avatar_index: int) -> String:
	# Retorna a descrição do efeito de cada personagem
	match avatar_index:
		0: return "Personagem básico sem habilidades especiais"
		1: return "Pode revelar uma letra por partida"
		2: return "Ganha pontos extras por palavras longas"
		3: return "Ganha mais moedas ao completar palavras"
		4: return "Tem mais tentativas para acertar a palavra"
		_: return "Efeito desconhecido"

func _update_inventory_display():
	# Atualiza a exibição do inventário
	for i in range(avatar_panels.size()):
		var panel = avatar_panels[i]
		var button = avatar_buttons[i]
		
		# Verifica se o personagem está desbloqueado
		if not Global.is_character_unlocked(i):
			# Esconde personagens bloqueados
			panel.visible = false
			continue
		
		# Mostra personagens desbloqueados
		panel.visible = true
		button.disabled = false
		
		# Destaca o personagem atualmente selecionado
		if i == Global.selected_avatar:
			panel.modulate = Color(1.2, 1.2, 1.2)  # Mais brilhante
			panel.scale = Vector2(1.05, 1.05)  # Ligeiramente maior
		else:
			panel.modulate = Color(1.0, 1.0, 1.0)  # Normal
			panel.scale = Vector2(1.0, 1.0)  # Tamanho normal

func _on_back_pressed():
	# Volta para a tela inicial
	get_tree().change_scene_to_file("res://scenes/Start.tscn")

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