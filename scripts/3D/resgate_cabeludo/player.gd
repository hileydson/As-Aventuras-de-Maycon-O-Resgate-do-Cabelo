extends "res://scripts/3D/platform_maycon.gd"

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const SCREAM_SOUND = preload("res://assets/novos_audios/maycon_falling_fase_1_transition.mp3")

# Corrida acelerada em 15% (de 10.3 para 11.85).
@export var run_speed:float = 11.85
# A fase corre sozinha: o jogador só desvia, pula e sobrevive.
@export var auto_run:bool = true
# Dash curto, pago em pentagramas, invencível enquanto dura.
const DASH_COST := 3
const DASH_TIME := 0.22
const DASH_SPEED := 22.0
# Mesmas cores e tempos do dash do Poço Infinito.
const DASH_GHOST_COLOR := Color(0.25, 0.85, 1.0, 0.22)
const DASH_STREAK_COLOR := Color(0.35, 0.90, 1.0, 0.20)
const DASH_BLUR := 0.62
# Soco da batalha final: rápido, curto e só dentro da arena.
const PUNCH_TIME := 0.26
const PUNCH_REACH := 3.4
const PUNCH_ANIM_SPEED := 3.2
# Câmera da arena: gira em volta do Maycon com o mouse ou o analógico direito.
const MOUSE_SENSIBILIDADE := 0.004
const GIRO_ANALOGICO := 2.5
const PITCH_MIN := -0.55
const PITCH_MAX := 0.45
const ARENA_DISTANCIA := 5.2
var arena_mode:bool = false
var punch_time:float = 0.0
var punch_hit:bool = false
var launch_time:float = 0.0
var launch_velocity:Vector3
var jump_dust:GPUParticles3D
var was_airborne:bool = false
var pending_landing:bool = false
var dash_time:float = 0.0
var dash_velocity:Vector3
var dash_trail_clock:float = 0.0
var dash_ghosts:Array[Dictionary] = []
var dash_fov_base:float = 0.0
var visual_skeleton:Skeleton3D
var scream_audio:AudioStreamPlayer3D

func _ready() -> void:
	super._ready()
	scream_audio = AudioStreamPlayer3D.new()
	scream_audio.stream = SCREAM_SOUND
	scream_audio.volume_db = 1.0
	scream_audio.unit_size = 12.0
	add_child(scream_audio)
	if has_node("Preview"):
		$Preview.queue_free()
	visual.rotation.y = PI
	control_enabled = false
	var ossos := visual.find_children("*", "Skeleton3D", true, false)
	if ossos.size() > 0:
		visual_skeleton = ossos[0] as Skeleton3D

func _unhandled_input(event:InputEvent) -> void:
	if is_instance_valid(get_parent().final_battle) and get_parent().final_battle.handles_player():
		return
	if event.is_action_pressed("dash_resgate"):
		try_dash()
	# O soco existe só na batalha contra o Lips.
	elif event.is_action_pressed("soco_resgate") and arena_mode:
		try_punch()
	# Na corrida a câmera é da fase. Na arena o mouse gira ela em volta do Maycon.
	elif arena_mode and control_enabled and event is InputEventMouseMotion:
		var mouse := event as InputEventMouseMotion
		camera_yaw -= mouse.relative.x * MOUSE_SENSIBILIDADE
		camera_pitch = clampf(camera_pitch - mouse.relative.y * MOUSE_SENSIBILIDADE * 0.75, PITCH_MIN, PITCH_MAX)

func _process(delta:float) -> void:
	if is_instance_valid(get_parent().final_battle) and get_parent().final_battle.handles_player():
		get_parent().final_battle.update_camera(delta)
		return
	if not control_enabled:
		return
	# Câmera colada atrás do Maycon, acompanhando a corrida de perto.
	var focus := global_position + Vector3(0, 1.3, -4.0)
	var desired := global_position + Vector3(0, 2.8, 5.6)
	if arena_mode:
		# Analógico direito girando a câmera em volta dele.
		var look := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
		if look.length_squared() > 0.04:
			camera_yaw -= look.x * delta * GIRO_ANALOGICO
			camera_pitch = clampf(camera_pitch - look.y * delta * GIRO_ANALOGICO * 0.6, PITCH_MIN, PITCH_MAX)
		# Terceira pessoa colada nele, com a mira deslocada para o lado para o
		# Maycon ficar na esquerda da tela em qualquer ângulo.
		desired = global_position + orbita() * ARENA_DISTANCIA + arena_lado() * 2.0 + Vector3.UP * (2.6 - camera_pitch * 4.0)
		focus = global_position + Vector3.UP * 1.3 - orbita() * 2.0 + arena_lado() * 1.9
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-8.0 * delta))
	camera.look_at(focus)
	if camera_shake > 0.0:
		camera_shake = maxf(0.0, camera_shake - delta * 2.0)
		camera.global_position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * camera_shake * 0.6

func _physics_process(delta:float) -> void:
	if is_instance_valid(get_parent().final_battle) and get_parent().final_battle.handles_player():
		get_parent().final_battle.physics_player(delta)
		return
	hurt_time = maxf(0.0, hurt_time - delta)
	_update_fart_puffs(delta)
	if not control_enabled or dying:
		return
	_update_dash_ghosts(delta)
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_velocity
		dash_trail_clock -= delta
		if dash_trail_clock <= 0.0:
			dash_trail_clock = 0.045
			_spawn_dash_ghost()
			_spawn_dash_streak()
			_spawn_dash_smoke(false)
		if dash_time <= 0.0:
			_end_dash()
	elif launch_time > 0.0:
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
		elif arena_mode:
			# Com a câmera girando, andar é sempre relativo a ela: para frente é
			# para longe da câmera, seja qual for o ângulo.
			var frente := -orbita()
			var lado := arena_lado()
			direction = (lado * input.x + frente * -input.y).normalized()
			velocity.x = move_toward(velocity.x, direction.x * run_speed, acceleration * delta)
			velocity.z = move_toward(velocity.z, direction.z * run_speed, acceleration * delta)
		else:
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
	if jump_buffer > 0.0 and launch_time <= 0.0 and dash_time <= 0.0 and (coyote_time > 0.0 or jumps == 1):
		if jumps == 1:
			_spawn_fart()
		velocity.y = 8.9 if jumps == 0 else 8.1
		jumps += 1
		coyote_time = 0.0
		jump_buffer = 0.0
		jump_audio.play()
		_play_scream()
		POEIRA.saltar(get_parent(), global_position)
	if dash_time <= 0.0:
		velocity.y -= 23.0 * delta
	if Input.is_action_just_released("ui_accept") and velocity.y > 3.5 and launch_time <= 0.0:
		velocity.y *= 0.62
	var previously_on_floor := is_on_floor()
	move_and_slide()
	if previously_on_floor and not is_on_floor() and velocity.y < 0.0:
		_play_scream()
	# O Maycon não sai da pista de lado; a queda só existe nos buracos entre as plataformas.
	var limit:float = get_parent().track_limit(global_position.z)
	if absf(global_position.x) > limit:
		global_position.x = clampf(global_position.x, -limit, limit)
		velocity.x = 0.0
	_update_landing_dust()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	if punch_time > 0.0:
		_update_punch(delta)
	else:
		_play_animation("Air_Flail" if not is_on_floor() else "Arise" if moving else "Walking")
		animation_player.speed_scale = 0.62 if not is_on_floor() else 1.2 if moving else 1.0
	visual.visible = hurt_time <= 0.0 or fmod(hurt_time, 0.16) < 0.08
	if global_position.y < get_parent().fall_limit(global_position.z):
		if is_instance_valid(scream_audio):
			scream_audio.stop()
		get_parent().respawn()

# O trampolim joga poeira junto com o Maycon e cobre o chão quando ele aterra.
func _update_landing_dust() -> void:
	var airborne := not is_on_floor()
	if was_airborne and not airborne:
		if is_instance_valid(scream_audio):
			scream_audio.stop()
		if pending_landing:
			pending_landing = false
			POEIRA.apagar(jump_dust)
			jump_dust = null
			POEIRA.pousar(get_parent(), global_position)
			get_parent().sound("spring")
		else:
			POEIRA.aterrar(get_parent(), global_position)
	was_airborne = airborne

func _play_scream() -> void:
	if not is_instance_valid(scream_audio):
		return
	scream_audio.stop()
	scream_audio.pitch_scale = randf_range(0.85, 1.05)
	scream_audio.play()

func launch_to(target:Vector3, duration:float) -> void:
	launch_time = duration
	launch_velocity = (target - global_position) / duration
	velocity = launch_velocity
	velocity.y += 11.5 * duration
	jumps = 1
	jump_audio.play()
	_play_scream()
	POEIRA.impulsionar(get_parent(), global_position)
	POEIRA.apagar(jump_dust)
	jump_dust = POEIRA.rastro(self)
	pending_landing = true
	was_airborne = true

func receive_damage(amount:float, source:Vector3) -> void:
	if is_instance_valid(get_parent().final_battle) and get_parent().final_battle.handles_player():
		get_parent().final_battle.take_hit(amount,source)
		return
	if not control_enabled or hurt_time > 0.0 or dying or is_invincible:
		return
	hurt_time = 1.6
	get_parent().damage(amount)
	var away := (global_position - source).normalized()
	velocity += Vector3(away.x * 4, 4, away.z * 2)
	Input.start_joy_vibration(0, 0.35, 0.55, 0.2)
	_splash_blood()
	# Pancada levanta poeira junto com o sangue, numa baforada só.
	POEIRA.aterrar(get_parent(), global_position)

# Mesmo espirro das lutas: muito sangue para todo lado a cada pancada.
func _splash_blood() -> void:
	var stage:Node3D = get_parent()
	for i in 7:
		var blood:Node3D = BLOOD_SCENE.instantiate()
		blood.position = global_position + Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.8), randf_range(-1.0, 1.0))
		blood.scale = Vector3.ONE * randf_range(2.0, 3.4)
		stage.get_node("Effects").add_child(blood)
		get_tree().create_timer(2.5).timeout.connect(blood.queue_free)

# Aqui a invencibilidade do dash não acende a cápsula amarela: quem mostra o
# estado é o rastro do próprio dash.
func set_invincible(active_val:bool, _duration:float = 0.0) -> void:
	is_invincible = active_val
	if is_instance_valid(invincibility_aura):
		invincibility_aura.visible = false

# A caixa empurra o Maycon para cima de leve, sem o impulso cheio do pisão.
func soft_bounce() -> void:
	velocity.y = maxf(velocity.y, 6.2)
	jumps = 1
	jump_buffer = 0.0
	_play_animation("Air_Flail")

# Direção que vai do Maycon para a câmera, no ângulo atual da órbita.
func orbita() -> Vector3:
	return Vector3(sin(camera_yaw), 0.0, cos(camera_yaw))

# Lado direito da tela, perpendicular à órbita.
func arena_lado() -> Vector3:
	var atras := orbita()
	return Vector3(atras.z, 0.0, -atras.x)

# Soco da batalha final: a animação Dead do Maycon acelerada, com o estalo e o
# tranco de câmera. Sem a animação importada, o braço é lançado na mão.
func try_punch() -> void:
	if not control_enabled or dying or punch_time > 0.0 or dash_time > 0.0 or launch_time > 0.0:
		return
	punch_time = PUNCH_TIME
	punch_hit = false
	var stage:Node3D = get_parent()
	stage.sound("hit")
	camera_shake = maxf(camera_shake, 0.1)
	if animation_player != null and animation_player.has_animation("Dead"):
		animation_player.speed_scale = PUNCH_ANIM_SPEED
		animation_player.play("Dead")

func _update_punch(delta:float) -> void:
	punch_time -= delta
	var andado:float = 1.0 - clampf(punch_time / PUNCH_TIME, 0.0, 1.0)
	if animation_player == null or not animation_player.has_animation("Dead"):
		_pose_punch(andado)
	# O golpe entra no meio do movimento, uma vez só por soco.
	if not punch_hit and andado > 0.35:
		punch_hit = true
		_punch_contact()
	if punch_time <= 0.0:
		punch_time = 0.0
		if visual_skeleton != null:
			visual_skeleton.reset_bone_poses()
		if animation_player != null:
			animation_player.speed_scale = 1.0

# Braço direito lançado para frente e o tronco acompanhando, a partir do descanso
# de cada osso.
func _pose_punch(andado:float) -> void:
	if visual_skeleton == null:
		return
	visual_skeleton.reset_bone_poses()
	# Recolhe, estende e volta: o pico do golpe fica no meio.
	var golpe := sin(clampf(andado, 0.0, 1.0) * PI)
	_pose_bone("Spine", Vector3(0.0, -0.3 * golpe, 0.0))
	_pose_bone("Spine02", Vector3(0.06 * golpe, -0.2 * golpe, 0.0))
	_pose_bone("RightShoulder", Vector3(0.0, -0.24 * golpe, 0.12 * golpe))
	_pose_bone("RightArm", Vector3(lerpf(0.2, -0.45, golpe), -0.18, lerpf(-0.8, -0.3, golpe)))
	_pose_bone("RightForeArm", Vector3(lerpf(1.2, 0.05, golpe), 0.0, -0.12))
	_pose_bone("LeftArm", Vector3(0.1, 0.18, 0.95))
	_pose_bone("LeftForeArm", Vector3(0.9, 0.0, 0.2))
	_pose_bone("Head", Vector3(0.05 * golpe, -0.1 * golpe, 0.0))

func _pose_bone(nome:String, euler:Vector3) -> void:
	var osso := visual_skeleton.find_bone(nome)
	if osso < 0:
		return
	var descanso := visual_skeleton.get_bone_rest(osso).basis.get_rotation_quaternion()
	visual_skeleton.set_bone_pose_rotation(osso, descanso * Quaternion.from_euler(euler))

# Quem estiver na frente leva: o Lips perde um ponto, os inimigos morrem.
func _punch_contact() -> void:
	var stage:Node3D = get_parent()
	# O modelo aponta para o próprio +z: o soco sai por ali.
	var frente := visual.global_transform.basis.z
	var alvo := global_position + Vector3(frente.x, 0.0, frente.z).normalized() * PUNCH_REACH * 0.5 + Vector3.UP
	POEIRA.saltar(stage, alvo)
	stage.burst(alvo, Color("fff0b8"), 16)
	var boss:Node3D = stage.boss
	if is_instance_valid(boss) and boss.active:
		var diff := boss.global_position - global_position
		if Vector2(diff.x, diff.z).length() < PUNCH_REACH:
			boss.receive_hit()
	for inimigo in get_tree().get_nodes_in_group("resgate_enemies"):
		if not inimigo.active:
			continue
		var para := (inimigo as Node3D).global_position - global_position
		if Vector2(para.x, para.z).length() < PUNCH_REACH and absf(para.y) < 2.4:
			inimigo.defeat()

func try_dash() -> void:
	if not control_enabled or dying or dash_time > 0.0 or launch_time > 0.0:
		return
	var stage:Node3D = get_parent()
	if not stage.spend_pentagrams(DASH_COST):
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Para frente e para os lados, nunca para trás.
	var direction := Vector3(input.x, 0.0, minf(input.y, 0.0))
	if arena_mode:
		# Na arena o "para frente" é o da câmera, que pode estar girada.
		direction = arena_lado() * input.x + -orbita() * maxf(-input.y, 0.0)
		if direction.length_squared() < 0.01:
			direction = -orbita()
	elif direction.length_squared() < 0.01:
		direction = Vector3(0, 0, -1)
	dash_velocity = direction.normalized() * DASH_SPEED
	dash_velocity.y = 0.0
	dash_time = DASH_TIME
	dash_trail_clock = 0.0
	set_invincible(true)
	# Mesmo peido do dash do Poço Infinito, com o tom sorteado.
	fart_audio.pitch_scale = randf_range(0.7, 0.8)
	fart_audio.play()
	camera_shake = maxf(camera_shake, 0.12)
	dash_fov_base = camera.fov
	camera.fov = dash_fov_base + 5.0
	stage.set_blur(DASH_BLUR, Vector2(0.5, 0.5))
	for i in 7:
		_spawn_dash_smoke(true)
	_spawn_dash_ghost()
	for i in 3:
		_spawn_dash_streak()

func _end_dash() -> void:
	set_invincible(false)
	velocity = dash_velocity * 0.35
	if dash_fov_base > 0.0:
		camera.fov = dash_fov_base
		dash_fov_base = 0.0
	fart_audio.pitch_scale = 0.75
	get_parent().set_blur(get_parent().BLUR_GAMEPLAY, Vector2(0.5, 0.28))

func _dash_material(cor:Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = cor
	return mat

# Silhueta do próprio Maycon ficando para trás, com a pose dos ossos copiada.
func _spawn_dash_ghost() -> void:
	var ghost:Node3D = MODEL.instantiate()
	get_parent().get_node("Effects").add_child(ghost)
	ghost.global_transform = visual.global_transform
	var copias := ghost.find_children("*", "Skeleton3D", true, false)
	if visual_skeleton != null and copias.size() > 0:
		var copia := copias[0] as Skeleton3D
		for osso in visual_skeleton.get_bone_count():
			copia.set_bone_pose_rotation(osso, visual_skeleton.get_bone_pose_rotation(osso))
			copia.set_bone_pose_position(osso, visual_skeleton.get_bone_pose_position(osso))
	var anim:AnimationPlayer = ghost.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null:
		anim.stop()
		anim.process_mode = Node.PROCESS_MODE_DISABLED
	var mat := _dash_material(DASH_GHOST_COLOR)
	for malha in ghost.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).material_override = mat
	dash_ghosts.append({"node": ghost, "mat": mat, "life": 0.25, "duration": 0.25, "alpha": DASH_GHOST_COLOR.a, "base_scale": ghost.scale})

# Riscos finos de velocidade ao redor dele, deitados na direção do dash.
func _spawn_dash_streak() -> void:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.015
	cilindro.bottom_radius = 0.07
	cilindro.height = randf_range(2.2, 4.2)
	cilindro.radial_segments = 5
	var streak := MeshInstance3D.new()
	streak.name = "RastroDoDash"
	streak.mesh = cilindro
	var mat := _dash_material(DASH_STREAK_COLOR)
	streak.material_override = mat
	get_parent().get_node("Effects").add_child(streak)
	streak.global_position = global_position + Vector3(randf_range(-0.55, 0.55), randf_range(0.25, 1.5), randf_range(-0.55, 0.55))
	var direcao := dash_velocity.normalized()
	if direcao.length_squared() > 0.001:
		streak.look_at(streak.global_position + direcao, Vector3.UP)
		streak.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	dash_ghosts.append({"node": streak, "mat": mat, "life": 0.18, "duration": 0.18, "alpha": DASH_STREAK_COLOR.a, "base_scale": streak.scale})

# A fumaça usa o mesmo sistema de baforadas que o peido do pulo duplo já tem.
func _spawn_dash_smoke(inicial:bool) -> void:
	var direcao := dash_velocity.normalized()
	var puff := Sprite3D.new()
	puff.texture = FART_SMOKE
	puff.hframes = 3
	puff.vframes = 2
	puff.frame = randi_range(0, 1)
	puff.pixel_size = randf_range(0.009, 0.014) if inicial else randf_range(0.007, 0.011)
	puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	puff.shaded = false
	puff.transparent = true
	puff.double_sided = true
	get_parent().get_node("Effects").add_child(puff)
	puff.global_position = global_position + Vector3.UP * 0.5 - direcao * 0.8 + Vector3(randf_range(-0.45, 0.45), randf_range(-0.3, 0.4), randf_range(-0.45, 0.45))
	var alpha:float = randf_range(0.18, 0.28) if inicial else randf_range(0.10, 0.18)
	puff.modulate = Color(randf_range(0.48, 0.62), randf_range(0.79, 0.92), randf_range(0.55, 0.71), alpha)
	var lado := Vector3(-direcao.z, 0.0, direcao.x) * randf_range(-2.1, 2.1)
	var duracao:float = randf_range(0.42, 0.64) if inicial else randf_range(0.35, 0.5)
	fart_puffs.append({"node": puff, "life": duracao, "duration": duracao, "alpha": alpha, "velocity": -direcao * 2.7 + lado + Vector3.UP * 0.65, "start_frame": puff.frame})

func _update_dash_ghosts(delta:float) -> void:
	for i in range(dash_ghosts.size() - 1, -1, -1):
		var data:Dictionary = dash_ghosts[i]
		var node:Node3D = data.node
		if not is_instance_valid(node):
			dash_ghosts.remove_at(i)
			continue
		data["life"] = float(data.life) - delta
		var progress:float = clampf(float(data.life) / float(data.duration), 0.0, 1.0)
		var mat:StandardMaterial3D = data.mat
		if mat != null:
			mat.albedo_color.a = pow(progress, 1.35) * float(data.alpha)
		node.scale = (data.base_scale as Vector3) * (1.0 + (1.0 - progress) * 0.10)
		if data.life <= 0.0:
			node.queue_free()
			dash_ghosts.remove_at(i)
