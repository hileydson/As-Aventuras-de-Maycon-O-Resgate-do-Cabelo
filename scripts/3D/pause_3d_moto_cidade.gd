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
	if Global.in_cutscene:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hud_canvas = player.get_node_or_null("hud_canvas")
		if is_instance_valid(hud_canvas):
			var control_gun = hud_canvas.get_node_or_null("control_gun")
			if is_instance_valid(control_gun):
				control_gun.visible = false
			var control_lamp = hud_canvas.get_node_or_null("control_lamp")
			if is_instance_valid(control_lamp):
				control_lamp.visible = false
			var maycon_hp = hud_canvas.get_node_or_null("maycon_hp")
			if is_instance_valid(maycon_hp):
				maycon_hp.visible = false
	
	if get_tree().paused:
		if configuracoes_dialog and configuracoes_dialog.visible:
			configuracoes_dialog.fechar()
		if player:
			player.get_node("hud_canvas").get_node("control_moto").visible = player.on_moto
			$"../maycon_3d/CharacterBody3D/mapa_maycon".visible = false
			if get_parent().has_method("update_map_objectives"):
				get_parent().update_map_objectives(false)
		
		if $camera_pause:
			$camera_pause.current = false	
			$luz_mapa.visible = false
			
		control.visible = false
		get_tree().paused = false
	else:
		if player:
			player.get_node("hud_canvas").get_node("control_moto").visible = false
			$"../maycon_3d/CharacterBody3D/mapa_maycon".visible = true
			if get_parent().has_method("update_map_objectives"):
				get_parent().update_map_objectives(true)
		
		if $camera_pause:
			$camera_pause.make_current()
			$luz_mapa.visible = true
		
		close.grab_focus()
		control.visible = true
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
