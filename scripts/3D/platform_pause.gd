extends CanvasLayer

const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")
const PAUSE_SOUND = preload("res://assets/novos_audios/pause_sfxr.mp3")

const GLITTER_COLORS := [
	Color("ffd700"), # Gold
	Color("ff2a70"), # Vivid Pink
	Color("00f0ff"), # Cyan
	Color("70ff00"), # Bright Lime
	Color("b05bff"), # Violet
	Color("ff8c00"), # Tangerine Orange
	Color("ffffff"), # Diamond White
	Color("ff55a3"), # Rose
	Color("38ef7d")  # Emerald
]

const CONFIGURACOES_DIALOG_SCENE = preload("res://scenes/menus/configuracoes_dialog.tscn")

var panel:Control
var card:PanelContainer
var resume_button:Button
var config_button:Button
var previous_mouse_mode:Input.MouseMode
var pause_audio:AudioStreamPlayer
var glitter_overlay:Control
var particles:Array[Dictionary] = []
var configuracoes_dialog:CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	pause_audio = AudioStreamPlayer.new()
	pause_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_audio.stream = PAUSE_SOUND
	pause_audio.volume_db = -8.0
	add_child(pause_audio)
	configuracoes_dialog = CONFIGURACOES_DIALOG_SCENE.instantiate()
	add_child(configuracoes_dialog)
	_build_panel()
	panel.visible = false

func _unhandled_input(event:InputEvent) -> void:
	if is_instance_valid(configuracoes_dialog) and configuracoes_dialog.visible:
		return
	if get_parent().exit_started or get_parent().death_in_progress:
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
		if is_instance_valid(pause_audio):
			pause_audio.play()
		_spawn_glitter_explosion()
		if is_instance_valid(card):
			card.pivot_offset = Vector2(220.0, 172.0)
			card.scale = Vector2(0.7, 0.7)
			var tween := create_tween().bind_node(self)
			tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		if is_instance_valid(configuracoes_dialog) and configuracoes_dialog.visible:
			configuracoes_dialog.fechar()
		Input.mouse_mode = previous_mouse_mode
		particles.clear()
		if is_instance_valid(glitter_overlay):
			glitter_overlay.queue_redraw()
	get_tree().paused = panel.visible

func _spawn_glitter_explosion() -> void:
	particles.clear()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	for i in range(170):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(260.0, 950.0)
		var shape := randi() % 3
		particles.append({
			"pos": center + Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0)),
			"vel": Vector2(cos(angle) * speed, sin(angle) * speed * 0.85),
			"color": GLITTER_COLORS[randi() % GLITTER_COLORS.size()],
			"size": randf_range(5.0, 12.0),
			"shape": shape,
			"rotation": randf_range(0.0, TAU),
			"spin": randf_range(-10.0, 10.0),
			"shimmer": randf_range(0.0, TAU),
			"shimmer_speed": randf_range(8.0, 18.0),
			"life": 0.0,
			"max_life": randf_range(1.2, 2.3),
			"gravity": randf_range(280.0, 480.0),
			"drag": randf_range(0.965, 0.985)
		})
	if is_instance_valid(glitter_overlay):
		glitter_overlay.queue_redraw()

func _process(delta:float) -> void:
	if particles.is_empty():
		return
	var i := particles.size() - 1
	while i >= 0:
		var p:Dictionary = particles[i]
		p["life"] += delta
		if p["life"] >= p["max_life"]:
			particles.remove_at(i)
		else:
			p["vel"].y += p["gravity"] * delta
			p["vel"].x *= p["drag"]
			p["vel"].y *= p["drag"]
			p["pos"] += p["vel"] * delta
			p["rotation"] += p["spin"] * delta
			p["shimmer"] += delta * p["shimmer_speed"]
		i -= 1
	if is_instance_valid(glitter_overlay):
		glitter_overlay.queue_redraw()

func _on_glitter_draw() -> void:
	if not is_instance_valid(glitter_overlay):
		return
	for p in particles:
		var progress:float = p["life"] / p["max_life"]
		var fade:float = clampf(1.0 - progress, 0.0, 1.0)
		var shimmer:float = 0.65 + sin(p["shimmer"]) * 0.35
		var alpha:float = fade * shimmer
		if alpha <= 0.01:
			continue
		var color:Color = p["color"]
		color.a = alpha
		var pos:Vector2 = p["pos"]
		var size:float = p["size"] * (0.8 + shimmer * 0.4)
		var rot:float = p["rotation"]

		match p["shape"]:
			0:
				# 4-pointed sparkle / star
				var arm_x := Vector2(cos(rot), sin(rot)) * size
				var arm_y := Vector2(-sin(rot), cos(rot)) * size
				var w_ratio := 0.28
				var points := PackedVector2Array([
					pos + arm_x,
					pos + arm_y * w_ratio,
					pos - arm_x,
					pos - arm_y * w_ratio
				])
				glitter_overlay.draw_colored_polygon(points, color)
				var points2 := PackedVector2Array([
					pos + arm_y,
					pos + arm_x * w_ratio,
					pos - arm_y,
					pos - arm_x * w_ratio
				])
				glitter_overlay.draw_colored_polygon(points2, color)
				var white_core := Color.WHITE
				white_core.a = alpha * 0.85
				glitter_overlay.draw_circle(pos, size * 0.22, white_core)
			1:
				# Glowing circle with halo
				var halo := color
				halo.a = alpha * 0.35
				glitter_overlay.draw_circle(pos, size * 1.35, halo)
				glitter_overlay.draw_circle(pos, size * 0.65, color)
				var center_dot := Color.WHITE
				center_dot.a = alpha * 0.85
				glitter_overlay.draw_circle(pos, size * 0.28, center_dot)
			2:
				# Tumbling diamond / rectangular confetti
				var aspect:float = absf(sin(p["shimmer"])) * 0.8 + 0.2
				var vx := Vector2(cos(rot), sin(rot)) * size
				var vy := Vector2(-sin(rot), cos(rot)) * (size * aspect)
				var poly := PackedVector2Array([
					pos - vx - vy,
					pos + vx - vy,
					pos + vx + vy,
					pos - vx + vy
				])
				glitter_overlay.draw_colored_polygon(poly, color)

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
	pentagram.offset_left = -400.0
	pentagram.offset_top = -400.0
	pentagram.offset_right = 400.0
	pentagram.offset_bottom = 400.0
	pentagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pentagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pentagram.modulate = Color(0.93, 0.53, 0.73, 0.42)
	pentagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pentagram)

	card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-220.0, -172.0)
	card.custom_minimum_size = Vector2(440.0, 344.0)
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
	config_button = _button(tr("MENU_SETTINGS"), Color("5c94d4"))
	config_button.pressed.connect(func():
		if is_instance_valid(configuracoes_dialog):
			configuracoes_dialog.abrir()
	)
	column.add_child(config_button)
	var menu_button := _button(tr("PLATFORM_BACK_MENU"), Color("897cc6"))
	menu_button.pressed.connect(_return_to_menu)
	column.add_child(menu_button)

	resume_button.focus_neighbor_bottom = config_button.get_path()
	config_button.focus_neighbor_top = resume_button.get_path()
	config_button.focus_neighbor_bottom = menu_button.get_path()
	menu_button.focus_neighbor_top = config_button.get_path()

	glitter_overlay = Control.new()
	glitter_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitter_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glitter_overlay.draw.connect(_on_glitter_draw)
	panel.add_child(glitter_overlay)

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
