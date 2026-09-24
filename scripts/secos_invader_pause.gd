extends CanvasLayer

const PAUSE_SOUND:AudioStream = preload("res://assets/novos_audios/pause_sfxr.mp3")

var panel:ColorRect
var resume_button:Button
var pause_audio:AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	pause_audio = AudioStreamPlayer.new()
	pause_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_audio.stream = PAUSE_SOUND
	pause_audio.volume_db = -8.0
	add_child(pause_audio)
	panel = ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.02, 0.88)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	add_child(panel)
	var heading:Label = Label.new()
	heading.text = tr("MENU_BATTLE_PAUSED")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.set_anchors_preset(Control.PRESET_CENTER)
	heading.position = Vector2(-260.0, -100.0)
	heading.size = Vector2(520.0, 70.0)
	panel.add_child(heading)
	resume_button = Button.new()
	resume_button.text = tr("MENU_CONTINUE")
	resume_button.set_anchors_preset(Control.PRESET_CENTER)
	resume_button.position = Vector2(-100.0, 15.0)
	resume_button.size = Vector2(200.0, 48.0)
	resume_button.pressed.connect(_toggle)
	panel.add_child(resume_button)


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
	else:
		resume_button.release_focus()
