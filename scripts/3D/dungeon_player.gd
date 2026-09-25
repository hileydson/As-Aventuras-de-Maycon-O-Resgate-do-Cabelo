class_name DungeonPlayer
extends CharacterBody3D

const STEP_SOUND:AudioStreamMP3 = preload("res://assets/novos_audios/mario_part_sounds/passo.mp3")

signal interact_pressed
signal fired(origin:Vector3, direction:Vector3)
signal flashlight_toggled(enabled:bool)
signal ammo_changed(current:int, reserve:int, weapon_name:String)
signal reload_started
signal reload_finished

@export var walk_speed:float = 4.2
@export var sprint_speed:float = 6.8
@export var mouse_sensitivity:float = 0.0022
@export var joy_sensitivity:float = 2.4

@onready var head:Node3D = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var flashlight:SpotLight3D = $Head/Camera3D/Flashlight
@onready var flashlight_spill:SpotLight3D = $Head/Camera3D/FlashlightSpill
@onready var muzzle_light:OmniLight3D = $Head/Camera3D/MuzzleLight

var has_flashlight:bool = false
var flashlight_on:bool = false
var has_gun:bool = false
var weapon_mode:String = ""
var controls_enabled:bool = true
var fire_cooldown:float = 0.0
var head_bob_time:float = 0.0
var base_head_y:float = 1.58
var gun_view:Node3D
var gun_rest_position:Vector3 = Vector3(0.38, -0.36, -0.72)
var step_audio:AudioStreamPlayer
var step_timer:float = 0.0

var pistol_clip:int = 4
var pistol_reserve:int = 8
const PISTOL_CLIP_SIZE:int = 4

var machinegun_clip:int = 15
var machinegun_reserve:int = 30
const MACHINEGUN_CLIP_SIZE:int = 15

var is_reloading:bool = false
var reload_audio:AudioStreamPlayer
var dry_fire_audio:AudioStreamPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	flashlight.visible = false
	flashlight_spill.visible = false
	muzzle_light.visible = false
	step_audio = AudioStreamPlayer.new()
	step_audio.stream = STEP_SOUND
	step_audio.volume_db = -18.0
	add_child(step_audio)
	
	reload_audio = AudioStreamPlayer.new()
	reload_audio.stream = load("res://assets/novos_audios/gun_load.mp3")
	reload_audio.volume_db = -2.0
	add_child(reload_audio)
	
	dry_fire_audio = AudioStreamPlayer.new()
	dry_fire_audio.stream = load("res://assets/novos_audios/pause_sfxr.wav")
	dry_fire_audio.volume_db = -6.0
	dry_fire_audio.pitch_scale = 1.8
	add_child(dry_fire_audio)
	
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
	elif (event is InputEventKey && event.physical_keycode == KEY_R) || (event is InputEventJoypadButton && event.button_index == JOY_BUTTON_B):
		start_reload()

func _physics_process(delta:float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if !is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	if !controls_enabled:
		_update_footsteps(delta, false, false)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var speed := sprint_speed if is_sprint_pressed() else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4 && is_on_floor()
	_update_footsteps(delta, moving, speed == sprint_speed)
	if moving:
		head_bob_time += delta * (11.0 if speed == sprint_speed else 8.0)
		head.position.y = base_head_y + sin(head_bob_time) * 0.035
	else:
		head.position.y = lerpf(head.position.y, base_head_y, delta * 8.0)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.12:
		rotate_y(-look.x * joy_sensitivity * delta)
		head.rotation.x = clamp(head.rotation.x - look.y * joy_sensitivity * delta, -1.35, 1.35)
	if has_gun && !is_reloading && fire_cooldown <= 0.0 && (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) || Input.is_action_pressed("tiro")):
		fire_cooldown = 0.095 if weapon_mode == "machinegun" else 0.32
		fire()

func is_sprint_pressed() -> bool:
	return (
		Input.is_action_pressed("run")
		or Input.is_key_pressed(KEY_SHIFT)
		or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
		or Input.is_joy_button_pressed(1, JOY_BUTTON_RIGHT_SHOULDER)
	)

func set_flashlight_available(value:bool) -> void:
	has_flashlight = value
	if !value:
		flashlight_on = false
	flashlight.visible = flashlight_on
	flashlight_spill.visible = flashlight_on

func set_gun_available(value:bool) -> void:
	has_gun = value
	if value && weapon_mode == "":
		weapon_mode = "machinegun"
	if is_instance_valid(gun_view):
		gun_view.visible = value
		update_view_gun()

func set_weapon(mode:String) -> void:
	weapon_mode = mode
	has_gun = mode != ""
	if is_instance_valid(gun_view):
		gun_view.visible = has_gun
		update_view_gun()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func toggle_flashlight() -> void:
	if !has_flashlight:
		return
	flashlight_on = !flashlight_on
	flashlight.visible = flashlight_on
	flashlight_spill.visible = flashlight_on
	flashlight_toggled.emit(flashlight_on)

func _update_footsteps(delta:float, moving:bool, running:bool) -> void:
	if !moving:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer > 0.0:
		return
	step_audio.pitch_scale = randf_range(1.02, 1.12) if running else randf_range(0.94, 1.04)
	step_audio.play()
	step_timer = 0.38 if running else 0.46

func get_current_clip() -> int:
	return pistol_clip if weapon_mode == "pistol" else (machinegun_clip if weapon_mode == "machinegun" else 0)

func get_current_reserve() -> int:
	return pistol_reserve if weapon_mode == "pistol" else (machinegun_reserve if weapon_mode == "machinegun" else 0)

func add_ammo(type:String, amount:int) -> void:
	if type == "pistol":
		pistol_reserve += amount
	elif type == "machinegun":
		machinegun_reserve += amount
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func start_reload() -> void:
	if is_reloading || !has_gun:
		return
	if weapon_mode == "pistol" && (pistol_clip >= PISTOL_CLIP_SIZE || pistol_reserve <= 0):
		return
	if weapon_mode == "machinegun" && (machinegun_clip >= MACHINEGUN_CLIP_SIZE || machinegun_reserve <= 0):
		return
		
	is_reloading = true
	var dur:float = 1.0 if weapon_mode == "pistol" else 1.5
	reload_started.emit()
	if is_instance_valid(reload_audio):
		reload_audio.play()
		
	# Animação de inclinar/abaixar a arma durante recarga
	if is_instance_valid(gun_view):
		var target_down:Vector3 = (Vector3(0.38, -0.4, -0.64) if weapon_mode == "pistol" else gun_rest_position) + Vector3(0, -0.28, 0.12)
		var rest_pos:Vector3 = Vector3(0.38, -0.4, -0.64) if weapon_mode == "pistol" else gun_rest_position
		var t := create_tween()
		t.tween_property(gun_view, "position", target_down, dur * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_interval(dur * 0.15)
		t.tween_property(gun_view, "position", rest_pos, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	await get_tree().create_timer(dur).timeout
	if !is_reloading:
		return
	if weapon_mode == "pistol":
		var needed := PISTOL_CLIP_SIZE - pistol_clip
		var take_amount := mini(needed, pistol_reserve)
		pistol_clip += take_amount
		pistol_reserve -= take_amount
	elif weapon_mode == "machinegun":
		var needed := MACHINEGUN_CLIP_SIZE - machinegun_clip
		var take_amount := mini(needed, machinegun_reserve)
		machinegun_clip += take_amount
		machinegun_reserve -= take_amount
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func eject_casing() -> void:
	var casing := RigidBody3D.new()
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.009
	cyl.bottom_radius = 0.009
	cyl.height = 0.028
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.65, 0.22)
	mat.metallic = 0.95
	mat.roughness = 0.2
	cyl.material = mat
	mesh_inst.mesh = cyl
	casing.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var col_shape := SphereShape3D.new()
	col_shape.radius = 0.02
	col.shape = col_shape
	casing.add_child(col)
	casing.collision_layer = 0
	casing.collision_mask = 1
	casing.mass = 0.02
	
	var spawn_pos := camera.global_position + camera.global_transform.basis * Vector3(0.32, -0.22, -0.45)
	casing.global_position = spawn_pos
	get_parent().add_child(casing)
	
	var eject_dir := camera.global_transform.basis * Vector3(randf_range(2.2, 3.8), randf_range(1.6, 2.8), randf_range(0.4, 1.2))
	casing.linear_velocity = eject_dir
	casing.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
	
	get_tree().create_timer(2.5).timeout.connect(casing.queue_free)

func fire() -> void:
	if is_reloading:
		return
	if weapon_mode == "pistol":
		if pistol_clip <= 0:
			if pistol_reserve > 0:
				start_reload()
			elif is_instance_valid(dry_fire_audio):
				dry_fire_audio.play()
			return
		pistol_clip -= 1
	elif weapon_mode == "machinegun":
		if machinegun_clip <= 0:
			if machinegun_reserve > 0:
				start_reload()
			elif is_instance_valid(dry_fire_audio):
				dry_fire_audio.play()
			return
		machinegun_clip -= 1
	else:
		return
		
	eject_casing()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)
	
	var direction := -camera.global_transform.basis.z
	fired.emit(camera.global_position, direction)
	muzzle_light.visible = true
	var tween := create_tween()
	tween.tween_interval(0.035)
	tween.tween_callback(func(): muzzle_light.visible = false)
	camera.rotation.z = randf_range(-0.012, 0.012)
	create_tween().tween_property(camera, "rotation:z", 0.0, 0.07)
	if is_instance_valid(gun_view):
		gun_view.position = (Vector3(0.38, -0.4, -0.64) if weapon_mode == "pistol" else gun_rest_position) + Vector3(0, 0.02, 0.09)
		create_tween().tween_property(gun_view, "position", (Vector3(0.38, -0.4, -0.64) if weapon_mode == "pistol" else gun_rest_position), 0.075)
		
	if get_current_clip() == 0 && get_current_reserve() > 0:
		start_reload()

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
	update_view_gun()

func update_view_gun() -> void:
	if !is_instance_valid(gun_view):
		return
	gun_view.scale = Vector3(0.72, 0.82, 0.7) if weapon_mode == "pistol" else Vector3.ONE
	gun_view.position = Vector3(0.38, -0.4, -0.64) if weapon_mode == "pistol" else gun_rest_position

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

func shake_camera(intensity:float = 0.06, duration:float = 0.6) -> void:
	var tween := create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		var rot := randf_range(-intensity * 0.4, intensity * 0.4)
		tween.tween_property(camera, "position", Vector3(0, 0, 0) + offset, 0.05)
		tween.parallel().tween_property(camera, "rotation:z", rot, 0.05)
	tween.tween_property(camera, "position", Vector3.ZERO, 0.1)
	tween.parallel().tween_property(camera, "rotation:z", 0.0, 0.1)
