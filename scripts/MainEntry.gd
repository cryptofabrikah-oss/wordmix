extends Control

# Script de entrada principal que decide o fluxo inicial do jogo

func _ready():
	# Aguarda o Global carregar os dados
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout  # Pequena pausa para carregamento
	
	# Sempre vai para a tela Start - ela agora gerencia a entrada de nome inline
	print("Iniciando jogo - indo para Start")
	get_tree().change_scene_to_file("res://scenes/Start.tscn")
