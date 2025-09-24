extends Node

# ===== SINAIS =====
signal player_data_updated

# ===== DADOS DO JOGADOR =====
var gold: int = 0
var crystal: int = 0
var level: int = 1
var correct_answers: int = 0  # Contador de acertos para progressão de nível
var player_name: String = "Jogador"
var player_id: String = ""
var player_data_loaded: bool = false

# ===== SISTEMA DE NÍVEIS E PALAVRAS =====
var words_frequency_levels: Dictionary = {}
var words_loaded: bool = false

# ===== SISTEMA DE CACHE =====
var cache_manager: Node

# ===== SISTEMA DE AVATARES =====
var selected_avatar = 0
var selected_avatar_index = 0
var unlocked_characters: Array[int] = [0]  # Apenas Aprendiz desbloqueado inicialmente
var avatar_names = ["Aprendiz", "Mago", "Arqueiro", "Mercador", "Guerreiro"]
var avatar_textures = [
	"res://assets/avatar1.svg",
	"res://assets/avatar2.svg",
	"res://assets/avatar3.svg",
	"res://assets/avatar4.svg",
	"res://assets/avatar5.svg"
]

# Configurações de personagem
var character_bonuses = {
	0: "default",        # Sem bônus especial
	1: "gold_bonus",     # Aprendiz - ganha mais gold
	2: "crystal_bonus",  # Mago - ganha mais cristais
	3: "gold_bonus",     # Mercador - ganha mais gold
	4: "default"         # Guerreiro - removido bonus_points
}

# Multiplicadores de bônus
var ability_used_this_round = false
var extra_attempts = 0
var gold_multiplier = 1.0
var crystal_multiplier = 1.0

# ===== SISTEMA DE PERSISTÊNCIA =====

# ===== INICIALIZAÇÃO =====
func _ready():
	print("🎮 Iniciando sistema de persistência local...")
	
	# Inicializa sistema de cache
	_initialize_cache_manager()
	
	# Carrega dados locais
	load_local_data()
	
	# Carrega sistema de palavras por frequência
	_load_words_frequency_levels()
	
	# Garante um UID persistente por dispositivo
	_ensure_persistent_uid()
	
	# Marca dados como carregados
	player_data_loaded = true
	
	print("✅ Sistema inicializado com sucesso")
	print("   • Nome: ", player_name)
	print("   • Nível: ", level)
	print("   • Acertos: ", correct_answers)
	print("   • UID: ", player_id if not player_id.is_empty() else "vazio")

# ===== FUNÇÕES DE HABILIDADES =====
func use_character_ability(character_id: int) -> bool:
	if ability_used_this_round:
		return false
	
	match character_id:
		1: return _use_mage_ability()
		2: return _use_archer_ability()
		3: return _use_merchant_ability()
		4: return _use_warrior_ability()
		_: return false

func _use_mage_ability() -> bool:
	ability_used_this_round = true
	return true

func _use_archer_ability() -> bool:
	extra_attempts += 1
	ability_used_this_round = true
	return true

func _use_merchant_ability() -> bool:
	gold_multiplier = 2.0
	ability_used_this_round = true
	return true

func _use_warrior_ability() -> bool:
	ability_used_this_round = true
	return true

func reset_abilities():
	ability_used_this_round = false
	extra_attempts = 0
	gold_multiplier = 1.0

# ===== FUNÇÕES DE DADOS DO JOGADOR =====
func add_gold(amount: int) -> void:
	gold += amount
	print("💰 Gold adicionado: +%d (Total: %d)" % [amount, gold])
	save_local_data()

func add_crystal(amount: int) -> void:
	crystal += amount
	print("💎 Cristais adicionados: +%d (Total: %d)" % [amount, crystal])
	save_local_data()

# ===== SISTEMA DE PROGRESSÃO DE NÍVEL =====
func add_correct_answer() -> void:
	correct_answers += 1
	var new_level = correct_answers + 1
	if new_level != level:
		level = new_level
		print("🎉 Nível aumentou para: ", level)
	save_local_data()

func get_current_level() -> int:
	return level

func get_correct_answers() -> int:
	return correct_answers

func unlock_character(character_id: int) -> void:
	if not unlocked_characters.has(character_id):
		unlocked_characters.append(character_id)
		print("Personagem %s desbloqueado!" % avatar_names[character_id])
		save_local_data()

func is_character_unlocked(character_id: int) -> bool:
	return unlocked_characters.has(character_id)

# ===== SISTEMA DE CACHE =====
func _initialize_cache_manager():
	print("🗄️ Inicializando CacheManager...")
	
	cache_manager = preload("res://scripts/CacheManager.gd").new()
	add_child(cache_manager)
	
	# Conecta sinais do cache
	cache_manager.cache_updated.connect(_on_cache_updated)
	cache_manager.cache_error.connect(_on_cache_error)
	
	print("✅ CacheManager inicializado")

func _on_cache_updated(data: Dictionary):
	print("🔄 Cache atualizado")

func _on_cache_error(error_message: String):
	print("❌ Erro no cache: " + error_message)

# ===== SISTEMA DE PERSISTÊNCIA =====
func _ensure_persistent_uid():
	var config_file := ConfigFile.new()
	var err := config_file.load("user://player_config.cfg")
	if err != OK:
		print("📁 Criando arquivo de config (primeira execução)")
	
	# Gera ou recupera UID
	var saved_uid: String = config_file.get_value("player", "id", "")
	if saved_uid.is_empty():
		saved_uid = _generate_persistent_uid()
		player_id = saved_uid
		config_file.set_value("player", "id", player_id)
		config_file.save("user://player_config.cfg")
		print("🆔 UID gerado: ", saved_uid)
	else:
		player_id = saved_uid
		print("🆔 UID recuperado: ", player_id)

func _generate_persistent_uid() -> String:
	var base := ""
	if OS.has_method("get_unique_id"):
		base = OS.get_unique_id()
	if base == null or base == "":
		base = OS.get_model_name() + ":" + str(Time.get_unix_time_from_system())
	return "WM-" + str(hash(base)).replace("-", "")

func is_first_run() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	if err != OK:
		print("📁 Primeira execução: arquivo não encontrado")
		return true
	
	var first_run = config.get_value("player", "first_run", true)
	print("📊 Primeira execução: ", first_run)
	return first_run

# ===== SISTEMA DE SALVAMENTO/CARREGAMENTO =====
func save_local_data():
	return save_local_data_robust()

func load_local_data():
	return load_local_data_robust()

func save_local_data_robust():
	print("💾 Salvando dados...")
	
	# Salva no cache manager
	if cache_manager:
		cache_manager.sync_from_global()
		cache_manager.save_cache()
	
	var config = ConfigFile.new()
	
	# Prepara dados para salvamento
	var save_data = {
		"name": player_name,
		"id": player_id,
		"gold": gold,
		"crystal": crystal,
		"level": level,
		"correct_answers": correct_answers,
		"avatar_index": selected_avatar,
		"first_run": false,
		"last_updated": Time.get_unix_time_from_system(),
		"unlocked_characters": unlocked_characters,
		"data_version": "2.1"
	}
	
	# Valida e salva dados
	if not _validate_save_data(save_data):
		print("❌ Dados inválidos - salvamento cancelado")
		return false
	
	for key in save_data.keys():
		config.set_value("player", key, save_data[key])
	
	var save_err = config.save("user://player_config.cfg")
	if save_err != OK:
		print("❌ Erro ao salvar: ", save_err)
		return false
	
	print("✅ Dados salvos com sucesso")
	return true

func load_local_data_robust():
	print("📂 Carregando dados...")
	
	# Tenta carregar do cache primeiro
	var cache_loaded = false
	if cache_manager:
		cache_loaded = cache_manager.load_cache()
		if cache_loaded:
			cache_manager.sync_to_global()
			print("✅ Dados carregados do cache")
			print("   - Gold carregado: %d" % gold)
			print("   - Level carregado: %d" % level)
	
	var config = ConfigFile.new()
	var err = config.load("user://player_config.cfg")
	
	if err != OK:
		if not cache_loaded:
			print("❌ Arquivo não encontrado - inicializando dados padrão")
			_initialize_default_data()
			return false
		else:
			print("✅ Usando dados do cache")
			player_data_loaded = true
			emit_signal("player_data_updated")
			return true
	
	# Carrega dados do arquivo
	var loaded_data = {
		"name": config.get_value("player", "name", "Jogador"),
		"id": config.get_value("player", "id", ""),
		"gold": config.get_value("player", "gold", 100),  # Valor padrão 100 em vez de 0
		"crystal": config.get_value("player", "crystal", 0),
		"level": config.get_value("player", "level", 1),
		"correct_answers": config.get_value("player", "correct_answers", 0),
		"avatar_index": config.get_value("player", "avatar_index", 0),
		"unlocked_characters": config.get_value("player", "unlocked_characters", [0])
	}
	
	print("📊 Dados carregados do arquivo:")
	print("   - Gold: %d" % loaded_data["gold"])
	print("   - Level: %d" % loaded_data["level"])
	print("   - Nome: %s" % loaded_data["name"])
	
	# Valida e aplica dados
	if not _validate_loaded_data(loaded_data):
		if not cache_loaded:
			print("❌ Dados inválidos - inicializando padrão")
			_initialize_default_data()
			return false
		else:
			print("⚠️ Dados inválidos, mantendo cache")
			player_data_loaded = true
			emit_signal("player_data_updated")
			return true
	
	_apply_loaded_data(loaded_data)
	
	# Sincroniza com cache
	if cache_manager:
		cache_manager.sync_from_global()
	
	print("✅ Dados carregados: ", player_name)
	print("   - Gold final: %d" % gold)
	print("   - Level final: %d" % level)
	player_data_loaded = true
	emit_signal("player_data_updated")
	return true

# ===== FUNÇÕES DE VALIDAÇÃO =====
func _validate_save_data(data: Dictionary) -> bool:
	var required_fields = ["name", "id", "gold", "crystal", "level"]
	for field in required_fields:
		if not data.has(field):
			print("❌ Campo ausente: ", field)
			return false
	
	if typeof(data["name"]) != TYPE_STRING or data["name"].length() < 2:
		print("❌ Nome inválido")
		return false
	
	if typeof(data["gold"]) != TYPE_INT or data["gold"] < 0:
		print("❌ Gold inválido")
		return false
	
	if typeof(data["level"]) != TYPE_INT or data["level"] < 1:
		print("❌ Level inválido")
		return false
	
	return true

func _validate_loaded_data(data: Dictionary) -> bool:
	return _validate_save_data(data)

func _apply_loaded_data(data: Dictionary):
	player_name = data["name"]
	player_id = data["id"]
	gold = data["gold"]
	crystal = data["crystal"]
	level = data["level"]
	correct_answers = data.get("correct_answers", 0)  # Compatibilidade com versões antigas
	selected_avatar_index = data["avatar_index"]
	selected_avatar = selected_avatar_index
	unlocked_characters = data["unlocked_characters"]

func _initialize_default_data():
	print("🆕 Inicializando dados padrão...")
	# Só inicializa se os dados realmente estão vazios/padrão
	if player_name.is_empty() or player_name == "Jogador":
		player_name = "Jogador"
	if player_id.is_empty():
		player_id = ""
	if gold == 0:
		gold = 100  # Valor padrão inicial
	if crystal == 0:
		crystal = 0
	if level == 0:
		level = 1
	if correct_answers == 0:
		correct_answers = 0
	if selected_avatar_index == 0:
		selected_avatar_index = 0
	if selected_avatar == 0:
		selected_avatar = 0
	if unlocked_characters.is_empty():
		unlocked_characters = [0]
	
	player_data_loaded = true
	emit_signal("player_data_updated")
	print("✅ Dados padrão inicializados - Gold: %d, Level: %d" % [gold, level])

# ===== FUNÇÕES UTILITÁRIAS =====
func check_username_exists(username: String, callback: Callable):
	# Verifica apenas localmente
	var config = ConfigFile.new()
	var err = config.load("user://local_users.dat")
	
	var username_exists = false
	if err == OK:
		var users = config.get_value("users", "registered_users", {})
		for user_id in users.keys():
			var user_data = users[user_id]
			if user_data.has("name") and user_data["name"].to_lower() == username.to_lower():
				username_exists = true
				break
	
	callback.call(username_exists)

# ===== SISTEMA DE PALAVRAS POR FREQUÊNCIA =====

# Calcula a dificuldade baseada no nível do jogador
# Níveis 1-10: Dificuldade 1, 11-20: Dificuldade 2, etc.
func get_difficulty_for_level(player_level: int) -> int:
	return ((player_level - 1) / 10) + 1

func _load_words_frequency_levels() -> void:
	print("📚 Carregando sistema de palavras por frequência...")
	
	var file = FileAccess.open("res://words_frequency_levels.json", FileAccess.READ)
	if not file:
		print("❌ Arquivo words_frequency_levels.json não encontrado")
		words_loaded = false
		return
	
	var content: String = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(content)
	if json == null or not (json is Dictionary):
		print("❌ Formato inválido em words_frequency_levels.json")
		words_loaded = false
		return
	
	words_frequency_levels = json
	words_loaded = true
	print("✅ Sistema de palavras carregado: %d níveis de frequência" % words_frequency_levels.size())

func get_words_for_level(player_level: int) -> Array[String]:
	if not words_loaded:
		print("❌ Sistema de palavras não carregado")
		return []
	
	# Calcula a dificuldade baseada no sistema escalonado (1-10: dif.1, 11-20: dif.2, etc.)
	var difficulty = get_difficulty_for_level(player_level)
	
	var available_words: Array[String] = []
	
	# Sistema de progressão escalonada de dificuldade
	# Dificuldade 1 (níveis 1-10): Apenas palavras muito fáceis (níveis 1-2)
	# Dificuldade 2 (níveis 11-20): Palavras fáceis a médias (níveis 1-4)
	# Dificuldade 3 (níveis 21-30): Palavras fáceis a difíceis (níveis 1-6)
	# Dificuldade 4+ (níveis 31+): Todas as palavras, com foco crescente nas mais difíceis
	
	if difficulty == 1:
		# Dificuldade 1: Apenas palavras muito frequentes (mais fáceis)
		for freq_level in range(1, min(3, words_frequency_levels.size() + 1)):
			if words_frequency_levels.has(str(freq_level)):
				available_words.append_array(words_frequency_levels[str(freq_level)]["words"])
	elif difficulty == 2:
		# Dificuldade 2: Palavras fáceis a médias
		for freq_level in range(1, min(5, words_frequency_levels.size() + 1)):
			if words_frequency_levels.has(str(freq_level)):
				available_words.append_array(words_frequency_levels[str(freq_level)]["words"])
	elif difficulty == 3:
		# Dificuldade 3: Palavras fáceis a difíceis
		for freq_level in range(1, min(7, words_frequency_levels.size() + 1)):
			if words_frequency_levels.has(str(freq_level)):
				available_words.append_array(words_frequency_levels[str(freq_level)]["words"])
	else:
		# Dificuldade 4+: Todas as palavras, com peso crescente para as mais difíceis
		var max_freq_level = min(difficulty + 6, words_frequency_levels.size())
		for freq_level in range(1, max_freq_level + 1):
			if words_frequency_levels.has(str(freq_level)):
				var words_to_add = words_frequency_levels[str(freq_level)]["words"]
				# Adiciona palavras mais difíceis com maior frequência em dificuldades altas
				if freq_level > 6:
					var repeat_count = min(difficulty - 3, 3)  # Repete até 3 vezes para aumentar chance
					for i in range(repeat_count):
						available_words.append_array(words_to_add)
				else:
					available_words.append_array(words_to_add)
	
	print("🎯 Nível %d (Dificuldade %d): %d palavras disponíveis" % [player_level, difficulty, available_words.size()])
	return available_words

func get_random_word_for_level(player_level: int) -> String:
	var available_words = get_words_for_level(player_level)
	if available_words.is_empty():
		print("❌ Nenhuma palavra disponível para o nível %d" % player_level)
		return ""
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var selected_word = available_words[rng.randi_range(0, available_words.size() - 1)]
	
	print("🎲 Palavra selecionada para nível %d: %s" % [player_level, selected_word])
	return selected_word
