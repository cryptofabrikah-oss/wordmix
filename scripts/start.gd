extends Control

# TopBar
@onready var gold_line = $TopBar/gold_line
@onready var crystal_line = $TopBar/crystal_line
@onready var gold_num: Label = $TopBar/gold_line/gold_num  # Label que mostra o gold
@onready var crystal_num: Label = $TopBar/crystal_line/crystal_num  # Label que mostra o crystal
# CharacterPanel
@onready var left_arrow = $CharacterPanel/CharacterContainer/LeftArrow
@onready var right_arrow = $CharacterPanel/CharacterContainer/RightArrow
@onready var start_btn = $StartB
@onready var player_sprite = $CharacterPanel/CharacterContainer/CenterBox/PlayerSprite
@onready var player_namestart = $CharacterPanel/CharacterContainer/CenterBox/PlayerNameContainer/PlayerName
@onready var player_name_input = $CharacterPanel/CharacterContainer/CenterBox/PlayerNameContainer/PlayerNameInput
@onready var confirm_name_button = $CharacterPanel/CharacterContainer/CenterBox/PlayerNameContainer/ConfirmNameButton
# BottomBar
@onready var market_btn = $BottonBar/Market
@onready var inventory_btn = $BottonBar/Inventory
# Player Level
@onready var player_level_label = $PlayerLevelLabel

# Variáveis de controle
var is_first_run: bool = false
var is_processing_name: bool = false

func _ready():
	print("🏠 Iniciando cena Start - Verificação de cache...")
	
	# Conecta os sinais
	market_btn.pressed.connect(_on_market_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	
	# Conecta sinais do sistema de entrada de nome
	confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	player_name_input.text_submitted.connect(_on_name_text_submitted)
	
	# Conecta sinal para atualizar quando retornar à cena
	if not tree_entered.is_connected(_on_tree_entered):
		tree_entered.connect(_on_tree_entered)
		print("🔔 Start: conectado ao sinal tree_entered")
	
	# Atualiza informações do jogador quando dados chegarem
	if not Global.player_data_updated.is_connected(_on_global_player_data_updated):
		Global.player_data_updated.connect(_on_global_player_data_updated)
		print("🔔 Start: conectado ao sinal Global.player_data_updated")
	
	# Sistema robusto de verificação de cache
	_check_cache_and_initialize()

# Verifica cache e inicializa a interface
func _check_cache_and_initialize():
	print("🔍 Verificando cache local e inicializando interface...")
	
	# Verifica se é primeira execução
	is_first_run = Global.is_first_run()
	print("🆕 Primeira execução: ", is_first_run)
	
	# Se não há dados carregados, aguarda ou carrega localmente
	if not Global.player_data_loaded:
		print("⏳ Aguardando carregamento de dados...")
		# Tenta carregar dados locais primeiro
		Global.load_local_data()
		
		# Aguarda um pouco para dados locais carregarem
		var timeout = 1.0
		var elapsed = 0.0
		while not Global.player_data_loaded and elapsed < timeout:
			await get_tree().process_frame
			elapsed += get_tree().process_frame
		
		# Se ainda não carregou e é primeira execução, configura interface para entrada de nome
		if not Global.player_data_loaded and is_first_run:
			print("🆕 Primeira execução detectada - configurando entrada de nome")
			_setup_first_run_interface()
			return
	
	# Se tem dados válidos, inicializa interface normalmente
	if _has_valid_player_data():
		print("✅ Dados válidos encontrados - inicializando interface")
		_initialize_interface()
	else:
		print("❌ Dados inválidos - configurando entrada de nome")
		_setup_first_run_interface()

# Responde ao sinal do Global quando os dados do jogador forem atualizados
func _on_global_player_data_updated():
	print("🛰️ Start: dados do jogador atualizados (sinal do Global)")
	_update_gold()
	_update_player_display()

# Verifica se os dados do jogador são válidos
func _has_valid_player_data() -> bool:
	# Se não é primeira execução e os dados foram carregados, considera válido
	if not Global.is_first_run() and Global.player_data_loaded:
		print("✅ Dados válidos: não é primeira execução e dados carregados")
		return true
	
	# Para primeira execução, verifica se tem nome personalizado
	var has_custom_name = Global.player_name.length() >= 2 and Global.player_name != "Jogador"
	
	print("🔍 Validação de dados:")
	print("   - Primeira execução: ", Global.is_first_run())
	print("   - Dados carregados: ", Global.player_data_loaded)
	print("   - Nome personalizado: ", has_custom_name)
	print("   - Nome atual: ", Global.player_name)
	
	return has_custom_name

# Inicializa a interface principal
func _initialize_interface():
	print("🎨 Inicializando interface com dados válidos...")
	
	# Aguarda um frame para garantir que os nós estejam prontos
	await get_tree().process_frame
	
	# Atualiza informações do jogador
	_update_player_display()
	# Atualiza o gold ao abrir o menu
	_update_gold()
	# Atualiza o nível do jogador
	_update_player_level()
	# Atualiza visibilidade das setas
	_update_arrows_visibility()
	
	print("✅ Interface inicializada com sucesso")

# Adiciona função para ser chamada quando a cena se torna visível
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		print("🔄 Start: cena tornou-se visível - atualizando interface")
		_update_gold()
		_update_player_display()
	
# Configura interface para primeira execução (sem entrada de nome)
func _setup_first_run_interface():
	print("🆕 Configurando interface para primeira execução - carregamento automático")
	
	# APENAS configura valores padrão se realmente não existem dados salvos
	if Global.player_name == "Jogador" and Global.gold == 0 and Global.level == 1:
		print("🔧 Aplicando valores padrão para primeira execução")
		# Configura valores padrão do jogador para primeira execução
		Global.player_name = "Jogador"  # Mantém nome padrão
		Global.gold = 100  # Inicia com 100 de ouro (valor padrão)
		Global.crystal = 0  # Inicia com 0 cristais
		Global.selected_avatar = 0  # Personagem padrão (Aprendiz)
		Global.unlocked_characters = [0]  # Apenas Aprendiz desbloqueado
		Global.level = 1  # Nível inicial
		Global.correct_answers = 0  # Contador de acertos zerado
		
		# Gera ID se necessário
		if Global.player_id.is_empty():
			var rng = RandomNumberGenerator.new()
			rng.randomize()
			Global.player_id = "player_" + str(rng.randi_range(100000, 999999))
		
		# Salva dados localmente
		Global.save_local_data()
	else:
		print("📊 Dados existentes detectados - mantendo valores atuais")
		print("   - Nome: ", Global.player_name)
		print("   - Gold: ", Global.gold)
		print("   - Level: ", Global.level)
	
	# Inicializa interface normalmente (sem entrada de nome)
	_initialize_interface()
	
	print("✅ Primeira execução configurada automaticamente")

# Processa confirmação do nome
func _on_confirm_name_pressed():
	_process_name_confirmation()

# Processa submissão do nome via Enter
func _on_name_text_submitted(text: String):
	_process_name_confirmation()

# Lógica principal de confirmação do nome
func _process_name_confirmation():
	if is_processing_name:
		return
		
	var name_text = player_name_input.text.strip_edges()
	
	# Validação do nome
	if name_text.length() < 2:
		_show_name_error("Nome deve ter pelo menos 2 caracteres")
		return
	
	if name_text.length() > 15:
		_show_name_error("Nome deve ter no máximo 15 caracteres")
		return
	
	# Verifica caracteres válidos (letras, números, espaços)
	var regex = RegEx.new()
	regex.compile("^[a-zA-ZÀ-ÿ0-9\\s]+$")
	if not regex.search(name_text):
		_show_name_error("Nome contém caracteres inválidos")
		return
	
	is_processing_name = true
	confirm_name_button.disabled = true
	confirm_name_button.text = "SALVANDO..."
	
	# Salva o nome no Global
	Global.player_name = name_text
	
	# Gera ID se necessário
	if Global.player_id.is_empty():
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		Global.player_id = "player_" + str(rng.randi_range(100000, 999999))
	
	# Salva dados localmente
	Global.save_local_data()
	
	# Finaliza configuração
	_finalize_name_setup()

# Mostra erro de validação do nome
func _show_name_error(message: String):
	print("❌ Erro na validação do nome: ", message)
	# Aqui você pode adicionar um toast ou label de erro se desejar
	player_name_input.modulate = Color.RED
	await get_tree().create_timer(0.5).timeout
	player_name_input.modulate = Color.WHITE

# Finaliza configuração do nome e ativa interface principal
func _finalize_name_setup():
	print("✅ Nome configurado com sucesso: ", Global.player_name)
	
	# Oculta elementos de entrada e mostra nome
	player_name_input.visible = false
	confirm_name_button.visible = false
	player_namestart.visible = true
	
	# Reabilita botões
	start_btn.disabled = false
	left_arrow.disabled = false
	right_arrow.disabled = false
	market_btn.disabled = false
	inventory_btn.disabled = false
	
	# Atualiza interface
	_initialize_interface()
	
	# Reset variáveis de controle
	is_processing_name = false
	is_first_run = false

# Chamada quando a cena se torna visível novamente
func _on_tree_entered():
	print("🔄 Start: _on_tree_entered chamado - atualizando interface completa")
	# Aguarda um frame para garantir que os nós estejam prontos
	await get_tree().process_frame
	_update_player_display()
	_update_gold()
	_update_player_level()

func _update_gold() -> void:
	# Verifica se os nós estão prontos antes de atualizar
	if not gold_num or not crystal_num:
		print("⚠️ Nós de gold/crystal ainda não estão prontos")
		return
		
	print("💰 Atualizando exibição - Gold: %d, Crystal: %d" % [Global.gold, Global.crystal])
	gold_num.text = str(Global.gold)
	crystal_num.text = str(Global.crystal)

func _update_player_level() -> void:
	var current_difficulty = Global.get_difficulty_for_level(Global.level)
	player_level_label.text = "NIVEL " + str(Global.level)

func _update_player_display() -> void:
	# Verifica se os nós estão prontos antes de atualizar
	if not player_sprite or not player_namestart:
		print("⚠️ Nós de player ainda não estão prontos")
		return
		
	# Exibe apenas o nome do personagem selecionado (sem "Jogador")
	player_namestart.text = Global.avatar_names[Global.selected_avatar]
	
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

# Marketplace
func _on_market_pressed():
	get_tree().change_scene_to_file("res://scenes/Market.tscn")

# Inventory
func _on_inventory_pressed():
	get_tree().change_scene_to_file("res://scenes/Inventory.tscn")

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

# Sistema de nome único (DEPRECATED - agora gerenciado inline)
func _check_first_run():
	# Esta função não é mais necessária - entrada de nome é gerenciada inline
	print("⚠️ _check_first_run() está deprecated - usando sistema inline")

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
	line_edit.text_submitted.connect(_on_name_submitted.bind(line_edit, error_label, dialog))
	dialog.confirmed.connect(_on_name_submitted.bind(line_edit, error_label, dialog))
	
	dialog.popup_centered()

func _on_name_submitted(line_edit: LineEdit, error_label: Label, dialog: AcceptDialog):
	var name = line_edit.text.strip_edges()
	
	if name.length() < 3:
		error_label.text = "Nome deve ter pelo menos 3 caracteres"
		return
	
	if _is_name_unique(name):
		Global.player_name = name
		player_namestart.text = Global.avatar_names[Global.selected_avatar]  # Exibe nome do personagem
		_save_name(name)
		dialog.queue_free()
	else:
		error_label.text = "Este nome já está em uso"

func _is_name_unique(name: String) -> bool:
	# Verificação local de nome único
	return name.to_lower() != Global.player_name.to_lower()

func _save_name(name: String):
	# Salva o nome usando o sistema integrado do Global
	Global.player_name = name
	
	# Salva localmente
	var config = ConfigFile.new()
	config.load("user://player_config.cfg")
	config.set_value("player", "name", name)
	config.save("user://player_config.cfg")
	
	# Salva dados localmente
	Global.save_local_data()
