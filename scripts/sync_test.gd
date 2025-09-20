extends Node

# Script para testar sincronização de dados

func _ready():
	print("🚀 Testando sincronização de dados...")
	test_sync()

func test_sync():
	print("📊 Status atual do Global:")
	print("  Online: ", Global.is_online)
	print("  Player ID: ", Global.player_id.substr(0, 8) + "..." if Global.player_id.length() > 8 else Global.player_id)
	print("  Player Name: ", Global.player_name)
	print("  Points: ", Global.points)
	print("  Gold: ", Global.gold)
	print("  Crystal: ", Global.crystal)
	
	# Se offline, tenta reconectar
	if not Global.is_online:
		print("🔄 Tentando reconectar...")
		Global._try_manual_firebase_auth()
		await get_tree().create_timer(3.0).timeout
		print("  Status após reconexão: ", Global.is_online)
	
	# Força sincronização
	if Global.is_online and Global.player_id != "":
		print("📤 Forçando sincronização...")
		Global.sync_data()
		Global.save_player_data_to_firebase()
		print("✅ Dados enviados!")
		
		# Aguarda e tenta carregar para verificar
		await get_tree().create_timer(2.0).timeout
		print("🔄 Verificando dados no Firebase...")
		Global.load_player_data_from_firebase()
		
		await get_tree().create_timer(3.0).timeout
		print("✅ Teste concluído!")
	else:
		print("❌ Não foi possível sincronizar")
	
	# Mostra dados locais
	show_local_data()
	
	# Sai do jogo
	get_tree().quit()

func show_local_data():
	print("\n📁 Dados locais salvos:")
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	
	if err == OK:
		print("  Nome: ", config.get_value("player", "name", "N/A"))
		print("  Pontos: ", config.get_value("player", "points", 0))
		print("  Ouro: ", config.get_value("player", "gold", 0))
		print("  Cristais: ", config.get_value("player", "crystal", 0))
	else:
		print("  ❌ Erro ao carregar dados locais")