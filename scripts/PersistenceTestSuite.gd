extends Node

# Suite de testes para verificar persistência de dados
# Simula cenários de fechamento e reabertura do jogo

var test_results = []
var original_data = {}

func _ready():
	print("🧪 Iniciando Suite de Testes de Persistência...")
	await get_tree().create_timer(1.0).timeout
	run_persistence_tests()

func run_persistence_tests():
	print("\n=== INICIANDO TESTES DE PERSISTÊNCIA ===")
	
	# Salva dados originais
	save_original_data()
	
	# Executa testes
	await test_local_save_load()
	await test_firebase_sync()
	await test_session_simulation()
	await test_notification_handling()
	
	# Mostra resultados
	show_test_results()

func save_original_data():
	original_data = {
		"player_name": Global.player_name,
		"player_id": Global.player_id,
		"points": Global.points,
		"gold": Global.gold,
		"crystal": Global.crystal,
		"level": Global.level,
		"selected_avatar": Global.selected_avatar
	}
	print("📊 Dados originais salvos: ", original_data)

func test_local_save_load() -> void:
	print("\n🔍 TESTE 1: Salvamento e Carregamento Local")
	
	# Modifica dados temporariamente
	var test_points = Global.points + 100
	var test_gold = Global.gold + 50
	var test_crystal = Global.crystal + 25
	
	Global.points = test_points
	Global.gold = test_gold
	Global.crystal = test_crystal
	
	# Força salvamento local
	Global.save_local_data()
	print("   ✅ Dados modificados e salvos localmente")
	
	# Simula "reinício" carregando dados
	Global.load_local_data()
	
	# Verifica se os dados foram mantidos
	var success = (Global.points == test_points and 
	               Global.gold == test_gold and 
	               Global.crystal == test_crystal)
	
	test_results.append({
		"test": "Salvamento/Carregamento Local",
		"success": success,
		"details": "Points: %d, Gold: %d, Crystal: %d" % [Global.points, Global.gold, Global.crystal]
	})
	
	print("   ", "✅ PASSOU" if success else "❌ FALHOU")

func test_firebase_sync() -> void:
	print("\n🔍 TESTE 2: Sincronização Firebase")
	
	if not Global.is_online:
		test_results.append({
			"test": "Sincronização Firebase",
			"success": false,
			"details": "Firebase offline - teste pulado"
		})
		print("   ⚠️ PULADO - Firebase offline")
		return
	
	# Testa salvamento no Firebase
	var initial_points = Global.points
	Global.points += 200
	
	# Força sincronização
	var sync_success = Global.force_upload_data()
	
	await get_tree().create_timer(2.0).timeout  # Aguarda sincronização
	
	test_results.append({
		"test": "Sincronização Firebase",
		"success": sync_success,
		"details": "Upload forçado: %s" % ("sucesso" if sync_success else "falhou")
	})
	
	print("   ", "✅ PASSOU" if sync_success else "❌ FALHOU")

func test_session_simulation() -> void:
	print("\n🔍 TESTE 3: Simulação de Sessão")
	
	# Simula dados de uma sessão de jogo
	var session_data = {
		"points_gained": 150,
		"gold_gained": 75,
		"crystal_gained": 10
	}
	
	var initial_points = Global.points
	var initial_gold = Global.gold
	var initial_crystal = Global.crystal
	
	# Simula progresso durante o jogo
	Global.add_points(session_data.points_gained)
	Global.add_gold(session_data.gold_gained)
	Global.add_crystal(session_data.crystal_gained)
	
	print("   📈 Progresso simulado - Points: +%d, Gold: +%d, Crystal: +%d" % 
	      [session_data.points_gained, session_data.gold_gained, session_data.crystal_gained])
	
	# Força salvamento (simula fechamento do jogo)
	Global.save_local_data()
	if Global.is_online:
		Global.force_upload_data()
	
	await get_tree().create_timer(1.0).timeout
	
	# Verifica se os dados foram mantidos
	var points_correct = Global.points == (initial_points + session_data.points_gained)
	var gold_correct = Global.gold == (initial_gold + session_data.gold_gained)
	var crystal_correct = Global.crystal == (initial_crystal + session_data.crystal_gained)
	
	var success = points_correct and gold_correct and crystal_correct
	
	test_results.append({
		"test": "Simulação de Sessão",
		"success": success,
		"details": "Points: %s, Gold: %s, Crystal: %s" % [
			"✅" if points_correct else "❌",
			"✅" if gold_correct else "❌", 
			"✅" if crystal_correct else "❌"
		]
	})
	
	print("   ", "✅ PASSOU" if success else "❌ FALHOU")

func test_notification_handling() -> void:
	print("\n🔍 TESTE 4: Tratamento de Notificações do Sistema")
	
	# Verifica se o Global tem tratamento para fechamento do app
	var has_notification_handler = Global.has_method("_notification")
	
	if not has_notification_handler:
		print("   ⚠️ PROBLEMA IDENTIFICADO: Global.gd não tem tratamento de _notification")
		print("   📝 Isso pode causar perda de dados ao fechar o app abruptamente")
	
	test_results.append({
		"test": "Tratamento de Notificações",
		"success": has_notification_handler,
		"details": "Handler _notification: %s" % ("presente" if has_notification_handler else "ausente")
	})
	
	print("   ", "✅ PASSOU" if has_notification_handler else "❌ FALHOU")

func show_test_results():
	print("\n=== RESULTADOS DOS TESTES DE PERSISTÊNCIA ===")
	
	var passed = 0
	var total = test_results.size()
	
	for result in test_results:
		var status = "✅ PASSOU" if result.success else "❌ FALHOU"
		print("• %s: %s" % [result.test, status])
		print("  Detalhes: %s" % result.details)
		if result.success:
			passed += 1
	
	print("\n📊 RESUMO: %d/%d testes passaram (%.1f%%)" % [passed, total, (passed * 100.0 / total)])
	
	if passed < total:
		print("\n🔧 PROBLEMAS IDENTIFICADOS:")
		for result in test_results:
			if not result.success:
				print("• %s: %s" % [result.test, result.details])
		
		print("\n💡 RECOMENDAÇÕES:")
		print("1. Implementar _notification() no Global.gd para salvar dados ao fechar")
		print("2. Adicionar salvamento automático periódico")
		print("3. Verificar regras de segurança do Firebase")
		print("4. Implementar sistema de backup local robusto")
	else:
		print("\n🎉 Todos os testes passaram! Sistema de persistência funcionando corretamente.")
	
	# Restaura dados originais
	restore_original_data()

func restore_original_data():
	Global.player_name = original_data.player_name
	Global.player_id = original_data.player_id
	Global.points = original_data.points
	Global.gold = original_data.gold
	Global.crystal = original_data.crystal
	Global.level = original_data.level
	Global.selected_avatar = original_data.selected_avatar
	
	Global.save_local_data()
	print("\n🔄 Dados originais restaurados")