extends Control

# TopBar
@onready var gold_line = $TopBar/gold_line
@onready var crystal_line = $TopBar/crystal_line
@onready var gold_num: Label = $TopBar/gold_line/gold_num  # Label que mostra o gold
@onready var crystal_num: Label = $TopBar/crystal_line/crystal_num  # Label que mostra o gold
# CharacterPanel
@onready var left_arrow = $CharacterPanel/CharacterContainer/LeftArrow
@onready var right_arrow = $CharacterPanel/CharacterContainer/RightArrow
@onready var start_btn = $StartB
@onready var player_sprite = $CharacterPanel/CharacterContainer/CenterBox/PlayerSprite
@onready var player_namestart = $CharacterPanel/CharacterContainer/CenterBox/PlayerName
# BottomBar
@onready var market_btn = $BottonBar/Market
@onready var rank_btn = $BottonBar/Rank
@onready var inventory_btn = $BottonBar/Inventory

# FirstTime Panel
@onready var first_time_panel = $FirstTimePanel
@onready var name_input = $FirstTimePanel/NameEntryContainer/NameInput
@onready var confirm_button = $FirstTimePanel/NameEntryContainer/ButtonContainer/ConfirmButton
@onready var offline_button = $FirstTimePanel/NameEntryContainer/ButtonContainer/OfflineButton
@onready var status_label = $FirstTimePanel/NameEntryContainer/StatusLabel

var is_processing = false

func _ready():
	print("🏠 Iniciando cena Start - Verificação de cache...")
	
	# Conecta os sinais
	market_btn.pressed.connect(_on_market_pressed)
	rank_btn.pressed.connect(_on_rank_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	
	# Conecta sinais do painel de primeira execução
	confirm_button.pressed.connect(_on_confirm_name_pressed)
	offline_button.pressed.connect(_on_offline_mode_pressed)
	name_input.text_submitted.connect(_on_name_submitted)
	
	# Ouve atualizações vindas do Global para refletir dados online quando chegarem
	if not Global.player_data_updated.is_connected(_on_global_player_data_updated):
		Global.player_data_updated.connect(_on_global_player_data_updated)
		print("🔔 Start: conectado ao sinal Global.player_data_updated")
	
	# Sistema robusto de verificação de cache
	_check_cache_and_initialize()

# Verifica cache e inicializa a interface
func _check_cache_and_initialize():
	print("🔍 Verificando cache local...")
	print("   • Estado Global: Online=", Global.is_online, " UID=", (Global.player_id if not Global.player_id.is_empty() else "vazio"))
	
	# Garante que o Global carregou os dados primeiro
	if not Global.player_data_loaded:
		print("⚠️  Dados do Global não carregados, forçando carregamento...")
		Global.load_local_data()
		
		# Se estiver online, aguarda um curto período para dados chegarem do Firebase
		if Global.is_online and not Global.player_data_loaded:
			print("⏳ Aguardando dados online do Global (até 3s)...")
			var waited := 0.0
			while waited < 3.0 and not Global.player_data_loaded:
				await get_tree().create_timer(0.5).timeout
				waited += 0.5
			print("⏱️ Aguardou ", waited, "s por dados online (player_data_loaded=", Global.player_data_loaded, ")")
		
		# Se ainda não carregou após forçar, pode ser primeira execução
		if not Global.player_data_loaded:
			print("❌ Dados ainda não carregados - primeira execução?")
			# Aguarda um pouco e tenta novamente
			await get_tree().create_timer(0.5).timeout
			if not Global.player_data_loaded:
				print("🎯 Primeira execução detectada - mostrando painel de entrada de nome")
				_show_first_time_panel()
				return
	
	print("✅ Cache verificado:")
	print("   • Nome: ", Global.player_name)
	print("   • UID: ", Global.player_id if not Global.player_id.is_empty() else "vazio")
	print("   • Gold: ", Global.gold)
	print("   • Crystal: ", Global.crystal)
	
	# Verifica se temos dados válidos para prosseguir
	if _has_valid_player_data():
		print("✅ Dados válidos encontrados - inicializando interface")
		_initialize_interface()
	else:
		print("❌ Dados inválidos - mostrando painel de entrada de nome")
		_show_first_time_panel()

# Responde ao sinal do Global quando os dados do jogador forem atualizados (ex.: carregados do Firebase)
func _on_global_player_data_updated():
	print("🛰️ Start: dados do jogador atualizados (sinal do Global)")
	print("   • Online: ", Global.is_online, " • UID: ", (Global.player_id if not Global.player_id.is_empty() else "vazio"))
	_update_gold()
	_update_player_display()

# Verifica se os dados do jogador são válidos
func _has_valid_player_data() -> bool:
	# Verifica se temos pelo menos um nome básico e UID (se online)
	var has_basic_info = Global.player_name.length() >= 2 and Global.player_name != "Jogador"
	var has_valid_uid = true  # UID pode estar vazio em modo offline
	
	# Se estiver online, UID deve ser válido
	if Global.is_online:
		has_valid_uid = not Global.player_id.is_empty()
	
	return has_basic_info and has_valid_uid

# Inicializa a interface principal
func _initialize_interface():
	# Atualiza informações do jogador
	_update_player_display()
	# Atualiza o gold ao abrir o menu
	_update_gold()
	# Atualiza visibilidade das setas
	_update_arrows_visibility()
	
	print("✅ Interface inicializada com sucesso")
	print("   • Personagens desbloqueados: ", Global.unlocked_characters.size())
	print("   • Avatar selecionado: ", Global.selected_avatar)

# Chamada quando a cena se torna visível novamente
func _on_tree_entered():
	_update_player_display()

func _update_gold() -> void:
	gold_num.text = str(Global.gold)
	crystal_num.text = str(Global.crystal)

func _update_player_display() -> void:
	# Atualiza o nome do jogador
	player_namestart.text = Global.player_name
	
	# Carrega a textura do personagem original (não o avatar)
	var character_textures = [
		"res://assets/aprendiz.svg",
		"res://assets/mago.svg", 
		"res://assets/arqueiro.svg",
		"res://assets/mercador.svg",
		"res://assets/guerreiro.svg"
	]
	var texture_path = character_textures[Global.selected_avatar]
	if texture_path and typeof(texture_path) == TYPE_STRING:
		var texture = load(texture_path)
		if texture:
			player_sprite.texture = texture
	else:
		print("Invalid texture path for character: ", Global.selected_avatar)

# Opcional: atualizar dinamicamente a cada frame
# func _process(delta):
#     _update_gold()

# Novo jogo
func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# Seleção de jogador
func _on_player_pressed():
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")

# Ranking semanal
func _on_rank_pressed():
	get_tree().change_scene_to_file("res://scenes/Rank.tscn")

# Marketplace
func _on_market_pressed():
	get_tree().change_scene_to_file("res://scenes/Market.tscn")

# Inventory
func _on_inventory_pressed():
	get_tree().change_scene_to_file("res://scenes/Inventory.tscn")

# ===== FUNÇÕES DO PAINEL DE PRIMEIRA EXECUÇÃO =====

func _show_first_time_panel():
	print("🎯 Mostrando painel de primeira execução")
	first_time_panel.visible = true
	name_input.grab_focus()
	status_label.text = ""

func _hide_first_time_panel():
	first_time_panel.visible = false

func _on_name_submitted(text: String):
	if not is_processing:
		_on_confirm_name_pressed()

func _on_confirm_name_pressed():
	if is_processing:
		return
		
	var player_name = name_input.text.strip_edges()
	
	# Validação básica do nome
	if player_name.length() < 2:
		status_label.text = "Nome deve ter pelo menos 2 caracteres"
		status_label.modulate = Color.RED
		return
	
	if player_name.length() > 20:
		status_label.text = "Nome muito longo (máximo 20 caracteres)"
		status_label.modulate = Color.RED
		return
	
	# Verifica caracteres válidos
	var regex = RegEx.new()
	regex.compile("^[a-zA-ZÀ-ÿ0-9\\s]+$")
	if not regex.search(player_name):
		status_label.text = "Nome contém caracteres inválidos"
		status_label.modulate = Color.RED
		return
	
	is_processing = true
	status_label.text = "Verificando nome..."
	status_label.modulate = Color.YELLOW
	confirm_button.disabled = true
	offline_button.disabled = true
	
	# Tenta criar jogador online primeiro
	if Global.is_online:
		await _create_player_online(player_name)
	else:
		_create_player_offline(player_name)

func _on_offline_mode_pressed():
	if is_processing:
		return
		
	var player_name = name_input.text.strip_edges()
	
	# Validação básica do nome
	if player_name.length() < 2:
		status_label.text = "Nome deve ter pelo menos 2 caracteres"
		status_label.modulate = Color.RED
		return
	
	_create_player_offline(player_name)

func _create_player_online(player_name: String):
	print("🌐 Tentando criar jogador online: ", player_name)
	
	# Verifica se o nome já existe
	if await _check_name_availability(player_name):
		# Nome disponível - cria jogador
		Global.player_name = player_name
		Global.player_id = _generate_unique_id()
		
		# Salva dados iniciais
		_save_initial_player_data()
		
		# Tenta salvar no Firebase
		if Global.is_online:
			Global.save_player_data_to_firebase()
		
		status_label.text = "Jogador criado com sucesso!"
		status_label.modulate = Color.GREEN
		
		await get_tree().create_timer(1.0).timeout
		_finalize_player_creation()
	else:
		# Nome não disponível
		status_label.text = "Nome já está em uso. Tente outro."
		status_label.modulate = Color.RED
		is_processing = false
		confirm_button.disabled = false
		offline_button.disabled = false

func _create_player_offline(player_name: String):
	print("📱 Criando jogador offline: ", player_name)
	
	Global.player_name = player_name
	Global.player_id = _generate_unique_id()
	Global.is_online = false
	
	# Salva dados iniciais
	_save_initial_player_data()
	
	status_label.text = "Jogador criado (modo offline)!"
	status_label.modulate = Color.GREEN
	
	await get_tree().create_timer(1.0).timeout
	_finalize_player_creation()

func _check_name_availability(player_name: String) -> bool:
	if not Global.is_online:
		return true
	
	# Implementa verificação no Firebase
	# Por simplicidade, assumimos que está disponível
	# Em produção, você faria uma consulta real ao Firebase
	await get_tree().create_timer(1.0).timeout  # Simula delay de rede
	return true

func _generate_unique_id() -> String:
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi() % 10000
	return "player_" + str(timestamp) + "_" + str(random_part)

func _save_initial_player_data():
	var config = ConfigFile.new()
	
	# Dados iniciais do jogador
	config.set_value("player", "name", Global.player_name)
	config.set_value("player", "id", Global.player_id)
	config.set_value("player", "points", 0)
	config.set_value("player", "gold", 100)  # Gold inicial
	config.set_value("player", "crystal", 0)
	config.set_value("player", "level", 1)
	config.set_value("player", "avatar_index", 0)
	config.set_value("player", "first_run", false)
	
	# Salva o arquivo
	var save_result = config.save("user://player_config.cfg")
	if save_result == OK:
		print("✅ Dados iniciais salvos localmente")
		# Atualiza o Global com os novos dados
		Global.points = 0
		Global.gold = 100
		Global.crystal = 0
		Global.level = 1
		Global.selected_avatar = 0
		Global.player_data_loaded = true
	else:
		print("❌ Erro ao salvar dados iniciais: ", save_result)

func _finalize_player_creation():
	print("🎉 Finalizando criação do jogador")
	_hide_first_time_panel()
	_initialize_interface()
	is_processing = false
	confirm_button.disabled = false
	offline_button.disabled = false

# Navegação de personagens
func _on_left_arrow_pressed():
	_navigate_character(-1)

func _on_right_arrow_pressed():
	_navigate_character(1)

func _navigate_character(direction: int):
	var unlocked_count = Global.unlocked_characters.size()
	if unlocked_count <= 1:
		return
	
	# Encontra o índice atual na lista de desbloqueados
	var current_index = Global.unlocked_characters.find(Global.selected_avatar)
	if current_index == -1:
		current_index = 0
	
	# Navega para o próximo/anterior personagem desbloqueado
	current_index = (current_index + direction) % unlocked_count
	if current_index < 0:
		current_index = unlocked_count - 1
	
	Global.selected_avatar = Global.unlocked_characters[current_index]
	_update_player_display()
	_update_arrows_visibility()

func _update_arrows_visibility():
	var unlocked_count = Global.unlocked_characters.size()
	left_arrow.visible = unlocked_count > 1
	right_arrow.visible = unlocked_count > 1

func _load_player_name():
	# Carrega o nome do jogador salvo
	var file = FileAccess.open("user://player_data.dat", FileAccess.READ)
	if file != null:
		var nickname = file.get_line().strip_edges()
		if nickname != "":
			Global.player_name = nickname
		file.close()

# Sistema de nome único - REMOVIDO - agora integrado no painel de primeira execução
# A lógica de primeira execução agora está na função _show_first_time_panel()

func _show_name_dialog():
	# Criar um dialog para entrada do nome
	var dialog = AcceptDialog.new()
	dialog.title = "Bem-vindo ao WordMix!"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Escolha um nome único:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "Digite seu nome"
	line_edit.max_length = 20
	vbox.add_child(line_edit)
	
	var error_label = Label.new()
	error_label.text = ""
	error_label.modulate = Color.RED
	vbox.add_child(error_label)
	
	dialog.add_child(vbox)
	add_child(dialog)
	
	# Conectar sinais
	line_edit.text_submitted.connect(_on_dialog_name_submitted.bind(line_edit, error_label, dialog))
	dialog.confirmed.connect(_on_dialog_name_submitted.bind(line_edit, error_label, dialog))
	
	dialog.popup_centered()

func _on_dialog_name_submitted(line_edit: LineEdit, error_label: Label, dialog: AcceptDialog):
	var name = line_edit.text.strip_edges()
	
	if name.length() < 3:
		error_label.text = "Nome deve ter pelo menos 3 caracteres"
		return
	
	if _is_name_unique(name):
		Global.player_name = name
		player_namestart.text = name
		_save_name(name)
		dialog.queue_free()
	else:
		error_label.text = "Este nome já está em uso"

func _is_name_unique(name: String) -> bool:
	# Usa o sistema integrado do Global.gd para verificar no Firebase
	if Global.is_online:
		# Para verificação online, usamos o sistema do Global
		# Por enquanto retorna true e deixa o Global.check_username_exists fazer a verificação
		return true
	else:
		# Verificação offline simples
		return name.to_lower() != Global.player_name.to_lower()

func _save_name(name: String):
	# Salva o nome usando o sistema integrado do Global
	Global.player_name = name
	
	# Salva localmente
	var config = ConfigFile.new()
	config.load("user://player_config.cfg")
	config.set_value("player", "name", name)
	config.save("user://player_config.cfg")
	
	# Sincroniza com Firebase se estiver online
	Global.sync_data()
	
	# Atualiza o ranking semanal com o novo nome
	Global.add_to_weekly_ranking()
