
extends VBoxContainer

signal letter_pressed(ch: String)
signal enter_pressed
signal backspace_pressed

const ROWS: Array[String] = [
	"QWERTYUIOP",
	"ASDFGHJKL",
	"ZXCVBNM"
]

var letter_state: Dictionary = {}

func _ready() -> void:
	_build_keys()

func _build_keys() -> void:
	_clear_children(self)
	for i: int in range(ROWS.size()):
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		add_child(h)
		var row: String = ROWS[i]

		# Enter button in last row
		if i == 2:
			var enter_btn: Button = _make_button("ENTER")
			enter_btn.custom_minimum_size = Vector2(72, 48)
			enter_btn.pressed.connect(func() -> void: emit_signal("enter_pressed"))
			h.add_child(enter_btn)

		for j: int in range(row.length()):
			var ch: String = row[j]
			var b: Button = _make_button(ch)
			var btn_ch: String = ch
			b.pressed.connect(func() -> void: emit_signal("letter_pressed", btn_ch))
			h.add_child(b)

		if i == 2:
			var back_btn: Button = _make_button("⌫")
			back_btn.custom_minimum_size = Vector2(72, 48)
			back_btn.pressed.connect(func() -> void: emit_signal("backspace_pressed"))
			h.add_child(back_btn)

func _clear_children(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()

func _make_button(t: String) -> Button:
	var b: Button = Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(40, 48)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	_update_button_style(b, "empty")
	return b

func set_letter_state(ch: String, state: String) -> void:
	ch = ch.to_upper()
	var rank: Dictionary = {"empty":0, "absent":1, "present":2, "correct":3}
	var prev: String = letter_state.get(ch, "empty")
	if rank[state] > rank[prev]:
		letter_state[ch] = state
		_refresh_colors()

func reset_states() -> void:
	letter_state.clear()
	_refresh_colors()

func _refresh_colors() -> void:
	for child in get_children():
		if child is HBoxContainer:
			for btn in child.get_children():
				if btn is Button:
					var text: String = btn.text
					var ch: String = text if text.length() == 1 else ""
					var st: String = letter_state.get(ch, "empty")
					_update_button_style(btn as Button, st)

func _update_button_style(b: Button, state: String) -> void:
	var col: Color = Color.hex(0x3a3b3eff)
	match state:
		"correct":
			col = Color.hex(0x23a559ff)
		"present":
			col = Color.hex(0xc9b458ff)
		"absent":
			col = Color.hex(0x3a3a3cff)
	_make_btn_style(b, col)

func _make_btn_style(b: Button, color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color.hex(0x0f1012ff)
	b.add_theme_stylebox_override("normal", sb)
