class_name DungeonInfected
extends CharacterBody3D

signal caught_player(infected:DungeonInfected)
signal died(infected:DungeonInfected)

const ZOMBIE_GROWL_1 := preload("res://assets/novos_audios/calabouco_terror/zombie_growl_pixabay.mp3")
const ZOMBIE_GROWL_2 := preload("res://assets/novos_audios/calabouco_terror/zombie_growl_2.wav")
const ZOMBIE_PAIN := preload("res://assets/novos_audios/calabouco_terror/zombie_pain_1.wav")
const ZOMBIE_SCREAM := preload("res://assets/novos_audios/calabouco_terror/monster_scream_2.wav")

const RAT_SNARL := preload("res://assets/novos_audios/calabouco_terror/rat_snarl_1.wav")
const RAT_ATTACK := preload("res://assets/novos_audios/calabouco_terror/rat_attack_1.wav")

const MUTANT_ROAR_1 := preload("res://assets/novos_audios/calabouco_terror/monster_roar_1.wav")
const MUTANT_ROAR_2 := preload("res://assets/novos_audios/calabouco_terror/monster_roar_2.wav")
const MUTANT_SCREAM := preload("res://assets/novos_audios/calabouco_terror/monster_scream_1.wav")

const METAL_SOUND := preload("res://assets/novos_audios/metal_batendo.mp3")

var player:DungeonPlayer
var dungeon:Node
var home:Vector3
var released:bool = false
var enraged:bool = false
var dead:bool = false
var health:int = 3
var speed:float = 1.15
var release_distance:float = 0.0
var sway:float = 0.0
var growl_cooldown:float = 1.0
var model_root:Node3D
var metal_audio:AudioStreamPlayer3D
var growl_audio:AudioStreamPlayer3D
var attack_audio:AudioStreamPlayer3D
var pain_audio:AudioStreamPlayer3D
var enemy_kind:String = "zombie"
var model_scale:float = 1.0
var wander_target:Vector3
var wander_timer:float = 0.0
var release_grace_time:float = 0.0
var cell_target:Vector3
var cell_wander_timer:float = 0.0
var cell_is_moving:bool = false
var animator:AnimationPlayer
var current_animation:StringName = &""
var model_origin:Vector3 = Vector3.ZERO
var is_attacking:bool = false
var is_leaping:bool = false
var leap_timer:float = 0.0

func setup(target:DungeonPlayer, owner_dungeon:Node, model_path:String, initially_released:bool, trigger_distance:float, kind:String = "zombie", scale_value:float = 1.0) -> void:
	player = target
	dungeon = owner_dungeon
	released = initially_released
	release_distance = trigger_distance
	enemy_kind = kind
	model_scale = scale_value
	if enemy_kind == "hound":
		speed = 2.4
		health = 4
	elif enemy_kind == "mutant":
		speed = 1.45
		health = 8
	else:
		speed = 1.15
		health = 6
	home = global_position if is_inside_tree() else position
	wander_target = home
	cell_target = home
	build_body(model_path)

func build_body(model_path:String) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55 if enemy_kind == "hound" else 0.48
	capsule.height = 1.1 if enemy_kind == "hound" else 2.1
	shape.shape = capsule
	shape.position.y = 0.55 if enemy_kind == "hound" else 1.05
	add_child(shape)
	
	var packed:PackedScene = load(model_path)
	if packed:
		model_root = packed.instantiate()
		model_root.scale = Vector3.ONE * model_scale
		add_child(model_root)
		model_origin = model_root.position
		
		# Limpeza de geometrias extras
		for extra in ["Icosphere", "Icosphere_001", "Icosphere_002", "pCube1", "pCube2"]:
			var extra_node = model_root.find_child(extra, true, false)
			if extra_node:
				extra_node.queue_free()
				
		if enemy_kind == "hound":
			# Rato rotacionado 180 graus para a cabeça apontar para frente (-Z)
			model_root.rotation.y = PI
			
			# Materiais de rato horror: pelo escuro, olhos vermelhos brilhantes e dentes sujos
			var fur_mat := StandardMaterial3D.new()
			fur_mat.albedo_color = Color(0.18, 0.14, 0.11)
			fur_mat.roughness = 0.88
			
			var eye_mat := StandardMaterial3D.new()
			eye_mat.albedo_color = Color(0.9, 0.02, 0.02)
			eye_mat.emission_enabled = true
			eye_mat.emission = Color(1.0, 0.05, 0.05)
			eye_mat.emission_energy_multiplier = 2.5
			
			var teeth_mat := StandardMaterial3D.new()
			teeth_mat.albedo_color = Color(0.85, 0.78, 0.55)
			teeth_mat.roughness = 0.4
			
			for m_name in ["Body", "Head"]:
				var mesh_node = model_root.find_child(m_name, true, false) as MeshInstance3D
				if mesh_node:
					mesh_node.material_override = fur_mat
			var eyes_node = model_root.find_child("Eyes", true, false) as MeshInstance3D
			if eyes_node:
				eyes_node.material_override = eye_mat
			var teeth_node = model_root.find_child("Teeth", true, false) as MeshInstance3D
			if teeth_node:
				teeth_node.material_override = teeth_mat
		animator = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator:
			play_idle_animation()
	else:
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.42
		capsule_mesh.height = 1.75
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position.y = 0.88
		add_child(mesh_instance)
		
	metal_audio = make_spatial_audio(METAL_SOUND, -9.0, 16.0)
	pain_audio = make_spatial_audio(ZOMBIE_PAIN, -6.0, 18.0)
	
	if enemy_kind == "hound":
		growl_audio = make_spatial_audio(RAT_SNARL, -6.0, 20.0)
		attack_audio = make_spatial_audio(RAT_ATTACK, -5.0, 22.0)
	elif enemy_kind == "mutant":
		growl_audio = make_spatial_audio(MUTANT_ROAR_1, -5.0, 22.0)
		attack_audio = make_spatial_audio(MUTANT_SCREAM, -4.0, 24.0)
	else:
		growl_audio = make_spatial_audio(ZOMBIE_GROWL_1, -6.0, 20.0)
		attack_audio = make_spatial_audio(ZOMBIE_SCREAM, -4.0, 24.0)

func make_spatial_audio(stream_res:AudioStream, volume:float, distance:float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream_res
	audio.volume_db = volume
	audio.max_distance = distance
	audio.unit_size = 4.0
	add_child(audio)
	return audio

func release_from_cell() -> void:
	if released || dead:
		return
	released = true
	release_grace_time = 5.0
	wander_timer = 0.0
	# Ao abrir a cela sai andando pelo cenário
	var forward_exit := -global_transform.basis.z * 3.5
	wander_target = global_position + forward_exit + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
	if is_instance_valid(metal_audio):
		metal_audio.play()

func _physics_process(delta:float) -> void:
	if dead || !is_instance_valid(player):
		return
	sway += delta
	growl_cooldown -= delta
	
	if !is_on_floor():
		velocity.y -= 18.0 * delta
		
	if !released:
		cell_wander_timer -= delta
		if cell_wander_timer <= 0.0 || global_position.distance_to(cell_target) < 0.35:
			cell_wander_timer = randf_range(2.2, 4.5)
			# Ponto aleatório dentro da cela (raio de 1.15m em torno de home)
			cell_target = home + Vector3(randf_range(-1.15, 1.15), 0.0, randf_range(-1.15, 1.15))
			cell_is_moving = randf() < 0.82
		
		if cell_is_moving:
			var cell_dir := cell_target - global_position
			cell_dir.y = 0.0
			if cell_dir.length() > 0.15:
				var move_speed := speed * 0.42
				velocity.x = cell_dir.normalized().x * move_speed
				velocity.z = cell_dir.normalized().z * move_speed
				look_at_horizontal(global_position + velocity)
				update_model_motion(true, false)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				update_model_motion(false, false)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			rotation.z = sin(sway * 2.8) * 0.02
			update_model_motion(false, false)
			
		if growl_cooldown <= 0.0:
			growl_cooldown = randf_range(3.5, 7.5)
			if randf() < 0.45 && is_instance_valid(metal_audio):
				metal_audio.play()
		move_and_slide()
		return

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return
		
	# Hound leap logic
	if is_leaping:
		leap_timer -= delta
		move_and_slide()
		if global_position.distance_to(player.global_position) < 1.3:
			trigger_caught()
		elif leap_timer <= 0.0:
			is_leaping = false
		return

	release_grace_time = maxf(0.0, release_grace_time - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist_to_player := to_player.length()
	var player_hidden:bool = dungeon.call("is_player_hidden")
	
	if release_grace_time > 0.0:
		wander_timer -= delta
		if wander_timer <= 0.0 || global_position.distance_to(wander_target) < 0.6:
			wander_timer = randf_range(1.6, 3.2)
			wander_target = home + Vector3(randf_range(-2.8, 2.8), 0.0, randf_range(-2.8, 2.8))
		var leave_direction := wander_target - global_position
		leave_direction.y = 0.0
		velocity.x = leave_direction.normalized().x * speed * 0.48
		velocity.z = leave_direction.normalized().z * speed * 0.48
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			look_at_horizontal(global_position + velocity)
		move_and_slide()
		update_model_motion(true, false)
		return
		
	var lit:bool = is_lit_by_flashlight()
	if lit:
		enraged = true
		if growl_cooldown <= 0.0:
			play_growl_sound()
			growl_cooldown = randf_range(2.0, 3.5)
			
	if player_hidden:
		enraged = false
		var back := home - global_position
		back.y = 0.0
		if back.length() > 0.4:
			velocity.x = back.normalized().x * speed * 0.65
			velocity.z = back.normalized().z * speed * 0.65
			look_at_horizontal(global_position + velocity)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		var awareness := 24.0 if enraged else 9.0
		if dist_to_player < awareness && (enraged || can_see_player()):
			look_at_horizontal(player.global_position)
			
			# Rato saltando no player
			if enemy_kind == "hound" && dist_to_player < 2.9 && can_see_player() && is_on_floor():
				is_leaping = true
				leap_timer = 0.8
				if is_instance_valid(attack_audio):
					attack_audio.play()
				play_animation_by_names(["Attack_000", "attack", "run"])
				var jump_dir := (player.global_position - global_position).normalized()
				velocity = jump_dir * 7.2 + Vector3(0, 3.2, 0)
				move_and_slide()
				return
				
			var chase_speed := speed * (1.35 if enraged else 1.0)
			velocity.x = to_player.normalized().x * chase_speed
			velocity.z = to_player.normalized().z * chase_speed
			
			# Chegou perto para atacar / agarrar
			if dist_to_player < 1.45:
				trigger_caught()
				return
		else:
			wander_timer -= delta
			if wander_timer <= 0.0 || global_position.distance_to(wander_target) < 0.8:
				wander_timer = randf_range(2.0, 4.5)
				wander_target = home + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
			var wander_direction := wander_target - global_position
			wander_direction.y = 0.0
			velocity.x = wander_direction.normalized().x * speed * 0.45
			velocity.z = wander_direction.normalized().z * speed * 0.45
			if Vector2(velocity.x, velocity.z).length() > 0.1:
				look_at_horizontal(global_position + velocity)
				
	move_and_slide()
	update_model_motion(Vector2(velocity.x, velocity.z).length() > 0.12, enraged)

func trigger_caught() -> void:
	if is_attacking || dead:
		return
	is_attacking = true
	look_at_horizontal(player.global_position)
	if is_instance_valid(attack_audio):
		attack_audio.play()
	if enemy_kind == "hound":
		play_animation_by_names(["Attack_000", "attack", "run"])
	else:
		play_animation_by_names(["attack", "run", "walk"])
		# Inimigo estica as mãos na direção do player e avança levemente
		create_tween().tween_property(self, "global_position", global_position + (player.global_position - global_position).normalized() * 0.4, 0.25)
	caught_player.emit(self)

func recover_from_attack(recovery_time:float = 1.3) -> void:
	if dead:
		return
	var t := create_tween()
	t.tween_interval(recovery_time)
	t.tween_callback(func():
		if !dead:
			is_attacking = false
			is_leaping = false
	)

func look_at_horizontal(target_pos:Vector3) -> void:
	var h_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_squared_to(h_target) > 0.001:
		look_at(h_target, Vector3.UP)

func play_growl_sound() -> void:
	if !is_instance_valid(growl_audio):
		return
	if enemy_kind == "zombie":
		growl_audio.stream = ZOMBIE_GROWL_2 if randf() < 0.5 else ZOMBIE_GROWL_1
	elif enemy_kind == "mutant":
		growl_audio.stream = MUTANT_ROAR_2 if randf() < 0.5 else MUTANT_ROAR_1
	growl_audio.pitch_scale = randf_range(0.92, 1.1)
	growl_audio.play()

func play_idle_animation() -> void:
	if enemy_kind == "hound":
		play_animation_by_names(["Idle_000", "idle", "Stand"])
	elif enemy_kind == "mutant":
		play_animation_by_names(["walk", "tentacleWalk"])
	else:
		play_animation_by_names(["idle", "walk"])

func play_animation_by_names(names:Array) -> void:
	if !is_instance_valid(animator) || animator.get_animation_list().is_empty():
		return
	var candidate_list := animator.get_animation_list()
	for wanted in names:
		for anim_name in candidate_list:
			if str(anim_name).to_lower() == str(wanted).to_lower() || str(wanted).to_lower() in str(anim_name).to_lower():
				if anim_name != current_animation || !animator.is_playing():
					current_animation = anim_name
					var anim := animator.get_animation(anim_name)
					if anim:
						anim.loop_mode = Animation.LOOP_LINEAR if "attack" not in str(wanted).to_lower() else Animation.LOOP_NONE
					animator.play(anim_name)
					animator.speed_scale = 1.0
				return

func update_model_motion(moving:bool, chasing:bool) -> void:
	if !is_instance_valid(model_root):
		return
	if is_instance_valid(animator):
		if moving:
			if enemy_kind == "hound":
				play_animation_by_names(["Run" if chasing else "Walk", "run", "walk"])
				animator.speed_scale = 1.4 if chasing else 1.0
			elif enemy_kind == "mutant":
				play_animation_by_names(["tentacleWalk", "walk"])
				animator.speed_scale = 1.3 if chasing else 0.9
			else:
				play_animation_by_names(["run" if chasing else "walk", "walk", "idle"])
				animator.speed_scale = 1.25 if chasing else 1.0
		else:
			play_idle_animation()
			animator.speed_scale = 1.0
		return
		
	# Fallback procedual se o modelo não tiver animação
	var motion_amount := 1.0 if moving else 0.28
	model_root.position = model_origin + Vector3(0, absf(sin(sway * 5.2)) * 0.075 * motion_amount, 0)
	model_root.rotation.z = sin(sway * 5.2) * 0.055 * motion_amount
	model_root.rotation.x = sin(sway * 2.6) * 0.025

func is_lit_by_flashlight() -> bool:
	if !player.has_flashlight || !player.flashlight_on:
		return false
	var from_camera := global_position + Vector3.UP * 0.9 - player.camera.global_position
	if from_camera.length() > 20.0:
		return false
	return player.camera_forward().dot(from_camera.normalized()) > 0.85

func can_see_player() -> bool:
	var eye := global_position + Vector3.UP * (0.6 if enemy_kind == "hound" else 1.25)
	var target := player.global_position + Vector3.UP * 1.0
	var direction := target - eye
	if direction.length() > 14.0:
		return false
	var forward := -global_transform.basis.z
	if forward.dot(direction.normalized()) < -0.15:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() || hit.get("collider") == player

func take_damage(amount:int, weapon_type:String = "pistol") -> void:
	if dead:
		return
	health -= amount
	enraged = true
	if is_instance_valid(pain_audio):
		pain_audio.pitch_scale = randf_range(0.9, 1.15)
		pain_audio.play()
	if is_instance_valid(animator):
		# Pequena reação de hit ou recuo
		var tween := create_tween()
		tween.tween_property(self, "global_position", global_position - global_transform.basis.z * 0.25, 0.1)
	if health <= 0:
		dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(dungeon) && dungeon.has_method("spawn_enemy_death_blood"):
			dungeon.call("spawn_enemy_death_blood", global_position + Vector3.UP * (0.55 if enemy_kind == "hound" else 1.05), enemy_kind)
		if is_instance_valid(dungeon) && dungeon.has_method("spawn_ammo_drop"):
			dungeon.call("spawn_ammo_drop", global_position + Vector3.UP * 0.35, weapon_type)
		died.emit(self)
		var tween := create_tween().set_parallel()
		tween.tween_property(model_root, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation:y", rotation.y + randf_range(-0.6, 0.6), 0.2)
		await tween.finished
		queue_free()
