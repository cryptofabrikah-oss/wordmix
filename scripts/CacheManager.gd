extends Node

# Sistema robusto de cache para persistência de dados do jogo
# Resolve problemas identificados nos testes 1 e 3

signal cache_updated(data: Dictionary)
signal cache_error(error_message: String)

# Configurações do cache
const CACHE_FILE = "user://game_cache.dat"
const BACKUP_CACHE_FILE = "user://game_cache_backup.dat"
const CACHE_VERSION = "2.0"
const MAX_CACHE_SIZE = 1024 * 1024  # 1MB
const CACHE_ENCRYPTION_KEY = "wordmix_cache_2024"

# Estado do cache
var cache_data: Dictionary = {}
var cache_loaded: bool = false
var cache_dirty: bool = false
var auto_save_enabled: bool = true
var auto_save_interval: float = 30.0  # 30 segundos

# Timer para auto-save
var auto_save_timer: Timer

func _ready():
	print("🗄️ Inicializando CacheManager...")
	setup_auto_save()
	load_cache()

func _exit_tree():
	if cache_dirty:
		save_cache()

# ===== CONFIGURAÇÃO =====

func setup_auto_save():
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	auto_save_timer.autostart = true
	add_child(auto_save_timer)
	print("⏰ Auto-save configurado para " + str(auto_save_interval) + " segundos")

func _on_auto_save_timeout():
	if cache_dirty and auto_save_enabled:
		save_cache()

# ===== OPERAÇÕES PRINCIPAIS =====

func load_cache():
	print("📂 Carregando cache...")
	
	var config = ConfigFile.new()
	var err = config.load(CACHE_FILE)
	
	# Se arquivo principal falhou, tenta backup
	if err != OK:
		print("⚠️ Cache principal falhou, tentando backup...")
		err = config.load(BACKUP_CACHE_FILE)
		
		if err != OK:
			print("🆕 Inicializando cache vazio")
			_initialize_empty_cache()
			return true
	
	# Carrega dados do cache
	cache_data.clear()
	
	# Carrega seção cache
	if config.has_section("cache"):
		for key in config.get_section_keys("cache"):
			cache_data[key] = config.get_value("cache", key)
	
	# Verifica versão
	var file_version = config.get_value("metadata", "version", "1.0")
	if file_version != CACHE_VERSION:
		print("⚠️ Versão do cache diferente: " + file_version + " vs " + CACHE_VERSION)
	
	cache_loaded = true
	print("✅ Cache carregado: " + str(cache_data.size()) + " itens")
	return true

func _load_cache_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("❌ Erro ao abrir arquivo de cache: " + file_path)
		return false
	
	# Lê dados criptografados
	var encrypted_data = file.get_buffer(file.get_length())
	file.close()
	
	# Descriptografa
	var crypto = Crypto.new()
	var key = CACHE_ENCRYPTION_KEY.to_utf8_buffer().slice(0, 32)  # 32 bytes para AES
	
	var decrypted_data = crypto.decrypt(key, encrypted_data)
	if decrypted_data.is_empty():
		print("❌ Erro ao descriptografar cache")
		return false
	
	# Converte de JSON
	var json_string = decrypted_data.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Erro ao parsear JSON do cache")
		return false
	
	var loaded_data = json.data
	
	# Valida estrutura do cache
	if not _validate_cache_structure(loaded_data):
		print("❌ Estrutura do cache inválida")
		return false
	
	cache_data = loaded_data
	return true

func save_cache() -> bool:
	print("💾 Salvando cache...")
	
	if cache_data.is_empty():
		print("⚠️ Cache vazio, nada para salvar")
		return false
	
	var config = ConfigFile.new()
	
	# Salva dados do cache
	for key in cache_data.keys():
		config.set_value("cache", key, cache_data[key])
	
	# Adiciona metadados
	config.set_value("metadata", "last_save", Time.get_unix_time_from_system())
	config.set_value("metadata", "version", CACHE_VERSION)
	
	# Salva arquivo principal
	var err = config.save(CACHE_FILE)
	if err != OK:
		print("❌ Erro ao salvar cache principal: " + str(err))
		return false
	
	# Salva backup
	err = config.save(BACKUP_CACHE_FILE)
	if err != OK:
		print("⚠️ Erro ao salvar backup do cache: " + str(err))
	
	print("✅ Cache salvo com sucesso")
	return true

# ===== OPERAÇÕES DE DADOS =====

func set_value(key: String, value) -> bool:
	if not cache_loaded:
		print("❌ Cache não carregado")
		return false
	
	cache_data["data"][key] = value
	cache_data["metadata"]["last_modified"] = Time.get_unix_time_from_system()
	cache_dirty = true
	
	print("📝 Cache atualizado: " + key + " = " + str(value))
	emit_signal("cache_updated", cache_data)
	return true

func get_value(key: String, default_value = null):
	if not cache_loaded:
		print("❌ Cache não carregado")
		return default_value
	
	return cache_data["data"].get(key, default_value)

func has_key(key: String) -> bool:
	if not cache_loaded:
		return false
	
	return cache_data["data"].has(key)

func remove_key(key: String) -> bool:
	if not cache_loaded:
		return false
	
	if cache_data["data"].has(key):
		cache_data["data"].erase(key)
		cache_data["metadata"]["last_modified"] = Time.get_unix_time_from_system()
		cache_dirty = true
		print("🗑️ Chave removida do cache: " + key)
		emit_signal("cache_updated", cache_data)
		return true
	
	return false

func clear_cache() -> bool:
	if not cache_loaded:
		return false
	
	cache_data["data"].clear()
	cache_data["metadata"]["last_modified"] = Time.get_unix_time_from_system()
	cache_dirty = true
	
	print("🧹 Cache limpo")
	emit_signal("cache_updated", cache_data)
	return true

# ===== OPERAÇÕES BATCH =====

func set_multiple_values(values: Dictionary) -> bool:
	if not cache_loaded:
		return false
	
	for key in values.keys():
		cache_data["data"][key] = values[key]
	
	cache_data["metadata"]["last_modified"] = Time.get_unix_time_from_system()
	cache_dirty = true
	
	print("📝 Cache atualizado em lote: " + str(values.size()) + " itens")
	emit_signal("cache_updated", cache_data)
	return true

func get_multiple_values(keys: Array) -> Dictionary:
	var result = {}
	
	if not cache_loaded:
		return result
	
	for key in keys:
		if cache_data["data"].has(key):
			result[key] = cache_data["data"][key]
	
	return result

# ===== SINCRONIZAÇÃO COM GLOBAL =====

# Sincroniza dados do Global para o cache
func sync_from_global():
	if not cache_loaded:
		print("⚠️ Cache não carregado")
		return
	
	cache_data["player_name"] = Global.player_name
	cache_data["player_gold"] = Global.gold
	cache_data["player_points"] = Global.points
	cache_data["player_level"] = Global.level
	cache_data["player_crystal"] = Global.crystal
	cache_data["player_id"] = Global.player_id
	cache_data["query_token"] = Global.client_query_token
	cache_data["avatar_index"] = Global.selected_avatar
	cache_data["unlocked_characters"] = Global.unlocked_characters
	
	print("🔄 Dados sincronizados do Global para cache")

# Sincroniza dados do cache para o Global
func sync_to_global():
	print("📥 Sincronizando dados do cache para Global...")
	Global.player_name = cache_data.get("player_name", "Jogador")
	Global.gold = cache_data.get("player_gold", 0)
	Global.level = cache_data.get("player_level", 1)
	Global.points = cache_data.get("player_points", 0)
	Global.crystal = cache_data.get("player_crystal", 0)
	Global.selected_avatar = cache_data.get("selected_avatar", 0)
	Global.unlocked_characters = cache_data.get("unlocked_characters", [0])
	Global.player_id = cache_data.get("player_id", "")
	Global.firebase_auth_uid = cache_data.get("firebase_auth_uid", "")
	Global.client_query_token = cache_data.get("client_query_token", "")
	print("✅ Dados sincronizados para Global")

# ===== VALIDAÇÃO E INTEGRIDADE =====

func _validate_cache_structure(data: Dictionary) -> bool:
	# Verifica estrutura básica
	if not data.has("metadata") or not data.has("data"):
		return false
	
	var metadata = data["metadata"]
	if not metadata.has("version") or not metadata.has("created_at"):
		return false
	
	# Verifica versão
	var version = metadata["version"]
	if version != CACHE_VERSION:
		print("⚠️ Versão do cache diferente: " + str(version) + " vs " + CACHE_VERSION)
		# Permite versões diferentes, mas registra
	
	return true

func _verify_cache_integrity() -> bool:
	# Recarrega o arquivo salvo e compara
	var temp_cache = {}
	if _load_cache_file(CACHE_FILE):
		# Compara alguns campos críticos
		var original_gold = cache_data["data"].get("gold", 0)
		var saved_gold = temp_cache.get("data", {}).get("gold", -1)
		
		return original_gold == saved_gold
	
	return false

func _initialize_empty_cache():
	cache_data = {
		"player_name": "",
		"player_gold": 0,
		"player_points": 0,
		"player_level": 1,
		"player_crystal": 0,
		"player_id": "",
		"query_token": "",
		"avatar_index": 0,
		"unlocked_characters": [0]
	}
	cache_loaded = true
	print("🆕 Cache vazio inicializado")

# ===== INFORMAÇÕES E DEBUG =====

func get_cache_info() -> Dictionary:
	if not cache_loaded:
		return {}
	
	var info = {
		"loaded": cache_loaded,
		"dirty": cache_dirty,
		"version": cache_data["metadata"]["version"],
		"created_at": cache_data["metadata"]["created_at"],
		"last_modified": cache_data["metadata"]["last_modified"],
		"last_saved": cache_data["metadata"]["last_saved"],
		"data_count": cache_data["data"].size(),
		"auto_save_enabled": auto_save_enabled,
		"auto_save_interval": auto_save_interval
	}
	
	return info

func print_cache_status():
	var info = get_cache_info()
	print("🗄️ STATUS DO CACHE:")
	print("   Carregado: " + str(info.get("loaded", false)))
	print("   Modificado: " + str(info.get("dirty", false)))
	print("   Versão: " + str(info.get("version", "N/A")))
	print("   Itens: " + str(info.get("data_count", 0)))
	print("   Auto-save: " + str(info.get("auto_save_enabled", false)))

# ===== CONFIGURAÇÕES =====

func set_auto_save_enabled(enabled: bool):
	auto_save_enabled = enabled
	print("⏰ Auto-save " + ("ativado" if enabled else "desativado"))

func set_auto_save_interval(interval: float):
	auto_save_interval = interval
	auto_save_timer.wait_time = interval
	print("⏰ Intervalo de auto-save alterado para " + str(interval) + " segundos")