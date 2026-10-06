extends CanvasLayer

const PAUSE_VISUAL = preload("res://scripts/ui/pause_visual.gd")
var elapsed: float = 0.0
var prompt: Label
var active: bool = false
var previous_pause_block: bool = false

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := ColorRect.new()
	overlay.name = "ControlsIntroOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.84)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var card := PAUSE_VISUAL.add_controls_card(overlay, "2d", Vector2.ZERO)
	card.reparent(column)
	card.custom_minimum_size = Vector2(340, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pause_hint := Label.new()
	pause_hint.name = "ControlsPauseHint"
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.text = tr("CONTROLS_PAUSE_HINT")
	PAUSE_VISUAL.style_hint(pause_hint, 20)
	pause_hint.add_theme_color_override("font_color", Color(1, 0.97, 0.82))
	column.add_child(pause_hint)
	prompt = Label.new()
	prompt.name = "ControlsIntroPrompt"
	prompt.custom_minimum_size = Vector2(500, 45)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.text = tr("BATTLE_CONTROLS_PROMPT")
	PAUSE_VISUAL.style_hint(prompt, 17)
	prompt.add_theme_color_override("font_color", Color(1, 0.97, 0.82))
	prompt.modulate.a = 0.0
	column.add_child(prompt)
	previous_pause_block = Global.block_pause_before_prologo
	Global.block_pause_before_prologo = true
	active = true
	get_tree().paused = true

func _process(delta: float) -> void:
	elapsed += delta
	prompt.modulate.a = 1.0 if elapsed >= 2.0 else 0.0

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()
		if elapsed >= 2.0:
			finish()

func finish() -> void:
	if not active:
		return
	active = false
	Global.block_pause_before_prologo = previous_pause_block
	get_tree().paused = false
	queue_free()

func _exit_tree() -> void:
	if active:
		Global.block_pause_before_prologo = previous_pause_block
		get_tree().paused = false
