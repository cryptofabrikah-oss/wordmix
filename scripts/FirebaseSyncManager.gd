extends Node

# ===== SISTEMA DE SINCRONIZAÇÃO FIREBASE =====
# Gerencia sincronização inteligente entre dados locais e Firebase
# Trabalha em conjunto com PersistentDataManager

# Sinais
signal sync_started
signal sync_completed(success: bool)
signal sync_progress(current: int, total: int)
signal conflict_detected(local_data: Dictionary, remote_data: Dictionary)

# Referências
var persistent_data_manager
var firebase_ref = null
var is_online: bool = false

# Configurações de sincronização
const SYNC_TIMEOUT = 30.0  # 30 segundos
const MAX_RETRY_ATTEMPTS = 3
const SYNC_BATCH_SIZE = 10

# Status da sincronização
var is_syncing: bool = false
var sync_queue: Array = []
var retry_count: int = 0
var last_successful_sync: float = 0.0

# Dados para sincronização
var pending_uploads: Dictionary = {}
var conflict_resolution_mode: String = "merge"  # "local", "remote", "merge"

# ===== SISTEMA DE CACHE OFFLINE =====

var offline_cache: Dictionary = {}
var offline_operations: Array = []
var cache_file_path = "user://offline_cache.json"
var operations_file_path = "user://offline_operations.json"

func _ready():
	print("🔄 Inicializando FirebaseSyncManager...")
	load_offline_cache()
	load_offline_operations()

func load_offline_cache():
	"""Carrega cache offline salvo"""
	if not FileAccess.file_exists(cache_file_path):
		print("📦 Nenhum cache offline encontrado")
		return
	
	var file = FileAccess.open(cache_file_path, FileAccess.READ)
	if not file:
		print("❌ Erro ao abrir cache offline")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Erro ao parsear cache offline")
		return
	
	offline_cache = json.data
	print("📦 Cache offline carregado: ", offline_cache.size(), " itens")

func save_offline_cache():
	"""Salva cache offline"""
	var file = FileAccess.open(cache_file_path, FileAccess.WRITE)
	if not file:
		print("❌ Erro ao salvar cache offline")
		return
	
	file.store_string(JSON.stringify(offline_cache))
	file.close()
	print("💾 Cache offline salvo: ", offline_cache.size(), " itens")

func load_offline_operations():
	"""Carrega operações offline pendentes"""
	if not FileAccess.file_exists(operations_file_path):
		print("📋 Nenhuma operação offline pendente")
		return
	
	var file = FileAccess.open(operations_file_path, FileAccess.READ)
	if not file:
		print("❌ Erro ao abrir operações offline")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("❌ Erro ao parsear operações offline")
		return
	
	offline_operations = json.data
	print("📋 Operações offline carregadas: ", offline_operations.size(), " pendentes")

func save_offline_operations():
	"""Salva operações offline pendentes"""
	var file = FileAccess.open(operations_file_path, FileAccess.WRITE)
	if not file:
		print("❌ Erro ao salvar operações offline")
		return
	
	file.store_string(JSON.stringify(offline_operations))
	file.close()
	print("💾 Operações offline salvas: ", offline_operations.size(), " pendentes")

func add_offline_operation(operation_type: String, data: Dictionary, timestamp: float = 0.0):
	"""Adiciona uma operação para ser executada quando voltar online"""
	if timestamp == 0.0:
		timestamp = Time.get_unix_time_from_system()
	
	var operation = {
		"type": operation_type,
		"data": data,
		"timestamp": timestamp,
		"id": generate_operation_id()
	}
	
	offline_operations.append(operation)
	save_offline_operations()
	
	print("📝 Operação offline adicionada: ", operation_type)

func generate_operation_id() -> String:
	"""Gera ID único para operação"""
	var timestamp = Time.get_unix_time_from_system()
	var random_part = randi_range(1000, 9999)
	return str(timestamp) + "_" + str(random_part)

# ===== MODO OFFLINE =====

func get_data_offline(key: String) -> Dictionary:
	"""Obtém dados do cache offline"""
	if offline_cache.has(key):
		print("📦 Dados obtidos do cache offline: ", key)
		return offline_cache[key]
	
	print("❌ Dados não encontrados no cache offline: ", key)
	return {}

func save_data_offline(key: String, data: Dictionary):
	"""Salva dados no cache offline"""
	offline_cache[key] = data
	save_offline_cache()
	
	# Adiciona operação para sincronizar quando voltar online
	add_offline_operation("save", {"key": key, "data": data})
	
	print("💾 Dados salvos offline: ", key)

func update_data_offline(key: String, updates: Dictionary):
	"""Atualiza dados no cache offline"""
	if not offline_cache.has(key):
		offline_cache[key] = {}
	
	# Merge dos dados
	for update_key in updates:
		offline_cache[key][update_key] = updates[update_key]
	
	save_offline_cache()
	
	# Adiciona operação para sincronizar quando voltar online
	add_offline_operation("update", {"key": key, "updates": updates})
	
	print("🔄 Dados atualizados offline: ", key)

func delete_data_offline(key: String):
	"""Remove dados do cache offline"""
	if offline_cache.has(key):
		offline_cache.erase(key)
		save_offline_cache()
	
	# Adiciona operação para sincronizar quando voltar online
	add_offline_operation("delete", {"key": key})
	
	print("🗑️ Dados removidos offline: ", key)

func initialize(data_manager):
	persistent_data_manager = data_manager
	
	# Conecta sinais do data manager
	if persistent_data_manager.connect("data_loaded", _on_local_data_loaded) != OK:
		print("❌ Erro ao conectar signal data_loaded")
	
	print("✅ FirebaseSyncManager inicializado")

func set_firebase_reference(ref):
	firebase_ref = ref
	is_online = (ref != null)
	print("🔗 Referência Firebase configurada: ", "Online" if is_online else "Offline")

# ===== SINCRONIZAÇÃO PRINCIPAL =====

func sync_all_data() -> bool:
	if is_syncing:
		print("⚠️  Sincronização já em andamento")
		return false
	
	if not is_online or firebase_ref == null:
		print("❌ Não é possível sincronizar: Firebase offline")
		return false
	
	if persistent_data_manager == null or not persistent_data_manager.is_initialized:
		print("❌ PersistentDataManager não inicializado")
		return false
	
	print("🔄 Iniciando sincronização completa...")
	is_syncing = true
	retry_count = 0
	emit_signal("sync_started")
	
	# Executa sincronização em etapas
	await _perform_sync_sequence()
	
	return true

func _perform_sync_sequence():
	var success = true
	
	# 1. Carrega dados remotos
	emit_signal("sync_progress", 1, 4)
	var remote_data = await _load_remote_data()
	
	if remote_data == null:
		success = false
		print("❌ Erro ao carregar dados remotos")
	else:
		# 2. Compara com dados locais
		emit_signal("sync_progress", 2, 4)
		var sync_plan = _create_sync_plan(remote_data)
		
		# 3. Resolve conflitos se necessário
		emit_signal("sync_progress", 3, 4)
		if sync_plan.has_conflicts:
			await _resolve_conflicts(sync_plan)
		
		# 4. Aplica mudanças
		emit_signal("sync_progress", 4, 4)
		await _apply_sync_changes(sync_plan)
		
		last_successful_sync = Time.get_unix_time_from_system()
		print("✅ Sincronização concluída com sucesso")
	
	# Se falhou, tenta novamente se não excedeu limite
	if not success and retry_count < MAX_RETRY_ATTEMPTS:
		retry_count += 1
		print("🔄 Tentativa ", retry_count, "/", MAX_RETRY_ATTEMPTS)
		await get_tree().create_timer(2.0).timeout
		await _perform_sync_sequence()
		return
	
	is_syncing = false
	emit_signal("sync_completed", success)

# ===== CARREGAMENTO DE DADOS REMOTOS =====

func _load_remote_data() -> Dictionary:
	if not is_online:
		return {}
	
	print("📥 Carregando dados do Firebase...")
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var remote_ref = firebase_ref.child("players").child(player_id)
	
	# Cria promise para aguardar resposta
	var data_received = false
	var remote_data = {}
	
	# Conecta callback temporário
	var callback = func(data):
		remote_data = data if data != null else {}
		data_received = true
	
	remote_ref.connect("new_data_update", callback, CONNECT_ONE_SHOT)
	
	# Solicita dados
	remote_ref.get_data()
	
	# Aguarda resposta com timeout
	var timeout = 0.0
	while not data_received and timeout < SYNC_TIMEOUT:
		await get_tree().process_frame
		timeout += get_process_delta_time()
	
	if timeout >= SYNC_TIMEOUT:
		print("⏰ Timeout ao carregar dados remotos")
		return {}
	
	print("📥 Dados remotos carregados: ", remote_data.size(), " itens")
	return remote_data

# ===== PLANEJAMENTO DE SINCRONIZAÇÃO =====

func _create_sync_plan(remote_data: Dictionary) -> Dictionary:
	var plan = {
		"has_conflicts": false,
		"local_newer": [],
		"remote_newer": [],
		"conflicts": [],
		"new_local": [],
		"new_remote": []
	}
	
	var local_data = _get_syncable_local_data()
	var local_timestamp = persistent_data_manager.local_progress.get("last_updated", 0.0)
	var remote_timestamp = remote_data.get("last_updated", 0.0)
	
	print("📊 Analisando dados para sincronização:")
	print("   • Local timestamp: ", local_timestamp)
	print("   • Remote timestamp: ", remote_timestamp)
	
	# Compara timestamps principais
	if local_timestamp > remote_timestamp:
		plan.local_newer.append("main_data")
		print("   • Dados locais mais recentes")
	elif remote_timestamp > local_timestamp:
		plan.remote_newer.append("main_data")
		print("   • Dados remotos mais recentes")
	else:
		print("   • Dados sincronizados")
	
	# Verifica conflitos específicos
	_check_data_conflicts(local_data, remote_data, plan)
	
	return plan

func _check_data_conflicts(local_data: Dictionary, remote_data: Dictionary, plan: Dictionary):
	# Verifica campos específicos que podem ter conflitos
	var conflict_fields = ["points", "gold", "crystal", "unlocked_characters"]
	
	for field in conflict_fields:
		var local_value = local_data.get(field)
		var remote_value = remote_data.get(field)
		
		if local_value != null and remote_value != null and local_value != remote_value:
			plan.conflicts.append({
				"field": field,
				"local_value": local_value,
				"remote_value": remote_value
			})
			plan.has_conflicts = true
			print("⚠️  Conflito detectado em '", field, "': local=", local_value, " remote=", remote_value)

# ===== RESOLUÇÃO DE CONFLITOS =====

func _resolve_conflicts(plan: Dictionary):
	if not plan.has_conflicts:
		return
	
	print("🔧 Resolvendo conflitos...")
	
	for conflict in plan.conflicts:
		var resolution = _resolve_single_conflict(conflict)
		conflict["resolution"] = resolution
		print("   • ", conflict.field, ": usando ", resolution)

func _resolve_single_conflict(conflict: Dictionary) -> String:
	match conflict_resolution_mode:
		"local":
			return "local"
		"remote":
			return "remote"
		"merge":
			return _smart_merge_conflict(conflict)
		_:
			return "local"  # Padrão

# ===== SINCRONIZAÇÃO QUANDO VOLTA ONLINE =====

func process_offline_operations():
	"""Processa todas as operações offline pendentes quando volta online"""
	if not is_online or firebase_ref == null:
		print("❌ Não é possível processar operações: Firebase offline")
		return false
	
	if offline_operations.size() == 0:
		print("✅ Nenhuma operação offline pendente")
		return true
	
	print("🔄 Processando ", offline_operations.size(), " operações offline...")
	
	var processed_operations = []
	var failed_operations = []
	
	for operation in offline_operations:
		var success = await _process_single_offline_operation(operation)
		
		if success:
			processed_operations.append(operation)
			print("✅ Operação processada: ", operation.type, " - ", operation.id)
		else:
			failed_operations.append(operation)
			print("❌ Falha na operação: ", operation.type, " - ", operation.id)
	
	# Remove operações processadas com sucesso
	for processed in processed_operations:
		offline_operations.erase(processed)
	
	# Salva operações que falharam para tentar novamente
	save_offline_operations()
	
	print("📊 Resultado do processamento:")
	print("   • Processadas: ", processed_operations.size())
	print("   • Falharam: ", failed_operations.size())
	print("   • Restantes: ", offline_operations.size())
	
	return failed_operations.size() == 0

func _process_single_offline_operation(operation: Dictionary) -> bool:
	"""Processa uma única operação offline"""
	var op_type = operation.type
	var op_data = operation.data
	
	match op_type:
		"save":
			return await _sync_save_operation(op_data.key, op_data.data)
		"update":
			return await _sync_update_operation(op_data.key, op_data.updates)
		"delete":
			return await _sync_delete_operation(op_data.key)
		_:
			print("❌ Tipo de operação desconhecido: ", op_type)
			return false

func _sync_save_operation(key: String, data: Dictionary) -> bool:
	"""Sincroniza operação de salvamento"""
	if not firebase_ref:
		return false
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var path = "players/" + player_id + "/" + key
	
	var task = firebase_ref.update(path, data)
	await task.task_finished
	
	if task.data == null:
		print("❌ Erro ao sincronizar salvamento: ", key)
		return false
	
	print("✅ Salvamento sincronizado: ", key)
	return true

func _sync_update_operation(key: String, updates: Dictionary) -> bool:
	"""Sincroniza operação de atualização"""
	if not firebase_ref:
		return false
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var path = "players/" + player_id + "/" + key
	
	var task = firebase_ref.update(path, updates)
	await task.task_finished
	
	if task.data == null:
		print("❌ Erro ao sincronizar atualização: ", key)
		return false
	
	print("✅ Atualização sincronizada: ", key)
	return true

func _sync_delete_operation(key: String) -> bool:
	"""Sincroniza operação de remoção"""
	if not firebase_ref:
		return false
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var path = "players/" + player_id + "/" + key
	
	var task = firebase_ref.update(path, null)
	await task.task_finished
	
	if task.data == null:
		print("❌ Erro ao sincronizar remoção: ", key)
		return false
	
	print("✅ Remoção sincronizada: ", key)
	return true

# ===== DETECÇÃO DE CONEXÃO =====

func set_online_status(online: bool):
	"""Define status online/offline e processa operações pendentes se necessário"""
	var was_offline = not is_online
	is_online = online
	
	if online and was_offline:
		print("🌐 Conexão restaurada! Processando operações offline...")
		await process_offline_operations()
		
		# Sincroniza dados completos após processar operações
		await sync_all_data()
	elif not online:
		print("📴 Modo offline ativado")

# ===== UTILITÁRIOS PÚBLICOS =====

func get_offline_status() -> Dictionary:
	"""Retorna informações sobre o status offline"""
	return {
		"is_online": is_online,
		"cached_items": offline_cache.size(),
		"pending_operations": offline_operations.size(),
		"last_sync": last_successful_sync,
		"cache_file_exists": FileAccess.file_exists(cache_file_path),
		"operations_file_exists": FileAccess.file_exists(operations_file_path)
	}

func clear_offline_data():
	"""Limpa todos os dados offline (use com cuidado!)"""
	offline_cache.clear()
	offline_operations.clear()
	
	if FileAccess.file_exists(cache_file_path):
		DirAccess.remove_absolute(cache_file_path)
	
	if FileAccess.file_exists(operations_file_path):
		DirAccess.remove_absolute(operations_file_path)
	
	print("🗑️ Dados offline limpos")

func force_sync_from_cache():
	"""Força sincronização de todos os dados do cache para o Firebase"""
	if not is_online:
		print("❌ Não é possível forçar sync: offline")
		return false
	
	print("🔄 Forçando sincronização do cache...")
	
	for key in offline_cache:
		add_offline_operation("save", {"key": key, "data": offline_cache[key]})
	
	return await process_offline_operations()

# Função para resolução inteligente de conflitos
func _smart_merge_conflict(conflict: Dictionary) -> String:
	var local_val = conflict.local_value
	var remote_val = conflict.remote_value
	var field = conflict.field
	
	# Regras inteligentes de merge
	match field:
		"points", "gold", "crystal":
			# Para recursos, usa o maior valor
			return "local" if local_val > remote_val else "remote"
		
		"unlocked_characters":
			# Para arrays, faz união
			if typeof(local_val) == TYPE_ARRAY and typeof(remote_val) == TYPE_ARRAY:
				var merged = local_val.duplicate()
				for item in remote_val:
					if not merged.has(item):
						merged.append(item)
				conflict["merged_value"] = merged
				return "merged"
			return "local"
		
		_:
			# Para outros campos, prefere local
			return "local"

# ===== APLICAÇÃO DE MUDANÇAS =====

func _apply_sync_changes(plan: Dictionary):
	print("🔄 Aplicando mudanças de sincronização...")
	
	var local_data = _get_syncable_local_data()
	var changes_made = false
	
	# Aplica resoluções de conflitos
	for conflict in plan.conflicts:
		var resolution = conflict.get("resolution", "local")
		var field = conflict.field
		
		match resolution:
			"remote":
				_apply_remote_value(field, conflict.remote_value)
				changes_made = true
			"merged":
				if conflict.has("merged_value"):
					_apply_merged_value(field, conflict.merged_value)
					changes_made = true
			# "local" não precisa fazer nada
	
	# Salva mudanças locais se houve alterações
	if changes_made:
		persistent_data_manager.save_local_data()
		print("💾 Mudanças locais salvas")
	
	# Envia dados para Firebase
	await _upload_to_firebase(local_data)

func _apply_remote_value(field: String, value):
	"""Aplica valor remoto aos dados locais com sincronização adequada"""
	match field:
		"points":
			Global.points = value
			persistent_data_manager.local_progress["points"] = value
		"gold":
			Global.gold = value
			persistent_data_manager.local_progress["gold"] = value
		"crystal":
			Global.crystal = value
			persistent_data_manager.local_progress["crystal"] = value
		"unlocked_characters":
			Global.unlocked_characters = value
			persistent_data_manager.local_progress["unlocked_characters"] = value
		"selected_avatar":
			Global.selected_avatar = value
			persistent_data_manager.local_progress["avatar_index"] = value
		"name":
			Global.player_name = value
			persistent_data_manager.player_name = value
		_:
			print("⚠️  Campo desconhecido para aplicar: ", field)
	
	# Salva dados locais após aplicar mudanças
	persistent_data_manager.save_local_data()

func _apply_merged_value(field: String, value):
	_apply_remote_value(field, value)  # Mesmo processo

func _upload_to_firebase(data: Dictionary):
	if not is_online:
		return
	
	print("📤 Enviando dados para Firebase...")
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var upload_data = data.duplicate()
	upload_data["last_updated"] = Time.get_unix_time_from_system()
	upload_data["synced_at"] = Time.get_unix_time_from_system()
	
	var player_ref = firebase_ref.child("players").child(player_id)
	player_ref.update("", upload_data)
	
	print("📤 Upload concluído")

# ===== UTILITÁRIOS =====

func _get_syncable_local_data() -> Dictionary:
	# Obtém dados do PersistentDataManager para garantir consistência
	return {
		"name": persistent_data_manager.get_player_name(),
		"points": persistent_data_manager.local_progress.get("points", Global.points),
		"gold": persistent_data_manager.local_progress.get("gold", Global.gold),
		"crystal": persistent_data_manager.local_progress.get("crystal", Global.crystal),
		"selected_avatar": persistent_data_manager.local_progress.get("avatar_index", Global.selected_avatar),
		"unlocked_characters": persistent_data_manager.local_progress.get("unlocked_characters", Global.unlocked_characters),
		"level": Global.level,
		"last_updated": Time.get_unix_time_from_system()
	}

func _on_local_data_loaded():
	print("📁 Dados locais carregados, preparando para sincronização")
	
	# Se estiver online, inicia sincronização automática
	if is_online:
		await get_tree().create_timer(1.0).timeout  # Aguarda um pouco
		sync_all_data()

# ===== SINCRONIZAÇÃO INCREMENTAL =====

func sync_single_field(field_name: String, value) -> bool:
	if not is_online:
		return false
	
	print("🔄 Sincronizando campo: ", field_name)
	
	var player_id = persistent_data_manager.get_persistent_player_id()
	var field_data = {
		field_name: value,
		"last_updated": Time.get_unix_time_from_system()
	}
	
	var player_ref = firebase_ref.child("players").child(player_id)
	player_ref.update("", field_data)
	
	return true

func get_sync_status() -> Dictionary:
	return {
		"is_syncing": is_syncing,
		"is_online": is_online,
		"last_sync": last_successful_sync,
		"retry_count": retry_count,
		"pending_uploads": pending_uploads.size()
	}

# ===== RESOLUÇÃO DE CONFLITOS =====

func resolve_data_conflicts(local_data: Dictionary, remote_data: Dictionary) -> Dictionary:
	"""Resolve conflitos entre dados locais e remotos usando estratégias inteligentes"""
	print("🔄 Resolvendo conflitos de dados...")
	
	var resolved_data = {}
	
	# Estratégia para pontos: usa o maior valor
	var local_points = local_data.get("points", 0)
	var remote_points = remote_data.get("points", 0)
	resolved_data["points"] = max(local_points, remote_points)
	if local_points != remote_points:
		print("   📊 Pontos: local=" + str(local_points) + ", remoto=" + str(remote_points) + " -> usando " + str(resolved_data["points"]))
	
	# Estratégia para gold: usa o maior valor
	var local_gold = local_data.get("gold", 0)
	var remote_gold = remote_data.get("gold", 0)
	resolved_data["gold"] = max(local_gold, remote_gold)
	if local_gold != remote_gold:
		print("   💰 Gold: local=" + str(local_gold) + ", remoto=" + str(remote_gold) + " -> usando " + str(resolved_data["gold"]))
	
	# Estratégia para crystal: usa o maior valor
	var local_crystal = local_data.get("crystal", 0)
	var remote_crystal = remote_data.get("crystal", 0)
	resolved_data["crystal"] = max(local_crystal, remote_crystal)
	if local_crystal != remote_crystal:
		print("   💎 Crystal: local=" + str(local_crystal) + ", remoto=" + str(remote_crystal) + " -> usando " + str(resolved_data["crystal"]))
	
	# Estratégia para level: usa o maior valor
	var local_level = local_data.get("level", 1)
	var remote_level = remote_data.get("level", 1)
	resolved_data["level"] = max(local_level, remote_level)
	if local_level != remote_level:
		print("   🎯 Level: local=" + str(local_level) + ", remoto=" + str(remote_level) + " -> usando " + str(resolved_data["level"]))
	
	# Estratégia para personagens desbloqueados: união dos arrays
	var local_unlocked = local_data.get("unlocked_characters", [])
	var remote_unlocked = remote_data.get("unlocked_characters", [])
	var merged_unlocked = []
	
	# Adiciona todos os personagens únicos
	for char_id in local_unlocked:
		if not merged_unlocked.has(char_id):
			merged_unlocked.append(char_id)
	
	for char_id in remote_unlocked:
		if not merged_unlocked.has(char_id):
			merged_unlocked.append(char_id)
	
	resolved_data["unlocked_characters"] = merged_unlocked
	if local_unlocked.size() != remote_unlocked.size() or local_unlocked != remote_unlocked:
		print("   👥 Personagens: local=" + str(local_unlocked.size()) + ", remoto=" + str(remote_unlocked.size()) + " -> mesclado=" + str(merged_unlocked.size()))
	
	# Estratégia para avatar selecionado: usa o mais recente baseado no timestamp
	var local_timestamp = local_data.get("last_updated", 0)
	var remote_timestamp = remote_data.get("last_updated", 0)
	
	if remote_timestamp > local_timestamp:
		resolved_data["avatar_index"] = remote_data.get("avatar_index", 0)
		resolved_data["player_name"] = remote_data.get("player_name", "Jogador")
		print("   🕒 Usando dados remotos mais recentes (timestamp: " + str(remote_timestamp) + ")")
	else:
		resolved_data["avatar_index"] = local_data.get("avatar_index", 0)
		resolved_data["player_name"] = local_data.get("player_name", "Jogador")
		print("   🕒 Usando dados locais mais recentes (timestamp: " + str(local_timestamp) + ")")
	
	# Atualiza timestamp para o mais recente
	resolved_data["last_updated"] = max(local_timestamp, remote_timestamp)
	
	# Valida avatar selecionado está desbloqueado
	var selected_avatar = resolved_data["avatar_index"]
	if not resolved_data["unlocked_characters"].has(selected_avatar):
		print("   ⚠️  Avatar selecionado não está desbloqueado, corrigindo...")
		resolved_data["avatar_index"] = resolved_data["unlocked_characters"][0]
	
	print("✅ Conflitos resolvidos com sucesso")
	return resolved_data
