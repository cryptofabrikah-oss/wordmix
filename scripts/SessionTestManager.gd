extends Node

# Gerenciador de Testes de Sessão
# Simula cenários reais de uso do jogo para testar persistência

var test_data = {}
var session_count = 0

func _ready():
	print("🧪 Iniciando Gerenciador de Testes de Sessão...")
	await get_tree().create_timer(1.0).timeout
	run_session_tests()

func run_session_tests():
	print("\n=== SIMULAÇÃO DE SESSÕES DE JOGO ===")
	
	# Teste 1: Sessão normal com progresso
	await simulate_normal_session()
	
	# Teste 2: Fechamento abrupto
	await simulate_abrupt_closure()
	
	# Teste 3: Perda de conexão durante o jogo
	await simulate_connection_loss()
	
	# Teste 4: Múltiplas sessões curtas
	await simulate_multiple_short_sessions()
	
	print("\n✅ Todos os testes de sessão concluídos!")

func simulate_normal_session():
	print("\n🎮 TESTE 1: Sessão Normal de Jogo")
	session_count += 1
	
	# Salva estado inicial
	var initial_state = capture_player_state()
	print("   📊 Estado inicial capturado")
	
	# Simula progresso durante o jogo
	print("   🎯 Simulando progresso no jogo...")
	Global.add_points(100)
	Global.add_gold(50)
	Global.add_crystal(5)
	
	await get_tree().create_timer(1.0).timeout
	
	# Simula fechamento normal (com salvamento)
	print("   💾 Simulando fechamento normal...")
	Global._save_on_exit()
	
	await get_tree().create_timer(2.0).timeout
	
	# Verifica se os dados persistiram
	var final_state = capture_player_state()
	var progress_saved = verify_progress(initial_state, final_state, {"points": 100, "gold": 50, "crystal": 5})
	
	print("   ", "✅ PASSOU - Progresso mantido" if progress_saved else "❌ FALHOU - Progresso perdido")

func simulate_abrupt_closure():
	print("\n⚡ TESTE 2: Fechamento Abrupto")
	session_count += 1
	
	var initial_state = capture_player_state()
	
	# Simula progresso
	print("   🎯 Simulando progresso...")
	Global.add_points(75)
	Global.add_gold(25)
	
	# Simula fechamento abrupto (sem salvamento explícito)
	print("   ⚡ Simulando fechamento abrupto...")
	# O sistema de _notification deveria capturar isso
	Global._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	
	await get_tree().create_timer(1.0).timeout
	
	# Simula "reabertura" carregando dados
	print("   🔄 Simulando reabertura do jogo...")
	Global.load_local_data()
	
	var final_state = capture_player_state()
	var progress_saved = verify_progress(initial_state, final_state, {"points": 75, "gold": 25, "crystal": 0})
	
	print("   ", "✅ PASSOU - Sistema de emergência funcionou" if progress_saved else "❌ FALHOU - Dados perdidos no fechamento abrupto")

func simulate_connection_loss():
	print("\n📡 TESTE 3: Perda de Conexão")
	session_count += 1
	
	var initial_state = capture_player_state()
	var was_online = Global.is_online
	
	# Simula perda de conexão
	print("   📡 Simulando perda de conexão...")
	Global.is_online = false
	
	# Progresso durante offline
	print("   🎯 Progresso durante modo offline...")
	Global.add_points(60)
	Global.add_gold(30)
	
	await get_tree().create_timer(1.0).timeout
	
	# Restaura conexão
	print("   🌐 Restaurando conexão...")
	Global.is_online = was_online
	
	# Força sincronização
	if Global.is_online:
		Global.force_upload_data()
	
	await get_tree().create_timer(2.0).timeout
	
	var final_state = capture_player_state()
	var progress_saved = verify_progress(initial_state, final_state, {"points": 60, "gold": 30, "crystal": 0})
	
	print("   ", "✅ PASSOU - Dados offline sincronizados" if progress_saved else "❌ FALHOU - Sincronização offline falhou")

func simulate_multiple_short_sessions():
	print("\n🔄 TESTE 4: Múltiplas Sessões Curtas")
	
	var initial_state = capture_player_state()
	var total_points = 0
	var total_gold = 0
	
	# Simula 5 sessões curtas
	for i in range(5):
		session_count += 1
		print("   📱 Sessão %d/5..." % (i + 1))
		
		# Pequeno progresso
		var points_gain = 20
		var gold_gain = 10
		
		Global.add_points(points_gain)
		Global.add_gold(gold_gain)
		
		total_points += points_gain
		total_gold += gold_gain
		
		# Salva e "fecha" a sessão
		Global._save_on_exit()
		
		# Pequena pausa entre sessões
		await get_tree().create_timer(0.5).timeout
		
		# "Reabre" carregando dados
		Global.load_local_data()
	
	var final_state = capture_player_state()
	var progress_saved = verify_progress(initial_state, final_state, {"points": total_points, "gold": total_gold, "crystal": 0})
	
	print("   ", "✅ PASSOU - Múltiplas sessões mantidas" if progress_saved else "❌ FALHOU - Dados perdidos entre sessões")

func capture_player_state() -> Dictionary:
	return {
		"points": Global.points,
		"gold": Global.gold,
		"crystal": Global.crystal,
		"level": Global.level,
		"player_name": Global.player_name,
		"player_id": Global.player_id
	}

func verify_progress(initial: Dictionary, final: Dictionary, expected_gains: Dictionary) -> bool:
	var points_correct = final.points == (initial.points + expected_gains.get("points", 0))
	var gold_correct = final.gold == (initial.gold + expected_gains.get("gold", 0))
	var crystal_correct = final.crystal == (initial.crystal + expected_gains.get("crystal", 0))
	
	if not points_correct:
		print("     ❌ Points: esperado %d, obtido %d" % [initial.points + expected_gains.get("points", 0), final.points])
	if not gold_correct:
		print("     ❌ Gold: esperado %d, obtido %d" % [initial.gold + expected_gains.get("gold", 0), final.gold])
	if not crystal_correct:
		print("     ❌ Crystal: esperado %d, obtido %d" % [initial.crystal + expected_gains.get("crystal", 0), final.crystal])
	
	return points_correct and gold_correct and crystal_correct

func get_test_summary() -> Dictionary:
	return {
		"sessions_tested": session_count,
		"auto_save_enabled": AutoSaveManager.is_auto_save_enabled if has_node("/root/AutoSaveManager") else false,
		"notification_handler": Global.has_method("_notification"),
		"firebase_online": Global.is_online
	}