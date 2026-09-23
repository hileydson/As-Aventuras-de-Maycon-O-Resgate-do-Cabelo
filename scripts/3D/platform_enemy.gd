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
var health:int = 1
var chase_time:float = 0.0
var state:int = 0
var damage_cooldown:float = 0.0
var rest_time:float = 0.0

func setup(model_index:int, player:CharacterBody3D, world:Node3D, enemy_type:int = 0) -> void:
	maycon = player
	stage = world
	archetype = enemy_type
	health = 3 if archetype == 2 else 2 if archetype == 3 else 1
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
	collision_layer = 4
	collision_mask = 2
	home = global_position
	phase = randf_range(0.0, TAU)
	activation_radius = 0.0 if archetype == 2 else 5.0 if archetype == 1 else 6.2
	speed = 2.0 if archetype == 2 else 2.8 if archetype == 0 else 2.3 if archetype == 1 else 3.4
	set_physics_process(true)

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
	damage_cooldown = maxf(damage_cooldown - delta, 0.0)
	rest_time = maxf(rest_time - delta, 0.0)
	phase += delta * 3.0
	model.position.y = absf(sin(phase * 1.7)) * 0.24 if archetype == 3 else sin(phase) * 0.05
	var difference := maycon.global_position - global_position
	var horizontal := Vector2(difference.x, difference.z)
	if state == 0 and rest_time <= 0.0 and activation_radius > 0.0 and horizontal.length() < activation_radius and absf(difference.y) < 1.8:
		state = 1
		chase_time = 3.4
	if state == 1:
		chase_time -= delta
		if chase_time <= 0.0 or horizontal.length() > activation_radius * 1.4 or home.distance_to(maycon.global_position) > 8.5:
			state = 2
		elif horizontal.length() > 0.66:
			_move_toward(maycon.global_position, speed, delta)
	elif state == 2:
		_move_toward(home, speed * 0.7, delta)
		if global_position.distance_to(home) < 0.2:
			state = 0
			rest_time = 2.3
	elif archetype == 1:
		var patrol := home + Vector3(sin(phase * 0.35) * 2.4, 0.0, cos(phase * 0.35) * 2.4)
		_move_toward(patrol, speed * 0.5, delta)
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
	if stage.has_ground_at(next):
		global_position = next
		model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.z), minf(delta * 5.0, 1.0))

func take_damage(amount:int) -> bool:
	if not active or damage_cooldown > 0.0:
		return false
	damage_cooldown = 0.16
	health -= amount
	if health <= 0:
		active = false
		monitoring = false
		stage.enemy_defeated(self)
	else:
		stage.enemy_hit(self)
	return true

func _touch_maycon() -> void:
	if not active:
		return
	if absf(maycon.global_position.y - global_position.y) > 1.65:
		return
	if maycon.velocity.y < -1.5 and maycon.global_position.y > global_position.y + 0.68:
		active = false
		monitoring = false
		maycon.bounce()
		stage.enemy_stomped(self)
	else:
		maycon.receive_damage(17.0, global_position)
