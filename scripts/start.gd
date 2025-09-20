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
@onready var rank_btn = $BottonBar/Rank
@onready var inventory_btn = $BottonBar/Inventory

# Variáveis de controle
var is_first_run: bool = false
var is_processing_name: bool = false

func _ready():
	print("🏠 Iniciando cena Start - Verificação de cache...")
	
	# Conecta os sinais
	market_btn.pressed.connect(_on_market_pressed)
	rank_btn.pressed.connect(_on_rank_pressed)
	inventory_btn.pressed.connect(_on_inventory_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	left_arrow.pressed.connect(_on_left_arrow_pressed)
	right_arrow.pressed.connect(_on_right_arrow_pressed)
	
	# Conecta sinais do sistema de entrada de nome
	confirm_name_button.pressed.connect(_on_confirm_name_pressed)
	player_name_input.text_submitted.connect(_on_name_text_submitted)
	
	# Ouve atualizações vindas do Global para refletir dados online quando chegarem
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
		
		# Aguarda um pouco para dados do Firebase se disponível
		var timeout = 3.0
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
	
# Configura interface para primeira execução (entrada de nome)
func _setup_first_run_interface():
	print("🆕 Configurando interface para primeira execução")
	
	# Oculta o label do nome e mostra os elementos de entrada
	player_namestart.visible = false
	player_name_input.visible = true
	confirm_name_button.visible = true
	
	# Desabilita botões principais durante entrada de nome
	start_btn.disabled = true
	left_arrow.disabled = true
	right_arrow.disabled = true
	market_btn.disabled = true
	rank_btn.disabled = true
	inventory_btn.disabled = true
	
	# Foca no campo de entrada
	player_name_input.grab_focus()
	
	# Configura valores padrão
	_update_gold()
	_update_arrows_visibility()

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
		Global.player_id = Global.generate_unique_id()
	
	# Salva dados localmente
	Global.save_local_data()
	
	# Tenta sincronizar com Firebase se online
	if Global.is_online:
		Global.sync_with_firebase_robust()
	
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
	rank_btn.disabled = false
	inventory_btn.disabled = false
	
	# Atualiza interface
	_initialize_interface()
	
	# Reset variáveis de controle
	is_processing_name = false
	is_first_run = false

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
