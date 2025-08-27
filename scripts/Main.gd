extends Control

const WORD_SIZE: int = 5
const MAX_TRIES: int = 6

enum GameMode { INFINITE }

@onready var grid: GridContainer = $VBox/Grid
@onready var status_lbl: Label = $VBox/Status
@onready var keyboard: Node = $VBox/Keyboard
@onready var backbutton: Button = $ButtonPanel/backbutton

var answer: String = ""
var row: int = 0
var col: int = 0
var current_guess: String = ""
var words: PackedStringArray
var words_map: Dictionary
var mode: GameMode = GameMode.INFINITE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	backbutton.pressed.connect(_on_backbutton_pressed)

	# Load words
	var f: FileAccess = FileAccess.open("res://data/words.txt", FileAccess.READ)
	var content: String = f.get_as_text()
	words = PackedStringArray()
	words_map = {}
	for line in content.strip_edges(true, true).split("\n"):
		var word : String = line.strip_edges().to_upper()
		var clean: String = remove_accents(word)            
		words_map[clean] = word

	# UI hooks
	keyboard.letter_pressed.connect(_on_key_letter)
	keyboard.enter_pressed.connect(_on_key_enter)
	keyboard.backspace_pressed.connect(_on_key_backspace)

	# Init
	_build_grid()
	_pick_answer()
	_update_status()

func remove_accents(text: String) -> String:
	var replacements = {
		"Á": "A", "À": "A", "Â": "A", "Ã": "A",
		"É": "E", "È": "E", "Ê": "E",
		"Í": "I", "Ì": "I", "Î": "I",
		"Ó": "O", "Ò": "O", "Ô": "O", "Õ": "O",
		"Ú": "U", "Ù": "U", "Û": "U",
		"Ç": "C"
	}
	var result: String = text
	for accented in replacements.keys():
		result = result.replace(accented, replacements[accented])
	return result

func _build_grid() -> void:
	_clear_children(grid)
	grid.columns = WORD_SIZE
	for r in range(MAX_TRIES):
		for c in range(WORD_SIZE):
			var tile: Control = load("res://scenes/Tile.tscn").instantiate() as Control
			grid.add_child(tile)

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _new_game() -> void:
	row = 0
	col = 0
	current_guess = ""
	for i in range(MAX_TRIES * WORD_SIZE):
		var tile: Node = grid.get_child(i)
		tile.set_letter("")
		tile.set_state("empty")
	keyboard.reset_states()
	_pick_answer()
	_update_status()

func _pick_answer() -> void:
	rng.randomize()
	answer = words_map.keys()[rng.randi_range(0, words_map.keys().size() - 1)]

func _update_status(text: String = "") -> void:
	if text == "":
		status_lbl.text = "Adivinhe a palavra de 5 letras"
	else:
		status_lbl.text = text

func _on_key_letter(ch: String) -> void:
	if row >= MAX_TRIES or col >= WORD_SIZE:
		return
	current_guess += ch
	var idx: int = row * WORD_SIZE + col
	var tile: Node = grid.get_child(idx)
	tile.set_letter(ch)
	col += 1

func _on_key_backspace() -> void:
	if col <= 0:
		return
	col -= 1
	current_guess = current_guess.substr(0, col)
	var idx: int = row * WORD_SIZE + col
	var tile: Node = grid.get_child(idx)
	tile.set_letter("")

func _on_key_enter() -> void:
	if col < WORD_SIZE:
		_flash_status("Palavra incompleta.")
		return

	var guess: String = current_guess.to_upper()
	if not words_map.keys().has(guess):
		_flash_status("Palavra nao existe.")
		return

	_reveal_guess(words_map.get(guess))
	current_guess = ""
	col = 0

	var gold_this_round: int = 0
	var points_this_round: int = 0

	if guess == answer:
		var TRIE = 6 - row
		points_this_round = 5 * TRIE
		gold_this_round = 10 * TRIE
		_update_status("Parabens! Voce acertou.")
		_lock_input(points_this_round, gold_this_round)
		return

	row += 1
	if row >= MAX_TRIES:
		points_this_round = 5  # pontos de consolação
		gold_this_round = 10    # gold de consolação
		_update_status("Fim de jogo. A palavra era: %s" % answer)
		_lock_input(points_this_round, gold_this_round)

func _lock_input(points_this_round: int, gold_this_round: int) -> void:
	# Atualiza os valores globais
	Global.add_points(points_this_round)
	Global.add_gold(gold_this_round)

	# Cria e passa os valores para o end_game
	var end_scene: Control = load("res://scenes/end_game.tscn").instantiate()
	end_scene.points_earned = points_this_round
	end_scene.gold_earned = gold_this_round

	get_tree().root.add_child(end_scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = end_scene

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
			freq[ch] = int(freq.get(ch, 0)) - 1
		else:
			states.append("pending")

	for i in range(WORD_SIZE):
		if states[i] == "pending":
			var ch: String = guess[i]
			if int(freq.get(ch, 0)) > 0:
				states[i] = "present"
				freq[ch] = int(freq.get(ch, 0)) - 1
			else:
				states[i] = "absent"

	for i in range(WORD_SIZE):
		var idx: int = row * WORD_SIZE + i
		var tile: Node = grid.get_child(idx)
		tile.set_letter(guess[i])
		tile.set_state(states[i])
		keyboard.set_letter_state(guess[i], states[i])

func _flash_status(t: String) -> void:
	status_lbl.text = t
	status_lbl.modulate = Color(1, 0.7, 0.7, 1)
	await get_tree().create_timer(0.35).timeout
	status_lbl.modulate = Color(1, 1, 1, 1)

func _on_backbutton_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Start.tscn")
