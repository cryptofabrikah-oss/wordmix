extends Node

# Firebase Configuration - Secure Version
# IMPORTANTE: Este arquivo agora lê configurações do arquivo .env.local
# Para configurar:
# 1. Copie o arquivo .env.local.template como .env.local
# 2. Preencha suas credenciais reais no .env.local
# 3. O arquivo .env.local NÃO será commitado (protegido pelo .gitignore)

# Importa o gerenciador de configuração segura
const FirebaseConfigSecure = preload("res://firebase_config_secure.gd")

func get_firebase_config() -> Dictionary:
	"""Retorna configuração do Firebase de forma segura"""
	return FirebaseConfigSecure.get_firebase_config()