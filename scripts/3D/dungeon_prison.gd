extends Node3D

const PLAYER_SCENE:PackedScene = preload("res://scenes/3D/dungeon_player.tscn")
const ZOMBIE_MODEL := "res://assets/horror_creatures/infected_zombie_animated.glb"
const RUNNER_MODEL := "res://assets/horror_creatures/horror_mutant.glb"
const HOUND_MODEL := "res://assets/horror_creatures/plague_hound_clean.glb"

var player:DungeonPlayer
var world_root:Node3D
var enemies:Array[DungeonInfected] = []
var enemy_spawns:Array[Dictionary] = []
var hiding_zones:Array[AABB] = []
var flicker_lights:Array[Dictionary] = []
var stage_doors := {"intro": [], "blue": [], "red": [], "green": []}
var stage_enemies := {"intro": [], "blue": [], "red": [], "green": []}
var route_gates:Dictionary = {}
var key_room_doors:Dictionary = {}
var levers:Dictionary = {}
var pickups:Dictionary = {}
var inventory_slots:Dictionary = {}
var axe_pickup:Node3D
var axe_door:Node3D
var trampoline:Node3D
var objective_label:Label
var help_label:Label
var prompt_label:Label
var flashlight_label:Label
var weapon_label:Label
var fade_overlay:ColorRect
var blood_overlay:Control
var inventory_bar:HBoxContainer
var gun_sound:AudioStreamPlayer
var pickup_sound:AudioStreamPlayer
var gate_sound:AudioStreamPlayer3D
var current_interaction := ""
var sequence_running := false
var elapsed := 0.0
var stone_material:StandardMaterial3D
var floor_material:StandardMaterial3D
var iron_material:StandardMaterial3D
var wet_material:StandardMaterial3D
var rotten_material:StandardMaterial3D
var blood_material:StandardMaterial3D
var flesh_material:StandardMaterial3D
var auto_release_assigned:bool = false

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
	Global.save_progress("calabouco_terror")
	start_arrival()

func build_materials() -> void:
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_diff_1k.jpg")
	stone_material.normal_enabled = true
	stone_material.normal_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_normal_1k.jpg")
	stone_material.roughness = 0.96
	floor_material = StandardMaterial3D.new()
	floor_material.albedo_texture = load("res://assets/polyhaven/realtime_battle/cobblestone_floor_diff_1k.jpg")
	floor_material.normal_enabled = true
	floor_material.normal_texture = load("res://assets/polyhaven/realtime_battle/cobblestone_floor_normal_1k.jpg")
	floor_material.roughness = 0.9
	iron_material = colored_material(Color(0.045, 0.052, 0.049), 0.94, 0.42)
	wet_material = colored_material(Color(0.025, 0.045, 0.04), 0.18, 0.2)
	rotten_material = colored_material(Color(0.18, 0.13, 0.045), 0.0, 1.0)
	blood_material = colored_material(Color(0.28, 0.003, 0.006), 0.0, 0.42)
	flesh_material = colored_material(Color(0.3, 0.18, 0.13), 0.0, 0.94)

func colored_material(color:Color, metallic:float, roughness:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func build_environment() -> void:
	var node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.001, 0.002, 0.004)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.035, 0.045, 0.052)
	environment.ambient_light_energy = 0.13
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.3
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.025, 0.034, 0.038)
	environment.fog_density = 0.026
	node.environment = environment
	add_child(node)
	world_root = Node3D.new()
	world_root.name = "PrisonArchitecture"
	add_child(world_root)

func build_prison() -> void:
	build_corridor_z("Entrance", 0, -39, 22, 90)
	build_hub()
	build_corridor_x("OpenTurn", -37, -94, 38, 22)
	build_corridor_z("OpenWing", -56, -119, 22, 50)
	build_corridor_x("BlueTurn", 37, -94, 38, 22)
	build_corridor_z("BlueWing", 56, -119, 22, 50)
	build_corridor_z("RedTurn", -7, -135, 10, 58)
	build_corridor_x("RedWing", -30, -164, 46, 22)
	build_corridor_z("GreenTurn", 7, -135, 10, 58)
	build_corridor_x("GreenWing", 30, -164, 46, 22)
	for z in [-11.0, -25.0, -39.0, -53.0, -67.0]:
		if z != -11.0:
			build_cell_z(0, -1, z, "intro", z == -25.0)
		build_cell_z(0, 1, z, "intro", z == -53.0)
	create_box("AxeCellDivider", Vector3(-8, 2, -3.6), Vector3(5.6, 4.4, 0.35), stone_material, true, world_root)
	create_box("AxeCellDivider", Vector3(-8, 2, -10.4), Vector3(5.6, 4.4, 0.35), stone_material, true, world_root)
	for z in [-106.0, -121.0]:
		build_cell_z(-56, -1, z, "intro", z == -121.0)
		build_cell_z(-56, 1, z, "intro", false)
		build_cell_z(56, -1, z, "blue", false)
		build_cell_z(56, 1, z, "blue", z == -106.0)
	for x in [-43.0, -28.0]:
		build_cell_x(x, -164, -1, "red", false)
		build_cell_x(x, -164, 1, "red", x == -28.0)
	for x in [28.0, 43.0]:
		build_cell_x(x, -164, -1, "green", x == 28.0)
		build_cell_x(x, -164, 1, "green", false)
	route_gates["blue"] = build_gate("BlueRouteGate", Vector3(19, 0, -94), 9, "x", Color(0.08, 0.3, 1))
	route_gates["red"] = build_gate("RedRouteGate", Vector3(-7, 0, -108), 8, "z", Color(1, 0.035, 0.02))
	route_gates["green"] = build_gate("GreenRouteGate", Vector3(7, 0, -108), 8, "z", Color(0.04, 1, 0.2))
	build_key_rooms()
	build_debris()
	for fixture in [Vector3(0, 4.15, -8), Vector3(0, 4.15, -36), Vector3(0, 4.15, -70), Vector3(-35, 4.15, -94), Vector3(-56, 4.15, -118), Vector3(35, 4.15, -94), Vector3(56, 4.15, -118), Vector3(-30, 4.15, -164), Vector3(30, 4.15, -164)]:
		build_flickering_fixture(fixture, int(absf(fixture.x + fixture.z)))

func build_hub() -> void:
	create_box("HubFloor", Vector3(0, -0.25, -94), Vector3(36, 0.5, 28), floor_material, true, world_root)
	create_box("HubCeiling", Vector3(0, 4.6, -94), Vector3(36, 0.45, 28), stone_material, true, world_root)
	for wall in [
		[Vector3(-12, 2.15, -80.3), Vector3(12, 4.8, 0.6)], [Vector3(12, 2.15, -80.3), Vector3(12, 4.8, 0.6)],
		[Vector3(-14, 2.15, -107.7), Vector3(8, 4.8, 0.6)], [Vector3(0, 2.15, -107.7), Vector3(4, 4.8, 0.6)], [Vector3(14, 2.15, -107.7), Vector3(8, 4.8, 0.6)],
		[Vector3(-17.7, 2.15, -104), Vector3(0.6, 4.8, 8)], [Vector3(-17.7, 2.15, -84), Vector3(0.6, 4.8, 8)],
		[Vector3(17.7, 2.15, -104), Vector3(0.6, 4.8, 8)], [Vector3(17.7, 2.15, -84), Vector3(0.6, 4.8, 8)]]:
		create_box("HubWall", wall[0], wall[1], stone_material, true, world_root)
	for marker in [[Vector3(-14.5, 3.6, -94), Color(0.25, 0.7, 0.9)], [Vector3(14.5, 3.6, -94), Color(0.08, 0.3, 1)], [Vector3(-7, 3.6, -104.5), Color(1, 0.03, 0.02)], [Vector3(7, 3.6, -104.5), Color(0.04, 1, 0.2)]]:
		build_light(marker[0], marker[1], 3.2, 8, world_root)

func build_corridor_z(prefix:String, x:float, z:float, width:float, length:float) -> void:
	create_box(prefix + "Floor", Vector3(x, -0.25, z), Vector3(width, 0.5, length), floor_material, true, world_root)
	create_box(prefix + "Ceiling", Vector3(x, 4.6, z), Vector3(width, 0.45, length), stone_material, true, world_root)
	create_box(prefix + "LeftWall", Vector3(x - width * 0.5, 2.15, z), Vector3(0.6, 4.8, length), stone_material, true, world_root)
	create_box(prefix + "RightWall", Vector3(x + width * 0.5, 2.15, z), Vector3(0.6, 4.8, length), stone_material, true, world_root)

func build_corridor_x(prefix:String, x:float, z:float, length:float, width:float) -> void:
	create_box(prefix + "Floor", Vector3(x, -0.25, z), Vector3(length, 0.5, width), floor_material, true, world_root)
	create_box(prefix + "Ceiling", Vector3(x, 4.6, z), Vector3(length, 0.45, width), stone_material, true, world_root)
	create_box(prefix + "NorthWall", Vector3(x, 2.15, z - width * 0.5), Vector3(length, 4.8, 0.6), stone_material, true, world_root)
	create_box(prefix + "SouthWall", Vector3(x, 2.15, z + width * 0.5), Vector3(length, 4.8, 0.6), stone_material, true, world_root)

func build_cell_z(corridor_x:float, side:int, z:float, stage:String, empty:bool) -> void:
	var center_x := corridor_x + side * 8.0
	var front_x := corridor_x + side * 5.25
	create_box("CellDivider", Vector3(center_x, 2, z - 3.4), Vector3(5.6, 4.4, 0.35), stone_material, true, world_root)
	create_box("CellDivider", Vector3(center_x, 2, z + 3.4), Vector3(5.6, 4.4, 0.35), stone_material, true, world_root)
	var door := build_gate("Cell_%s_%s" % [stage, str(z)], Vector3(front_x, 0, z), 5.8, "x", Color(0.32, 0.09, 0.05), false)
	if empty:
		hiding_zones.append(AABB(Vector3(minf(front_x, center_x) - 0.5, -0.2, z - 3), Vector3(absf(center_x - front_x) + 1, 2.8, 6)))
		create_box("CellCover", Vector3(center_x, 0.8, z), Vector3(1.8, 1.6, 2.4), rotten_material, true, world_root)
	else:
		stage_doors[stage].append(door)
		spawn_record(Vector3(center_x, 0, z), stage, door)

func build_cell_x(x:float, corridor_z:float, side:int, stage:String, empty:bool) -> void:
	var center_z := corridor_z + side * 8.0
	var front_z := corridor_z + side * 5.25
	create_box("CellDivider", Vector3(x - 3.4, 2, center_z), Vector3(0.35, 4.4, 5.6), stone_material, true, world_root)
	create_box("CellDivider", Vector3(x + 3.4, 2, center_z), Vector3(0.35, 4.4, 5.6), stone_material, true, world_root)
	var door := build_gate("Cell_%s_%s" % [stage, str(x)], Vector3(x, 0, front_z), 5.8, "z", Color(0.32, 0.09, 0.05), false)
	if empty:
		hiding_zones.append(AABB(Vector3(x - 3, -0.2, minf(front_z, center_z) - 0.5), Vector3(6, 2.8, absf(center_z - front_z) + 1)))
		create_box("CellCover", Vector3(x, 0.8, center_z), Vector3(2.4, 1.6, 1.8), rotten_material, true, world_root)
	else:
		stage_doors[stage].append(door)
		spawn_record(Vector3(x, 0, center_z), stage, door)

func build_key_rooms() -> void:
	key_room_doors["intro"] = build_gate("BlueKeyRoom", Vector3(-56, 0, -137), 9, "z", Color(0.08, 0.3, 1))
	key_room_doors["blue"] = build_gate("RedKeyRoom", Vector3(56, 0, -137), 9, "z", Color(1, 0.035, 0.02))
	key_room_doors["red"] = build_gate("GreenKeyRoom", Vector3(-49, 0, -164), 9, "x", Color(0.04, 1, 0.2))
	key_room_doors["green"] = build_gate("FinalKeyRoom", Vector3(49, 0, -164), 9, "x", Color(0.8, 0.72, 0.5))
	levers["intro"] = build_lever(Vector3(-51.5, 1, -133.5), "intro")
	levers["blue"] = build_lever(Vector3(51.5, 1, -133.5), "blue")
	levers["red"] = build_lever(Vector3(-45.5, 1, -159.5), "red")
	levers["green"] = build_lever(Vector3(45.5, 1, -159.5), "green")

func build_gate(node_name:String, position_value:Vector3, width:float, axis:String, color:Color, add_light:bool = true) -> Node3D:
	var door := Node3D.new()
	door.name = node_name
	door.position = position_value
	world_root.add_child(door)
	var count := maxi(5, int(width / 0.75))
	for index in count:
		var offset := -width * 0.5 + index * width / float(count - 1)
		create_bar(Vector3(0, 2.05, offset) if axis == "x" else Vector3(offset, 2.05, 0), 4.3, 0.09, door)
	for height in [0.45, 2.05, 3.65]:
		create_box("Crossbar", Vector3(0, height, 0), Vector3(0.16, 0.13, width) if axis == "x" else Vector3(width, 0.13, 0.16), iron_material, true, door)
	# Barreira física contínua que impede 100% que o player atravesse as grades da cela
	var barrier := StaticBody3D.new()
	barrier.name = "SolidGateBarrier"
	barrier.position = Vector3(0, 2.15, 0)
	var b_col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = Vector3(0.35, 4.3, width) if axis == "x" else Vector3(width, 4.3, 0.35)
	b_col.shape = b_shape
	barrier.add_child(b_col)
	door.add_child(barrier)
	if add_light:
		build_light(Vector3(0, 3.3, 0), color, 3.6, 7, door)
	return door

func build_lever(position_value:Vector3, stage:String) -> Node3D:
	var lever := Node3D.new()
	lever.name = "Lever_" + stage
	lever.position = position_value
	world_root.add_child(lever)
	create_box("Base", Vector3.ZERO, Vector3(0.65, 1, 0.35), iron_material, false, lever)
	var handle := create_box("Handle", Vector3(0, 0.65, -0.08), Vector3(0.14, 0.95, 0.14), rotten_material, false, lever)
	handle.rotation.x = -0.55
	lever.set_meta("handle", handle)
	build_light(Vector3(0, 0.6, 0.35), Color(1, 0.5, 0.04), 2.4, 4, lever)
	return lever

func create_bar(local_position:Vector3, height:float, radius:float, parent:Node3D) -> void:
	var body := StaticBody3D.new()
	body.position = local_position
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
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
	var root:Node3D = StaticBody3D.new() if collision_enabled else Node3D.new()
	root.name = node_name
	root.position = position_value
	parent.add_child(root)
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	if material == stone_material || material == floor_material:
		var tiled := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		# Projeção triplanar em escala de mundo impede que paredes longas
		# estiquem o mesmo UV por dezenas de metros.
		tiled.uv1_triplanar = true
		tiled.uv1_world_triplanar = true
		tiled.uv1_scale = Vector3(0.42, 0.42, 0.42)
		mesh.material = tiled
		mesh.subdivide_width = mini(32, maxi(0, int(size.x / 3)))
		mesh.subdivide_height = mini(16, maxi(0, int(size.y / 2)))
		mesh.subdivide_depth = mini(32, maxi(0, int(size.z / 3)))
	else:
		mesh.material = material
	instance.mesh = mesh
	root.add_child(instance)
	if collision_enabled:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		root.add_child(collision)
	return root

func build_light(position_value:Vector3, color:Color, energy:float, light_range:float, parent:Node3D) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	parent.add_child(light)
	return light

func build_flickering_fixture(position_value:Vector3, seed_value:int) -> void:
	var fixture := create_box("BrokenFixture", position_value, Vector3(1.2, 0.1, 0.28), iron_material, false, world_root)
	var light := build_light(Vector3(0, -0.25, 0), Color(0.48, 0.64, 0.67) if seed_value % 2 == 0 else Color(0.58, 0.12, 0.06), 2.4, 9, fixture)
	flicker_lights.append({"light": light, "base": light.light_energy, "phase": seed_value * 0.31})

func build_debris() -> void:
	for p in [Vector3(-1.5, 0.015, -14), Vector3(2.2, 0.015, -48), Vector3(-9, 0.015, -91), Vector3(-55, 0.015, -116), Vector3(55, 0.015, -124), Vector3(0, 0.015, -161)]:
		var instance := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.4
		mesh.bottom_radius = 1.7
		mesh.height = 0.025
		mesh.material = wet_material
		instance.mesh = mesh
		instance.position = p
		world_root.add_child(instance)
	for p in [Vector3(-5.8, 0.12, -19), Vector3(6.2, 0.12, -45), Vector3(-57, 0.12, -112), Vector3(57, 0.12, -127), Vector3(31, 0.12, -165)]:
		for piece in 5:
			var lump := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.1 + randf() * 0.1
			mesh.height = mesh.radius * 2
			mesh.material = rotten_material
			lump.mesh = mesh
			lump.position = p + Vector3(randf_range(-0.35, 0.35), 0.12, randf_range(-0.35, 0.35))
			world_root.add_child(lump)
		build_mosquitoes(p + Vector3.UP * 0.4)
	for p in [Vector3(-4, 0.85, -32), Vector3(4, 0.85, -61), Vector3(-42, 0.85, -94), Vector3(-56, 0.85, -128), Vector3(43, 0.85, -94), Vector3(56, 0.85, -112), Vector3(-24, 0.85, -164), Vector3(24, 0.85, -164)]:
		create_box("CorridorCover", p, Vector3(2.4, 1.7, 2.2), rotten_material, true, world_root)

func build_mosquitoes(position_value:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = position_value
	particles.amount = 24
	particles.lifetime = 3.2
	particles.preprocess = 3.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.1
	particles.spread = 180
	particles.initial_velocity_min = 0.12
	particles.initial_velocity_max = 0.6
	particles.gravity = Vector3.ZERO
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.026, 0.026)
	mesh.material = colored_material(Color(0.005, 0.005, 0.005), 0, 1)
	particles.mesh = mesh
	world_root.add_child(particles)

func build_player() -> void:
	player = PLAYER_SCENE.instantiate() as DungeonPlayer
	player.position = Vector3(0, 8, 3.2)
	add_child(player)
	player.interact_pressed.connect(on_interact_pressed)
	player.fired.connect(on_player_fired)
	player.flashlight_toggled.connect(func(_enabled:bool): update_hud())

func build_pickups() -> void:
	pickups["flashlight"] = build_flashlight(Vector3(0.2, 0.45, -2.5))
	pickups["blue_key"] = build_key(Vector3(-56, 0.65, -141), Color(0.08, 0.3, 1), "BlueKey")
	pickups["pistol"] = build_gun(Vector3(-53.8, 0.62, -141), false)
	pickups["red_key"] = build_key(Vector3(56, 0.65, -141), Color(1, 0.035, 0.02), "RedKey")
	pickups["green_key"] = build_key(Vector3(-52.5, 0.65, -164), Color(0.04, 1, 0.2), "GreenKey")
	pickups["cell_key"] = build_key(Vector3(52.5, 0.65, -164), Color(0.9, 0.8, 0.52), "CellKey")
	pickups["machinegun"] = build_gun(Vector3(52.5, 0.62, -161.7), true)
	axe_door = build_gate("AxeCellDoor", Vector3(-5.25, 0, -7), 5.8, "x", Color(0.95, 0.02, 0.01))
	axe_pickup = build_axe(Vector3(-8.2, 0.72, -7))
	trampoline = Node3D.new()
	trampoline.position = Vector3(0, 0, 3.5)
	world_root.add_child(trampoline)
	instantiate_model("res://assets/kenney/platformer_3d/spring.glb", Vector3.ZERO, Vector3.ONE * 1.8, trampoline)
	build_light(Vector3(0, 0.7, 0), Color(0.15, 0.45, 1), 2.8, 5, trampoline)

func build_flashlight(position_value:Vector3) -> Node3D:
	var pickup := Node3D.new()
	pickup.position = position_value
	world_root.add_child(pickup)
	instantiate_model("res://assets/kenney/graveyard_kit/lantern-glass.glb", Vector3.ZERO, Vector3.ONE * 1.7, pickup)
	build_light(Vector3.ZERO, Color(0.72, 0.86, 1), 3, 4, pickup)
	return pickup

func build_gun(position_value:Vector3, machinegun:bool) -> Node3D:
	var gun := Node3D.new()
	gun.position = position_value
	world_root.add_child(gun)
	create_box("Body", Vector3.ZERO, Vector3(0.3, 0.26, 1.15 if machinegun else 0.62), iron_material, false, gun)
	create_box("Barrel", Vector3(0, 0.03, -0.78 if machinegun else -0.48), Vector3(0.11, 0.11, 0.75 if machinegun else 0.42), iron_material, false, gun)
	create_box("Grip", Vector3(0, -0.24, 0.2), Vector3(0.18, 0.48, 0.22), rotten_material, false, gun)
	build_light(Vector3(0, 0.3, 0), Color(1, 0.48, 0.08), 3, 4.5, gun)
	return gun

func build_key(position_value:Vector3, color:Color, node_name:String) -> Node3D:
	var key := Node3D.new()
	key.name = node_name
	key.position = position_value
	world_root.add_child(key)
	var material := colored_material(color, 0.75, 0.35)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.21
	torus.material = material
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	key.add_child(ring)
	create_box("Stem", Vector3(0, 0, -0.3), Vector3(0.09, 0.09, 0.6), material, false, key)
	build_light(Vector3.ZERO, color, 2.7, 4, key)
	return key

func build_axe(position_value:Vector3) -> Node3D:
	var axe := Node3D.new()
	axe.position = position_value
	world_root.add_child(axe)
	create_box("Handle", Vector3(0, 0.35, 0), Vector3(0.12, 1.3, 0.12), rotten_material, false, axe)
	var blade := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.62, 0.55, 0.12)
	prism.material = iron_material
	blade.mesh = prism
	blade.position = Vector3(0.25, 0.9, 0)
	blade.rotation.z = -PI * 0.5
	axe.add_child(blade)
	build_light(Vector3(0, 1.1, 0), Color(0.9, 0.08, 0.02), 3.8, 5, axe)
	return axe

func instantiate_model(path:String, position_value:Vector3, scale_value:Vector3, parent:Node3D) -> Node3D:
	var packed:PackedScene = load(path)
	if !packed:
		return null
	var model := packed.instantiate() as Node3D
	model.position = position_value
	model.scale = scale_value
	parent.add_child(model)
	return model

func spawn_record(position_value:Vector3, stage:String, door:Node3D) -> void:
	var variants := [
		{"path": ZOMBIE_MODEL, "kind": "zombie", "scale": 1.05},
		{"path": HOUND_MODEL, "kind": "hound", "scale": 0.72},
		{"path": RUNNER_MODEL, "kind": "mutant", "scale": 1.35}
	]
	var variant:Dictionary = variants[enemy_spawns.size() % variants.size()]
	var automatic:bool = stage == "intro" && !auto_release_assigned
	if automatic:
		auto_release_assigned = true
	enemy_spawns.append({"position": position_value, "stage": stage, "path": variant.path, "kind": variant.kind, "scale": variant.scale, "door": door, "auto_release": automatic})

func build_infected_population() -> void:
	for record in enemy_spawns:
		spawn_infected(record, false)

func spawn_infected(record:Dictionary, force_released:bool) -> DungeonInfected:
	var infected := DungeonInfected.new()
	infected.position = record.position
	add_child(infected)
	var stage:String = record.stage
	var opened := event_is_true("dungeon_%s_lever" % stage) || event_is_true("dungeon_finale_triggered")
	infected.setup(player, self, record.path, force_released || opened, 0, record.kind, float(record.scale))
	infected.set_meta("stage", stage)
	infected.set_meta("cell_door", record.door)
	infected.set_meta("auto_release", bool(record.get("auto_release", false)))
	infected.caught_player.connect(on_player_caught)
	infected.died.connect(on_infected_died)
	enemies.append(infected)
	stage_enemies[stage].append(infected)
	return infected

func build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "DungeonHUD"
	hud.add_to_group("hide_on_pause")
	add_child(hud)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.01, 0.015, 0.02, 0.16)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vignette)
	objective_label = make_label(20, Color(0.78, 0.86, 0.83), HORIZONTAL_ALIGNMENT_LEFT)
	objective_label.position = Vector2(28, 24)
	objective_label.size = Vector2(940, 40)
	hud.add_child(objective_label)
	help_label = make_label(17, Color(0.65, 0.72, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	help_label.position = Vector2(28, 58)
	help_label.size = Vector2(940, 35)
	help_label.text = tr("DUNGEON_MOVE_HINT")
	hud.add_child(help_label)
	flashlight_label = make_label(18, Color(0.7, 0.84, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	flashlight_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	flashlight_label.position = Vector2(-510, 28)
	flashlight_label.size = Vector2(480, 35)
	hud.add_child(flashlight_label)
	weapon_label = make_label(18, Color(1, 0.62, 0.26), HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	weapon_label.position = Vector2(-510, 64)
	weapon_label.size = Vector2(480, 35)
	hud.add_child(weapon_label)
	prompt_label = make_label(24, Color(0.95, 0.86, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-550, -112)
	prompt_label.size = Vector2(1100, 44)
	hud.add_child(prompt_label)
	var crosshair := make_label(24, Color(0.9, 0.92, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-20, -22)
	crosshair.size = Vector2(40, 40)
	crosshair.text = "+"
	hud.add_child(crosshair)
	build_inventory_hud(hud)
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color.BLACK
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.z_index = 100
	hud.add_child(fade_overlay)
	blood_overlay = Control.new()
	blood_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blood_overlay.z_index = 90
	blood_overlay.visible = false
	hud.add_child(blood_overlay)
	build_blood_overlay_graphics()
	update_hud()

func generate_organic_blood_texture(radius:int) -> ImageTexture:
	var size := radius * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(radius, radius)
	var seed_offset := randf() * 100.0
	for y in size:
		for x in size:
			var pos := Vector2(x, y)
			var dist := pos.distance_to(center)
			var angle := (pos - center).angle()
			var radius_noise := float(radius) * (0.6 + 0.32 * sin(angle * 4.0 + seed_offset) * cos(angle * 2.0))
			if dist < radius_noise:
				var edge_fade := clampf((radius_noise - dist) / 6.0, 0.0, 1.0)
				var alpha := clampf((1.0 - (dist / radius_noise) * 0.45) * edge_fade, 0.0, 0.95)
				img.set_pixel(x, y, Color(randf_range(0.38, 0.65), randf_range(0.005, 0.02), randf_range(0.01, 0.025), alpha))
	# Adicionar respingos finos e gotas ao redor da mancha
	for s in 10:
		var s_angle := randf() * TAU
		var s_dist := randf_range(radius * 0.45, radius * 0.92)
		var s_center := center + Vector2(cos(s_angle), sin(s_angle)) * s_dist
		var s_rad := randf_range(2.0, radius * 0.22)
		for dy in range(-int(s_rad), int(s_rad) + 1):
			for dx in range(-int(s_rad), int(s_rad) + 1):
				var px := int(s_center.x + dx)
				var py := int(s_center.y + dy)
				if px >= 0 && px < size && py >= 0 && py < size:
					if Vector2(dx, dy).length() < s_rad:
						img.set_pixel(px, py, Color(randf_range(0.42, 0.62), 0.01, 0.015, 0.88))
	return ImageTexture.create_from_image(img)

func build_blood_overlay_graphics() -> void:
	for child in blood_overlay.get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(24):
		var patch := TextureRect.new()
		var rad := rng.randi_range(55, 145)
		patch.texture = generate_organic_blood_texture(rad)
		patch.position = Vector2(rng.randf_range(-40, 1820), rng.randf_range(-30, 980))
		patch.rotation = rng.randf_range(-PI, PI)
		patch.modulate.a = 0.0
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blood_overlay.add_child(patch)

func build_inventory_hud(hud:CanvasLayer) -> void:
	inventory_bar = HBoxContainer.new()
	inventory_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	inventory_bar.position = Vector2(24, -86)
	inventory_bar.size = Vector2(840, 60)
	hud.add_child(inventory_bar)
	for data in [["flashlight", "🔦", "DUNGEON_ITEM_FLASHLIGHT", Color(0.55, 0.78, 1)], ["blue_key", "🔑", "DUNGEON_ITEM_BLUE_KEY", Color(0.15, 0.35, 1)], ["pistol", "🔫", "DUNGEON_ITEM_PISTOL", Color(0.8, 0.65, 0.35)], ["red_key", "🔑", "DUNGEON_ITEM_RED_KEY", Color(1, 0.12, 0.08)], ["green_key", "🔑", "DUNGEON_ITEM_GREEN_KEY", Color(0.08, 1, 0.24)], ["cell_key", "🔑", "DUNGEON_ITEM_CELL_KEY", Color(0.9, 0.78, 0.48)], ["machinegun", "🔫", "DUNGEON_ITEM_MACHINEGUN", Color(1, 0.5, 0.08)], ["axe", "🪓", "DUNGEON_ITEM_AXE", Color(0.92, 0.15, 0.08)]]:
		var slot := Label.new()
		slot.text = "%s\n%s" % [data[1], tr(data[2])]
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.custom_minimum_size = Vector2(92, 56)
		slot.add_theme_font_size_override("font_size", 12)
		slot.add_theme_color_override("font_color", data[3])
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.015, 0.02, 0.025, 0.88)
		panel.border_color = Color(data[3], 0.7)
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(5)
		slot.add_theme_stylebox_override("normal", panel)
		slot.visible = false
		inventory_bar.add_child(slot)
		inventory_slots[data[0]] = slot

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
	var ambience := AudioStreamPlayer.new()
	var ambience_stream:AudioStream = load("res://assets/novos_audios/calabouco_terror/dungeon_ambience_pixabay.mp3")
	if ambience_stream:
		ambience_stream = ambience_stream.duplicate()
		ambience_stream.set("loop", true)
	ambience.stream = ambience_stream
	ambience.volume_db = -10.5
	add_child(ambience)
	ambience.play()
	gun_sound = make_audio("res://assets/novos_audios/gun_shot.mp3", -5)
	pickup_sound = make_audio("res://assets/novos_audios/gun_load.mp3", -7)
	gate_sound = AudioStreamPlayer3D.new()
	gate_sound.stream = load("res://assets/novos_audios/metal_batendo.mp3")
	gate_sound.max_distance = 30
	add_child(gate_sound)

func make_audio(path:String, volume:float) -> AudioStreamPlayer:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func apply_saved_state() -> void:
	player.set_flashlight_available(event_is_true("dungeon_flashlight_taken"))
	if event_is_true("dungeon_gun_taken"):
		player.set_weapon("machinegun")
	elif event_is_true("dungeon_pistol_taken"):
		player.set_weapon("pistol")
	for data in [["flashlight", "dungeon_flashlight_taken"], ["blue_key", "dungeon_blue_key_taken"], ["pistol", "dungeon_pistol_taken"], ["red_key", "dungeon_red_key_taken"], ["green_key", "dungeon_green_key_taken"], ["cell_key", "dungeon_key_taken"], ["machinegun", "dungeon_gun_taken"]]:
		if event_is_true(data[1]) && is_instance_valid(pickups[data[0]]):
			pickups[data[0]].queue_free()
	for color in ["blue", "red", "green"]:
		if event_is_true("dungeon_%s_key_taken" % color):
			open_door(route_gates[color], false)
	for stage in ["intro", "blue", "red", "green"]:
		if event_is_true("dungeon_%s_lever" % stage) || event_is_true("dungeon_finale_triggered"):
			activate_stage(stage, false)
	if event_is_true("dungeon_axe_door_open") || event_is_true("dungeon_key_taken") || has_axe_event():
		open_door(axe_door, false)
	if has_axe_event() && is_instance_valid(axe_pickup):
		axe_pickup.queue_free()
	update_hud()

func start_arrival() -> void:
	sequence_running = true
	player.controls_enabled = false
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(player, "position:y", 0.08, 1.05)
	tween.parallel().tween_property(fade_overlay, "color:a", 0, 1.7)
	await tween.finished
	player.controls_enabled = true
	sequence_running = false
	fade_overlay.visible = false

func _process(delta:float) -> void:
	elapsed += delta
	for data in flicker_lights:
		var light:OmniLight3D = data.light
		var pulse:float = sin(elapsed * 7.3 + data.phase) * sin(elapsed * 13.7 + data.phase * 2)
		light.light_energy = data.base * (0.65 + absf(pulse) * 0.45) * (0.08 if pulse > 0.82 else 1)
	for key in pickups:
		var pickup = pickups[key]
		if is_instance_valid(pickup):
			pickup.rotation.y += delta * (1.15 if "key" in key else 0.55)
	if is_instance_valid(axe_pickup):
		axe_pickup.rotation.y = sin(elapsed * 1.3) * 0.1
	if !sequence_running:
		for enemy in enemies:
			if is_instance_valid(enemy) && !enemy.released && enemy.get_meta("auto_release", false) && player.global_position.z < enemy.global_position.z + 6.0:
				release_enemy(enemy)
		check_automatic_pickups()
		update_interaction()
		if player.position.y < -4:
			restart_after_caught(null)

func check_automatic_pickups() -> void:
	for pickup_name in pickups:
		var pickup = pickups[pickup_name]
		if is_instance_valid(pickup) && player.global_position.distance_to(pickup.global_position) < 1.65:
			collect_pickup(pickup_name)
	if is_instance_valid(axe_pickup) && event_is_true("dungeon_axe_door_open") && player.global_position.distance_to(axe_pickup.global_position) < 1.7:
		collect_axe()

func collect_pickup(pickup_name:String) -> void:
	var pickup:Node3D = pickups[pickup_name]
	if !is_instance_valid(pickup):
		return
	match pickup_name:
		"flashlight":
			Global.game_events["dungeon_flashlight_taken"] = true
			player.set_flashlight_available(true)
			player.toggle_flashlight()
		"blue_key":
			Global.game_events["dungeon_blue_key_taken"] = true
			open_door(route_gates["blue"], true)
		"pistol":
			Global.game_events["dungeon_pistol_taken"] = true
			player.set_weapon("pistol")
		"red_key":
			Global.game_events["dungeon_red_key_taken"] = true
			open_door(route_gates["red"], true)
		"green_key":
			Global.game_events["dungeon_green_key_taken"] = true
			open_door(route_gates["green"], true)
		"cell_key":
			Global.game_events["dungeon_key_taken"] = true
			Global.game_events["dungeon_gun_taken"] = true
			player.set_weapon("machinegun")
			if is_instance_valid(pickups["machinegun"]):
				pickups["machinegun"].queue_free()
			open_door(axe_door, true)
			start_finale_cutscene.call_deferred()
		"machinegun":
			Global.game_events["dungeon_gun_taken"] = true
			player.set_weapon("machinegun")
	pickup_sound.play()
	pickup.queue_free()
	Global.save_progress("calabouco_terror")
	update_hud()

func collect_axe() -> void:
	Global.maycon_itens["axe"] = true
	Global.game_events["axe_taken"] = true
	Global.game_events["dungeon_axe_taken"] = true
	pickup_sound.play()
	axe_pickup.queue_free()
	Global.save_progress("calabouco_terror")
	update_hud()

func update_interaction() -> void:
	current_interaction = ""
	var prompt_key := ""
	for stage in levers:
		var lever:Node3D = levers[stage]
		if !event_is_true("dungeon_%s_lever" % stage) && player.global_position.distance_to(lever.global_position) < 2.2:
			current_interaction = "lever:" + stage
			prompt_key = "DUNGEON_PROMPT_LEVER"
			break
	if prompt_key == "" && player.global_position.distance_to(trampoline.global_position) < 2.4:
		current_interaction = "trampoline"
		prompt_key = "DUNGEON_PROMPT_TRAMPOLINE" if has_axe_event() else "DUNGEON_TRAMPOLINE_LOCKED"
	prompt_label.visible = prompt_key != ""
	if prompt_key != "":
		prompt_label.text = tr(prompt_key)

func on_interact_pressed() -> void:
	if sequence_running:
		return
	if current_interaction.begins_with("lever:"):
		activate_stage(current_interaction.trim_prefix("lever:"), true)
	elif current_interaction == "trampoline" && has_axe_event():
		return_to_castle()

func activate_stage(stage:String, with_sound:bool) -> void:
	Global.game_events["dungeon_%s_lever" % stage] = true
	open_door(key_room_doors[stage], with_sound)
	for door in stage_doors[stage]:
		open_door(door, false)
	for enemy in stage_enemies[stage]:
		if is_instance_valid(enemy):
			enemy.release_from_cell()
	var handle:Node3D = levers[stage].get_meta("handle", null)
	if is_instance_valid(handle):
		handle.rotation.x = 0.75
	Global.save_progress("calabouco_terror")
	update_hud()

func release_enemy(enemy:DungeonInfected) -> void:
	enemy.release_from_cell()
	var door:Node3D = enemy.get_meta("cell_door", null)
	open_door(door, true)

func open_door(door:Node3D, with_sound:bool) -> void:
	if !is_instance_valid(door) || door.get_meta("open", false):
		return
	door.set_meta("open", true)
	if door == axe_door:
		Global.game_events["dungeon_axe_door_open"] = true
	if with_sound:
		gate_sound.global_position = door.global_position
		gate_sound.play()
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT).tween_property(door, "position:y", 5.2, 1.15)

func start_finale_cutscene() -> void:
	if sequence_running || event_is_true("dungeon_finale_triggered"):
		return
	Global.game_events["dungeon_finale_triggered"] = true
	for stage in ["intro", "blue", "red", "green"]:
		activate_stage(stage, false)
	for record in enemy_spawns:
		spawn_infected(record, true)
	sequence_running = true
	player.controls_enabled = false
	var cinematic := Camera3D.new()
	add_child(cinematic)
	cinematic.global_position = player.camera.global_position
	cinematic.current = true
	for point in [Vector3(0, 3, -45), Vector3(0, 3.2, -92), Vector3(-45, 3, -104), Vector3(-56, 3, -132), Vector3(48, 3, -102), Vector3(56, 3, -132), Vector3(-32, 3, -164), Vector3(32, 3, -164)]:
		cinematic.look_at(point + Vector3(0, -0.8, -5), Vector3.UP)
		await create_tween().set_trans(Tween.TRANS_SINE).tween_property(cinematic, "global_position", point, 0.72).finished
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1, 0.4).finished
	player.camera.current = true
	cinematic.queue_free()
	await create_tween().tween_property(fade_overlay, "color:a", 0, 0.55).finished
	fade_overlay.visible = false
	player.controls_enabled = true
	sequence_running = false
	update_hud()

func update_hud() -> void:
	if !is_instance_valid(objective_label):
		return
	if !player.has_flashlight:
		objective_label.text = tr("DUNGEON_OBJECTIVE_FLASHLIGHT")
	elif !event_is_true("dungeon_blue_key_taken"):
		objective_label.text = tr("DUNGEON_OBJECTIVE_BLUE_KEY")
	elif !event_is_true("dungeon_red_key_taken"):
		objective_label.text = tr("DUNGEON_OBJECTIVE_RED_KEY")
	elif !event_is_true("dungeon_green_key_taken"):
		objective_label.text = tr("DUNGEON_OBJECTIVE_GREEN_KEY")
	elif !event_is_true("dungeon_key_taken"):
		objective_label.text = tr("DUNGEON_OBJECTIVE_CELL_KEY")
	elif !has_axe_event():
		objective_label.text = tr("DUNGEON_OBJECTIVE_AXE")
	else:
		objective_label.text = tr("DUNGEON_OBJECTIVE_ESCAPE")
	flashlight_label.text = tr("DUNGEON_FLASHLIGHT_ON") if player.flashlight_on else tr("DUNGEON_FLASHLIGHT_OFF")
	if !player.has_flashlight:
		flashlight_label.text = ""
	weapon_label.text = tr("DUNGEON_MACHINEGUN_READY") if player.weapon_mode == "machinegun" else (tr("DUNGEON_PISTOL_READY") if player.weapon_mode == "pistol" else "")
	var found := {"flashlight": event_is_true("dungeon_flashlight_taken"), "blue_key": event_is_true("dungeon_blue_key_taken"), "pistol": event_is_true("dungeon_pistol_taken"), "red_key": event_is_true("dungeon_red_key_taken"), "green_key": event_is_true("dungeon_green_key_taken"), "cell_key": event_is_true("dungeon_key_taken"), "machinegun": event_is_true("dungeon_gun_taken"), "axe": has_axe_event()}
	for item_name in inventory_slots:
		var slot: Control = inventory_slots[item_name]
		var should_be_visible: bool = bool(found.get(item_name, false))
		if should_be_visible:
			if not slot.visible:
				slot.visible = true
				slot.scale = Vector2(0.2, 0.2)
				slot.pivot_offset = slot.size * 0.5
				create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(slot, "scale", Vector2.ONE, 0.28)
		else:
			slot.visible = false

func event_is_true(event_name:String) -> bool:
	return bool(Global.game_events.get(event_name, false))

func has_axe_event() -> bool:
	return event_is_true("axe_taken") || event_is_true("dungeon_axe_taken") || bool(Global.maycon_itens.get("axe", false))

func on_player_fired(origin:Vector3, direction:Vector3) -> void:
	if sequence_running:
		return
	gun_sound.play()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 68)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if !hit.is_empty() && hit.collider is DungeonInfected:
		hit.collider.take_damage(2 if player.weapon_mode == "pistol" else 1)
		spawn_blood_hit(hit.position, direction)

func spawn_blood_hit(hit_position:Vector3, direction:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = hit_position
	particles.amount = 45
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = direction
	particles.spread = 55
	particles.initial_velocity_min = 2.4
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -9.8, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.04
	mesh.material = blood_material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)

func spawn_enemy_death_blood(death_position:Vector3, enemy_kind:String) -> void:
	var particles := CPUParticles3D.new()
	particles.position = death_position
	particles.amount = 170 if enemy_kind != "hound" else 110
	particles.lifetime = 1.15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.28
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.2
	particles.initial_velocity_max = 9.5
	particles.gravity = Vector3(0, -13.5, 0)
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.65
	var droplet := SphereMesh.new()
	droplet.radius = 0.045
	droplet.height = 0.09
	droplet.material = blood_material
	particles.mesh = droplet
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.8).timeout.connect(particles.queue_free)
	create_blood_stain(Vector3(death_position.x, 0.025, death_position.z), enemy_kind)

func create_blood_stain(floor_position:Vector3, enemy_kind:String) -> void:
	var stain := Node3D.new()
	stain.name = "PersistentBloodStain"
	stain.position = floor_position
	stain.rotation.y = randf_range(-PI, PI)
	world_root.add_child(stain)
	var stain_scale:float = 1.0 if enemy_kind != "hound" else 0.68
	for index in 9:
		var pool := MeshInstance3D.new()
		var disk := CylinderMesh.new()
		var radius := randf_range(0.22, 0.62) * stain_scale
		disk.top_radius = radius
		disk.bottom_radius = radius * randf_range(0.88, 1.06)
		disk.height = 0.012
		disk.radial_segments = 12
		var stain_material := blood_material.duplicate() as StandardMaterial3D
		stain_material.albedo_color = Color(randf_range(0.16, 0.31), 0.002, 0.006)
		stain_material.roughness = randf_range(0.28, 0.52)
		disk.material = stain_material
		pool.mesh = disk
		pool.position = Vector3(randf_range(-0.48, 0.48), index * 0.0015, randf_range(-0.48, 0.48)) * stain_scale
		pool.scale.z = randf_range(0.45, 1.0)
		stain.add_child(pool)

func on_player_caught(infected:DungeonInfected) -> void:
	if Global.debug_dungeon_invincible:
		return
	if !sequence_running:
		restart_after_caught(infected)

func restart_after_caught(infected:DungeonInfected) -> void:
	sequence_running = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	
	# Som de sangue e dano forte
	var hit_sfx := AudioStreamPlayer.new()
	hit_sfx.stream = load("res://assets/novos_audios/sangue_fill_effect.mp3")
	hit_sfx.volume_db = 0.0
	add_child(hit_sfx)
	hit_sfx.play()

	var is_hound: bool = is_instance_valid(infected) && infected.enemy_kind == "hound"
	
	if is_instance_valid(infected):
		infected.set_physics_process(false)
		if is_hound:
			# Rato pula na altura da câmera atacando
			infected.global_position = player.global_position + player.camera_forward() * 0.95 + Vector3(0, 0.45, 0)
			player.shake_camera(0.1, 0.85)
		else:
			# Humanoide / mutante: aproxima de frente e estica as mãos na direção do jogador
			infected.global_position = player.global_position + player.camera_forward() * 1.15
			player.shake_camera(0.07, 0.8)
			
	# Espirros de sangue 3D finos
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.4)
	
	# Manchas orgânicas cobrem a tela com fade suave
	blood_overlay.visible = true
	for child in blood_overlay.get_children():
		child.modulate.a = 0.0
		create_tween().tween_property(child, "modulate:a", randf_range(0.65, 0.95), randf_range(0.06, 0.28)).set_delay(randf_range(0.0, 0.35))
		
	await get_tree().create_timer(1.15).timeout
	fade_overlay.visible = true
	fade_overlay.color = Color(0.12, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1.0, 0.75).finished
	get_tree().reload_current_scene()

func spawn_blood_spurt(origin_pos:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = origin_pos
	particles.amount = 75
	particles.lifetime = 0.75
	particles.one_shot = true
	particles.explosiveness = 0.98
	particles.direction = -player.camera_forward() + Vector3(0, 0.4, 0)
	particles.spread = 75.0
	particles.initial_velocity_min = 2.5
	particles.initial_velocity_max = 7.0
	particles.gravity = Vector3(0, -9.8, 0)
	
	# Gotículas finas alongadas, sem cubos nem malhas geométricas
	var droplet := SphereMesh.new()
	droplet.radius = 0.016
	droplet.height = 0.045
	droplet.material = blood_material
	particles.mesh = droplet
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)

func on_infected_died(infected:DungeonInfected) -> void:
	enemies.erase(infected)
	for stage in stage_enemies:
		stage_enemies[stage].erase(infected)

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
	await create_tween().tween_property(player.head, "rotation:x", -0.45, 0.45).finished
	var jump := create_tween().set_trans(Tween.TRANS_QUAD)
	jump.tween_property(player, "position:y", 7.5, 0.75).set_ease(Tween.EASE_OUT)
	jump.parallel().tween_property(player, "position:z", trampoline.position.z, 0.75)
	await get_tree().create_timer(0.35).timeout
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1, 0.8).finished
	Global.dungeon_return_pending = true
	Global.back_to_fase = false
	Global.save_progress("fase_1_castle_2")
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")
