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

# ---------------------------
# READY
# ---------------------------
func _ready() -> void:
	print("Main ready")  # Debug inicial

	# Conectar botão voltar
	backbutton.pressed.connect(_on_backbutton_pressed)

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
	_build_grid()
	_pick_answer()
	_update_status()
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
	for r in range(MAX_TRIES):
		for c in range(WORD_SIZE):
			var tile: Tile = TileScene.instantiate() as Tile
			tile.name = "Tile_%d_%d" % [r, c]
			grid.add_child(tile)
	print("Grid built: %d tiles" % (MAX_TRIES*WORD_SIZE))

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
	for i in range(MAX_TRIES * WORD_SIZE):
		var tile: Tile = grid.get_child(i) as Tile
		tile.set_letter("")
		tile.set_state("empty")
	keyboard.reset_states()
	_pick_answer()
	_update_status()
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

	var guess: String = current_guess.to_upper()
	if not words_map.has(guess):
		_flash_status("Palavra nao existe.")
		return

	_reveal_guess(words_map.get(guess))
	current_guess = ""
	col = 0

	var gold_this_round: int = 0
	var points_this_round: int = 0

	if guess == answer:
		var TRIE = MAX_TRIES - row
		points_this_round = 5 * TRIE
		gold_this_round = 10 * TRIE
		_update_status("Parabéns! Você acertou.")
		_lock_input(points_this_round, gold_this_round)
		return

	row += 1
	if row >= MAX_TRIES:
		points_this_round = 5
		gold_this_round = 10
		_update_status("Fim de jogo. A palavra era: %s" % answer)
		_lock_input(points_this_round, gold_this_round)

# ---------------------------
# LOCK INPUT E END GAME
# ---------------------------
func _lock_input(points_this_round: int, gold_this_round: int) -> void:
	Global.add_points(points_this_round)
	Global.add_gold(gold_this_round)

	var end_scene: Control = EndGameScene.instantiate()
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
# BOTÃO VOLTAR
# ---------------------------
func _on_backbutton_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Start.tscn")
	print("Back button pressed")
