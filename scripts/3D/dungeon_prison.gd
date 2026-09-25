extends Node3D

const PLAYER_SCENE:PackedScene = preload("res://scenes/3D/dungeon_player.tscn")
const ZOMBIE_MODEL:String = "res://assets/kenney/graveyard_kit/character-zombie.glb"
const KEEPER_MODEL:String = "res://assets/kenney/graveyard_kit/character-keeper.glb"
const SKELETON_MODEL:String = "res://assets/kenney/graveyard_kit/character-skeleton.glb"

var player:DungeonPlayer
var world_root:Node3D
var enemies:Array[DungeonInfected] = []
var hiding_zones:Array[AABB] = []
var flicker_lights:Array[Dictionary] = []
var release_doors:Array[Node3D] = []
var flashlight_pickup:Node3D
var gun_pickup:Node3D
var key_pickup:Node3D
var axe_pickup:Node3D
var axe_door:Node3D
var trampoline:Node3D
var hud:CanvasLayer
var objective_label:Label
var help_label:Label
var prompt_label:Label
var flashlight_label:Label
var weapon_label:Label
var fade_overlay:ColorRect
var blood_overlay:Control
var ambience:AudioStreamPlayer
var gun_sound:AudioStreamPlayer
var pickup_sound:AudioStreamPlayer
var gate_sound:AudioStreamPlayer3D
var current_interaction:String = ""
var key_collected:bool = false
var axe_door_open:bool = false
var sequence_running:bool = false
var elapsed:float = 0.0
var stone_material:StandardMaterial3D
var floor_material:StandardMaterial3D
var iron_material:StandardMaterial3D
var wet_material:StandardMaterial3D
var rotten_material:StandardMaterial3D
var blood_material:StandardMaterial3D
var emissive_material:StandardMaterial3D
var flesh_material:StandardMaterial3D

func _ready() -> void:
	get_tree().paused = false
	GameSongs.stop(1)
	build_materials()
	build_environment()
	build_prison()
	build_player()
	build_pickups()
	build_infected_population()
	build_hud()
	build_audio()
	apply_saved_state()
	start_arrival()

func build_materials() -> void:
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_diff_1k.jpg")
	stone_material.normal_enabled = true
	stone_material.normal_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_normal_1k.jpg")
	stone_material.roughness = 0.96
	stone_material.uv1_scale = Vector3(2.5, 2.5, 2.5)
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_texture = load("res://assets/polyhaven/realtime_battle/cobblestone_floor_diff_1k.jpg")
	floor_material.normal_enabled = true
	floor_material.normal_texture = load("res://assets/polyhaven/realtime_battle/cobblestone_floor_normal_1k.jpg")
	floor_material.roughness = 0.9
	floor_material.uv1_scale = Vector3(4.0, 4.0, 4.0)
	iron_material = StandardMaterial3D.new()
	iron_material.albedo_color = Color(0.075, 0.085, 0.08)
	iron_material.metallic = 0.92
	iron_material.roughness = 0.44
	wet_material = StandardMaterial3D.new()
	wet_material.albedo_color = Color(0.035, 0.06, 0.055)
	wet_material.metallic = 0.18
	wet_material.roughness = 0.2
	rotten_material = StandardMaterial3D.new()
	rotten_material.albedo_color = Color(0.19, 0.16, 0.055)
	rotten_material.roughness = 1.0
	blood_material = StandardMaterial3D.new()
	blood_material.albedo_color = Color(0.24, 0.005, 0.008)
	blood_material.roughness = 0.45
	emissive_material = StandardMaterial3D.new()
	emissive_material.albedo_color = Color(0.8, 0.16, 0.025)
	emissive_material.emission_enabled = true
	emissive_material.emission = Color(1.0, 0.08, 0.01)
	emissive_material.emission_energy_multiplier = 4.5
	flesh_material = StandardMaterial3D.new()
	flesh_material.albedo_color = Color(0.31, 0.24, 0.17)
	flesh_material.roughness = 0.92

func build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.002, 0.004, 0.006)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.045, 0.055, 0.065)
	environment.ambient_light_energy = 0.16
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.25
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.035, 0.045, 0.05)
	environment.fog_density = 0.035
	environment.fog_height = 1.2
	environment.fog_height_density = 0.38
	environment_node.environment = environment
	add_child(environment_node)
	world_root = Node3D.new()
	world_root.name = "PrisonArchitecture"
	add_child(world_root)

func build_prison() -> void:
	create_box("MainFloor", Vector3(0, -0.25, -35), Vector3(22, 0.5, 84), floor_material, true, world_root)
	create_box("MainCeiling", Vector3(0, 4.6, -35), Vector3(22, 0.45, 84), stone_material, true, world_root)
	create_box("LeftBackWall", Vector3(-10.8, 2.15, -35), Vector3(0.6, 4.8, 84), stone_material, true, world_root)
	create_box("RightBackWall", Vector3(10.8, 2.15, -35), Vector3(0.6, 4.8, 84), stone_material, true, world_root)
	create_box("EndWall", Vector3(0, 2.15, -76.6), Vector3(22, 4.8, 0.6), stone_material, true, world_root)
	create_box("EntranceWall", Vector3(0, 2.15, 6.6), Vector3(22, 4.8, 0.6), stone_material, true, world_root)
	for z in [-5.0, -13.0, -21.0, -29.0, -37.0, -45.0, -53.0, -61.0]:
		build_cell(-1, z, z in [-21.0, -45.0])
		build_cell(1, z, z in [-13.0, -37.0, -53.0])
	build_side_branch(1, -31.0)
	build_side_branch(-1, -55.0)
	for z in [-8.0, -24.0, -40.0, -58.0, -70.0]:
		build_flickering_fixture(Vector3(0, 4.15, z), int(absf(z)))
	build_puddles_and_food()
	build_mosquitoes(Vector3(-6.7, 0.45, -18.0))
	build_mosquitoes(Vector3(7.2, 0.4, -43.0))
	build_mosquitoes(Vector3(-15.5, 0.5, -55.0))

func build_cell(side:int, z:float, empty_cell:bool) -> void:
	var side_x:float = float(side) * 8.0
	var front_x:float = float(side) * 5.25
	create_box("CellDivider", Vector3(side_x, 2.0, z - 3.55), Vector3(5.5, 4.4, 0.35), stone_material, true, world_root)
	create_box("CellDivider", Vector3(side_x, 2.0, z + 3.55), Vector3(5.5, 4.4, 0.35), stone_material, true, world_root)
	# A primeira cela à esquerda recebe uma porta exclusiva para o machado.
	if side == -1 && is_equal_approx(z, -5.0):
		return
	var door := Node3D.new()
	door.name = "CellDoor_%s_%s" % [side, int(absf(z))]
	door.position = Vector3(front_x, 0.0, z)
	world_root.add_child(door)
	for index in 7:
		var offset_z:float = -2.6 + float(index) * 0.86
		create_bar(Vector3(0, 2.0, offset_z), 4.2, 0.085, door)
	for height in [0.45, 2.0, 3.55]:
		create_box("Crossbar", Vector3(0, height, 0), Vector3(0.16, 0.12, 5.65), iron_material, true, door)
	if empty_cell:
		hiding_zones.append(AABB(Vector3(minf(front_x, side_x) - 0.4, -0.2, z - 3.0), Vector3(absf(side_x - front_x) + 0.8, 2.8, 6.0)))
		var coffin:Node3D = instantiate_model("res://assets/kenney/graveyard_kit/coffin-old.glb", Vector3(side_x, 0.0, z), Vector3.ONE * 1.4, world_root)
		if coffin:
			coffin.rotation.y = PI * 0.5
	else:
		release_doors.append(door)

func build_side_branch(side:int, z:float) -> void:
	var center_x:float = float(side) * 19.0
	create_box("BranchFloor", Vector3(center_x, -0.24, z), Vector3(18, 0.48, 7.0), floor_material, true, world_root)
	create_box("BranchCeiling", Vector3(center_x, 4.6, z), Vector3(18, 0.45, 7.0), stone_material, true, world_root)
	create_box("BranchWallA", Vector3(center_x, 2.1, z - 3.5), Vector3(18, 4.7, 0.5), stone_material, true, world_root)
	create_box("BranchWallB", Vector3(center_x, 2.1, z + 3.5), Vector3(18, 4.7, 0.5), stone_material, true, world_root)
	create_box("BranchEnd", Vector3(float(side) * 28.0, 2.1, z), Vector3(0.5, 4.7, 7.0), stone_material, true, world_root)
	hiding_zones.append(AABB(Vector3(minf(center_x - 5.0, center_x + 5.0), -0.2, z - 3.1), Vector3(10.0, 2.8, 6.2)))
	for x_step in [14.0, 21.0, 26.0]:
		build_flickering_fixture(Vector3(float(side) * x_step, 4.05, z), int(x_step + absf(z)))
	for barrier_index in 3:
		var barrier_x := float(side) * (14.0 + float(barrier_index) * 4.8)
		create_box("CoverCrate", Vector3(barrier_x, 0.8, z + (-1.6 if barrier_index % 2 == 0 else 1.6)), Vector3(2.1, 1.6, 2.0), stone_material, true, world_root)

func create_bar(local_position:Vector3, height:float, radius:float, parent:Node3D) -> void:
	var body := StaticBody3D.new()
	body.position = local_position
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = iron_material
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)

func create_box(node_name:String, position_value:Vector3, size:Vector3, material:Material, collision_enabled:bool, parent:Node3D) -> Node3D:
	var root:Node3D
	if collision_enabled:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = position_value
	parent.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func instantiate_model(path:String, position_value:Vector3, scale_value:Vector3, parent:Node3D) -> Node3D:
	var packed:PackedScene = load(path)
	if !packed:
		return null
	var model := packed.instantiate() as Node3D
	model.position = position_value
	model.scale = scale_value
	parent.add_child(model)
	return model

func build_flickering_fixture(position_value:Vector3, seed_value:int) -> void:
	var fixture := create_box("BrokenFixture", position_value, Vector3(1.2, 0.1, 0.28), iron_material, false, world_root)
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.25, 0)
	light.light_color = Color(0.52, 0.7, 0.72) if seed_value % 2 == 0 else Color(0.65, 0.16, 0.08)
	light.light_energy = 2.4
	light.omni_range = 8.5
	light.shadow_enabled = seed_value % 3 == 0
	fixture.add_child(light)
	flicker_lights.append({"light": light, "base": light.light_energy, "phase": float(seed_value) * 0.31})

func build_puddles_and_food() -> void:
	for puddle_position in [Vector3(-1.5, 0.015, -12), Vector3(2.2, 0.015, -35), Vector3(-2.4, 0.015, -63)]:
		var puddle := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.4
		mesh.bottom_radius = 1.7
		mesh.height = 0.025
		mesh.material = wet_material
		puddle.mesh = mesh
		puddle.position = puddle_position
		world_root.add_child(puddle)
	for food_position in [Vector3(-6.8, 0.12, -18), Vector3(7.0, 0.12, -43), Vector3(-7.3, 0.12, -59)]:
		instantiate_model("res://assets/kenney/graveyard_kit/detail-plate.glb", food_position, Vector3.ONE * 1.5, world_root)
		for piece in 4:
			var lump := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.11 + randf() * 0.09
			sphere.height = sphere.radius * 2.0
			sphere.material = rotten_material
			lump.mesh = sphere
			lump.position = food_position + Vector3(randf_range(-0.25, 0.25), 0.12, randf_range(-0.25, 0.25))
			world_root.add_child(lump)

func build_mosquitoes(position_value:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = position_value
	particles.amount = 28
	particles.lifetime = 3.2
	particles.preprocess = 3.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.1
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.6
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.25
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.025, 0.025)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.01, 0.01, 0.01)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	particles.mesh = mesh
	world_root.add_child(particles)

func build_player() -> void:
	player = PLAYER_SCENE.instantiate() as DungeonPlayer
	player.position = Vector3(0, 8.0, 3.2)
	add_child(player)
	player.interact_pressed.connect(on_interact_pressed)
	player.fired.connect(on_player_fired)
	player.flashlight_toggled.connect(func(_enabled:bool): update_hud())

func build_pickups() -> void:
	flashlight_pickup = Node3D.new()
	flashlight_pickup.name = "FlashlightPickup"
	flashlight_pickup.position = Vector3(0.2, 0.45, -2.5)
	world_root.add_child(flashlight_pickup)
	instantiate_model("res://assets/kenney/graveyard_kit/lantern-glass.glb", Vector3.ZERO, Vector3.ONE * 1.7, flashlight_pickup)
	var lamp_light := OmniLight3D.new()
	lamp_light.light_color = Color(0.72, 0.86, 1.0)
	lamp_light.light_energy = 3.0
	lamp_light.omni_range = 4.0
	flashlight_pickup.add_child(lamp_light)
	gun_pickup = build_gun(Vector3(1.2, 0.62, -73.0))
	key_pickup = build_key(Vector3(-1.25, 0.55, -72.5))
	axe_door = build_axe_cell()
	axe_pickup = build_axe(Vector3(-8.1, 0.72, -7.0))
	trampoline = Node3D.new()
	trampoline.name = "ReturnTrampoline"
	trampoline.position = Vector3(0, 0.0, 3.5)
	world_root.add_child(trampoline)
	instantiate_model("res://assets/kenney/platformer_3d/spring.glb", Vector3.ZERO, Vector3.ONE * 1.8, trampoline)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(0.15, 0.45, 1.0)
	beacon.light_energy = 2.8
	beacon.omni_range = 5.0
	trampoline.add_child(beacon)

func build_gun(position_value:Vector3) -> Node3D:
	var gun := Node3D.new()
	gun.name = "MachineGunPickup"
	gun.position = position_value
	world_root.add_child(gun)
	create_box("GunBody", Vector3.ZERO, Vector3(0.32, 0.28, 1.25), iron_material, false, gun)
	create_box("GunBarrel", Vector3(0, 0.03, -0.95), Vector3(0.12, 0.12, 0.85), iron_material, false, gun)
	create_box("GunStock", Vector3(0, -0.06, 0.78), Vector3(0.28, 0.42, 0.62), rotten_material, false, gun)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.08)
	light.light_energy = 3.2
	light.omni_range = 4.5
	gun.add_child(light)
	return gun

func build_key(position_value:Vector3) -> Node3D:
	var key := Node3D.new()
	key.name = "DungeonKeyPickup"
	key.position = position_value
	world_root.add_child(key)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.2
	torus.material = emissive_material
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	key.add_child(ring)
	create_box("KeyStem", Vector3(0, 0, -0.28), Vector3(0.08, 0.08, 0.55), emissive_material, false, key)
	return key

func build_axe_cell() -> Node3D:
	var door := Node3D.new()
	door.name = "AxeCellDoor"
	door.position = Vector3(-5.22, 0.0, -7.0)
	world_root.add_child(door)
	for index in 7:
		create_bar(Vector3(0, 2.0, -2.5 + float(index) * 0.83), 4.2, 0.11, door)
	for height in [0.45, 2.0, 3.55]:
		create_box("AxeDoorCrossbar", Vector3(0, height, 0), Vector3(0.18, 0.14, 5.4), iron_material, true, door)
	var red_light := OmniLight3D.new()
	red_light.position = Vector3(-2.4, 2.3, 0)
	red_light.light_color = Color(0.9, 0.02, 0.01)
	red_light.light_energy = 4.5
	red_light.omni_range = 6.0
	door.add_child(red_light)
	return door

func build_axe(position_value:Vector3) -> Node3D:
	var axe := Node3D.new()
	axe.name = "AxePickup"
	axe.position = position_value
	world_root.add_child(axe)
	create_box("AxeHandle", Vector3(0, 0.35, 0), Vector3(0.12, 1.3, 0.12), rotten_material, false, axe)
	var blade := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.62, 0.55, 0.12)
	prism.material = iron_material
	blade.mesh = prism
	blade.position = Vector3(0.25, 0.9, 0)
	blade.rotation.z = -PI * 0.5
	axe.add_child(blade)
	return axe

func build_infected_population() -> void:
	spawn_infected(Vector3(-7.8, 0.0, -13.0), ZOMBIE_MODEL, false, -20.0)
	spawn_infected(Vector3(7.8, 0.0, -21.0), KEEPER_MODEL, false, -28.0)
	spawn_infected(Vector3(-7.8, 0.0, -29.0), SKELETON_MODEL, false, -37.0)
	spawn_infected(Vector3(7.8, 0.0, -45.0), ZOMBIE_MODEL, false, -51.0)
	spawn_infected(Vector3(-7.8, 0.0, -53.0), KEEPER_MODEL, false, -60.0)
	spawn_infected(Vector3(19.0, 0.0, -31.0), ZOMBIE_MODEL, true, 0.0)
	spawn_infected(Vector3(-20.0, 0.0, -55.0), SKELETON_MODEL, true, 0.0)
	spawn_infected(Vector3(5.5, 0.0, -68.0), ZOMBIE_MODEL, true, 0.0)

func spawn_infected(position_value:Vector3, model_path:String, released:bool, trigger:float) -> void:
	var infected := DungeonInfected.new()
	infected.position = position_value
	add_child(infected)
	infected.setup(player, self, model_path, released, trigger)
	infected.caught_player.connect(on_player_caught)
	infected.died.connect(on_infected_died)
	enemies.append(infected)
	if !released:
		var closest_door:Node3D
		var closest_distance:float = INF
		for candidate in release_doors:
			var candidate_distance:float = candidate.global_position.distance_to(infected.global_position)
			if candidate_distance < closest_distance:
				closest_distance = candidate_distance
				closest_door = candidate
		if is_instance_valid(closest_door):
			infected.set_meta("cell_door", closest_door)
			release_doors.erase(closest_door)

func build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "DungeonHUD"
	add_child(hud)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.015, 0.02, 0.025, 0.12)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vignette)
	objective_label = make_label(20, Color(0.78, 0.86, 0.83), HORIZONTAL_ALIGNMENT_LEFT)
	objective_label.position = Vector2(28, 24)
	objective_label.size = Vector2(780, 40)
	hud.add_child(objective_label)
	help_label = make_label(17, Color(0.65, 0.72, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	help_label.position = Vector2(28, 58)
	help_label.size = Vector2(900, 35)
	help_label.text = tr("DUNGEON_MOVE_HINT")
	hud.add_child(help_label)
	flashlight_label = make_label(18, Color(0.7, 0.84, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	flashlight_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	flashlight_label.position = Vector2(-510, 28)
	flashlight_label.size = Vector2(480, 35)
	hud.add_child(flashlight_label)
	weapon_label = make_label(18, Color(1.0, 0.62, 0.26), HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	weapon_label.position = Vector2(-510, 64)
	weapon_label.size = Vector2(480, 35)
	hud.add_child(weapon_label)
	prompt_label = make_label(24, Color(0.95, 0.86, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-420, -115)
	prompt_label.size = Vector2(840, 44)
	prompt_label.visible = false
	hud.add_child(prompt_label)
	var crosshair := make_label(24, Color(0.9, 0.92, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-20, -22)
	crosshair.size = Vector2(40, 40)
	crosshair.text = "+"
	hud.add_child(crosshair)
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.z_index = 100
	hud.add_child(fade_overlay)
	blood_overlay = Control.new()
	blood_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_overlay.z_index = 90
	blood_overlay.visible = false
	hud.add_child(blood_overlay)
	for index in 34:
		var splash := ColorRect.new()
		var splash_size := Vector2(randf_range(25, 150), randf_range(18, 110))
		splash.size = splash_size
		splash.position = Vector2(randf_range(-40, 1880), randf_range(-30, 1040))
		splash.rotation = randf_range(-PI, PI)
		splash.color = Color(0.42 + randf() * 0.25, 0.0, 0.01, randf_range(0.45, 0.88))
		blood_overlay.add_child(splash)
	update_hud()

func make_label(font_size:int, color:Color, alignment:HorizontalAlignment) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = alignment
	return label

func build_audio() -> void:
	ambience = AudioStreamPlayer.new()
	var ambience_stream:AudioStream = load("res://assets/novos_audios/calabouco_terror/dungeon_ambience_pixabay.mp3")
	if ambience_stream:
		ambience_stream = ambience_stream.duplicate()
		ambience_stream.set("loop", true)
	ambience.stream = ambience_stream
	ambience.volume_db = -12.0
	add_child(ambience)
	ambience.play()
	gun_sound = make_audio("res://assets/novos_audios/gun_shot.mp3", -5.0)
	pickup_sound = make_audio("res://assets/novos_audios/gun_load.mp3", -7.0)
	gate_sound = AudioStreamPlayer3D.new()
	gate_sound.stream = load("res://assets/novos_audios/metal_batendo.mp3")
	gate_sound.max_distance = 24.0
	gate_sound.volume_db = -5.0
	add_child(gate_sound)

func make_audio(path:String, volume:float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func apply_saved_state() -> void:
	player.set_flashlight_available(bool(Global.game_events.get("dungeon_flashlight_taken", false)))
	player.set_gun_available(bool(Global.game_events.get("dungeon_gun_taken", false)))
	key_collected = bool(Global.game_events.get("dungeon_key_taken", false))
	axe_door_open = bool(Global.game_events.get("dungeon_axe_door_open", false)) || Global.maycon_itens.get("axe", false)
	if player.has_flashlight && is_instance_valid(flashlight_pickup):
		flashlight_pickup.queue_free()
	if player.has_gun && is_instance_valid(gun_pickup):
		gun_pickup.queue_free()
	if key_collected && is_instance_valid(key_pickup):
		key_pickup.queue_free()
	if axe_door_open:
		open_axe_door(false)
	if Global.maycon_itens.get("axe", false) && is_instance_valid(axe_pickup):
		axe_pickup.queue_free()
	update_hud()

func start_arrival() -> void:
	sequence_running = true
	player.controls_enabled = false
	var fall_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(player, "position:y", 0.08, 1.05)
	fall_tween.parallel().tween_property(fade_overlay, "color:a", 0.0, 1.7)
	await fall_tween.finished
	player.controls_enabled = true
	sequence_running = false
	fade_overlay.visible = false

func _process(delta:float) -> void:
	elapsed += delta
	for data in flicker_lights:
		var light:OmniLight3D = data.light
		var pulse:float = sin(elapsed * 7.3 + data.phase) * sin(elapsed * 13.7 + data.phase * 2.0)
		var dropout:float = 0.08 if pulse > 0.82 else 1.0
		light.light_energy = float(data.base) * (0.65 + absf(pulse) * 0.45) * dropout
	for enemy in enemies:
		if is_instance_valid(enemy) && !enemy.released && player.position.z < enemy.release_distance:
			release_enemy(enemy)
	if is_instance_valid(flashlight_pickup):
		flashlight_pickup.rotation.y += delta * 0.8
	if is_instance_valid(gun_pickup):
		gun_pickup.rotation.y += delta * 0.45
	if is_instance_valid(key_pickup):
		key_pickup.rotation.y += delta * 1.1
	if is_instance_valid(axe_pickup):
		axe_pickup.rotation.y = sin(elapsed * 1.3) * 0.1
	update_interaction()
	if player.position.y < -4.0 && !sequence_running:
		restart_after_caught(null)

func release_enemy(enemy:DungeonInfected) -> void:
	enemy.release_from_cell()
	var door:Node3D = enemy.get_meta("cell_door", null)
	if is_instance_valid(door):
		gate_sound.global_position = door.global_position
		gate_sound.play()
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(door, "rotation:y", PI * 0.48, 1.1)

func update_interaction() -> void:
	if sequence_running:
		prompt_label.visible = false
		return
	current_interaction = ""
	var prompt_key:String = ""
	if is_instance_valid(flashlight_pickup) && player.global_position.distance_to(flashlight_pickup.global_position) < 2.0:
		current_interaction = "flashlight"
		prompt_key = "DUNGEON_PROMPT_FLASHLIGHT"
	elif is_instance_valid(gun_pickup) && player.global_position.distance_to(gun_pickup.global_position) < 2.2:
		current_interaction = "gun"
		prompt_key = "DUNGEON_PROMPT_GUN"
	elif is_instance_valid(key_pickup) && player.global_position.distance_to(key_pickup.global_position) < 2.0:
		current_interaction = "key"
		prompt_key = "DUNGEON_PROMPT_KEY"
	elif !axe_door_open && player.global_position.distance_to(axe_door.global_position) < 2.5:
		current_interaction = "axe_door"
		prompt_key = "DUNGEON_PROMPT_OPEN_CELL" if key_collected else "DUNGEON_CELL_LOCKED"
	elif is_instance_valid(axe_pickup) && axe_door_open && player.global_position.distance_to(axe_pickup.global_position) < 2.2:
		current_interaction = "axe"
		prompt_key = "DUNGEON_PROMPT_AXE"
	elif is_instance_valid(trampoline) && player.global_position.distance_to(trampoline.global_position) < 2.4:
		current_interaction = "trampoline"
		prompt_key = "DUNGEON_PROMPT_TRAMPOLINE" if Global.maycon_itens.get("axe", false) else "DUNGEON_TRAMPOLINE_LOCKED"
	prompt_label.visible = prompt_key != ""
	if prompt_key != "":
		prompt_label.text = tr(prompt_key)

func on_interact_pressed() -> void:
	if sequence_running:
		return
	match current_interaction:
		"flashlight":
			Global.game_events["dungeon_flashlight_taken"] = true
			player.set_flashlight_available(true)
			player.flashlight_on = true
			player.flashlight.visible = true
			pickup_sound.play()
			flashlight_pickup.queue_free()
			update_hud()
		"gun":
			Global.game_events["dungeon_gun_taken"] = true
			player.set_gun_available(true)
			pickup_sound.play()
			gun_pickup.queue_free()
			update_hud()
		"key":
			key_collected = true
			Global.game_events["dungeon_key_taken"] = true
			pickup_sound.play()
			key_pickup.queue_free()
			update_hud()
		"axe_door":
			if key_collected:
				open_axe_door(true)
			else:
				gate_sound.global_position = axe_door.global_position
				gate_sound.play()
		"axe":
			Global.maycon_itens["axe"] = true
			Global.game_events["axe_taken"] = true
			Global.game_events["dungeon_axe_taken"] = true
			pickup_sound.play()
			axe_pickup.queue_free()
			Global.save_progress("fase_1_castle_2")
			update_hud()
		"trampoline":
			if Global.maycon_itens.get("axe", false):
				return_to_castle()

func open_axe_door(with_sound:bool) -> void:
	axe_door_open = true
	Global.game_events["dungeon_axe_door_open"] = true
	if with_sound:
		gate_sound.global_position = axe_door.global_position
		gate_sound.play()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(axe_door, "rotation:y", PI * 0.5, 1.15)
	update_hud()

func update_hud() -> void:
	if !is_instance_valid(objective_label):
		return
	if !player.has_flashlight:
		objective_label.text = tr("DUNGEON_OBJECTIVE_FLASHLIGHT")
	elif !player.has_gun || !key_collected:
		objective_label.text = tr("DUNGEON_OBJECTIVE_EXPLORE")
	elif !Global.maycon_itens.get("axe", false):
		objective_label.text = tr("DUNGEON_OBJECTIVE_AXE")
	else:
		objective_label.text = tr("DUNGEON_OBJECTIVE_ESCAPE")
	flashlight_label.text = tr("DUNGEON_FLASHLIGHT_ON") if player.flashlight_on else tr("DUNGEON_FLASHLIGHT_OFF")
	if !player.has_flashlight:
		flashlight_label.text = ""
	weapon_label.text = tr("DUNGEON_WEAPON_READY") if player.has_gun else ""

func on_player_fired(origin:Vector3, direction:Vector3) -> void:
	if sequence_running:
		return
	gun_sound.play()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 65.0)
	query.exclude = [player.get_rid()]
	query.collision_mask = 0xFFFFFFFF
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if !hit.is_empty():
		var collider:Object = hit.get("collider")
		if collider is DungeonInfected:
			(collider as DungeonInfected).take_damage(1)
			spawn_blood_hit(hit.position, direction)

func spawn_blood_hit(hit_position:Vector3, direction:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = hit_position
	particles.amount = 30
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = direction
	particles.spread = 48.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 6.5
	particles.gravity = Vector3(0, -9.8, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.material = blood_material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)

func on_player_caught(infected:DungeonInfected) -> void:
	if sequence_running:
		return
	restart_after_caught(infected)

func restart_after_caught(infected:DungeonInfected) -> void:
	sequence_running = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	if is_instance_valid(infected):
		infected.set_physics_process(false)
		infected.global_position = player.global_position + player.camera_forward() * 1.15
		infected.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
	create_grabbing_hands()
	blood_overlay.visible = true
	for child in blood_overlay.get_children():
		child.modulate.a = 0.0
		create_tween().tween_property(child, "modulate:a", 1.0, randf_range(0.08, 0.35)).set_delay(randf_range(0.0, 0.42))
	var camera_tween := create_tween().set_trans(Tween.TRANS_ELASTIC)
	camera_tween.tween_property(player.head, "rotation:z", 0.18, 0.25)
	camera_tween.tween_property(player.head, "rotation:z", -0.22, 0.2)
	camera_tween.tween_property(player.head, "rotation:z", 0.08, 0.18)
	await get_tree().create_timer(1.05).timeout
	fade_overlay.visible = true
	fade_overlay.color = Color(0.12, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1.0, 0.8).finished
	get_tree().reload_current_scene()

func create_grabbing_hands() -> void:
	for side in [-1.0, 1.0]:
		var hand := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.13
		mesh.height = 0.75
		mesh.material = flesh_material
		hand.mesh = mesh
		hand.position = Vector3(side * 1.1, -0.8, -1.2)
		hand.rotation.z = side * 0.8
		player.camera.add_child(hand)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(hand, "position", Vector3(side * 0.34, -0.15, -0.48), 0.34).set_delay(0.08 if side > 0 else 0.0)

func on_infected_died(infected:DungeonInfected) -> void:
	enemies.erase(infected)

func is_player_hidden() -> bool:
	if player.flashlight_on:
		return false
	for zone in hiding_zones:
		if zone.has_point(player.global_position):
			return true
	return false

func return_to_castle() -> void:
	sequence_running = true
	player.controls_enabled = false
	player.look_at(trampoline.global_position + Vector3.UP * 0.6, Vector3.UP)
	var look_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_tween.tween_property(player.head, "rotation:x", -0.45, 0.45)
	await look_tween.finished
	var jump_tween := create_tween().set_trans(Tween.TRANS_QUAD)
	jump_tween.tween_property(player, "position:y", 7.5, 0.75).set_ease(Tween.EASE_OUT)
	jump_tween.parallel().tween_property(player, "position:z", trampoline.position.z, 0.75)
	await get_tree().create_timer(0.35).timeout
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1.0, 0.8).finished
	Global.dungeon_return_pending = true
	Global.back_to_fase = false
	Global.save_progress("fase_1_castle_2")
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")
