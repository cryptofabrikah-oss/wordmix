extends Control

@onready var start_btn = $VBoxContainer/StartB

func _ready():
	start_btn.pressed.connect(_on_start_pressed)

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
