extends VBoxContainer

@onready var portugues: Button = $Portugues
@onready var ingles: Button = $Ingles
@onready var espanhol: Button = $Espanhol
@onready var chines: Button = $Chines

var is_selecting_language := false

func _ready() -> void:
	portugues.grab_focus()

func _on_portugues_button_down() -> void:
	_select_language(Global.language_pt_br)

func _on_ingles_button_down() -> void:
	_select_language(Global.language_en)

func _on_espanhol_button_down() -> void:
	_select_language(Global.language_es)

func _on_chines_button_down() -> void:
	_select_language(Global.language_zh)

func _select_language(language) -> void:
	if is_selecting_language:
		return

	is_selecting_language = true
	portugues.disabled = true
	ingles.disabled = true
	espanhol.disabled = true
	chines.disabled = true
	Global.set_game_language(language)
	get_tree().change_scene_to_file("res://scenes/godot_splash.tscn")
