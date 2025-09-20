extends Control

@onready var name_input: LineEdit = $MainPanel/VBoxContainer/NameInputContainer/NameInput
@onready var confirm_button: Button = $MainPanel/VBoxContainer/ButtonContainer/ConfirmButton
@onready var error_label: Label = $MainPanel/VBoxContainer/ErrorLabel
@onready var loading_label: Label = $MainPanel/LoadingLabel
@onready var main_panel: Panel = $MainPanel

var is_processing = false

func _ready():
	# Conecta os sinais
	confirm_button.pressed.connect(_on_confirm_pressed)
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.text_changed.connect(_on_name_changed)
	
	# Foca no campo de entrada
	name_input.grab_focus()
	
	# Limpa mensagens de erro
	error_label.text = ""

func _on_name_changed(new_text: String):
	# Limpa erro quando o usuário digita
	error_label.text = ""
	
	# Habilita/desabilita botão baseado no texto
	confirm_button.disabled = new_text.strip_edges().length() < 2

func _on_name_submitted(text: String):
	# Permite envio com Enter
	if not confirm_button.disabled:
		_on_confirm_pressed()

func _on_confirm_pressed():
	if is_processing:
		return
	
	var player_name = name_input.text.strip_edges()
	
	# Validação do nome
	if not _validate_name(player_name):
		return
	
	# Verifica se o nome já existe
	_show_loading(true)
	Global.check_username_exists(player_name, _on_username_check_complete)

func _validate_name(name: String) -> bool:
	# Verifica se o nome não está vazio
	if name.length() < 2:
		_show_error("Nome deve ter pelo menos 2 caracteres")
		return false
	
	# Verifica se o nome não é muito longo
	if name.length() > 15:
		_show_error("Nome deve ter no máximo 15 caracteres")
		return false
	
	# Verifica caracteres válidos (letras, números, espaços e alguns símbolos)
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9À-ÿ\\s._-]+$")
	if not regex.search(name):
		_show_error("Nome contém caracteres inválidos")
		return false
	
	# Verifica se não é apenas espaços
	if name.replace(" ", "").length() == 0:
		_show_error("Nome não pode ser apenas espaços")
		return false
	
	return true

func _on_username_check_complete(username_exists: bool):
	print("🎯 Verificação de nome completa: ", ("existe" if username_exists else "disponível"))
	_show_loading(false)
	
	if username_exists:
		_show_error("Este nome já está em uso. Escolha outro nome.")
		name_input.grab_focus()
	else:
		# Nome disponível, prossegue com o salvamento
		var player_name = name_input.text.strip_edges()
		print("✅ Nome aprovado, salvando: ", player_name)
		_save_player_name(player_name)

func _show_error(message: String):
	error_label.text = message
	# Anima o erro
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 0.0, 0.0)
	tween.tween_property(error_label, "modulate:a", 1.0, 0.3)

func _save_player_name(player_name: String):
	is_processing = true
	_show_loading(true)
	
	# Salva o nome no Global
	Global.player_name = player_name
	
	# Verifica se já existe um player_id, se não, gera um novo
	# IMPORTANTE: Primeiro verifica se há um ID persistente disponível
	if Global.player_id.is_empty():
		# Tenta obter ID persistente se disponível
		if PersistentDataManager.has_method("get_persistent_player_id"):
			var persistent_id = PersistentDataManager.get_persistent_player_id()
			if not persistent_id.is_empty():
				Global.player_id = persistent_id
				print("Usando ID persistente existente: ", persistent_id.substr(0, 8) + "...")
			else:
				Global.player_id = _generate_player_id()
				print("Gerando novo ID: ", Global.player_id.substr(0, 8) + "...")
		else:
			Global.player_id = _generate_player_id()
			print("Gerando novo ID (fallback): ", Global.player_id.substr(0, 8) + "...")
	
	# Prepara dados do jogador para Firebase
	var player_data = {
		"name": player_name,
		"points": Global.points,
		"gold": Global.gold,
		"crystal": Global.crystal,
		"level": Global.level,
		"avatar_index": Global.selected_avatar_index,
		"created_at": Time.get_unix_time_from_system(),
		"last_updated": Time.get_unix_time_from_system()
	}
	
	# Salva no Firebase
	_sync_to_firebase(player_data)

func _generate_player_id() -> String:
	# Gera um ID único baseado no timestamp e um número aleatório
	var timestamp = Time.get_unix_time_from_system()
	var random_num = randi() % 10000
	return "player_" + str(timestamp) + "_" + str(random_num)

func _sync_to_firebase(player_data: Dictionary):
	# Usa o sistema existente do Global para sincronizar
	if Global.firebase_reference:
		# Salva os dados do jogador
		var player_ref = Global.firebase_reference.child("players").child(Global.player_id)
		player_ref.update("", player_data)
		
		# Adiciona ao ranking semanal
		_add_to_weekly_ranking(player_data)
		
		# Aguarda um pouco para simular sincronização
		await get_tree().create_timer(1.5).timeout
		
		# Salva localmente também
		_save_locally()
		
		# Vai para a tela principal
		_go_to_main_menu()
	else:
		# Se não conseguir conectar ao Firebase, salva localmente e continua
		print("⚠️ Firebase não disponível - salvando apenas localmente")
		_save_locally()
		await get_tree().create_timer(1.0).timeout
		_go_to_main_menu()

func _add_to_weekly_ranking(player_data: Dictionary):
	# Adiciona o jogador ao ranking semanal
	if Global.firebase_reference:
		var ranking_data = {
			"player_id": Global.player_id,
			"name": player_data["name"],
			"points": player_data["points"],
			"avatar_index": player_data["avatar_index"],
			"timestamp": Time.get_unix_time_from_system()
		}
		
		# Calcula a semana atual (baseado no sistema do rank.gd)
		var current_time = Time.get_unix_time_from_system()
		var week_start = (current_time / (7 * 24 * 3600)) as int
		
		var weekly_ref = Global.firebase_reference.child("weekly_rankings").child(str(week_start)).child(Global.player_id)
		weekly_ref.update("", ranking_data)

func _save_locally():
	# Salva as configurações localmente
	var config = ConfigFile.new()
	
	# Carrega arquivo existente ou cria novo
	var err = config.load("user://player_config.cfg")
	
	# Salva dados do jogador
	config.set_value("player", "name", Global.player_name)
	config.set_value("player", "id", Global.player_id)
	config.set_value("player", "points", Global.points)
	config.set_value("player", "gold", Global.gold)
	config.set_value("player", "crystal", Global.crystal)
	config.set_value("player", "level", Global.level)
	config.set_value("player", "avatar_index", Global.selected_avatar_index)
	config.set_value("player", "first_run", false)
	
	# Salva o arquivo
	var save_result = config.save("user://player_config.cfg")
	if save_result == OK:
		print("✅ Dados salvos localmente com sucesso")
		# Força o Global a recarregar os dados para sincronizar
		Global.load_local_data()
	else:
		print("❌ Erro ao salvar dados localmente: ", save_result)

func _show_loading(show: bool):
	loading_label.visible = show
	main_panel.modulate.a = 0.7 if show else 1.0
	confirm_button.disabled = show
	name_input.editable = not show

func _go_to_main_menu():
	print("🚀 Iniciando transição para menu principal...")
	is_processing = false
	_show_loading(false)
	
	# Transição suave para o menu principal
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	print("🎯 Mudando para Start.tscn...")
	# Muda para a cena principal
	var result = get_tree().change_scene_to_file("res://scenes/Start.tscn")
	if result != OK:
		print("❌ Erro ao mudar para Start.tscn: ", result)
	else:
		print("✅ Transição para Start.tscn iniciada")

# Função para pular a entrada de nome (para testes)
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1: # F1 para pular (apenas para desenvolvimento)
			Global.player_name = "Jogador_" + str(randi() % 1000)
			Global.player_id = _generate_player_id()
			_save_locally()
			_go_to_main_menu()
		elif event.keycode == KEY_F2: # F2 para testar o botão automaticamente
			print("🧪 TESTE AUTOMÁTICO DO BOTÃO INICIADO")
			var test_name = "TestUser" + str(randi() % 1000)
			name_input.text = test_name
			print("   • Nome de teste: ", test_name)
			print("   • Simulando clique no botão...")
			_on_confirm_pressed()
