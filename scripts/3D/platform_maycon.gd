extends CharacterBody3D

const MODEL = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const JUMP_SOUND = preload("res://assets/audio/pulo_maycon.mp3")

@onready var camera:Camera3D = $"../Camera3D"

var visual:Node3D
var animation_player:AnimationPlayer
var jump_audio:AudioStreamPlayer3D
var camera_yaw:float = 0.0
var camera_pitch:float = -0.22
var jumps:int = 0
var coyote_time:float = 0.0
var jump_buffer:float = 0.0
var hurt_time:float = 0.0
var control_enabled:bool = true
var attack_time:float = 0.0
var attack_cooldown:float = 0.0
var facing_direction:Vector3 = Vector3.FORWARD

func _ready() -> void:
	visual = MODEL.instantiate()
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	jump_audio = AudioStreamPlayer3D.new()
	jump_audio.stream = JUMP_SOUND
	jump_audio.unit_size = 9.0
	add_child(jump_audio)
	_play_animation("Idle")

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.004
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -0.65, 0.28)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_punch()
	elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and event.pressed:
		_punch()

func _punch() -> void:
	if not control_enabled or attack_cooldown > 0.0:
		return
	attack_time = 0.42
	attack_cooldown = 0.48
	_play_animation("Boxing_Practice")
	get_parent().punch_enemies(global_position, facing_direction)

func _physics_process(delta:float) -> void:
	if hurt_time > 0.0:
		hurt_time -= delta
	attack_time = maxf(attack_time - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if is_on_floor():
		coyote_time = 0.13
		jumps = 0
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
	if Input.is_action_just_pressed("ui_accept") and control_enabled:
		jump_buffer = 0.14
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and control_enabled and (coyote_time > 0.0 or jumps < 2 and not is_on_floor()):
		velocity.y = 8.9 if jumps == 0 else 8.1
		jumps += 1
		coyote_time = 0.0
		jump_buffer = 0.0
		jump_audio.play()
		_play_animation("Arise")
	velocity.y -= 23.0 * delta
	if Input.is_action_just_released("ui_accept") and velocity.y > 3.5:
		velocity.y *= 0.62
	var input:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if control_enabled else Vector2.ZERO
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var direction := (right * input.x - forward * input.y).normalized()
	# The shared "run" action also contains controller X; in this stage X punches.
	var speed := 9.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 6.8
	var acceleration := 25.0 if is_on_floor() else 11.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	move_and_slide()
	if direction.length_squared() > 0.01:
		facing_direction = direction
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 12.0, 1.0))
	if attack_time > 0.0:
		_play_animation("Boxing_Practice")
	elif is_on_floor():
		_play_animation("Walking" if direction.length_squared() > 0.01 else "Idle")
	elif velocity.y < -0.5:
		_play_animation("BeHit_FlyUp")
	if animation_player and animation_player.current_animation == "Walking":
		animation_player.speed_scale = 1.8 if speed > 7.0 else 1.35
	elif animation_player:
		animation_player.speed_scale = 1.0

func _process(delta:float) -> void:
	var look:Vector2 = Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	if look.length_squared() > 0.02:
		camera_yaw -= look.x * delta * 2.5
		camera_pitch = clampf(camera_pitch - look.y * delta * 1.6, -0.65, 0.28)
	var focus := global_position + Vector3(0.0, 1.35, 0.0)
	var offset := Vector3(sin(camera_yaw) * 11.0, 5.0 - camera_pitch * 7.0, cos(camera_yaw) * 11.0)
	var desired := focus + offset
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = focus + (hit.position - focus).normalized() * maxf(focus.distance_to(hit.position) - 0.4, 1.2)
	camera.global_position = camera.global_position.lerp(desired, minf(delta * 6.0, 1.0))
	camera.look_at(focus, Vector3.UP)

func _play_animation(animation:String) -> void:
	if animation_player and animation_player.has_animation(animation) and animation_player.current_animation != animation:
		animation_player.play(animation)

func bounce() -> void:
	velocity.y = 10.2
	jumps = 1
	jump_buffer = 0.0
	_play_animation("Arise")

func receive_damage(amount:float, source:Vector3) -> void:
	if hurt_time > 0.0:
		return
	hurt_time = 1.0
	Global.realtime_hp = maxf(0.0, Global.realtime_hp - amount)
	var knockback := global_position - source
	knockback.y = 0.0
	if knockback.length_squared() > 0.01:
		knockback = knockback.normalized()
	velocity.x = knockback.x * 7.0
	velocity.z = knockback.z * 7.0
	velocity.y = 5.0
	_play_animation("BeHit_FlyUp")
	get_parent().update_hud()
	if Global.realtime_hp <= 0.0:
		get_parent().respawn(true)
