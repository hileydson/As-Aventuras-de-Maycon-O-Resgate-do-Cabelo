extends Control

var realtime_button:Button
var strategic_button:Button
var overlay:ColorRect

func _ready() -> void:
	build_interface()
	realtime_button.grab_focus()

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
	title.text = tr("BATTLE_MODE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("ffd166"))
	content.add_child(title)

	var subtitle = Label.new()
	subtitle.text = tr("BATTLE_MODE_SUBTITLE")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var cards = HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 24)
	content.add_child(cards)

	realtime_button = create_mode_card(
		tr("BATTLE_MODE_REALTIME_TITLE"),
		tr("BATTLE_MODE_REALTIME_DESC"),
		Color("d1495b")
	)
	strategic_button = create_mode_card(
		tr("BATTLE_MODE_STRATEGIC_TITLE"),
		tr("BATTLE_MODE_STRATEGIC_DESC"),
		Color("277da1")
	)
	cards.add_child(realtime_button)
	cards.add_child(strategic_button)
	realtime_button.pressed.connect(select_mode.bind(Global.battle_mode_realtime))
	strategic_button.pressed.connect(select_mode.bind(Global.battle_mode_strategic))

	var hint = Label.new()
	hint.text = tr("BATTLE_MODE_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color("9fb3c8"))
	content.add_child(hint)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func create_mode_card(title_text:String, description:String, accent:Color) -> Button:
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

func select_mode(mode:String) -> void:
	Global.battle_mode = mode
	realtime_button.disabled = true
	strategic_button.disabled = true
	var tween = create_tween()
	tween.tween_property(overlay, "color", Color.BLACK, 0.55)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/intro_game.tscn")
