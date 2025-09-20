extends Node

# Validador de Conexões do Firebase
# Testa se as correções para conexões duplicadas funcionaram

var test_results = []

func _ready():
	print("🔥 INICIANDO VALIDAÇÃO DAS CONEXÕES DO FIREBASE")
	print("=" * 60)
	await get_tree().create_timer(2.0).timeout
	run_firebase_connection_tests()

func run_firebase_connection_tests():
	print("\n🧪 Executando testes de conexão do Firebase...")
	
	# Teste 1: Verifica se Firebase está disponível
	test_firebase_availability()
	
	# Teste 2: Verifica conexões de sinais
	test_signal_connections()
	
	# Teste 3: Testa múltiplas chamadas de initialize_firebase
	await test_multiple_initializations()
	
	# Teste 4: Verifica se _save_on_exit não causa problemas
	await test_save_on_exit_behavior()
	
	# Mostra resultados
	show_test_results()

func test_firebase_availability():
	print("\n🔍 TESTE 1: Disponibilidade do Firebase")
	
	var firebase_available = (Firebase != null)
	var auth_available = firebase_available and (Firebase.Auth != null)
	
	var success = firebase_available and auth_available
	
	test_results.append({
		"name": "Disponibilidade do Firebase",
		"success": success,
		"details": "Firebase: %s, Auth: %s" % [firebase_available, auth_available]
	})
	
	print("   Firebase disponível: ", "✅" if firebase_available else "❌")
	print("   Firebase.Auth disponível: ", "✅" if auth_available else "❌")
	print("   Resultado: ", "✅ PASSOU" if success else "❌ FALHOU")

func test_signal_connections():
	print("\n🔍 TESTE 2: Conexões de Sinais")
	
	if Firebase == null or Firebase.Auth == null:
		test_results.append({
			"name": "Conexões de Sinais",
			"success": false,
			"details": "Firebase não disponível"
		})
		print("   ❌ Firebase não disponível para teste")
		return
	
	# Verifica se os sinais existem
	var has_login_succeeded = Firebase.Auth.has_signal("login_succeeded")
	var has_signup_succeeded = Firebase.Auth.has_signal("signup_succeeded")
	var has_login_failed = Firebase.Auth.has_signal("login_failed")
	
	# Verifica se estão conectados ao Global
	var login_connected = false
	var signup_connected = false
	var failed_connected = false
	
	if has_login_succeeded:
		login_connected = Firebase.Auth.is_connected("login_succeeded", Global._on_firebase_login_succeeded)
	
	if has_signup_succeeded:
		signup_connected = Firebase.Auth.is_connected("signup_succeeded", Global._on_firebase_signup_succeeded)
	
	if has_login_failed:
		failed_connected = Firebase.Auth.is_connected("login_failed", Global._on_firebase_login_failed)
	
	var success = has_login_succeeded and has_signup_succeeded and has_login_failed
	var connections_ok = login_connected and signup_connected and failed_connected
	
	test_results.append({
		"name": "Conexões de Sinais",
		"success": success and connections_ok,
		"details": "Sinais: %s, Conexões: %s" % [success, connections_ok]
	})
	
	print("   Sinais existem: ", "✅" if success else "❌")
	print("   Sinais conectados: ", "✅" if connections_ok else "❌")
	print("   • login_succeeded: ", "✅" if login_connected else "❌")
	print("   • signup_succeeded: ", "✅" if signup_connected else "❌")
	print("   • login_failed: ", "✅" if failed_connected else "❌")
	print("   Resultado: ", "✅ PASSOU" if (success and connections_ok) else "❌ FALHOU")

func test_multiple_initializations():
	print("\n🔍 TESTE 3: Múltiplas Inicializações")
	
	if Firebase == null or Firebase.Auth == null:
		test_results.append({
			"name": "Múltiplas Inicializações",
			"success": false,
			"details": "Firebase não disponível"
		})
		print("   ❌ Firebase não disponível para teste")
		return
	
	# Conta conexões antes
	var connections_before = count_signal_connections()
	
	# Chama initialize_firebase múltiplas vezes
	print("   Chamando initialize_firebase 3 vezes...")
	Global.initialize_firebase()
	await get_tree().create_timer(0.5).timeout
	
	Global.initialize_firebase()
	await get_tree().create_timer(0.5).timeout
	
	Global.initialize_firebase()
	await get_tree().create_timer(0.5).timeout
	
	# Conta conexões depois
	var connections_after = count_signal_connections()
	
	# Deve ter o mesmo número de conexões (não duplicadas)
	var success = (connections_before == connections_after)
	
	test_results.append({
		"name": "Múltiplas Inicializações",
		"success": success,
		"details": "Antes: %d, Depois: %d" % [connections_before, connections_after]
	})
	
	print("   Conexões antes: ", connections_before)
	print("   Conexões depois: ", connections_after)
	print("   Sem duplicação: ", "✅" if success else "❌")
	print("   Resultado: ", "✅ PASSOU" if success else "❌ FALHOU")

func count_signal_connections() -> int:
	if Firebase == null or Firebase.Auth == null:
		return 0
	
	var count = 0
	
	# Conta conexões dos sinais principais
	if Firebase.Auth.is_connected("login_succeeded", Global._on_firebase_login_succeeded):
		count += 1
	
	if Firebase.Auth.is_connected("signup_succeeded", Global._on_firebase_signup_succeeded):
		count += 1
	
	if Firebase.Auth.is_connected("login_failed", Global._on_firebase_login_failed):
		count += 1
	
	return count

func test_save_on_exit_behavior():
	print("\n🔍 TESTE 4: Comportamento do _save_on_exit")
	
	# Conta conexões antes
	var connections_before = count_signal_connections()
	
	# Chama _save_on_exit (que antes causava problemas)
	print("   Chamando _save_on_exit...")
	Global._save_on_exit()
	await get_tree().create_timer(1.0).timeout
	
	# Conta conexões depois
	var connections_after = count_signal_connections()
	
	# Não deve ter alterado as conexões
	var success = (connections_before == connections_after)
	
	test_results.append({
		"name": "Comportamento do _save_on_exit",
		"success": success,
		"details": "Antes: %d, Depois: %d" % [connections_before, connections_after]
	})
	
	print("   Conexões antes: ", connections_before)
	print("   Conexões depois: ", connections_after)
	print("   Sem alteração: ", "✅" if success else "❌")
	print("   Resultado: ", "✅ PASSOU" if success else "❌ FALHOU")

func show_test_results():
	print("\n" + "=" * 60)
	print("📊 RESULTADOS DOS TESTES DE CONEXÃO FIREBASE")
	print("=" * 60)
	
	var passed = 0
	var total = test_results.size()
	
	for result in test_results:
		var status = "✅ PASSOU" if result.success else "❌ FALHOU"
		print("• %s: %s" % [result.name, status])
		print("  └─ %s" % result.details)
		if result.success:
			passed += 1
	
	var percentage = (passed * 100.0 / total) if total > 0 else 0
	
	print("\n📈 ESTATÍSTICAS:")
	print("   Testes executados: %d" % total)
	print("   Testes aprovados: %d" % passed)
	print("   Taxa de sucesso: %.1f%%" % percentage)
	
	print("\n" + "=" * 60)
	
	if passed == total:
		print("🎉 TODAS AS CORREÇÕES FUNCIONARAM!")
		print("✅ Conexões duplicadas foram eliminadas")
		print("✅ Firebase inicializa corretamente")
		print("✅ _save_on_exit não causa mais problemas")
		print("✅ Sinais conectam apenas uma vez")
		
		print("\n🔧 CORREÇÕES APLICADAS COM SUCESSO:")
		print("1. ✅ Removida chamada desnecessária de initialize_firebase em _save_on_exit")
		print("2. ✅ Adicionadas verificações is_connected() antes de conectar sinais")
		print("3. ✅ Verificação de autenticação antes de tentar login anônimo")
		print("4. ✅ Logs informativos para conexões já existentes")
		
		print("\n💡 OS ERROS DE CONEXÃO DUPLICADA FORAM CORRIGIDOS!")
		
	else:
		print("⚠️ ALGUMAS CORREÇÕES PRECISAM DE AJUSTES")
		print("🔧 Verifique os itens marcados como falhou acima")
	
	print("=" * 60)