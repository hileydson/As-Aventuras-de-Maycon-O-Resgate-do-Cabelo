extends "res://scripts/3D/platform_maycon.gd"

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")

@export var run_speed:float = 7.8
# A fase corre sozinha: o jogador só desvia, pula e sobrevive.
@export var auto_run:bool = true
var arena_mode:bool = false
var launch_time:float = 0.0
var launch_velocity:Vector3
var jump_dust:GPUParticles3D
var was_airborne:bool = false
var pending_landing:bool = false

func _ready() -> void:
	super._ready()
	if has_node("Preview"):
		$Preview.queue_free()
	visual.rotation.y = PI
	control_enabled = false

func _unhandled_input(_event:InputEvent) -> void:
	pass # A câmera pertence à fase, nunca ao mouse.

func _process(delta:float) -> void:
	if not control_enabled:
		return
	# Câmera colada atrás do Maycon, acompanhando a corrida de perto.
	var focus := global_position + Vector3(0, 1.3, -4.0)
	var desired := global_position + Vector3(0, 2.8, 5.6)
	if arena_mode:
		# Recuada além da entrada para enquadrar o player desde o primeiro passo na arena.
		desired = Vector3(global_position.x * 0.3, 17, -1758)
		focus = Vector3(global_position.x * 0.3, 3.0, -1796)
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-8.0 * delta))
	camera.look_at(focus)

func _physics_process(delta:float) -> void:
	hurt_time = maxf(0.0, hurt_time - delta)
	_update_fart_puffs(delta)
	if not control_enabled or dying:
		return
	if launch_time > 0.0:
		launch_time -= delta
		velocity.x = launch_velocity.x
		velocity.z = launch_velocity.z
	else:
		var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var acceleration := 28.0 if is_on_floor() else 16.0
		var direction := Vector3.ZERO
		if auto_run and not arena_mode:
			direction = Vector3(input.x, 0, -1)
			velocity.x = move_toward(velocity.x, input.x * run_speed * 0.8, acceleration * delta)
			velocity.z = move_toward(velocity.z, -run_speed, acceleration * delta)
		else:
			if not arena_mode:
				input.y = minf(input.y, 0.0)
			direction = Vector3(input.x, 0, input.y).normalized()
			velocity.x = move_toward(velocity.x, direction.x * run_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * run_speed, acceleration * delta)
		if direction.length_squared() > 0.01:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(12.0 * delta, 1.0))
		_update_footsteps(delta, direction, run_speed)
	if is_on_floor():
		coyote_time = 0.13
		jumps = 0
	else:
		coyote_time = maxf(0.0, coyote_time - delta)
	jump_buffer = 0.14 if Input.is_action_just_pressed("ui_accept") else maxf(0.0, jump_buffer - delta)
	if jump_buffer > 0.0 and launch_time <= 0.0 and (coyote_time > 0.0 or jumps == 1):
		if jumps == 1:
			_spawn_fart()
		velocity.y = 8.9 if jumps == 0 else 8.1
		jumps += 1
		coyote_time = 0.0
		jump_buffer = 0.0
		jump_audio.play()
		POEIRA.saltar(get_parent(), global_position)
	velocity.y -= 23.0 * delta
	if Input.is_action_just_released("ui_accept") and velocity.y > 3.5 and launch_time <= 0.0:
		velocity.y *= 0.62
	move_and_slide()
	# O Maycon não sai da pista de lado; a queda só existe nos buracos entre as plataformas.
	var limit:float = get_parent().track_limit(global_position.z)
	if absf(global_position.x) > limit:
		global_position.x = clampf(global_position.x, -limit, limit)
		velocity.x = 0.0
	_update_landing_dust()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	_play_animation("Air_Flail" if not is_on_floor() else "Arise" if moving else "Walking")
	animation_player.speed_scale = 0.62 if not is_on_floor() else 1.0
	visual.visible = hurt_time <= 0.0 or fmod(hurt_time, 0.16) < 0.08
	if global_position.y < get_parent().fall_limit(global_position.z):
		get_parent().respawn()

# O trampolim joga poeira junto com o Maycon e cobre o chão quando ele aterra.
func _update_landing_dust() -> void:
	var airborne := not is_on_floor()
	if was_airborne and not airborne:
		if pending_landing:
			pending_landing = false
			POEIRA.apagar(jump_dust)
			jump_dust = null
			POEIRA.pousar(get_parent(), global_position)
			get_parent().sound("spring")
		else:
			POEIRA.aterrar(get_parent(), global_position)
	was_airborne = airborne

func launch_to(target:Vector3, duration:float) -> void:
	launch_time = duration
	launch_velocity = (target - global_position) / duration
	velocity = launch_velocity
	velocity.y += 11.5 * duration
	jumps = 1
	jump_audio.play()
	POEIRA.impulsionar(get_parent(), global_position)
	POEIRA.apagar(jump_dust)
	jump_dust = POEIRA.rastro(self)
	pending_landing = true
	was_airborne = true

func receive_damage(amount:float, source:Vector3) -> void:
	if not control_enabled or hurt_time > 0.0 or dying:
		return
	hurt_time = 1.6
	get_parent().damage(amount)
	var away := (global_position - source).normalized()
	velocity += Vector3(away.x * 4, 4, away.z * 2)
	Input.start_joy_vibration(0, 0.35, 0.55, 0.2)
	_splash_blood()
	# Pancada levanta poeira para todo lado, junto com o sangue.
	POEIRA.pousar(get_parent(), global_position)
	POEIRA.impulsionar(get_parent(), global_position + Vector3.UP * 0.8)

# Mesmo espirro das lutas: muito sangue para todo lado a cada pancada.
func _splash_blood() -> void:
	var stage:Node3D = get_parent()
	for i in 7:
		var blood:Node3D = BLOOD_SCENE.instantiate()
		blood.position = global_position + Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.8), randf_range(-1.0, 1.0))
		blood.scale = Vector3.ONE * randf_range(2.0, 3.4)
		stage.get_node("Effects").add_child(blood)
		get_tree().create_timer(2.5).timeout.connect(blood.queue_free)
