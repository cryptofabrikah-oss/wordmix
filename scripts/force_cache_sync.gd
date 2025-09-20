extends Node

# Script para forçar sincronização de dados em cache para Firebase
# Executa automaticamente ao ser carregado

func _ready():
	print("🚀 Iniciando sincronização forçada de cache...")
	await get_tree().process_frame  # Aguarda um frame para garantir que tudo esteja carregado
	force_sync_all_cache()

func force_sync_all_cache():
	print("📤 Forçando envio de todos os dados em cache para Firebase...")
	
	# Acessa o Global através do autoload
	var global_node = get_node("/root/Global")
	if not global_node:
		print("❌ Não foi possível acessar o Global")
		return
	
	# 1. Força sincronização via Global
	if global_node.is_online:
		print("✅ Firebase online - enviando dados do Global...")
		global_node.sync_data()
		global_node.save_player_data_to_firebase()
	else:
		print("❌ Firebase offline - tentando reconectar...")
		global_node._try_manual_firebase_auth()
		await get_tree().create_timer(3.0).timeout
		if global_node.is_online:
			global_node.sync_data()
			global_node.save_player_data_to_firebase()
	
	# 2. Força sincronização via FirebaseSyncManager se existir
	var firebase_sync = get_node_or_null("/root/FirebaseSyncManager")
	if firebase_sync and firebase_sync.has_method("force_sync_from_cache"):
		print("🔄 Executando force_sync_from_cache...")
		var result = await firebase_sync.force_sync_from_cache()
		print("Resultado da sincronização forçada: ", result)
	
	# 3. Força sincronização via DataSyncManager se existir
	var data_sync = get_node_or_null("/root/DataSyncManager")
	if data_sync and data_sync.has_method("force_sync"):
		print("🔄 Executando DataSyncManager.force_sync...")
		data_sync.force_sync()
	
	# 4. Verifica se há dados locais para enviar
	await check_and_send_local_data()
	
	print("✅ Sincronização forçada concluída!")

func check_and_send_local_data():
	print("🔍 Verificando dados locais...")
	
	# Acessa o Global
	var global_node = get_node("/root/Global")
	if not global_node:
		print("❌ Não foi possível acessar o Global")
		return
	
	# Verifica arquivo de configuração local
	var config_file = "user://player_config.cfg"
	if FileAccess.file_exists(config_file):
		print("📁 Encontrado arquivo de configuração local")
		var config = ConfigFile.new()
		config.load(config_file)
		
		# Mostra dados encontrados
		var player_name = config.get_value("player", "name", "")
		var player_id = config.get_value("player", "id", "")
		var points = config.get_value("player", "points", 0)
		var gold = config.get_value("player", "gold", 0)
		var crystal = config.get_value("player", "crystal", 0)
		
		print("Dados locais encontrados:")
		print("  Nome: ", player_name)
		print("  ID: ", player_id.substr(0, 8) + "..." if player_id.length() > 8 else player_id)
		print("  Pontos: ", points)
		print("  Ouro: ", gold)
		print("  Cristais: ", crystal)
		
		# Se há dados e Firebase está online, força envio
		if global_node.is_online and player_id != "":
			print("📤 Enviando dados locais para Firebase...")
			
			var player_data = {
				"name": player_name,
				"points": points,
				"gold": gold,
				"crystal": crystal,
				"selected_avatar": config.get_value("player", "avatar_index", 0),
				"last_updated": Time.get_unix_time_from_system(),
				"synced_at": Time.get_unix_time_from_system()
			}
			
			# Envia para Firebase
			var firebase_ref = Firebase.Database.get_database_reference("players/" + player_id, {})
			firebase_ref.update("", player_data)
			print("✅ Dados enviados para Firebase!")
			
			# Aguarda um pouco e verifica se foi salvo
			await get_tree().create_timer(2.0).timeout
			await verify_data_upload(player_id, player_data)
		else:
			print("❌ Não é possível enviar: Firebase offline ou ID inválido")
	else:
		print("❌ Nenhum arquivo de configuração local encontrado")

func verify_data_upload(player_id: String, sent_data: Dictionary):
	print("🔍 Verificando se dados foram salvos no Firebase...")
	
	var firebase_ref = Firebase.Database.get_database_reference("players/" + player_id, {})
	firebase_ref.connect("new_data_update", _on_verification_data_received.bind(sent_data), CONNECT_ONE_SHOT)
	firebase_ref.connect("no_data_update", _on_verification_no_data, CONNECT_ONE_SHOT)
	firebase_ref.get_data()

func _on_verification_data_received(sent_data: Dictionary, received_data: Dictionary):
	print("📥 Dados recebidos do Firebase para verificação:")
	
	var success = true
	var errors = []
	
	# Verifica cada campo importante
	for key in ["name", "points", "gold", "crystal"]:
		if sent_data.has(key) and received_data.has(key):
			if sent_data[key] == received_data[key]:
				print("  ✅ ", key, ": ", received_data[key], " (OK)")
			else:
				print("  ❌ ", key, ": enviado=", sent_data[key], " recebido=", received_data[key])
				errors.append(key)
				success = false
		else:
			print("  ⚠️ ", key, ": campo ausente")
			errors.append(key)
			success = false
	
	if success:
		print("🎉 SUCESSO! Todos os dados foram enviados e verificados corretamente!")
	else:
		print("❌ ERRO! Problemas encontrados nos campos: ", errors)

func _on_verification_no_data():
	print("❌ ERRO! Nenhum dado encontrado no Firebase após envio!")