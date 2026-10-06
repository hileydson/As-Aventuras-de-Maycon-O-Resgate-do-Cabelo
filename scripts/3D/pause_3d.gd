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
var pause_maycon:AnimatedSprite2D
var controls_card:PanelContainer

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
	
	# O overlay de controles segura o jogo e bloqueia o pause enquanto aparece.
	if Global.block_pause_before_prologo and not (is_instance_valid(control) and control.visible):
		return
	
	#NAO DEIXA O SEGUNDO CONTROLE PARAR A PARTIDA NO PRIMEIRO START - DAI DEPOIS SIM
	if (Input.is_action_just_pressed("ui_cancel") and !Input.is_joy_button_pressed(1, JOY_BUTTON_START)) or (Input.is_action_just_pressed("ui_cancel") and Input.is_joy_button_pressed(1, JOY_BUTTON_START) and Global.is_two_player_active):
		alterna_pause_uma_vez()

func _input(event: InputEvent) -> void:
	if not get_tree().paused or not (is_instance_valid(control) and control.visible):
		return
	if is_instance_valid(configuracoes_dialog) and configuracoes_dialog.visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
		get_viewport().set_input_as_handled()
		alterna_pause_uma_vez()
		return
	Global.check_debug_activation(event)




var ultimo_frame_toggle_pause:int = -1

# O mesmo toque chega por _input e por _process no mesmo quadro: set_input_as_handled
# corta a propagação do evento, mas não impede Input.is_action_just_pressed de ler a
# ação. Os dois juntos alternavam o pause duas vezes, e ele reabria em vez de fechar.
func alterna_pause_uma_vez() -> void:
	var frame := Engine.get_process_frames()
	if frame == ultimo_frame_toggle_pause:
		return
	ultimo_frame_toggle_pause = frame
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
		set_pause_hidden_nodes_visible(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false
	else:
		close.grab_focus()
		set_pause_hidden_nodes_visible(false)
		control.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		pause_audio.play()
		PAUSE_VISUAL.animate_walking_maycon(pause_maycon)
		PAUSE_VISUAL.animate_open(control, $Control/VBoxContainer)

func set_pause_hidden_nodes_visible(value:bool) -> void:
	for node in get_tree().get_nodes_in_group("hide_on_pause"):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = value
		elif node is CanvasItem:
			(node as CanvasItem).visible = value
		
		
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
	PAUSE_VISUAL.add_rotating_pentagram(control)
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
	pause_maycon = PAUSE_VISUAL.add_walking_maycon(control)
	var scene_path := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	if scene_path != "res://scenes/3D/cenario_3d_bofore_castle_1.tscn":
		var profile := "dungeon" if scene_path == "res://scenes/3D/calabouco_terror.tscn" else "first_3d"
		var card_position := Vector2(825.0, 102.0) if profile == "dungeon" else Vector2(825.0, 142.0)
		controls_card = PAUSE_VISUAL.add_controls_card(control, profile, card_position)
