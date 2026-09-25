class_name DungeonInfected
extends CharacterBody3D

signal caught_player(infected:DungeonInfected)
signal died(infected:DungeonInfected)

var player:DungeonPlayer
var dungeon:Node
var home:Vector3
var released:bool = false
var enraged:bool = false
var dead:bool = false
var health:int = 3
var speed:float = 1.05
var release_distance:float = 0.0
var sway:float = 0.0
var growl_cooldown:float = 1.0
var model_root:Node3D
var metal_sound:AudioStreamPlayer3D
var growl_sound:AudioStreamPlayer3D
var enemy_kind:String = "zombie"
var model_scale:float = 1.0
var wander_target:Vector3
var wander_timer:float = 0.0
var release_grace_time:float = 0.0
var animator:AnimationPlayer
var current_animation:StringName = &""
var model_origin:Vector3 = Vector3.ZERO

func setup(target:DungeonPlayer, owner_dungeon:Node, model_path:String, initially_released:bool, trigger_distance:float, kind:String = "zombie", scale_value:float = 1.0) -> void:
	player = target
	dungeon = owner_dungeon
	released = initially_released
	release_distance = trigger_distance
	enemy_kind = kind
	model_scale = scale_value
	if enemy_kind == "hound":
		speed = 1.35
		health = 2
	elif enemy_kind == "runner":
		speed = 1.1
		health = 4
	else:
		speed = 0.78
	home = global_position
	wander_target = home
	build_body(model_path)

func build_body(model_path:String) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.62 if enemy_kind == "hound" else 0.5
	capsule.height = 1.3 if enemy_kind == "hound" else 2.15
	shape.shape = capsule
	shape.position.y = 0.66 if enemy_kind == "hound" else 1.08
	add_child(shape)
	var packed:PackedScene = load(model_path)
	if packed:
		model_root = packed.instantiate()
		model_root.scale = Vector3.ONE * model_scale
		if enemy_kind == "hound":
			model_root.rotation.y = PI
		add_child(model_root)
		model_origin = model_root.position
		animator = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		play_best_animation(["idle", "walk", "run"])
	else:
		var mesh_instance := MeshInstance3D.new()
		var capsule_mesh := CapsuleMesh.new()
		capsule_mesh.radius = 0.42
		capsule_mesh.height = 1.75
		mesh_instance.mesh = capsule_mesh
		mesh_instance.position.y = 0.88
		add_child(mesh_instance)
	metal_sound = make_spatial_audio("res://assets/novos_audios/metal_batendo.mp3", -9.0, 16.0)
	growl_sound = make_spatial_audio("res://assets/novos_audios/calabouco_terror/zombie_growl_pixabay.mp3", -7.0, 20.0)

func make_spatial_audio(path:String, volume:float, distance:float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = load(path)
	audio.volume_db = volume
	audio.max_distance = distance
	audio.unit_size = 4.0
	add_child(audio)
	return audio

func release_from_cell() -> void:
	if released || dead:
		return
	released = true
	release_grace_time = 8.0
	wander_timer = 0.0
	if is_instance_valid(metal_sound):
		metal_sound.play()

func _physics_process(delta:float) -> void:
	if dead || !is_instance_valid(player):
		return
	sway += delta
	growl_cooldown -= delta
	if !released:
		velocity = Vector3.ZERO
		rotation.z = sin(sway * 3.4) * 0.035
		update_model_motion(false, false)
		if growl_cooldown <= 0.0:
			growl_cooldown = randf_range(3.0, 7.0)
			if randf() < 0.5 && is_instance_valid(metal_sound):
				metal_sound.play()
		return
	release_grace_time = maxf(0.0, release_grace_time - delta)
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var player_hidden:bool = dungeon.call("is_player_hidden")
	if release_grace_time > 0.0:
		wander_timer -= delta
		if wander_timer <= 0.0 || global_position.distance_to(wander_target) < 0.6:
			wander_timer = randf_range(1.8, 3.5)
			wander_target = home + Vector3(randf_range(-2.8, 2.8), 0.0, randf_range(-2.8, 2.8))
		var leave_direction := wander_target - global_position
		leave_direction.y = 0.0
		velocity = leave_direction.normalized() * speed * 0.42
		if velocity.length() > 0.1:
			look_at(global_position + velocity, Vector3.UP)
		move_and_slide()
		update_model_motion(true, false)
		return
	var lit:bool = is_lit_by_flashlight()
	if lit:
		enraged = true
		if growl_cooldown <= 0.0 && is_instance_valid(growl_sound):
			growl_sound.play()
			growl_cooldown = 2.4
	if player_hidden:
		enraged = false
		var back := home - global_position
		back.y = 0.0
		if back.length() > 0.35:
			velocity = back.normalized() * speed * 0.75
			look_at(global_position + velocity, Vector3.UP)
		else:
			velocity = Vector3.ZERO
	else:
		var awareness := 22.0 if enraged else 8.5
		if to_player.length() < awareness && (enraged || can_see_player()):
			var chase_speed := speed * (1.22 if enraged else 1.0)
			velocity = to_player.normalized() * chase_speed
			look_at(player.global_position * Vector3(1, 0, 1) + Vector3(0, global_position.y, 0), Vector3.UP)
		else:
			wander_timer -= delta
			if wander_timer <= 0.0 || global_position.distance_to(wander_target) < 0.8:
				wander_timer = randf_range(2.0, 5.0)
				wander_target = home + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
			var wander_direction := wander_target - global_position
			wander_direction.y = 0.0
			velocity = wander_direction.normalized() * speed * 0.45
			if velocity.length() > 0.1:
				look_at(global_position + velocity, Vector3.UP)
	move_and_slide()
	update_model_motion(velocity.length() > 0.12, enraged)
	if !player_hidden && global_position.distance_to(player.global_position) < 1.05:
		caught_player.emit(self)

func play_best_animation(preferred:Array) -> void:
	if !is_instance_valid(animator) || animator.get_animation_list().is_empty():
		return
	var candidates:PackedStringArray = animator.get_animation_list()
	var chosen:StringName = &""
	for wanted in preferred:
		for animation_name in candidates:
			var lowered := str(animation_name).to_lower()
			if wanted in lowered && "reset" not in lowered:
				chosen = animation_name
				break
		if chosen != &"":
			break
	if chosen == &"":
		for animation_name in candidates:
			if "reset" not in str(animation_name).to_lower():
				chosen = animation_name
				break
	if chosen != &"":
		var animation := animator.get_animation(chosen)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR
	if chosen != &"" && (chosen != current_animation || !animator.is_playing()):
		current_animation = chosen
		animator.play(chosen)

func update_model_motion(moving:bool, chasing:bool) -> void:
	if !is_instance_valid(model_root):
		return
	if is_instance_valid(animator):
		play_best_animation(["run", "walk", "idle"] if moving else ["idle", "walk", "run"])
		animator.speed_scale = 0.82 if chasing else (0.58 if moving else 0.34)
		return
	var motion_amount := 1.0 if moving else 0.28
	model_root.position = model_origin + Vector3(0, absf(sin(sway * 5.2)) * 0.075 * motion_amount, 0)
	model_root.rotation.z = sin(sway * 5.2) * 0.055 * motion_amount
	model_root.rotation.x = sin(sway * 2.6) * 0.025

func is_lit_by_flashlight() -> bool:
	if !player.has_flashlight || !player.flashlight_on:
		return false
	var from_camera := global_position + Vector3.UP * 0.9 - player.camera.global_position
	if from_camera.length() > 19.0:
		return false
	return player.camera_forward().dot(from_camera.normalized()) > 0.86

func can_see_player() -> bool:
	var eye := global_position + Vector3.UP * (0.65 if enemy_kind == "hound" else 1.25)
	var target := player.global_position + Vector3.UP * 1.0
	var direction := target - eye
	if direction.length() > 10.0:
		return false
	var forward := -global_transform.basis.z
	if forward.dot(direction.normalized()) < -0.15:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() || hit.get("collider") == player

func take_damage(amount:int) -> void:
	if dead:
		return
	health -= amount
	enraged = true
	if is_instance_valid(growl_sound):
		growl_sound.play()
	if health <= 0:
		dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(dungeon) && dungeon.has_method("spawn_enemy_death_blood"):
			dungeon.call("spawn_enemy_death_blood", global_position + Vector3.UP * (0.55 if enemy_kind == "hound" else 1.05), enemy_kind)
		died.emit(self)
		var tween := create_tween().set_parallel()
		tween.tween_property(model_root, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "rotation:y", rotation.y + randf_range(-0.5, 0.5), 0.16)
		await tween.finished
		queue_free()
