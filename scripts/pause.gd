extends Control

const PAUSE_SOUND:AudioStream = preload("res://assets/novos_audios/pause_sfxr.mp3")
const PAUSE_VISUAL = preload("res://scripts/ui/pause_visual.gd")
const MENU_SOUND_CONTROLLER = preload("res://scripts/ui/menu_sound_controller.gd")

@onready var pause_animation: AnimationPlayer = $pause_animation
@onready var black_screen: ColorRect = $black_screen
@onready var camera: Camera2D = $black_screen/camera
@onready var maycon: AnimatedSprite2D = $black_screen/maycon
@onready var close: Button = $black_screen/VBoxContainer/close
@onready var settings_btn: Button = $black_screen/VBoxContainer/settings
@onready var quit: Button = $black_screen/VBoxContainer/quit
@onready var configuracoes_dialog = $ConfiguracoesDialog
@onready var run_label: Label = $black_screen/run_label
@onready var down_label: Label = $black_screen/down_label
@onready var space_keys: Label = get_node_or_null("black_screen/space_keys")
@onready var powers: Label = $black_screen/powers
@onready var v_box_container: VBoxContainer = $black_screen/VBoxContainer
@onready var pause: Label = $black_screen/pause
@onready var maycon_hp: Node2D = $maycon_hp
var realtime_hp_bar:ProgressBar
var realtime_hp_label:Label
var pause_audio:AudioStreamPlayer
var menu_sounds:Node
var controls_card:PanelContainer
var background_pentagram:TextureRect
var pause_background:ColorRect
var pause_layer:CanvasLayer
var transition_in_progress:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_sounds = MENU_SOUND_CONTROLLER.new()
	add_child(menu_sounds)
	menu_sounds.bind_button(close, "back")
	menu_sounds.bind_button(settings_btn)
	menu_sounds.bind_button(quit)
	build_realtime_hp_display()
	update_hp_display()
	v_box_container.visible = true
	maycon_hp.visible = true
	
	var p3 = tr("POWER_DASH") if Global.battle_mode == Global.battle_mode_realtime else tr("POWER_JUMP")
	powers.text = " " + tr("POWER_PUNCH") + " \n " + tr("POWER_KICK") + " \n\n " + p3
	close.text = tr("MENU_CLOSE")
	settings_btn.text = tr("SETTINGS_TITLE")
	
	quit.text = tr("MENU_SAVE_QUIT")
	
	run_label.text = tr("MENU_RUN")
	down_label.text = tr("MENU_CROUCH")
	_setup_pause_canvas_layer()
	_apply_modern_pause_layout()
	pause_audio = AudioStreamPlayer.new()
	pause_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_audio.stream = PAUSE_SOUND
	pause_audio.volume_db = -8.0
	add_child(pause_audio)
		

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

func processa_pause_unpause(play_close_sound:bool = true)->void:
	if transition_in_progress:
		return
	update_hp_display()
	v_box_container.visible = true
	maycon_hp.visible = true
	
	if get_tree().paused:
		if play_close_sound:
			menu_sounds.play_back()
		_fade_out_and_resume()
		return
	else:
		
		var maycon_items := get_node_or_null("../maycon_itens")
		if is_instance_valid(maycon_items):
			var items_canvas := maycon_items.get_node_or_null("canvas")
			if is_instance_valid(items_canvas):
				items_canvas.visible = false
		
		update_hp_display()
			
		
		close.grab_focus()
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
		get_tree().paused = true
		pause_animation.stop()
		maycon.stop()
		maycon.frame = 0
		maycon.frame_progress = 0.0
		maycon.play("idle")
		if is_instance_valid(pause_audio):
			pause_audio.play()
		_play_modern_intro()
		
		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") && (!Global.battle_started) && !Global.block_pause_before_prologo:
		alterna_pause_uma_vez()

func _input(event: InputEvent) -> void:
	if not get_tree().paused or not (pause_layer and pause_layer.visible) or transition_in_progress:
		return
	if is_instance_valid(configuracoes_dialog) and configuracoes_dialog.visible:
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
		get_viewport().set_input_as_handled()
		alterna_pause_uma_vez()
		return
	Global.check_debug_activation(event)
			

func _on_close_pressed() -> void:
	processa_pause_unpause(false)


func _on_settings_pressed() -> void:
	configuracoes_dialog.abrir()


func _on_quit_pressed() -> void:
	if transition_in_progress:
		return
	transition_in_progress = true
	close.disabled = true
	settings_btn.disabled = true
	quit.disabled = true
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel(true)
	fade.tween_property(v_box_container, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	fade.tween_property(maycon, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	fade.tween_property(controls_card, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	fade.tween_property(background_pentagram, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE)
	fade.tween_property(maycon_hp, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	await fade.finished
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func build_realtime_hp_display() -> void:
	realtime_hp_bar = ProgressBar.new()
	realtime_hp_bar.position = Vector2(42, 603)
	realtime_hp_bar.size = Vector2(205, 24)
	realtime_hp_bar.show_percentage = false
	realtime_hp_bar.max_value = Global.realtime_hp_max
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.025, 0.035, 0.94)
	background.border_color = Color(0.95, 0.95, 1.0, 0.7)
	background.set_border_width_all(2)
	background.set_corner_radius_all(7)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("b3132b")
	fill.set_corner_radius_all(6)
	realtime_hp_bar.add_theme_stylebox_override("background", background)
	realtime_hp_bar.add_theme_stylebox_override("fill", fill)
	maycon_hp.add_child(realtime_hp_bar)
	realtime_hp_label = Label.new()
	realtime_hp_label.position = Vector2(42, 574)
	realtime_hp_label.size = Vector2(205, 28)
	realtime_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realtime_hp_label.add_theme_font_size_override("font_size", 18)
	realtime_hp_label.add_theme_color_override("font_color", Color("ffd6dc"))
	maycon_hp.add_child(realtime_hp_label)

func update_hp_display() -> void:
	var realtime = Global.battle_mode == Global.battle_mode_realtime
	var hp_1 := maycon_hp.get_node_or_null("hp_1") as CanvasItem
	var hp_2 := maycon_hp.get_node_or_null("hp_2") as CanvasItem
	var hp_3 := maycon_hp.get_node_or_null("hp_3") as CanvasItem
	if is_instance_valid(hp_1):
		hp_1.visible = !realtime && Global.maycon_hp_count<=2
	if is_instance_valid(hp_2):
		hp_2.visible = !realtime && Global.maycon_hp_count<=1
	if is_instance_valid(hp_3):
		hp_3.visible = !realtime && Global.maycon_hp_count<=0
	if realtime_hp_bar:
		realtime_hp_bar.visible = realtime
		realtime_hp_bar.max_value = Global.realtime_hp_max
		realtime_hp_bar.value = Global.realtime_hp
		realtime_hp_label.visible = realtime
		realtime_hp_label.text = tr("BATTLE_HP_LABEL")


func _apply_modern_pause_layout() -> void:
	_create_opaque_background()
	black_screen.material = null
	black_screen.color = Color.TRANSPARENT
	black_screen.z_index = 101
	black_screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_add_rotating_pentagram()
	pause.visible = false
	for legacy_node_name in ["jump", "defence", "power", "powers", "run_label", "down_label", "ArrowDownKeyLight", "ButtonIconSwitchDpadDown", "360X", "Shift"]:
		var legacy_node := black_screen.get_node_or_null(legacy_node_name)
		if is_instance_valid(legacy_node):
			legacy_node.visible = false
	for legacy_node_name in ["QKeyLight", "360Y", "WKeyLight", "360B", "BlankWhiteSuperWide", "BlankWhiteEnter", "360A"]:
		var legacy_node := get_node_or_null(legacy_node_name)
		if is_instance_valid(legacy_node):
			legacy_node.visible = false

	PAUSE_VISUAL.add_header(black_screen, tr("MENU_PAUSE"), tr("MENU_PAUSE_HINT"))
	PAUSE_VISUAL.add_side_glow(black_screen)
	v_box_container.position = Vector2(70.0, 205.0)
	v_box_container.size = Vector2(360.0, 210.0)
	v_box_container.scale = Vector2.ONE
	v_box_container.add_theme_constant_override("separation", 9)
	PAUSE_VISUAL.style_button(close)
	PAUSE_VISUAL.style_button(settings_btn)
	PAUSE_VISUAL.style_button(quit, true)
	close.text = close.text.to_upper()
	settings_btn.text = settings_btn.text.to_upper()
	quit.text = quit.text.to_upper()

	maycon.position = Vector2(690.0, 348.0)
	maycon.scale = Vector2(1.58, 1.58)
	maycon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	maycon.sprite_frames.set_animation_loop("idle", false)
	maycon.flip_h = true
	maycon_hp.position = Vector2(850.0, -8.0)
	maycon_hp.z_index = 102

	var profile := "prologue" if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://scenes/game.tscn" else "2d"
	controls_card = PAUSE_VISUAL.add_controls_card(black_screen, profile)
	controls_card.visible = true


func _setup_pause_canvas_layer() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.name = "PauseLayer"
	pause_layer.layer = 50
	pause_layer.visible = false
	add_child(pause_layer)
	black_screen.reparent(pause_layer)
	maycon_hp.reparent(pause_layer)
	black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_screen.offset_left = 0.0
	black_screen.offset_top = 0.0
	black_screen.offset_right = 0.0
	black_screen.offset_bottom = 0.0
	camera.enabled = false


func _create_opaque_background() -> void:
	pause_background = ColorRect.new()
	pause_background.name = "PauseBackground"
	pause_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_background.offset_left = 0.0
	pause_background.offset_top = 0.0
	pause_background.offset_right = 0.0
	pause_background.offset_bottom = 0.0
	pause_background.color = Color.BLACK
	pause_background.z_index = 100
	pause_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_background.visible = false
	pause_layer.add_child(pause_background)
	pause_layer.move_child(pause_background, 0)


func _add_rotating_pentagram() -> void:
	background_pentagram = PAUSE_VISUAL.add_rotating_pentagram(pause_background)


func _play_modern_intro() -> void:
	pause_layer.visible = true
	pause_background.visible = true
	pause_background.modulate.a = 1.0
	black_screen.modulate.a = 1.0
	maycon_hp.modulate.a = 1.0
	controls_card.modulate.a = 1.0
	background_pentagram.modulate = Color(0.30, 0.82, 0.88, 0.115)
	close.disabled = false
	settings_btn.disabled = false
	quit.disabled = false
	maycon.position = Vector2(1180.0, 348.0)
	maycon.rotation = 0.035
	maycon.modulate.a = 0.0
	maycon.flip_h = true
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(maycon, "position", Vector2(690.0, 348.0), 1.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.parallel().tween_property(maycon, "rotation", 0.0, 1.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.parallel().tween_property(maycon, "modulate:a", 1.0, 0.42)
	var menu_destination := Vector2(70.0, 205.0)
	v_box_container.position = menu_destination + Vector2(-28.0, 0.0)
	v_box_container.modulate.a = 0.0
	reveal.parallel().tween_property(v_box_container, "position", menu_destination, 0.46).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	reveal.parallel().tween_property(v_box_container, "modulate:a", 1.0, 0.32)


func _fade_out_and_resume() -> void:
	transition_in_progress = true
	close.disabled = true
	settings_btn.disabled = true
	quit.disabled = true
	close.release_focus()
	quit.release_focus()
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel(true)
	fade.tween_property(pause_background, "modulate:a", 0.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_property(black_screen, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade.tween_property(maycon_hp, "modulate:a", 0.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade.finished
	Global.back_to_main_camera = true
	get_tree().paused = false
	pause_layer.visible = false
	var maycon_items := get_node_or_null("../maycon_itens")
	if is_instance_valid(maycon_items):
		var items_canvas := maycon_items.get_node_or_null("canvas")
		if is_instance_valid(items_canvas):
			items_canvas.visible = true
	transition_in_progress = false
