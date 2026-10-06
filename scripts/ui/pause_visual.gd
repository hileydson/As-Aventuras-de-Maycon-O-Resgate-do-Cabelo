class_name PauseVisual
extends RefCounted

const MENU_FONT:Font = preload("res://assets/fonts/contrast_menu.tres")
const BACKDROP_SHADER:Shader = preload("res://scenes/menus/pause_backdrop.gdshader")
const PENTAGRAM_TEXTURE:Texture2D = preload("res://assets/3D/pentagram_item.png")
const KEY_Q_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/Q_Key_Light.png")
const KEY_V_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/V_Key_Light.png")
const KEY_F_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/F_Key_Light.png")
const KEY_W_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/W_Key_Light.png")
const KEY_SPACE_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/Blank_White_Super_Wide.png")
const KEY_SHIFT_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/shift.png")
const KEY_ENTER_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/Blank_White_Enter.png")
const KEY_DIRECTIONS_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/ButtonIcon-Switch-Dpad.png")
const MOUSE_SHOOT_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/mouse_trigger.png")
const MOUSE_ALT_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/mouse_right_click.png")
const PAD_A_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/360_A.png")
const PAD_B_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/360_B.png")
const PAD_X_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/360_X.png")
const PAD_Y_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/360_Y.png")
const PAD_DIRECTIONS_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/PS5_Dpad.png")
const PAD_TRIGGER_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/button_trigger.png")
const PAD_SHOULDER_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/rb_xbox.png")
const PAD_LEFT_SHOULDER_TEXTURE:Texture2D = preload("res://assets/novas_imagens/buttons/lb_xbox.png")

const MAYCON_WALK_TEXTURES:Array[Texture2D] = [
	preload("res://assets/images/jamela_INTRO_0.png"),
	preload("res://assets/images/jamela_INTRO_1.png"),
	preload("res://assets/images/jamela_INTRO_2.png"),
	preload("res://assets/images/jamela_INTRO_3.png"),
	preload("res://assets/images/jamela_INTRO_4.png"),
	preload("res://assets/images/jamela_INTRO_5.png"),
	preload("res://assets/images/jamela_INTRO_6.png"),
	preload("res://assets/images/jamela_INTRO_7.png"),
	preload("res://assets/images/jamela_INTRO2_0.png"),
	preload("res://assets/images/jamela_INTRO2_1.png"),
	preload("res://assets/images/jamela_INTRO2_2.png"),
	preload("res://assets/images/jamela_INTRO2_3.png"),
	preload("res://assets/images/jamela_INTRO2_4.png")
]

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


static func style_hint(label:Label, font_size:int = 17) -> void:
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.79, 0.89, 0.91))


static func style_button(button:Button, is_danger:bool = false) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(330.0, 52.0)
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 22)
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


static func add_rotating_pentagram(parent:Control) -> TextureRect:
	var pentagram := TextureRect.new()
	pentagram.name = "RotatingPentagram"
	pentagram.texture = PENTAGRAM_TEXTURE
	pentagram.position = Vector2(216.0, -36.0)
	pentagram.size = Vector2(720.0, 720.0)
	pentagram.pivot_offset = pentagram.size * 0.5
	pentagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pentagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pentagram.modulate = Color(0.30, 0.82, 0.88, 0.115)
	pentagram.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pentagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pentagram)
	parent.move_child(pentagram, 0)
	var rotation_tween := pentagram.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	rotation_tween.tween_property(pentagram, "rotation", TAU, 32.0).from(0.0).set_trans(Tween.TRANS_LINEAR)
	return pentagram


static func add_walking_maycon(parent:Control) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 5.0)
	frames.set_animation_loop("walk", false)
	for texture in MAYCON_WALK_TEXTURES:
		frames.add_frame("walk", texture)
	var maycon := AnimatedSprite2D.new()
	maycon.name = "PauseMaycon"
	maycon.sprite_frames = frames
	maycon.animation = "walk"
	maycon.position = Vector2(690.0, 348.0)
	maycon.scale = Vector2(1.58, 1.58)
	maycon.flip_h = true
	maycon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	maycon.z_index = 2
	parent.add_child(maycon)
	return maycon


static func animate_walking_maycon(maycon:AnimatedSprite2D) -> void:
	if not is_instance_valid(maycon):
		return
	maycon.stop()
	maycon.frame = 0
	maycon.frame_progress = 0.0
	maycon.position = Vector2(1180.0, 348.0)
	maycon.rotation = 0.035
	maycon.modulate.a = 0.0
	maycon.play("walk")
	var reveal := maycon.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(maycon, "position", Vector2(690.0, 348.0), 1.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.parallel().tween_property(maycon, "rotation", 0.0, 1.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.parallel().tween_property(maycon, "modulate:a", 1.0, 0.42)


static func add_controls_card(parent:Control, profile:String, position:Vector2 = Vector2(825.0, 142.0)) -> PanelContainer:
	var rows := controls_for(profile)
	if rows.is_empty():
		return null
	var height := 77.0 + float(rows.size()) * 45.0
	var controls_column := make_info_card(parent, position, Vector2(305.0, height))
	var controls_card := controls_column.get_parent() as PanelContainer
	controls_card.name = "PauseControlsCard"
	var controls_title := Label.new()
	controls_title.text = TranslationServer.translate("MENU_CONTROLLER").to_upper()
	style_hint(controls_title, 17)
	controls_title.add_theme_color_override("font_color", Color(0.75, 0.91, 0.92))
	controls_column.add_child(controls_title)
	var controls_rule := ColorRect.new()
	controls_rule.custom_minimum_size = Vector2(0.0, 1.0)
	controls_rule.color = Color(0.35, 0.72, 0.77, 0.5)
	controls_column.add_child(controls_rule)
	for row in rows:
		add_action_row(
			controls_column,
			str(row["label"]),
			row.get("key") as Texture2D,
			row.get("mouse") as Texture2D,
			row.get("pad") as Texture2D,
			row.get("accent", Color(0.35, 0.9, 1.0)) as Color,
			bool(row.get("wide_key", false)),
			row.get("pad_extra") as Texture2D
		)
	return controls_card


static func controls_for(profile:String) -> Array[Dictionary]:
	var move := {
		"label": TranslationServer.translate("PAUSE_MOVE"),
		"key": KEY_DIRECTIONS_TEXTURE,
		"pad": PAD_DIRECTIONS_TEXTURE,
		"accent": Color(0.35, 0.9, 1.0)
	}
	var jump := {
		"label": TranslationServer.translate("POWER_JUMP"),
		"key": KEY_SPACE_TEXTURE,
		"pad": PAD_A_TEXTURE,
		"accent": Color(1.0, 0.88, 0.35),
		"wide_key": true
	}
	var dash := {
		"label": TranslationServer.translate("POWER_DASH"),
		"key": KEY_SPACE_TEXTURE,
		"pad": PAD_A_TEXTURE,
		"accent": Color(0.35, 0.9, 1.0),
		"wide_key": true
	}
	var shoot := {
		"label": TranslationServer.translate("PAUSE_SHOOT"),
		"mouse": MOUSE_SHOOT_TEXTURE,
		"pad": PAD_TRIGGER_TEXTURE,
		"accent": Color(1.0, 0.48, 0.68)
	}
	var run := {
		"label": TranslationServer.translate("MENU_RUN"),
		"key": KEY_SHIFT_TEXTURE,
		"pad": PAD_SHOULDER_TEXTURE,
		"accent": Color(0.55, 0.92, 0.72)
	}
	match profile:
		"move_only":
			return [move]
		"prologue":
			return [jump]
		"2d":
			return [
				{"label": TranslationServer.translate("POWER_PUNCH"), "key": KEY_Q_TEXTURE, "pad": PAD_Y_TEXTURE, "accent": Color(0.35, 0.9, 1.0)},
				{"label": TranslationServer.translate("POWER_KICK"), "key": KEY_W_TEXTURE, "pad": PAD_B_TEXTURE, "accent": Color(1.0, 0.48, 0.68)},
				jump,
				{
					"label": TranslationServer.translate("MENU_RUN"),
					"key": KEY_SHIFT_TEXTURE,
					"pad": PAD_SHOULDER_TEXTURE,
					"pad_extra": PAD_X_TEXTURE,
					"accent": Color(0.55, 0.92, 0.72)
				}
			]
		"realtime":
			return [
				{"label": TranslationServer.translate("POWER_PUNCH"), "key": KEY_Q_TEXTURE, "mouse": MOUSE_SHOOT_TEXTURE, "pad": PAD_Y_TEXTURE, "accent": Color(0.35, 0.9, 1.0)},
				{"label": TranslationServer.translate("POWER_KICK"), "key": KEY_W_TEXTURE, "mouse": MOUSE_ALT_TEXTURE, "pad": PAD_B_TEXTURE, "accent": Color(1.0, 0.48, 0.68)},
				dash
			]
		"well":
			return [
				move,
				dash,
				{"label": TranslationServer.translate("PAUSE_SPECIAL"), "key": KEY_Q_TEXTURE, "pad": PAD_Y_TEXTURE, "accent": Color(1.0, 0.35, 0.42)}
			]
		"invader":
			return [move, dash]
		"resgate":
			# O dash do Resgate Cabeludo fica no B do controle e na tecla V.
			return [
				move,
				jump,
				{"label": TranslationServer.translate("POWER_DASH"), "key": KEY_V_TEXTURE, "pad": PAD_B_TEXTURE, "accent": Color(0.35, 0.9, 1.0)}
			]
		"elden":
			# Arena do Elden Lips: a esquiva troca para o espaço e o B, e o frasco
			# de sangue entra na tecla V com o Y do controle.
			return [
				{"label": TranslationServer.translate("POWER_DASH"), "key": KEY_SPACE_TEXTURE, "pad": PAD_B_TEXTURE, "accent": Color(0.35, 0.9, 1.0), "wide_key": true},
				{"label": TranslationServer.translate("PAUSE_ATTACK"), "key": KEY_Q_TEXTURE, "mouse": MOUSE_SHOOT_TEXTURE, "pad": PAD_X_TEXTURE, "accent": Color(1.0, 0.88, 0.35)},
				{"label": TranslationServer.translate("PAUSE_GUARD"), "key": KEY_F_TEXTURE, "mouse": MOUSE_ALT_TEXTURE, "pad": PAD_LEFT_SHOULDER_TEXTURE, "accent": Color(0.55, 0.92, 0.72)},
				{"label": TranslationServer.translate("PAUSE_POTION"), "key": KEY_V_TEXTURE, "pad": PAD_Y_TEXTURE, "accent": Color(1.0, 0.35, 0.42)}
			]
		"ace":
			return [
				move,
				shoot,
				{"label": TranslationServer.translate("POWER_DASH"), "mouse": MOUSE_ALT_TEXTURE, "pad": PAD_A_TEXTURE, "accent": Color(0.35, 0.9, 1.0)}
			]
		"first_3d":
			return [move, shoot, run]
		"dungeon":
			return [
				move,
				run,
				{"label": TranslationServer.translate("PAUSE_INTERACT"), "key": KEY_ENTER_TEXTURE, "pad": PAD_A_TEXTURE, "accent": Color(1.0, 0.88, 0.35), "wide_key": true},
				shoot
			]
		_:
			return [move, shoot, run]


static func add_action_row(parent:VBoxContainer, action_text:String, key_texture:Texture2D, mouse_texture:Texture2D, pad_texture:Texture2D, accent:Color, wide_key:bool = false, pad_extra_texture:Texture2D = null) -> void:
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
	label.add_theme_font_size_override("font_size", 15)
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
	if pad_extra_texture:
		_add_input_icon(content, pad_extra_texture, Vector2(24.0, 24.0))


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
