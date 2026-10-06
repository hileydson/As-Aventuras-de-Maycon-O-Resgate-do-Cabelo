extends SceneTree

# Regressão de apresentação: usa eventos reais do Viewport, inclusive consumidos
# por um menu pausado, sem abrir fases nem modificar saves.
class InputConsumer extends Control:
	func _input(_event:InputEvent) -> void:
		get_viewport().set_input_as_handled()

var failures:int = 0
var hints:Node
var scene:Control

func _init() -> void:
	call_deferred("run")

func check(label:String, condition:bool) -> void:
	print(("OK " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func key(pressed:bool = true, echo:bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.physical_keycode = KEY_Q
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func pad(device:int = 0, pressed:bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)

func axis(value:float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)

func mouse_motion(distance:float) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(distance, 0)
	Input.parse_input_event(event)

func check_icons(gamepad:bool) -> bool:
	for node in get_nodes_in_group("dynamic_input_hints"):
		if node.has_meta("input_hint_device") and not node.has_meta("input_hint_player"):
			if node.visible != (gamepad == (node.get_meta("input_hint_device") == "pad")):
				return false
		elif node.has_meta("input_hint_device") and node.get_meta("input_hint_player") == -1:
			if node.visible != (gamepad == (node.get_meta("input_hint_device") == "pad")):
				return false
	return true

func run() -> void:
	hints = root.get_node("InputHints")
	TranslationServer.set_locale("en")
	var actions_before := InputMap.get_actions()
	scene = Control.new()
	scene.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(scene)
	current_scene = scene
	var consumer := InputConsumer.new()
	consumer.process_mode = Node.PROCESS_MODE_ALWAYS
	scene.add_child(consumer)
	var visual = load("res://scripts/ui/pause_visual.gd")
	for profile in ["prologue", "2d", "realtime", "well", "invader", "resgate", "elden", "ace", "first_3d", "dungeon", "move_only"]:
		var card:PanelContainer = visual.add_controls_card(scene, profile, Vector2.ZERO)
		check("controls card loads: " + profile, is_instance_valid(card))
	# Valida também os indicadores gravados nas cenas, sem executar as fases.
	for path in ["res://scenes/batalha_2d.tscn", "res://scenes/sangue_fill_scene.tscn", "res://scenes/3D/cenario_3d_bofore_castle_1.tscn", "res://scenes/3D/maycon_3d.tscn"]:
		var fixture:Node = load(path).instantiate()
		var marked:int = 0
		for node in fixture.find_children("*", "", true, false):
			if node.has_meta("input_hint_device"):
				marked += 1
				node.owner = null
				node.reparent(scene)
		check("scene indicators load: " + path.get_file(), marked > 0)
		fixture.free()
	var battle:Node = load("res://scripts/realtime_battle.gd").new()
	scene.add_child(battle._create_action_row("Punch", Color.WHITE, visual.KEY_Q_TEXTURE, visual.MOUSE_SHOOT_TEXTURE, visual.PAD_Y_TEXTURE, false))
	scene.add_child(battle._create_action_row("Dash", Color.WHITE, visual.KEY_SPACE_TEXTURE, null, visual.PAD_A_TEXTURE, true))
	battle.free()
	var header:Dictionary = visual.add_header(scene, "Pause", scene.tr("MENU_PAUSE_HINT"))
	var objective := Label.new()
	scene.add_child(objective)
	hints.bind_text(objective, "DUNGEON_PROMPT_GUN")
	var icon := TextureRect.new()
	scene.add_child(icon)
	var key_texture:Texture2D = load("res://assets/novas_imagens/buttons/Q_Key_Light.png")
	var pad_texture:Texture2D = load("res://assets/novas_imagens/buttons/360_Y.png")
	hints.bind_texture(icon, key_texture, pad_texture)
	await process_frame
	await process_frame
	check("keyboard is the initial device", not hints.using_gamepad and check_icons(false))
	check("keyboard hints show only ESC and E", header.hint.text == "ESC to continue" and objective.text == "[E] TAKE MACHINE GUN")
	pad()
	await process_frame
	check("consumed joypad event switches all cards and textures", hints.using_gamepad and check_icons(true) and icon.texture == pad_texture)
	check("controller hints show only START and A", header.hint.text == "START to continue" and objective.text == "[A] TAKE MACHINE GUN")
	key(false)
	key(true, true)
	mouse_motion(0.5)
	axis(0.12)
	check("releases, key echoes, tiny mouse motion and stick drift do not switch", hints.using_gamepad)
	paused = true
	key()
	await process_frame
	check("consumed keyboard event switches while paused", paused and not hints.using_gamepad and check_icons(false) and icon.texture == key_texture)
	axis(0.8)
	await process_frame
	check("stick switches while paused", hints.using_gamepad and check_icons(true))
	mouse_motion(8.0)
	await process_frame
	check("mouse movement switches while paused", not hints.using_gamepad and check_icons(false))
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	pad()
	Input.parse_input_event(mouse)
	await process_frame
	check("mouse click switches device", not hints.using_gamepad)
	var player_one := Sprite2D.new()
	var player_two := Sprite2D.new()
	scene.add_child(player_one)
	scene.add_child(player_two)
	hints.bind_visibility(player_one, true, 0)
	hints.bind_visibility(player_two, true, 1)
	pad(1)
	await process_frame
	check("player two does not change player one's HUD", not player_one.visible and player_two.visible)
	pad(0)
	await process_frame
	check("player one controller updates independently", player_one.visible and player_two.visible)
	key()
	await process_frame
	check("player two keeps controller hints when player one uses keyboard", not player_one.visible and player_two.visible)
	pad()
	await process_frame
	hints._on_joy_connection_changed(0, false)
	check("disconnect falls back to keyboard", not hints.using_gamepad and check_icons(false))
	TranslationServer.set_locale("pt")
	await process_frame
	await process_frame
	check("language change preserves the selected device", header.hint.text == "ESC para continuar" and objective.text == "[E] PEGAR METRALHADORA")
	var hidden_parent := Control.new()
	hidden_parent.visible = false
	scene.add_child(hidden_parent)
	var hidden_icon := Sprite2D.new()
	hidden_parent.add_child(hidden_icon)
	hints.bind_visibility(hidden_icon, true)
	pad()
	check("switching never reveals a gameplay-hidden container", not hidden_parent.visible and not hidden_icon.is_visible_in_tree())
	check("input actions are preserved", InputMap.get_actions() == actions_before)
	paused = false
	key(false)
	pad(0, false)
	pad(1, false)
	check("scene stays in place", current_scene == scene)
	scene.queue_free()
	await process_frame
	hints.refresh()
	print("DYNAMIC INPUT HINTS: %d failures" % failures)
	quit(1 if failures else 0)
