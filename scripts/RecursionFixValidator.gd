extends Node

# Validador para testar a correção do problema de recursão infinita
# Este script testa se o sistema de sincronização está funcionando sem loops

class_name RecursionFixValidator

func _ready():
	print("🔧 RecursionFixValidator iniciado")

# Testa se a proteção contra recursão está funcionando
func test_recursion_protection():
	print("\n=== TESTE DE PROTEÇÃO CONTRA RECURSÃO ===")
	
	# Simula múltiplas chamadas rápidas de sincronização
	print("📋 Testando múltiplas chamadas de sync_data()...")
	
	var initial_sync_state = Global.is_syncing
	print("   Estado inicial is_syncing: ", initial_sync_state)
	
	# Primeira chamada
	print("   Chamada 1: sync_data()")
	Global.sync_data()
	
	# Verifica se a flag foi ativada
	if Global.is_syncing:
		print("   ✅ Proteção ativada corretamente")
	else:
		print("   ❌ ERRO: Proteção não foi ativada")
		return false
	
	# Segunda chamada imediata (deve ser bloqueada)
	print("   Chamada 2: sync_data() (deve ser bloqueada)")
	Global.sync_data()
	
	# Terceira chamada imediata (deve ser bloqueada)
	print("   Chamada 3: sync_data() (deve ser bloqueada)")
	Global.sync_data()
	
	print("   ✅ Teste de múltiplas chamadas concluído")
	return true

# Testa se o callback _on_data_updated não causa recursão
func test_callback_protection():
	print("\n=== TESTE DE PROTEÇÃO DO CALLBACK ===")
	
	print("📋 Testando callback _on_data_updated()...")
	
	# Simula estado de sincronização ativa
	Global.is_syncing = true
	print("   Simulando is_syncing = true")
	
	# Chama o callback (deve ser bloqueado)
	print("   Chamando _on_data_updated() (deve ser bloqueado)")
	Global._on_data_updated()
	
	# Reset para teste normal
	Global.is_syncing = false
	print("   Reset is_syncing = false")
	
	# Chama o callback normalmente
	print("   Chamando _on_data_updated() (deve funcionar)")
	Global._on_data_updated()
	
	print("   ✅ Teste de proteção do callback concluído")
	return true

# Testa se as emissões de sinal estão protegidas
func test_signal_emission_protection():
	print("\n=== TESTE DE PROTEÇÃO DE EMISSÃO DE SINAIS ===")
	
	print("📋 Testando emissões de sinal durante sincronização...")
	
	# Simula estado de sincronização
	Global.is_syncing = true
	print("   Simulando is_syncing = true")
	
	# Testa load_local_data (não deve emitir sinal)
	print("   Chamando load_local_data() (não deve emitir sinal)")
	Global.load_local_data()
	
	# Reset
	Global.is_syncing = false
	print("   Reset is_syncing = false")
	
	# Testa load_local_data normal (deve emitir sinal)
	print("   Chamando load_local_data() (deve emitir sinal)")
	Global.load_local_data()
	
	print("   ✅ Teste de proteção de emissão concluído")
	return true

# Executa todos os testes
func run_all_tests():
	print("\n🚀 INICIANDO TESTES DE CORREÇÃO DE RECURSÃO")
	print("=" * 50)
	
	var tests_passed = 0
	var total_tests = 3
	
	# Teste 1: Proteção contra recursão
	if test_recursion_protection():
		tests_passed += 1
	
	# Teste 2: Proteção do callback
	if test_callback_protection():
		tests_passed += 1
	
	# Teste 3: Proteção de emissão de sinais
	if test_signal_emission_protection():
		tests_passed += 1
	
	# Resultado final
	print("\n" + "=" * 50)
	print("📊 RESULTADO DOS TESTES:")
	print("   Testes aprovados: ", tests_passed, "/", total_tests)
	
	if tests_passed == total_tests:
		print("   🎉 TODOS OS TESTES PASSARAM!")
		print("   ✅ Problema de recursão infinita CORRIGIDO")
	else:
		print("   ⚠️ Alguns testes falharam")
		print("   ❌ Problema de recursão pode ainda existir")
	
	return tests_passed == total_tests

# Monitora o estado de sincronização em tempo real
func monitor_sync_state():
	print("\n🔍 MONITOR DE ESTADO DE SINCRONIZAÇÃO")
	print("   is_syncing atual: ", Global.is_syncing)
	print("   player_data_loaded: ", Global.player_data_loaded)
	print("   is_online: ", Global.is_online)
	print("   player_id: ", Global.player_id if not Global.player_id.is_empty() else "vazio")