extends Node

# Firebase Configuration
# IMPORTANTE: Você precisa preencher essas informações com os dados do seu projeto Firebase
# Para obter essas informações:
# 1. Acesse https://console.firebase.google.com/
# 2. Selecione seu projeto ou crie um novo
# 3. Vá em Configurações do projeto > Geral
# 4. Role para baixo até "Seus apps" e clique em "Configuração"

func get_firebase_config() -> Dictionary:
	return {
		"apiKey": "AIzaSyAzP482P_Y7iS9wrnYqjtJWE0qwAN_4OWE", # Sua API Key do Firebase
		"authDomain": "cinco-words.firebaseapp.com", # Seu domínio de autenticação (projeto-id.firebaseapp.com)
		"databaseURL": "https://cinco-words-default-rtdb.firebaseio.com/", # URL do Realtime Database (se usar)
		"projectId": "cinco-words", # ID do seu projeto Firebase
		"storageBucket": "cinco-words.appspot.com", # Bucket de storage (projeto-id.appspot.com)
		"messagingSenderId": "469180192710", # Sender ID para mensagens
		"appId": "1:469180192710:web:ebf3b39e910591b56884c7", # App ID do Firebase (web)
		"measurementId": "", # Measurement ID (se usar Analytics)
		"clientId": "", # Client ID (se usar OAuth)
		"clientSecret": "", # Client Secret (se usar OAuth)
		"domainUriPrefix": "", # Prefixo para Dynamic Links
		"cacheLocation": "user://firebase_cache/", # Local do cache
		"emulators": {
			"ports": {
				"authentication": "",
				"realtimeDatabase": ""
			}
		},
		"workarounds": {
			"database_connection_closed_issue": false
		},
		"auth_providers": {
			"facebook_id": "",
			"google_id": "",
			"twitter_id": "",
			"github_id": ""
		}
	}