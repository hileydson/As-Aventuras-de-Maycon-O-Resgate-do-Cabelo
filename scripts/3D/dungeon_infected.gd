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

func setup(target:DungeonPlayer, owner_dungeon:Node, model_path:String, initially_released:bool, trigger_distance:float) -> void:
	player = target
	dungeon = owner_dungeon
	released = initially_released
	release_distance = trigger_distance
	home = global_position
	build_body(model_path)

func build_body(model_path:String) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.88
	add_child(shape)
	var packed:PackedScene = load(model_path)
	if packed:
		model_root = packed.instantiate()
		model_root.scale = Vector3.ONE * 1.35
		add_child(model_root)
		var animator := find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator && !animator.get_animation_list().is_empty():
			var candidates = animator.get_animation_list()
			var chosen:StringName = candidates[0]
			for animation_name in candidates:
				if "idle" in str(animation_name).to_lower() || "walk" in str(animation_name).to_lower():
					chosen = animation_name
					break
			animator.play(chosen)
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
		if growl_cooldown <= 0.0:
			growl_cooldown = randf_range(3.0, 7.0)
			if randf() < 0.5 && is_instance_valid(metal_sound):
				metal_sound.play()
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var player_hidden:bool = dungeon.call("is_player_hidden")
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
			velocity = back.normalized() * 1.15
			look_at(global_position + velocity, Vector3.UP)
		else:
			velocity = Vector3.ZERO
	else:
		var awareness := 18.0 if enraged else 6.0
		if to_player.length() < awareness:
			var chase_speed := 4.6 if enraged else speed
			velocity = to_player.normalized() * chase_speed
			look_at(player.global_position * Vector3(1, 0, 1) + Vector3(0, global_position.y, 0), Vector3.UP)
		else:
			velocity = Vector3(sin(sway * 0.7), 0.0, cos(sway * 0.55)) * 0.32
	move_and_slide()
	if !player_hidden && global_position.distance_to(player.global_position) < 1.05:
		caught_player.emit(self)

func is_lit_by_flashlight() -> bool:
	if !player.has_flashlight || !player.flashlight_on:
		return false
	var from_camera := global_position + Vector3.UP * 0.9 - player.camera.global_position
	if from_camera.length() > 19.0:
		return false
	return player.camera_forward().dot(from_camera.normalized()) > 0.86

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
		var tween := create_tween().set_parallel()
		tween.tween_property(self, "rotation:x", PI * 0.5, 0.35)
		tween.tween_property(self, "position:y", -0.55, 0.35)
		await tween.finished
		died.emit(self)
		queue_free()
