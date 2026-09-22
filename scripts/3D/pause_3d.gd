extends Node3D

@onready var control: Control = $Control
@onready var close: Button = $Control/VBoxContainer/close
@onready var settings: Button = $Control/VBoxContainer/settings
@onready var quit: Button = $Control/VBoxContainer/quit
@onready var configuracoes_dialog = $ConfiguracoesDialog

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	quit.text = tr("MENU_EXIT")
	close.text = tr("MENU_CLOSE")
	if settings:
		settings.text = tr("MENU_SETTINGS")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if configuracoes_dialog and configuracoes_dialog.visible:
		return
	
	#NAO DEIXA O SEGUNDO CONTROLE PARAR A PARTIDA NO PRIMEIRO START - DAI DEPOIS SIM
	if (Input.is_action_just_pressed("ui_cancel") and !Input.is_joy_button_pressed(1, JOY_BUTTON_START)) or (Input.is_action_just_pressed("ui_cancel") and Input.is_joy_button_pressed(1, JOY_BUTTON_START) and Global.is_two_player_active):
		processa_pause_unpause()




func processa_pause_unpause()->void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("hud_canvas"):
		var hud = player.get_node("hud_canvas")
		if hud.has_node("control_gun"):
			hud.get_node("control_gun").visible = false
		if hud.has_node("control_lamp"):
			hud.get_node("control_lamp").visible = false
	
	if get_tree().paused:
		if configuracoes_dialog and configuracoes_dialog.visible:
			configuracoes_dialog.fechar()
		control.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
	else:
		close.grab_focus()
		control.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		
		
func _on_close_pressed() -> void:
	processa_pause_unpause()


func _on_settings_pressed() -> void:
	if configuracoes_dialog:
		configuracoes_dialog.abrir()


func _on_quit_pressed() -> void:
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
