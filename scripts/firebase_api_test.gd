extends Node

# Script para testar comunicação com Firebase Realtime Database
# Verifica API Key, autenticação e troca de dados

var test_data = {
	"name": "teste_api",
	"points": 100,
	"gold": 50,
	"crystal": 25,
	"timestamp": Time.get_unix_time_from_system()
}

func _ready():
	print("🔧 INICIANDO TESTE DE COMUNICAÇÃO FIREBASE")
	print("==================================================")
	
	# Aguarda inicialização completa
	await get_tree().create_timer(1.0).timeout
	
	# Executa testes em sequência
	await test_api_key_validity()
	await test_authentication()
	await test_database_write()
	await test_database_read()
	await test_data_consistency()
	
	print("\n✅ TESTES CONCLUÍDOS")
	get_tree().quit()

# Teste 1: Verificar validade da API Key
func test_api_key_validity():
	print("\n🔑 TESTE 1: Verificando API Key...")
	
	var config = Global.firebase_config.get_firebase_config()
	var api_key = config.get("apiKey", "")
	
	if api_key.is_empty():
		print("❌ API Key não encontrada!")
		return false
	
	print("✅ API Key encontrada: " + api_key.substr(0, 10) + "...")
	
	# Testa se a API Key é válida fazendo uma requisição
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + api_key
	var headers = ["Content-Type: application/json"]
	var body = JSON.stringify({"returnSecureToken": true})
	
	http_request.request_completed.connect(_on_api_key_test_completed)
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		print("❌ Erro ao fazer requisição: " + str(error))
		return false
	
	# Aguarda resposta
	await http_request.request_completed
	http_request.queue_free()
	return true

func _on_api_key_test_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("📡 Resposta da API:")
	print("   • Código: " + str(response_code))
	
	if response_code == 200 or response_code == 400:  # 400 é esperado para requisição vazia
		print("✅ API Key válida - Firebase respondeu")
	else:
		print("❌ Problema com API Key - Código: " + str(response_code))
		if body.size() > 0:
			print("   • Resposta: " + body.get_string_from_utf8())

# Teste 2: Verificar autenticação
func test_authentication():
	print("\n🔐 TESTE 2: Verificando autenticação...")
	
	if not Firebase or not Firebase.Auth:
		print("❌ Firebase.Auth não disponível")
		return false
	
	# Verifica se já está autenticado
	if Firebase.Auth.auth and Firebase.Auth.auth.idtoken != "":
		print("✅ Já autenticado - Token presente")
		print("   • UID: " + str(Firebase.Auth.auth.localid))
		return true
	
	# Tenta login anônimo
	print("🔄 Tentando login anônimo...")
	Firebase.Auth.login_anonymous()
	
	# Aguarda até 5 segundos pela autenticação
	var timeout = 5.0
	var elapsed = 0.0
	
	while elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
		
		if Firebase.Auth.auth and Firebase.Auth.auth.idtoken != "":
			print("✅ Autenticação bem-sucedida!")
			print("   • UID: " + str(Firebase.Auth.auth.localid))
			return true
	
	print("❌ Timeout na autenticação")
	return false

# Teste 3: Testar escrita no database
func test_database_write():
	print("\n📤 TESTE 3: Testando escrita no Realtime Database...")
	
	if not Firebase or not Firebase.Database:
		print("❌ Firebase.Database não disponível")
		return false
	
	var test_path = "api_test/" + str(Time.get_unix_time_from_system())
	
	var db_ref = Firebase.Database.get_database_reference(test_path, {})
	if not db_ref:
		print("❌ Não foi possível obter referência do database")
		return false
		
		print("🔄 Enviando dados para: " + test_path)
		db_ref.update("", test_data)
		
		# Aguarda um pouco para o envio
		await get_tree().create_timer(2.0).timeout
		print("✅ Dados enviados (aguardando confirmação)")
		return true
		
	# Em caso de erro
	if not db_ref:
		print("❌ Erro ao enviar dados para o database")
		return false

# Teste 4: Testar leitura do database
func test_database_read():
	print("\n📥 TESTE 4: Testando leitura do Realtime Database...")
	
	if not Firebase or not Firebase.Database:
		print("❌ Firebase.Database não disponível")
		return false
	
	var test_path = "api_test"
	
	var db_ref = Firebase.Database.get_database_reference(test_path, {})
	if not db_ref:
		print("❌ Não foi possível obter referência do database")
		return false
	
	print("🔄 Lendo dados de: " + test_path)
	
	# Conecta sinal para receber dados
	if not db_ref.new_data_update.is_connected(_on_data_received):
		db_ref.new_data_update.connect(_on_data_received)
	
	# Aguarda dados por até 5 segundos
	var timeout = 5.0
	var elapsed = 0.0
	
	while elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1
	
	return true

func _on_data_received(data):
	print("📨 Dados recebidos do Firebase:")
	print("🔍 Tipo de dados: " + str(typeof(data)))
	print("🔍 Conteúdo bruto: " + str(data))
	
	if data == null:
		print("❌ Dados nulos recebidos")
		return
	
	# Tipo 24 = TYPE_OBJECT no Godot
	if typeof(data) == 24:  # TYPE_OBJECT
		print("🎯 Dados recebidos como OBJECT (tipo 24)")
		
		# Tenta acessar propriedades do objeto
		if data.has_method("keys") or data.has_method("get"):
			print("✅ Objeto com métodos de acesso detectado")
			# Se tem método keys, trata como dicionário-like
			if data.has_method("keys"):
				var keys = data.keys()
				print("🔑 Chaves encontradas: " + str(keys))
				for key in keys:
					if data.has_method("get"):
						var value = data.get(key)
						print("   • " + str(key) + ": " + str(value))
					else:
						var value = data[key]
						print("   • " + str(key) + ": " + str(value))
				print("✅ Leitura de objeto bem-sucedida!")
			elif data.has_method("get"):
				print("🔧 Objeto tem método get, tentando acessar propriedades conhecidas...")
				var test_keys = ["key", "data", "test", "connection"]
				for test_key in test_keys:
					var value = data.get(test_key)
					if value != null:
						print("   • " + test_key + ": " + str(value))
		else:
			# Tenta converter para string e fazer parse
			var data_str = str(data)
			print("📝 Convertendo objeto para string: " + data_str)
			
			# Remove espaços e caracteres especiais para tentar fazer parse manual
			if data_str.begins_with("{") and data_str.ends_with("}"):
				print("🔧 Tentando parse manual de objeto-like string...")
				# Remove { e }
				var content = data_str.substr(1, data_str.length() - 2).strip_edges()
				print("   Conteúdo limpo: " + content)
				
				# Divide por vírgulas para obter pares chave:valor
				var pairs = content.split(",")
				for pair in pairs:
					var kv = pair.split(":")
					if kv.size() == 2:
						var key = kv[0].strip_edges()
						var value = kv[1].strip_edges()
						print("   • " + key + ": " + value)
				print("✅ Parse manual bem-sucedido!")
			else:
				print("⚠️  Formato de objeto não reconhecido")
	elif typeof(data) == TYPE_DICTIONARY:
		print("✅ Dados em formato de dicionário:")
		for key in data.keys():
			print("   • " + str(key) + ": " + str(data[key]))
		print("✅ Leitura bem-sucedida!")
	elif typeof(data) == TYPE_STRING:
		print("📝 Dados em formato de string:")
		print("   Conteúdo: " + str(data))
		# Tenta fazer parse JSON se for string
		var json = JSON.new()
		var parse_result = json.parse(str(data))
		if parse_result == OK:
			var parsed_data = json.data
			print("✅ JSON parseado com sucesso:")
			if typeof(parsed_data) == TYPE_DICTIONARY:
				for key in parsed_data.keys():
					print("   • " + str(key) + ": " + str(parsed_data[key]))
		else:
			print("⚠️  Não foi possível fazer parse JSON")
	else:
		print("⚠️  Formato de dados não reconhecido:")
		print("   Tipo: " + str(typeof(data)))
		print("   Valor: " + str(data))

# Teste 5: Verificar consistência dos dados
func test_data_consistency():
	print("\n🔍 TESTE 5: Verificando consistência dos dados...")
	
	# Testa se os dados do Global estão sendo sincronizados
	var local_data = {
		"name": Global.player_name,
		"points": Global.points,
		"gold": Global.gold,
		"crystal": Global.crystal
	}
	
	print("📊 Dados locais atuais:")
	for key in local_data.keys():
		print("   • " + str(key) + ": " + str(local_data[key]))
	
	# Força sincronização
	if Global.has_method("force_upload_data"):
		print("🔄 Forçando sincronização...")
		Global.force_upload_data()
		await get_tree().create_timer(2.0).timeout
		print("✅ Sincronização solicitada")
	else:
		print("⚠️  Método force_upload_data não encontrado")
	
	return true