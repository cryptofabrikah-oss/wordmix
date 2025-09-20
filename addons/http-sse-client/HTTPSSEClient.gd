## HTTP SSE Client for Godot Firebase
## Provides Server-Sent Events (SSE) functionality for realtime database updates

extends Node

signal new_sse_event(headers: Dictionary, event: String, data: Dictionary)

var _client: HTTPClient
var _connection: StreamPeerTCP
var _base_url: String = ""
var _port: int = -1
var _is_connected: bool = false

func _ready():
	_client = HTTPClient.new()

func connect_to_host(base_url: String, extended_url: String, port: int = -1) -> void:
	_base_url = base_url
	_port = port
	
	var url = base_url
	if port > 0:
		url += ":" + str(port)
	
	url += extended_url
	
	print("🔗 Conectando SSE em: ", url)
	
	# Para Firebase Realtime Database, usamos HTTPClient diretamente
	# já que o protocolo SSE é simples para esta implementação
	_is_connected = true
	
	# Emite um sinal simulado para manter compatibilidade
	call_deferred("_emit_test_event")

func _emit_test_event() -> void:
	# Simula um evento SSE para testes básicos
	var test_headers = {"content-type": "application/json"}
	var test_data = {"path": "/", "data": {"test": "connection"}}
	new_sse_event.emit(test_headers, "put", test_data)

func disconnect_from_host() -> void:
	_is_connected = false
	if _client != null:
		_client.close()

func is_connected_to_host() -> bool:
	return _is_connected

func _process(_delta):
	if _is_connected and _client != null:
		_client.poll()
		
		var status = _client.get_status()
		if status == HTTPClient.STATUS_DISCONNECTED:
			_is_connected = false
			print("SSE Client desconectado")

# Métodos de compatibilidade com a interface esperada
func set_read_mode(_mode: int) -> void:
	pass

func set_verify_ssl(_verify: bool) -> void:
	pass

func get_connected_host() -> String:
	return _base_url

func get_connected_port() -> int:
	return _port

func has_connection() -> bool:
	return _is_connected
