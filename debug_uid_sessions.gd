extends SceneTree

func _init():
	print("=== TESTE DE CONSISTÊNCIA DE IDs COM FIREBASE ===")
	test_firebase_consistency()
	quit()

func test_firebase_consistency():
	print("\n🔍 Testando consistência de IDs entre sessões...")
	
	# Simula primeira sessão
	print("\n--- PRIMEIRA SESSÃO ---")
	var first_session_id = simulate_first_session()
	
	# Simula segunda sessão (reinicialização)
	print("\n--- SEGUNDA SESSÃO (REINICIALIZAÇÃO) ---")
	var second_session_id = simulate_second_session()
	
	# Análise dos resultados
	print("\n=== ANÁLISE DOS RESULTADOS ===")
	print("ID da primeira sessão: ", first_session_id.substr(0, 12) + "...")
	print("ID da segunda sessão: ", second_session_id.substr(0, 12) + "...")
	
	if first_session_id == second_session_id:
		print("✅ SUCESSO: IDs consistentes entre sessões!")
		print("✅ O sistema mantém o mesmo usuário corretamente")
	else:
		print("❌ PROBLEMA: IDs diferentes entre sessões")
		print("❌ Isso causa duplicação de dados no Firebase")
	
	# Verifica se o arquivo persistente existe
	var persistent_file = "user://persistent_player_id.dat"
	if FileAccess.file_exists(persistent_file):
		print("📁 Arquivo de ID persistente encontrado")
	else:
		print("⚠️ Arquivo de ID persistente não encontrado")

func simulate_first_session() -> String:
	print("🚀 Simulando primeira sessão...")
	
	# Simula o comportamento do PersistentIDManager na primeira execução
	var persistent_manager = PersistentIDManager.new()
	persistent_manager.initialize_persistent_id()
	
	# Simula login no Firebase (primeira vez)
	var mock_firebase_id = "VAjCTuD4TCS0VL1ybgHMvEbOC9S2"
	
	# Simula o comportamento do Global.gd
	var player_id = ""
	
	# Verifica se já existe ID persistente
	var existing_id = persistent_manager.get_persistent_id()
	if existing_id != "":
		player_id = existing_id
		print("📋 Usando ID persistente existente: ", player_id.substr(0, 12) + "...")
	else:
		player_id = mock_firebase_id
		persistent_manager.set_persistent_id(player_id)
		print("🆕 Novo ID do Firebase salvo: ", player_id.substr(0, 12) + "...")
	
	return player_id

func simulate_second_session() -> String:
	print("🔄 Simulando segunda sessão (reinicialização)...")
	
	# Simula o comportamento do PersistentIDManager na segunda execução
	var persistent_manager = PersistentIDManager.new()
	persistent_manager.initialize_persistent_id()
	
	# Simula novo login no Firebase (geraria novo ID se não corrigido)
	var mock_new_firebase_id = "y20SynHd5GRyCFQmDgi6zoWm9MT2"
	
	# Simula o comportamento CORRIGIDO do Global.gd
	var player_id = ""
	
	# PRIORIDADE: Verifica se PersistentIDManager já tem um ID salvo
	var existing_id = persistent_manager.get_persistent_id()
	if existing_id != "":
		player_id = existing_id
		print("🔄 Usando ID persistente existente: ", player_id.substr(0, 12) + "...")
	else:
		# Só usa o novo ID do Firebase se não tiver ID persistente
		player_id = mock_new_firebase_id
		persistent_manager.set_persistent_id(player_id)
		print("🆕 Novo ID do Firebase (não deveria acontecer): ", player_id.substr(0, 12) + "...")
	
	return player_id
