extends Node3D

const ENEMY_SCRIPT = preload("res://scripts/3D/platform_enemy.gd")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const ASSET_ROOT = "res://assets/kenney/platformer_3d/"
const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const BLOOD_OVERLAY_SCRIPT = preload("res://scripts/3D/platform_blood_overlay.gd")
const HUBS = [
	Vector3(0, 0, 32), Vector3(-25, 1, 8), Vector3(25, 0.5, 8),
	Vector3(-44, 2, -24), Vector3(44, 1.5, -24),
	Vector3(-25, 2.8, -54), Vector3(25, 0.5, -54),
	Vector3(-48, 1.2, -87), Vector3(48, 3, -87),
	Vector3(-23, 0.5, -118), Vector3(23, 2, -118),
	Vector3(-43, 2.8, -151), Vector3(43, 0.5, -151),
	Vector3(0, 0, -183)
]
const ROUTES = [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4),
	Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 8),
	Vector2i(7, 9), Vector2i(8, 10), Vector2i(9, 11), Vector2i(10, 12),
	Vector2i(11, 13), Vector2i(12, 13),
	Vector2i(3, 4), Vector2i(5, 6), Vector2i(7, 8), Vector2i(9, 10)
]

@onready var maycon:CharacterBody3D = $Maycon

var materials:Dictionary = {}
var assets:Dictionary = {}
var geometry:Node3D
var enemies:Node3D
var effects:Node3D
var hp_bar:ProgressBar
var hp_label:Label
var pentagram_label:Label
var blood_overlay:Control
var pentagram_nodes:Dictionary = {}
var exit_started:bool = false
var blood_pickups:Array[Node3D] = []
var total_stomps:int = 0

func _ready() -> void:
	get_tree().paused = false
	Global.save_progress("fase_3d_platform")
	GameSongs.play_song(1)
	_build_materials()
	_build_environment()
	geometry = Node3D.new()
	geometry.name = "Cenario"
	add_child(geometry)
	_build_clouds()
	enemies = Node3D.new()
	enemies.name = "Inimigos"
	add_child(enemies)
	effects = Node3D.new()
	effects.name = "Efeitos"
	add_child(effects)
	_build_hubs_and_routes()
	_build_elevated_areas()
	_build_finish()
	_scatter_details()
	_spawn_enemies()
	_spawn_pentagrams()
	_build_blue_particles()
	_build_hud()
	_build_pause()
	update_hud()

func _physics_process(delta:float) -> void:
	if exit_started:
		return
	if maycon.global_position.y < -7.0:
		var point := maycon.global_position
		if absf(point.x) < 2.3 and point.z < -202.8 and point.z > -210.5:
			_exit_stage()
		else:
			respawn(false)
	for i in range(blood_pickups.size() - 1, -1, -1):
		var pickup := blood_pickups[i]
		if not is_instance_valid(pickup):
			blood_pickups.remove_at(i)
			continue
		pickup.rotate_y(delta * 2.0)
		if pickup.global_position.distance_to(maycon.global_position + Vector3.UP) < 1.4:
			Global.realtime_hp = minf(Global.realtime_hp_max, Global.realtime_hp + 11.0)
			blood_pickups.remove_at(i)
			pickup.queue_free()
			update_hud()
	for id in pentagram_nodes.keys():
		var item:Node3D = pentagram_nodes[id]
		if not is_instance_valid(item):
			continue
		item.rotate_y(delta * 1.3)
		if item.global_position.distance_to(maycon.global_position + Vector3.UP * 0.9) < 1.35:
			_spawn_color_burst(item.global_position, true)
			Global.platform_pentagram_collected[id] = true
			Global.platform_pentagrams += 1
			pentagram_nodes.erase(id)
			item.queue_free()
			Global.save_progress("fase_3d_platform")
			update_hud()

func _build_materials() -> void:
	materials["grass"] = _material(Color("529755"), 0.9)
	materials["grass_light"] = _material(Color("75ae64"), 0.9)
	materials["earth"] = _material(Color("8f6248"), 1.0)
	materials["earth_dark"] = _material(Color("614335"), 1.0)
	materials["stone"] = _material(Color("c8b8a0"), 0.95)
	materials["stone_dark"] = _material(Color("827c83"), 1.0)
	materials["gold"] = _material(Color("f9ca51"), 0.32)
	materials["red"] = _material(Color("b71d3b"), 0.8)
	materials["blood"] = _material(Color("700016"), 0.46)
	materials["water"] = _material(Color("61b5ca"), 0.3)
	materials["wood"] = _material(Color("915b39"), 1.0)
	materials["leaves"] = _material(Color("43835c"), 1.0)
	materials["pine"] = _material(Color("345e54"), 1.0)
	materials["flower"] = _material(Color("ee8fac"), 0.9)
	materials["mushroom"] = _material(Color("e46f52"), 0.9)

func _material(color:Color, roughness:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91c8e7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e0e6ef")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("a8d0e6")
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff0c9")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)
	# The distant water and stone silhouettes make the floating islands feel like a world.
	_box(Vector3(0.0, -18.0, -83.0), Vector3(300.0, 1.0, 360.0), "water", false)
	for i in range(34):
		var z := 55.0 - float(i) * 8.0
		for side in [-1.0, 1.0]:
			var height := 8.0 + float((i * 7) % 9)
			_box(Vector3(side * (77.0 + float((i * 3) % 9)), -9.0 + height * 0.5, z), Vector3(8.0 + float(i % 3) * 3.0, height, 8.0), "stone_dark", false)

func _box(center:Vector3, size:Vector3, material_name:String, solid:bool = true) -> Node3D:
	var parent := geometry if is_instance_valid(geometry) else self
	var node := Node3D.new()
	node.position = center
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = materials[material_name]
	node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func _build_clouds() -> void:
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 12
	cloud_mesh.rings = 6
	var cloud_material := StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.albedo_color = Color("f8faff")
	var cloud_rng := RandomNumberGenerator.new()
	cloud_rng.seed = 91573
	for i in range(25):
		var center := Vector3(cloud_rng.randf_range(-95.0, 95.0), cloud_rng.randf_range(18.0, 32.0), cloud_rng.randf_range(-215.0, 75.0))
		for puff_index in range(4):
			var puff := MeshInstance3D.new()
			puff.mesh = cloud_mesh
			puff.material_override = cloud_material
			puff.position = center + Vector3(float(puff_index) * 3.2 - 4.8, cloud_rng.randf_range(-1.2, 1.2), cloud_rng.randf_range(-2.0, 2.0))
			puff.scale = Vector3(cloud_rng.randf_range(3.5, 5.5), cloud_rng.randf_range(1.2, 2.2), cloud_rng.randf_range(2.3, 4.2))
			geometry.add_child(puff)

func _asset(name:String, position:Vector3, scale:float = 1.0, rotation:float = 0.0) -> Node3D:
	if not assets.has(name):
		assets[name] = load(ASSET_ROOT + name + ".glb")
	var scene:PackedScene = assets[name]
	var model:Node3D = scene.instantiate()
	model.position = position
	model.scale = Vector3.ONE * scale
	model.rotation.y = rotation
	geometry.add_child(model)
	var tint := "stone"
	if name.begins_with("tree-pine"):
		tint = "pine"
	elif name.begins_with("tree") or name == "grass" or name == "plant":
		tint = "leaves"
	elif name.begins_with("flower"):
		tint = "flower"
	elif name == "mushrooms":
		tint = "mushroom"
	elif name.begins_with("block-grass"):
		tint = "grass_light"
	elif name.begins_with("coin") or name == "star":
		tint = "gold"
	elif name == "flag" or name == "heart":
		tint = "red"
	elif name == "crate" or name == "barrel" or name.begins_with("fence") or name == "sign":
		tint = "wood"
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = materials[tint]
	return model

func _platform(top:Vector3, footprint:Vector2, material_name:String = "grass") -> void:
	_box(top - Vector3.UP * 0.75, Vector3(footprint.x, 1.5, footprint.y), "earth" if material_name == "grass" else "stone_dark")
	_box(top + Vector3.UP * 0.09, Vector3(footprint.x, 0.18, footprint.y), material_name)

func _build_hubs_and_routes() -> void:
	for i in range(HUBS.size()):
		var hub:Vector3 = HUBS[i]
		var size := Vector2(23.0, 20.0) if i == 0 or i == HUBS.size() - 1 else Vector2(19.0, 17.0)
		_platform(hub, size)
		for side in [-1.0, 1.0]:
			for corner in [-1.0, 1.0]:
				_asset("block-grass-large", hub + Vector3(side * (size.x * 0.5 - 1.2), -0.2, corner * (size.y * 0.5 - 1.0)), 1.2, float(i) * 0.4)
	for route in ROUTES:
		var start:Vector3 = HUBS[route.x]
		var finish:Vector3 = HUBS[route.y]
		var steps := ceili(start.distance_to(finish) / 4.2)
		for i in range(1, steps):
			var point := start.lerp(finish, float(i) / float(steps))
			var material_name := "wood" if i % 4 == 0 else "stone" if i % 4 == 1 else "grass_light"
			_platform(point, Vector2(3.5, 3.5), material_name)
			if i % 5 == 0:
				_asset("rocks", point + Vector3(-1.6, 0.25, 0.0), 0.7, float(i))

func _build_elevated_areas() -> void:
	for hub_index in range(1, HUBS.size() - 1):
		var hub:Vector3 = HUBS[hub_index]
		var side := -1.0 if hub.x < 0.0 else 1.0
		for step in range(1, 5):
			var top := hub + Vector3(side * (1.0 + float(step) * 2.0), float(step) * 0.82, 5.0 - float(step) * 2.1)
			_platform(top, Vector2(3.5, 3.5), "grass_light")
		var balcony := hub + Vector3(side * 11.0, 4.1, -4.0)
		_platform(balcony, Vector2(7.0, 7.0), "grass")
		_asset("star", balcony + Vector3.UP * 1.1, 1.6)
		for step in range(2):
			var overlook := hub + Vector3(side * (13.0 + float(step) * 4.1), 4.1 - float(step) * 0.7, -4.0 - float(step) * 3.3)
			_platform(overlook, Vector2(3.4, 3.4), "stone")

func _build_finish() -> void:
	# The final flag surrounds a real opening; only the side and end caps are solid.
	_platform(Vector3(0.0, 0.0, -195.0), Vector2(17.0, 5.0))
	for side in [-1.0, 1.0]:
		_platform(Vector3(side * 6.0, 0.0, -206.0), Vector2(8.0, 14.0), "stone")
	for z in [-200.0, -212.0]:
		_platform(Vector3(0.0, 0.0, z), Vector2(4.0, 4.0), "stone")
	_asset("flag", Vector3(-5.0, 0.15, -199.0), 6.0, PI * 0.5)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var ring := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		ring.mesh = mesh
		ring.material_override = materials["gold"]
		ring.position = Vector3(cos(angle) * 2.4, 0.34, -206.0 + sin(angle) * 2.4)
		geometry.add_child(ring)
	var beam := OmniLight3D.new()
	beam.position = Vector3(0.0, -0.5, -206.0)
	beam.light_color = Color("ffc45b")
	beam.light_energy = 1.5
	beam.omni_range = 6.0
	add_child(beam)

func _scatter_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 746302
	for i in range(HUBS.size()):
		var hub:Vector3 = HUBS[i]
		var half := 10.0 if i == 0 or i == HUBS.size() - 1 else 8.0
		for j in range(18):
			var side := -1.0 if j % 2 == 0 else 1.0
			var x := side * rng.randf_range(half - 2.6, half - 0.9)
			var position := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			var name := "tree" if j % 5 == 0 else "tree-pine-small" if j % 5 == 1 else "flowers" if j % 5 == 2 else "rocks" if j % 5 == 3 else "mushrooms"
			var size := rng.randf_range(1.3, 2.8) if name.begins_with("tree") else rng.randf_range(0.8, 1.9)
			_asset(name, position, size, rng.randf_range(0.0, TAU))
		for j in range(6):
			var x := rng.randf_range(-half + 3.0, half - 3.0)
			var position := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			_asset("grass" if j % 2 == 0 else "flowers-tall", position, rng.randf_range(0.8, 1.5))
		for j in range(2):
			var side := -1.0 if j == 0 else 1.0
			_asset("crate" if j == 0 else "barrel", hub + Vector3(side * (half - 2.2), 0.18, -4.0 + float(j) * 7.0), 1.6, float(j))
	var sign := _asset("sign", HUBS[0] + Vector3(3.6, 0.15, -2.0), 2.8)
	var sign_back := MeshInstance3D.new()
	var sign_back_mesh := BoxMesh.new()
	sign_back_mesh.size = Vector3(4.75, 1.05, 0.16)
	sign_back.mesh = sign_back_mesh
	sign_back.material_override = materials["gold"]
	sign_back.position = sign.position + Vector3(0.0, 1.58, 0.18)
	geometry.add_child(sign_back)
	var sign_face := MeshInstance3D.new()
	var sign_face_mesh := BoxMesh.new()
	sign_face_mesh.size = Vector3(4.55, 0.86, 0.18)
	sign_face.mesh = sign_face_mesh
	sign_face.material_override = materials["wood"]
	sign_face.position = sign_back.position + Vector3(0.0, 0.0, 0.03)
	geometry.add_child(sign_face)
	var sign_text := Label3D.new()
	sign_text.text = tr("PLATFORM_START_SIGN")
	sign_text.font_size = 48
	sign_text.pixel_size = 0.0062
	sign_text.outline_size = 4
	sign_text.modulate = Color("fff3d0")
	sign_text.outline_modulate = Color("4e2c34")
	sign_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_text.position = sign_face.position + Vector3(0.0, 0.0, 0.15)
	geometry.add_child(sign_text)

func _spawn_enemies() -> void:
	for i in range(HUBS.size()):
		for j in range(3 if i == 0 else 4):
			var enemy := Area3D.new()
			enemy.set_script(ENEMY_SCRIPT)
			enemy.name = "Inimigo_%d_%d" % [i, j]
			enemies.add_child(enemy)
			var x := -5.0 + float(j % 2) * 10.0
			var z := -4.0 + float(j / 2) * 7.0
			enemy.position = HUBS[i] + Vector3(x, 0.2, z)
			enemy.setup((i + j) % 4, maycon, self, (i + j) % 4)

func _spawn_pentagrams() -> void:
	for i in range(1, HUBS.size()):
		_spawn_pentagram("hub_%d" % i, HUBS[i] + Vector3.UP * 1.45)
	for i in range(ROUTES.size()):
		var route:Vector2i = ROUTES[i]
		var steps := ceili(HUBS[route.x].distance_to(HUBS[route.y]) / 4.2)
		var middle:Vector3 = HUBS[route.x].lerp(HUBS[route.y], float(floori(steps * 0.5)) / float(steps))
		_spawn_pentagram("route_%d" % i, middle + Vector3.UP * 1.45)
	for i in range(1, HUBS.size() - 1):
		var hub:Vector3 = HUBS[i]
		var side := -1.0 if hub.x < 0.0 else 1.0
		_spawn_pentagram("high_%d" % i, hub + Vector3(side * 11.0, 5.55, -4.0))

func _spawn_pentagram(id:String, position:Vector3) -> void:
	if Global.platform_pentagram_collected.has(id):
		return
	var item := Node3D.new()
	item.name = "Pentagrama_" + id
	item.position = position
	var sprite := Sprite3D.new()
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.pixel_size = 0.0031
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	item.add_child(sprite)
	geometry.add_child(item)
	pentagram_nodes[id] = item

func _build_blue_particles() -> void:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(7.0, 2.0, 112.0)
	particle_material.direction = Vector3.DOWN
	particle_material.spread = 16.0
	particle_material.initial_velocity_min = 4.0
	particle_material.initial_velocity_max = 7.0
	particle_material.gravity = Vector3(0.0, -2.8, 0.0)
	particle_material.color = Color(0.28, 0.72, 1.0, 0.75)
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_material.albedo_color = Color(0.37, 0.76, 1.0, 0.7)
	var trail_mesh := QuadMesh.new()
	trail_mesh.size = Vector2(0.08, 0.45)
	trail_mesh.material = trail_material
	for x in [-59.0, 0.0, 59.0]:
		var particles := GPUParticles3D.new()
		particles.name = "ChuvaAzulDoCenario"
		particles.position = Vector3(x, 13.0, -82.0)
		particles.amount = 260
		particles.lifetime = 5.0
		particles.process_material = particle_material
		particles.draw_pass_1 = trail_mesh
		particles.local_coords = false
		particles.emitting = true
		add_child(particles)
	for hub_index in [0, 3, 4, 7, 8, 11, 12]:
		var hub:Vector3 = HUBS[hub_index]
		for side in [-1.0, 1.0]:
			var edge_material:ParticleProcessMaterial = particle_material.duplicate()
			edge_material.emission_box_extents = Vector3(1.5, 1.0, 8.0)
			var edge_particles := GPUParticles3D.new()
			edge_particles.name = "CascataAzulNaBorda"
			edge_particles.position = hub + Vector3(side * 12.5, 11.0, 0.0)
			edge_particles.amount = 90
			edge_particles.lifetime = 4.2
			edge_particles.process_material = edge_material
			edge_particles.draw_pass_1 = trail_mesh
			edge_particles.local_coords = false
			edge_particles.emitting = true
			add_child(edge_particles)

func has_ground_at(point:Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point - Vector3.UP * 3.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func enemy_defeated(enemy:Area3D) -> void:
	var at:Vector3 = enemy.global_position
	_spawn_blood(at, true)
	_spawn_color_burst(at + Vector3.UP * 0.8, false)
	var drop := _asset("heart", at + Vector3.UP * 1.1, 1.0)
	blood_pickups.append(drop)
	enemy.queue_free()

func enemy_stomped(enemy:Area3D) -> void:
	enemy_defeated(enemy)
	total_stomps += 1

func _spawn_blood(at:Vector3, leave_stain:bool) -> void:
	var blood := BLOOD_SCENE.instantiate()
	blood.position = at + Vector3.UP * 0.5
	effects.add_child(blood)
	get_tree().create_timer(2.5).timeout.connect(blood.queue_free)
	if not leave_stain:
		return
	for i in range(14):
		var angle := float(i) * 2.39996
		var distance := 0.25 + float(i % 4) * 0.42
		var stain := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.2 + float(i % 3) * 0.12
		mesh.height = 0.025
		stain.mesh = mesh
		stain.material_override = materials["blood"]
		stain.position = Vector3(at.x + cos(angle) * distance, at.y + 0.02 + float(i) * 0.0005, at.z + sin(angle) * distance)
		effects.add_child(stain)

func _spawn_color_burst(at:Vector3, pickup:bool) -> void:
	var colors := [Color("ffda60"), Color("ff6fb1"), Color("71d3ff"), Color("a985ff"), Color("8ee899"), Color("ff9369")]
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.075
	spark_mesh.height = 0.15
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	var spark_materials:Array[StandardMaterial3D] = []
	for color in colors:
		var material := _material(color, 0.24)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_materials.append(material)
	for i in range(24 if pickup else 30):
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		spark.material_override = spark_materials[i % spark_materials.size()]
		spark.position = at
		spark.scale = Vector3.ONE * randf_range(0.7, 1.5)
		effects.add_child(spark)
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.1), randf_range(-1.0, 1.0)).normalized()
		var distance := randf_range(1.0, 2.1) if pickup else randf_range(0.8, 2.4)
		var tween := create_tween().bind_node(spark).set_parallel(true)
		tween.tween_property(spark, "position", at + direction * distance, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(spark.queue_free)
	if pickup:
		var flash := Sprite3D.new()
		flash.texture = PENTAGRAM_TEXTURE
		flash.pixel_size = 0.0031
		flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flash.shaded = false
		flash.double_sided = true
		flash.position = at
		effects.add_child(flash)
		var flash_tween := create_tween().bind_node(flash).set_parallel(true)
		flash_tween.tween_property(flash, "scale", Vector3.ONE * 2.1, 0.48)
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.48)
		flash_tween.chain().tween_callback(flash.queue_free)

func player_hit(at:Vector3) -> void:
	var ground_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at - Vector3.UP * 3.0, 1)
	var ground := get_world_3d().direct_space_state.intersect_ray(ground_query)
	_spawn_blood(ground.position if not ground.is_empty() else at, not ground.is_empty())
	blood_overlay.call("flash")

func respawn(reset_health:bool) -> void:
	maycon.global_position = Vector3(0.0, 1.4, 32.0)
	maycon.velocity = Vector3.ZERO
	maycon.hurt_time = 1.0
	maycon.camera.global_position = Vector3(0.0, 7.0, 43.0)
	if reset_health:
		Global.realtime_hp = Global.realtime_hp_max
	else:
		Global.realtime_hp = maxf(15.0, Global.realtime_hp - 8.0)
	update_hud()

func _exit_stage() -> void:
	exit_started = true
	maycon.control_enabled = false
	Global.platform_arrival_pending = true
	Global.save_progress("fase_4")
	get_tree().change_scene_to_file.call_deferred("res://scenes/fase_1_before_castle_4.tscn")

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var count_panel := HBoxContainer.new()
	count_panel.anchor_left = 1.0
	count_panel.anchor_right = 1.0
	count_panel.offset_left = -135.0
	count_panel.offset_right = -12.0
	count_panel.offset_top = 9.0
	count_panel.offset_bottom = 53.0
	canvas.add_child(count_panel)
	count_panel.add_child(_hud_icon(PENTAGRAM_TEXTURE, Vector2(42.0, 42.0)))
	pentagram_label = Label.new()
	pentagram_label.add_theme_font_size_override("font_size", 28)
	pentagram_label.add_theme_color_override("font_color", Color("d72343"))
	count_panel.add_child(pentagram_label)
	var background := PanelContainer.new()
	background.anchor_top = 1.0
	background.anchor_bottom = 1.0
	background.offset_left = 12.0
	background.offset_right = 224.0
	background.offset_top = -66.0
	background.offset_bottom = -12.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.10, 0.14, 0.8)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(6)
	background.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(background)
	var column := VBoxContainer.new()
	background.add_child(column)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 12)
	column.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(200.0, 12.0)
	hp_bar.show_percentage = false
	hp_bar.max_value = Global.realtime_hp_max
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("b1223e")
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color("3a1924")
	hp_bar.add_theme_stylebox_override("background", bar_back)
	column.add_child(hp_bar)
	var action_background := PanelContainer.new()
	action_background.anchor_top = 1.0
	action_background.anchor_bottom = 1.0
	action_background.offset_left = 238.0
	action_background.offset_right = 544.0
	action_background.offset_top = -66.0
	action_background.offset_bottom = -12.0
	action_background.add_theme_stylebox_override("panel", panel_style.duplicate())
	canvas.add_child(action_background)
	var control_panel := HBoxContainer.new()
	control_panel.add_theme_constant_override("separation", 6)
	action_background.add_child(control_panel)
	control_panel.add_child(_hud_icon(load("res://assets/novas_imagens/buttons/360_A.png"), Vector2(30.0, 30.0)))
	var jump_label := Label.new()
	jump_label.text = tr("PLATFORM_JUMP_HINT")
	jump_label.add_theme_font_size_override("font_size", 13)
	control_panel.add_child(jump_label)
	control_panel.add_child(_hud_icon(load("res://assets/novas_imagens/buttons/360_X.png"), Vector2(30.0, 30.0)))
	var run_label := Label.new()
	run_label.text = tr("PLATFORM_RUN_HINT")
	run_label.add_theme_font_size_override("font_size", 13)
	control_panel.add_child(run_label)
	blood_overlay = Control.new()
	blood_overlay.set_script(BLOOD_OVERLAY_SCRIPT)
	canvas.add_child(blood_overlay)

func _build_pause() -> void:
	var pause := CanvasLayer.new()
	pause.name = "PauseFofo"
	pause.set_script(PAUSE_SCRIPT)
	add_child(pause)

func _hud_icon(texture:Texture2D, size:Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func update_hud() -> void:
	if not is_instance_valid(hp_bar):
		return
	hp_bar.value = Global.realtime_hp
	hp_label.text = tr("UI_HEALTH")
	pentagram_label.text = str(Global.platform_pentagrams)
