class_name Tile
extends Panel

@export var letter: String = ""

@export var state: String = "empty" # empty, correct, present, absent
@export var is_archer_extra_row: bool = false

var label: Label


func _ready():
	label = Label.new()
	custom_minimum_size = Vector2(100, 100)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.set_anchor(SIDE_RIGHT, 1)
	label.set_anchor(SIDE_BOTTOM, 1)
	label.add_theme_font_size_override("font_size", 36)
	add_child(label)
	_update_style()

func set_letter(v: String) -> void:
	letter = v.substr(0, 1).to_upper()
	if label:
		label.text = letter
	_update_style()

func get_letter() -> String:
	return letter

func set_state(v: String) -> void:
	state = v
	_update_style()

func _update_style():
	var col = Color.hex(0x1F3A4DFF) # default azul petroleo para empty
	match state:
		"correct":
			col = Color.hex(0x4DB6ACFF) # verde-agua
		"present":
			col = Color.hex(0xC9B458FF) # amarelo
		"absent":
			col = Color.hex(0x4B4B4BFF) # cinza
		_:
			if letter == "":
				col = Color.hex(0x1F3A4DFF) # empty
			else:
				col = Color.hex(0x1F3A4DFF)
	add_theme_stylebox_override("panel", _make_stylebox(col))

func set_archer_extra_row(value: bool) -> void:
	is_archer_extra_row = value
	_update_style()

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	# Aplicar borda dourada para linha extra do arqueiro
	if is_archer_extra_row:
		sb.border_color = Color(1, 0.84, 0)  # Dourado
		sb.border_width_bottom = 4
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 4
	else:
		sb.border_color = Color.hex(0xD9CFC4FF)
	return sb
