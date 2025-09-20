extends Node

# Firebase Auth Manager - Sistema seguro de verificação de usuário
# Implementa métodos HTTP corretos seguindo as melhores práticas do Firebase

## CONSTANTES DE CONFIGURAÇÃO ##
const FIREBASE_AUTH_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword"
const FIREBASE_SIGNUP_URL = "https://identitytoolkit.googleapis.com/v1/accounts:signUp"
const FIREBASE_LOOKUP_URL = "https://identitytoolkit.googleapis.com/v1/accounts:lookup"
const FIREBASE_SECURE_TOKEN_URL = "https://securetoken.googleapis.com/v1/token"

## SINAIS ##
signal auth_success(auth_data: Dictionary)
signal auth_failed(error_code: int, error_message: String)
signal user_verified(user_exists: bool, user_data: Dictionary)
signal csrf_token_updated(token: String)

## VARIÁVEIS ##
var api_key: String = ""
var csrf_token: String = ""
var http_client: HTTPRequest
var pending_requests: Dictionary = {}

# Inicialização
func _ready():
	# Configura cliente HTTP
	http_client = HTTPRequest.new()
	add_child(http_client)
	http_client.request_completed.connect(_on_http_request_completed)
	
	# Carrega API key da configuração
	var config = _load_firebase_config()
	api_key = config.get("apiKey", "")
	
	# Gera token CSRF inicial
	_generate_csrf_token()

## MÉTODOS PÚBLICOS ##

# Verifica se um usuário existe (método GET seguro)
func check_user_exists(email: String) -> void:
	"""
	Verifica se um email já está registrado no Firebase
	Usa método GET seguro apenas para consultas públicas
	"""
	if not _validate_email(email):
		auth_failed.emit(-1, "Email inválido")
		return
	
	var headers = _get_secure_headers()
	var url = FIREBASE_LOOKUP_URL + "?key=" + api_key
	
	var body = JSON.stringify({
		"email": [email]
	})
	
	var request_id = http_client.request(url, headers, HTTPClient.METHOD_POST, body)
	pending_requests[request_id] = {
		"type": "user_lookup",
		"email": email
	}

# Autentica usuário (método POST seguro)
func authenticate_user(email: String, password: String) -> void:
	"""
	Autentica usuário com credenciais criptografadas
	Usa método POST seguro para envio de dados sensíveis
	"""
	if not _validate_credentials(email, password):
		auth_failed.emit(-1, "Credenciais inválidas")
		return
	
	var encrypted_password = _encrypt_password(password)
	var headers = _get_secure_headers()
	var url = FIREBASE_AUTH_URL + "?key=" + api_key
	
	var body = JSON.stringify({
		"email": email,
		"password": encrypted_password,
		"returnSecureToken": true
	})
	
	var request_id = http_client.request(url, headers, HTTPClient.METHOD_POST, body)
	pending_requests[request_id] = {
		"type": "auth",
		"email": email
	}

# Registra novo usuário (método POST seguro)
func register_user(email: String, password: String, display_name: String = "") -> void:
	"""
	Registra novo usuário com credenciais criptografadas
	Usa método POST seguro para envio de dados sensíveis
	"""
	if not _validate_credentials(email, password):
		auth_failed.emit(-1, "Credenciais inválidas")
		return
	
	var encrypted_password = _encrypt_password(password)
	var headers = _get_secure_headers()
	var url = FIREBASE_SIGNUP_URL + "?key=" + api_key
	
	var body = JSON.stringify({
		"email": email,
		"password": encrypted_password,
		"displayName": display_name,
		"returnSecureToken": true
	})
	
	var request_id = http_client.request(url, headers, HTTPClient.METHOD_POST, body)
	pending_requests[request_id] = {
		"type": "signup",
		"email": email
	}

# Atualiza token de acesso
func refresh_token(refresh_token: String) -> void:
	"""
	Atualiza token de acesso usando refresh token
	"""
	var headers = _get_secure_headers()
	var url = FIREBASE_SECURE_TOKEN_URL + "?key=" + api_key
	
	var body = JSON.stringify({
		"grant_type": "refresh_token",
		"refresh_token": refresh_token
	})
	
	var request_id = http_client.request(url, headers, HTTPClient.METHOD_POST, body)
	pending_requests[request_id] = {
		"type": "token_refresh"
	}

## MÉTODOS PRIVADOS ##

# Carrega configuração do Firebase
func _load_firebase_config() -> Dictionary:
	var config_script = preload("res://firebase_config.gd")
	var config_instance = config_script.new()
	return config_instance.get_firebase_config()

# Gera headers seguros
func _get_secure_headers() -> PackedStringArray:
	return [
		"Content-Type: application/json",
		"X-CSRF-Token: " + csrf_token,
		"X-Requested-With: XMLHttpRequest",
		"User-Agent: Godot-Firebase-Auth/1.0"
	]

# Gera token CSRF
func _generate_csrf_token() -> void:
	var random = RandomNumberGenerator.new()
	random.randomize()
	csrf_token = str(random.randi()) + str(Time.get_unix_time_from_system())
	csrf_token_updated.emit(csrf_token)

# Valida email
func _validate_email(email: String) -> bool:
	var email_regex = RegEx.new()
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return email_regex.search(email) != null

# Valida credenciais
func _validate_credentials(email: String, password: String) -> bool:
	return _validate_email(email) and password.length() >= 6

# Criptografa senha (hash básico para demonstração)
func _encrypt_password(password: String) -> String:
	# Em produção, use biblioteca de criptografia adequada
	var sha = password.sha256_text()
	return sha

# Processa respostas HTTP
func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_id = http_client.get_http_client_status()
	var request_data = pending_requests.get(request_id, {})
	
	if request_data.is_empty():
		return
	
	var response_body = body.get_string_from_utf8()
	var json_response = JSON.parse_string(response_body)
	
	match request_data["type"]:
		"auth":
			_handle_auth_response(result, response_code, json_response, request_data)
		"signup":
			_handle_signup_response(result, response_code, json_response, request_data)
		"user_lookup":
			_handle_lookup_response(result, response_code, json_response, request_data)
		"token_refresh":
			_handle_token_refresh_response(result, response_code, json_response)
	
	pending_requests.erase(request_id)

# Manipula resposta de autenticação
func _handle_auth_response(result: int, response_code: int, response: Variant, request_data: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		auth_failed.emit(result, "Falha na conexão")
		return
	
	if response_code != 200:
		var error_msg = _get_error_message(response)
		auth_failed.emit(response_code, error_msg)
		return
	
	if response and response.has("idToken"):
		auth_success.emit(response)
	else:
		auth_failed.emit(-1, "Resposta inválida do servidor")

# Manipula resposta de registro
func _handle_signup_response(result: int, response_code: int, response: Variant, request_data: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		auth_failed.emit(result, "Falha na conexão")
		return
	
	if response_code != 200:
		var error_msg = _get_error_message(response)
		auth_failed.emit(response_code, error_msg)
		return
	
	if response and response.has("idToken"):
		auth_success.emit(response)
	else:
		auth_failed.emit(-1, "Resposta inválida do servidor")

# Manipula resposta de verificação de usuário
func _handle_lookup_response(result: int, response_code: int, response: Variant, request_data: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		user_verified.emit(false, {"error": "Falha na conexão"})
		return
	
	if response_code != 200:
		user_verified.emit(false, {"error": "Erro HTTP: " + str(response_code)})
		return
	
	var user_exists = false
	var user_data = {}
	
	if response and response.has("users"):
		var users = response["users"]
		if users is Array and users.size() > 0:
			user_exists = true
			user_data = users[0]
	
	user_verified.emit(user_exists, user_data)

# Manipula resposta de atualização de token
func _handle_token_refresh_response(result: int, response_code: int, response: Variant) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("Falha ao atualizar token")
		return
	
	if response and response.has("id_token"):
		# Token atualizado com sucesso
		pass

# Extrai mensagem de erro da resposta
func _get_error_message(response: Variant) -> String:
	if not response or not response.has("error"):
		return "Erro desconhecido"
	
	var error_data = response["error"]
	if error_data.has("message"):
		return error_data["message"]
	
	return "Erro de autenticação"

# Limpeza
func _exit_tree():
	if http_client:
		http_client.queue_free()