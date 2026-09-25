class_name DungeonPlayer
extends CharacterBody3D

signal interact_pressed
signal fired(origin:Vector3, direction:Vector3)
signal flashlight_toggled(enabled:bool)

@export var walk_speed:float = 4.2
@export var sprint_speed:float = 6.8
@export var mouse_sensitivity:float = 0.0022
@export var joy_sensitivity:float = 2.4

@onready var head:Node3D = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var flashlight:SpotLight3D = $Head/Camera3D/Flashlight
@onready var muzzle_light:OmniLight3D = $Head/Camera3D/MuzzleLight

var has_flashlight:bool = false
var flashlight_on:bool = false
var has_gun:bool = false
var controls_enabled:bool = true
var fire_cooldown:float = 0.0
var head_bob_time:float = 0.0
var base_head_y:float = 1.58
var gun_view:Node3D
var gun_rest_position:Vector3 = Vector3(0.38, -0.36, -0.72)

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	flashlight.visible = false
	muzzle_light.visible = false
	build_view_gun()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion && controls_enabled && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x - event.relative.y * mouse_sensitivity, -1.35, 1.35)
	if event is InputEventKey && event.pressed && event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if !controls_enabled:
		return
	var is_pressed_event:bool = (event is InputEventKey || event is InputEventMouseButton || event is InputEventJoypadButton) && event.pressed
	if !is_pressed_event || event.is_echo():
		return
	if (event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT) || (event is InputEventJoypadButton && event.button_index == JOY_BUTTON_Y):
		toggle_flashlight()
	elif (event is InputEventKey && event.physical_keycode == KEY_E) || (event is InputEventJoypadButton && event.button_index == JOY_BUTTON_X):
		interact_pressed.emit()

func _physics_process(delta:float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if !is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	if !controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if Input.is_action_pressed("run") else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4 && is_on_floor()
	if moving:
		head_bob_time += delta * (11.0 if speed == sprint_speed else 8.0)
		head.position.y = base_head_y + sin(head_bob_time) * 0.035
	else:
		head.position.y = lerpf(head.position.y, base_head_y, delta * 8.0)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.12:
		rotate_y(-look.x * joy_sensitivity * delta)
		head.rotation.x = clamp(head.rotation.x - look.y * joy_sensitivity * delta, -1.35, 1.35)
	if has_gun && fire_cooldown <= 0.0 && (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) || Input.is_action_pressed("tiro")):
		fire_cooldown = 0.095
		fire()

func set_flashlight_available(value:bool) -> void:
	has_flashlight = value
	if !value:
		flashlight_on = false
	flashlight.visible = flashlight_on

func set_gun_available(value:bool) -> void:
	has_gun = value
	if is_instance_valid(gun_view):
		gun_view.visible = value

func toggle_flashlight() -> void:
	if !has_flashlight:
		return
	flashlight_on = !flashlight_on
	flashlight.visible = flashlight_on
	flashlight_toggled.emit(flashlight_on)

func fire() -> void:
	var direction := -camera.global_transform.basis.z
	fired.emit(camera.global_position, direction)
	muzzle_light.visible = true
	var tween := create_tween()
	tween.tween_interval(0.035)
	tween.tween_callback(func(): muzzle_light.visible = false)
	camera.rotation.z = randf_range(-0.012, 0.012)
	create_tween().tween_property(camera, "rotation:z", 0.0, 0.07)
	if is_instance_valid(gun_view):
		gun_view.position = gun_rest_position + Vector3(0, 0.02, 0.09)
		create_tween().tween_property(gun_view, "position", gun_rest_position, 0.075)

func build_view_gun() -> void:
	gun_view = Node3D.new()
	gun_view.name = "MachineGunView"
	gun_view.position = gun_rest_position
	gun_view.visible = false
	camera.add_child(gun_view)
	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.055, 0.06, 0.065)
	dark_metal.metallic = 0.88
	dark_metal.roughness = 0.32
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.105, 0.045)
	wood.roughness = 0.85
	add_gun_box(Vector3.ZERO, Vector3(0.22, 0.2, 0.72), dark_metal)
	add_gun_box(Vector3(0, 0.025, -0.56), Vector3(0.08, 0.08, 0.55), dark_metal)
	add_gun_box(Vector3(0, -0.08, 0.47), Vector3(0.2, 0.3, 0.35), wood)
	add_gun_box(Vector3(0.12, -0.18, 0.06), Vector3(0.09, 0.33, 0.12), dark_metal)

func add_gun_box(position_value:Vector3, size:Vector3, material:Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position_value
	gun_view.add_child(mesh_instance)

func camera_forward() -> Vector3:
	return -camera.global_transform.basis.z
