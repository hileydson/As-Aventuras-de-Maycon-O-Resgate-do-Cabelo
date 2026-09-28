class_name PauseVisual
extends RefCounted

const MENU_FONT:Font = preload("res://assets/fonts/contrast.ttf")
const BACKDROP_SHADER:Shader = preload("res://scenes/menus/pause_backdrop.gdshader")

static func configure_backdrop(backdrop:ColorRect, alpha:float = 0.96) -> void:
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.color = Color.WHITE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	material.set_shader_parameter("background_alpha", alpha)
	backdrop.material = material


static func style_title(label:Label, font_size:int = 46) -> void:
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.92))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.07, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.uppercase = true


static func style_hint(label:Label, font_size:int = 15) -> void:
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.67, 0.80, 0.82))


static func style_button(button:Button, is_danger:bool = false) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(330.0, 52.0)
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.78) if is_danger else Color(0.84, 0.93, 0.93))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.82))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.82))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.03, 0.04, 0.35) if is_danger else Color(0.015, 0.085, 0.11, 0.28)
		style.border_width_left = 3
		style.border_color = Color(0.65, 0.20, 0.20, 0.58) if is_danger else Color(0.20, 0.52, 0.60, 0.52)
		style.content_margin_left = 20.0
		style.content_margin_right = 16.0
		style.set_corner_radius_all(4)
		if state == "hover" or state == "focus" or state == "pressed":
			style.bg_color = Color(0.45, 0.08, 0.12, 0.76) if is_danger else Color(0.05, 0.20, 0.24, 0.76)
			style.border_color = Color(1.0, 0.35, 0.35) if is_danger else Color(0.67, 0.92, 0.92)
		elif state == "disabled":
			style.bg_color.a *= 0.35
			style.border_color.a *= 0.45
		button.add_theme_stylebox_override(state, style)


static func add_header(parent:Control, title_text:String, hint_text:String, left:float = 70.0) -> Dictionary:
	var title := Label.new()
	title.name = "ModernPauseTitle"
	title.position = Vector2(left, 55.0)
	title.size = Vector2(440.0, 66.0)
	title.text = title_text
	style_title(title)
	parent.add_child(title)
	var rule := ColorRect.new()
	rule.name = "ModernPauseRule"
	rule.position = Vector2(left, 127.0)
	rule.size = Vector2(360.0, 2.0)
	rule.color = Color(0.35, 0.72, 0.77, 0.72)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)
	var hint := Label.new()
	hint.name = "ModernPauseHint"
	hint.position = Vector2(left, 140.0)
	hint.size = Vector2(440.0, 30.0)
	hint.text = hint_text
	style_hint(hint)
	parent.add_child(hint)
	return {"title": title, "rule": rule, "hint": hint}


static func add_side_glow(parent:Control, x:float = 470.0) -> void:
	var line := ColorRect.new()
	line.name = "ModernPauseDivider"
	line.position = Vector2(x, 54.0)
	line.size = Vector2(1.0, 540.0)
	line.color = Color(0.30, 0.70, 0.75, 0.32)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	var accent := ColorRect.new()
	accent.name = "ModernPauseAccent"
	accent.position = Vector2(x - 1.0, 184.0)
	accent.size = Vector2(3.0, 94.0)
	accent.color = Color(0.67, 0.92, 0.92, 0.9)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(accent)


static func make_info_card(parent:Control, position:Vector2, size:Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "ModernPauseInfoCard"
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.07, 0.09, 0.64)
	style.border_color = Color(0.20, 0.52, 0.60, 0.44)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	return column


static func add_action_row(parent:VBoxContainer, action_text:String, key_texture:Texture2D, mouse_texture:Texture2D, pad_texture:Texture2D, accent:Color, wide_key:bool = false) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 38.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.012, 0.045, 0.06, 0.72)
	row_style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(5)
	row_style.content_margin_left = 9.0
	row_style.content_margin_right = 8.0
	row_style.content_margin_top = 3.0
	row_style.content_margin_bottom = 3.0
	row.add_theme_stylebox_override("panel", row_style)
	parent.add_child(row)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var label := Label.new()
	label.text = action_text.to_upper()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", accent)
	content.add_child(label)
	_add_input_icon(content, key_texture, Vector2(38.0, 24.0) if wide_key else Vector2(24.0, 24.0))
	if mouse_texture:
		_add_input_icon(content, mouse_texture, Vector2(24.0, 24.0))
	var divider := Label.new()
	divider.text = "/"
	divider.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	divider.add_theme_font_override("font", MENU_FONT)
	divider.add_theme_font_size_override("font_size", 11)
	divider.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.36))
	content.add_child(divider)
	_add_input_icon(content, pad_texture, Vector2(24.0, 24.0))


static func _add_input_icon(parent:HBoxContainer, texture:Texture2D, minimum_size:Vector2) -> void:
	if not texture:
		return
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = minimum_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


static func animate_open(control:Control, menu:Control = null) -> void:
	control.modulate.a = 0.0
	var reveal := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(control, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(menu):
		var destination := menu.position
		menu.position = destination + Vector2(-28.0, 0.0)
		menu.modulate.a = 0.0
		reveal.parallel().tween_property(menu, "position", destination, 0.34).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		reveal.parallel().tween_property(menu, "modulate:a", 1.0, 0.26)
