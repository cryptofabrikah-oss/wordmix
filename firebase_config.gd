extends Node

# Firebase Configuration - Client-Side Only
# Para obter essas configurações:
# 1. Acesse https://console.firebase.google.com/
# 2. Selecione seu projeto
# 3. Vá em Configurações do projeto > Geral
# 4. Role até "Seus apps" e clique em "Configuração"

func get_firebase_config() -> Dictionary:
	return {
		"apiKey": "AIzaSyAzP482P_Y7iS9wrnYqjtJWE0qwAN_4OWE",
		"authDomain": "cinco-words.firebaseapp.com",
		"databaseURL": "https://cinco-words-default-rtdb.firebaseio.com/",
		"projectId": "cinco-words",
		"storageBucket": "cinco-words.appspot.com",
		"messagingSenderId": "469180192710",
		"appId": "1:469180192710:web:ebf3b39e910591b56884c7",
		"measurementId": "", # Analytics (opcional)
		"cacheLocation": "user://firebase_cache/",
		"emulators": {
			"ports": {
				"authentication": "",
				"realtimeDatabase": ""
			}
		},
		"workarounds": {
			"database_connection_closed_issue": false
		}
	}