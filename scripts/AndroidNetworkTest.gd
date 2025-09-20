extends Node

## Script de Teste de Conectividade para Android APK
## Use este script para diagnosticar problemas de rede específicos do Android

signal network_test_completed(success: bool, details: String)

var test_results = []

func _ready():
	print("🔧 AndroidNetworkTest inicializado")

# Teste completo de conectividade
func run_full_network_test():
	print("🚀 Iniciando teste completo de rede...")
	test_results.clear()
	
	# Teste 1: Conectividade básica
	await test_basic_connectivity()
	
	# Teste 2: Resolução DNS
	await test_dns_resolution()
	
	# Teste 3: Conectividade Firebase
	await test_firebase_connectivity()
	
	# Teste 4: Autenticação Firebase
	await test_firebase_auth()
	
	# Gerar relatório
	generate_test_report()

# Teste 1: Conectividade básica com Google
func test_basic_connectivity():
	print("🌐 Testando conectividade básica...")
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(_on_basic_connectivity_completed)
	var error = http.request("https://www.google.com")
	
	if error != OK:
		test_results.append({
			"test": "Conectividade Básica",
			"status": "FALHOU",
			"details": "Erro ao iniciar requisição: " + str(error)
		})
		http.queue_free()
		return
	
	# Aguardar resposta (timeout de 10 segundos)
	await get_tree().create_timer(10.0).timeout
	http.queue_free()

func _on_basic_connectivity_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200:
		test_results.append({
			"test": "Conectividade Básica",
			"status": "SUCESSO",
			"details": "Conexão com Google estabelecida (HTTP " + str(response_code) + ")"
		})
	else:
		test_results.append({
			"test": "Conectividade Básica",
			"status": "FALHOU",
			"details": "Código de resposta: " + str(response_code) + ", Resultado: " + str(result)
		})

# Teste 2: Resolução DNS específica do Firebase
func test_dns_resolution():
	print("🔍 Testando resolução DNS do Firebase...")
	
	var http = HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(_on_dns_test_completed)
	var error = http.request("https://cinco-words-default-rtdb.firebaseio.com/.json")
	
	if error != OK:
		test_results.append({
			"test": "Resolução DNS Firebase",
			"status": "FALHOU",
			"details": "Erro ao resolver DNS: " + str(error)
		})
		http.queue_free()
		return
	
	await get_tree().create_timer(10.0).timeout
	http.queue_free()

func _on_dns_test_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 401:  # Esperado sem autenticação
		test_results.append({
			"test": "Resolução DNS Firebase",
			"status": "SUCESSO",
			"details": "DNS resolvido corretamente (HTTP 401 - sem auth, como esperado)"
		})
	elif response_code == 200:
		test_results.append({
			"test": "Resolução DNS Firebase",
			"status": "SUCESSO",
			"details": "DNS e conexão Firebase OK (HTTP 200)"
		})
	else:
		test_results.append({
			"test": "Resolução DNS Firebase",
			"status": "FALHOU",
			"details": "Código inesperado: " + str(response_code) + ", Resultado: " + str(result)
		})

# Teste 3: Conectividade Firebase com autenticação
func test_firebase_connectivity():
	print("🔥 Testando conectividade Firebase autenticada...")
	
	if not Firebase.Auth.auth or Firebase.Auth.auth.idtoken == "":
		test_results.append({
			"test": "Conectividade Firebase",
			"status": "FALHOU",
			"details": "Token de autenticação não disponível"
		})
		return
	
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = PackedStringArray([
		"Authorization: Bearer " + Firebase.Auth.auth.idtoken,
		"Content-Type: application/json"
	])
	
	http.request_completed.connect(_on_firebase_connectivity_completed)
	var error = http.request("https://cinco-words-default-rtdb.firebaseio.com/test.json", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		test_results.append({
			"test": "Conectividade Firebase",
			"status": "FALHOU",
			"details": "Erro na requisição autenticada: " + str(error)
		})
		http.queue_free()
		return
	
	await get_tree().create_timer(10.0).timeout
	http.queue_free()

func _on_firebase_connectivity_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code == 200 or response_code == 204:
		test_results.append({
			"test": "Conectividade Firebase",
			"status": "SUCESSO",
			"details": "Requisição autenticada bem-sucedida (HTTP " + str(response_code) + ")"
		})
	else:
		test_results.append({
			"test": "Conectividade Firebase",
			"status": "FALHOU",
			"details": "Falha na requisição autenticada: HTTP " + str(response_code) + ", Resultado: " + str(result)
		})

# Teste 4: Autenticação Firebase
func test_firebase_auth():
	print("🔐 Testando autenticação Firebase...")
	
	if Firebase.Auth.auth and Firebase.Auth.auth.idtoken != "":
		var token_parts = Firebase.Auth.auth.idtoken.split(".")
		if token_parts.size() == 3:
			test_results.append({
				"test": "Autenticação Firebase",
				"status": "SUCESSO",
				"details": "Token JWT válido presente (3 partes), UID: " + str(Firebase.Auth.auth.localid)
			})
		else:
			test_results.append({
				"test": "Autenticação Firebase",
				"status": "FALHOU",
				"details": "Token malformado: " + str(token_parts.size()) + " partes"
			})
	else:
		test_results.append({
			"test": "Autenticação Firebase",
			"status": "FALHOU",
			"details": "Nenhum token de autenticação disponível"
		})

# Gerar relatório final
func generate_test_report():
	print("\n" + "="*50)
	print("📊 RELATÓRIO DE TESTE DE REDE ANDROID")
	print("="*50)
	
	var success_count = 0
	var total_tests = test_results.size()
	
	for result in test_results:
		var status_icon = "✅" if result.status == "SUCESSO" else "❌"
		print(status_icon + " " + result.test + ": " + result.status)
		print("   └─ " + result.details)
		
		if result.status == "SUCESSO":
			success_count += 1
	
	print("\n📈 RESUMO:")
	print("   Testes bem-sucedidos: " + str(success_count) + "/" + str(total_tests))
	
	if success_count == total_tests:
		print("🎉 TODOS OS TESTES PASSARAM - Rede funcionando corretamente!")
	elif success_count > 0:
		print("⚠️  ALGUNS TESTES FALHARAM - Verificar configurações específicas")
	else:
		print("🚨 TODOS OS TESTES FALHARAM - Problema grave de conectividade")
	
	print("="*50 + "\n")
	
	# Emitir sinal de conclusão
	network_test_completed.emit(success_count == total_tests, "Testes concluídos: " + str(success_count) + "/" + str(total_tests))

# Função para chamar de outros scripts
func quick_connectivity_check() -> bool:
	print("⚡ Teste rápido de conectividade...")
	
	# Verificar se há conexão com a internet
	var http = HTTPRequest.new()
	add_child(http)
	
	var connected = false
	http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		connected = (response_code == 200)
		http.queue_free()
	)
	
	http.request("https://www.google.com")
	
	# Aguardar resposta por 5 segundos
	var timer = get_tree().create_timer(5.0)
	await timer.timeout
	
	if http:
		http.queue_free()
	
	print("🌐 Conectividade rápida: " + ("OK" if connected else "FALHOU"))
	return connected

# Função para uso em produção - log de diagnóstico
func log_network_info():
	print("📱 INFORMAÇÕES DE REDE (Android):")
	print("   • OS: " + OS.get_name())
	print("   • Plataforma: " + str(OS.get_model_name()))
	print("   • Godot: " + Engine.get_version_info().string)
	
	if Firebase.Auth.auth:
		print("   • Firebase Auth: Ativo")
		print("   • Token presente: " + ("Sim" if Firebase.Auth.auth.idtoken != "" else "Não"))
		print("   • UID: " + str(Firebase.Auth.auth.localid))
	else:
		print("   • Firebase Auth: Inativo")