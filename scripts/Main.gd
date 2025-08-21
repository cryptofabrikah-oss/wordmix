extends Control

const WORD_SIZE: int = 5
const MAX_TRIES: int = 6

enum GameMode { DAILY, INFINITE }

@onready var grid: GridContainer = $VBox/Grid
@onready var status_lbl: Label = $VBox/Status
@onready var keyboard: Node = $VBox/Keyboard
@onready var mode_btn: Button = $TopBar/ModeButton
@onready var newgame_btn: Button = $TopBar/NewGame

var answer: String = ""
var row: int = 0
var col: int = 0
var words: PackedStringArray
var words_map: Dictionary
var current_guess: String = ""

var mode: GameMode = GameMode.INFINITE
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
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
	#mode_btn.pressed.connect(_toggle_mode)
#	newgame_btn.pressed.connect(_new_game)

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

func _toggle_mode() -> void:
	mode = GameMode.INFINITE if mode == GameMode.DAILY else GameMode.DAILY
	_new_game()
	_update_topbar()

func _update_topbar() -> void:
	mode_btn.text = "Modo: Diário" if mode == GameMode.DAILY else "Modo: Infinito"

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
	if mode == GameMode.DAILY:
		answer = _pick_daily_word()
	else:
		rng.randomize()
		answer = words_map.keys()[rng.randi_range(0, words_map.keys().size()-1)]

func _update_status(text: String = "") -> void:
	if text == "":
		var base: String = "Adivinhe a palavra de 5 letras" 
		status_lbl.text = base
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
		_flash_status("Palavra não existe.")
		#_clear()
		return
	_reveal_guess(words_map.get(guess))
	current_guess = ""
	col = 0
	if guess == answer:
		_update_status("Parabéns! Você acertou.")
		_lock_input()
		return
	row += 1
	if row >= MAX_TRIES:
		_update_status("Fim de jogo. A palavra era: %s" % answer)
		_lock_input()

func _lock_input() -> void:
	get_tree().change_scene_to_file("res://scenes/end_game.tscn")
	
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
		
func _clear() -> void:
	for i in range(WORD_SIZE):
		var idx: int = row * WORD_SIZE + i
		var tile: Node = grid.get_child(idx)
		tile.set_letter("")      # limpa a letra
		tile.set_state("empty")  # volta ao estado vazio

func _pick_daily_word() -> String:
	var unix_time: int = Time.get_unix_time_from_system()
	var days: int = int(floor(unix_time / 86400.0))
	var local_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	local_rng.seed = days
	return words_map.keys()[local_rng.randi_range(0, words_map.keys().size()-1)]

func _flash_status(t: String) -> void:
	status_lbl.text = t
	status_lbl.modulate = Color(1, 0.7, 0.7, 1)
	await get_tree().create_timer(0.35).timeout
	status_lbl.modulate = Color(1, 1, 1, 1)
