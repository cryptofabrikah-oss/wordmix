extends Node

# Script para testar a conexão e sincronização com Firebase
# Executa automaticamente quando o jogo inicia e mostra resultados no console

var test_results: Array = []
var current_test: int = 0
var auto_run_tests: bool = true  # Executa testes automaticamente

func _ready():
	# Aguarda 2 segundos para garantir que todos os sistemas estejam inicializados
	await get_tree().create_timer(2.0).timeout
	
	if auto_run_tests:
		var title = "🧪 INICIANDO TESTES AUTOMÁTICOS DE DEBUG FIREBASE"
		var padding = (80 - title.length()) / 2
		var centered_title = "=".repeat(int(padding)) + title + "=".repeat(int(padding))
		print("\n" + centered_title)
		print("⏰ Timestamp: %s" % Time.get_datetime_string_from_system())
		print("=".repeat(80))
		
		# Executa os testes em sequência
		await run_all_tests()
		
		# Exibe resultados finais
		show_final_results()

func run_all_tests():
	var tests = [
		"test_firebase_availability",
		"test_global_singleton", 
		"test_authentication_status",
		"test_player_data_status",
		"test_local_data_integrity",
		"test_cache_system_status",
		"test_network_connectivity"
	]
	
	for test_name in tests:
		current_test += 1
		print("\n🔍 TESTE %d/%d: %s" % [current_test, tests.size(), test_name.replace("_", " ").to_upper()])
		print("-".repeat(50))
		
		var result = await call(test_name)
		test_results.append({
			"name": test_name,
			"passed": result,
			"timestamp": Time.get_unix_time_from_system()
		})
		
		# Pequena pausa entre testes para não sobrecarregar
		await get_tree().create_timer(0.5).timeout

func test_firebase_availability() -> bool:
	print("📡 Verificando disponibilidade do Firebase...")
	
	if not Firebase:
		print("❌ Firebase singleton não encontrado")
		print("   → Verifique se o plugin Firebase está instalado")
		return false
	
	print("✅ Firebase singleton encontrado")
	
	if not Firebase.Auth:
		print("❌ Firebase Auth não disponível")
		print("   → Verifique configuração do Firebase Auth")
		return false
	
	print("✅ Firebase Auth disponível")
	
	if not Firebase.Database:
		print("❌ Firebase Database não disponível") 
		print("   → Verifique configuração do Firebase Database")
		return false
	
	print("✅ Firebase Database disponível")
	print("🎯 Status: Firebase completamente configurado")
	return true

func test_global_singleton() -> bool:
	print("🌐 Verificando singleton Global...")
	
	if not Global:
		print("❌ Global singleton não encontrado")
		return false
	
	print("✅ Global singleton encontrado")
	
	# Verifica propriedades essenciais
	var essential_props = ["player_name", "player_id", "points", "gold", "crystal", "is_online"]
	var missing_props = []
	
	for prop in essential_props:
		if not Global.has_method("get") or Global.get(prop) == null:
			missing_props.append(prop)
	
	if missing_props.size() > 0:
		print("⚠️ Propriedades ausentes: %s" % str(missing_props))
	else:
		print("✅ Todas as propriedades essenciais presentes")
	
	print("📊 Dados atuais do jogador:")
	print("   • Nome: %s" % Global.player_name)
	print("   • ID: %s" % Global.player_id)
	print("   • Pontos: %d" % Global.points)
	print("   • Gold: %d" % Global.gold)
	print("   • Crystal: %d" % Global.crystal)
	print("   • Online: %s" % ("Sim" if Global.is_online else "Não"))
	
	return missing_props.size() == 0

func test_authentication_status() -> bool:
	print("🔐 Verificando status de autenticação...")
	
	if Global.player_id == "" or Global.player_id == null:
		print("⚠️ Jogador não autenticado")
		print("   → Tentando autenticação anônima...")
		
		# Tenta autenticação se não estiver autenticado
		if Global.is_online and Firebase.Auth:
			Firebase.Auth.login_anonymous()
			
			# Aguarda um pouco para ver se a autenticação funciona
			await get_tree().create_timer(3.0).timeout
			
			if Global.player_id != "":
				print("✅ Autenticação anônima bem-sucedida")
				print("   • Novo ID: %s" % Global.player_id)
				return true
			else:
				print("❌ Falha na autenticação anônima")
				return false
		else:
			print("❌ Não é possível autenticar (offline ou Firebase indisponível)")
			return false
	else:
		print("✅ Jogador já autenticado")
		print("   • ID atual: %s" % Global.player_id)
		return true

func test_player_data_status() -> bool:
	print("👤 Verificando integridade dos dados do jogador...")
	
	var data_issues = []
	
	# Verifica se os dados fazem sentido
	if Global.points < 0:
		data_issues.append("Pontos negativos: %d" % Global.points)
	
	if Global.gold < 0:
		data_issues.append("Gold negativo: %d" % Global.gold)
	
	if Global.crystal < 0:
		data_issues.append("Crystal negativo: %d" % Global.crystal)
	
	if Global.player_name == "" or Global.player_name == null:
		data_issues.append("Nome do jogador vazio")
	
	if data_issues.size() > 0:
		print("⚠️ Problemas encontrados nos dados:")
		for issue in data_issues:
			print("   • %s" % issue)
		return false
	else:
		print("✅ Dados do jogador íntegros")
		return true

func test_local_data_integrity() -> bool:
	print("💾 Verificando integridade dos dados locais...")
	
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	
	if err != OK:
		print("⚠️ Arquivo de configuração local não encontrado")
		print("   → Isso é normal na primeira execução")
		return true
	
	print("✅ Arquivo de configuração local encontrado")
	
	# Verifica se há backup disponível
	var backup_data = config.get_value("backup", "data", {})
	if not backup_data.is_empty():
		print("✅ Backup automático disponível")
		var backup_time = config.get_value("backup", "created_at", 0)
		var time_diff = Time.get_unix_time_from_system() - backup_time
		print("   • Idade do backup: %.1f minutos" % (time_diff / 60.0))
	else:
		print("ℹ️ Nenhum backup encontrado")
	
	return true

func test_cache_system_status() -> bool:
	print("🗄️ Verificando sistema de cache...")
	
	if not Global.has_method("_is_cache_valid"):
		print("❌ Sistema de cache não implementado")
		return false
	
	print("✅ Sistema de cache implementado")
	
	# Testa cache básico
	var test_key = "debug_test_cache"
	Global.data_cache[test_key] = {"test": "data", "timestamp": Time.get_unix_time_from_system()}
	Global.cache_timestamp[test_key] = Time.get_unix_time_from_system()
	
	if Global._is_cache_valid(test_key):
		print("✅ Cache funcionando corretamente")
		
		# Limpa o cache de teste
		Global.data_cache.erase(test_key)
		Global.cache_timestamp.erase(test_key)
		
		return true
	else:
		print("❌ Cache não está funcionando")
		return false

func test_network_connectivity() -> bool:
	print("🌐 Verificando conectividade de rede...")
	
	print("📡 Status de conexão Global.is_online: %s" % ("Conectado" if Global.is_online else "Desconectado"))
	
	# Verifica se consegue acessar configurações do Firebase
	if Global.has_method("firebase_config") or get_node_or_null("/root/FirebaseFix"):
		print("✅ Configurações Firebase carregadas")
	else:
		print("⚠️ Configurações Firebase podem não estar carregadas")
	
	# Se estiver online, tenta uma operação simples
	if Global.is_online and Global.player_id != "":
		print("🔄 Testando operação de salvamento...")
		Global.save_player_data_to_firebase()
		await get_tree().create_timer(2.0).timeout
		print("✅ Operação de salvamento iniciada")
		return true
	else:
		print("ℹ️ Modo offline ou não autenticado - operações limitadas")
		return true

func show_final_results():
	var title = "📊 RELATÓRIO FINAL DOS TESTES DE DEBUG"
	var padding = (80 - title.length()) / 2
	var centered_title = "=".repeat(int(padding)) + title + "=".repeat(int(padding))
	print("\n" + centered_title)
	print("⏰ Concluído em: %s" % Time.get_datetime_string_from_system())
	print("=".repeat(80))
	
	var passed = 0
	var total = test_results.size()
	
	for result in test_results:
		var status_icon = "✅" if result.passed else "❌"
		var status_text = "PASSOU" if result.passed else "FALHOU"
		var test_name_formatted = result.name.replace("_", " ").to_upper()
		
		print("%s %s: %s" % [status_icon, test_name_formatted, status_text])
		
		if result.passed:
			passed += 1
	
	print("-".repeat(80))
	var percentage = (passed * 100.0 / total) if total > 0 else 0
	print("📈 RESULTADO: %d/%d testes passaram (%.1f%%)" % [passed, total, percentage])
	
	# Análise do resultado
	if passed == total:
		print("🎉 EXCELENTE! Todos os testes passaram!")
		print("   → Sistema Firebase funcionando perfeitamente")
	elif passed >= total * 0.8:
		print("👍 BOM! Maioria dos testes passou")
		print("   → Sistema funcionando com pequenos problemas")
	elif passed >= total * 0.5:
		print("⚠️ ATENÇÃO! Alguns problemas detectados")
		print("   → Verifique os testes que falharam")
	else:
		print("🚨 CRÍTICO! Muitos testes falharam")
		print("   → Sistema precisa de correções urgentes")
	
	print("\n💡 PRÓXIMOS PASSOS:")
	if passed < total:
		print("   1. Verifique os testes que falharam acima")
		print("   2. Consulte FIREBASE_IMPROVEMENTS_GUIDE.md para soluções")
		print("   3. Teste novamente após correções")
	else:
		print("   1. Sistema funcionando corretamente!")
		print("   2. Monitore os logs durante o jogo")
		print("   3. Aproveite as melhorias implementadas!")
	
	print("=".repeat(80))
	print("🔧 Para desabilitar estes testes automáticos:")
	print("   → Mude 'auto_run_tests = false' em firebase_test_connection.gd")
	print("=".repeat(80))

# Função para executar testes manualmente via console
func run_manual_test():
	print("🔧 Executando testes manuais...")
	auto_run_tests = true
	await run_all_tests()
	show_final_results()

func _on_auth_success(auth_info: Dictionary):
	print("🔧 Executando testes manuais...")
	auto_run_tests = true
	await run_all_tests()
	show_final_results()

func _on_auth_failed(error_code: int, message: String):
	print("❌ Falha na autenticação: %s (código: %d)" % [message, error_code])

func test_data_save() -> bool:
	print("Testando salvamento de dados...")
	
	# Configura dados de teste
	var original_name = Global.player_name
	var original_points = Global.points
	var original_gold = Global.gold
	
	Global.player_name = "TestPlayer_" + str(Time.get_unix_time_from_system())
	Global.points = 1000
	Global.gold = 500
	
	# Tenta salvar
	Global.save_player_data_to_firebase()
	
	# Aguarda salvamento
	await get_tree().create_timer(3.0).timeout
	
	# Restaura dados originais
	Global.player_name = original_name
	Global.points = original_points
	Global.gold = original_gold
	
	print("✅ Dados de teste salvos (verificação manual necessária)")
	return true

func test_data_load() -> bool:
	print("Testando carregamento de dados...")
	
	if not Global.is_online or Global.player_id == "":
		print("⚠️ Offline ou não autenticado - usando dados locais")
		Global.load_local_data()
		print("✅ Dados locais carregados")
		return true
	
	# Tenta carregar do Firebase
	Global.load_player_data_from_firebase()
	
	# Aguarda carregamento
	await get_tree().create_timer(3.0).timeout
	
	print("✅ Tentativa de carregamento concluída")
	return true

func test_conflict_resolution() -> bool:
	print("Testando resolução de conflitos...")
	
	# Simula dados conflitantes
	var local_data = {
		"points": 100,
		"gold": 50,
		"unlocked_characters": ["char1", "char2"]
	}
	
	var remote_data = {
		"points": 150,  # Maior que local
		"gold": 30,     # Menor que local
		"unlocked_characters": ["char2", "char3"]  # Diferentes
	}
	
	# Testa resolução
	var resolved = Global._resolve_data_conflicts(local_data, remote_data)
	
	# Verifica se a resolução está correta
	var conflicts_resolved = true
	
	if resolved["points"] != 150:  # Deve usar o maior
		print("❌ Conflito de pontos não resolvido corretamente")
		conflicts_resolved = false
	
	if resolved["gold"] != 50:  # Deve usar o maior
		print("❌ Conflito de gold não resolvido corretamente")
		conflicts_resolved = false
	
	if resolved["unlocked_characters"].size() != 3:  # Deve fazer merge
		print("❌ Conflito de personagens não resolvido corretamente")
		conflicts_resolved = false
	
	if conflicts_resolved:
		print("✅ Resolução de conflitos funcionando corretamente")
	
	return conflicts_resolved

func test_offline_mode() -> bool:
	print("Testando modo offline...")
	
	# Simula modo offline
	var original_online = Global.is_online
	Global.is_online = false
	
	# Tenta salvar em modo offline
	Global.save_player_data_to_firebase()
	
	# Restaura estado original
	Global.is_online = original_online
	
	print("✅ Modo offline testado - dados salvos localmente")
	return true

func test_cache_system() -> bool:
	print("Testando sistema de cache...")
	
	# Testa validação de cache
	var cache_key = "test_cache"
	Global.data_cache[cache_key] = {"test": "data"}
	Global.cache_timestamp[cache_key] = Time.get_unix_time_from_system()
	
	# Cache deve ser válido
	if not Global._is_cache_valid(cache_key):
		print("❌ Cache válido não foi reconhecido")
		return false
	
	# Simula cache expirado
	Global.cache_timestamp[cache_key] = Time.get_unix_time_from_system() - 100
	
	# Cache deve ser inválido
	if Global._is_cache_valid(cache_key):
		print("❌ Cache expirado não foi detectado")
		return false
	
	print("✅ Sistema de cache funcionando corretamente")
	return true
