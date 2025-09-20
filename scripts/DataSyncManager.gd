extends Node

# ===== GERENCIADOR DE SINCRONIZAÇÃO DE DADOS WORDMIX =====
# Compara dados locais vs Firebase e mantém a versão mais recente
# Gerencia cache local para carregamento rápido

# Sinais
signal sync_started
signal sync_completed(updated_data: Dictionary)
signal sync_failed(error: String)
signal data_conflict_resolved(resolution: String)

# Configurações
const CACHE_FILE = "user://game_cache.json"
const BACKUP_FILE = "user://game_backup.json"
const SYNC_INTERVAL = 30.0  # Sincroniza a cada 30 segundos

# Dados de cache
var local_cache: Dictionary = {}
var firebase_data: Dictionary = {}
var last_sync_timestamp: float = 0.0
var sync_in_progress: bool = false

# Timer para sincronização automática
var sync_timer: Timer = null

# Referências
var global_ref: Node = null
var persistent_id_manager: Node = null

# ===== INICIALIZAÇÃO =====

func _ready():
	print("🔄 Inicializando DataSyncManager...")
	setup_sync_timer()
	load_cache()

func initialize(global_node: Node, id_manager: Node):
	global_ref = global_node
	persistent_id_manager = id_manager
	print("✅ DataSyncManager inicializado com referências")

func setup_sync_timer():
	sync_timer = Timer.new()
	sync_timer.wait_time = SYNC_INTERVAL
	sync_timer.timeout.connect(_on_sync_timer_timeout)
	add_child(sync_timer)

# ===== GERENCIAMENTO DE CACHE =====

func load_cache():
	var file = FileAccess.open(CACHE_FILE, FileAccess.READ)
	if file == null:
		print("📁 Cache não encontrado, criando novo")
		local_cache = create_default_cache()
		save_cache()
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		local_cache = json.data
		last_sync_timestamp = local_cache.get("last_sync", 0.0)
		print("📁 Cache carregado: ", local_cache.size(), " itens")
		print("   • Última sincronização: ", Time.get_datetime_string_from_unix_time(last_sync_timestamp))
	else:
		print("❌ Erro ao carregar cache, criando novo")
		local_cache = create_default_cache()

func save_cache():
	# Atualiza timestamp
	local_cache["last_sync"] = Time.get_unix_time_from_system()
	local_cache["cache_version"] = "1.0"
	
	var file = FileAccess.open(CACHE_FILE, FileAccess.WRITE)
	if file == null:
		print("❌ Erro ao salvar cache")
		return
	
	var json_string = JSON.stringify(local_cache)
	file.store_string(json_string)
	file.close()
	print("💾 Cache salvo com sucesso")

func create_default_cache() -> Dictionary:
	return {
		"player_data": {
			"points": 0,
			"gold": 0,
			"crystal": 0,
			"level": 1,
			"unlocked_characters": [0]
		},
		"game_progress": {},
		"settings": {},
		"last_sync": 0.0,
		"cache_version": "1.0"
	}

# ===== SINCRONIZAÇÃO PRINCIPAL =====

func start_sync():
	if sync_in_progress:
		print("⚠️ Sincronização já em andamento")
		return
	
	if not global_ref or not persistent_id_manager:
		print("❌ Referências não inicializadas")
		emit_signal("sync_failed", "Referências não inicializadas")
		return
	
	sync_in_progress = true
	emit_signal("sync_started")
	print("🔄 Iniciando sincronização de dados...")
	
	# 1. Carrega dados atuais do Global
	var current_global_data = get_current_global_data()
	
	# 2. Compara com cache local
	var local_comparison = compare_with_local_cache(current_global_data)
	
	# 3. Se Firebase estiver disponível, compara com ele
	if global_ref.is_online:
		await compare_with_firebase(current_global_data)
	else:
		print("📡 Firebase offline, usando apenas cache local")
	
	# 4. Resolve conflitos e atualiza dados
	var resolved_data = resolve_data_conflicts(current_global_data, local_comparison)
	
	# 5. Atualiza Global com dados resolvidos
	update_global_data(resolved_data)
	
	# 6. Salva cache atualizado
	update_cache_with_resolved_data(resolved_data)
	save_cache()
	
	sync_in_progress = false
	last_sync_timestamp = Time.get_unix_time_from_system()
	
	emit_signal("sync_completed", resolved_data)
	print("✅ Sincronização concluída")

func get_current_global_data() -> Dictionary:
	if not global_ref:
		return {}
	
	return {
		"points": global_ref.points,
		"gold": global_ref.gold,
		"crystal": global_ref.crystal,
		"level": global_ref.level,
		"player_name": global_ref.player_name,
		"selected_avatar": global_ref.selected_avatar,
		"unlocked_characters": global_ref.unlocked_characters,
		"timestamp": Time.get_unix_time_from_system()
	}

func compare_with_local_cache(current_data: Dictionary) -> Dictionary:
	var cached_player_data = local_cache.get("player_data", {})
	var comparison = {
		"needs_update": false,
		"conflicts": [],
		"newer_data": {}
	}
	
	# Compara cada campo
	for key in current_data:
		if key == "timestamp":
			continue
			
		var current_value = current_data[key]
		var cached_value = cached_player_data.get(key, null)
		
		if cached_value != null and cached_value != current_value:
			comparison.conflicts.append({
				"field": key,
				"current": current_value,
				"cached": cached_value
			})
			comparison.needs_update = true
	
	print("🔍 Comparação com cache local:")
	print("   • Conflitos encontrados: ", comparison.conflicts.size())
	
	return comparison

func compare_with_firebase(current_data: Dictionary):
	if not global_ref.is_online:
		return
	
	print("🔍 Comparando com Firebase...")
	# Esta função será expandida quando a integração Firebase estiver completa
	await get_tree().create_timer(0.1).timeout

func resolve_data_conflicts(current_data: Dictionary, local_comparison: Dictionary) -> Dictionary:
	var resolved_data = current_data.duplicate()
	
	# Estratégia: prioriza dados mais recentes ou com valores maiores (para pontos, gold, etc.)
	for conflict in local_comparison.conflicts:
		var field = conflict.field
		var current_value = conflict.current
		var cached_value = conflict.cached
		
		match field:
			"points", "gold", "crystal":
				# Para recursos, usa o maior valor
				resolved_data[field] = max(current_value, cached_value)
				print("⚖️ Conflito resolvido para ", field, ": ", resolved_data[field])
			
			"level":
				# Para nível, usa o maior
				resolved_data[field] = max(current_value, cached_value)
				print("⚖️ Conflito resolvido para ", field, ": ", resolved_data[field])
			
			"unlocked_characters":
				# Para personagens, faz união dos arrays
				var merged_characters = []
				for char in current_value:
					if not merged_characters.has(char):
						merged_characters.append(char)
				for char in cached_value:
					if not merged_characters.has(char):
						merged_characters.append(char)
				resolved_data[field] = merged_characters
				print("⚖️ Conflito resolvido para ", field, ": ", resolved_data[field])
			
			_:
				# Para outros campos, mantém o valor atual
				resolved_data[field] = current_value
	
	emit_signal("data_conflict_resolved", "Conflitos resolvidos com sucesso")
	return resolved_data

func update_global_data(resolved_data: Dictionary):
	if not global_ref:
		return
	
	# Atualiza Global com dados resolvidos
	global_ref.points = resolved_data.get("points", global_ref.points)
	global_ref.gold = resolved_data.get("gold", global_ref.gold)
	global_ref.crystal = resolved_data.get("crystal", global_ref.crystal)
	global_ref.level = resolved_data.get("level", global_ref.level)
	global_ref.selected_avatar = resolved_data.get("selected_avatar", global_ref.selected_avatar)
	global_ref.unlocked_characters = resolved_data.get("unlocked_characters", global_ref.unlocked_characters)
	
	print("🔄 Dados do Global atualizados")

func update_cache_with_resolved_data(resolved_data: Dictionary):
	local_cache["player_data"] = {
		"points": resolved_data.get("points", 0),
		"gold": resolved_data.get("gold", 0),
		"crystal": resolved_data.get("crystal", 0),
		"level": resolved_data.get("level", 1),
		"selected_avatar": resolved_data.get("selected_avatar", 0),
		"unlocked_characters": resolved_data.get("unlocked_characters", [0]),
		"last_updated": Time.get_unix_time_from_system()
	}

# ===== SINCRONIZAÇÃO AUTOMÁTICA =====

func start_auto_sync():
	if sync_timer:
		sync_timer.start()
		print("🔄 Sincronização automática iniciada")

func stop_auto_sync():
	if sync_timer:
		sync_timer.stop()
		print("⏹️ Sincronização automática parada")

func _on_sync_timer_timeout():
	print("⏰ Timer de sincronização disparado")
	start_sync()

# ===== FUNÇÕES UTILITÁRIAS =====

func get_cached_data(key: String, default_value = null):
	return local_cache.get(key, default_value)

func update_cached_data(key: String, value):
	local_cache[key] = value
	save_cache()

func force_sync():
	print("🔄 Forçando sincronização...")
	start_sync()

func create_backup():
	var backup_data = local_cache.duplicate()
	backup_data["backup_timestamp"] = Time.get_unix_time_from_system()
	
	var file = FileAccess.open(BACKUP_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(backup_data))
		file.close()
		print("💾 Backup criado com sucesso")

# ===== LIMPEZA =====

func _exit_tree():
	if sync_in_progress:
		print("⚠️ Sincronização interrompida ao sair")
	stop_auto_sync()