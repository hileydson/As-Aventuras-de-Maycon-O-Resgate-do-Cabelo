extends VideoStreamPlayer

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")

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

const SKIP_HOLD_TIME: float = 1.1

var old_film_layer: CanvasLayer
var ui_layer: CanvasLayer
var subtitle_label: Label
var skip_container: VBoxContainer
var skip_hint: Label
var skip_bar: ProgressBar

var current_key: String = ""
var skip_progress: float = 0.0
var is_skipping: bool = false
var is_mouse_holding: bool = false
var is_portuguese: bool = false

func _ready() -> void:
	# Não exibe legendas se o idioma for português, pois o áudio original já é em português
	var locale := TranslationServer.get_locale().to_lower()
	is_portuguese = locale.begins_with("pt")

	_create_old_film_filter()
	_create_ui()

func _create_old_film_filter() -> void:
	old_film_layer = CanvasLayer.new()
	old_film_layer.layer = 10
	add_child(old_film_layer)

	var film_rect := ColorRect.new()
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = OLD_FILM_SHADER
	mat.set_shader_parameter("sepia_amount", 0.48)
	mat.set_shader_parameter("grain_amount", 0.082)
	mat.set_shader_parameter("grain_speed", 24.0)
	mat.set_shader_parameter("vignette_intensity", 0.85)
	mat.set_shader_parameter("vignette_radius", 1.0)
	mat.set_shader_parameter("flicker_intensity", 0.048)
	mat.set_shader_parameter("scratch_intensity", 0.40)
	mat.set_shader_parameter("dust_intensity", 0.45)
	mat.set_shader_parameter("jitter_amount", 0.00065)
	film_rect.material = mat

	old_film_layer.add_child(film_rect)

func _create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 25
	add_child(ui_layer)

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_control)

	# Legenda: posicionada bem em baixo, sem faixa preta, com outline e sombra fortes
	subtitle_label = Label.new()
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.anchor_top = 0.88
	subtitle_label.anchor_bottom = 0.98
	subtitle_label.offset_left = 40.0
	subtitle_label.offset_right = -40.0
	subtitle_label.offset_top = 0.0
	subtitle_label.offset_bottom = 0.0
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 23)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	subtitle_label.add_theme_constant_override("outline_size", 6)
	subtitle_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	subtitle_label.add_theme_constant_override("shadow_offset_x", 2)
	subtitle_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitle_label.visible = false
	root_control.add_child(subtitle_label)

	# Container de pular vídeo (Hold to Skip) no canto superior direito
	skip_container = VBoxContainer.new()
	skip_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_container.offset_left = -280.0
	skip_container.offset_top = 18.0
	skip_container.offset_right = -24.0
	skip_container.offset_bottom = 58.0
	skip_container.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_container.modulate.a = 0.55
	root_control.add_child(skip_container)

	skip_hint = Label.new()
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_hint.add_theme_font_size_override("font_size", 13)
	skip_hint.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
	skip_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	skip_hint.add_theme_constant_override("outline_size", 2)
	skip_hint.text = tr("UI_HOLD_SKIP")
	skip_container.add_child(skip_hint)

	# Barra de progresso para segurar e pular
	skip_bar = ProgressBar.new()
	skip_bar.custom_minimum_size = Vector2(0, 5)
	skip_bar.min_value = 0.0
	skip_bar.max_value = SKIP_HOLD_TIME
	skip_bar.value = 0.0
	skip_bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.08, 0.12, 0.55)
	bar_bg.set_corner_radius_all(3)
	skip_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.82, 0.35, 0.95)
	bar_fill.set_corner_radius_all(3)
	skip_bar.add_theme_stylebox_override("fill", bar_fill)

	skip_container.add_child(skip_bar)

func go_to_game_scene() -> void:
	if is_skipping:
		return
	is_skipping = true
	get_tree().change_scene_to_file("res://scenes/demo_controls.tscn")

func _on_finished() -> void:
	go_to_game_scene()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_mouse_holding = event.pressed

func _on_gui_input(event: InputEvent) -> void:
	_gui_input(event)

func _process(delta: float) -> void:
	if is_skipping:
		return

	_process_hold_to_skip(delta)
	_update_subtitles()

func _process_hold_to_skip(delta: float) -> void:
	var holding := Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("ui_accept") or is_mouse_holding

	if holding:
		skip_progress = minf(SKIP_HOLD_TIME, skip_progress + delta)
		skip_container.modulate.a = 1.0
	else:
		skip_progress = maxf(0.0, skip_progress - delta * 3.0)
		skip_container.modulate.a = lerpf(skip_container.modulate.a, 0.55, delta * 5.0)

	skip_bar.value = skip_progress

	if skip_progress >= SKIP_HOLD_TIME:
		go_to_game_scene()

func _update_subtitles() -> void:
	# Em português não exibimos legenda
	if is_portuguese or not is_playing():
		if is_instance_valid(subtitle_label):
			subtitle_label.visible = false
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
			subtitle_label.visible = true
		else:
			subtitle_label.text = ""
			subtitle_label.visible = false
