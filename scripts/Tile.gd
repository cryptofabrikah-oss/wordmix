extends Panel

@export var letter: String = ""

@export var state: String = "empty" # empty, correct, present, absent

var label: Label


func _ready():
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 28)
	add_child(label)
	_update_style()

func set_letter(v: String) -> void:
	letter = v.substr(0, 1).to_upper()
	if label:
		label.text = letter
	_update_style()

func set_state(v: String) -> void:
	state = v
	_update_style()

func _update_style():
	var col = Color.hex(0x2b2d31ff) # default dark
	match state:
		"correct":
			col = Color.hex(0x23a559ff) # green
		"present":
			col = Color.hex(0xc9b458ff) # yellow
		"absent":
			col = Color.hex(0x3a3a3cff) # gray
		_:
			if letter == "":
				col = Color.hex(0x17181bff)
			else:
				col = Color.hex(0x2b2d31ff)
	add_theme_stylebox_override("panel", _make_stylebox(col))

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
	sb.border_color = Color.hex(0x0f1012ff)
	return sb
