extends Control

@onready var ranking_list = $Mainpanel/ScrollContainer/playerslist
@onready var backb = $Mainpanel/backb
@onready var time_left_label = $Mainpanel/TimeLeft

# Timer para atualizar o relógio
var update_timer: Timer

# Sistema de ranking semanal
var week_start_time: float
var week_duration: float = 7.0 * 24.0 * 60.0 * 60.0  # 7 dias em segundos
var crystal_rewards = {1: 50, 2: 30, 3: 20}  # Premiações especiais para top 3 (reduzidas 10x)
var default_reward = 5  # Premiação para posições 4-50 (reduzida 10x)

# Dados do ranking em tempo real
var ranking_data: Array = []
var firebase_ranking_ref = null
var firebase_players_ref = null
var is_listening_to_updates: bool = false
var is_listening_to_players: bool = false
var all_players_data: Dictionary = {}
var last_sync_timestamp: float = 0.0

func _ready():
	backb.pressed.connect(_on_back_pressed)
	# Inicializa o sistema semanal
	init_weekly_system()
	
	# Configura timer para atualizar o relógio a cada minuto
	update_timer = Timer.new()
	update_timer.wait_time = 60.0  # Atualiza a cada 60 segundos
	update_timer.timeout.connect(update_time_display)
	update_timer.autostart = true
	add_child(update_timer)
	
	# Conecta ao sinal de atualização de dados globais para reagir quando login/dados chegarem
	if not Global.player_data_updated.is_connected(_on_global_player_data_updated):
		Global.player_data_updated.connect(_on_global_player_data_updated)
		print("🔔 Rank: conectado ao sinal Global.player_data_updated")
	
	# Estilo do botão backb (igual às linhas)
	var backb_style = StyleBoxFlat.new()
	backb_style.bg_color = Color.hex(0x100101FF)      # fundo vermelho quase preto
	backb_style.border_color = Color(1, 0.84, 0)   # borda dourada
	backb_style.set_border_width_all(5)
	backb_style.set_corner_radius_all(10)
	
	# Aplica ao botão em todos os estados
	backb.add_theme_stylebox_override("normal", backb_style)
	backb.add_theme_stylebox_override("hover", backb_style)
	backb.add_theme_stylebox_override("pressed", backb_style)
	backb.add_theme_stylebox_override("disabled", backb_style)
	
	var style = StyleBoxFlat.new()
	style.border_color = Color(1, 0.84, 0)   # borda dourada
	style.set_border_width_all(5)              # bordas arredondadas
	style.set_corner_radius_all(8)
	style.bg_color = Color8(40, 20, 0, 255)  # laranja escuro sólido
	
	$Mainpanel.add_theme_stylebox_override("panel", style)
	
	# Inicia o carregamento completo dos dados do Firebase
	load_all_players_data()
	load_firebase_ranking()
	update_time_display()
	

func compare_players(a, b) -> bool:
	return a["score"] > b["score"]  # ordena do maior para o menor

func _on_back_pressed():
	# Limpa todas as conexões com o Firebase antes de sair
	cleanup_firebase_connections()
	get_tree().change_scene_to_file("res://scenes/Start.tscn")

func _exit_tree():
	# Garante que todas as conexões são limpas quando a cena é removida
	cleanup_firebase_connections()
	# Desconecta do sinal global
	if Global.player_data_updated.is_connected(_on_global_player_data_updated):
		Global.player_data_updated.disconnect(_on_global_player_data_updated)

func cleanup_firebase_connections():
	# Limpa conexão do ranking
	if firebase_ranking_ref and is_listening_to_updates:
		firebase_ranking_ref.stop_listening()
		is_listening_to_updates = false
		print("🔌 Parando escuta de atualizações do ranking")
	
	# Limpa conexão dos dados dos jogadores
	if firebase_players_ref and is_listening_to_players:
		firebase_players_ref.stop_listening()
		is_listening_to_players = false
		print("🔌 Parando escuta de dados dos jogadores")

func _on_global_player_data_updated():
	print("🛰️ Rank: dados globais atualizados. Online=", Global.is_online, " UID=", (Global.player_id if not Global.player_id.is_empty() else "vazio"))
	# Se login/DB prontos, recarrega do Firebase, senão atualiza visão offline
	if Global.is_online and Global.firebase_reference:
		load_firebase_ranking()
	else:
		_ensure_current_player_in_ranking()
		ranking_data.sort_custom(func(a, b): return a["score"] > b["score"])
		update_ranking()

func update_ranking():
	# Limpa a lista antes de recriar
	for child in ranking_list.get_children():
		child.queue_free()
	
	ranking_list.add_theme_constant_override("separation", 15)
	
	# Atualiza timestamp da última sincronização
	last_sync_timestamp = Time.get_ticks_msec() / 1000.0
	
	# Indicador removido conforme solicitação do usuário
	
	# Adiciona separador
	var separator = HSeparator.new()
	separator.custom_minimum_size = Vector2(0, 10)
	ranking_list.add_child(separator)
	
	var pos = 1
	var player_position = -1
	
	for player in ranking_data:
		# Verifica se é o jogador atual
		var is_current_player = (player.get("player_id", "") == Global.player_id or player["name"] == Global.player_name)
		if is_current_player:
			player_position = pos
		
		# Cada linha vai ser um PanelContainer (pra poder ter fundo)
		var row_panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		
		# Destaca o jogador atual com cores diferentes
		if is_current_player:
			style.bg_color = Color.hex(0x1a4d1aFF) # fundo verde escuro para o jogador atual
			style.border_color = Color(0, 1, 0.5) # borda verde brilhante
			style.set_border_width_all(8) # borda mais grossa
		else:
			style.bg_color = Color.hex(0x100101FF) # fundo escuro vermelho
			style.border_color = Color(1, 0.84, 0) # borda dourada
			style.set_border_width_all(5)
		
		style.set_corner_radius_all(10)
		style.set_expand_margin_all(5)
		row_panel.add_theme_stylebox_override("panel", style)
		
		# HBox dentro do Panel
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		# Adiciona margens internas
		row.add_theme_constant_override("margin_left", 7)
		row.add_theme_constant_override("margin_right", 7)
		row.add_theme_constant_override("margin_top", 5)
		row.add_theme_constant_override("margin_bottom", 5)
		
		# Posição
		var pos_lbl = Label.new()
		pos_lbl.text = str(pos)
		pos_lbl.custom_minimum_size = Vector2(40, 0)
		pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_make_lbl_style(pos_lbl, Color(1, 0.84, 0)) # dourado
		row.add_child(pos_lbl)

		# Avatar
		var avatar = TextureRect.new()
		# Carrega a textura do avatar baseada no jogador
		if player.has("avatar"):
			var texture = load(player["avatar"])
			if texture:
				avatar.texture = texture
		avatar.custom_minimum_size = Vector2(32, 32)
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(avatar)

		# Container vertical para nome e informações
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Nome
		var name_lbl = Label.new()
		name_lbl.text = player["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_make_lbl_style(name_lbl, Color(1, 0.84, 0))
		vbox.add_child(name_lbl)
		
		# Informações adicionais (nível, cristais, última atividade)
		var info_text = ""
		if player.has("level"):
			info_text += "Nível " + str(player["level"])
		if player.has("crystals"):
			info_text += " • " + str(player["crystals"]) + " 💎"
		if player.has("last_active") and player["last_active"] != "":
			info_text += " • Ativo: " + str(player["last_active"])
		
		if info_text != "":
			var info_lbl = Label.new()
			info_lbl.text = info_text
			info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			info_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
			vbox.add_child(info_lbl)
		
		row.add_child(vbox)

		# Score
		var score_lbl = Label.new()
		score_lbl.text = str(player["score"])
		score_lbl.custom_minimum_size = Vector2(80, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_make_lbl_style(score_lbl, Color(1, 0.84, 0))
		row.add_child(score_lbl)

		# Cristais que o jogador vai ganhar
		var reward = 0
		if pos <= 3 and crystal_rewards.has(pos):
			reward = crystal_rewards[pos]
		else:
			reward = default_reward
		
		var crystal_lbl = Label.new()
		crystal_lbl.text = "+" + str(reward) + "💎"
		crystal_lbl.custom_minimum_size = Vector2(60, 0)
		crystal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_make_lbl_style(crystal_lbl, Color(0.4, 0.8, 1.0))  # azul cristal
		row.add_child(crystal_lbl)

		# Monta linha
		row_panel.add_child(row)
		ranking_list.add_child(row_panel)
		pos += 1
	
	print("📊 Interface do ranking atualizada com ", ranking_data.size(), " jogadores")

func _make_lbl_style(lbl: Label, color: Color) -> void:
	lbl.add_theme_color_override("font_color", color)

func init_weekly_system():
	# Inicializa ou recupera o tempo de início da semana
	if not Global.has_method("get_week_start_time"):
		week_start_time = Time.get_unix_time_from_system() as float
	else:
		week_start_time = Global.get_week_start_time() as float



func load_firebase_ranking():
	if not Global.firebase_reference:
		print("Firebase não disponível, usando dados locais")
		# Se offline, usa dados locais e mostra ranking básico
		_ensure_current_player_in_ranking()
		ranking_data.sort_custom(func(a, b): return a["score"] > b["score"])
		update_ranking()
		return
	
	# Calcula a semana atual
	var current_time = Time.get_unix_time_from_system()
	var week_start = (current_time / (7 * 24 * 3600)) as int
	
	# Referência para o ranking semanal
	firebase_ranking_ref = Global.firebase_reference.child("weekly_rankings").child(str(week_start))
	
	# Conecta ao sinal de dados recebidos para atualizações em tempo real
	if not firebase_ranking_ref.new_data_update.is_connected(_on_firebase_ranking_loaded):
		firebase_ranking_ref.new_data_update.connect(_on_firebase_ranking_loaded)
	
	# Conecta ao sinal de atualizações parciais em tempo real
	if not firebase_ranking_ref.patch_data_update.is_connected(_on_firebase_ranking_updated):
		firebase_ranking_ref.patch_data_update.connect(_on_firebase_ranking_updated)
	
	# Configura escuta em tempo real para mudanças
	if not is_listening_to_updates:
		firebase_ranking_ref.listen_to_changes()
		is_listening_to_updates = true
		print("🔊 Escutando atualizações em tempo real do ranking")
	
	# Solicita os dados iniciais
	firebase_ranking_ref.get_data()

# Carrega todos os dados dos jogadores do Firebase
func load_all_players_data():
	if not Global.firebase_reference:
		print("❌ Firebase Database não disponível para carregar dados dos jogadores")
		return
	
	print("📊 Carregando todos os dados dos jogadores do Firebase...")
	
	# Cria referência para todos os jogadores
	firebase_players_ref = Global.firebase_reference.child("players")
	
	if firebase_players_ref:
		# Conecta aos sinais para receber dados
		if not firebase_players_ref.new_data_update.is_connected(_on_all_players_data_loaded):
			firebase_players_ref.new_data_update.connect(_on_all_players_data_loaded)
		
		if not firebase_players_ref.patch_data_update.is_connected(_on_player_data_updated):
			firebase_players_ref.patch_data_update.connect(_on_player_data_updated)
		
		# Inicia escuta em tempo real
		firebase_players_ref.listen()
		is_listening_to_players = true
		print("🔊 Iniciando escuta em tempo real dos dados dos jogadores")
		
		# Solicita dados iniciais
		firebase_players_ref.get_data()
	else:
		print("❌ Erro ao criar referência para dados dos jogadores")

# Callback quando todos os dados dos jogadores são carregados
func _on_all_players_data_loaded(data):
	if data == null:
		print("⚠️ Nenhum dado de jogadores encontrado no Firebase")
		all_players_data = {}
		return
	
	print("✅ Dados de todos os jogadores carregados: ", data.size(), " jogadores")
	all_players_data = data
	last_sync_timestamp = Time.get_ticks_msec() / 1000.0
	
	# Atualiza o ranking com os novos dados
	update_ranking_with_all_data()

# Callback quando dados de um jogador específico são atualizados
func _on_player_data_updated(data):
	if data == null:
		return
	
	print("🔄 Dados de jogador atualizados em tempo real: ", data.keys())
	
	# Atualiza os dados locais
	for player_id in data.keys():
		all_players_data[player_id] = data[player_id]
	
	last_sync_timestamp = Time.get_ticks_msec() / 1000.0
	
	# Atualiza o ranking se necessário
	update_ranking_with_all_data()

# Atualiza o ranking usando todos os dados dos jogadores
func update_ranking_with_all_data():
	if all_players_data.is_empty():
		print("⚠️ Nenhum dado de jogadores disponível para atualizar ranking")
		return
	
	# Converte dados dos jogadores para formato do ranking
	var updated_ranking = []
	
	for player_id in all_players_data.keys():
		var player_data = all_players_data[player_id]
		
		# Verifica se o jogador tem dados válidos
		if player_data.has("name") and player_data.has("score"):
			var ranking_entry = {
				"name": player_data.get("name", "Jogador"),
				"score": player_data.get("score", 0),
				"level": player_data.get("level", 1),
				"avatar": player_data.get("avatar", 0),
				"crystals": player_data.get("crystals", 0),
				"player_id": player_id,
				"last_active": player_data.get("last_active", "")
			}
			updated_ranking.append(ranking_entry)
	
	# Ordena por pontuação
	updated_ranking.sort_custom(compare_players)
	
	# Atualiza dados do ranking
	ranking_data = updated_ranking
	
	print("📈 Ranking atualizado com ", ranking_data.size(), " jogadores")
	
	# Atualiza a interface
	update_ranking()

# Callback quando dados do ranking são atualizados em tempo real
func _on_firebase_ranking_updated(data):
	if data == null:
		return
	
	print("🔄 Ranking atualizado em tempo real")
	_on_firebase_ranking_loaded(data)

func _on_firebase_ranking_loaded(data):
	if data == null:
		print("⚠️ Nenhum dado de ranking encontrado no Firebase")
		# Mesmo sem dados, garante que o jogador atual está presente
		_ensure_current_player_in_ranking()
		ranking_data.sort_custom(compare_players)
		update_ranking()
		return
	
	print("✅ Dados do ranking carregados do Firebase: ", data.size(), " jogadores")
	ranking_data.clear()
	
	# Converte os dados do Firebase para o formato local
	for player_id in data.keys():
		var player_data = data[player_id]
		if player_data.has("name") and player_data.has("points"):
			var avatar_index = player_data.get("avatar_index", 0)
			# Garante que o índice do avatar está dentro dos limites
			if avatar_index >= Global.avatar_textures.size():
				avatar_index = 0
			
			ranking_data.append({
				"name": player_data["name"],
				"score": player_data["points"],
				"avatar": Global.avatar_textures[avatar_index],
				"player_id": player_id,
				"level": player_data.get("level", 1),
				"crystals": player_data.get("crystals", 0),
				"last_active": player_data.get("last_active", "")
			})
	
	# Mescla com dados completos dos jogadores se disponível
	merge_with_all_players_data()
	
	# Garante que o jogador atual está no ranking
	_ensure_current_player_in_ranking()
	
	# Ordena por pontuação
	ranking_data.sort_custom(compare_players)
	
	# Atualiza a interface
	update_ranking()

# Mescla dados do ranking com dados completos dos jogadores
func merge_with_all_players_data():
	if all_players_data.is_empty():
		return
	
	for i in range(ranking_data.size()):
		var ranking_entry = ranking_data[i]
		var player_id = ranking_entry.get("player_id", "")
		
		if player_id != "" and all_players_data.has(player_id):
			var complete_data = all_players_data[player_id]
			# Atualiza com dados mais completos
			ranking_entry["level"] = complete_data.get("level", ranking_entry.get("level", 1))
			ranking_entry["crystals"] = complete_data.get("crystals", ranking_entry.get("crystals", 0))
			ranking_entry["last_active"] = complete_data.get("last_active", ranking_entry.get("last_active", ""))
			ranking_entry["name"] = complete_data.get("name", ranking_entry.get("name", "Jogador"))
			ranking_entry["score"] = complete_data.get("score", ranking_entry.get("score", 0))
			
			ranking_data[i] = ranking_entry

func _ensure_current_player_in_ranking():
	# Garante que o jogador atual está no ranking
	var player_found = false
	for player in ranking_data:
		if player.get("player_id", "") == Global.player_id or player["name"] == Global.player_name:
			player_found = true
			# Atualiza os dados do jogador atual
			player["name"] = Global.player_name
			player["score"] = Global.points
			player["avatar"] = Global.avatar_textures[Global.selected_avatar_index]
			player["player_id"] = Global.player_id
			break
	
	# Se o jogador atual não foi encontrado, adiciona ele
	if not player_found:
		ranking_data.append({
			"name": Global.player_name,
			"score": Global.points,
			"avatar": Global.avatar_textures[Global.selected_avatar_index],
			"player_id": Global.player_id
		})

func update_time_display():
	var current_time: float = Time.get_unix_time_from_system()
	var elapsed_time: float = current_time - week_start_time
	var remaining_time: float = week_duration - elapsed_time
	
	if remaining_time <= 0.0:
		# Semana acabou, distribui premios e reinicia
		distribute_rewards()
		week_start_time = current_time
		remaining_time = week_duration
	
	var days: int = int(remaining_time / (24.0 * 60.0 * 60.0))
	var hours: int = int(fmod(remaining_time, 24.0 * 60.0 * 60.0) / (60.0 * 60.0))
	var minutes: int = int(fmod(remaining_time, 60.0 * 60.0) / 60.0)
	
	time_left_label.text = "Tempo restante: %dd %dh %dm" % [days, hours, minutes]

func distribute_rewards():
	# Distribui cristais baseado na posicao no ranking
	for i in range(min(ranking_data.size(), 50)):
		var player_data = ranking_data[i]
		var reward = 0
		
		if i + 1 <= 3 and crystal_rewards.has(i + 1):
			reward = crystal_rewards[i + 1]
		else:
			reward = default_reward
		
		# Se for o jogador atual, adiciona os cristais
		if player_data["name"] == Global.player_name:
			Global.crystal += reward
			print("Voce ganhou ", reward, " cristais por ficar em ", i + 1, "º lugar!")
