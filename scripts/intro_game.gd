extends VideoStreamPlayer

const SUBTITLES = [
	{"start": 9.0, "end": 14.0, "key": "INTRO_SUB_1"},
	{"start": 14.0, "end": 19.0, "key": "INTRO_SUB_2"},
	{"start": 19.0, "end": 24.0, "key": "INTRO_SUB_3"},
	{"start": 24.0, "end": 29.0, "key": "INTRO_SUB_4"},
	{"start": 29.0, "end": 33.0, "key": "INTRO_SUB_5"},
	{"start": 33.0, "end": 36.5, "key": "INTRO_SUB_6"},
	{"start": 36.5, "end": 41.0, "key": "INTRO_SUB_7"},
	{"start": 41.0, "end": 48.0, "key": "INTRO_SUB_8"},
	{"start": 48.0, "end": 57.0, "key": "INTRO_SUB_9"},
	{"start": 57.0, "end": 62.5, "key": "INTRO_SUB_10"},
	{"start": 62.5, "end": 68.0, "key": "INTRO_SUB_11"},
	{"start": 68.0, "end": 73.5, "key": "INTRO_SUB_12"},
	{"start": 73.5, "end": 80.5, "key": "INTRO_SUB_13"},
	{"start": 80.5, "end": 86.5, "key": "INTRO_SUB_14"}
]

var canvas_layer: CanvasLayer
var subtitle_panel: PanelContainer
var subtitle_label: Label
var skip_hint: Label
var current_key: String = ""

func _ready() -> void:
	_create_subtitle_ui()

func _create_subtitle_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 20
	add_child(canvas_layer)

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(root_control)

	# Painel de Legenda no rodapé
	subtitle_panel = PanelContainer.new()
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_panel.anchor_top = 0.82
	subtitle_panel.anchor_bottom = 0.96
	subtitle_panel.offset_left = 60.0
	subtitle_panel.offset_right = -60.0
	subtitle_panel.offset_top = 0.0
	subtitle_panel.offset_bottom = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	subtitle_panel.add_theme_stylebox_override("panel", style)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	subtitle_label.add_theme_constant_override("outline_size", 4)
	subtitle_panel.add_child(subtitle_label)

	root_control.add_child(subtitle_panel)
	subtitle_panel.visible = false

	# Indicador de pular vídeo no canto superior direito
	skip_hint = Label.new()
	skip_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_hint.offset_left = -260.0
	skip_hint.offset_top = 18.0
	skip_hint.offset_right = -20.0
	skip_hint.offset_bottom = 50.0
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	skip_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	skip_hint.add_theme_constant_override("outline_size", 2)
	skip_hint.text = tr("UI_HOLD_SKIP")
	root_control.add_child(skip_hint)

func go_to_game_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/demo_controls.tscn")

func _on_finished() -> void:
	go_to_game_scene()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		go_to_game_scene()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel"):
		go_to_game_scene()
		return

	_update_subtitles()

func _update_subtitles() -> void:
	if not is_playing():
		if is_instance_valid(subtitle_panel):
			subtitle_panel.visible = false
		return

	var pos: float = get_stream_position()
	var found_key: String = ""

	for entry in SUBTITLES:
		if pos >= entry.start and pos <= entry.end:
			found_key = entry.key
			break

	if found_key != current_key:
		current_key = found_key
		if current_key != "":
			subtitle_label.text = tr(current_key)
			subtitle_panel.visible = true
		else:
			subtitle_label.text = ""
			subtitle_panel.visible = false

