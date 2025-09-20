extends Node

# Carrega a configuração do Firebase
var firebase_config = preload("res://firebase_config.gd").new()

# Sinal para notificar atualizações de dados
signal player_data_updated

# Variáveis do jogador
var points: int = 0
var gold: int = 0
var crystal: int = 0
var level: int = 1
var player_name: String = "Jogador"
var player_id: String = ""  # ID único do jogador no Firebase
var is_online: bool = false  # Status de conexão com Firebase
var firebase_reference = null  # Referência do Firebase Database
var player_data_loaded: bool = false  # Indica se os dados foram carregados

# Sistema de cache robusto
var cache_manager: Node
# Variáveis para seleção de avatar
var selected_avatar = 0
var selected_avatar_index = 0
# Sistema de personagens desbloqueados
var unlocked_characters: Array[int] = [0]  # Apenas Aprendiz desbloqueado inicialmente
var avatar_names = ["Aprendiz", "Mago", "Arqueiro", "Mercador", "Guerreiro"]
var avatar_textures = [
	"res://assets/avatar1.svg",
	"res://assets/avatar2.svg",
	"res://assets/avatar3.svg",
	"res://assets/avatar4.svg",
	"res://assets/avatar5.svg"
]

# Habilidades especiais dos personagens
var character_abilities = {
	0: "none",        # Aprendiz - sem habilidade especial
	1: "reveal_letter", # Mago - revela uma letra
	2: "extra_attempt", # Arqueiro - ganha tentativa extra
	3: "bonus_gold",   # Mercador - ganha mais gold
	4: "bonus_points"  # Guerreiro - ganha mais pontos
}

# Variáveis para controle das habilidades
var ability_used_this_round = false
var extra_attempts = 0
var gold_multiplier = 1.0
var points_multiplier = 1.0

# ===== Correções de Persistência e Autenticação =====
# UID de autenticação anônima do Firebase (não usar como chave de jogador)
var firebase_auth_uid: String = ""
# Gerenciador de ID persistente (opcional)
var _persistent_id_manager: Node = null
# Token de consulta criptografada estável por dispositivo (cacheado)
var client_query_token: String = ""

# Funções para usar habilidades especiais dos personagens
func use_character_ability(character_id: int) -> bool:
	if ability_used_this_round:
		return false
	
	match character_id:
		1: # Mago - revela uma letra
			return _use_mage_ability()
		2: # Arqueiro - ganha tentativa extra
			return _use_archer_ability()
		3: # Mercador - multiplica gold
			return _use_merchant_ability()
		4: # Guerreiro - multiplica pontos
			return _use_warrior_ability()
		_:
			return false

func _use_mage_ability() -> bool:
	# Esta função é chamada pelo Main.gd
	ability_used_this_round = true
	return true

func _use_archer_ability() -> bool:
	# Adiciona uma tentativa extra
	extra_attempts += 1
	ability_used_this_round = true
	return true

func _use_merchant_ability() -> bool:
	# Multiplica o gold ganho nesta rodada
	gold_multiplier = 2.0
	ability_used_this_round = true
	return true

func _use_warrior_ability() -> bool:
	# Multiplica os pontos ganhos nesta rodada
	points_multiplier = 1.5
	ability_used_this_round = true
	return true

# Reseta as habilidades para uma nova rodada
func reset_abilities():
	ability_used_this_round = false
	extra_attempts = 0
	gold_multiplier = 1.0
	points_multiplier = 1.0


# Adiciona pontos ao jogador
func add_points(amount: int) -> void:
	points += amount
	sync_data()  # Sincroniza com Firebase
	# Atualiza automaticamente o ranking semanal
	add_to_weekly_ranking()

# Adiciona uma quantidade de gold
func add_gold(amount: int) -> void:
	gold += amount
	sync_data()  # Sincroniza com Firebase

# Adiciona uma quantidade de cristais
func add_crystal(amount: int) -> void:
	crystal += amount
	sync_data()  # Sincroniza com Firebase

# Desbloqueia um personagem
func unlock_character(character_id: int) -> void:
	if not unlocked_characters.has(character_id):
		unlocked_characters.append(character_id)
		print("Personagem %s desbloqueado!" % avatar_names[character_id])
		sync_data()  # Sincroniza com Firebase

# Verifica se um personagem esta desbloqueado
func is_character_unlocked(character_id: int) -> bool:
	return unlocked_characters.has(character_id)

# ===== FIREBASE INITIALIZATION =====

# Inicializa o Firebase quando o jogo inicia
func _ready():
	print("🎮 Iniciando sistema de persistência...")
	
	# Inicializa sistema de cache robusto
	_initialize_cache_manager()
	
	# Carrega dados locais primeiro (modo offline)
	load_local_data()
	
	# Garante um UID persistente por dispositivo e token de query estável
	_ensure_persistent_uid_and_token()
	
	# Log de sessão para comparação entre execuções
	print("🧭 Sessão iniciada:")
	print("   • UID persistente: ", player_id if not player_id.is_empty() else "vazio")
	print("   • Query token: ", client_query_token if not client_query_token.is_empty() else "vazio")
	
	# Aguarda um frame para garantir que Firebase esteja inicializado
	await get_tree().process_frame
	
	# Inicializa Firebase e verifica conexão
	initialize_firebase()
	
	# Se estiver online, tenta carregar dados do Firebase
	if is_online:
		print("🌐 Modo online - sincronizando com Firebase...")
		load_player_data_from_firebase()
	else:
		print("🔌 Modo offline - usando dados locais")
		player_data_loaded = true  # Marca dados como carregados
	
	# Inicializa o sistema de atualização automática
	initialize_auto_refresh()
	
	# Verifica consistência dos dados entre Firebase e cache local
	ensure_data_consistency()
	
	print("✅ Sistema de persistência inicializado")
	print("   • Nome: ", player_name)
	print("   • UID: ", player_id if not player_id.is_empty() else "vazio")
	print("   • Online: ", is_online)
	print("   • Dados carregados: ", player_data_loaded)

func _initialize_cache_manager():
	"""Inicializa o sistema de cache robusto"""
	print("🗄️ Inicializando CacheManager...")
	
	cache_manager = preload("res://scripts/CacheManager.gd").new()
	add_child(cache_manager)
	
	# Conecta sinais do cache
	cache_manager.cache_updated.connect(_on_cache_updated)
	cache_manager.cache_error.connect(_on_cache_error)
	
	print("✅ CacheManager inicializado")

func _on_cache_updated(data: Dictionary):
	"""Callback quando o cache é atualizado"""
	print("🔄 Cache atualizado")
	# Sincroniza dados do cache para as variáveis globais se necessário
	
func _on_cache_error(error_message: String):
	"""Callback quando ocorre erro no cache"""
	print("❌ Erro no cache: " + error_message)
	# Implementa fallback ou recuperação de erro

# Configura o Firebase com as credenciais
func initialize_firebase():
	print("🔧 Iniciando inicialização do Firebase...")
	
	# Verifica se Firebase está disponível
	if Firebase == null:
		print("❌ ERRO CRÍTICO: Firebase não encontrado!")
		print("   Verifique se o plugin godot-firebase está:")
		print("   1. Instalado na pasta addons/")
		print("   2. Ativado em Project > Project Settings > Plugins")
		print("   3. Configurado em project.godot")
		
		# Tenta carregar manualmente como fallback
		_try_manual_firebase_load()
		is_online = false
		return
	
	if Firebase.Auth == null:
		print("❌ ERRO: Firebase.Auth não encontrado!")
		print("   O módulo de autenticação não está disponível")
		is_online = false
		return
	
	var config = firebase_config.get_firebase_config()
	
	# Verifica se as configurações estão preenchidas
	if config.apiKey == "" or config.projectId == "":
		print("⚠️  AVISO: Firebase não configurado completamente")
		print("   Execute o jogo offline ou verifique firebase_config.gd")
		is_online = false
		return
	
	# Verificação detalhada da configuração
	print("✅ Configuração do Firebase carregada:")
	print("   • Project ID: ", config.projectId)
	print("   • API Key: ", config.apiKey.substr(0, 10) + "...")
	print("   • Auth Domain: ", config.authDomain)
	print("   • Database URL: ", config.databaseURL)
	
	# Injeta a configuração diretamente nos módulos antes de logar
	# Evita chamadas repetidas que quebram o operador de formatação '%'
	if Firebase.Auth and Firebase.Auth.has_method("_set_config"):
		var signup_fmt := ""
		if Firebase.Auth.has_method("get"):
			signup_fmt = str(Firebase.Auth.get("_signup_request_url"))
		if signup_fmt.find("%s") != -1:
			Firebase.Auth._set_config(config)
			print("⚙️  Config aplicada em Firebase.Auth")
		else:
			print("ℹ️  Firebase.Auth já configurado, pulando _set_config")
	if Firebase.Database and Firebase.Database.has_method("_set_config"):
		Firebase.Database._set_config(config)
		print("⚙️  Config aplicada em Firebase.Database")
	
	# Verifica se a API Key parece válida
	if not config.apiKey.begins_with("AIza"):
		print("❌ ERRO: API Key parece inválida (deve começar com 'AIza')")
		print("   Verifique no Firebase Console > Configurações do projeto")
		is_online = false
		return
	
	print("🔗 Conectando sinais do Firebase Auth...")
	
	# Verifica se o módulo Auth está disponível
	if Firebase.Auth == null:
		print("❌ ERRO: Módulo Auth do Firebase não disponível")
		print("   Verifique se o módulo de autenticação está habilitado")
		is_online = false
		return
	
	# Configura o Firebase com tratamento de erros melhorado
	var signals_connected = true
	
	if Firebase.Auth.connect("login_succeeded", _on_firebase_login_succeeded) != OK:
		print("❌ ERRO: Falha ao conectar signal login_succeeded")
		signals_connected = false
	else:
		print("✅ Signal login_succeeded conectado")
	
	if Firebase.Auth.connect("signup_succeeded", _on_firebase_signup_succeeded) != OK:
		print("❌ ERRO: Falha ao conectar signal signup_succeeded")
		signals_connected = false
	else:
		print("✅ Signal signup_succeeded conectado")
	
	if Firebase.Auth.connect("login_failed", _on_firebase_login_failed) != OK:
		print("❌ ERRO: Falha ao conectar signal login_failed")
		signals_connected = false
	else:
		print("✅ Signal login_failed conectado")
	
	if not signals_connected:
		print("⚠️  Alguns sinais não puderam ser conectados, continuando...")
	
	# Tenta fazer login anônimo
	print("🔐 Tentando login anônimo no Firebase...")
	signin_anonymously()

# Injeta config nos módulos do plugin (evita falha silenciosa de conexão)
func _inject_firebase_config(config):
	# Nem todos os módulos expõem _set_config, então checamos antes
	if Firebase.Auth and Firebase.Auth.has_method("_set_config"):
		Firebase.Auth._set_config(config)
		print("⚙️  Config aplicada em Firebase.Auth")
	if Firebase.Database and Firebase.Database.has_method("_set_config"):
		Firebase.Database._set_config(config)
		print("⚙️  Config aplicada em Firebase.Database")

# Garante um UID persistente e um token de query estável por dispositivo
func _ensure_persistent_uid_and_token():
	var config_file := ConfigFile.new()
	var err := config_file.load("user://player_config.cfg")
	if err != OK:
		print("📁 Criando arquivo de config de jogador (primeira execução)")
	
	var saved_uid: String = config_file.get_value("player", "id", "")
	if saved_uid.is_empty():
		# Tenta utilizar gerenciador dedicado, se existir
		if _persistent_id_manager == null:
			var pidm_res: GDScript = null
			if ResourceLoader.exists("res://scripts/PersistentIDManager.gd"):
				pidm_res = preload("res://scripts/PersistentIDManager.gd")
			if pidm_res != null:
				_persistent_id_manager = pidm_res.new()
				get_tree().root.add_child(_persistent_id_manager)
				if _persistent_id_manager.has_method("initialize_persistent_id"):
					_persistent_id_manager.initialize_persistent_id()
				await get_tree().process_frame
				if _persistent_id_manager.has_method("get_persistent_id"):
					saved_uid = _persistent_id_manager.get_persistent_id()
					print("🆔 UID obtido do PersistentIDManager: ", saved_uid)
		
		# Fallback local se ainda vazio
		if saved_uid.is_empty():
			saved_uid = _generate_persistent_uid_fallback()
			print("🆔 UID gerado localmente: ", saved_uid)
		
		player_id = saved_uid
		config_file.set_value("player", "id", player_id)
		config_file.save("user://player_config.cfg")
	else:
		player_id = saved_uid
		print("🆔 UID persistente recuperado do cache: ", player_id)
	
	# Gera ou recupera token de query estável por dispositivo
	client_query_token = config_file.get_value("player", "query_token", "")
	if client_query_token.is_empty():
		# Token derivado do UID (sem expor segredos)
		client_query_token = "QT-" + str(hash(player_id)).substr(0, 10)
		config_file.set_value("player", "query_token", client_query_token)
		config_file.save("user://player_config.cfg")
		print("🔐 Query token criado e cacheado: ", client_query_token)
	else:
		print("🔐 Query token recuperado do cache: ", client_query_token)

# Fallback simples para gerar UID estável
func _generate_persistent_uid_fallback() -> String:
	var base := ""
	if OS.has_method("get_unique_id"):
		base = OS.get_unique_id()
	if base == null or base == "":
		base = OS.get_model_name() + ":" + str(Time.get_unix_time_from_system())
	return "WM-" + str(hash(base)).replace("-", "")

# Faz login anônimo no Firebase
func signin_anonymously():
	Firebase.Auth.login_anonymous()
	print("Tentando conectar ao Firebase...")

# Callback quando login é bem-sucedido
func _on_firebase_login_succeeded(auth_info: Dictionary):
	print("Conectado ao Firebase!")
	is_online = true
	
	# Guarda o UID de autenticação, mas NÃO sobrescreve nosso UID persistente de jogador
	if auth_info.has("localid"):
		firebase_auth_uid = auth_info.localid
		print("   • Firebase Auth UID: ", firebase_auth_uid)
	
	# Garante que player_id já está definido de forma persistente
	if player_id.is_empty():
		_ensure_persistent_uid_and_token()
		print("   • UID persistente consolidado: ", player_id)
	else:
		print("   • Mantendo UID persistente existente: ", player_id)
	
	firebase_reference = Firebase.Database.get_database_reference("", {})
	load_player_data_from_firebase()
	# Persiste localmente para garantir consistência entre sessões
	save_local_data()

# Callback quando signup é bem-sucedido
func _on_firebase_signup_succeeded(auth_info: Dictionary):
	print("Conta criada no Firebase!")
	is_online = true
	# Apenas registra o UID de auth; a chave de dados permanece sendo player_id
	if auth_info.has("localid"):
		firebase_auth_uid = auth_info.localid
	save_player_data_to_firebase()

# Callback quando o login falha
func _on_firebase_login_failed(error_code, message):
	# Converte error_code para inteiro se for string (corrige bug de conversão)
	var error_code_int = error_code
	if typeof(error_code) == TYPE_STRING:
		error_code_int = error_code.to_int()
	
	print("❌ FALHA AO CONECTAR FIREBASE: ", message)
	print("   Código do erro: ", error_code_int)
	
	# Diagnóstico detalhado do erro
	match error_code_int:
		-1: # API Key inválida
			print("   🔍 Diagnóstico: API Key inválida ou não autorizada")
			print("   💡 Solução: Verifique no Firebase Console > Configurações do projeto")
			
		-2: # Domínio não autorizado
			print("   🔍 Diagnóstico: Domínio não autorizado")
			print("   💡 Solução: Verifique em Authentication > Settings > Authorized domains")
			
		-3: # Sem conexão com internet
			print("   🔍 Diagnóstico: Sem conexão com a internet")
			print("   💡 Solução: Verifique sua conexão de rede")
			
		-4: # Projeto não encontrado
			print("   🔍 Diagnóstico: Project ID não encontrado")
			print("   💡 Solução: Verifique se o projeto existe no Firebase Console")
			
		403: # Erro 403 - Método não permite chamadores não registrados
			print("   🔍 Diagnóstico: Erro 403 - Método não permite chamadores não registrados")
			print("   💡 Solução CRÍTICA: Configure a autenticação anônima no Firebase Console")
			print("   1. Acesse: https://console.firebase.google.com/")
			print("   2. Selecione seu projeto 'cinco-words'")
			print("   3. Vá em Authentication > Sign-in method")
			print("   4. Habilite 'Anonymous' provider")
			print("   5. Salve as alterações")
			
		_: # Erro desconhecido
			print("   🔍 Diagnóstico: Erro desconhecido")
			print("   💡 Solução: Verifique a configuração do Firebase no projeto")
			print("   📋 Para mais ajuda, consulte a documentação do Firebase")
	
	# Tenta fallback manual para erros específicos
	if error_code_int == 403:
		print("   ⚠️  Tentando fallback manual devido ao erro 403...")
		_try_manual_firebase_auth()
	
	is_online = false

# Salva dados do jogador no Firebase
func save_player_data_to_firebase():
	if not is_online or player_id == "":
		return
	
	var player_data = {
		"name": player_name,
		"points": points,
		"gold": gold,
		"crystal": crystal,
		"selected_avatar": selected_avatar,
		"unlocked_characters": unlocked_characters,
		"last_updated": Time.get_unix_time_from_system()
	}
	
	Firebase.Database.get_database_reference("players/" + player_id, {}).update("", player_data)
	print("Dados salvos no Firebase para jogador: ", player_name)

# Carrega dados do Firebase com timeout
func load_player_data_from_firebase():
	if not is_online or player_id == "":
		print("⚠️  Não é possível carregar do Firebase: offline ou ID inválido")
		return
	
	print("🌐 Carregando dados do Firebase para ID: ", player_id.substr(0, 8) + "...")
	
	var firebase_ref = Firebase.Database.get_database_reference("players/" + player_id, {})
	firebase_ref.connect("new_data_update", _on_player_data_loaded)
	firebase_ref.connect("no_data_update", _on_no_player_data)
	
	# Sistema de timeout para evitar travamento
	_start_firebase_timeout()

# Sistema de timeout para carregamento do Firebase
func _start_firebase_timeout():
	await get_tree().create_timer(10.0).timeout  # Timeout de 10 segundos
	
	# Se os dados ainda não foram carregados após o timeout
	if not player_data_loaded:
		print("⏰ Timeout do Firebase - usando dados locais")
		player_data_loaded = true  # Força marcação como carregado
		
		# Dispara sinal para notificar que os dados estão prontos (mesmo que locais)
		emit_signal("player_data_updated")

# Callback quando dados são carregados do Firebase
func _on_player_data_loaded(data: Dictionary):
	print("🔄 Comparando dados Firebase vs Local...")
	
	# Verifica se há timestamp para comparação
	var firebase_timestamp = 0
	var local_timestamp = 0
	
	if data.has("last_updated"):
		firebase_timestamp = data.last_updated
	
	# Carrega timestamp local do arquivo de configuração
	var config = ConfigFile.new()
	if config.load("user://player_config.cfg") == OK:
		local_timestamp = config.get_value("player", "last_updated", 0)
	
	print("   • Firebase timestamp: ", firebase_timestamp)
	print("   • Local timestamp: ", local_timestamp)
	
	# Só sobrescreve se os dados do Firebase forem mais recentes
	if firebase_timestamp > local_timestamp:
		print("   ✅ Dados do Firebase são mais recentes - atualizando...")
		
		if data.has("name"):
			player_name = data.name
		if data.has("points"):
			points = data.points
		if data.has("gold"):
			gold = data.gold
		if data.has("crystal"):
			crystal = data.crystal
		if data.has("selected_avatar"):
			selected_avatar = data.selected_avatar
		if data.has("unlocked_characters"):
			unlocked_characters = data.unlocked_characters
		
		# Salva os dados carregados localmente para persistência
		save_local_data()
		print("Dados carregados do Firebase para jogador: ", player_name)
	else:
		print("   ⚠️  Dados locais são mais recentes - mantendo dados atuais")
		# Salva dados locais no Firebase para sincronizar
		save_player_data_to_firebase()
	
	player_data_loaded = true  # Marca que os dados foram carregados

# Callback quando não há dados no Firebase
func _on_no_player_data():
	print("Nenhum dado encontrado no Firebase, usando dados locais")
	save_player_data_to_firebase()  # Salva os dados atuais
	player_data_loaded = true  # Marca que os dados foram processados
	# Notifica para que UI se atualize mesmo sem dados remotos
	emit_signal("player_data_updated")

# Função para sincronizar dados automaticamente
func sync_data():
	if is_online:
		save_player_data_to_firebase()

# Sistema de atualização automática dos dados
var auto_refresh_timer: Timer = null
var is_auto_refresh_enabled: bool = false

# Inicializa o sistema de atualização automática
func initialize_auto_refresh():
	if auto_refresh_timer == null:
		auto_refresh_timer = Timer.new()
		auto_refresh_timer.wait_time = 30.0  # Atualiza a cada 30 segundos
		auto_refresh_timer.timeout.connect(_on_auto_refresh_timeout)
		get_tree().root.add_child(auto_refresh_timer)
		
	if is_online:
		start_auto_refresh()

# Inicia a atualização automática
func start_auto_refresh():
	if auto_refresh_timer != null and not is_auto_refresh_enabled:
		auto_refresh_timer.start()
		is_auto_refresh_enabled = true
		print("Sistema de atualização automática iniciado")

# Para a atualização automática
func stop_auto_refresh():
	if auto_refresh_timer != null and is_auto_refresh_enabled:
		auto_refresh_timer.stop()
		is_auto_refresh_enabled = false
		print("Sistema de atualização automática parado")

# Callback do timer de atualização
func _on_auto_refresh_timeout():
	if is_online:
		print("Atualizando dados do jogador automaticamente...")
		refresh_player_data()

# Função principal de atualização dos dados
func refresh_player_data():
	if not is_online or player_id.is_empty():
		print("Não é possível atualizar dados: offline ou ID inválido")
		return
	
	print("🔄 Atualizando dados do jogador do Firebase...")
	print("   • Gold: ", gold)
	print("   • Crystal: ", crystal) 
	print("   • Pontos: ", points)
	
	# Carrega dados atualizados do Firebase
	load_player_data_from_firebase()
	
	# Dispara sinal para notificar outras partes do jogo
	emit_signal("player_data_updated")

# Verifica se é a primeira execução do jogo
func is_first_run() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	if err != OK:
		print("📁 Primeira execução: arquivo de configuração não encontrado")
		return true
	
	var first_run = config.get_value("player", "first_run", true)
	print("📊 Verificação de primeira execução: ", first_run)
	return first_run

# Sistema de fallback automático entre Firebase e cache local
func ensure_data_consistency():
	print("🔄 Verificando consistência dos dados...")
	
	# Se estiver online mas não tem UID, pode ser um problema de sincronização
	if is_online and player_id.is_empty():
		print("⚠️  Online sem UID - verificando dados locais...")
		
		# Tenta recuperar UID do arquivo local
		var config = ConfigFile.new()
		var err = config.load("user://player_config.cfg")
		if err == OK:
			var saved_id = config.get_value("player", "id", "")
			if not saved_id.is_empty():
				player_id = saved_id
				print("✅ UID recuperado do cache local: ", saved_id.substr(0, 8) + "...")
				# Sincroniza dados com Firebase
				save_player_data_to_firebase()
			else:
				print("❌ Nenhum UID encontrado localmente - pode ser primeira execução")
		
	# Se estiver offline mas tem UID, mantém os dados locais
	elif not is_online and not player_id.is_empty():
		print("🔌 Modo offline com UID - usando cache local")
		
	print("✅ Consistência de dados verificada")
	print("   • Estado final: Online=", is_online, " UID=", player_id if not player_id.is_empty() else "vazio")

# Sistema de ranking semanal
var week_start_time: float = 0.0

func get_week_start_time() -> float:
	if week_start_time == 0.0:
		# Carrega do arquivo de configuração ou inicializa
		var config = ConfigFile.new()
		var err = config.load("user://player_config.cfg")
		if err == OK:
			week_start_time = config.get_value("ranking", "week_start_time", Time.get_unix_time_from_system())
		else:
			week_start_time = Time.get_unix_time_from_system()
			_save_week_start_time()
	return week_start_time

func _save_week_start_time():
	var config = ConfigFile.new()
	config.load("user://player_config.cfg")  # Carrega existente ou cria novo
	config.set_value("ranking", "week_start_time", week_start_time)
	config.save("user://player_config.cfg")

# Adiciona jogador ao ranking semanal
func add_to_weekly_ranking():
	if not is_online or not firebase_reference:
		return
	
	# Validação de dados básicos
	if player_id.is_empty() or player_name.is_empty():
		print("Erro: Dados do jogador inválidos para ranking")
		return
	
	# Previne pontuações negativas
	if points < 0:
		print("Aviso: Pontuação negativa detectada, ajustando para 0")
		points = 0
	
	# Calcula a semana atual
	var current_time = Time.get_unix_time_from_system()
	var week_start = (current_time / (7 * 24 * 3600)) as int
	
	# Garante que o índice do avatar está dentro dos limites
	var valid_avatar_index = selected_avatar_index
	if valid_avatar_index < 0 or valid_avatar_index >= avatar_textures.size():
		valid_avatar_index = 0
		print("Aviso: Índice de avatar inválido, usando padrão")
	
	var ranking_data = {
		"player_id": player_id,
		"name": player_name,
		"points": points,
		"avatar_index": valid_avatar_index,
		"timestamp": current_time
	}
	
	var weekly_ref = firebase_reference.child("weekly_rankings").child(str(week_start)).child(player_id)
	weekly_ref.update("", ranking_data)
	
	print("Jogador adicionado/atualizado no ranking semanal: ", player_name)

# Carrega dados salvos localmente
# ===== SISTEMA ROBUSTO DE SINCRONIZAÇÃO FIREBASE =====

# Sincronização inteligente com Firebase
func sync_with_firebase_robust():
	if not is_online or not firebase_reference:
		print("🔌 Offline - sincronização adiada")
		return false
	
	print("🔄 Iniciando sincronização robusta com Firebase...")
	
	# Verifica conectividade antes de tentar
	if not await _check_firebase_connectivity():
		print("❌ Firebase inacessível - mantendo dados locais")
		return false
	
	# Tenta sincronização com retry
	var max_retries = 3
	var retry_count = 0
	
	while retry_count < max_retries:
		if await _attempt_firebase_sync():
			print("✅ Sincronização com Firebase concluída")
			return true
		
		retry_count += 1
		print("⚠️ Tentativa ", retry_count, " falhou, aguardando...")
		await get_tree().create_timer(2.0 * retry_count).timeout  # Backoff exponencial
	
	print("❌ Falha na sincronização após ", max_retries, " tentativas")
	return false

# Verifica conectividade com Firebase
func _check_firebase_connectivity() -> bool:
	print("🔍 Verificando conectividade com Firebase...")
	
	# Tenta uma operação simples de leitura
	var test_ref = firebase_reference.child("connectivity_test")
	var connected = false
	
	# Timeout para verificação
	var timeout_timer = get_tree().create_timer(5.0)
	var connectivity_check = false
	
	# Conecta sinal temporário para teste
	var connection_id = test_ref.connect("new_data_update", func(data): 
		connectivity_check = true
		connected = true
	)
	
	test_ref.get_data()
	
	# Aguarda resposta ou timeout
	while not connectivity_check and not timeout_timer.is_stopped():
		await get_tree().process_frame
	
	# Desconecta sinal temporário
	if test_ref.is_connected("new_data_update", Callable()):
		test_ref.disconnect("new_data_update", Callable())
	
	print("🌐 Conectividade Firebase: ", "OK" if connected else "FALHA")
	return connected

# Tentativa de sincronização com Firebase
func _attempt_firebase_sync() -> bool:
	print("📤 Tentando sincronizar dados com Firebase...")
	
	var sync_successful = false
	var timeout_timer = get_tree().create_timer(10.0)
	
	# Prepara dados para envio
	var sync_data = {
		"name": player_name,
		"points": points,
		"gold": gold,
		"crystal": crystal,
		"level": level,
		"avatar_index": selected_avatar,
		"last_updated": Time.get_unix_time_from_system(),
		"unlocked_characters": unlocked_characters
	}
	
	# Referência do jogador no Firebase
	var player_ref = firebase_reference.child("players").child(player_id)
	
	# Conecta sinal para confirmar salvamento
	var save_connection_id = player_ref.connect("patch_data_update", func(data):
		if data != null:
			sync_successful = true
			print("✅ Dados sincronizados com Firebase")
		else:
			print("❌ Falha na sincronização")
	)
	
	# Envia dados
	player_ref.patch_data(sync_data)
	
	# Aguarda confirmação ou timeout
	while not sync_successful and not timeout_timer.is_stopped():
		await get_tree().process_frame
	
	# Limpa conexão
	if player_ref.is_connected("patch_data_update", Callable()):
		player_ref.disconnect("patch_data_update", Callable())
	
	return sync_successful

# Carrega dados do Firebase com fallback local
func load_from_firebase_robust():
	if not is_online or not firebase_reference:
		print("🔌 Offline - carregando dados locais")
		return load_local_data_robust()
	
	print("📥 Carregando dados do Firebase...")
	
	var load_successful = false
	var timeout_timer = get_tree().create_timer(8.0)
	var firebase_data = null
	
	# Referência do jogador
	var player_ref = firebase_reference.child("players").child(player_id)
	
	# Conecta sinal para receber dados
	var load_connection_id = player_ref.connect("new_data_update", func(data):
		firebase_data = data
		load_successful = true
	)
	
	# Solicita dados
	player_ref.get_data()
	
	# Aguarda dados ou timeout
	while not load_successful and not timeout_timer.is_stopped():
		await get_tree().process_frame
	
	# Limpa conexão
	if player_ref.is_connected("new_data_update", Callable()):
		player_ref.disconnect("new_data_update", Callable())
	
	# Processa resultado
	if load_successful and firebase_data != null:
		print("✅ Dados carregados do Firebase")
		_apply_firebase_data(firebase_data)
		# Salva localmente como backup
		save_local_data_robust()
		return true
	else:
		print("⚠️ Falha no Firebase - usando dados locais")
		return load_local_data_robust()

# Aplica dados recebidos do Firebase
func _apply_firebase_data(data: Dictionary):
	if data.has("name"): player_name = data["name"]
	if data.has("points"): points = data["points"]
	if data.has("gold"): gold = data["gold"]
	if data.has("crystal"): crystal = data["crystal"]
	if data.has("level"): level = data["level"]
	if data.has("avatar_index"): 
		selected_avatar_index = data["avatar_index"]
		selected_avatar = selected_avatar_index
	if data.has("unlocked_characters"): unlocked_characters = data["unlocked_characters"]
	
	player_data_loaded = true
	emit_signal("player_data_updated")

# Escuta mudanças em tempo real do Firebase
func setup_firebase_listeners():
	if not is_online or not firebase_reference:
		return
	
	print("👂 Configurando listeners do Firebase...")
	
	var player_ref = firebase_reference.child("players").child(player_id)
	
	# Listener para mudanças nos dados do jogador
	if not player_ref.is_connected("new_data_update", _on_firebase_data_changed):
		player_ref.connect("new_data_update", _on_firebase_data_changed)
	
	print("✅ Listeners do Firebase configurados")

# Responde a mudanças nos dados do Firebase
func _on_firebase_data_changed(data: Dictionary):
	if data == null:
		return
	
	print("🔄 Dados atualizados no Firebase - sincronizando localmente...")
	
	# Verifica se os dados remotos são mais recentes
	var remote_timestamp = data.get("last_updated", 0)
	var local_timestamp = Time.get_unix_time_from_system()
	
	# Se dados remotos são mais recentes, aplica localmente
	if remote_timestamp > local_timestamp - 60:  # Margem de 1 minuto
		_apply_firebase_data(data)
		save_local_data_robust()
		print("✅ Dados sincronizados do Firebase para local")

# Wrapper para manter compatibilidade com código existente
func save_local_data():
	return save_local_data_robust()

func load_local_data():
	return load_local_data_robust()

# ===== SISTEMA ROBUSTO DE PERSISTÊNCIA COM CACHE =====

# Salva dados com sistema de backup, cache e verificação de integridade
func save_local_data_robust():
	print("💾 Iniciando salvamento robusto de dados...")
	
	# Primeiro, salva no cache manager
	if cache_manager:
		cache_manager.sync_from_global()
		cache_manager.save_cache()
	
	var config = ConfigFile.new()
	var backup_config = ConfigFile.new()
	
	# Carrega arquivo existente
	var err = config.load("user://player_config.cfg")
	
	# Cria backup do arquivo atual se existir
	if err == OK:
		var backup_err = backup_config.load("user://player_config.cfg")
		if backup_err == OK:
			backup_config.save("user://player_config_backup.cfg")
			print("📋 Backup criado com sucesso")
	
	# Prepara dados para salvamento
	var save_data = {
		"name": player_name,
		"id": player_id,
		"points": points,
		"gold": gold,
		"crystal": crystal,
		"level": level,
		"avatar_index": selected_avatar,
		"first_run": false,
		"last_updated": Time.get_unix_time_from_system(),
		"query_token": client_query_token,
		"unlocked_characters": unlocked_characters,
		"data_version": "2.0"  # Versão atualizada com cache
	}
	
	# Valida dados antes de salvar
	if not _validate_save_data(save_data):
		print("❌ Dados inválidos - salvamento cancelado")
		return false
	
	# Salva dados principais
	for key in save_data.keys():
		config.set_value("player", key, save_data[key])
	
	# Tenta salvar arquivo principal
	var save_err = config.save("user://player_config.cfg")
	if save_err != OK:
		print("❌ Erro ao salvar arquivo principal: ", save_err)
		# Tenta restaurar backup se falhou
		_restore_from_backup()
		return false
	
	# Verifica integridade do arquivo salvo
	if not _verify_save_integrity(save_data):
		print("❌ Falha na verificação de integridade")
		_restore_from_backup()
		return false
	
	print("✅ Dados salvos com sucesso e integridade verificada")
	return true

# Carrega dados com sistema de recuperação, cache e fallback
func load_local_data_robust():
	print("📂 Iniciando carregamento robusto de dados...")
	
	# Primeiro, tenta carregar do cache manager
	var cache_loaded = false
	if cache_manager and cache_manager.cache_loaded:
		print("🗄️ Tentando carregar do cache...")
		cache_manager.sync_to_global()
		cache_loaded = true
		print("✅ Dados carregados do cache")
	
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	
	# Se arquivo principal falhou, tenta backup
	if err != OK:
		print("⚠️ Arquivo principal não encontrado, tentando backup...")
		err = config.load("user://player_config_backup.cfg")
		
		if err != OK:
			if not cache_loaded:
				print("❌ Nenhum arquivo de dados encontrado")
				_initialize_default_data()
				return false
			else:
				print("✅ Usando dados do cache como fallback")
				player_data_loaded = true
				emit_signal("player_data_updated")
				return true
		else:
			print("📋 Dados carregados do backup")
	
	# Carrega e valida dados do arquivo
	var loaded_data = {
		"name": config.get_value("player", "name", "Jogador"),
		"id": config.get_value("player", "id", ""),
		"points": config.get_value("player", "points", 0),
		"gold": config.get_value("player", "gold", 0),
		"crystal": config.get_value("player", "crystal", 0),
		"level": config.get_value("player", "level", 1),
		"avatar_index": config.get_value("player", "avatar_index", 0),
		"query_token": config.get_value("player", "query_token", ""),
		"unlocked_characters": config.get_value("player", "unlocked_characters", [0]),
		"data_version": config.get_value("player", "data_version", "1.0")
	}
	
	# Valida dados carregados
	if not _validate_loaded_data(loaded_data):
		if not cache_loaded:
			print("❌ Dados carregados são inválidos")
			_initialize_default_data()
			return false
		else:
			print("⚠️ Dados do arquivo inválidos, mantendo dados do cache")
			player_data_loaded = true
			emit_signal("player_data_updated")
			return true
	
	# Aplica dados carregados
	_apply_loaded_data(loaded_data)
	
	# Sincroniza com cache manager
	if cache_manager:
		cache_manager.sync_from_global()
	
	print("✅ Dados carregados com sucesso: ", player_name)
	player_data_loaded = true
	emit_signal("player_data_updated")
	return true

# Valida dados antes do salvamento
func _validate_save_data(data: Dictionary) -> bool:
	# Verifica campos obrigatórios
	var required_fields = ["name", "id", "points", "gold", "crystal", "level"]
	for field in required_fields:
		if not data.has(field):
			print("❌ Campo obrigatório ausente: ", field)
			return false
	
	# Valida tipos e valores
	if typeof(data["name"]) != TYPE_STRING or data["name"].length() < 2:
		print("❌ Nome inválido")
		return false
	
	if typeof(data["points"]) != TYPE_INT or data["points"] < 0:
		print("❌ Pontos inválidos")
		return false
	
	if typeof(data["gold"]) != TYPE_INT or data["gold"] < 0:
		print("❌ Gold inválido")
		return false
	
	if typeof(data["level"]) != TYPE_INT or data["level"] < 1:
		print("❌ Level inválido")
		return false
	
	return true

# Valida dados após carregamento
func _validate_loaded_data(data: Dictionary) -> bool:
	return _validate_save_data(data)

# Aplica dados carregados às variáveis globais
func _apply_loaded_data(data: Dictionary):
	player_name = data["name"]
	player_id = data["id"]
	points = data["points"]
	gold = data["gold"]
	crystal = data["crystal"]
	level = data["level"]
	selected_avatar_index = data["avatar_index"]
	selected_avatar = selected_avatar_index
	client_query_token = data["query_token"]
	unlocked_characters = data["unlocked_characters"]

# Verifica integridade do arquivo salvo
func _verify_save_integrity(original_data: Dictionary) -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	
	if err != OK:
		return false
	
	# Verifica alguns campos críticos
	var saved_name = config.get_value("player", "name", "")
	var saved_gold = config.get_value("player", "gold", -1)
	
	return saved_name == original_data["name"] and saved_gold == original_data["gold"]

# Restaura dados do backup
func _restore_from_backup():
	print("🔄 Restaurando dados do backup...")
	var backup_config = ConfigFile.new()
	var err = backup_config.load("user://player_config_backup.cfg")
	
	if err == OK:
		backup_config.save("user://player_config.cfg")
		print("✅ Backup restaurado com sucesso")
	else:
		print("❌ Falha ao restaurar backup")

# Inicializa dados padrão
func _initialize_default_data():
	print("🆕 Inicializando dados padrão...")
	player_name = "Jogador"
	player_id = ""
	points = 0
	gold = 100  # Gold inicial
	crystal = 0
	level = 1
	selected_avatar_index = 0
	selected_avatar = 0
	unlocked_characters = [0]
	client_query_token = ""
	player_data_loaded = true
	emit_signal("player_data_updated")

# Verifica se um nome de usuário já existe no Firebase
func check_username_exists(username: String, callback: Callable):
	if not is_online or not firebase_reference:
		callback.call(false)  # Se offline, assume que não existe
		return
	
	# Busca por jogadores com o mesmo nome
	var players_ref = firebase_reference.child("players")
	players_ref.connect("new_data_update", _on_username_check_result.bind(username, callback), CONNECT_ONE_SHOT)
	players_ref.get_data()

func _on_username_check_result(username: String, callback: Callable, data: Dictionary):
	var username_exists = false
	
	if data != null:
		for player_id in data.keys():
			var player_data = data[player_id]
			if player_data.has("name") and player_data["name"].to_lower() == username.to_lower():
				username_exists = true
				break
	
	callback.call(username_exists)

# ===== FALLBACK FUNCTIONS =====

# Tenta carregar manualmente o Firebase como fallback
func _try_manual_firebase_load():
	print("🔄 Tentando carregar Firebase manualmente...")
	print("   Para problemas de configuração, verifique firebase_config.gd")

# Tenta autenticação manual para erro 403
func _try_manual_firebase_auth():
	print("🔐 Tentando autenticação manual alternativa...")
	
	var config = firebase_config.get_firebase_config()
	if config.apiKey == "":
		print("❌ Não é possível fazer autenticação manual: API Key vazia")
		return
	
	print("⚠️  Para resolver o erro 403, configure a autenticação anônima:")
	print("   1. Acesse: https://console.firebase.google.com/")
	print("   2. Projeto: cinco-words")
	print("   3. Authentication > Sign-in method > Habilitar Anonymous")
	
	# Como fallback final, opera em modo offline
	is_online = false
	print("🔌 Modo offline ativado - jogando sem conexão com Firebase")
