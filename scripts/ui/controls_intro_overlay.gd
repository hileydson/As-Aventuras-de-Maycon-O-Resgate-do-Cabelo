extends CanvasLayer

const PAUSE_VISUAL = preload("res://scripts/ui/pause_visual.gd")
# Perfil de controles exibido no card; cada fase informa o seu antes de entrar na árvore.
var profile: String = "2d"
var elapsed: float = 0.0
var prompt: Label
var active: bool = false
var previous_pause_block: bool = false
var opened_at_msec: int = 0
var input_actions: Array[StringName] = []

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
	var card := PAUSE_VISUAL.add_controls_card(overlay, profile, Vector2.ZERO)
	if is_instance_valid(card):
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
	opened_at_msec = Time.get_ticks_msec()
	input_actions = InputMap.get_actions()
	active = true
	get_tree().paused = true

func _process(_delta: float) -> void:
	elapsed = float(Time.get_ticks_msec() - opened_at_msec) / 1000.0
	prompt.modulate.a = 1.0 if elapsed >= 2.0 else 0.0
	if active and elapsed >= 2.0:
		for action in input_actions:
			if Input.is_action_just_pressed(action):
				finish()
				break

func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch or event is InputEventAction):
		get_viewport().set_input_as_handled()
		if Time.get_ticks_msec() - opened_at_msec >= 2000:
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
