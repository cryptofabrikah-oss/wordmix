extends Control

const WORD_SIZE: int = 5
const MAX_TRIES: int = 6

enum GameMode { INFINITE }

# Preload das cenas
const TileScene: PackedScene = preload("res://scenes/Tile.tscn")
const EndGameScene: PackedScene = preload("res://scenes/end_game.tscn")

# Nodes
@onready var grid: GridContainer = $Game/Grid
@onready var status_lbl: Label = $Game/Status
@onready var keyboard: Keyboard = $Game/Keyboard
@onready var backbutton: Button = $ButtonPanel/backbutton

# Game state
var answer: String = ""
var row: int = 0
var col: int = 0
var current_guess: String = ""
var words: Array[String] = []
var words_map: Dictionary = {}
var mode: GameMode = GameMode.INFINITE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Character abilities
var max_tries: int = MAX_TRIES
var mage_ability_used: bool = false
var mage_revealed_position: int = -1  # Posição da letra revelada pelo mago

# ---------------------------
# READY
# ---------------------------
func _ready() -> void:
	# Main ready

	# Conectar botão voltar
	backbutton.pressed.connect(_on_backbutton_pressed)
	
	# Aplicar estilo padronizado ao botão de voltar
	_apply_back_button_style()

	# Carregar palavras
	if not _load_words():
		push_error("Nao foi possível carregar palavras. Verifique se words.json está incluído no projeto.")
		_update_status("Erro: words.json não encontrado")
		return

	# Conectar sinais do teclado
	keyboard.letter_pressed.connect(_on_key_letter)
	keyboard.enter_pressed.connect(_on_key_enter)
	keyboard.backspace_pressed.connect(_on_key_backspace)

	# Inicializar jogo
	_apply_character_abilities()
	_build_grid()
	_pick_answer()
	_update_status()
	# Apply mage ability if selected
	if Global.selected_avatar == 1 and not mage_ability_used:
		_reveal_random_letter()
	print("Jogo inicializado com sucesso")

# ---------------------------
# CARREGAR PALAVRAS (JSON)
# ---------------------------
func _load_words() -> bool:
	words_map.clear()
	words.clear()

	var file = FileAccess.open("res://data/words.json", FileAccess.READ)
	if not file:
		push_error("Arquivo words.json não encontrado em res://data/")
		return false

	var content: String = file.get_as_text()
	var json = JSON.parse_string(content)

	if json == null or not (json is Array):
		push_error("Formato inválido em words.json (esperado: Array de palavras).")
		return false

	for raw_word in json:
		if typeof(raw_word) != TYPE_STRING:
			continue
		var word = raw_word.strip_edges().to_upper()
		if word == "":
			continue
		var clean = remove_accents(word)
		words_map[clean] = word
		words.append(word)

	print("Words loaded: %d" % words_map.size())
	return true

# ---------------------------
# REMOVE ACENTOS
# ---------------------------
func remove_accents(text: String) -> String:
	var replacements = {
		"Á":"A","À":"A","Â":"A","Ã":"A",
		"É":"E","È":"E","Ê":"E",
		"Í":"I","Ì":"I","Î":"I",
		"Ó":"O","Ò":"O","Ô":"O","Õ":"O",
		"Ú":"U","Ù":"U","Û":"U",
		"Ç":"C"
	}
	var result: String = text
	for accented in replacements.keys():
		result = result.replace(accented, replacements[accented])
	return result

# ---------------------------
# GRID
# ---------------------------
func _build_grid() -> void:
	_clear_children(grid)
	grid.columns = WORD_SIZE
	for r in range(max_tries):
		for c in range(WORD_SIZE):
			var tile: Tile = TileScene.instantiate() as Tile
			tile.name = "Tile_%d_%d" % [r, c]
			# Aplicar feedback visual para linha extra do arqueiro
			if Global.selected_avatar == 2 and r == (max_tries - 1):  # Arqueiro e última linha (linha extra)
				tile.set_archer_extra_row(true)
			grid.add_child(tile)
	print("Grid built: %d tiles" % (max_tries*WORD_SIZE))

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

# ---------------------------
# NOVO JOGO
# ---------------------------
func _new_game() -> void:
	row = 0
	col = 0
	current_guess = ""
	# Reset character abilities
	mage_ability_used = false
	mage_revealed_position = -1
	_apply_character_abilities()
	for i in range(max_tries * WORD_SIZE):
		var tile: Tile = grid.get_child(i) as Tile
		tile.set_letter("")
		tile.set_state("empty")
	keyboard.reset_states()
	_pick_answer()
	_update_status()
	# Apply mage ability if selected
	if Global.selected_avatar == 1 and not mage_ability_used:
		_reveal_random_letter()
	print("New game started")

# ---------------------------
# ESCOLHER PALAVRA
# ---------------------------
func _pick_answer() -> void:
	if words_map.size() == 0:
		push_error("words_map vazio! Nenhuma palavra para escolher.")
		answer = "ERROR"
		return
	rng.randomize()
	var keys = words_map.keys()
	answer = keys[rng.randi_range(0, keys.size() - 1)]
	print("Answer picked: %s" % answer)

# ---------------------------
# ATUALIZAR STATUS
# ---------------------------
func _update_status(text: String = "") -> void:
	status_lbl.text = text if text != "" else "Adivinhe a palavra de 5 letras"
	print("Status updated: %s" % status_lbl.text)

# ---------------------------
# TECLADO
# ---------------------------
func _on_key_letter(ch: String) -> void:
	if row >= MAX_TRIES or col >= WORD_SIZE:
		return
	
	# Se estamos na posição revelada pelo mago, pula automaticamente
	if row == 0 and col == mage_revealed_position and mage_revealed_position != -1:
		col += 1
		if col >= WORD_SIZE:
			return
	
	current_guess += ch
	var idx: int = row * WORD_SIZE + col
	if idx >= grid.get_child_count():
		push_error("Tile index %d fora do grid" % idx)
		return
	var tile: Tile = grid.get_child(idx) as Tile
	tile.set_letter(ch)
	col += 1
	print("Letter pressed: %s" % ch)

func _on_key_backspace() -> void:
	if col <= 0:
		return
	
	# Se estamos na primeira linha e a próxima posição é a revelada pelo mago, pula ela
	if row == 0 and col - 1 == mage_revealed_position and mage_revealed_position != -1:
		col -= 1
		if col <= 0:
			return
	
	col -= 1
	current_guess = current_guess.substr(0, col)
	var idx: int = row * WORD_SIZE + col
	if idx >= grid.get_child_count():
		return
	var tile: Tile = grid.get_child(idx) as Tile
	tile.set_letter("")
	print("Backspace pressed")

func _on_key_enter() -> void:
	if col < WORD_SIZE:
		_flash_status("Palavra incompleta.")
		return

	# Constrói a palavra completa incluindo a letra revelada pelo mago
	var complete_guess: String = ""
	for i in range(WORD_SIZE):
		if row == 0 and i == mage_revealed_position and mage_revealed_position != -1:
			# Usa a letra revelada pelo mago
			complete_guess += answer[i]
		else:
			# Usa a letra digitada pelo jogador
			var tile_idx = row * WORD_SIZE + i
			var tile: Tile = grid.get_child(tile_idx) as Tile
			complete_guess += tile.get_letter()
	
	var guess: String = complete_guess.to_upper()
	if not words_map.has(guess):
		_flash_status("Palavra nao existe.")
		return

	_reveal_guess(words_map.get(guess))
	current_guess = ""
	col = 0

	var gold_this_round: int = 0
	var points_this_round: int = 0
	var status_text: String = "" 
	if guess == answer:
		var TRIE = max_tries - row
		points_this_round = 5 * TRIE
		gold_this_round = 10 * TRIE
		# Apply character bonuses
		points_this_round = _apply_character_bonus_points(points_this_round)
		gold_this_round = _apply_character_bonus_gold(gold_this_round)
		status_text = "Voce ganhou"
		_update_status("Parabéns! Você acertou.")
		_lock_input(points_this_round, gold_this_round, status_text)
		return

	row += 1
	if row >= max_tries:
		points_this_round = 5
		gold_this_round = 1
		# Apply character bonuses even on failure
		points_this_round = _apply_character_bonus_points(points_this_round)
		gold_this_round = _apply_character_bonus_gold(gold_this_round)
		status_text = "Voce falhou"
		_update_status("Fim de jogo. A palavra era: %s" % answer)
		_lock_input(points_this_round, gold_this_round, status_text)

# ---------------------------
# LOCK INPUT E END GAME
# ---------------------------
func _lock_input(points_this_round: int, gold_this_round: int, status_text: String) -> void:
	Global.add_points(points_this_round)
	Global.add_gold(gold_this_round)
	
	# Atualiza o ranking semanal com a nova pontuação
	Global.add_to_weekly_ranking()
	
	# Reseta as habilidades para a próxima partida
	Global.reset_abilities()

	var end_scene: Control = EndGameScene.instantiate()
	end_scene.status_end = status_text 
	end_scene.points_earned = points_this_round
	end_scene.gold_earned = gold_this_round
	

	get_tree().root.add_child(end_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = end_scene
	print("End game scene loaded")

# ---------------------------
# REVELAR PALAVRA
# ---------------------------
func _reveal_guess(guess: String) -> void:
	var freq: Dictionary = {}
	for i in range(WORD_SIZE):
		var ch: String = answer[i]
		freq[ch] = int(freq.get(ch, 0)) + 1

	var states: Array = []
	for i in range(WORD_SIZE):
		var ch: String = guess[i]
		if ch == answer[i]:
			states.append("correct")
			freq[ch] -= 1
		else:
			states.append("pending")

	for i in range(WORD_SIZE):
		if states[i] == "pending":
			var ch: String = guess[i]
			if int(freq.get(ch, 0)) > 0:
				states[i] = "present"
				freq[ch] -= 1
			else:
				states[i] = "absent"

	for i in range(WORD_SIZE):
		var idx: int = row * WORD_SIZE + i
		if idx >= grid.get_child_count():
			continue
		var tile: Tile = grid.get_child(idx) as Tile
		tile.set_letter(guess[i])
		tile.set_state(states[i])
		keyboard.set_letter_state(guess[i], states[i])
	print("Guess revealed: %s" % guess)

# ---------------------------
# FLASH STATUS
# ---------------------------
func _flash_status(t: String) -> void:
	status_lbl.text = t
	status_lbl.modulate = Color(1, 0.7, 0.7, 1)
	await get_tree().create_timer(0.35).timeout
	status_lbl.modulate = Color(1, 1, 1, 1)

# ---------------------------
# BOTAO VOLTAR
# ---------------------------
func _on_backbutton_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Start.tscn")
	print("Back button pressed")

# ---------------------------
# CHARACTER ABILITIES
# ---------------------------
func _apply_character_abilities() -> void:
	# Reset to default values
	max_tries = MAX_TRIES
	
	# Apply archer ability (extra attempt)
	if Global.selected_avatar == 2:  # Arqueiro
		max_tries = MAX_TRIES + 1
		# Archer ability: Extra attempt granted

func _apply_character_bonus_points(base_points: int) -> int:
	# Guerreiro ganha mais pontos
	if Global.selected_avatar == 4:  # Guerreiro
		return int(base_points * 1.5)  # 50% mais pontos
	return base_points

func _apply_character_bonus_gold(base_gold: int) -> int:
	# Mercador ganha mais gold
	if Global.selected_avatar == 3:  # Mercador
		return int(base_gold * 2.0)  # 100% mais gold
	return base_gold

func _reveal_random_letter() -> void:
	# Mago revela uma letra aleatória da palavra
	if answer == "" or mage_ability_used:
		return
	
	rng.randomize()
	var random_pos = rng.randi_range(0, WORD_SIZE - 1)
	var letter_to_reveal = answer[random_pos]
	
	# Armazena a posição revelada
	mage_revealed_position = random_pos
	
	# Encontra um tile vazio na primeira linha para mostrar a dica
	var hint_tile: Tile = grid.get_child(random_pos) as Tile
	hint_tile.set_letter(letter_to_reveal)
	hint_tile.set_state("correct")
	
	mage_ability_used = true
	_update_status("Dica do Mago: A letra '%s' está na posição %d!" % [letter_to_reveal, random_pos + 1])
	print("Mage ability: Revealed letter %s at position %d" % [letter_to_reveal, random_pos])

func _apply_back_button_style():
	# Estilo padronizado do botão de voltar (igual ao ranking)
	var back_style = StyleBoxFlat.new()
	back_style.bg_color = Color.hex(0x100101FF)      # fundo vermelho quase preto
	back_style.border_color = Color(1, 0.84, 0)   # borda dourada
	back_style.set_border_width_all(5)
	back_style.set_corner_radius_all(10)

	# Aplica ao botão em todos os estados
	backbutton.add_theme_stylebox_override("normal", back_style)
	backbutton.add_theme_stylebox_override("hover", back_style)
	backbutton.add_theme_stylebox_override("pressed", back_style)
	backbutton.add_theme_stylebox_override("disabled", back_style)
