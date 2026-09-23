extends CanvasLayer

const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")

var panel:Control
var resume_button:Button
var previous_mouse_mode:Input.MouseMode

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_panel()
	panel.visible = false

func _unhandled_input(event:InputEvent) -> void:
	if get_parent().exit_started:
		return
	if event.is_action_pressed("ui_cancel") or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		resume_button.grab_focus()
	else:
		Input.mouse_mode = previous_mouse_mode
	get_tree().paused = panel.visible

func _return_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_parent().exit_to_menu()

func _build_panel() -> void:
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.23, 0.69)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var pentagram := TextureRect.new()
	pentagram.texture = PENTAGRAM_TEXTURE
	pentagram.set_anchors_preset(Control.PRESET_CENTER)
	pentagram.offset_left = -310.0
	pentagram.offset_top = -310.0
	pentagram.offset_right = 310.0
	pentagram.offset_bottom = 310.0
	pentagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pentagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pentagram.modulate = Color(0.93, 0.53, 0.73, 0.23)
	pentagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pentagram)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-220.0, -145.0)
	card.custom_minimum_size = Vector2(440.0, 290.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3d345f")
	style.border_color = Color("f6cae3")
	style.set_border_width_all(4)
	style.set_corner_radius_all(25)
	style.shadow_color = Color(0.07, 0.04, 0.13, 0.55)
	style.shadow_size = 18
	style.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", style)
	panel.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var ornament := Label.new()
	ornament.text = "✦  ☁  ✦"
	ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament.add_theme_font_size_override("font_size", 28)
	ornament.add_theme_color_override("font_color", Color("ffdd92"))
	column.add_child(ornament)
	var title := Label.new()
	title.text = tr("PLATFORM_PAUSE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff2f9"))
	column.add_child(title)
	var hint := Label.new()
	hint.text = tr("PLATFORM_PAUSE_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("dfd8f4"))
	column.add_child(hint)
	resume_button = _button(tr("MENU_CONTINUE"), Color("da709f"))
	resume_button.pressed.connect(_toggle)
	column.add_child(resume_button)
	var menu_button := _button(tr("PLATFORM_BACK_MENU"), Color("897cc6"))
	menu_button.pressed.connect(_return_to_menu)
	column.add_child(menu_button)

func _button(label:String, color:Color) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(260.0, 40.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(14)
	button.add_theme_stylebox_override("normal", normal)
	var hover:StyleBoxFlat = normal.duplicate()
	hover.bg_color = color.lightened(0.18)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	return button
