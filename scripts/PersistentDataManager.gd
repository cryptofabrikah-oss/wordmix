extends Node

# ===== SISTEMA DE DADOS PERSISTENTES WORDMIX =====
# Gerencia IDs únicos, cache local e sincronização com Firebase
# Evita criação de novos players a cada sessão

# Sinais para notificar mudanças
signal data_loaded
signal data_synced
signal sync_failed(error_message: String)

# Configurações do sistema
const LOCAL_DATA_FILE = "user://persistent_data.cfg"  # Arquivo dedicado para dados persistentes
const CACHE_FILE = "user://wordmix_cache.json"
const BACKUP_FILE = "user://wordmix_backup.cfg"
const SESSION_FILE_PATH = "user://firebase_session.save"

# Dados básicos (salvos localmente)
var persistent_player_id: String = ""
var device_uuid: String = ""
var player_name: String = "Jogador"
var settings: Dictionary = {}
var local_progress: Dictionary = {}

# Cache de dados Firebase (para carregamento rápido)
var cached_firebase_data: Dictionary = {}
var last_sync_timestamp: float = 0.0
var cache_valid: bool = false

# Status do sistema
var is_initialized: bool = false
var is_syncing: bool = false
var firebase_available: bool = false

# ===== INICIALIZAÇÃO =====

func _ready():
	print("🔧 Inicializando PersistentDataManager...")
	initialize_system()
	load_firebase_session()  # Carrega sessão Firebase salva

func initialize_system():
	# 1. Gera ou carrega ID único do dispositivo
	generate_or_load_device_uuid()
	
	# 2. Carrega dados locais
	load_local_data()
	
	# 3. Gera ou carrega ID persistente do jogador
	ensure_persistent_player_id()
	
	# 4. Carrega cache se disponível
	load_cache()
	
	# 5. Marca como inicializado
	is_initialized = true
	print("✅ PersistentDataManager inicializado com sucesso")
	print("   • Device UUID: ", device_uuid.substr(0, 8) + "...")
	print("   • Player ID: ", persistent_player_id.substr(0, 8) + "...")
	print("   • Player Name: ", player_name)
	
	# 6. Emite sinal de dados carregados
	emit_signal("data_loaded")

# ===== GERAÇÃO DE IDs ÚNICOS =====

func generate_or_load_device_uuid():
	var config = ConfigFile.new()
	var err = config.load(LOCAL_DATA_FILE)
	
	if err == OK:
		device_uuid = config.get_value("device", "uuid", "")
	
	# Se não existe UUID, gera um novo
	if device_uuid == "":
		device_uuid = generate_unique_uuid()
		save_device_uuid()
		print("🆔 Novo Device UUID gerado: ", device_uuid.substr(0, 8) + "...")
	else:
		print("🆔 Device UUID carregado: ", device_uuid.substr(0, 8) + "...")

func generate_unique_uuid() -> String:
	# Gera UUID baseado em timestamp + random + device info
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi_range(100000, 999999)
	var device_info = OS.get_name() + "_" + str(OS.get_processor_count())
	
	# Cria hash único
	var uuid_string = str(timestamp) + "_" + str(random_part) + "_" + device_info
	return uuid_string.md5_text().substr(0, 16).to_upper()

func save_device_uuid():
	var config = ConfigFile.new()
	config.load(LOCAL_DATA_FILE)  # Carrega existente ou cria novo
	config.set_value("device", "uuid", device_uuid)
	config.set_value("device", "created_at", Time.get_unix_time_from_system())
	var save_result = config.save(LOCAL_DATA_FILE)
	print("💾 Salvando Device UUID - Resultado: ", save_result)
	print("📁 Arquivo: ", LOCAL_DATA_FILE)
	
	# Verifica se foi salvo
	var verify_config = ConfigFile.new()
	var verify_result = verify_config.load(LOCAL_DATA_FILE)
	if verify_result == OK:
		var saved_uuid = verify_config.get_value("device", "uuid", "")
		print("✅ Verificação: UUID salvo = ", saved_uuid.substr(0, 8) + "...")
	else:
		print("❌ Verificação: Falha ao carregar arquivo salvo")

func ensure_persistent_player_id():
	# Se já temos um player_id persistente, usa ele
	if persistent_player_id != "":
		print("🎮 Player ID persistente encontrado: ", persistent_player_id.substr(0, 8) + "...")
		return
	
	# Tenta carregar do arquivo local
	var config = ConfigFile.new()
	var err = config.load(LOCAL_DATA_FILE)
	
	if err == OK:
		persistent_player_id = config.get_value("player", "persistent_id", "")
	
	# Se ainda não tem, gera baseado no device_uuid
	if persistent_player_id == "":
		persistent_player_id = generate_uuid_v4()
		save_persistent_player_id()
		print("🆔 Novo Player ID persistente gerado (UUID v4): ", persistent_player_id.substr(0, 8) + "...")
	else:
		print("🆔 Player ID persistente carregado: ", persistent_player_id.substr(0, 8) + "...")

func save_persistent_player_id():
	var config = ConfigFile.new()
	config.load(LOCAL_DATA_FILE)
	config.set_value("player", "persistent_id", persistent_player_id)
	config.set_value("player", "created_at", Time.get_unix_time_from_system())
	var save_result = config.save(LOCAL_DATA_FILE)
	print("💾 Salvando Player ID - Resultado: ", save_result)
	print("📁 Arquivo: ", LOCAL_DATA_FILE)

# ===== GERENCIAMENTO DE DADOS LOCAIS =====

func load_local_data():
	var config = ConfigFile.new()
	var err = config.load(LOCAL_DATA_FILE)
	
	if err != OK:
		print("📁 Arquivo persistent_data.cfg não encontrado, tentando carregar do sistema antigo...")
		# Tenta carregar do arquivo antigo para migração
		var old_config = ConfigFile.new()
		var old_err = old_config.load("user://player_config.cfg")
		
		if old_err == OK:
			print("🔄 Migrando dados do sistema antigo...")
			player_name = old_config.get_value("player", "name", "Jogador")
			
			# Migra outros dados também
			if old_config.has_section_key("player", "points"):
				local_progress["points"] = old_config.get_value("player", "points", 0)
			if old_config.has_section_key("player", "gold"):
				local_progress["gold"] = old_config.get_value("player", "gold", 0)
			if old_config.has_section_key("player", "crystal"):
				local_progress["crystal"] = old_config.get_value("player", "crystal", 0)
			if old_config.has_section_key("player", "level"):
				local_progress["level"] = old_config.get_value("player", "level", 1)
			if old_config.has_section_key("player", "avatar_index"):
				local_progress["avatar_index"] = old_config.get_value("player", "avatar_index", 0)
			if old_config.has_section_key("player", "id"):
				persistent_player_id = old_config.get_value("player", "id", "")
			
			# Salva no novo formato
			save_local_data()
			print("✅ Migração concluída - Nome: ", player_name)
		else:
			print("📁 Nenhum arquivo de dados encontrado, usando padrões")
			initialize_default_data()
		return
	
	# Carrega dados básicos
	player_name = config.get_value("player", "name", "Jogador")
	persistent_player_id = config.get_value("player", "persistent_id", "")
	
	# Carrega configurações
	settings = config.get_value("settings", "data", {})
	
	# Carrega progresso local
	local_progress = config.get_value("progress", "data", {})
	
	print("📁 Dados locais carregados:")
	print("   • Nome: ", player_name)
	print("   • ID Persistente: ", persistent_player_id.substr(0, 8) + "..." if persistent_player_id != "" else "vazio")
	print("   • Configurações: ", settings.size(), " itens")
	print("   • Progresso: ", local_progress.size(), " itens")

func save_local_data():
	var config = ConfigFile.new()
	
	# Salva dados do jogador
	config.set_value("player", "name", player_name)
	config.set_value("player", "persistent_id", persistent_player_id)
	config.set_value("player", "last_updated", Time.get_unix_time_from_system())
	
	# Salva configurações
	config.set_value("settings", "data", settings)
	
	# Salva progresso local
	config.set_value("progress", "data", local_progress)
	
	# Salva metadados
	config.set_value("meta", "version", "1.0")
	config.set_value("meta", "last_save", Time.get_unix_time_from_system())
	
	var err = config.save(LOCAL_DATA_FILE)
	if err == OK:
		print("💾 Dados salvos com sucesso:")
		print("   • Arquivo: ", LOCAL_DATA_FILE)
		print("   • Nome: ", player_name)
		print("   • ID: ", persistent_player_id.substr(0, 8) + "..." if persistent_player_id != "" else "vazio")
		print("   • Progresso: ", local_progress.size(), " itens")
	else:
		print("❌ Erro ao salvar dados locais: ", err)

func initialize_default_data():
	settings = {
		"sound_enabled": true,
		"music_enabled": true,
		"notifications_enabled": true
	}
	
	local_progress = {
		"games_played": 0,
		"total_score": 0,
		"best_score": 0,
		"achievements": []
	}
	
	save_local_data()

# ===== SISTEMA DE CACHE =====

func load_cache():
	var file = FileAccess.open(CACHE_FILE, FileAccess.READ)
	if file == null:
		print("📦 Nenhum cache encontrado")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Erro ao carregar cache: JSON inválido")
		return
	
	var cache_data = json.data
	
	# Verifica se o cache ainda é válido (ex: menos de 1 hora)
	var cache_age = Time.get_unix_time_from_system() - cache_data.get("timestamp", 0)
	if cache_age > 3600:  # 1 hora
		print("📦 Cache expirado, será renovado")
		cache_valid = false
		return
	
	cached_firebase_data = cache_data.get("data", {})
	last_sync_timestamp = cache_data.get("timestamp", 0)
	cache_valid = true
	
	print("📦 Cache carregado com sucesso")
	print("   • Idade: ", int(cache_age), " segundos")
	print("   • Itens: ", cached_firebase_data.size())

func save_cache(data: Dictionary):
	var cache_data = {
		"timestamp": Time.get_unix_time_from_system(),
		"data": data,
		"player_id": persistent_player_id
	}
	
	var json_string = JSON.stringify(cache_data)
	var file = FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	
	if file == null:
		print("❌ Erro ao salvar cache")
		return
	
	file.store_string(json_string)
	file.close()
	
	cached_firebase_data = data
	last_sync_timestamp = cache_data.timestamp
	cache_valid = true
	
	print("💾 Cache salvo com sucesso")

# ===== GETTERS PÚBLICOS =====

func get_persistent_player_id() -> String:
	return persistent_player_id

func get_device_uuid() -> String:
	return device_uuid

func get_player_name() -> String:
	return player_name

func set_player_name(new_name: String):
	player_name = new_name
	save_local_data()

func get_cached_data() -> Dictionary:
	return cached_firebase_data if cache_valid else {}

func is_cache_valid() -> bool:
	return cache_valid

# ===== UTILITÁRIOS =====

func create_backup():
	var config = ConfigFile.new()
	config.load(LOCAL_DATA_FILE)
	
	var backup_data = {
		"backup_timestamp": Time.get_unix_time_from_system(),
		"device_uuid": device_uuid,
		"player_id": persistent_player_id,
		"player_name": player_name,
		"settings": settings,
		"progress": local_progress
	}
	
	config.set_value("backup", "data", backup_data)
	config.save(BACKUP_FILE)
	
	print("🔄 Backup criado com sucesso")

func validate_data_integrity() -> Dictionary:
	"""Valida a integridade dos dados do jogador"""
	var validation_result = {
		"is_valid": true,
		"issues": [],
		"warnings": []
	}
	
	# Verifica dados básicos
	if player_name == "" or player_name == null:
		validation_result.issues.append("Nome do jogador vazio")
		validation_result.is_valid = false
	
	# Verifica valores negativos
	if local_progress.get("points", 0) < 0:
		validation_result.issues.append("Pontos negativos: " + str(local_progress.get("points", 0)))
		validation_result.is_valid = false
	
	if local_progress.get("gold", 0) < 0:
		validation_result.issues.append("Gold negativo: " + str(local_progress.get("gold", 0)))
		validation_result.is_valid = false
	
	if local_progress.get("crystal", 0) < 0:
		validation_result.issues.append("Crystal negativo: " + str(local_progress.get("crystal", 0)))
		validation_result.is_valid = false
	
	# Verifica avatar válido
	var avatar_index = local_progress.get("avatar_index", 0)
	if avatar_index < 0 or avatar_index >= 5:  # Assumindo 5 avatares
		validation_result.warnings.append("Índice de avatar inválido: " + str(avatar_index))
		local_progress["avatar_index"] = 0  # Corrige automaticamente
	
	# Verifica personagens desbloqueados
	var unlocked = local_progress.get("unlocked_characters", [])
	if not unlocked is Array or unlocked.size() == 0:
		validation_result.warnings.append("Lista de personagens desbloqueados inválida")
		local_progress["unlocked_characters"] = [0]  # Corrige automaticamente
	
	# Verifica se o avatar selecionado está desbloqueado
	if not unlocked.has(avatar_index):
		validation_result.warnings.append("Avatar selecionado não está desbloqueado")
		local_progress["avatar_index"] = unlocked[0]  # Usa o primeiro desbloqueado
	
	return validation_result

func fix_data_inconsistencies():
	"""Corrige inconsistências conhecidas nos dados"""
	var validation = validate_data_integrity()
	
	if validation.warnings.size() > 0:
		print("🔧 Corrigindo inconsistências nos dados:")
		for warning in validation.warnings:
			print("   • " + warning)
		
		# Salva dados corrigidos
		save_local_data()
		print("✅ Inconsistências corrigidas e dados salvos")
	
	return validation.is_valid

func get_system_info() -> Dictionary:
	return {
		"initialized": is_initialized,
		"device_uuid": device_uuid,
		"player_id": persistent_player_id,
		"player_name": player_name,
		"cache_valid": cache_valid,
		"last_sync": last_sync_timestamp,
		"local_data_size": local_progress.size(),
		"cached_data_size": cached_firebase_data.size(),
		"firebase_session_active": is_firebase_session_active(),
		"firebase_auth_id": firebase_auth_id.substr(0, 8) + "..." if firebase_auth_id != "" else "none"
	}

var firebase_auth_id: String = ""
var session_active: bool = false

func save_firebase_auth_session(auth_id: String):
	"""Salva o Firebase Auth ID para reutilizar a sessão"""
	firebase_auth_id = auth_id
	session_active = true
	
	var session_data = {
		"firebase_auth_id": firebase_auth_id,
		"session_timestamp": Time.get_unix_time_from_system(),
		"session_active": true,
		"device_uuid": device_uuid,
		"player_id": persistent_player_id
	}
	
	var file = FileAccess.open(SESSION_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(session_data))
		file.close()
		print("💾 Sessão Firebase salva: ", auth_id.substr(0, 8) + "...")
		return true
	else:
		print("❌ Erro ao salvar sessão Firebase")
		return false

func load_firebase_session() -> Dictionary:
	"""Carrega a sessão Firebase salva"""
	if not FileAccess.file_exists(SESSION_FILE_PATH):
		print("📂 Nenhuma sessão Firebase encontrada")
		return {}
	
	var file = FileAccess.open(SESSION_FILE_PATH, FileAccess.READ)
	if not file:
		print("❌ Erro ao abrir arquivo de sessão")
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Erro ao parsear sessão Firebase")
		return {}
	
	var session_data = json.data
	
	# Verifica se a sessão ainda é válida (24 horas)
	var current_time = Time.get_unix_time_from_system()
	var session_time = session_data.get("session_timestamp", 0)
	var session_age = current_time - session_time
	
	if session_age > 86400:  # 24 horas em segundos
		print("⏰ Sessão Firebase expirada")
		clear_firebase_session()
		return {}
	
	firebase_auth_id = session_data.get("firebase_auth_id", "")
	session_active = session_data.get("session_active", false)
	
	if firebase_auth_id != "":
		print("🔄 Sessão Firebase carregada: ", firebase_auth_id.substr(0, 8) + "...")
		return session_data
	
	return {}

func clear_firebase_session():
	"""Limpa a sessão Firebase"""
	firebase_auth_id = ""
	session_active = false
	
	if FileAccess.file_exists(SESSION_FILE_PATH):
		DirAccess.remove_absolute(SESSION_FILE_PATH)
		print("🗑️ Sessão Firebase limpa")

func get_firebase_auth_id() -> String:
	"""Retorna o Firebase Auth ID da sessão ativa"""
	return firebase_auth_id

func is_firebase_session_active() -> bool:
	"""Verifica se há uma sessão Firebase ativa"""
	return session_active and firebase_auth_id != ""

func generate_uuid_v4() -> String:\n    var bytes = PackedByteArray()\n    for i in range(16):\n        bytes.append(randi() % 256)\n    bytes[6] = (bytes[6] & 0x0f) | 0x40\n    bytes[8] = (bytes[8] & 0x3f) | 0x80\n    var uuid = \"\"\n    for i in range(16):\n        if i == 4 or i == 6 or i == 8 or i == 10:\n            uuid += \"-\"\n        uuid += \"%02x\" % bytes[i]\n    return uuid.to_lower()
