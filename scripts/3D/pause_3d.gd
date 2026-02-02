extends Node3D

@onready var control: Control = $Control
@onready var close: Button = $Control/VBoxContainer/close
@onready var quit: Button = $Control/VBoxContainer/quit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	if Global.default_language == Global.language_pt_br:
		quit.text = "Sair"
		close.text = "Fechar"
	else:
		quit.text = "Quit"
		close.text = "Close"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if Input.is_action_just_pressed("ui_cancel"):
		processa_pause_unpause()




func processa_pause_unpause()->void:
	if get_tree().paused:
		control.visible = false
		get_tree().paused = false
	else:
		close.grab_focus()
		control.visible = true
		get_tree().paused = true
		
		
func _on_close_pressed() -> void:
	processa_pause_unpause()


func _on_quit_pressed() -> void:
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
