extends CharacterBody3D

const MODEL = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const JUMP_SOUND = preload("res://assets/audio/pulo_maycon.mp3")
const FART_SOUND = preload("res://assets/audio/peido.mp3")
const STEP_SOUND = preload("res://assets/novos_audios/mario_part_sounds/passo.mp3")
const FART_SMOKE = preload("res://assets/novas_imagens/effects/smoke_animation.png")
const AIR_FLAIL_ANIM = preload("res://assets/novas_imagens/3d_enemies/maycon_air_flail.res")

@onready var camera:Camera3D = $"../Camera3D"

var visual:Node3D
var animation_player:AnimationPlayer
var jump_audio:AudioStreamPlayer3D
var fart_audio:AudioStreamPlayer3D
var step_audio:AudioStreamPlayer
var step_timer:float = 0.0
var fart_puffs:Array[Dictionary] = []
var camera_yaw:float = 0.0
var camera_pitch:float = -0.22
var manual_camera_cooldown:float = 0.0
var is_invincible:bool = false
var invincibility_aura:MeshInstance3D
var jumps:int = 0
var coyote_time:float = 0.0
var jump_buffer:float = 0.0
var hurt_time:float = 0.0
var control_enabled:bool = true
var intro_mode:bool = false
var landing_recovery_time:float = 0.0
var landing_recovery_duration:float = 0.85
var dying:bool = false
var death_hazard:String = ""
var death_hazard_node:Node3D = null
var camera_shake:float = 0.0
var jump_windup:float = 0.0
var preparing_jump:bool = false
var takeoff_stretch:float = 0.0
var latched_count:int = 0
var current_camera_distance:float = 11.0
var air_wobble_time:float = 0.0
var air_random_phase:float = 0.0
var cutscene_active:bool = false
var saved_cutscene_velocity:Vector3 = Vector3.ZERO

func _ready() -> void:
	visual = MODEL.instantiate()
	add_child(visual)
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player and AIR_FLAIL_ANIM:
		var lib: AnimationLibrary = animation_player.get_animation_library("")
		if lib and not lib.has_animation("Air_Flail"):
			lib.add_animation("Air_Flail", AIR_FLAIL_ANIM)
	jump_audio = AudioStreamPlayer3D.new()
	jump_audio.stream = JUMP_SOUND
	jump_audio.unit_size = 9.0
	add_child(jump_audio)
	fart_audio = AudioStreamPlayer3D.new()
	fart_audio.stream = FART_SOUND
	fart_audio.unit_size = 12.0
	fart_audio.pitch_scale = 0.75
	add_child(fart_audio)
	step_audio = AudioStreamPlayer.new()
	step_audio.stream = STEP_SOUND
	step_audio.volume_db = -4.0
	add_child(step_audio)
	
	var aura_mesh := CapsuleMesh.new()
	aura_mesh.radius = 0.46
	aura_mesh.height = 1.7
	invincibility_aura = MeshInstance3D.new()
	invincibility_aura.mesh = aura_mesh
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.45)
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	invincibility_aura.material_override = aura_mat
	invincibility_aura.position.y = 0.83
	invincibility_aura.visible = false
	add_child(invincibility_aura)
	
	_play_animation("Walking")

func set_invincible(active_val:bool, _duration:float = 0.0) -> void:
	is_invincible = active_val
	if is_instance_valid(invincibility_aura):
		invincibility_aura.visible = active_val

func set_cutscene_active(val:bool) -> void:
	cutscene_active = val
	if val:
		control_enabled = false
		saved_cutscene_velocity = velocity
		velocity = Vector3.ZERO
		if is_instance_valid(animation_player) and animation_player.is_playing():
			animation_player.pause()
	else:
		control_enabled = true
		velocity = saved_cutscene_velocity
		if is_instance_valid(animation_player) and not animation_player.is_playing():
			animation_player.play()

func _unhandled_input(event:InputEvent) -> void:
	if cutscene_active or not control_enabled:
		return
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		camera_yaw -= event.relative.x * 0.004
		camera_pitch = clampf(camera_pitch - event.relative.y * 0.003, -0.65, 0.28)
		manual_camera_cooldown = 0.85

func _physics_process(delta:float) -> void:
	if hurt_time > 0.0:
		hurt_time -= delta
	_update_fart_puffs(delta)
	if intro_mode or cutscene_active:
		return
	if landing_recovery_time > 0.0:
		landing_recovery_time = maxf(landing_recovery_time - delta, 0.0)
		control_enabled = false
		velocity = Vector3.ZERO
		var recover_progress := clampf((landing_recovery_duration - landing_recovery_time) / minf(0.9, landing_recovery_duration), 0.0, 1.0)
		var recover_factor := ease(recover_progress, 0.5)
		if is_instance_valid(visual):
			visual.scale = Vector3(1.35, 0.60, 1.35).lerp(Vector3.ONE, recover_factor)
			visual.position.y = lerpf(-0.22, 0.0, recover_factor)
		if landing_recovery_time <= 0.0:
			control_enabled = true
			if is_instance_valid(visual):
				visual.scale = Vector3.ONE
				visual.position.y = 0.0
		_play_animation("Walking")
		move_and_slide()
		return
	if dying:
		velocity = Vector3.ZERO
		step_audio.stop()
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
			takeoff_stretch = 0.11
			_play_animation("Air_Flail")
	if Input.is_action_just_pressed("ui_accept") and control_enabled:
		jump_buffer = 0.14
	else:
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	if jump_buffer > 0.0 and control_enabled and not preparing_jump and (coyote_time > 0.0 or jumps == 1 and not is_on_floor()):
		if jumps == 0:
			preparing_jump = true
			jump_windup = 0.10
			velocity.y = 8.9
			jumps = 1
			air_random_phase = randf_range(0.0, TAU)
			air_wobble_time = 0.0
			jump_audio.play()
			_play_animation("Walking")
		else:
			_spawn_fart()
			velocity.y = 8.1
			jumps = 2
			air_random_phase = randf_range(0.0, TAU)
			air_wobble_time = 0.0
			jump_audio.play()
			takeoff_stretch = 0.11
			_play_animation("Air_Flail")
		coyote_time = 0.0
		jump_buffer = 0.0
	velocity.y -= 23.0 * delta
	if Input.is_action_just_released("ui_accept") and velocity.y > 3.5:
		velocity.y *= 0.62
	var input:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if control_enabled else Vector2.ZERO
	var forward := Vector3(-sin(camera_yaw), 0.0, -cos(camera_yaw))
	var right := Vector3(cos(camera_yaw), 0.0, -sin(camera_yaw))
	var direction := (right * input.x - forward * input.y).normalized()
	var is_running := Input.is_action_pressed("run")
	var speed := 7.8 if is_running else 4.8
	if latched_count > 0:
		speed *= 0.52
	var acceleration:float
	if is_on_floor():
		if direction.length_squared() < 0.01:
			acceleration = 58.0
		elif direction.dot(Vector3(velocity.x, 0.0, velocity.z)) < -0.2:
			acceleration = 48.0
		else:
			acceleration = 22.0 if is_running else 28.0
	else:
		acceleration = 11.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	_step_over_small_lip(delta)
	move_and_slide()
	_update_footsteps(delta, direction, speed)
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 12.0, 1.0))
	if not is_on_floor():
		air_wobble_time += delta
		var wobble_pitch := sin(air_wobble_time * 3.2 + air_random_phase) * 0.12 + cos(air_wobble_time * 1.9) * 0.06
		var wobble_roll := sin(air_wobble_time * 2.6 + 1.2 + air_random_phase) * 0.10
		var base_pitch: float
		if jumps >= 2:
			# Segundo pulo: muito mais inclinado!
			base_pitch = -0.46 if velocity.y > 0.0 else 0.25
		else:
			# Primeiro pulo: inclinação moderada
			base_pitch = -0.16 if velocity.y > 0.0 else 0.10
		var target_x := base_pitch + wobble_pitch
		var target_z := wobble_roll
		visual.rotation.x = lerpf(visual.rotation.x, target_x, minf(delta * 8.0, 1.0))
		visual.rotation.z = lerpf(visual.rotation.z, target_z, minf(delta * 8.0, 1.0))
	else:
		air_wobble_time = 0.0
		visual.rotation.x = lerpf(visual.rotation.x, 0.0, minf(delta * 14.0, 1.0))
		visual.rotation.z = lerpf(visual.rotation.z, 0.0, minf(delta * 14.0, 1.0))
	var target_scale := Vector3(1.17, 0.66, 1.17) if preparing_jump else Vector3(0.95, 1.11, 0.95) if takeoff_stretch > 0.0 else Vector3.ONE
	visual.scale = visual.scale.lerp(target_scale, 1.0 - exp(-27.0 * delta))
	visual.position.y = lerpf(visual.position.y, -0.26 if preparing_jump else 0.0, 1.0 - exp(-27.0 * delta))
	takeoff_stretch = maxf(takeoff_stretch - delta, 0.0)
	if preparing_jump:
		_play_animation("Walking")
	elif is_on_floor():
		_play_animation("Arise" if direction.length_squared() > 0.01 and speed > 6.0 else "Skill_03" if direction.length_squared() > 0.01 else "Walking")
	else:
		_play_animation("Air_Flail")
	if animation_player and preparing_jump:
		animation_player.speed_scale = 0.0
	elif animation_player:
		var is_walking := is_on_floor() and direction.length_squared() > 0.01 and speed <= 6.0
		var is_air := not is_on_floor()
		# Braços e pernas batendo mais lentamente no ar (0.62 em vez de 1.35)
		animation_player.speed_scale = 1.6 if is_walking else 0.62 if is_air else 1.0

func _update_footsteps(delta:float, direction:Vector3, speed:float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or direction.length_squared() < 0.01 or horizontal_speed < 0.8:
		step_timer = 0.0
		if step_audio.playing:
			step_audio.stop()
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_audio.pitch_scale = randf_range(1.02, 1.12) if speed > 6.0 else randf_range(0.94, 1.04)
		step_audio.play()
		step_timer = 0.38 if speed > 6.0 else 0.46

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
		puff.modulate = Color(randf_range(0.17, 0.29), randf_range(0.78, 0.96), randf_range(0.12, 0.24), alpha)
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
	if intro_mode:
		return
	var look:Vector2 = Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
	if look.length_squared() > 0.02:
		camera_yaw -= look.x * delta * 2.5
		camera_pitch = clampf(camera_pitch - look.y * delta * 1.6, -0.65, 0.28)
		manual_camera_cooldown = 0.85
	
	if manual_camera_cooldown > 0.0:
		manual_camera_cooldown = maxf(manual_camera_cooldown - delta, 0.0)
	elif control_enabled and not dying:
		var horiz_vel := Vector2(velocity.x, velocity.z)
		if horiz_vel.length() > 0.7:
			var move_heading := Vector3(velocity.x, 0.0, velocity.z).normalized()
			var target_yaw := atan2(-move_heading.x, -move_heading.z)
			var angle_diff := absf(wrapf(target_yaw - camera_yaw, -PI, PI))
			var alignment_factor := clampf(1.0 - (angle_diff / PI), 0.15, 1.0)
			var auto_speed := 2.4 if horiz_vel.length() > 6.0 else 1.6
			camera_yaw = lerp_angle(camera_yaw, target_yaw, auto_speed * alignment_factor * delta)

	# Proximity zoom when near jumping enemies (Mini Seco) or hazard death (Navalha / Mão)
	var target_cam_distance := 11.0
	var focus_y := 1.35
	var focus: Vector3
	if dying and (death_hazard == "blade" or death_hazard == "hand"):
		target_cam_distance = 4.2
		if is_instance_valid(death_hazard_node):
			if death_hazard == "blade":
				focus = death_hazard_node.global_position + Vector3(0.0, 1.05, 0.0)
			else:
				focus = death_hazard_node.global_position + Vector3(0.0, 0.55, -0.35)
		else:
			focus = global_position + Vector3(0.0, 0.6, 0.0)
	elif latched_count > 0:
		target_cam_distance = 5.2
		focus_y = 1.48
		focus = global_position + Vector3(0.0, focus_y, 0.0)
	else:
		var parent_node := get_parent()
		if parent_node and parent_node.has_node("Inimigos"):
			var nearest_dist := 999.0
			for enemy in parent_node.get_node("Inimigos").get_children():
				if is_instance_valid(enemy) and enemy.get("active") == true and enemy.get("MIN_LATCH_TIME") != null:
					var d:float = global_position.distance_to(enemy.global_position)
					if d < nearest_dist:
						nearest_dist = d
			if nearest_dist < 9.5:
				var factor := clampf((nearest_dist - 2.5) / 7.0, 0.0, 1.0)
				target_cam_distance = lerpf(5.8, 11.0, factor)
				focus_y = lerpf(1.15, 1.35, factor)
		focus = global_position + Vector3(0.0, focus_y, 0.0)

	var zoom_lerp := 8.0 if (dying and (death_hazard == "blade" or death_hazard == "hand")) else 4.5
	current_camera_distance = lerpf(current_camera_distance, target_cam_distance, minf(delta * zoom_lerp, 1.0))
	var dist_ratio := current_camera_distance / 11.0
	var offset := Vector3(sin(camera_yaw) * current_camera_distance, (3.1 - camera_pitch * 5.0) * dist_ratio, cos(camera_yaw) * current_camera_distance)
	var desired := focus + offset
	var query := PhysicsRayQueryParameters3D.create(focus, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = focus + (hit.position - focus).normalized() * maxf(focus.distance_to(hit.position) - 0.4, 1.2)
	var cam_lerp_speed := 9.0 if (dying and (death_hazard == "blade" or death_hazard == "hand")) else 6.0
	camera.global_position = camera.global_position.lerp(desired, minf(delta * cam_lerp_speed, 1.0))
	camera.look_at(focus, Vector3.UP)
	camera_shake = maxf(camera_shake - delta * 1.8, 0.0)
	camera.h_offset = randf_range(-camera_shake, camera_shake)
	camera.v_offset = randf_range(-camera_shake, camera_shake)
	
	if is_invincible and is_instance_valid(invincibility_aura):
		var hue := fmod(Time.get_ticks_msec() * 0.0018, 1.0)
		var mat := invincibility_aura.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color.from_hsv(hue, 0.8, 1.0, 0.45 + sin(Time.get_ticks_msec() * 0.01) * 0.15)
		invincibility_aura.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.06)

func _play_animation(animation:String) -> void:
	if animation_player and animation_player.has_animation(animation) and (animation_player.current_animation != animation or not animation_player.is_playing()):
		var previous := animation_player.current_animation
		var blend := 0.24 if previous in ["Skill_03", "Arise"] and animation in ["Skill_03", "Arise"] else 0.10 if animation == "Air_Flail" or previous == "Air_Flail" else 0.08
		animation_player.play(animation, blend)

func bounce() -> void:
	velocity.y = 10.2
	jumps = 1
	jump_buffer = 0.0
	_play_animation("Air_Flail")

func set_latched(active_val:bool) -> void:
	if active_val:
		latched_count += 1
	else:
		latched_count = maxi(latched_count - 1, 0)

func is_immune_to_latch() -> bool:
	return cutscene_active or is_invincible or (jumps == 2 and not is_on_floor())

func receive_damage(amount:float, source:Vector3) -> void:
	if cutscene_active or is_invincible or hurt_time > 0.0 or dying or not is_on_floor():
		return
	preparing_jump = false
	jump_windup = 0.0
	takeoff_stretch = 0.0
	visual.scale = Vector3.ONE
	visual.position.y = 0.0
	hurt_time = 2.0
	get_parent().set_stage_hp(get_parent().stage_hp - amount)
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
	if get_parent().stage_hp <= 0.0:
		dying = true
		control_enabled = false
		velocity = Vector3.ZERO
		_play_animation("Casual_Walk")
		get_parent().start_player_death("enemy")

func start_landing_cooldown(duration: float = 0.85) -> void:
	control_enabled = false
	landing_recovery_time = duration
	landing_recovery_duration = duration
	velocity = Vector3.ZERO
	if is_instance_valid(visual):
		visual.scale = Vector3(1.35, 0.60, 1.35)
		visual.position.y = -0.22
