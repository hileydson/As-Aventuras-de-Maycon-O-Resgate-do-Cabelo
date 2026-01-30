extends Control
@onready var pause_animation: AnimationPlayer = $pause_animation
@onready var camera: Camera2D = $black_screen/camera
@onready var maycon: AnimatedSprite2D = $black_screen/maycon
@onready var close: Button = $black_screen/VBoxContainer/close
@onready var quit: Button = $black_screen/VBoxContainer/quit
@onready var run_label: Label = $black_screen/run_label
@onready var down_label: Label = $black_screen/down_label
@onready var space_keys: Label = $black_screen/space_keys
@onready var powers: Label = $black_screen/powers
@onready var v_box_container: VBoxContainer = $black_screen/VBoxContainer
@onready var pause: Label = $black_screen/pause
@onready var maycon_hp: Node2D = $maycon_hp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	if Global.game_events["before_prologo"] == false:
		v_box_container.visible = true
		maycon_hp.visible = true
	else:
		v_box_container.visible = false
		maycon_hp.visible = false
	
	if Global.default_language == Global.language_pt_br:
		powers.text = " SOCO \n CHUTE \n\n PULO"
		close.text = "Fechar"
		quit.text = "Salvar & Sair"
		run_label.text = "Correr"
		down_label.text = "Agachar"
		
		if Global.game_events["before_prologo"]:
			pause.text = "CONTROLE"
		
	else:
		powers.text = " PUNCH \n KICK \n\n JUMP"
		close.text = "Close"
		quit.text = "Save & Quit"
		run_label.text = "Run"
		down_label.text = "Croutch"
		
		if Global.game_events["before_prologo"]:
			pause.text = "CONTROLLER"
		

func processa_pause_unpause()->void:
	if get_tree().paused:
			close.release_focus()
			quit.release_focus()
			Global.back_to_main_camera = true
			get_tree().paused = false
			$"../maycon_itens".get_node("canvas").visible = true
	else:
		
		$"../maycon_itens".get_node("canvas").visible = false
		
		$maycon_hp/hp_1.visible = Global.maycon_hp_count<=2
		$maycon_hp/hp_2.visible = Global.maycon_hp_count<=1
		$maycon_hp/hp_3.visible = Global.maycon_hp_count<=0
		
		close.grab_focus()
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
		camera.make_current()
		get_tree().paused = true
		pause_animation.stop()
		maycon.stop()
		pause_animation.play("intro")
		maycon.play("idle")
		
		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") && (!Global.battle_started) && (!Global.game_events["before_prologo"]):
		processa_pause_unpause()
			

func _on_close_pressed() -> void:
	processa_pause_unpause()


func _on_quit_pressed() -> void:
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
