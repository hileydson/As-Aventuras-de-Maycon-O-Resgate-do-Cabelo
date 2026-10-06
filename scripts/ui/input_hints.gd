extends Node

# Observa a entrada sem consumir eventos nem modificar o InputMap.
signal device_changed

const HINT_GROUP := "dynamic_input_hints"
const AXIS_THRESHOLD := 0.35
const MOUSE_THRESHOLD := 3.0
var using_gamepad:bool = false
var active_gamepad:int = -1
var player_one_gamepad:bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	device_changed.connect(refresh)

func _input(event:InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_use_gamepad(event.device)
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= AXIS_THRESHOLD:
		_use_gamepad(event.device)
	elif event is InputEventKey and event.pressed and not event.echo:
		_use_keyboard_mouse()
	elif event is InputEventMouseButton and event.pressed:
		_use_keyboard_mouse()
	elif event is InputEventMouseMotion and event.relative.length() >= MOUSE_THRESHOLD:
		_use_keyboard_mouse()

func _use_gamepad(device:int) -> void:
	var changed := not using_gamepad or active_gamepad != device
	using_gamepad = true
	active_gamepad = device
	if device == 0 and not player_one_gamepad:
		player_one_gamepad = true
		changed = true
	if changed:
		device_changed.emit()

func _use_keyboard_mouse() -> void:
	var changed := using_gamepad or player_one_gamepad
	using_gamepad = false
	active_gamepad = -1
	player_one_gamepad = false
	if changed:
		device_changed.emit()

func _on_joy_connection_changed(device:int, connected:bool) -> void:
	if not connected:
		if device == active_gamepad:
			_use_keyboard_mouse()
		elif device == 0 and player_one_gamepad:
			player_one_gamepad = false
			device_changed.emit()

func _notification(what:int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		refresh.call_deferred()

func is_gamepad(player_device:int = -1) -> bool:
	if player_device == 0:
		return player_one_gamepad
	if player_device > 0:
		return true # A segunda tela recebe entrada exclusivamente do controle.
	return using_gamepad

func text(key:String, player_device:int = -1) -> String:
	var variant := key + ("_PAD" if is_gamepad(player_device) else "_KBM")
	var translated := TranslationServer.translate(variant)
	return TranslationServer.translate(key) if translated == variant else translated

func bind_visibility(node:CanvasItem, gamepad:bool, player_device:int = -1) -> void:
	node.set_meta("input_hint_device", "pad" if gamepad else "kbm")
	node.set_meta("input_hint_player", player_device)
	_register(node)

func bind_texture(node:CanvasItem, keyboard_texture:Texture2D, pad_texture:Texture2D) -> void:
	node.set_meta("input_hint_textures", [keyboard_texture, pad_texture])
	_register(node)

func bind_text(node:Node, key:String) -> void:
	node.set_meta("input_hint_text", key)
	_register(node)

func _register(node:Node) -> void:
	if not node.is_in_group(HINT_GROUP):
		node.add_to_group(HINT_GROUP)
	_apply(node)

func _on_node_added(node:Node) -> void:
	# O Viewport entrega _input em ordem inversa. Observa antes de menus que
	# marcam o evento como tratado, inclusive quando o jogo está pausado.
	if node != self and node.get_parent() == get_tree().root:
		get_tree().root.move_child.call_deferred(self, -1)
	if node.has_meta("input_hint_device") or node.has_meta("input_hint_text") or node.has_meta("input_hint_textures"):
		_register(node)

func refresh() -> void:
	for node in get_tree().get_nodes_in_group(HINT_GROUP):
		_apply(node)

func _apply(node:Node) -> void:
	var pad := is_gamepad(int(node.get_meta("input_hint_player", -1)))
	if node.has_meta("input_hint_device"):
		node.set("visible", pad if node.get_meta("input_hint_device") == "pad" else not pad)
	if node.has_meta("input_hint_textures"):
		var textures:Array = node.get_meta("input_hint_textures")
		node.set("texture", textures[1] if pad else textures[0])
	if node.has_meta("input_hint_text"):
		node.set("text", text(str(node.get_meta("input_hint_text"))))
