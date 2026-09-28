extends VBoxContainer

@onready var portugues: Button = $Portugues
@onready var ingles: Button = $Ingles
@onready var espanhol: Button = $Espanhol
@onready var chines: Button = $Chines

func _ready() -> void:
	portugues.grab_focus()

func _on_portugues_button_down() -> void:
	Global.set_game_language(Global.language_pt_br)
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")

func _on_ingles_button_down() -> void:
	Global.set_game_language(Global.language_en)
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")

func _on_espanhol_button_down() -> void:
	Global.set_game_language(Global.language_es)
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")

func _on_chines_button_down() -> void:
	Global.set_game_language(Global.language_zh)
	get_tree().change_scene_to_file("res://scenes/intro_pacoca_producoes.tscn")
