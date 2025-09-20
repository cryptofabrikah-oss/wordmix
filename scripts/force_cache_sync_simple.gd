extends SceneTree

# Script simplificado para forçar sincronização usando apenas Global

func _initialize():
	print("🚀 Iniciando sincronização forçada simples...")
	await process_frame
	force_sync_via_global()
	quit()

func force_sync_via_global():
	print("📤 Forçando sincronização via Global...")
	
	# Acessa o Global
	var global_node = get_node("/root/Global")
	if not global_node:
		print("❌ Não foi possível acessar o Global")
		return
	
	print("Status do Firebase: ", "Online" if global_node.is_online else "Offline")
	print("Player ID: ", global_node.player_id.substr(0, 8) + "..." if global_node.player_id.length() > 8 else global_node.player_id)
	print("Player Name: ", global_node.player_name)
	print("Points: ", global_node.points)
	print("Gold: ", global_node.gold)
	print("Crystal: ", global_node.crystal)
	
	# Se offline, tenta reconectar
	if not global_node.is_online:
		print("🔄 Tentando reconectar ao Firebase...")
		global_node._try_manual_firebase_auth()
		await create_timer(5.0).timeout
		print("Status após reconexão: ", "Online" if global_node.is_online else "Offline")
	
	# Força sincronização
	if global_node.is_online and global_node.player_id != "":
		print("✅ Enviando dados para Firebase...")
		global_node.sync_data()
		global_node.save_player_data_to_firebase()
		
		# Aguarda um pouco
		await create_timer(3.0).timeout
		
		print("🔄 Tentando carregar dados do Firebase para verificar...")
		global_node.load_player_data_from_firebase()
		
		# Aguarda mais um pouco para o carregamento
		await create_timer(5.0).timeout
		
		print("✅ Sincronização concluída!")
	else:
		print("❌ Não foi possível sincronizar: Firebase offline ou ID inválido")
	
	# Mostra dados locais salvos
	show_local_data()

func show_local_data():
	print("\n📁 Verificando dados locais salvos...")
	
	var config_file = "user://player_config.cfg"
	if FileAccess.file_exists(config_file):
		var config = ConfigFile.new()
		config.load(config_file)
		
		print("Dados no arquivo local:")
		print("  Nome: ", config.get_value("player", "name", "N/A"))
		print("  ID: ", config.get_value("player", "id", "N/A"))
		print("  Pontos: ", config.get_value("player", "points", 0))
		print("  Ouro: ", config.get_value("player", "gold", 0))
		print("  Cristais: ", config.get_value("player", "crystal", 0))
		print("  Avatar: ", config.get_value("player", "avatar_index", 0))
	else:
		print("❌ Nenhum arquivo de dados local encontrado")