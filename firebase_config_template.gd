extends Node

# Template de configuração segura do Firebase
# Use variáveis de ambiente para armazenar credenciais sensíveis

class_name FirebaseConfigTemplate

# Configuração do Firebase usando variáveis de ambiente
var config = {
	"apiKey": OS.get_environment("FIREBASE_API_KEY"),
	"authDomain": OS.get_environment("FIREBASE_AUTH_DOMAIN"),
	"databaseURL": OS.get_environment("FIREBASE_DATABASE_URL"),
	"projectId": OS.get_environment("FIREBASE_PROJECT_ID"),
	"storageBucket": OS.get_environment("FIREBASE_STORAGE_BUCKET"),
	"messagingSenderId": OS.get_environment("FIREBASE_MESSAGING_SENDER_ID"),
	"appId": OS.get_environment("FIREBASE_APP_ID")
}

# Service Account (para uso server-side)
var service_account = {
	"type": "service_account",
	"project_id": OS.get_environment("FIREBASE_PROJECT_ID"),
	"private_key_id": OS.get_environment("FIREBASE_PRIVATE_KEY_ID"),
	"private_key": OS.get_environment("FIREBASE_PRIVATE_KEY"),
	"client_email": OS.get_environment("FIREBASE_CLIENT_EMAIL"),
	"client_id": OS.get_environment("FIREBASE_CLIENT_ID"),
	"auth_uri": "https://accounts.google.com/o/oauth2/auth",
	"token_uri": "https://oauth2.googleapis.com/token",
	"auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
	"client_x509_cert_url": OS.get_environment("FIREBASE_CLIENT_X509_CERT_URL"),
	"universe_domain": "googleapis.com"
}

func _ready():
	# Verifica se todas as variáveis de ambiente necessárias estão definidas
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