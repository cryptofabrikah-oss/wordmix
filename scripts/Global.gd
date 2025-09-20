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
	sync_data()  # Sincroniza com Firebase e salva localmente
	# Atualiza automaticamente o ranking semanal
	add_to_weekly_ranking()

# Adiciona uma quantidade de gold
func add_gold(amount: int) -> void:
	gold += amount
	sync_data()  # Sincroniza com Firebase e salva localmente

# Adiciona uma quantidade de cristais
func add_crystal(amount: int) -> void:
	crystal += amount
	sync_data()  # Sincroniza com Firebase e salva localmente

# Desbloqueia um personagem
func unlock_character(character_id: int) -> void:
	if not unlocked_characters.has(character_id):
		unlocked_characters.append(character_id)
		print("Personagem %s desbloqueado!" % avatar_names[character_id])
		sync_data()  # Sincroniza com Firebase e salva localmente

# Verifica se um personagem esta desbloqueado
func is_character_unlocked(character_id: int) -> bool:
	return unlocked_characters.has(character_id)

# ===== FIREBASE INITIALIZATION =====

# Inicializa o Firebase quando o jogo inicia
func _ready():
	print("🎮 Iniciando sistema de persistência...")
	
	# Carrega dados locais primeiro (modo offline)
	load_local_data()
	
	# Conecta ao sinal de dados atualizados para sincronização automática
	if not player_data_updated.is_connected(_on_data_updated):
		player_data_updated.connect(_on_data_updated)
	
	# Inicializa Firebase após carregar dados locais (async)
	_initialize_firebase_async()

				  # Proteção contra recursão infinita
var is_syncing: bool = false

# Callback para sincronização automática quando dados são atualizados
func _on_data_updated():
	# Evita recursão infinita
	if is_syncing:
		print("⚠️ Sincronização já em andamento - ignorando chamada duplicada")
		return
	
	print("📊 Dados do jogador atualizados - sincronizando...")
	sync_data()

# Tratamento de notificações do sistema para salvar dados ao fechar
func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("🚪 Aplicativo sendo fechado - salvando dados...")
			_save_on_exit()
		NOTIFICATION_APPLICATION_PAUSED:
			print("⏸️ Aplicativo pausado - salvando dados...")
			_save_on_exit()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			print("👁️ Aplicativo perdeu foco - salvando dados...")
			_save_on_exit()

# Função para salvar dados ao sair/pausar
func _save_on_exit():
	print("💾 Executando salvamento de emergência...")
	
	# Salva dados localmente (sempre funciona)
	save_local_data()
	print("✅ Dados salvos localmente")
	
	# Tenta salvar no Firebase se estiver online
	if is_online and not player_id.is_empty():
		print("🌐 Tentando salvar no Firebase...")
		save_player_data_to_firebase()
		
		# Aguarda um pouco para a sincronização (máximo 2 segundos)
		var timeout = 0.0
		while timeout < 2.0:
			await get_tree().create_timer(0.1).timeout
			timeout += 0.1
		
		print("✅ Tentativa de salvamento no Firebase concluída")
	else:
		print("⚠️ Firebase offline ou ID inválido - apenas salvamento local")
	
	print("🔒 Salvamento de emergência finalizado")

# Função assíncrona para inicializar Firebase
func _initialize_firebase_async():
	await initialize_firebase()

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
		print("   Possíveis causas:")
		print("   1. Plugin Firebase não carregado corretamente na APK")
		print("   2. Dependências do Firebase ausentes no build Android")
		print("   3. Problema de inicialização do autoload")
		print("🔄 Tentando inicialização alternativa...")
		
		# Tenta recarregar o Firebase como fallback
		if await _try_alternative_firebase_init():
			print("✅ Firebase inicializado com método alternativo")
		else:
			print("⚠️  Continuando em modo offline - todas as funcionalidades locais disponíveis")
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
	
	# Conecta sinais apenas se ainda não estiverem conectados
	if not Firebase.Auth.is_connected("login_succeeded", _on_firebase_login_succeeded):
		if Firebase.Auth.connect("login_succeeded", _on_firebase_login_succeeded) != OK:
			print("❌ ERRO: Falha ao conectar signal login_succeeded")
			signals_connected = false
		else:
			print("✅ Signal login_succeeded conectado")
	else:
		print("ℹ️ Signal login_succeeded já estava conectado")
	
	if not Firebase.Auth.is_connected("signup_succeeded", _on_firebase_signup_succeeded):
		if Firebase.Auth.connect("signup_succeeded", _on_firebase_signup_succeeded) != OK:
			print("❌ ERRO: Falha ao conectar signal signup_succeeded")
			signals_connected = false
		else:
			print("✅ Signal signup_succeeded conectado")
	else:
		print("ℹ️ Signal signup_succeeded já estava conectado")
	
	if not Firebase.Auth.is_connected("login_failed", _on_firebase_login_failed):
		if Firebase.Auth.connect("login_failed", _on_firebase_login_failed) != OK:
			print("❌ ERRO: Falha ao conectar signal login_failed")
			signals_connected = false
		else:
			print("✅ Signal login_failed conectado")
	else:
		print("ℹ️ Signal login_failed já estava conectado")
	
	if not signals_connected:
		print("⚠️ Alguns sinais não puderam ser conectados, continuando...")
	
	# Tenta fazer login anônimo apenas se não estiver autenticado
	if Firebase.Auth.auth == null or Firebase.Auth.auth.is_empty():
		print("🔐 Tentando login anônimo no Firebase...")
		signin_anonymously()
	else:
		print("ℹ️ Usuário já está autenticado no Firebase")
		is_online = true

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

# Carrega dados do Firebase com merge inteligente para evitar sobrescrita
func load_player_data_from_firebase_with_merge(local_backup: Dictionary):
	if not is_online or player_id == "":
		print("⚠️  Não é possível carregar do Firebase: offline ou ID inválido")
		return
	
	print("🌐 Carregando dados do Firebase com merge inteligente para ID: ", player_id.substr(0, 8) + "...")
	
	var firebase_ref = Firebase.Database.get_database_reference("players/" + player_id, {})
	firebase_ref.connect("new_data_update", _on_player_data_loaded_with_merge.bind(local_backup))
	firebase_ref.connect("no_data_update", _on_no_player_data_with_merge.bind(local_backup))
	
	# Sistema de timeout para evitar travamento
	_start_firebase_timeout()

# Callback para merge inteligente de dados do Firebase
func _on_player_data_loaded_with_merge(local_backup: Dictionary, firebase_data: Dictionary):
	print("🔄 Fazendo merge inteligente dos dados...")
	
	var changes_made = false
	
	# Merge de pontos - usa o maior valor
	if firebase_data.has("points"):
		var firebase_points = firebase_data.points
		if firebase_points > points:
			print("   📈 Pontos atualizados: ", points, " → ", firebase_points)
			points = firebase_points
			changes_made = true
		elif points > firebase_points:
			print("   📈 Pontos locais são maiores, mantendo: ", points)
			# Atualiza Firebase com valor local maior
			save_player_data_to_firebase()
	
	# Merge de gold - usa o maior valor
	if firebase_data.has("gold"):
		var firebase_gold = firebase_data.gold
		if firebase_gold > gold:
			print("   💰 Gold atualizado: ", gold, " → ", firebase_gold)
			gold = firebase_gold
			changes_made = true
		elif gold > firebase_gold:
			print("   💰 Gold local é maior, mantendo: ", gold)
			save_player_data_to_firebase()
	
	# Merge de crystal - usa o maior valor
	if firebase_data.has("crystal"):
		var firebase_crystal = firebase_data.crystal
		if firebase_crystal > crystal:
			print("   💎 Crystal atualizado: ", crystal, " → ", firebase_crystal)
			crystal = firebase_crystal
			changes_made = true
		elif crystal > firebase_crystal:
			print("   💎 Crystal local é maior, mantendo: ", crystal)
			save_player_data_to_firebase()
	
	# Merge de personagens desbloqueados - combina arrays
	if firebase_data.has("unlocked_characters"):
		var firebase_unlocked = firebase_data.unlocked_characters
		var original_count = unlocked_characters.size()
		
		# Adiciona personagens do Firebase que não estão localmente
		for character_id in firebase_unlocked:
			if not unlocked_characters.has(character_id):
				unlocked_characters.append(character_id)
				changes_made = true
		
		# Atualiza Firebase se temos personagens locais que não estão lá
		var needs_firebase_update = false
		for character_id in unlocked_characters:
			if not firebase_unlocked.has(character_id):
				needs_firebase_update = true
				break
		
		if needs_firebase_update:
			save_player_data_to_firebase()
		
		if unlocked_characters.size() > original_count:
			print("   🎭 Personagens desbloqueados sincronizados: ", original_count, " → ", unlocked_characters.size())
	
	# Atualiza outros campos se necessário
	if firebase_data.has("name") and firebase_data.name != player_name:
		player_name = firebase_data.name
		changes_made = true
	
	if firebase_data.has("selected_avatar") and firebase_data.selected_avatar != selected_avatar:
		selected_avatar = firebase_data.selected_avatar
		changes_made = true
	
	# Salva dados mesclados localmente
	if changes_made:
		save_local_data()
		print("✅ Merge concluído com alterações - dados salvos localmente")
	else:
		print("✅ Merge concluído - nenhuma alteração necessária")
	
	player_data_loaded = true
	is_syncing = false  # Reset da proteção de recursão
	emit_signal("player_data_updated")

# Callback quando não há dados no Firebase para merge
func _on_no_player_data_with_merge(local_backup: Dictionary):
	print("📤 Nenhum dado no Firebase - enviando dados locais")
	save_player_data_to_firebase()  # Envia dados locais para Firebase
	player_data_loaded = true
	is_syncing = false  # Reset da proteção de recursão
	emit_signal("player_data_updated")

# Carrega dados do Firebase com timeout (versão original mantida para compatibilidade)
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
	player_data_loaded = true  # Marca que os dados foram carregados
	print("Dados carregados do Firebase para jogador: ", player_name)

# Callback quando não há dados no Firebase
func _on_no_player_data():
	print("Nenhum dado encontrado no Firebase, usando dados locais")
	save_player_data_to_firebase()  # Salva os dados atuais
	player_data_loaded = true  # Marca que os dados foram processados
	# Notifica para que UI se atualize mesmo sem dados remotos
	emit_signal("player_data_updated")

# Função para sincronizar dados com validação anti-sobrescrita
func sync_data():
	print("🔄 Iniciando sincronização inteligente de dados...")
	
	# Proteção contra recursão infinita
	if is_syncing:
		print("⚠️ Sincronização já em andamento - ignorando chamada duplicada")
		return
	
	is_syncing = true
	
	# Sempre salva localmente primeiro para garantir backup
	save_local_data()
	print("✅ Dados salvos localmente como backup")
	
	# Se estiver online, faz merge inteligente em vez de sobrescrita
	if is_online and not player_id.is_empty():
		print("🌐 Fazendo sincronização inteligente com Firebase...")
		
		# Cria backup dos dados locais atuais
		var local_backup = {
			"points": points,
			"gold": gold,
			"crystal": crystal,
			"selected_avatar": selected_avatar,
			"unlocked_characters": unlocked_characters.duplicate(),
			"local_timestamp": Time.get_unix_time_from_system()
		}
		
		# Usa a nova função de merge inteligente
		load_player_data_from_firebase_with_merge(local_backup)
	else:
		print("🔌 Modo offline - apenas salvamento local realizado")
		# Emite sinal para atualizar UI mesmo offline (sem causar recursão)
		is_syncing = false
		emit_signal("player_data_updated")
		return
	
	# Reset da proteção será feito nos callbacks do Firebase
	# is_syncing = false será chamado em _on_player_data_loaded_with_merge ou _on_no_player_data_with_merge

# Força upload imediato dos dados para Firebase (usado em testes)
func force_upload_data():
	print("🚀 Forçando upload imediato dos dados...")
	if not is_online:
		print("❌ Firebase offline - não é possível fazer upload")
		return false
	
	if player_id == "":
		print("❌ ID do jogador inválido - não é possível fazer upload")
		return false
	
	save_player_data_to_firebase()
	print("✅ Upload forçado concluído")
	return true

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

# Função principal de atualização dos dados com merge inteligente
func refresh_player_data():
	if not is_online or player_id.is_empty():
		print("Não é possível atualizar dados: offline ou ID inválido")
		return
	
	print("🔄 Verificando dados do Firebase para merge inteligente...")
	print("   • Dados locais - Gold: ", gold, " Crystal: ", crystal, " Pontos: ", points)
	
	# Salva dados locais atuais antes de carregar do Firebase
	var local_backup = {
		"points": points,
		"gold": gold,
		"crystal": crystal,
		"selected_avatar": selected_avatar,
		"unlocked_characters": unlocked_characters.duplicate(),
		"local_timestamp": Time.get_unix_time_from_system()
	}
	
	# Carrega dados do Firebase com merge inteligente
	load_player_data_from_firebase_with_merge(local_backup)
	
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
func load_local_data():
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	if err != OK:
		print("Nenhum arquivo de configuração encontrado")
		player_data_loaded = true  # Marca como carregado mesmo sem arquivo
		# Notifica interessados que dados (locais) estão prontos - sem causar recursão
		if not is_syncing:
			emit_signal("player_data_updated")
		return
	
	# Carrega dados do jogador
	player_name = config.get_value("player", "name", "Jogador")
	player_id = config.get_value("player", "id", "")
	points = config.get_value("player", "points", 0)
	gold = config.get_value("player", "gold", 0)
	crystal = config.get_value("player", "crystal", 0)
	level = config.get_value("player", "level", 1)
	selected_avatar_index = config.get_value("player", "avatar_index", 0)
	selected_avatar = selected_avatar_index  # Sincroniza as variáveis
	client_query_token = config.get_value("player", "query_token", client_query_token)
	
	print("Dados locais carregados para: ", player_name)
	print("UID recuperado: ", player_id)
	player_data_loaded = true  # Marca que os dados foram carregados
	# Emite sinal para atualizar UI baseada em dados locais - sem causar recursão
	if not is_syncing:
		emit_signal("player_data_updated")

# Salva dados localmente
func save_local_data():
	var config = ConfigFile.new()
	
	# Carrega arquivo existente ou cria novo
	var err = config.load("user://player_config.cfg")
	
	# Salva dados do jogador
	config.set_value("player", "name", player_name)
	config.set_value("player", "id", player_id)
	config.set_value("player", "points", points)
	config.set_value("player", "gold", gold)
	config.set_value("player", "crystal", crystal)
	config.set_value("player", "level", level)
	selected_avatar_index = selected_avatar  # Sincroniza as variáveis
	config.set_value("player", "avatar_index", selected_avatar_index)
	config.set_value("player", "first_run", false)
	# Persiste o token de query
	if not client_query_token.is_empty():
		config.set_value("player", "query_token", client_query_token)
	
	# Salva o arquivo
	config.save("user://player_config.cfg")

# Verifica se um nome de usuário já existe no Firebase
func check_username_exists(username: String, callback: Callable):
	print("🔍 Verificando se nome existe: ", username)
	
	if not is_online or not firebase_reference:
		print("⚠️ Firebase offline - assumindo nome disponível")
		callback.call(false)  # Se offline, assume que não existe
		return
	
	# Busca por jogadores com o mesmo nome
	var players_ref = firebase_reference.child("players")
	
	# Conecta sinais com timeout
	players_ref.connect("new_data_update", _on_username_check_result.bind(username, callback), CONNECT_ONE_SHOT)
	players_ref.connect("no_data_update", _on_username_check_no_data.bind(callback), CONNECT_ONE_SHOT)
	
	# Timeout de segurança
	get_tree().create_timer(10.0).timeout.connect(_on_username_check_timeout.bind(callback), CONNECT_ONE_SHOT)
	
	print("📡 Fazendo consulta ao Firebase...")
	players_ref.get_data()

func _on_username_check_result(username: String, callback: Callable, data: Dictionary):
	print("📥 Resultado da verificação de nome recebido")
	var username_exists = false
	
	if data != null and not data.is_empty():
		print("📊 Verificando ", data.size(), " jogadores...")
		for player_id in data.keys():
			var player_data = data[player_id]
			if player_data.has("name") and player_data["name"].to_lower() == username.to_lower():
				print("❌ Nome já existe: ", player_data["name"])
				username_exists = true
				break
	else:
		print("📭 Nenhum dado encontrado - nome disponível")
	
	print("✅ Verificação concluída: nome ", ("existe" if username_exists else "disponível"))
	callback.call(username_exists)

# Callback para quando não há dados no Firebase
func _on_username_check_no_data(callback: Callable):
	print("📭 Firebase retornou sem dados - nome disponível")
	callback.call(false)

# Callback para timeout da verificação
func _on_username_check_timeout(callback: Callable):
	print("⏰ Timeout na verificação de nome - assumindo disponível")
	callback.call(false)

# ===== FALLBACK FUNCTIONS =====

# Tenta inicialização alternativa do Firebase
func _try_alternative_firebase_init() -> bool:
	print("🔄 Tentando inicialização alternativa do Firebase...")
	
	# Método 1: Tentar recarregar o autoload Firebase
	if has_node("/root/Firebase"):
		var firebase_node = get_node("/root/Firebase")
		if firebase_node and firebase_node.has_method("_ready"):
			print("   • Tentando reinicializar Firebase existente...")
			firebase_node._ready()
			
			# Aguarda um pouco para a inicialização
			await get_tree().create_timer(0.5).timeout
			
			if firebase_node.Auth != null:
				print("   ✅ Firebase.Auth agora disponível!")
				return true
	
	# Método 2: Tentar carregar manualmente o Firebase.tscn
	print("   • Tentando carregar Firebase.tscn manualmente...")
	var firebase_scene = load("res://addons/godot-firebase/firebase/firebase.tscn")
	if firebase_scene:
		var firebase_instance = firebase_scene.instantiate()
		get_tree().root.add_child(firebase_instance)
		firebase_instance.name = "FirebaseBackup"
		
		# Aguarda inicialização
		await get_tree().create_timer(1.0).timeout
		
		if firebase_instance.Auth != null:
			print("   ✅ Firebase backup inicializado com sucesso!")
			# Nota: Não podemos substituir o autoload Firebase, mas o backup está funcionando
			return true
		else:
			firebase_instance.queue_free()
	
	print("   ❌ Falha na inicialização alternativa")
	return false

# Tenta carregar manualmente o Firebase como fallback
func _try_manual_firebase_load():
	print("🔄 Tentando carregar Firebase manualmente...")
	
	# Como o FirebaseEnvFix foi removido, usa configuração direta
	print("⚠️  FirebaseEnvFix não está disponível - usando configuração padrão")
	print("   Para problemas de ambiente, verifique firebase_config.gd")

# Tenta autenticação manual para erro 403
func _try_manual_firebase_auth():
	print("🔐 Tentando autenticação manual alternativa...")
	
	# Método alternativo: usar HTTP requests diretos para Firebase Auth
	# Isso é um fallback para quando o plugin oficial falha
	
	var config = firebase_config.get_firebase_config()
	if config.apiKey == "":
		print("❌ Não é possível fazer autenticação manual: API Key vazia")
		return
	
	print("⚠️  Autenticação manual não implementada completamente")
	print("   Para resolver o erro 403, configure a autenticação anônima:")
	print("   1. Acesse: https://console.firebase.google.com/")
	print("   2. Projeto: cinco-words")
	print("   3. Authentication > Sign-in method > Habilitar Anonymous")
	
	# Como fallback final, opera em modo offline
	is_online = false
	print("🔌 Modo offline ativado - jogando sem conexão com Firebase")
