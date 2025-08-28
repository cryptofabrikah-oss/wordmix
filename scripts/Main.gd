extends Control

const WORD_SIZE: int = 5
const MAX_TRIES: int = 6

enum GameMode { INFINITE }

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
var words: PackedStringArray
var words_map: Dictionary
var mode: GameMode = GameMode.INFINITE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Conectar botão voltar
	backbutton.pressed.connect(_on_backbutton_pressed)

	# Carregar palavras
	var f: FileAccess = FileAccess.open("res://data/words.txt", FileAccess.READ)
	if not f:
		push_error("Arquivo words.txt não encontrado!")
		return
	var content: String = f.get_as_text()
	words = PackedStringArray()
	words_map = {}
	for line in content.strip_edges(true, true).split("\n"):
		var word: String = line.strip_edges().to_upper()
		var clean: String = remove_accents(word)
		words_map[clean] = word

	# Conectar sinais do teclado
	keyboard.letter_pressed.connect(_on_key_letter)
	keyboard.enter_pressed.connect(_on_key_enter)
	keyboard.backspace_pressed.connect(_on_key_backspace)

	# Inicializar jogo
	_build_grid()
	_pick_answer()
	_update_status()

# Remove acentos de uma palavra
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

# Construir grid de tiles
func _build_grid() -> void:
	_clear_children(grid)
	grid.columns = WORD_SIZE
	for r in range(MAX_TRIES):
		for c in range(WORD_SIZE):
			var tile: Tile = load("res://scenes/Tile.tscn").instantiate() as Tile
			grid.add_child(tile)

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

# Resetar jogo
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

# Escolher palavra aleatória
func _pick_answer() -> void:
	rng.randomize()
	var keys = words_map.keys()
	answer = keys[rng.randi_range(0, keys.size() - 1)]

func _update_status(text: String = "") -> void:
	status_lbl.text = text if text != "" else "Adivinhe a palavra de 5 letras"

# Sinal do teclado: letra pressionada
func _on_key_letter(ch: String) -> void:
	if row >= MAX_TRIES or col >= WORD_SIZE:
		return
	current_guess += ch
	var idx: int = row * WORD_SIZE + col
	var tile: Tile = grid.get_child(idx) as Tile
	tile.set_letter(ch)
	col += 1

# Sinal do teclado: backspace
func _on_key_backspace() -> void:
	if col <= 0:
		return
	col -= 1
	current_guess = current_guess.substr(0, col)
	var idx: int = row * WORD_SIZE + col
	var tile: Tile = grid.get_child(idx) as Tile
	tile.set_letter("")

# Sinal do teclado: enter
func _on_key_enter() -> void:
	if col < WORD_SIZE:
		_flash_status("Palavra incompleta.")
		return

	var guess: String = current_guess.to_upper()
	if not words_map.keys().has(guess):
		_flash_status("Palavra não existe.")
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

# Trava inputs e abre tela de fim de jogo
func _lock_input(points_this_round: int, gold_this_round: int) -> void:
	Global.add_points(points_this_round)
	Global.add_gold(gold_this_round)

	var end_scene: Control = load("res://scenes/end_game.tscn").instantiate()
	end_scene.points_earned = points_this_round
	end_scene.gold_earned = gold_this_round

	get_tree().root.add_child(end_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = end_scene

# Revela a palavra digitada
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
		var tile: Tile = grid.get_child(idx) as Tile
		tile.set_letter(guess[i])
		tile.set_state(states[i])
		keyboard.set_letter_state(guess[i], states[i])

# Flash de status
func _flash_status(t: String) -> void:
	status_lbl.text = t
	status_lbl.modulate = Color(1, 0.7, 0.7, 1)
	await get_tree().create_timer(0.35).timeout
	status_lbl.modulate = Color(1, 1, 1, 1)

func _on_backbutton_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Start.tscn")
