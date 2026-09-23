extends CharacterBody3D

const MODEL = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const JUMP_SOUND = preload("res://assets/audio/pulo_maycon.mp3")
const FART_SOUND = preload("res://assets/audio/peido.mp3")
const FART_SMOKE = preload("res://assets/novas_imagens/effects/smoke_animation.png")

@onready var camera:Camera3D = $"../Camera3D"

var visual:Node3D
var animation_player:AnimationPlayer
var jump_audio:AudioStreamPlayer3D
var fart_audio:AudioStreamPlayer3D
var fart_puffs:Array[Dictionary] = []
var camera_yaw:float = 0.0
var camera_pitch:float = -0.22
var jumps:int = 0
var coyote_time:float = 0.0
var jump_buffer:float = 0.0
var hurt_time:float = 0.0
var control_enabled:bool = true
var dying:bool = false
var camera_shake:float = 0.0
var jump_windup:float = 0.0
var preparing_jump:bool = false

func _ready() -> void:
	visual = MODEL.instantiate()
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	jump_audio = AudioStreamPlayer3D.new()
	jump_audio.stream = JUMP_SOUND
	jump_audio.unit_size = 9.0
	add_child(jump_audio)
	fart_audio = AudioStreamPlayer3D.new()
	fart_audio.stream = FART_SOUND
	fart_audio.unit_size = 12.0
	fart_audio.pitch_scale = 0.75
	add_child(fart_audio)
	_play_animation("Walking")

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.004
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -0.65, 0.28)

func _physics_process(delta:float) -> void:
	if hurt_time > 0.0:
		hurt_time -= delta
	_update_fart_puffs(delta)
	if dying:
		velocity = Vector3.ZERO
		return
	if is_on_floor() and not preparing_jump:
		coyote_time = 0.13
		jumps = 0
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
	if preparing_jump:
		jump_windup -= delta
		if jump_windup <= 0.0:
			preparing_jump = false
			velocity.y = 8.9
			jumps = 1
			coyote_time = 0.0
			jump_audio.play()
			visual.scale = Vector3(0.94, 1.13, 0.94)
	if Input.is_action_just_pressed("ui_accept") and control_enabled:
		jump_buffer = 0.14
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and control_enabled and not preparing_jump and (coyote_time > 0.0 or jumps == 1 and not is_on_floor()):
		if jumps == 0:
			preparing_jump = true
			jump_windup = 0.09
			visual.scale = Vector3(1.1, 0.76, 1.1)
			_play_animation("Walking")
		else:
			_spawn_fart()
			velocity.y = 8.1
			jumps = 2
			jump_audio.play()
			visual.scale = Vector3(0.91, 1.16, 0.91)
		coyote_time = 0.0
		jump_buffer = 0.0
	if not preparing_jump:
		velocity.y -= 23.0 * delta
	if Input.is_action_just_released("ui_accept") and velocity.y > 3.5:
		velocity.y *= 0.62
	var input:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if control_enabled else Vector2.ZERO
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var direction := (right * input.x - forward * input.y).normalized()
	var speed := 9.0 if Input.is_action_pressed("run") else 6.8
	var acceleration := 25.0 if is_on_floor() else 11.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	_step_over_small_lip(delta)
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 12.0, 1.0))
	visual.rotation.x = lerpf(visual.rotation.x, 0.0 if is_on_floor() else -0.1 if velocity.y > 0.0 else 0.08, minf(delta * 8.0, 1.0))
	if not preparing_jump:
		visual.scale = visual.scale.lerp(Vector3.ONE, minf(delta * 6.0, 1.0))
	if preparing_jump:
		_play_animation("Walking")
	elif is_on_floor():
		_play_animation("Arise" if direction.length_squared() > 0.01 and speed > 7.0 else "Idle" if direction.length_squared() > 0.01 else "Walking")
	else:
		_play_animation("Walking")
	if animation_player and (preparing_jump or not is_on_floor()):
		animation_player.speed_scale = 0.0
	elif animation_player and animation_player.current_animation == "Idle":
		animation_player.speed_scale = 1.35
	elif animation_player:
		animation_player.speed_scale = 1.0

func _step_over_small_lip(delta:float) -> void:
	if not is_on_floor():
		return
	var horizontal_move := Vector3(velocity.x * delta, 0.0, velocity.z * delta)
	if horizontal_move.length_squared() < 0.00001 or not test_move(global_transform, horizontal_move):
		return
	for rise in [0.14, 0.26, 0.38]:
		var raised := global_transform.translated(Vector3.UP * rise)
		if not test_move(raised, horizontal_move):
			global_position.y += rise
			return

func _spawn_fart() -> void:
	fart_audio.play()
	var camera_right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var side_motion := Input.get_axis("ui_left", "ui_right")
	if absf(side_motion) < 0.1:
		side_motion = Vector3(velocity.x, 0.0, velocity.z).dot(camera_right)
	for i in range(7):
		var puff := Sprite3D.new()
		puff.texture = FART_SMOKE
		puff.hframes = 3
		puff.vframes = 2
		puff.frame = randi_range(0, 1)
		puff.pixel_size = randf_range(0.009, 0.014)
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.shaded = false
		puff.transparent = true
		puff.double_sided = true
		puff.flip_h = side_motion > 0.1
		get_parent().add_child(puff)
		puff.global_position = global_position + Vector3(randf_range(-0.38, 0.38), randf_range(0.05, 0.5), randf_range(-0.38, 0.38))
		var alpha := randf_range(0.4, 0.58)
		puff.modulate = Color(randf_range(0.48, 0.62), randf_range(0.79, 0.92), randf_range(0.55, 0.71), alpha)
		var duration := randf_range(0.42, 0.64)
		fart_puffs.append({"node":puff, "life":duration, "duration":duration, "alpha":alpha, "velocity":Vector3(randf_range(-2.0, 2.0), randf_range(-1.8, 0.4), randf_range(-2.0, 2.0)), "start_frame":puff.frame})

func _update_fart_puffs(delta:float) -> void:
	for i in range(fart_puffs.size() - 1, -1, -1):
		var data:Dictionary = fart_puffs[i]
		var puff:Sprite3D = data.node
		data["life"] = float(data.life) - delta
		puff.position += data.velocity * delta
		puff.scale += Vector3.ONE * delta * 0.55
		var progress:float = 1.0 - clampf(float(data.life) / float(data.duration), 0.0, 1.0)
		puff.frame = mini(5, int(data.start_frame) + int(progress * 5.0))
		puff.modulate.a = (1.0 - smoothstep(0.2, 1.0, progress)) * float(data.alpha)
		if data.life <= 0.0:
			puff.queue_free()
			fart_puffs.remove_at(i)

func _process(delta:float) -> void:
	var look:Vector2 = Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	if look.length_squared() > 0.02:
		camera_yaw -= look.x * delta * 2.5
		camera_pitch = clampf(camera_pitch - look.y * delta * 1.6, -0.65, 0.28)
	var focus := global_position + Vector3(0.0, 1.35, 0.0)
	var offset := Vector3(sin(camera_yaw) * 11.0, 3.1 - camera_pitch * 5.0, cos(camera_yaw) * 11.0)
	var desired := focus + offset
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = focus + (hit.position - focus).normalized() * maxf(focus.distance_to(hit.position) - 0.4, 1.2)
	camera.global_position = camera.global_position.lerp(desired, minf(delta * 6.0, 1.0))
	camera.look_at(focus, Vector3.UP)
	camera_shake = maxf(camera_shake - delta * 1.8, 0.0)
	camera.h_offset = randf_range(-camera_shake, camera_shake)
	camera.v_offset = randf_range(-camera_shake, camera_shake)

func _play_animation(animation:String) -> void:
	if animation_player and animation_player.has_animation(animation) and animation_player.current_animation != animation:
		animation_player.play(animation)

func bounce() -> void:
	velocity.y = 10.2
	jumps = 1
	jump_buffer = 0.0
	_play_animation("Walking")

func receive_damage(amount:float, source:Vector3) -> void:
	if hurt_time > 0.0 or dying:
		return
	preparing_jump = false
	jump_windup = 0.0
	visual.scale = Vector3.ONE
	hurt_time = 1.0
	Global.realtime_hp = maxf(0.0, Global.realtime_hp - amount)
	var knockback := global_position - source
	knockback.y = 0.0
	if knockback.length_squared() > 0.01:
		knockback = knockback.normalized()
	velocity.x = knockback.x * 7.0
	velocity.z = knockback.z * 7.0
	velocity.y = 5.0
	camera_shake = 0.32
	Input.start_joy_vibration(0, 0.42, 0.65, 0.25)
	get_parent().player_hit(global_position)
	get_parent().update_hud()
	if Global.realtime_hp <= 0.0:
		dying = true
		control_enabled = false
		velocity = Vector3.ZERO
		_play_animation("Casual_Walk")
		await get_tree().create_timer(0.9).timeout
		if is_inside_tree():
			get_parent().respawn(true)
			dying = false
			control_enabled = true
			_play_animation("Walking")
