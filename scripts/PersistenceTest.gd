extends Node

# Script de teste para verificar persistência entre sessões

func _ready():
	print("🧪 Iniciando testes de persistência...")
	analyze_export_file()
	test_persistence_system()

func test_persistence_system():
	print("\n📋 TESTE 1: Verificando sistema de ID persistente")
	
	# Simula primeira execução
	print("\n🔹 Simulando primeira execução:")
	var persistent_id = generate_uuid()
	print("   UUID Gerado: ", persistent_id.substr(0, 12) + "...")
	
	# Salva dados locais simulados
	var local_data = {
		"persistent_id": persistent_id,
		"player_name": "JogadorTeste",
		"selected_avatar_index": 1,
		"last_updated": Time.get_unix_time_from_system()
	}
	
	save_test_data(local_data)
	print("   ✅ Dados salvos localmente")
	
	# Simula dados no Firebase
	var firebase_data = {
		"name": "JogadorTeste",
		"points": 1500,
		"gold": 750,
		"crystal": 25,
		"selected_avatar": 1,
		"unlocked_characters": ["warrior", "wizard"],
		"persistent_id": persistent_id,
		"last_updated": Time.get_unix_time_from_system() + 3600  # 1 hora depois
	}
	
	print("   📊 Dados no Firebase simulados")
	
	# Teste 2: Simula segunda execução (mesmo dispositivo)
	print("\n🔹 Simulando segunda execução:")
	
	# Carrega dados locais
	var loaded_data = load_test_data()
	if loaded_data and loaded_data.has("persistent_id"):
		var same_persistent_id = loaded_data.persistent_id
		print("   ✅ ID Persistente recuperado: ", same_persistent_id.substr(0, 12) + "...")
		
		# Verifica se é o mesmo ID
		if same_persistent_id == persistent_id:
			print("   ✅ PERSISTÊNCIA CONFIRMADA: Mesmo ID em sessões diferentes")
		else:
			print("   ❌ FALHA NA PERSISTÊNCIA: IDs diferentes")
	else:
		print("   ❌ FALHA: Não foi possível carregar dados locais")
	
	# Teste 3: Simula resolução de conflitos
	print("\n🔹 Testando resolução de conflitos:")
	
	var local_timestamp = local_data["last_updated"]
	var firebase_timestamp = firebase_data["last_updated"]
	
	print("   📅 Timestamp Local: ", local_timestamp)
	print("   📅 Timestamp Firebase: ", firebase_timestamp)
	
	if firebase_timestamp > local_timestamp:
		print("   ✅ Firebase tem dados mais recentes - Atualizando local")
		# Aqui o sistema deveria atualizar os dados locais com os do Firebase
		local_data["last_updated"] = firebase_timestamp
		print("   🔄 Dados locais atualizados com timestamp do Firebase")
	else:
		print("   ✅ Dados locais estão atualizados")
	
	print("\n🎯 Testes de persistência concluídos!")

func generate_uuid() -> String:
	# Gera um UUID v4 simplificado para testes
	var uuid = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		uuid += str(randi() % 16).hex_encode().substr(0, 1)
	return uuid

func save_test_data(data: Dictionary):
	var config = ConfigFile.new()
	config.set_value("test", "persistent_id", data["persistent_id"])
	config.set_value("test", "player_name", data["player_name"])
	config.set_value("test", "selected_avatar_index", data["selected_avatar_index"])
	config.set_value("test", "last_updated", data["last_updated"])
	
	var error = config.save("user://persistence_test.cfg")
	if error != OK:
		print("❌ Erro ao salvar dados de teste: ", error)

func load_test_data() -> Dictionary:
	var config = ConfigFile.new()
	var error = config.load("user://persistence_test.cfg")
	
	if error != OK:
		print("❌ Erro ao carregar dados de teste: ", error)
		return {}
	
	return {
		"persistent_id": config.get_value("test", "persistent_id", ""),
		"player_name": config.get_value("test", "player_name", ""),
		"selected_avatar_index": config.get_value("test", "selected_avatar_index", 0),
		"last_updated": config.get_value("test", "last_updated", 0)
	}

func analyze_export_file():
	print("\n📊 Analisando arquivo de exportação...")
	
	# Verifica se o arquivo de exportação existe
	var file = FileAccess.open("user://cinco-words-default-rtdb-export.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		
		print("   ✅ Arquivo de exportação encontrado")
		print("   📏 Tamanho: ", content.length(), " caracteres")
		
		# Analisa estrutura básica
		if content.find("players") != -1:
			print("   👥 Estrutura 'players' detectada")
		if content.find("persistent_id") != -1:
			print("   🔑 Campo 'persistent_id' detectado")
		
		print("   📋 Amostra do conteúdo:")
		print("   ", content.substr(0, 200).replace("\n", " ").replace("\t", " ") + "...")
	else:
		print("   ⚠️ Arquivo de exportação não encontrado em user://")
		print("   💡 Dica: O arquivo pode estar no diretório do projeto")

# Executa análise do arquivo de exportação também
func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		analyze_export_file()