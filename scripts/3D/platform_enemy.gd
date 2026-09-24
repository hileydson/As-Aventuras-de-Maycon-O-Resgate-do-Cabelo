extends Area3D

const MODELS = [
	preload("res://assets/kenney/platformer_3d/character-oopi.glb"),
	preload("res://assets/kenney/platformer_3d/character-oodi.glb"),
	preload("res://assets/kenney/platformer_3d/character-ooli.glb"),
	preload("res://assets/kenney/platformer_3d/character-oozi.glb")
]

var maycon:CharacterBody3D
var stage:Node3D
var model:Node3D
var speed:float = 2.8
var activation_radius:float = 5.8
var home:Vector3
var active:bool = true
var phase:float = 0.0
var archetype:int = 0
var chase_time:float = 0.0
var state:int = 0
var rest_time:float = 0.0
var wall_shape:SphereShape3D
var trail_distance:float = 0.0
var is_slow_motion:bool = false
var blue_aura:MeshInstance3D

func setup(model_index:int, player:CharacterBody3D, world:Node3D, enemy_type:int = 0) -> void:
	maycon = player
	stage = world
	archetype = enemy_type
	model = MODELS[model_index % MODELS.size()].instantiate()
	model.scale = Vector3.ONE * (1.12 if archetype == 2 else 0.82 if archetype == 3 else 0.95)
	add_child(model)
	var colors := [Color("a33e62"), Color("42768d"), Color("b17b32"), Color("80569d")]
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[model_index % colors.size()]
	material.roughness = 0.9
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material
	_add_accessory(material)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.47 if archetype != 2 else 0.56
	shape.shape = sphere
	shape.position.y = 0.46 if archetype != 2 else 0.55
	add_child(shape)
	wall_shape = SphereShape3D.new()
	wall_shape.radius = 0.42 if archetype != 2 else 0.51
	collision_layer = 4
	collision_mask = 2
	home = global_position
	phase = randf_range(0.0, TAU)
	activation_radius = 0.0 if archetype == 2 else 5.0 if archetype == 1 else 6.2
	speed = 2.0 if archetype == 2 else 2.8 if archetype == 0 else 2.3 if archetype == 1 else 3.4
	
	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = 0.82 if archetype != 2 else 0.95
	aura_mesh.height = 1.64 if archetype != 2 else 1.9
	aura_mesh.radial_segments = 16
	aura_mesh.rings = 8
	blue_aura = MeshInstance3D.new()
	blue_aura.mesh = aura_mesh
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.albedo_color = Color(0.18, 0.65, 1.0, 0.45)
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blue_aura.material_override = aura_mat
	blue_aura.position.y = 0.52 if archetype != 2 else 0.62
	blue_aura.visible = false
	add_child(blue_aura)
	
	set_physics_process(true)

func set_slow_motion(active_val:bool) -> void:
	is_slow_motion = active_val
	if is_instance_valid(blue_aura):
		blue_aura.visible = active_val

func _add_accessory(material:StandardMaterial3D) -> void:
	if archetype == 2:
		for side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.13
			cone.height = 0.45
			horn.mesh = cone
			horn.material_override = material
			horn.position = Vector3(side * 0.25, 1.04, 0.0)
			add_child(horn)
	elif archetype == 3:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.17
		sphere.height = 0.34
		eye.mesh = sphere
		eye.material_override = material
		eye.position.y = 1.07
		add_child(eye)

func _physics_process(delta:float) -> void:
	if not active or not is_instance_valid(maycon):
		return
	var delta_eff := delta * (0.10 if is_slow_motion else 1.0)
	if is_slow_motion and is_instance_valid(blue_aura):
		blue_aura.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.08)
	rest_time = maxf(rest_time - delta_eff, 0.0)
	phase += delta_eff * 3.0
	model.position.y = absf(sin(phase * 1.7)) * 0.24 if archetype == 3 else sin(phase) * 0.05
	var difference := maycon.global_position - global_position
	var horizontal := Vector2(difference.x, difference.z)
	if state == 0 and rest_time <= 0.0 and activation_radius > 0.0 and horizontal.length() < activation_radius and absf(difference.y) < 1.8:
		state = 1
		chase_time = 3.4
	if state == 1:
		chase_time -= delta_eff
		if chase_time <= 0.0 or horizontal.length() > activation_radius * 1.4 or home.distance_to(maycon.global_position) > 8.5:
			state = 2
		elif horizontal.length() > 0.66:
			_move_toward(maycon.global_position, speed, delta_eff)
	elif state == 2:
		_move_toward(home, speed * 0.7, delta_eff)
		if global_position.distance_to(home) < 0.2:
			state = 0
			rest_time = 2.3
	elif archetype == 1:
		var patrol := home + Vector3(sin(phase * 0.35) * 2.4, 0.0, cos(phase * 0.35) * 2.4)
		_move_toward(patrol, speed * 0.5, delta_eff)
	if horizontal.length() < 0.74:
		_touch_maycon()
	if active and monitoring:
		for body in get_overlapping_bodies():
			if body == maycon:
				_touch_maycon()

func _move_toward(target:Vector3, move_speed:float, delta:float) -> void:
	var difference := target - global_position
	difference.y = 0.0
	if difference.length_squared() < 0.02:
		return
	var direction := difference.normalized()
	var next := global_position + direction * move_speed * delta
	var wall_query := PhysicsShapeQueryParameters3D.new()
	wall_query.shape = wall_shape
	wall_query.transform = Transform3D(Basis.IDENTITY, next + Vector3.UP * (0.75 if archetype == 2 else 0.64))
	wall_query.collision_mask = 1
	if stage.has_ground_at(next) and get_world_3d().direct_space_state.intersect_shape(wall_query).is_empty():
		trail_distance += global_position.distance_to(next)
		global_position = next
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(delta * 5.0, 1.0))
		if trail_distance >= 0.75:
			trail_distance = 0.0
			stage.spawn_enemy_trail(global_position, archetype)

func _touch_maycon() -> void:
	if not active:
		return
	if absf(maycon.global_position.y - global_position.y) > 1.65:
		return
	if is_slow_motion or stage.get("is_invincible") == true or maycon.get("is_invincible") == true:
		active = false
		monitoring = false
		_launch_away_from_maycon()
		stage.enemy_stomped(self)
		return
	if maycon.velocity.y < -1.5 and maycon.global_position.y > global_position.y + 0.68:
		active = false
		monitoring = false
		maycon.bounce()
		stage.enemy_stomped(self)
	else:
		maycon.receive_damage(17.0, global_position)

func _launch_away_from_maycon() -> void:
	if not is_instance_valid(model) or not is_instance_valid(maycon):
		return
	var away := (global_position - maycon.global_position).normalized()
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	if is_instance_valid(stage) and "effects" in stage:
		var corpse := model.duplicate() as Node3D
		corpse.position = global_position
		corpse.rotation = model.rotation
		corpse.scale = model.scale
		stage.effects.add_child(corpse)
		var fly_target := global_position + Vector3(away.x * 12.0, 6.0, away.z * 12.0)
		var fly_tw := stage.create_tween().bind_node(corpse).set_parallel(true)
		fly_tw.tween_property(corpse, "position", fly_target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly_tw.tween_property(corpse, "rotation", Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)), 0.55)
		fly_tw.tween_property(corpse, "scale", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tw.chain().tween_callback(corpse.queue_free)
