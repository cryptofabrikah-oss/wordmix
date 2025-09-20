extends Node

# ===== GERENCIADOR DE ID PERSISTENTE WORDMIX =====
# Sistema dedicado para manter IDs únicos entre sessões
# Evita criação de novos players a cada abertura do app

# Sinais
signal id_ready(persistent_id: String)
signal sync_completed
signal sync_failed(error: String)

# Configurações
const PERSISTENT_ID_FILE = "user://persistent_id.cfg"
const SYNC_DATA_FILE = "user://sync_cache.json"

# Dados persistentes
var persistent_player_id: String = ""
var device_uuid: String = ""
var firebase_uid: String = ""
var is_first_run: bool = true
var last_sync_timestamp: float = 0.0

# Cache de sincronização
var local_cache: Dictionary = {}
var firebase_cache: Dictionary = {}
var sync_in_progress: bool = false

# Criptografia
var crypto: Crypto = Crypto.new()
var crypto_key: CryptoKey = CryptoKey.new()
var encryption_key: PackedByteArray = "wordmix_secret_key_32_characters".to_utf8_buffer()

# ===== INICIALIZAÇÃO =====

func _ready():
	print("🆔 Inicializando PersistentIDManager...")
	# Inicializa a chave de criptografia
	crypto_key.load_from_string(encryption_key.get_string_from_utf8())
	initialize_persistent_id()
	
	# Aguarda o Global estar pronto antes de sincronizar
	await get_tree().process_frame
	_sync_with_global()

func initialize_persistent_id():
	# 1. Gera ou carrega device UUID primeiro
	generate_or_load_device_uuid()
	
	# 2. Carrega ou gera ID persistente
	load_persistent_id()
	
	# 3. Se não existe, gera novo baseado no device
	if persistent_player_id == "":
		generate_new_persistent_id()
	
	# 4. Emite sinal de ID pronto
	emit_signal("id_ready", persistent_player_id)
	print("✅ ID Persistente pronto: ", persistent_player_id.substr(0, 12) + "...")

# ===== GERAÇÃO E CARREGAMENTO DE ID =====

func generate_new_persistent_id():
	# Gera device UUID se não existe
	if device_uuid == "":
		generate_or_load_device_uuid()
	
	# Gera ID baseado no device UUID para garantir consistência
	var device_hash = device_uuid.md5_text()
	var hash_int = 0
	for i in range(min(8, device_hash.length())):
		var char_code = device_hash.unicode_at(i)
		if char_code >= 48 and char_code <= 57:  # 0-9
			hash_int = hash_int * 16 + (char_code - 48)
		elif char_code >= 65 and char_code <= 70:  # A-F
			hash_int = hash_int * 16 + (char_code - 55)
		elif char_code >= 97 and char_code <= 102:  # a-f
			hash_int = hash_int * 16 + (char_code - 87)
	
	persistent_player_id = "player_" + device_hash.substr(0, 8) + "_" + str(hash_int % 1000000)
	
	# Salva imediatamente
	save_persistent_id()
	print("🆔 Novo ID persistente gerado baseado no device: ", persistent_player_id.substr(0, 12) + "...")

func load_persistent_id():
	if not FileAccess.file_exists(PERSISTENT_ID_FILE):
		print("📂 Arquivo de ID persistente não encontrado")
		return
	
	var file = FileAccess.open(PERSISTENT_ID_FILE, FileAccess.READ)
	if file == null:
		print("❌ Erro ao abrir arquivo de ID persistente")
		return
	
	var encrypted_data = file.get_buffer(file.get_length())
	file.close()
	
	# Descriptografa os dados
	var decrypted_data = crypto.decrypt(crypto_key, encrypted_data)
	if decrypted_data.is_empty():
		print("❌ Erro ao descriptografar ID persistente")
		return
	
	persistent_player_id = decrypted_data.get_string_from_utf8()
	print("📋 ID persistente carregado: ", persistent_player_id.substr(0, 12) + "...")

func save_persistent_id():
	if persistent_player_id == "":
		print("❌ Tentativa de salvar ID vazio")
		return
	
	var file = FileAccess.open(PERSISTENT_ID_FILE, FileAccess.WRITE)
	if file == null:
		print("❌ Erro ao criar arquivo de ID persistente")
		return
	
	# Criptografa os dados
	var data_to_encrypt = persistent_player_id.to_utf8_buffer()
	var encrypted_data = crypto.encrypt(crypto_key, data_to_encrypt)
	
	file.store_buffer(encrypted_data)
	file.close()
	print("💾 ID persistente salvo com segurança")

# ===== MÉTODOS PÚBLICOS =====

func get_persistent_id() -> String:
	return persistent_player_id

func set_persistent_id(new_id: String):
	"""Define um novo ID persistente e salva"""
	if new_id == "":
		print("❌ Tentativa de definir ID vazio")
		return
	
	persistent_player_id = new_id
	save_persistent_id()
	print("✅ ID persistente definido: ", new_id.substr(0, 12) + "...")

# ===== INTEGRAÇÃO COM FIREBASE =====

func _sync_with_global():
	"""Sincroniza com o Global após ambos estarem prontos"""
	# Só define Firebase UID se ainda não temos um ID persistente OU se o Firebase UID é diferente
	if Global.is_online and Global.player_id != "" and Global.player_id != persistent_player_id:
		print("🔄 Firebase UID diferente do ID persistente, sincronizando...")
		set_firebase_uid(Global.player_id)
	elif persistent_player_id != "" and Global.player_id == "":
		# Se temos ID persistente mas Global não tem, usa o nosso
		Global.player_id = persistent_player_id
		print("📋 Usando ID persistente existente no Global: ", persistent_player_id.substr(0, 12) + "...")

func set_firebase_uid(firebase_uid: String):
	if firebase_uid == "":
		print("⚠️ Firebase UID vazio, mantendo ID persistente atual")
		return
	
	if persistent_player_id == "":
		# Se não temos ID persistente, usa o Firebase UID
		persistent_player_id = firebase_uid
		save_persistent_id()
		Global.player_id = persistent_player_id
		print("🔄 ID persistente definido como Firebase UID: ", firebase_uid.substr(0, 12) + "...")
	elif persistent_player_id == firebase_uid:
		# IDs já são iguais, não faz nada
		print("✅ ID persistente já corresponde ao Firebase UID")
		return
	else:
		# IDs são diferentes, precisa verificar qual usar
		print("🔄 Firebase UID diferente do ID persistente, verificando dados...")
		
		# Verifica se o Firebase UID já tem dados
		var uid_has_data = await check_firebase_uid_exists(firebase_uid)
		
		if uid_has_data:
			# Firebase UID tem dados, precisa mesclar ou escolher
			print("📊 Firebase UID tem dados, mantendo ID persistente atual")
			# Mantém o ID persistente atual e atualiza Global se necessário
			if Global.player_id != persistent_player_id:
				Global.player_id = persistent_player_id
		else:
			# Firebase UID não tem dados, pode usar o ID persistente
			print("📝 Firebase UID sem dados, mantendo ID persistente atual")
			Global.player_id = persistent_player_id

func check_firebase_uid_exists(uid: String) -> bool:
	if not Global.firebase_reference:
		print("⚠️ Firebase não disponível, assumindo UID não existe")
		return false
	
	print("🔍 Verificando se Firebase UID existe: ", uid.substr(0, 12) + "...")
	
	var player_ref = Global.firebase_reference.child("players").child(uid)
	var data = await player_ref.get_data()
	
	if data != null and not data.is_empty():
		print("✅ Firebase UID tem dados existentes")
		return true
	else:
		print("📭 Firebase UID não tem dados")
		return false

# ===== GETTERS =====

func get_device_uuid() -> String:
	"""Retorna o UUID do dispositivo"""
	return device_uuid

# ===== GERAÇÃO DE DEVICE UUID =====

func generate_or_load_device_uuid():
	"""Gera ou carrega UUID único do dispositivo"""
	var config = ConfigFile.new()
	var err = config.load(PERSISTENT_ID_FILE)
	
	if err == OK:
		device_uuid = config.get_value("device", "uuid", "")
	
	# Se não existe UUID, gera um novo baseado no dispositivo
	if device_uuid == "":
		device_uuid = generate_device_uuid()
		save_device_uuid()
		print("🆔 Novo Device UUID gerado: ", device_uuid.substr(0, 8) + "...")
	else:
		print("🆔 Device UUID carregado: ", device_uuid.substr(0, 8) + "...")

func generate_device_uuid() -> String:
	"""Gera UUID único baseado em características do dispositivo"""
	# Usa informações do dispositivo para gerar ID consistente
	var device_info = ""
	
	# Tenta usar OS.get_unique_id() se disponível (Android/iOS)
	if OS.has_method("get_unique_id"):
		device_info = OS.get_unique_id()
		if device_info != "":
			print("📱 Usando OS.get_unique_id(): ", device_info.substr(0, 8) + "...")
			return device_info.md5_text().substr(0, 16).to_upper()
	
	# Fallback: combina informações do sistema
	var system_info = []
	system_info.append(OS.get_name())
	system_info.append(str(OS.get_processor_count()))
	system_info.append(OS.get_model_name())
	system_info.append(str(DisplayServer.screen_get_size()))
	
	# Adiciona timestamp apenas na primeira execução
	var timestamp = Time.get_unix_time_from_system()
	system_info.append(str(int(timestamp) % 1000000))  # Últimos 6 dígitos
	
	var combined_info = "_".join(system_info)
	var device_hash = combined_info.md5_text().substr(0, 16).to_upper()
	
	print("🔧 Device UUID gerado via fallback: ", device_hash.substr(0, 8) + "...")
	return device_hash

func save_device_uuid():
	"""Salva o device UUID no arquivo de configuração"""
	var config = ConfigFile.new()
	config.load(PERSISTENT_ID_FILE)  # Carrega existente ou cria novo
	
	config.set_value("device", "uuid", device_uuid)
	config.set_value("device", "created_at", Time.get_unix_time_from_system())
	config.set_value("device", "os_name", OS.get_name())
	
	var save_result = config.save(PERSISTENT_ID_FILE)
	if save_result == OK:
		print("💾 Device UUID salvo com sucesso")
	else:
		print("❌ Erro ao salvar Device UUID: ", save_result)