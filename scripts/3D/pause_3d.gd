extends Node3D

const PAUSE_SOUND:AudioStream = preload("res://assets/novos_audios/pause_sfxr.mp3")
const PAUSE_VISUAL = preload("res://scripts/ui/pause_visual.gd")

@onready var control: Control = $Control
@onready var backdrop: ColorRect = $Control/ColorRect
@onready var close: Button = $Control/VBoxContainer/close
@onready var settings: Button = $Control/VBoxContainer/settings
@onready var quit: Button = $Control/VBoxContainer/quit
@onready var configuracoes_dialog = $ConfiguracoesDialog
var pause_audio:AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)
	
	quit.text = tr("MENU_EXIT")
	close.text = tr("MENU_CLOSE")
	if settings:
		settings.text = tr("MENU_SETTINGS")
	_apply_modern_layout()
	pause_audio = AudioStreamPlayer.new()
	pause_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_audio.stream = PAUSE_SOUND
	pause_audio.volume_db = -8.0
	add_child(pause_audio)

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
		pause_audio.play()
		PAUSE_VISUAL.animate_open(control, $Control/VBoxContainer)
		
		
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


func _apply_modern_layout() -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	PAUSE_VISUAL.configure_backdrop(backdrop, 0.91)
	backdrop.z_index = -10
	$Control/pause.visible = false
	PAUSE_VISUAL.add_header(control, tr("MENU_PAUSE"), tr("MENU_PAUSE_HINT"))
	PAUSE_VISUAL.add_side_glow(control)
	var menu:VBoxContainer = $Control/VBoxContainer
	menu.position = Vector2(70.0, 205.0)
	menu.size = Vector2(360.0, 210.0)
	menu.scale = Vector2.ONE
	menu.add_theme_constant_override("separation", 9)
	PAUSE_VISUAL.style_button(close)
	PAUSE_VISUAL.style_button(settings)
	PAUSE_VISUAL.style_button(quit, true)
	close.text = close.text.to_upper()
	settings.text = settings.text.to_upper()
	quit.text = quit.text.to_upper()
	var note_column := PAUSE_VISUAL.make_info_card(control, Vector2(780.0, 440.0), Vector2(300.0, 96.0))
	var note := Label.new()
	note.text = tr("MENU_PAUSE_HINT")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PAUSE_VISUAL.style_hint(note, 16)
	note_column.add_child(note)
