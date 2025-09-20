extends Node

# Script de teste para debug do botão de confirmação
# Execute este script para testar o fluxo completo

func _ready():
	print("🧪 INICIANDO TESTE DE DEBUG DO BOTÃO")
	print("=" * 50)
	
	# Aguarda um pouco para garantir que tudo carregou
	await get_tree().create_timer(1.0).timeout
	
	# Verifica estado inicial
	print("📊 ESTADO INICIAL:")
	print("   • Global.player_name: '", Global.player_name, "'")
	print("   • Global.player_id: '", Global.player_id, "'")
	print("   • Global.is_online: ", Global.is_online)
	print("   • Firebase disponível: ", Global.firebase_reference != null)
	
	# Simula primeira execução
	print("\n🎯 SIMULANDO PRIMEIRA EXECUÇÃO...")
	print("   • Limpando dados do Global...")
	Global.player_name = ""
	Global.player_id = ""
	Global.points = 0
	Global.gold = 100
	Global.crystal = 0
	Global.level = 1
	
	print("   • Verificando is_first_run(): ", Global.is_first_run())
	
	# Aguarda um pouco
	await get_tree().create_timer(1.0).timeout
	
	# Vai para a tela principal (Start.tscn) - lógica de primeira execução integrada
	print("\n🚀 REDIRECIONANDO PARA Start...")
	get_tree().change_scene_to_file("res://scenes/Start.tscn")