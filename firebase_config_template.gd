extends Node

# Configuração segura do Firebase para jogos mobile
# Usa apenas client-side authentication - SEM service account necessário!
# Perfeito para jogos que precisam de auth + realtime database

class_name FirebaseConfigTemplate

# Configuração completa do Firebase usando variáveis de ambiente
# APENAS o que é necessário para jogos mobile
func get_firebase_config() -> Dictionary:
	return {
		# Configurações essenciais (obrigatórias)
		"apiKey": OS.get_environment("FIREBASE_API_KEY"),
		"authDomain": OS.get_environment("FIREBASE_AUTH_DOMAIN"), 
		"databaseURL": OS.get_environment("FIREBASE_DATABASE_URL"),
		"projectId": OS.get_environment("FIREBASE_PROJECT_ID"),
		"storageBucket": OS.get_environment("FIREBASE_STORAGE_BUCKET"),
		"messagingSenderId": OS.get_environment("FIREBASE_MESSAGING_SENDER_ID"),
		"appId": OS.get_environment("FIREBASE_APP_ID"),
		
		# Configurações opcionais
		"measurementId": OS.get_environment("FIREBASE_MEASUREMENT_ID"), # Para Analytics
		"cacheLocation": "user://firebase_cache/",
		
		# Configurações de emuladores (desenvolvimento)
		"emulators": {
			"ports": {
				"authentication": "",
				"realtimeDatabase": ""
			}
		},
		
		# Workarounds conhecidos
		"workarounds": {
			"database_connection_closed_issue": false
		},
		
		# Provedores de autenticação (se usar OAuth)
		"auth_providers": {
			"facebook_id": OS.get_environment("FIREBASE_FACEBOOK_ID"),
			"google_id": OS.get_environment("FIREBASE_GOOGLE_ID"),
			"twitter_id": OS.get_environment("FIREBASE_TWITTER_ID"),
			"github_id": OS.get_environment("FIREBASE_GITHUB_ID")
		}
	}

func _ready():
	# Verifica se as variáveis essenciais estão definidas
	validate_environment_variables()

func validate_environment_variables():
	var required_vars = [
		"FIREBASE_API_KEY",
		"FIREBASE_AUTH_DOMAIN", 
		"FIREBASE_DATABASE_URL",
		"FIREBASE_PROJECT_ID",
		"FIREBASE_STORAGE_BUCKET",
		"FIREBASE_MESSAGING_SENDER_ID",
		"FIREBASE_APP_ID"
	]
	
	var missing_vars = []
	for var_name in required_vars:
		if OS.get_environment(var_name) == "":
			missing_vars.append(var_name)
	
	if missing_vars.size() > 0:
		print("⚠️ AVISO: Variáveis de ambiente Firebase não definidas:")
		for var_name in missing_vars:
			print("   - " + var_name)
		print("📋 Configure essas variáveis antes de usar o Firebase")

func get_config():
	return config

func get_service_account():
	return service_account