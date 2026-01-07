extends Control
@onready var pause_animation: AnimationPlayer = $pause_animation
@onready var camera: Camera2D = $black_screen/camera
@onready var maycon: AnimatedSprite2D = $black_screen/maycon
@onready var close: Button = $black_screen/VBoxContainer/close
@onready var quit: Button = $black_screen/VBoxContainer/quit

@onready var space_keys: Label = $black_screen/space_keys
@onready var powers: Label = $black_screen/powers

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close.grab_focus()
	
	if Global.default_language == Global.language_pt_br:
		space_keys.text = "espaço"
		powers.text = " CHUTE \n SOCO \n\n\n PULO"
		close.text = "Fechar"
		quit.text = "Sair"
	else:
		space_keys.text = "space"
		powers.text = " KICK \n PUNCH \n\n\n JUMP"
		close.text = "Close"
		quit.text = "Quit"
		

func processa_pause_unpause()->void:
	if get_tree().paused:
			Global.back_to_main_camera = true
			get_tree().paused = false
	else:
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
		camera.make_current()
		get_tree().paused = true
		pause_animation.play("intro")
		maycon.play("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") && (!Global.battle_started):
		processa_pause_unpause()
			

func _on_close_pressed() -> void:
	processa_pause_unpause()


func _on_quit_pressed() -> void:
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
