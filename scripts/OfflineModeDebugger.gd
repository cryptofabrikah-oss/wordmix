extends Node

# ===== DEBUGGER DE MODO OFFLINE =====
# Script para diagnosticar problemas de modo offline no Firebase

signal debug_completed(results: Dictionary)

var debug_results: Dictionary = {}

func _ready():
	print("🔍 OfflineModeDebugger inicializado")

# Executa diagnóstico completo do modo offline
func run_complete_diagnosis() -> Dictionary:
	print("🚀 Iniciando diagnóstico completo do modo offline...")
	
	debug_results.clear()
	debug_results["timestamp"] = Time.get_unix_time_from_system()
	debug_results["tests"] = {}
	
	# Teste 1: Verificar estado do Firebase
	await _test_firebase_state()
	
	# Teste 2: Verificar configuração
	await _test_firebase_config()
	
	# Teste 3: Verificar conectividade
	await _test_network_connectivity()
	
	# Teste 4: Verificar autenticação
	await _test_authentication_flow()
	
	# Teste 5: Verificar operações de escrita
	await _test_write_operations()
	
	# Teste 6: Verificar sinais e callbacks
	await _test_signals_and_callbacks()
	
	# Gera relatório final
	_generate_final_report()
	
	emit_signal("debug_completed", debug_results)
	return debug_results

# Teste 1: Estado do Firebase
func _test_firebase_state():
	print("📋 Teste 1: Verificando estado do Firebase...")
	
	var test_result = {
		"firebase_available": Firebase != null,
		"auth_available": Firebase != null and Firebase.Auth != null,
		"database_available": Firebase != null and Firebase.Database != null,
		"global_online_status": Global.is_online if Global else false,
		"global_firebase_ref": Global.firebase_reference != null if Global else false
	}
	
	debug_results.tests["firebase_state"] = test_result
	
	print("   • Firebase disponível: ", test_result.firebase_available)
	print("   • Auth disponível: ", test_result.auth_available)
	print("   • Database disponível: ", test_result.database_available)
	print("   • Global online: ", test_result.global_online_status)
	print("   • Firebase ref: ", test_result.global_firebase_ref)

# Teste 2: Configuração do Firebase
func _test_firebase_config():
	print("📋 Teste 2: Verificando configuração do Firebase...")
	
	var config_valid = false
	var config_details = {}
	
	if Global and Global.firebase_config:
		var config = Global.firebase_config.get_firebase_config()
		config_valid = Global.firebase_config.is_config_valid()
		
		config_details = {
			"api_key_present": config.has("apiKey") and not config.apiKey.is_empty(),
			"project_id_present": config.has("projectId") and not config.projectId.is_empty(),
			"database_url_present": config.has("databaseURL") and not config.databaseURL.is_empty(),
			"api_key_format": config.apiKey.begins_with("AIza") if config.has("apiKey") else false
		}
	
	var test_result = {
		"config_valid": config_valid,
		"config_details": config_details
	}
	
	debug_results.tests["firebase_config"] = test_result
	
	print("   • Configuração válida: ", config_valid)
	print("   • API Key presente: ", config_details.get("api_key_present", false))
	print("   • Project ID presente: ", config_details.get("project_id_present", false))
	print("   • Database URL presente: ", config_details.get("database_url_present", false))

# Teste 3: Conectividade de rede
func _test_network_connectivity():
	print("📋 Teste 3: Verificando conectividade de rede...")
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var connectivity_result = {
		"google_reachable": false,
		"firebase_reachable": false,
		"response_time": 0.0
	}
	
	var start_time = Time.get_unix_time_from_system()
	
	# Teste de conectividade com Google
	http_request.request_completed.connect(_on_google_connectivity_test)
	http_request.request("https://www.google.com")
	
	# Aguarda resposta por até 10 segundos
	var timeout = 10.0
	var elapsed = 0.0
	while elapsed < timeout:
		await get_tree().process_frame
		elapsed = Time.get_unix_time_from_system() - start_time
		if connectivity_result.google_reachable:
			break
	
	connectivity_result.response_time = elapsed
	
	# Teste específico do Firebase
	if connectivity_result.google_reachable:
		http_request.request_completed.disconnect(_on_google_connectivity_test)
		http_request.request_completed.connect(_on_firebase_connectivity_test)
		http_request.request("https://cinco-words-default-rtdb.firebaseio.com/.json")
		
		# Aguarda resposta do Firebase
		elapsed = 0.0
		start_time = Time.get_unix_time_from_system()
		while elapsed < timeout:
			await get_tree().process_frame
			elapsed = Time.get_unix_time_from_system() - start_time
			if connectivity_result.firebase_reachable:
				break
	
	debug_results.tests["network_connectivity"] = connectivity_result
	
	print("   • Google alcançável: ", connectivity_result.google_reachable)
	print("   • Firebase alcançável: ", connectivity_result.firebase_reachable)
	print("   • Tempo de resposta: ", connectivity_result.response_time, "s")
	
	http_request.queue_free()

func _on_google_connectivity_test(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	debug_results.tests["network_connectivity"]["google_reachable"] = (response_code == 200)

func _on_firebase_connectivity_test(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	debug_results.tests["network_connectivity"]["firebase_reachable"] = (response_code == 200)

# Teste 4: Fluxo de autenticação
func _test_authentication_flow():
	print("📋 Teste 4: Verificando fluxo de autenticação...")
	
	var auth_result = {
		"auth_uid_present": false,
		"player_id_present": false,
		"auth_signals_connected": false,
		"login_attempt_successful": false
	}
	
	if Global:
		auth_result.auth_uid_present = not Global.firebase_auth_uid.is_empty()
		auth_result.player_id_present = not Global.player_id.is_empty()
	
	# Verifica se sinais estão conectados
	if Firebase and Firebase.Auth:
		auth_result.auth_signals_connected = (
			Firebase.Auth.is_connected("login_succeeded", Global._on_firebase_login_succeeded) and
			Firebase.Auth.is_connected("login_failed", Global._on_firebase_login_failed)
		)
	
	debug_results.tests["authentication_flow"] = auth_result
	
	print("   • Auth UID presente: ", auth_result.auth_uid_present)
	print("   • Player ID presente: ", auth_result.player_id_present)
	print("   • Sinais conectados: ", auth_result.auth_signals_connected)

# Teste 5: Operações de escrita
func _test_write_operations():
	print("📋 Teste 5: Verificando operações de escrita...")
	
	var write_result = {
		"can_create_reference": false,
		"can_attempt_write": false,
		"write_successful": false,
		"error_message": ""
	}
	
	if Global and Global.is_online and Global.firebase_reference:
		write_result.can_create_reference = true
		
		# Tenta criar uma referência de teste
		var test_ref = Global.firebase_reference.child("debug_test").child("connectivity")
		if test_ref:
			write_result.can_attempt_write = true
			
			# Tenta escrever dados de teste
			var test_data = {
				"test": true,
				"timestamp": Time.get_unix_time_from_system(),
				"source": "OfflineModeDebugger"
			}
			
			# Conecta sinais para capturar resultado
			if test_ref.has_signal("push_successful"):
				test_ref.connect("push_successful", func(): write_result.write_successful = true)
			if test_ref.has_signal("push_failed"):
				test_ref.connect("push_failed", func(): write_result.error_message = "Push failed")
			
			# Executa operação de escrita
			test_ref.update("", test_data)
			
			# Aguarda resultado por 5 segundos
			var timeout = 5.0
			var elapsed = 0.0
			while elapsed < timeout and not write_result.write_successful and write_result.error_message.is_empty():
				await get_tree().process_frame
				elapsed += get_process_delta_time()
	
	debug_results.tests["write_operations"] = write_result
	
	print("   • Pode criar referência: ", write_result.can_create_reference)
	print("   • Pode tentar escrita: ", write_result.can_attempt_write)
	print("   • Escrita bem-sucedida: ", write_result.write_successful)
	if not write_result.error_message.is_empty():
		print("   • Erro: ", write_result.error_message)

# Teste 6: Sinais e callbacks
func _test_signals_and_callbacks():
	print("📋 Teste 6: Verificando sinais e callbacks...")
	
	var signals_result = {
		"global_signals_connected": false,
		"firebase_auth_signals": [],
		"firebase_database_signals": []
	}
	
	if Global:
		# Verifica sinais do Global
		var signal_list = Global.get_signal_list()
		for signal_info in signal_list:
			if signal_info.name == "player_data_updated":
				signals_result.global_signals_connected = true
				break
	
	# Verifica sinais do Firebase Auth
	if Firebase and Firebase.Auth:
		var auth_signals = Firebase.Auth.get_signal_list()
		for signal_info in auth_signals:
			signals_result.firebase_auth_signals.append(signal_info.name)
	
	# Verifica sinais do Firebase Database
	if Firebase and Firebase.Database:
		var db_signals = Firebase.Database.get_signal_list()
		for signal_info in db_signals:
			signals_result.firebase_database_signals.append(signal_info.name)
	
	debug_results.tests["signals_and_callbacks"] = signals_result
	
	print("   • Sinais Global conectados: ", signals_result.global_signals_connected)
	print("   • Sinais Auth disponíveis: ", signals_result.firebase_auth_signals.size())
	print("   • Sinais Database disponíveis: ", signals_result.firebase_database_signals.size())

# Gera relatório final
func _generate_final_report():
	print("📊 Gerando relatório final...")
	
	var summary = {
		"overall_status": "unknown",
		"critical_issues": [],
		"warnings": [],
		"recommendations": []
	}
	
	# Analisa resultados dos testes
	var firebase_state = debug_results.tests.get("firebase_state", {})
	var config_test = debug_results.tests.get("firebase_config", {})
	var connectivity = debug_results.tests.get("network_connectivity", {})
	var auth_flow = debug_results.tests.get("authentication_flow", {})
	var write_ops = debug_results.tests.get("write_operations", {})
	
	# Determina status geral
	if not firebase_state.get("firebase_available", false):
		summary.overall_status = "critical"
		summary.critical_issues.append("Firebase não disponível")
	elif not config_test.get("config_valid", false):
		summary.overall_status = "critical"
		summary.critical_issues.append("Configuração Firebase inválida")
	elif not connectivity.get("firebase_reachable", false):
		summary.overall_status = "network_issue"
		summary.critical_issues.append("Firebase não alcançável pela rede")
	elif not auth_flow.get("player_id_present", false):
		summary.overall_status = "auth_issue"
		summary.critical_issues.append("Player ID não definido")
	elif not write_ops.get("write_successful", false):
		summary.overall_status = "write_issue"
		summary.critical_issues.append("Falha nas operações de escrita")
	else:
		summary.overall_status = "healthy"
	
	# Adiciona recomendações baseadas nos problemas encontrados
	if "Firebase não disponível" in summary.critical_issues:
		summary.recommendations.append("Verificar se o plugin godot-firebase está instalado e ativado")
	
	if "Configuração Firebase inválida" in summary.critical_issues:
		summary.recommendations.append("Revisar firebase_config.gd e verificar credenciais no Firebase Console")
	
	if "Firebase não alcançável pela rede" in summary.critical_issues:
		summary.recommendations.append("Verificar conexão de internet e configurações de firewall")
	
	if "Player ID não definido" in summary.critical_issues:
		summary.recommendations.append("Verificar inicialização do sistema de ID persistente")
	
	if "Falha nas operações de escrita" in summary.critical_issues:
		summary.recommendations.append("Verificar permissões do Firebase Database e regras de segurança")
	
	debug_results["summary"] = summary
	
	print("✅ Diagnóstico completo finalizado")
	print("   • Status geral: ", summary.overall_status)
	print("   • Problemas críticos: ", summary.critical_issues.size())
	print("   • Recomendações: ", summary.recommendations.size())

# Salva relatório em arquivo
func save_debug_report(file_path: String = "user://offline_debug_report.json"):
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(debug_results, "\t"))
		file.close()
		print("📄 Relatório salvo em: ", file_path)
	else:
		print("❌ Erro ao salvar relatório")

# Função de conveniência para executar diagnóstico rápido
func quick_diagnosis() -> String:
	var quick_result = ""
	
	if not Firebase:
		quick_result = "CRÍTICO: Firebase não disponível"
	elif not Global.is_online:
		quick_result = "OFFLINE: Sistema em modo offline"
	elif Global.player_id.is_empty():
		quick_result = "AUTH: Player ID não definido"
	elif not Global.firebase_reference:
		quick_result = "REF: Referência Firebase não criada"
	else:
		quick_result = "OK: Sistema aparenta estar funcionando"
	
	print("🔍 Diagnóstico rápido: ", quick_result)
	return quick_result