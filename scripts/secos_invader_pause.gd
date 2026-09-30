extends CanvasLayer

const PAUSE_SOUND:AudioStream = preload("res://assets/novos_audios/pause_sfxr.mp3")
const PAUSE_VISUAL = preload("res://scripts/ui/pause_visual.gd")
const SETTINGS_DIALOG = preload("res://scenes/menus/configuracoes_dialog.tscn")

var panel:ColorRect
var resume_button:Button
var pause_audio:AudioStreamPlayer
var settings_dialog:CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	pause_audio = AudioStreamPlayer.new()
	pause_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_audio.stream = PAUSE_SOUND
	pause_audio.volume_db = -8.0
	add_child(pause_audio)
	settings_dialog = SETTINGS_DIALOG.instantiate()
	add_child(settings_dialog)
	panel = ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	PAUSE_VISUAL.configure_backdrop(panel, 0.93)
	PAUSE_VISUAL.add_header(panel, tr("MENU_BATTLE_PAUSED"), tr("MENU_PAUSE_HINT"))
	PAUSE_VISUAL.add_side_glow(panel)
	resume_button = Button.new()
	resume_button.text = tr("MENU_CONTINUE").to_upper()
	resume_button.position = Vector2(70.0, 205.0)
	resume_button.size = Vector2(360.0, 52.0)
	PAUSE_VISUAL.style_button(resume_button)
	resume_button.pressed.connect(_toggle)
	panel.add_child(resume_button)
	var settings_button := Button.new()
	settings_button.text = tr("MENU_SETTINGS").to_upper()
	settings_button.position = Vector2(70.0, 269.0)
	settings_button.size = Vector2(360.0, 52.0)
	PAUSE_VISUAL.style_button(settings_button)
	settings_button.pressed.connect(func(): settings_dialog.abrir())
	panel.add_child(settings_button)
	var exit_button := Button.new()
	exit_button.text = tr("MENU_EXIT").to_upper()
	exit_button.position = Vector2(70.0, 333.0)
	exit_button.size = Vector2(360.0, 52.0)
	PAUSE_VISUAL.style_button(exit_button, true)
	exit_button.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	)
	panel.add_child(exit_button)


func _unhandled_input(event:InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	panel.visible = !panel.visible
	get_tree().paused = panel.visible
	get_parent().set_invader_paused(panel.visible)
	if panel.visible:
		pause_audio.play()
		resume_button.grab_focus()
		PAUSE_VISUAL.animate_open(panel, resume_button)
	else:
		resume_button.release_focus()
