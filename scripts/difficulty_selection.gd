extends Control

var normal_button: Button
var easy_button: Button
var overlay: ColorRect

func _ready() -> void:
	build_interface()
	normal_button.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background = ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("101525")
	add_child(background)

	var glow = ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.position = Vector2(-520, -245)
	glow.size = Vector2(1040, 490)
	glow.color = Color(0.12, 0.18, 0.3, 0.95)
	add_child(glow)

	var content = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-500, -280)
	content.size = Vector2(1000, 560)
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var title = Label.new()
	title.text = tr("DIFFICULTY_SELECTION_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("ffd166"))
	content.add_child(title)

	var subtitle = Label.new()
	subtitle.text = tr("DIFFICULTY_SELECTION_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var cards = HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 24)
	content.add_child(cards)

	easy_button = create_card(
		tr("DIFFICULTY_EASY_TITLE"),
		tr("DIFFICULTY_EASY_DESC"),
		Color("06d6a0")
	)
	normal_button = create_card(
		tr("DIFFICULTY_NORMAL_TITLE"),
		tr("DIFFICULTY_NORMAL_DESC"),
		Color("277da1")
	)
	cards.add_child(easy_button)
	cards.add_child(normal_button)
	easy_button.focus_neighbor_right = normal_button.get_path()
	normal_button.focus_neighbor_left = easy_button.get_path()
	easy_button.pressed.connect(select_difficulty.bind(Global.DIFFICULTY_EASY))
	normal_button.pressed.connect(select_difficulty.bind(Global.DIFFICULTY_NORMAL))

	var hint = Label.new()
	hint.text = tr("DIFFICULTY_SELECTION_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("9fb3c8"))
	content.add_child(hint)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func create_card(title_text: String, description: String, accent: Color) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(488, 350)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = title_text + "\n\n" + description
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.07, 0.12, 0.98)
	normal.border_color = Color(accent, 0.55)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 30
	normal.content_margin_right = 30
	var focus = normal.duplicate()
	focus.bg_color = Color(accent, 0.38)
	focus.border_color = accent
	focus.set_border_width_all(6)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	return button

func select_difficulty(diff: String) -> void:
	Global.set_difficulty(diff, true)
	normal_button.disabled = true
	easy_button.disabled = true
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color.BLACK, 0.45)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/battle_mode_selection.tscn")
