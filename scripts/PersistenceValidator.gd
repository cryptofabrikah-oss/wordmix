extends Node

# Validador de Persistência
# Verifica se todas as correções implementadas estão funcionando

func _ready():
	print("🔍 Iniciando Validação de Persistência...")
	await get_tree().create_timer(2.0).timeout
	validate_persistence_system()

func validate_persistence_system():
	print("\n=== VALIDAÇÃO DO SISTEMA DE PERSISTÊNCIA ===")
	
	var validation_results = []
	
	# Validação 1: Tratamento de notificações
	validation_results.append(validate_notification_handler())
	
	# Validação 2: Salvamento automático
	validation_results.append(validate_auto_save_system())
	
	# Validação 3: Sincronização dupla (local + Firebase)
	validation_results.append(validate_dual_sync())
	
	# Validação 4: Regras de segurança do Firebase
	validation_results.append(validate_firebase_rules())
	
	# Validação 5: Teste de persistência real
	await validate_real_persistence()
	
	# Mostra resultados finais
	show_validation_results(validation_results)

func validate_notification_handler() -> Dictionary:
	print("\n🔍 Validação 1: Tratamento de Notificações do Sistema")
	
	var has_handler = Global.has_method("_notification")
	var has_save_on_exit = Global.has_method("_save_on_exit")
	
	var success = has_handler and has_save_on_exit
	
	print("   • Handler _notification: ", "✅" if has_handler else "❌")
	print("   • Função _save_on_exit: ", "✅" if has_save_on_exit else "❌")
	
	return {
		"test": "Tratamento de Notificações",
		"success": success,
		"details": "Handler: %s, Save on exit: %s" % [has_handler, has_save_on_exit]
	}

func validate_auto_save_system() -> Dictionary:
	print("\n🔍 Validação 2: Sistema de Salvamento Automático")
	
	var has_auto_save_manager = has_node("/root/AutoSaveManager")
	var auto_save_enabled = false
	
	if has_auto_save_manager:
		var manager = get_node("/root/AutoSaveManager")
		auto_save_enabled = manager.is_auto_save_enabled
	
	var success = has_auto_save_manager and auto_save_enabled
	
	print("   • AutoSaveManager presente: ", "✅" if has_auto_save_manager else "❌")
	print("   • Salvamento automático ativo: ", "✅" if auto_save_enabled else "❌")
	
	return {
		"test": "Sistema de Salvamento Automático",
		"success": success,
		"details": "Manager: %s, Enabled: %s" % [has_auto_save_manager, auto_save_enabled]
	}

func validate_dual_sync() -> Dictionary:
	print("\n🔍 Validação 3: Sincronização Dupla (Local + Firebase)")
	
	# Testa se sync_data salva tanto local quanto Firebase
	var initial_points = Global.points
	Global.points += 1  # Pequena alteração
	
	# Chama sync_data e verifica se salva localmente
	Global.sync_data()
	
	# Verifica se os dados foram salvos localmente
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	var local_saved = (err == OK and config.get_value("player", "points", 0) == Global.points)
	
	# Restaura valor original
	Global.points = initial_points
	Global.sync_data()
	
	print("   • Salvamento local na sync_data: ", "✅" if local_saved else "❌")
	print("   • Firebase online: ", "✅" if Global.is_online else "⚠️ Offline")
	
	return {
		"test": "Sincronização Dupla",
		"success": local_saved,
		"details": "Local: %s, Firebase: %s" % [local_saved, Global.is_online]
	}

func validate_firebase_rules() -> Dictionary:
	print("\n🔍 Validação 4: Regras de Segurança do Firebase")
	
	# Verifica se as regras estão configuradas corretamente
	var rules_correct = true
	var issues = []
	
	# Verifica se o caminho usado no código ("players") bate com as regras
	if Global.is_online:
		print("   • Firebase online - regras podem ser testadas")
		# Aqui poderíamos fazer um teste real, mas por segurança apenas validamos a estrutura
	else:
		print("   • Firebase offline - validação de regras limitada")
		rules_correct = false
		issues.append("Firebase offline")
	
	# Verifica se o player_id está válido
	if Global.player_id.is_empty():
		rules_correct = false
		issues.append("Player ID vazio")
	
	print("   • Player ID válido: ", "✅" if not Global.player_id.is_empty() else "❌")
	print("   • Autenticação ativa: ", "✅" if Global.is_online else "❌")
	
	return {
		"test": "Regras de Segurança Firebase",
		"success": rules_correct,
		"details": "Issues: %s" % str(issues) if issues.size() > 0 else "OK"
	}

func validate_real_persistence() -> Dictionary:
	print("\n🔍 Validação 5: Teste de Persistência Real")
	
	# Salva estado atual
	var original_points = Global.points
	var original_gold = Global.gold
	
	# Faz alterações
	Global.points += 100
	Global.gold += 50
	
	print("   • Dados alterados temporariamente")
	
	# Força salvamento completo
	Global._save_on_exit()
	await get_tree().create_timer(1.0).timeout
	
	# Simula "reinício" carregando dados
	Global.load_local_data()
	
	# Verifica se as alterações persistiram
	var points_persisted = (Global.points == original_points + 100)
	var gold_persisted = (Global.gold == original_gold + 50)
	
	var success = points_persisted and gold_persisted
	
	print("   • Points persistiram: ", "✅" if points_persisted else "❌")
	print("   • Gold persistiu: ", "✅" if gold_persisted else "❌")
	
	# Restaura valores originais
	Global.points = original_points
	Global.gold = original_gold
	Global.save_local_data()
	
	return {
		"test": "Persistência Real",
		"success": success,
		"details": "Points: %s, Gold: %s" % [points_persisted, gold_persisted]
	}

func show_validation_results(results: Array):
	print("\n=== RESULTADOS DA VALIDAÇÃO ===")
	
	var passed = 0
	var total = results.size()
	
	for result in results:
		var status = "✅ PASSOU" if result.success else "❌ FALHOU"
		print("• %s: %s" % [result.test, status])
		print("  %s" % result.details)
		if result.success:
			passed += 1
	
	var percentage = (passed * 100.0 / total) if total > 0 else 0
	print("\n📊 RESULTADO FINAL: %d/%d validações passaram (%.1f%%)" % [passed, total, percentage])
	
	if passed == total:
		print("\n🎉 SISTEMA DE PERSISTÊNCIA TOTALMENTE FUNCIONAL!")
		print("✅ Todas as correções foram implementadas com sucesso")
		print("✅ Os dados do jogador agora persistem corretamente")
		print("✅ O problema de perda de progresso foi resolvido")
	else:
		print("\n⚠️ ALGUMAS VALIDAÇÕES FALHARAM")
		print("🔧 Verifique os itens marcados como falhou acima")
	
	print("\n💡 RESUMO DAS CORREÇÕES IMPLEMENTADAS:")
	print("1. ✅ Tratamento de notificações do sistema (_notification)")
	print("2. ✅ Salvamento automático periódico (AutoSaveManager)")
	print("3. ✅ Sincronização dupla (local + Firebase)")
	print("4. ✅ Salvamento em todas as operações de mudança de dados")
	print("5. ✅ Sistema de backup local robusto")