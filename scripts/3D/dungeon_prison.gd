extends Node3D

const PLAYER_SCENE:PackedScene = preload("res://scenes/3D/dungeon_player.tscn")
const MAYCON_SCENE = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const MAYCON_MENU_ANIMATIONS = preload("res://assets/novas_imagens/3d_enemies/menu_maycon_animations.res")
const ZOMBIE_MODEL := "res://assets/horror_creatures/infected_zombie_animated.glb"
const RUNNER_MODEL := "res://assets/horror_creatures/horror_runner.glb"
const HOUND_MODEL := "res://assets/horror_creatures/plague_hound.glb"
const FALL_IMPACT_SOUND := preload("res://assets/novos_audios/maycon_platform_landing.mp3")
const DUST_TEXTURE := preload("res://assets/novas_imagens/effects/dust_puff.png")
const SERVICE_PISTOL_PATH := "res://assets/modelo_3d/calabouco/service_pistol_4k.glb"
const SMG_PATH := "res://assets/modelo_3d/calabouco/SMG.fbx"
const SMG_ALBEDO:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_BaseColor.png")
const SMG_NORMAL:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Normal.png")
const SMG_METALLIC:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Metallic.png")
const SMG_ROUGHNESS:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Roughness.png")

var player:DungeonPlayer
var main_monster:DungeonMainMonster
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
var ammo_label:Label
var crosshair_label:Label
var sprint_hud:Control
var sprint_rb_icon:Sprite2D
var sprint_shift_icon:Sprite2D
var status_hud:Control
var health_bar:ProgressBar
var health_label:Label
var stamina_bar:ProgressBar
var stamina_label:Label
var last_player_hp:float = 100.0
var life_shake_tween:Tween
var life_bleed_tween:Tween
var notice_label:Label
var notice_timer:float = 0.0
var active_ammo_drops:Array[Node3D] = []
var fade_overlay:ColorRect
var blood_overlay:Control
var inventory_bar:HBoxContainer
var ambience:AudioStreamPlayer
var gun_sound:AudioStreamPlayer
var pickup_sound:AudioStreamPlayer
var gate_sound:AudioStreamPlayer3D
var gate_iron_sound:AudioStreamPlayer3D
var gate_squeaky_sound:AudioStreamPlayer3D
var gate_heavy_sound:AudioStreamPlayer3D
var gate_unlock_sound:AudioStreamPlayer3D
var zombie_grab_sound:AudioStreamPlayer
var monster_damage_sound:AudioStreamPlayer
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
var main_monster_grab_active:bool = false
var main_monster_grab_anchor:Marker3D
var main_monster_grabber:DungeonMainMonster
var monster_damage_serial:int = 0
var giant_zombies:Array[DungeonGiantZombie] = []
var giant_grab_active:bool = false
var giant_grab_anchor:Marker3D
var giant_grabber:DungeonGiantZombie
var infected_grab_active:bool = false
var infected_grab_anchor:Marker3D
var infected_grabber:DungeonInfected

func _ready() -> void:
	get_tree().paused = false
	GameSongs.stop(1)
	build_materials()
	build_environment()
	build_prison()
	build_player()
	build_pickups()
	# Cutscene em primeira pessoa do machado caindo do teto e escorregando até a cela.mud
	# Roda logo após o machado cair no buraco em fase_1_castle_2 e depois volta para lá.
	if Global.axe_cutscene_pending:
		Global.axe_cutscene_pending = false
		build_cutscene_overlay()
		start_axe_drop_cutscene()
		return
	build_infected_population()
	build_main_monster()
	build_giant_zombies()
	build_hud()
	build_audio()
	apply_saved_state()
	Global.save_progress("calabouco_terror")
	if !event_is_true("dungeon_intro_cutscene_seen"):
		start_intro_cutscene()
	else:
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
	blood_material = colored_material(Color(0.34, 0.004, 0.006), 0.0, 0.22)
	blood_material.clearcoat_enabled = true
	blood_material.clearcoat = 0.85
	blood_material.clearcoat_roughness = 0.15
	flesh_material = colored_material(Color(0.3, 0.18, 0.13), 0.0, 0.94)

func colored_material(color:Color, metallic:float, roughness:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

func build_environment() -> void:
	if has_node("PrisonArchitecture"):
		world_root = get_node("PrisonArchitecture") as Node3D
		return
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
	if is_instance_valid(world_root) and world_root.get_child_count() > 0:
		wire_existing_prison()
		return
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
	create_box("EntranceSouthWall", Vector3(0, 2.15, 6), Vector3(22.6, 4.8, 0.6), stone_material, true, world_root)
	route_gates["blue"] = build_gate("BlueRouteGate", Vector3(17.7, 0, -94), 12.2, "x", Color(0.08, 0.3, 1))
	route_gates["red"] = build_gate("RedRouteGate", Vector3(-7, 0, -107.7), 10.2, "z", Color(1, 0.035, 0.02))
	route_gates["green"] = build_gate("GreenRouteGate", Vector3(7, 0, -107.7), 10.2, "z", Color(0.04, 1, 0.2))
	build_key_rooms()
	build_debris()
	for fixture in [Vector3(0, 4.15, -8), Vector3(0, 4.15, -36), Vector3(0, 4.15, -70), Vector3(-35, 4.15, -94), Vector3(-56, 4.15, -118), Vector3(35, 4.15, -94), Vector3(56, 4.15, -118), Vector3(-30, 4.15, -164), Vector3(30, 4.15, -164)]:
		build_flickering_fixture(fixture, int(absf(fixture.x + fixture.z)))

func wire_existing_prison() -> void:
	# Portões principais (Route Gates)
	route_gates["blue"] = find_child("BlueRouteGate", true, false)
	route_gates["red"] = find_child("RedRouteGate", true, false)
	route_gates["green"] = find_child("GreenRouteGate", true, false)
	
	# Portões das salas das chaves
	key_room_doors["intro"] = find_child("BlueKeyRoom", true, false)
	if is_instance_valid(key_room_doors["intro"]):
		key_room_doors["intro"].set_meta("is_key_room", true)
	key_room_doors["blue"] = find_child("RedKeyRoom", true, false)
	if is_instance_valid(key_room_doors["blue"]):
		key_room_doors["blue"].set_meta("is_key_room", true)
	key_room_doors["red"] = find_child("GreenKeyRoom", true, false)
	if is_instance_valid(key_room_doors["red"]):
		key_room_doors["red"].set_meta("is_key_room", true)
	key_room_doors["green"] = find_child("FinalKeyRoom", true, false)
	if is_instance_valid(key_room_doors["green"]):
		key_room_doors["green"].set_meta("is_key_room", true)
	
	# Alavancas
	levers["intro"] = find_child("Lever_intro", true, false)
	levers["blue"] = find_child("Lever_blue", true, false)
	levers["red"] = find_child("Lever_red", true, false)
	levers["green"] = find_child("Lever_green", true, false)
	for k in levers.keys():
		var lever: Node3D = levers[k]
		if is_instance_valid(lever):
			var hinge := lever.find_child("Hinge", true, false)
			if hinge:
				lever.set_meta("handle", hinge)
	
	# Portas de cela (stage_doors)
	for s in ["intro", "blue", "red", "green"]:
		stage_doors[s].clear()
	for child in world_root.get_children():
		var cname := child.name
		if cname.begins_with("Cell_"):
			for stage in ["intro", "blue", "red", "green"]:
				if cname.begins_with("Cell_" + stage):
					stage_doors[stage].append(child)
					break

	# Lâmpadas piscantes
	flicker_lights.clear()
	for fixture in world_root.find_children("BrokenFixture*", "Node3D", true, false):
		var light := fixture.find_child("OmniLight3D", true, false) as OmniLight3D
		if light:
			var seed_val := int(absf(fixture.position.x + fixture.position.z))
			flicker_lights.append({"light": light, "base": light.light_energy, "phase": seed_val * 0.31})

	# Spawns de inimigos nas celas e esconderijos
	populate_hiding_zones_and_spawns()

func populate_hiding_zones_and_spawns() -> void:
	hiding_zones.clear()
	enemy_spawns.clear()
	auto_release_assigned = false
	for z in [-11.0, -25.0, -39.0, -53.0, -67.0]:
		if z != -11.0:
			register_cell_record(0, -1, z, "intro", z == -25.0)
		register_cell_record(0, 1, z, "intro", z == -53.0)
	for z in [-106.0, -121.0]:
		register_cell_record(-56, -1, z, "intro", z == -121.0)
		register_cell_record(-56, 1, z, "intro", false)
		register_cell_record(56, -1, z, "blue", false)
		register_cell_record(56, 1, z, "blue", z == -106.0)
	for x in [-43.0, -28.0]:
		register_cell_record_x(x, -164, -1, "red", false)
		register_cell_record_x(x, -164, 1, "red", x == -28.0)
	for x in [28.0, 43.0]:
		register_cell_record_x(x, -164, -1, "green", x == 28.0)
		register_cell_record_x(x, -164, 1, "green", false)

func register_cell_record(corridor_x: float, side: int, z: float, stage: String, empty: bool) -> void:
	var center_x := corridor_x + side * 8.0
	var front_x := corridor_x + side * 5.25
	var door_name := "Cell_%s_%s" % [stage, str(z)]
	var door := find_child(door_name, true, false) as Node3D
	if empty:
		hiding_zones.append(AABB(Vector3(minf(front_x, center_x) - 0.5, -0.2, z - 3), Vector3(absf(center_x - front_x) + 1, 2.8, 6)))
	elif door != null:
		spawn_record(Vector3(center_x, 0, z), stage, door)

func register_cell_record_x(x: float, corridor_z: float, side: int, stage: String, empty: bool) -> void:
	var center_z := corridor_z + side * 8.0
	var front_z := corridor_z + side * 5.25
	var door_name := "Cell_%s_%s" % [stage, str(x)]
	var door := find_child(door_name, true, false) as Node3D
	if empty:
		hiding_zones.append(AABB(Vector3(x - 3, -0.2, minf(front_z, center_z) - 0.5), Vector3(6, 2.8, absf(center_z - front_z) + 1)))
	elif door != null:
		spawn_record(Vector3(x, 0, center_z), stage, door)

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
	if prefix == "Entrance":
		build_entrance_ceiling_hole(x, z, width, length)
	else:
		create_box(prefix + "Ceiling", Vector3(x, 4.6, z), Vector3(width, 0.45, length), stone_material, true, world_root)
	create_box(prefix + "LeftWall", Vector3(x - width * 0.5, 2.15, z), Vector3(0.6, 4.8, length), stone_material, true, world_root)
	create_box(prefix + "RightWall", Vector3(x + width * 0.5, 2.15, z), Vector3(0.6, 4.8, length), stone_material, true, world_root)

func build_entrance_ceiling_hole(x:float, z:float, width:float, length:float) -> void:
	var hole_center_z:float = 3.5
	var hole_width:float = 5.6
	var hole_length:float = 5.0
	var side_width:float = (width - hole_width) * 0.5
	var side_offset:float = hole_width * 0.5 + side_width * 0.5
	create_box("EntranceCeilingLeft", Vector3(x - side_offset, 4.6, z), Vector3(side_width, 0.45, length), stone_material, true, world_root)
	create_box("EntranceCeilingRight", Vector3(x + side_offset, 4.6, z), Vector3(side_width, 0.45, length), stone_material, true, world_root)
	var corridor_min_z:float = z - length * 0.5
	var hole_min_z:float = hole_center_z - hole_length * 0.5
	var back_length:float = hole_min_z - corridor_min_z
	create_box("EntranceCeilingBack", Vector3(x, 4.6, corridor_min_z + back_length * 0.5), Vector3(hole_width, 0.45, back_length), stone_material, true, world_root)
	build_trampoline_shaft(Vector3(x, 4.6, hole_center_z), hole_width, hole_length)

func build_trampoline_shaft(hole_center:Vector3, hole_width:float, hole_length:float) -> void:
	var shaft_height:float = 6.2
	var shaft_center_y:float = hole_center.y + shaft_height * 0.5
	create_box("TrampolineShaftLeft", Vector3(hole_center.x - hole_width * 0.5, shaft_center_y, hole_center.z), Vector3(0.4, shaft_height, hole_length), stone_material, true, world_root)
	create_box("TrampolineShaftRight", Vector3(hole_center.x + hole_width * 0.5, shaft_center_y, hole_center.z), Vector3(0.4, shaft_height, hole_length), stone_material, true, world_root)
	create_box("TrampolineShaftBack", Vector3(hole_center.x, shaft_center_y, hole_center.z - hole_length * 0.5), Vector3(hole_width, shaft_height, 0.4), stone_material, true, world_root)
	create_box("TrampolineShaftFront", Vector3(hole_center.x, shaft_center_y, hole_center.z + hole_length * 0.5), Vector3(hole_width, shaft_height, 0.4), stone_material, true, world_root)
	var void_material := colored_material(Color(0.0005, 0.0005, 0.001), 0.0, 1.0)
	void_material.emission_enabled = true
	void_material.emission = Color(0.0002, 0.0002, 0.0005)
	create_box("TrampolineShaftDarkness", Vector3(hole_center.x, hole_center.y + shaft_height + 0.05, hole_center.z), Vector3(hole_width - 0.35, 0.1, hole_length - 0.35), void_material, false, world_root)
	for rim in [
		[Vector3(hole_center.x - hole_width * 0.5, hole_center.y, hole_center.z), Vector3(0.5, 0.32, hole_length + 0.5)],
		[Vector3(hole_center.x + hole_width * 0.5, hole_center.y, hole_center.z), Vector3(0.5, 0.32, hole_length + 0.5)],
		[Vector3(hole_center.x, hole_center.y, hole_center.z - hole_length * 0.5), Vector3(hole_width + 0.5, 0.32, 0.5)],
		[Vector3(hole_center.x, hole_center.y, hole_center.z + hole_length * 0.5), Vector3(hole_width + 0.5, 0.32, 0.5)]
	]:
		create_box("BrokenHoleRim", rim[0], rim[1], stone_material, true, world_root)

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
	var door := build_gate("Cell_%s_%s" % [stage, str(z)], Vector3(front_x, 0, z), 7.0, "x", Color(0.32, 0.09, 0.05), false)
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
	var door := build_gate("Cell_%s_%s" % [stage, str(x)], Vector3(x, 0, front_z), 7.0, "z", Color(0.32, 0.09, 0.05), false)
	if empty:
		hiding_zones.append(AABB(Vector3(x - 3, -0.2, minf(front_z, center_z) - 0.5), Vector3(6, 2.8, absf(center_z - front_z) + 1)))
		create_box("CellCover", Vector3(x, 0.8, center_z), Vector3(2.4, 1.6, 1.8), rotten_material, true, world_root)
	else:
		stage_doors[stage].append(door)
		spawn_record(Vector3(x, 0, center_z), stage, door)

func build_key_rooms() -> void:
	# --- 1. ALA INTRO (Caminho aberto do início: contém a Chave Azul) ---
	# Fundo do corredor OpenWing (z = -144) com uma ABERTURA por onde o zumbi gigante
	# do lado de fora do mapa espreita para dentro.
	build_giant_opening_z("OpenWingEndWall", -56, -144, 22.6)
	# Paredes da divisória frontal (z = -135) que selam de parede a parede
	create_box("OpenWingGateWallL", Vector3(-63.5, 2.15, -135), Vector3(7.2, 4.8, 0.6), stone_material, true, world_root)
	create_box("OpenWingGateWallR", Vector3(-48.5, 2.15, -135), Vector3(7.2, 4.8, 0.6), stone_material, true, world_root)
	# Grade central azulada (tranca a sala onde fica a Chave Azul)
	key_room_doors["intro"] = build_gate("BlueKeyRoom", Vector3(-56, 0, -135), 8.2, "z", Color(0.15, 0.45, 1.0))
	key_room_doors["intro"].set_meta("is_key_room", true)
	# Alavanca na frente da grade, apoiada no chão
	levers["intro"] = build_lever(Vector3(-50.5, 0, -132.5), "intro", 0.0)

	# --- 2. ALA AZUL (Portão Azul no Hub: contém a Chave Vermelha) ---
	# Fundo do corredor BlueWing (z = -144) com ABERTURA para o segundo zumbi gigante.
	build_giant_opening_z("BlueWingEndWall", 56, -144, 22.6)
	# Paredes da divisória frontal (z = -135)
	create_box("BlueWingGateWallL", Vector3(48.5, 2.15, -135), Vector3(7.2, 4.8, 0.6), stone_material, true, world_root)
	create_box("BlueWingGateWallR", Vector3(63.5, 2.15, -135), Vector3(7.2, 4.8, 0.6), stone_material, true, world_root)
	# Grade central vermelha (tranca a sala onde fica a Chave Vermelha)
	key_room_doors["blue"] = build_gate("RedKeyRoom", Vector3(56, 0, -135), 8.2, "z", Color(1.0, 0.05, 0.02))
	key_room_doors["blue"].set_meta("is_key_room", true)
	# Alavanca na frente da grade, apoiada no chão
	levers["blue"] = build_lever(Vector3(50.5, 0, -132.5), "blue", 0.0)

	# --- 3. ALA VERMELHA (Portão Vermelho no Hub: contém a Chave Verde) ---
	# Fechamento do fundo oeste do corredor RedWing (x = -53)
	create_box("RedWingEndWall", Vector3(-53, 2.15, -164), Vector3(0.6, 4.8, 22.6), stone_material, true, world_root)
	# Paredes da divisória frontal (x = -45)
	create_box("RedWingGateWallN", Vector3(-45, 2.15, -171.5), Vector3(0.6, 4.8, 7.2), stone_material, true, world_root)
	create_box("RedWingGateWallS", Vector3(-45, 2.15, -156.5), Vector3(0.6, 4.8, 7.2), stone_material, true, world_root)
	# Grade central verde (tranca a sala onde fica a Chave Verde)
	key_room_doors["red"] = build_gate("GreenKeyRoom", Vector3(-45, 0, -164), 8.2, "x", Color(0.05, 1.0, 0.2))
	key_room_doors["red"].set_meta("is_key_room", true)
	# Alavanca na frente da grade, apoiada no chão
	levers["red"] = build_lever(Vector3(-42.5, 0, -158.5), "red", PI * 0.5)

	# --- 4. ALA VERDE (Portão Verde no Hub: contém a Chave da Cela do Machado) ---
	# Fechamento do fundo leste do corredor GreenWing (x = 53)
	create_box("GreenWingEndWall", Vector3(53, 2.15, -164), Vector3(0.6, 4.8, 22.6), stone_material, true, world_root)
	# Paredes da divisória frontal (x = 45)
	create_box("GreenWingGateWallN", Vector3(45, 2.15, -171.5), Vector3(0.6, 4.8, 7.2), stone_material, true, world_root)
	create_box("GreenWingGateWallS", Vector3(45, 2.15, -156.5), Vector3(0.6, 4.8, 7.2), stone_material, true, world_root)
	# Grade central (tranca a sala onde fica a Chave da Cela)
	key_room_doors["green"] = build_gate("FinalKeyRoom", Vector3(45, 0, -164), 8.2, "x", Color(0.9, 0.8, 0.52))
	key_room_doors["green"].set_meta("is_key_room", true)
	# Alavanca na frente da grade, apoiada no chão
	levers["green"] = build_lever(Vector3(42.5, 0, -158.5), "green", -PI * 0.5)

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

func build_lever(position_value:Vector3, stage:String, rotation_y:float = 0.0) -> Node3D:
	var lever := Node3D.new()
	lever.name = "Lever_" + stage
	lever.position = position_value
	lever.rotation.y = rotation_y
	world_root.add_child(lever)
	# Base de 1m de altura apoiada firmemente no chão (centro em Y = 0.5)
	create_box("Base", Vector3(0, 0.5, 0), Vector3(0.65, 1.0, 0.35), iron_material, false, lever)
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0, 0.95, 0) # Ponto de articulação no topo da base
	lever.add_child(hinge)
	create_box("Handle", Vector3(0, 0.45, 0), Vector3(0.14, 0.9, 0.14), rotten_material, false, hinge)
	hinge.rotation.x = -0.55
	lever.set_meta("handle", hinge)
	build_light(Vector3(0, 1.1, 0.35), Color(1, 0.5, 0.04), 2.4, 4, lever)
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
	var spawn_pos := Vector3(0, 8, 3.2)
	var spawn_rot := Vector3.ZERO
	var spawn_marker := find_child("PlayerSpawn", true, false) as Marker3D
	if spawn_marker:
		spawn_pos = spawn_marker.position
		spawn_rot = spawn_marker.rotation
	player = PLAYER_SCENE.instantiate() as DungeonPlayer
	player.name = "DungeonPlayer"
	player.position = spawn_pos
	player.rotation = spawn_rot
	add_child(player)
	player.interact_pressed.connect(on_interact_pressed)
	player.fired.connect(on_player_fired)
	player.flashlight_toggled.connect(func(_enabled:bool): update_hud())

func build_pickups() -> void:
	if find_child("AxeCellDoor", true, false) != null or find_child("FlashlightPickup", true, false) != null:
		wire_existing_pickups()
		return
	pickups["flashlight"] = build_flashlight(Vector3(0.2, 0.45, -2.5))

	# TESTE: duas armas extras logo no início da fase para validar as mãos do modelo 3D.
	# Não substituem as armas originais (que continuam nos corredores).
	pickups["pistol_test"] = build_gun(Vector3(-1.4, 0.62, -2.2), false, "PistolTestPickup")
	pickups["machinegun_test"] = build_gun(Vector3(1.4, 0.62, -2.2), true, "MachinegunTestPickup")

	# Caminho aberto de início (OpenWing): pistola no corredor e chave azul dentro da cela
	pickups["pistol"] = build_gun(Vector3(-56.0, 0.62, -125.0), false, "PistolPickup")
	pickups["blue_key"] = build_key(Vector3(-56.0, 0.65, -140.0), Color(0.12, 0.4, 1.0), "BlueKey")

	# Passagem azul (BlueWing): chave vermelha dentro da cela
	pickups["red_key"] = build_key(Vector3(56.0, 0.65, -140.0), Color(1.0, 0.05, 0.02), "RedKey")

	# Passagem vermelha (RedWing): metralhadora no corredor e chave verde dentro da cela
	pickups["machinegun"] = build_gun(Vector3(-32.0, 0.62, -164.0), true, "SMGPickup")
	pickups["green_key"] = build_key(Vector3(-49.5, 0.65, -164.0), Color(0.05, 1.0, 0.2), "GreenKey")

	# Passagem verde (GreenWing): chave da cela do machado dentro da cela
	pickups["cell_key"] = build_key(Vector3(49.5, 0.65, -164.0), Color(0.9, 0.8, 0.52), "CellKey")

	axe_door = build_gate("AxeCellDoor", Vector3(-5.25, 0, -7), 7.0, "x", Color(0.95, 0.02, 0.01))
	axe_pickup = build_axe(Vector3(-8.2, 0.72, -7))
	trampoline = Node3D.new()
	trampoline.name = "Trampoline"
	trampoline.position = Vector3(0, 0, 3.5)
	world_root.add_child(trampoline)
	instantiate_model("res://assets/kenney/platformer_3d/spring.glb", Vector3.ZERO, Vector3.ONE * 1.8, trampoline)
	build_light(Vector3(0, 0.7, 0), Color(0.15, 0.45, 1), 2.8, 5, trampoline)

func wire_existing_pickups() -> void:
	pickups["flashlight"] = find_child("FlashlightPickup", true, false)
	pickups["pistol_test"] = find_child("PistolTestPickup", true, false)
	pickups["machinegun_test"] = find_child("MachinegunTestPickup", true, false)
	pickups["pistol"] = find_child("PistolPickup", true, false)
	if pickups["pistol"] == null:
		pickups["pistol"] = find_child("ServicePistolPickup", true, false)
	pickups["blue_key"] = find_child("BlueKey", true, false)
	pickups["red_key"] = find_child("RedKey", true, false)
	pickups["machinegun"] = find_child("SMGPickup", true, false)
	pickups["green_key"] = find_child("GreenKey", true, false)
	pickups["cell_key"] = find_child("CellKey", true, false)
	axe_door = find_child("AxeCellDoor", true, false)
	axe_pickup = find_child("AxePickup", true, false)
	trampoline = find_child("Trampoline", true, false)

func build_flashlight(position_value:Vector3) -> Node3D:
	var pickup := Node3D.new()
	pickup.name = "FlashlightPickup"
	pickup.position = position_value
	world_root.add_child(pickup)
	instantiate_model("res://assets/kenney/graveyard_kit/lantern-glass.glb", Vector3.ZERO, Vector3.ONE * 1.7, pickup)
	build_light(Vector3.ZERO, Color(0.72, 0.86, 1), 3, 4, pickup)
	return pickup

func build_gun(position_value:Vector3, machinegun:bool, custom_name:String = "") -> Node3D:
	var gun := Node3D.new()
	gun.name = custom_name if custom_name != "" else ("SMGPickup" if machinegun else "ServicePistolPickup")
	gun.position = position_value
	world_root.add_child(gun)
	var model := instantiate_model(SMG_PATH if machinegun else SERVICE_PISTOL_PATH, Vector3.ZERO, Vector3.ONE * (0.95 if machinegun else 2.15), gun)
	if is_instance_valid(model):
		model.rotation.y = PI if machinegun else PI * 0.5
		if machinegun:
			apply_pickup_smg_material(model)
		else:
			for node_name in ["service_pistol_bullet", "service_pistol_magazine_loaded"]:
				var loose_part := model.find_child(node_name, true, false) as Node3D
				if is_instance_valid(loose_part):
					loose_part.visible = false
	build_light(Vector3(0, 0.3, 0), Color(1, 0.48, 0.08), 3, 4.5, gun)
	return gun

func apply_pickup_smg_material(model:Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = SMG_ALBEDO
	material.normal_enabled = true
	material.normal_texture = SMG_NORMAL
	material.metallic = 1.0
	material.metallic_texture = SMG_METALLIC
	material.roughness = 1.0
	material.roughness_texture = SMG_ROUGHNESS
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material

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
	axe.name = "AxePickup"
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
	var variant := {"path": ZOMBIE_MODEL, "kind": "zombie", "scale": 1.35}
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

func build_main_monster() -> void:
	var existing = find_child("AnimMonsterStalker", true, false) as DungeonMainMonster
	if existing != null:
		main_monster = existing
		main_monster.setup(player, self)
		return
	main_monster = DungeonMainMonster.new()
	main_monster.name = "AnimMonsterStalker"
	main_monster.position = Vector3(0, 0.05, -91)
	add_child(main_monster)
	main_monster.setup(player, self)

func build_giant_opening_z(node_name:String, center_x:float, z:float, total_width:float) -> void:
	# Constrói o fundo de um corredor (parede em Z) com uma grande ABERTURA central por
	# onde o zumbi gigante, do lado de fora do mapa, espreita para dentro. Além da
	# abertura fica um fundo escuro (void) para o gigante emergir da escuridão.
	var gap := 11.0
	var side := (total_width - gap) * 0.5
	var side_off := gap * 0.5 + side * 0.5
	create_box(node_name + "L", Vector3(center_x - side_off, 2.15, z), Vector3(side, 4.8, 0.6), stone_material, true, world_root)
	create_box(node_name + "R", Vector3(center_x + side_off, 2.15, z), Vector3(side, 4.8, 0.6), stone_material, true, world_root)
	create_box(node_name + "Top", Vector3(center_x, 4.4, z), Vector3(gap, 0.45, 0.6), stone_material, true, world_root)
	var void_mat := colored_material(Color(0.0006, 0.0006, 0.0012), 0.0, 1.0)
	create_box(node_name + "Void", Vector3(center_x, 3.0, z - 7.0), Vector3(total_width + 8.0, 13.0, 0.5), void_mat, false, world_root)
	create_box(node_name + "VoidFloor", Vector3(center_x, -1.5, z - 3.6), Vector3(total_width + 8.0, 0.5, 7.0), void_mat, false, world_root)

func build_giant_zombies() -> void:
	giant_zombies.clear()
	var found_giants = find_children("*", "DungeonGiantZombie", true, false)
	if not found_giants.is_empty():
		for g in found_giants:
			var giant := g as DungeonGiantZombie
			giant.setup(player, self)
			giant_zombies.append(giant)
		return

	# Fallback se não existirem zumbis gigantes na cena:
	var configs := [
		{
			"body_pos": Vector3(-56, -1.2, -147.5),
			"face_dir": Vector3(0, 0, 1),
			"zone_center": Vector3(-56, 0, -140),
			"zone_half": Vector3(6, 3, 5.5),
			"scale": 3.0
		},
		{
			"body_pos": Vector3(56, -1.2, -147.5),
			"face_dir": Vector3(0, 0, 1),
			"zone_center": Vector3(56, 0, -140),
			"zone_half": Vector3(6, 3, 5.5),
			"scale": 3.0
		}
	]
	for i in configs.size():
		var giant := DungeonGiantZombie.new()
		giant.name = "GiantZombie_%d" % i
		add_child(giant)
		giant.setup(player, self, configs[i])
		giant_zombies.append(giant)

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
	objective_label.visible = false
	hud.add_child(objective_label)
	help_label = make_label(17, Color(0.65, 0.72, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	help_label.position = Vector2(28, 58)
	help_label.size = Vector2(940, 35)
	help_label.text = tr("DUNGEON_MOVE_HINT")
	help_label.visible = false
	hud.add_child(help_label)
	flashlight_label = make_label(18, Color(0.7, 0.84, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	flashlight_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	flashlight_label.position = Vector2(-510, 28)
	flashlight_label.size = Vector2(480, 35)
	flashlight_label.visible = false
	hud.add_child(flashlight_label)
	weapon_label = make_label(18, Color(1, 0.62, 0.26), HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	weapon_label.position = Vector2(-510, 64)
	weapon_label.size = Vector2(480, 35)
	weapon_label.visible = false
	hud.add_child(weapon_label)
	prompt_label = make_label(24, Color(0.95, 0.86, 0.52), HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-550, -112)
	prompt_label.size = Vector2(1100, 44)
	hud.add_child(prompt_label)
	
	ammo_label = make_label(18, Color(1, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-340, -128)
	ammo_label.size = Vector2(315, 48)
	var ammo_panel := StyleBoxFlat.new()
	ammo_panel.bg_color = Color(0.015, 0.025, 0.03, 0.88)
	ammo_panel.border_color = Color(0.85, 0.68, 0.25, 0.8)
	ammo_panel.set_border_width_all(2)
	ammo_panel.set_corner_radius_all(6)
	ammo_label.add_theme_stylebox_override("normal", ammo_panel)
	ammo_label.visible = false
	hud.add_child(ammo_label)
	
	# HUD de comando para correr (padrão cena cidade perdida: RB / Shift no canto inferior direito)
	sprint_hud = Control.new()
	sprint_hud.name = "SprintHUD"
	sprint_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint_hud.position = Vector2(-225, -68)
	sprint_hud.size = Vector2(200, 52)
	hud.add_child(sprint_hud)
	
	var sprint_panel := Panel.new()
	sprint_panel.size = Vector2(200, 52)
	var sp_box := StyleBoxFlat.new()
	sp_box.bg_color = Color(0.015, 0.025, 0.03, 0.82)
	sp_box.border_color = Color(0.42, 0.48, 0.54, 0.7)
	sp_box.set_border_width_all(1)
	sp_box.set_corner_radius_all(6)
	sprint_panel.add_theme_stylebox_override("panel", sp_box)
	sprint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprint_hud.add_child(sprint_panel)
	
	sprint_rb_icon = Sprite2D.new()
	sprint_rb_icon.texture = load("res://assets/novas_imagens/buttons/rb_xbox.png")
	sprint_rb_icon.scale = Vector2(0.44, 0.40)
	sprint_rb_icon.position = Vector2(30, 26)
	sprint_rb_icon.rotation = 0.22
	sprint_rb_icon.self_modulate = Color(1.0, 1.0, 1.0, 0.84)
	sprint_hud.add_child(sprint_rb_icon)
	
	var slash_sep := make_label(16, Color(0.65, 0.72, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	slash_sep.position = Vector2(58, 12)
	slash_sep.size = Vector2(16, 28)
	slash_sep.text = "/"
	sprint_hud.add_child(slash_sep)
	
	sprint_shift_icon = Sprite2D.new()
	sprint_shift_icon.texture = load("res://assets/novas_imagens/buttons/shift_dark.png")
	sprint_shift_icon.scale = Vector2(0.52, 0.44)
	sprint_shift_icon.position = Vector2(98, 26)
	sprint_shift_icon.self_modulate = Color(1.0, 1.0, 1.0, 0.61)
	sprint_hud.add_child(sprint_shift_icon)
	
	var sprint_title := make_label(16, Color(0.9, 0.94, 0.98, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	sprint_title.position = Vector2(132, 14)
	sprint_title.size = Vector2(65, 26)
	sprint_title.text = tr("DUNGEON_RUN_ACTION")
	sprint_hud.add_child(sprint_title)
	
	notice_label = make_label(22, Color(1.0, 0.92, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	notice_label.set_anchors_preset(Control.PRESET_CENTER)
	notice_label.position = Vector2(-320, 80)
	notice_label.size = Vector2(640, 44)
	notice_label.visible = false
	hud.add_child(notice_label)
	
	player.ammo_changed.connect(func(_c:int, _r:int, _w:String): update_hud())
	player.reload_started.connect(func(): update_hud())
	player.reload_finished.connect(func(): update_hud())
	
	crosshair_label = make_label(24, Color(0.9, 0.92, 0.9, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	crosshair_label.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_label.position = Vector2(-20, -22)
	crosshair_label.size = Vector2(40, 40)
	crosshair_label.text = "+"
	crosshair_label.visible = false
	hud.add_child(crosshair_label)
	build_inventory_hud(hud)
	build_status_hud(hud)
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

func show_pickup_notice(text_msg:String) -> void:
	if !is_instance_valid(notice_label):
		return
	notice_label.text = text_msg
	notice_label.visible = true
	notice_label.modulate.a = 1.0
	notice_label.scale = Vector2(1.2, 1.2)
	notice_label.pivot_offset = notice_label.size * 0.5
	var t := create_tween()
	t.tween_property(notice_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.2)
	t.tween_property(notice_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): notice_label.visible = false)

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
	inventory_bar.position = Vector2(24, -142)
	inventory_bar.size = Vector2(840, 60)
	hud.add_child(inventory_bar)
	for data in [["flashlight", "🔦", "DUNGEON_ITEM_FLASHLIGHT", Color(0.55, 0.78, 1)], ["pistol", "🔫", "DUNGEON_ITEM_PISTOL", Color(0.8, 0.65, 0.35)], ["blue_key", "🔑", "DUNGEON_ITEM_BLUE_KEY", Color(0.15, 0.35, 1)], ["red_key", "🔑", "DUNGEON_ITEM_RED_KEY", Color(1, 0.12, 0.08)], ["machinegun", "🔫", "DUNGEON_ITEM_MACHINEGUN", Color(1, 0.5, 0.08)], ["green_key", "🔑", "DUNGEON_ITEM_GREEN_KEY", Color(0.08, 1, 0.24)], ["cell_key", "🔑", "DUNGEON_ITEM_CELL_KEY", Color(0.9, 0.78, 0.48)], ["axe", "🪓", "DUNGEON_ITEM_AXE", Color(0.92, 0.15, 0.08)]]:
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

func build_status_hud(hud:CanvasLayer) -> void:
	status_hud = Control.new()
	status_hud.name = "StatusHUD"
	status_hud.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	status_hud.position = Vector2(24, -74)
	status_hud.size = Vector2(220, 52)
	hud.add_child(status_hud)
	
	# --- BARRA DE SANGUE / VIDA ---
	health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.position = Vector2(0, 0)
	health_bar.size = Vector2(220, 22)
	health_bar.show_percentage = false
	health_bar.max_value = player.max_hp
	health_bar.value = player.current_hp
	
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.014, 0.016, 0.02, 0.92)
	hp_bg.border_color = Color(0.24, 0.25, 0.28, 0.5)
	hp_bg.set_border_width_all(1)
	hp_bg.set_corner_radius_all(4)
	
	var hp_fill := StyleBoxFlat.new()
	# Vermelho escuro desaturado / vinho sóbrio (menos vibrante)
	hp_fill.bg_color = Color(0.38, 0.08, 0.10)
	hp_fill.set_corner_radius_all(3)
	
	health_bar.add_theme_stylebox_override("background", hp_bg)
	health_bar.add_theme_stylebox_override("fill", hp_fill)
	status_hud.add_child(health_bar)
	
	# Texto único no centro da barra de vida: VIDA
	health_label = make_label(11, Color(0.85, 0.82, 0.82, 0.88), HORIZONTAL_ALIGNMENT_CENTER)
	health_label.position = Vector2(0, 0)
	health_label.size = Vector2(220, 22)
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_label.text = tr("DUNGEON_HP_LABEL")
	status_hud.add_child(health_label)
	
	# Emissor de pingos de sangue ao levar dano
	var life_blood_drips := CPUParticles2D.new()
	life_blood_drips.name = "LifeBloodDrips"
	life_blood_drips.position = Vector2(110, 22)
	life_blood_drips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	life_blood_drips.emission_rect_extents = Vector2(105, 1)
	life_blood_drips.direction = Vector2(0, 1)
	life_blood_drips.spread = 12.0
	life_blood_drips.gravity = Vector2(0, 160)
	life_blood_drips.initial_velocity_min = 15.0
	life_blood_drips.initial_velocity_max = 42.0
	life_blood_drips.scale_amount_min = 2.0
	life_blood_drips.scale_amount_max = 3.5
	life_blood_drips.color = Color(0.38, 0.05, 0.07, 0.95)
	life_blood_drips.lifetime = 0.75
	life_blood_drips.emitting = false
	status_hud.add_child(life_blood_drips)
	
	# --- BARRA DE ESTAMINA ---
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	stamina_bar.position = Vector2(0, 26)
	stamina_bar.size = Vector2(220, 12)
	stamina_bar.show_percentage = false
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.current_stamina
	
	var st_bg := StyleBoxFlat.new()
	st_bg.bg_color = Color(0.012, 0.014, 0.016, 0.88)
	st_bg.border_color = Color(0.2, 0.22, 0.24, 0.42)
	st_bg.set_border_width_all(1)
	st_bg.set_corner_radius_all(3)
	
	var st_fill := StyleBoxFlat.new()
	# Verde musgo/oliva apagado e sóbrio (menos vibrante)
	st_fill.bg_color = Color(0.16, 0.32, 0.22)
	st_fill.set_corner_radius_all(2)
	
	stamina_bar.add_theme_stylebox_override("background", st_bg)
	stamina_bar.add_theme_stylebox_override("fill", st_fill)
	status_hud.add_child(stamina_bar)
	
	player.hp_changed.connect(on_player_hp_changed)
	player.stamina_changed.connect(on_player_stamina_changed)
	player.player_died.connect(func(): on_player_caught(null))

func on_player_hp_changed(current:float, max_val:float) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_val
		create_tween().tween_property(health_bar, "value", current, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(health_label):
		health_label.text = tr("DUNGEON_HP_LABEL")
	
	if current < last_player_hp:
		trigger_life_damage_fx()
	last_player_hp = current

func trigger_life_damage_fx() -> void:
	if !is_instance_valid(status_hud) || !is_instance_valid(health_bar):
		return
	var base_pos := Vector2(24, -74)
	if life_shake_tween and life_shake_tween.is_valid():
		life_shake_tween.kill()
	life_shake_tween = create_tween()
	for i in range(8):
		var offset := Vector2(randf_range(-4.5, 4.5), randf_range(-3.0, 3.0))
		life_shake_tween.tween_property(status_hud, "position", base_pos + offset, 0.035)
	life_shake_tween.tween_property(status_hud, "position", base_pos, 0.05)
	
	var blood_particles:CPUParticles2D = status_hud.get_node_or_null("LifeBloodDrips")
	if is_instance_valid(blood_particles):
		blood_particles.emitting = true
		get_tree().create_timer(1.35).timeout.connect(func():
			if is_instance_valid(blood_particles):
				blood_particles.emitting = false
		)
	
	if life_bleed_tween and life_bleed_tween.is_valid():
		life_bleed_tween.kill()
	life_bleed_tween = create_tween()
	life_bleed_tween.tween_property(health_bar, "modulate", Color(1.5, 0.45, 0.45, 1.0), 0.08)
	life_bleed_tween.tween_property(health_bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.25)

func on_player_stamina_changed(current:float, max_val:float) -> void:
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = max_val
		stamina_bar.value = current
		if current <= 0.0 or !player.can_sprint:
			stamina_bar.modulate = Color(1.0, 0.55, 0.55, 0.75)
			if is_instance_valid(sprint_hud):
				sprint_hud.modulate = Color(1.0, 0.5, 0.5, 0.6)
		else:
			stamina_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
			if is_instance_valid(sprint_hud):
				sprint_hud.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
	ambience = find_child("DungeonAmbience", true, false) as AudioStreamPlayer
	if ambience == null:
		ambience = AudioStreamPlayer.new()
		ambience.name = "DungeonAmbience"
		ambience.bus = "Master"
		var ambience_stream := load("res://assets/novos_audios/calabouco_terror/dungeon_ambience_pixabay.mp3") as AudioStreamMP3
		if ambience_stream:
			ambience_stream.loop = true
		ambience.stream = ambience_stream
		ambience.volume_db = -2.5
		ambience.autoplay = true
		ambience.finished.connect(func():
			if is_instance_valid(ambience) && is_inside_tree():
				ambience.play()
		)
		add_child(ambience)
		ambience.play()
		print("[Dungeon] Som ambiente iniciado com volume: ", ambience.volume_db, " dB (stream: ", ambience_stream, ")")
	if gun_sound == null:
		gun_sound = make_audio("res://assets/novos_audios/gun_shot.mp3", -5)
	if pickup_sound == null:
		pickup_sound = make_audio("res://assets/novos_audios/gun_load.mp3", -7)
	if monster_damage_sound == null:
		monster_damage_sound = make_audio("res://assets/novos_audios/sangue_fill_effect.mp3", -1.5)
	if gate_sound == null:
		gate_sound = AudioStreamPlayer3D.new()
		gate_sound.name = "GateSound"
		gate_sound.stream = load("res://assets/novos_audios/metal_batendo.mp3")
		gate_sound.max_distance = 30
		add_child(gate_sound)
	if gate_iron_sound == null:
		gate_iron_sound = AudioStreamPlayer3D.new()
		gate_iron_sound.name = "GateIronSound"
		gate_iron_sound.stream = load("res://assets/novos_audios/calabouco_terror/gate_opening_iron.mp3")
		gate_iron_sound.volume_db = 0.0
		gate_iron_sound.max_distance = 36
		add_child(gate_iron_sound)
	if gate_squeaky_sound == null:
		gate_squeaky_sound = AudioStreamPlayer3D.new()
		gate_squeaky_sound.name = "GateSqueakySound"
		gate_squeaky_sound.stream = load("res://assets/novos_audios/calabouco_terror/gate_squeaky.mp3")
		gate_squeaky_sound.volume_db = 1.0
		gate_squeaky_sound.max_distance = 36
		add_child(gate_squeaky_sound)
	if gate_heavy_sound == null:
		gate_heavy_sound = AudioStreamPlayer3D.new()
		gate_heavy_sound.name = "GateHeavySound"
		gate_heavy_sound.stream = load("res://assets/novos_audios/calabouco_terror/gate_opening_heavy.mp3")
		gate_heavy_sound.volume_db = 0.5
		gate_heavy_sound.max_distance = 36
		add_child(gate_heavy_sound)
	if gate_unlock_sound == null:
		gate_unlock_sound = AudioStreamPlayer3D.new()
		gate_unlock_sound.name = "GateUnlockSound"
		gate_unlock_sound.stream = load("res://assets/novos_audios/calabouco_terror/gate_unlock_heavy.mp3")
		gate_unlock_sound.volume_db = 2.0
		gate_unlock_sound.max_distance = 36
		add_child(gate_unlock_sound)
	if zombie_grab_sound == null:
		zombie_grab_sound = make_audio("res://assets/novos_audios/calabouco_terror/zombie_growl_pixabay.mp3", 1.0)

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
	else:
		player.set_weapon("")
	for data in [["flashlight", "dungeon_flashlight_taken"], ["blue_key", "dungeon_blue_key_taken"], ["pistol", "dungeon_pistol_taken"], ["red_key", "dungeon_red_key_taken"], ["green_key", "dungeon_green_key_taken"], ["cell_key", "dungeon_key_taken"], ["machinegun", "dungeon_gun_taken"]]:
		if event_is_true(data[1]) && is_instance_valid(pickups.get(data[0])):
			pickups[data[0]].queue_free()
			pickups.erase(data[0])
	for color in ["blue", "red", "green"]:
		if event_is_true("dungeon_%s_gate_open" % color) && is_instance_valid(route_gates.get(color)):
			open_door(route_gates[color], false)
	for stage in ["intro", "blue", "red", "green"]:
		if event_is_true("dungeon_%s_lever" % stage) || event_is_true("dungeon_finale_triggered"):
			activate_stage(stage, false)
	if event_is_true("dungeon_axe_door_open") || has_axe_event():
		open_door(axe_door, false)
	if has_axe_event() && is_instance_valid(axe_pickup):
		axe_pickup.queue_free()
		axe_pickup = null
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

# Overlay mínimo (só o fade) usado na cutscene do machado, sem montar o HUD de gameplay.
func build_cutscene_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "AxeCutsceneOverlay"
	add_child(layer)
	fade_overlay = ColorRect.new()
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.z_index = 100
	layer.add_child(fade_overlay)

# Cutscene em primeira pessoa: a câmera acompanha o machado caindo do teto (pelo buraco
# onde o Maycon cai), escorregando pelo chão e entrando na cela onde ele fica. No fim faz
# fade out e volta para fase_1_castle_2. O player não controla nada durante a cutscene.
func start_axe_drop_cutscene() -> void:
	sequence_running = true
	if is_instance_valid(player):
		player.controls_enabled = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.set_body_visible(false)
	# Esconde o machado estático da cela; a cutscene anima um machado dedicado idêntico
	if is_instance_valid(axe_pickup):
		axe_pickup.visible = false

	var hole_center := Vector3(0.0, 4.6, 3.5)
	var floor_landing := Vector3(0.0, 0.3, 3.4)
	var cell_rest := Vector3(-8.3, 0.2, -7.0)

	# Machado da cutscene (mesma geometria do machado da cela), começando lá no alto do buraco
	var axe := build_axe(Vector3(hole_center.x, 8.2, hole_center.z))
	axe.rotation = Vector3.ZERO

	# Câmera em primeira pessoa que acompanha o machado
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.global_position = axe.global_position + Vector3(0.0, 1.4, 1.8)
	cam.look_at(axe.global_position + Vector3(0, -1.2, -0.6), Vector3.UP)

	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 1)

	var prev_pos := axe.global_position

	# --- Fase 1: queda do teto pelo buraco onde o Maycon cai ---
	var fall := create_tween()
	fall.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(axe, "position", floor_landing, 0.75)
	fall.parallel().tween_property(axe, "rotation", Vector3(0, 0, PI * 0.5), 0.75)
	fall.parallel().tween_property(fade_overlay, "color:a", 0.0, 0.45)
	while fall.is_running():
		await get_tree().process_frame
		_follow_axe_camera(cam, axe, prev_pos, true)
		prev_pos = axe.global_position

	# Impacto no chão
	var land_sound := AudioStreamPlayer.new()
	land_sound.stream = FALL_IMPACT_SOUND
	land_sound.volume_db = 3.0
	add_child(land_sound)
	land_sound.play()
	spawn_dust_landing(Vector3(floor_landing.x, 0.05, floor_landing.z))

	# --- Fase 2: escorrega pelo chão e entra na cela onde o machado fica ---
	var slide := create_tween()
	slide.set_trans(Tween.TRANS_SINE)
	slide.tween_property(axe, "position", Vector3(-1.5, 0.22, -5.5), 0.55).set_ease(Tween.EASE_OUT)
	slide.tween_property(axe, "position", Vector3(-5.4, 0.2, -7.0), 0.4)
	slide.tween_property(axe, "position", cell_rest, 0.55).set_ease(Tween.EASE_OUT)
	while slide.is_running():
		await get_tree().process_frame
		_follow_axe_camera(cam, axe, prev_pos, false)
		prev_pos = axe.global_position

	await get_tree().create_timer(0.7).timeout

	# --- Fade out e retorno para fase_1_castle_2 de onde estava ---
	await create_tween().tween_property(fade_overlay, "color:a", 1.0, 0.8).finished
	Global.axe_cutscene_return_valid = true
	Global.dungeon_return_pending = false
	Global.back_to_fase = false
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")

func _follow_axe_camera(cam:Camera3D, axe:Node3D, prev_pos:Vector3, falling:bool) -> void:
	if !is_instance_valid(cam) || !is_instance_valid(axe):
		return
	var current := axe.global_position
	if falling:
		# POV da queda: câmera acompanha o machado de cima em 3/4, mostrando o chão que se aproxima
		cam.global_position = current + Vector3(0.0, 1.4, 1.8)
		cam.look_at(current + Vector3(0, -1.2, -0.6), Vector3.UP)
	else:
		# POV do deslize: câmera baixa, logo atrás do machado, correndo na direção do movimento
		var forward := current - prev_pos
		forward.y = 0.0
		if forward.length() < 0.001:
			forward = Vector3(0, 0, -1)
		forward = forward.normalized()
		cam.global_position = current - forward * 1.5 + Vector3(0, 0.85, 0)
		cam.look_at(current + forward * 2.0 + Vector3(0, 0.1, 0), Vector3.UP)

func start_intro_cutscene() -> void:
	sequence_running = true
	player.controls_enabled = false
	player.set_body_visible(false)
	player.set_weapon("")
	player.set_flashlight_available(false)
	
	# Queda inicial em primeira pessoa
	player.position = Vector3(0, 4.2, 1.8)
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 1)
	
	var fall_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(player, "position:y", 0.08, 0.78)
	fall_tween.parallel().tween_property(fade_overlay, "color:a", 0.0, 0.45)
	await fall_tween.finished
	
	var land_sound := AudioStreamPlayer.new()
	land_sound.stream = FALL_IMPACT_SOUND
	land_sound.volume_db = 4.0
	add_child(land_sound)
	land_sound.play()
	player.shake_camera(0.24, 0.75)
	
	# Poeiras subindo no chão na visão de primeira pessoa
	spawn_dust_landing(Vector3(0, 0.05, 1.8))
	
	# Maycon olhando levemente para baixo após a queda
	var look_down_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	look_down_tween.tween_property(player.head, "rotation:x", -0.42, 0.55)
	await look_down_tween.finished
	await get_tree().create_timer(0.4).timeout
	
	# Olhando para a direita
	var look_right_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_right_tween.tween_property(player.head, "rotation:y", -0.58, 0.72)
	look_right_tween.parallel().tween_property(player.head, "rotation:x", -0.15, 0.72)
	await look_right_tween.finished
	await get_tree().create_timer(0.3).timeout
	
	# Olhando para a esquerda
	var look_left_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_left_tween.tween_property(player.head, "rotation:y", 0.58, 0.95)
	look_left_tween.parallel().tween_property(player.head, "rotation:x", -0.08, 0.95)
	await look_left_tween.finished
	await get_tree().create_timer(0.3).timeout
	
	# Olhando para a frente
	var look_forward_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look_forward_tween.tween_property(player.head, "rotation:y", 0.0, 0.65)
	look_forward_tween.parallel().tween_property(player.head, "rotation:x", 0.0, 0.65)
	await look_forward_tween.finished
	await get_tree().create_timer(0.45).timeout
	
	# Instancia o Maycon Dummy em pose Idle exatamente como na praia
	var maycon_dummy: Node3D = MAYCON_SCENE.instantiate()
	maycon_dummy.position = Vector3(0, 0.08, 1.8)
	maycon_dummy.scale = Vector3.ONE * 0.95
	# Maycon olhando para frente (direção dos portões em -Z)
	maycon_dummy.rotation.y = PI
	world_root.add_child(maycon_dummy)
	
	var dummy_anim: AnimationPlayer = maycon_dummy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if dummy_anim:
		if not dummy_anim.has_animation("Walking"):
			if dummy_anim.get_animation_library_list().has(""):
				dummy_anim.remove_animation_library("")
			dummy_anim.add_animation_library("", MAYCON_MENU_ANIMATIONS)
		var anim_to_play = "Walking" if dummy_anim.has_animation("Walking") else "Idle"
		var a = dummy_anim.get_animation(anim_to_play)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
		dummy_anim.play(anim_to_play)
		dummy_anim.speed_scale = 0.95
		
	# Câmera da cutscene vindo lá de perto dos portões coloridos
	var cutscene_cam := Camera3D.new()
	add_child(cutscene_cam)
	cutscene_cam.position = Vector3(0, 1.8, -26.0)
	cutscene_cam.look_at(Vector3(0, 1.1, 1.8), Vector3.UP)
	cutscene_cam.current = true
	
	# Câmera vem em linha reta de encontro ao Maycon
	var approach_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	approach_tween.tween_property(cutscene_cam, "position", Vector3(0, 1.35, -1.8), 3.4)
	
	# Título bem grande no meio da tela que surge com a aproximação da câmera
	var title_layer := CanvasLayer.new()
	title_layer.name = "DungeonTitleCutsceneLayer"
	title_layer.layer = 95
	add_child(title_layer)
	
	var title_container := Control.new()
	title_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_container.modulate.a = 0.0
	title_layer.add_child(title_container)
	
	var title_label := Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.text = tr("DUNGEON_TITLE_CUTSCENE")
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.88, 1.0))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0.04, 0.015, 0.015, 0.98))
	title_label.add_theme_constant_override("outline_size", 10)
	title_container.add_child(title_label)
	
	# Fade in do título durante a aproximação
	create_tween().tween_property(title_container, "modulate:a", 1.0, 1.1)
	
	while approach_tween.is_running():
		await get_tree().process_frame
		cutscene_cam.look_at(Vector3(0, 1.1, 1.8), Vector3.UP)
		
	# Câmera dá uma volta ao redor do Maycon e para olhando para as costas dele
	var orbit_time := 3.0
	var orbit_timer := 0.0
	var maycon_center := Vector3(0, 1.1, 1.8)
	var radius := 2.6
	
	while orbit_timer < orbit_time:
		var delta_t: float = get_process_delta_time()
		orbit_timer += delta_t
		var t_norm := clampf(orbit_timer / orbit_time, 0.0, 1.0)
		var smooth_t := (1.0 - cos(t_norm * PI)) * 0.5
		var angle := -PI * 0.5 + smooth_t * PI
		var cam_x := sin(angle) * radius
		var cam_z := 1.8 - cos(angle) * radius
		var cam_y := lerpf(1.35, 1.55, smooth_t)
		cutscene_cam.position = Vector3(cam_x, cam_y, cam_z)
		cutscene_cam.look_at(maycon_center + Vector3(0, 0.1, 0), Vector3.UP)
		await get_tree().process_frame
		
	# Câmera sobe na região da cabeça e entra na cabeça dele simulando a primeira pessoa
	var enter_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	enter_tween.tween_property(cutscene_cam, "position", Vector3(0, 1.62, 1.82), 1.25)
	await enter_tween.finished
	
	# Transição para a gameplay de fato
	player.camera.current = true
	cutscene_cam.queue_free()
	maycon_dummy.queue_free()
	player.set_body_visible(false)
	
	Global.game_events["dungeon_intro_cutscene_seen"] = true
	Global.save_progress("calabouco_terror")
	
	player.controls_enabled = true
	sequence_running = false
	update_hud()
	
	# Deixa o título na tela por um tempo após a gameplay voltar e faz fade out suave
	var title_fade_routine := func():
		await get_tree().create_timer(1.8).timeout
		if is_instance_valid(title_container):
			var fade_tw := create_tween()
			fade_tw.tween_property(title_container, "modulate:a", 0.0, 1.35)
			await fade_tw.finished
			if is_instance_valid(title_layer):
				title_layer.queue_free()
	title_fade_routine.call()

func spawn_dust_landing(pos:Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	world_root.add_child(root)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = DUST_TEXTURE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 1.15)
	quad.material = mat
	
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.35))
	scale_curve.add_point(Vector2(0.25, 0.85))
	scale_curve.add_point(Vector2(1.0, 1.55))
	
	var color_grad := Gradient.new()
	color_grad.set_color(0, Color(0.72, 0.67, 0.58, 0.0))
	color_grad.add_point(0.12, Color(0.74, 0.69, 0.60, 0.75))
	color_grad.add_point(0.55, Color(0.70, 0.65, 0.56, 0.42))
	color_grad.set_color(color_grad.get_point_count() - 1, Color(0.66, 0.62, 0.54, 0.0))
	
	# Pluma de poeira ascendente
	var dust_plume := CPUParticles3D.new()
	dust_plume.mesh = quad
	dust_plume.amount = 32
	dust_plume.lifetime = 2.1
	dust_plume.one_shot = true
	dust_plume.explosiveness = 0.92
	dust_plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust_plume.emission_sphere_radius = 0.32
	dust_plume.direction = Vector3.UP
	dust_plume.spread = 48.0
	dust_plume.initial_velocity_min = 1.1
	dust_plume.initial_velocity_max = 2.5
	dust_plume.gravity = Vector3(0, 0.12, 0)
	dust_plume.damping_min = 0.8
	dust_plume.damping_max = 1.5
	dust_plume.angle_min = 0.0
	dust_plume.angle_max = 360.0
	dust_plume.angular_velocity_min = -30.0
	dust_plume.angular_velocity_max = 30.0
	dust_plume.scale_amount_min = 0.7
	dust_plume.scale_amount_max = 1.6
	dust_plume.scale_amount_curve = scale_curve
	dust_plume.color_ramp = color_grad
	root.add_child(dust_plume)
	dust_plume.emitting = true
	
	# Anel de poeira rápido espalhado no solo
	var dust_ring := CPUParticles3D.new()
	dust_ring.mesh = quad
	dust_ring.amount = 26
	dust_ring.lifetime = 1.35
	dust_ring.one_shot = true
	dust_ring.explosiveness = 0.96
	dust_ring.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust_ring.emission_ring_radius = 0.35
	dust_ring.emission_ring_inner_radius = 0.1
	dust_ring.direction = Vector3.UP
	dust_ring.spread = 90.0
	dust_ring.initial_velocity_min = 2.2
	dust_ring.initial_velocity_max = 3.8
	dust_ring.gravity = Vector3(0, -0.4, 0)
	dust_ring.damping_min = 2.2
	dust_ring.damping_max = 3.6
	dust_ring.angle_min = 0.0
	dust_ring.angle_max = 360.0
	dust_ring.angular_velocity_min = -45.0
	dust_ring.angular_velocity_max = 45.0
	dust_ring.scale_amount_min = 0.5
	dust_ring.scale_amount_max = 1.2
	dust_ring.scale_amount_curve = scale_curve
	dust_ring.color_ramp = color_grad
	root.add_child(dust_ring)
	dust_ring.emitting = true
	
	# Onda de choque sutil no piso
	var shock_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.28
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.78, 0.74, 0.65, 0.45)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = ring_mat
	shock_mesh.mesh = torus
	shock_mesh.position = Vector3(0, 0.02, 0)
	root.add_child(shock_mesh)
	
	var ring_tween := create_tween()
	ring_tween.parallel().tween_property(shock_mesh, "scale", Vector3(5.5, 1.0, 5.5), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	get_tree().create_timer(2.6).timeout.connect(root.queue_free)

func _process(delta:float) -> void:
	elapsed += delta
	update_main_monster_grab()
	update_giant_grab()
	update_infected_grab()
	if is_instance_valid(crosshair_label):
		var should_show_crosshair: bool = !sequence_running && is_instance_valid(player) && player.controls_enabled
		if crosshair_label.visible != should_show_crosshair:
			crosshair_label.visible = should_show_crosshair
	if is_instance_valid(player) && is_instance_valid(sprint_hud):
		var running_now: bool = player.is_sprint_pressed()
		if is_instance_valid(sprint_rb_icon):
			sprint_rb_icon.self_modulate = Color(1.3, 1.2, 0.45, 1.0) if running_now else Color(1.0, 1.0, 1.0, 0.84)
		if is_instance_valid(sprint_shift_icon):
			sprint_shift_icon.self_modulate = Color(1.3, 1.2, 0.45, 1.0) if running_now else Color(1.0, 1.0, 1.0, 0.61)
	for data in flicker_lights:
		var light:OmniLight3D = data.light
		var pulse:float = sin(elapsed * 7.3 + data.phase) * sin(elapsed * 13.7 + data.phase * 2)
		light.light_energy = data.base * (0.65 + absf(pulse) * 0.45) * (0.08 if pulse > 0.82 else 1)
	# Rotação contínua e flutuação senoidal suave (bobbing) de todos os itens colecionáveis
	for key in pickups.keys():
		var pickup:Node3D = pickups.get(key)
		if is_instance_valid(pickup):
			if !pickup.has_meta("base_y"):
				pickup.set_meta("base_y", pickup.position.y)
				pickup.set_meta("bob_phase", randf_range(0.0, TAU))
			pickup.rotation.y += delta * 1.85
			var p_base_y:float = pickup.get_meta("base_y")
			var p_phase:float = pickup.get_meta("bob_phase")
			pickup.position.y = p_base_y + sin(elapsed * 2.8 + p_phase) * 0.08
	if is_instance_valid(axe_pickup):
		if !axe_pickup.has_meta("base_y"):
			axe_pickup.set_meta("base_y", axe_pickup.position.y)
		axe_pickup.rotation.y += delta * 1.4
		var axe_base_y:float = axe_pickup.get_meta("base_y")
		axe_pickup.position.y = axe_base_y + sin(elapsed * 2.4) * 0.08
	for i in range(active_ammo_drops.size() - 1, -1, -1):
		var drop:Node3D = active_ammo_drops[i]
		if is_instance_valid(drop):
			if !drop.has_meta("base_y"):
				drop.set_meta("base_y", drop.position.y)
				drop.set_meta("bob_phase", randf_range(0.0, TAU))
			drop.rotation.y += delta * 2.2
			var drop_base_y:float = drop.get_meta("base_y")
			var drop_phase:float = drop.get_meta("bob_phase")
			drop.position.y = drop_base_y + sin(elapsed * 3.2 + drop_phase) * 0.06
			if player.global_position.distance_to(drop.global_position) < 1.65:
				collect_ammo_drop(drop)
				active_ammo_drops.remove_at(i)
		else:
			active_ammo_drops.remove_at(i)
	if !sequence_running:
		for enemy in enemies:
			if is_instance_valid(enemy) && !enemy.released && enemy.get_meta("auto_release", false) && player.global_position.z < enemy.global_position.z + 6.0:
				release_enemy(enemy)
		check_automatic_pickups()
		update_interaction()
		if player.position.y < -4:
			restart_after_caught(null)

func collect_ammo_drop(drop:Node3D) -> void:
	var w_type:String = str(drop.get_meta("weapon_type", "pistol"))
	var amount:int = int(drop.get_meta("amount", 4))
	player.add_ammo(w_type, amount)
	pickup_sound.play()
	if w_type == "pistol":
		show_pickup_notice(tr("DUNGEON_AMMO_PISTOL_DROPPED"))
	else:
		show_pickup_notice(tr("DUNGEON_AMMO_MG_DROPPED"))
	var t := create_tween()
	t.tween_property(drop, "scale", Vector3.ZERO, 0.15)
	t.tween_callback(drop.queue_free)

func check_automatic_pickups() -> void:
	var to_collect: Array[String] = []
	for pickup_name in pickups.keys():
		var pickup = pickups.get(pickup_name)
		if is_instance_valid(pickup) && player.global_position.distance_to(pickup.global_position) < 1.65:
			to_collect.append(str(pickup_name))
	for p_name in to_collect:
		collect_pickup(p_name)
	if is_instance_valid(axe_pickup) && event_is_true("dungeon_axe_door_open") && player.global_position.distance_to(axe_pickup.global_position) < 1.7:
		collect_axe()

func collect_pickup(pickup_name:String) -> void:
	if !pickups.has(pickup_name):
		return
	var pickup = pickups.get(pickup_name)
	if !is_instance_valid(pickup):
		pickups.erase(pickup_name)
		return
	pickup_sound.play()
	match pickup_name:
		"flashlight":
			Global.game_events["dungeon_flashlight_taken"] = true
			player.set_flashlight_available(true)
			player.toggle_flashlight()
			show_pickup_notice(tr("DUNGEON_ITEM_FLASHLIGHT"))
		"blue_key":
			Global.game_events["dungeon_blue_key_taken"] = true
			show_pickup_notice(tr("DUNGEON_ITEM_BLUE_KEY"))
		"pistol":
			Global.game_events["dungeon_pistol_taken"] = true
			player.set_weapon("pistol")
			show_pickup_notice(tr("DUNGEON_ITEM_PISTOL"))
		"red_key":
			Global.game_events["dungeon_red_key_taken"] = true
			show_pickup_notice(tr("DUNGEON_ITEM_RED_KEY"))
		"green_key":
			Global.game_events["dungeon_green_key_taken"] = true
			show_pickup_notice(tr("DUNGEON_ITEM_GREEN_KEY"))
		"cell_key":
			Global.game_events["dungeon_key_taken"] = true
			show_pickup_notice(tr("DUNGEON_ITEM_CELL_KEY"))
		"machinegun":
			Global.game_events["dungeon_gun_taken"] = true
			player.set_weapon("machinegun")
			show_pickup_notice(tr("DUNGEON_ITEM_MACHINEGUN"))
		"pistol_test":
			player.set_weapon("pistol")
			show_pickup_notice(tr("DUNGEON_ITEM_PISTOL"))
		"machinegun_test":
			player.set_weapon("machinegun")
			show_pickup_notice(tr("DUNGEON_ITEM_MACHINEGUN"))
	pickup.queue_free()
	pickups.erase(pickup_name)
	Global.save_progress("calabouco_terror")
	update_hud()

func collect_axe() -> void:
	if !is_instance_valid(axe_pickup):
		return
	Global.maycon_itens["axe"] = true
	Global.game_events["axe_taken"] = true
	Global.game_events["dungeon_axe_taken"] = true
	pickup_sound.play()
	axe_pickup.queue_free()
	axe_pickup = null
	show_pickup_notice(tr("DUNGEON_ITEM_AXE"))
	Global.save_progress("calabouco_terror")
	update_hud()

func update_interaction() -> void:
	current_interaction = ""
	var prompt_key := ""
	
	if !event_is_true("dungeon_blue_gate_open") && is_instance_valid(route_gates.get("blue")) && player.global_position.distance_to(route_gates["blue"].global_position) < 4.8:
		if event_is_true("dungeon_blue_key_taken") && !event_is_true("dungeon_blue_key_used"):
			current_interaction = "unlock_gate:blue"
			prompt_key = "DUNGEON_PROMPT_UNLOCK_BLUE"
		else:
			prompt_key = "DUNGEON_GATE_LOCKED_BLUE"
	elif !event_is_true("dungeon_red_gate_open") && is_instance_valid(route_gates.get("red")) && player.global_position.distance_to(route_gates["red"].global_position) < 3.2:
		if event_is_true("dungeon_red_key_taken") && !event_is_true("dungeon_red_key_used"):
			current_interaction = "unlock_gate:red"
			prompt_key = "DUNGEON_PROMPT_UNLOCK_RED"
		else:
			prompt_key = "DUNGEON_GATE_LOCKED_RED"
	elif !event_is_true("dungeon_green_gate_open") && is_instance_valid(route_gates.get("green")) && player.global_position.distance_to(route_gates["green"].global_position) < 3.2:
		if event_is_true("dungeon_green_key_taken") && !event_is_true("dungeon_green_key_used"):
			current_interaction = "unlock_gate:green"
			prompt_key = "DUNGEON_PROMPT_UNLOCK_GREEN"
		else:
			prompt_key = "DUNGEON_GATE_LOCKED_GREEN"
	elif !event_is_true("dungeon_axe_door_open") && is_instance_valid(axe_door) && player.global_position.distance_to(axe_door.global_position) < 3.0:
		if event_is_true("dungeon_key_taken") && !event_is_true("dungeon_cell_key_used"):
			current_interaction = "unlock_gate:axe"
			prompt_key = "DUNGEON_PROMPT_UNLOCK_AXE"
		else:
			prompt_key = "DUNGEON_GATE_LOCKED_AXE"
	else:
		for stage in levers:
			var lever:Node3D = levers[stage]
			if !event_is_true("dungeon_%s_lever" % stage) && player.global_position.distance_to(lever.global_position) < 2.6:
				current_interaction = "lever:" + stage
				prompt_key = "DUNGEON_PROMPT_LEVER"
				break
		if prompt_key == "" && player.global_position.distance_to(trampoline.global_position) < 2.6:
			current_interaction = "trampoline"
			prompt_key = "DUNGEON_PROMPT_TRAMPOLINE" if has_axe_event() else "DUNGEON_TRAMPOLINE_LOCKED"
			
	prompt_label.visible = prompt_key != ""
	if prompt_key != "":
		prompt_label.text = tr(prompt_key)

func on_interact_pressed() -> void:
	if sequence_running:
		return
	if current_interaction.begins_with("unlock_gate:"):
		var gate_name := current_interaction.trim_prefix("unlock_gate:")
		unlock_gate_manually(gate_name)
	elif current_interaction.begins_with("lever:"):
		activate_stage(current_interaction.trim_prefix("lever:"), true)
	elif current_interaction == "trampoline" && has_axe_event():
		return_to_castle()

func unlock_gate_manually(gate_name:String) -> void:
	if is_instance_valid(gate_unlock_sound):
		gate_unlock_sound.global_position = player.global_position
		gate_unlock_sound.pitch_scale = randf_range(0.97, 1.03)
		gate_unlock_sound.play()
	if gate_name == "axe":
		Global.game_events["dungeon_axe_door_open"] = true
		Global.game_events["dungeon_cell_key_used"] = true
		open_door(axe_door, true)
		show_pickup_notice(tr("DUNGEON_PROMPT_OPEN_CELL"))
		if !event_is_true("dungeon_finale_triggered"):
			start_finale_cutscene.call_deferred()
	elif gate_name in route_gates:
		Global.game_events["dungeon_%s_gate_open" % gate_name] = true
		Global.game_events["dungeon_%s_key_used" % gate_name] = true
		open_door(route_gates[gate_name], true)
		show_pickup_notice(tr("DUNGEON_PROMPT_UNLOCK_" + gate_name.to_upper()))
	Global.save_progress("calabouco_terror")
	update_hud()

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
		create_tween().tween_property(handle, "rotation:x", 0.75, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
		var is_key_door:bool = door.get_meta("is_key_room", false)
		if is_key_door:
			# Portão onde estão as chaves: tocar squeaky + heavy opening ao mesmo tempo
			if is_instance_valid(gate_squeaky_sound):
				gate_squeaky_sound.global_position = door.global_position
				gate_squeaky_sound.pitch_scale = randf_range(0.96, 1.04)
				gate_squeaky_sound.play()
			if is_instance_valid(gate_heavy_sound):
				gate_heavy_sound.global_position = door.global_position
				gate_heavy_sound.pitch_scale = randf_range(0.96, 1.04)
				gate_heavy_sound.play()
		else:
			# Qualquer outro portão (que não seja o portão onde está a chave)
			if is_instance_valid(gate_iron_sound):
				gate_iron_sound.global_position = door.global_position
				gate_iron_sound.pitch_scale = randf_range(0.95, 1.05)
				gate_iron_sound.play()
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).tween_property(door, "position:y", 5.2, 5.8)

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
	fade_overlay.visible = true
	fade_overlay.color = Color(0, 0, 0, 0)
	await create_tween().tween_property(fade_overlay, "color:a", 1, 0.4).finished
	await get_tree().create_timer(0.3).timeout
	await create_tween().tween_property(fade_overlay, "color:a", 0, 0.55).finished
	fade_overlay.visible = false
	player.controls_enabled = true
	sequence_running = false
	update_hud()

func update_hud() -> void:
	if !is_instance_valid(objective_label):
		return
	objective_label.visible = false
	if is_instance_valid(help_label):
		help_label.visible = false
	if is_instance_valid(flashlight_label):
		flashlight_label.visible = false
	if is_instance_valid(weapon_label):
		weapon_label.visible = false
	
	if is_instance_valid(ammo_label):
		if player.has_gun:
			ammo_label.visible = true
			var w_name:String = tr("DUNGEON_ITEM_MACHINEGUN") if player.weapon_mode == "machinegun" else tr("DUNGEON_ITEM_PISTOL")
			var clip:int = player.get_current_clip()
			var res:int = player.get_current_reserve()
			if player.is_reloading:
				ammo_label.text = "%s\n%s" % [w_name, tr("DUNGEON_RELOADING")]
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
			elif clip == 0:
				ammo_label.text = "%s [ 0 / %d ]\n%s" % [w_name, res, tr("DUNGEON_RELOAD_PROMPT")]
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			else:
				ammo_label.text = "%s [ %d / %d ]" % [w_name, clip, res]
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		else:
			ammo_label.visible = false
			
	var found := {
		"flashlight": event_is_true("dungeon_flashlight_taken"),
		"blue_key": event_is_true("dungeon_blue_key_taken") && !event_is_true("dungeon_blue_key_used"),
		"pistol": event_is_true("dungeon_pistol_taken") && !event_is_true("dungeon_gun_taken"),
		"red_key": event_is_true("dungeon_red_key_taken") && !event_is_true("dungeon_red_key_used"),
		"green_key": event_is_true("dungeon_green_key_taken") && !event_is_true("dungeon_green_key_used"),
		"cell_key": event_is_true("dungeon_key_taken") && !event_is_true("dungeon_cell_key_used"),
		"machinegun": event_is_true("dungeon_gun_taken"),
		"axe": has_axe_event()
	}
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
	if is_instance_valid(crosshair_label):
		crosshair_label.visible = !sequence_running && is_instance_valid(player) && player.controls_enabled
	if is_instance_valid(status_hud):
		status_hud.visible = !sequence_running
	if is_instance_valid(sprint_hud):
		sprint_hud.visible = !sequence_running
	if is_instance_valid(health_bar):
		health_bar.max_value = player.max_hp
		health_bar.value = player.current_hp
	if is_instance_valid(health_label):
		health_label.text = tr("DUNGEON_HP_LABEL")
	if is_instance_valid(stamina_bar):
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.current_stamina

func event_is_true(event_name:String) -> bool:
	return bool(Global.game_events.get(event_name, false))

func has_axe_event() -> bool:
	return event_is_true("axe_taken") || event_is_true("dungeon_axe_taken") || bool(Global.maycon_itens.get("axe", false))

func on_player_fired(origin:Vector3, direction:Vector3) -> void:
	if sequence_running:
		return
	gun_sound.pitch_scale = randf_range(1.15, 1.3) if player.weapon_mode == "machinegun" else randf_range(0.9, 1.05)
	gun_sound.play()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 68)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if !hit.is_empty():
		var damage_amount: int = 2 if player.weapon_mode == "pistol" else 1
		var hit_collider = hit.collider
		if hit_collider is DungeonMainMonster or hit_collider is DungeonInfected:
			hit_collider.take_damage(damage_amount, player.weapon_mode, hit.position, direction)
			spawn_blood_hit(hit.position, direction)
		elif hit_collider.has_method("take_damage"):
			hit_collider.take_damage(damage_amount, player.weapon_mode, hit.position, direction)
			spawn_blood_hit(hit.position, direction)

func spawn_ammo_drop(pos:Vector3, weapon_type:String) -> void:
	var drop := Node3D.new()
	drop.name = "AmmoDrop"
	drop.position = pos
	drop.set_meta("weapon_type", weapon_type)
	drop.set_meta("amount", 4 if weapon_type == "pistol" else 15)
	world_root.add_child(drop)
	
	var box := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.32, 0.22, 0.44) if weapon_type == "machinegun" else Vector3(0.24, 0.18, 0.32)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.38, 0.12) if weapon_type == "machinegun" else Color(0.72, 0.52, 0.18)
	mat.metallic = 0.8
	mat.roughness = 0.3
	b_mesh.material = mat
	box.mesh = b_mesh
	drop.add_child(box)
	
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.35) if weapon_type == "machinegun" else Color(1.0, 0.75, 0.15)
	light.light_energy = 2.4
	light.omni_range = 3.6
	drop.add_child(light)
	
	active_ammo_drops.append(drop)


func blood_fade_ramp() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.62, 0.03, 0.03, 1.0))
	gradient.set_color(1, Color(0.2, 0.004, 0.008, 0.0))
	gradient.add_point(0.45, Color(0.4, 0.01, 0.015, 1.0))
	return gradient

func spawn_blood_hit(hit_position:Vector3, direction:Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.position = hit_position
	particles.amount = 110
	particles.lifetime = 0.85
	particles.one_shot = true
	particles.explosiveness = 0.95
	# Espirrar para trás (na direção de onde veio o tiro) e para os lados
	particles.direction = (-direction * 0.75 + Vector3.UP * 0.35).normalized()
	particles.spread = 55.0
	particles.initial_velocity_min = 3.8
	particles.initial_velocity_max = 10.5
	particles.gravity = Vector3(0, -14.0, 0)
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 2.2
	particles.color_ramp = blood_fade_ramp()
	particles.particle_flag_align_y = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.013
	mesh.height = 0.12
	mesh.material = blood_material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.4).timeout.connect(particles.queue_free)

func spawn_enemy_death_blood(death_position:Vector3, enemy_kind:String) -> void:
	var base_amount:int = 380 if enemy_kind != "hound" else 260
	# Jato principal: gotas grandes e velozes, esticadas na direção do voo (mais realista que "bolinhas")
	var particles := CPUParticles3D.new()
	particles.position = death_position
	particles.amount = base_amount
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.32
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 13.0
	particles.gravity = Vector3(0, -16.0, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.9
	particles.color_ramp = blood_fade_ramp()
	particles.particle_flag_align_y = true
	var droplet := SphereMesh.new()
	droplet.radius = 0.02
	droplet.height = 0.17
	droplet.material = blood_material
	particles.mesh = droplet
	add_child(particles)
	particles.emitting = true
	get_tree().create_timer(2.1).timeout.connect(particles.queue_free)
	# Névoa fina complementar, para dar volume/densidade à explosão de sangue
	var mist := CPUParticles3D.new()
	mist.position = death_position
	mist.amount = int(base_amount * 0.6)
	mist.lifetime = 0.85
	mist.one_shot = true
	mist.explosiveness = 1.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 0.22
	mist.direction = Vector3.UP
	mist.spread = 180.0
	mist.initial_velocity_min = 1.5
	mist.initial_velocity_max = 5.5
	mist.gravity = Vector3(0, -6.0, 0)
	mist.scale_amount_min = 0.2
	mist.scale_amount_max = 0.55
	mist.color_ramp = blood_fade_ramp()
	var mist_mesh := SphereMesh.new()
	mist_mesh.radius = 0.01
	mist_mesh.height = 0.02
	mist_mesh.material = blood_material
	mist.mesh = mist_mesh
	add_child(mist)
	mist.emitting = true
	get_tree().create_timer(1.2).timeout.connect(mist.queue_free)
	create_blood_stain(Vector3(death_position.x, 0.025, death_position.z), enemy_kind)

func create_blood_stain(floor_position:Vector3, enemy_kind:String) -> void:
	var stain := Node3D.new()
	stain.name = "PersistentBloodStain"
	stain.position = floor_position
	stain.rotation.y = randf_range(-PI, PI)
	world_root.add_child(stain)
	var stain_scale:float = 1.35 if enemy_kind != "hound" else 0.9
	for index in 13:
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
	if Global.debug_dungeon_invincible || sequence_running:
		return
	
	var damage:float = 25.0
	if is_instance_valid(infected):
		if infected.enemy_kind == "hound":
			damage = 14.0 # Rato tira menos sangue, o menor dos 3
		elif infected.enemy_kind == "zombie":
			damage = 25.0
		elif infected.enemy_kind == "mutant":
			damage = 42.0
			
	var hit_sfx := AudioStreamPlayer.new()
	hit_sfx.stream = load("res://assets/novos_audios/sangue_fill_effect.mp3")
	hit_sfx.volume_db = 0.0
	add_child(hit_sfx)
	hit_sfx.play()
	hit_sfx.finished.connect(hit_sfx.queue_free)
	
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.4)
	
	var died := player.take_damage(damage)
	if died:
		restart_after_caught(infected)
	else:
		flash_blood_damage_overlay(0.7)
		if is_instance_valid(infected):
			var push_dir := (player.global_position - infected.global_position).normalized()
			push_dir.y = 0.22
			player.apply_knockback(push_dir * 4.6, 0.4)
			infected.recover_from_attack(1.4)

func flash_blood_damage_overlay(intensity:float = 0.7) -> void:
	monster_damage_serial += 1
	var current_serial := monster_damage_serial
	blood_overlay.visible = true
	for child in blood_overlay.get_children():
		child.modulate.a = 0.0
		var target_alpha := randf_range(0.35, 0.75) * intensity
		create_tween().tween_property(child, "modulate:a", target_alpha, randf_range(0.04, 0.15))
	await get_tree().create_timer(0.45).timeout
	if current_serial != monster_damage_serial:
		return
	var fade := create_tween().set_parallel()
	for child in blood_overlay.get_children():
		fade.tween_property(child, "modulate:a", 0.0, 0.55)
	await fade.finished
	if current_serial == monster_damage_serial:
		blood_overlay.visible = false

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

func apply_main_monster_strike(monster:DungeonMainMonster, attack_variant:int) -> void:
	if Global.debug_dungeon_invincible || sequence_running || !is_instance_valid(monster):
		return
	var throw_direction := player.global_position - monster.global_position
	throw_direction.y = 0.0
	if throw_direction.length_squared() < 0.01:
		throw_direction = -monster.global_transform.basis.z
	var died := player.take_damage(26.0 + attack_variant * 3.5)
	player.apply_knockback(throw_direction.normalized() * (5.4 + attack_variant * 0.22) + Vector3.UP * 1.7, 0.56)
	player.shake_camera(0.085, 0.62)
	show_main_monster_blood(0.78)
	if died:
		restart_after_caught(null)

func begin_main_monster_grab(monster:DungeonMainMonster, anchor:Marker3D) -> bool:
	if Global.debug_dungeon_invincible || sequence_running || !is_instance_valid(monster) || !is_instance_valid(anchor):
		return false
	main_monster_grab_active = true
	main_monster_grabber = monster
	main_monster_grab_anchor = anchor
	sequence_running = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.shake_camera(0.055, 0.45)
	show_main_monster_blood(0.52)
	return true

func update_main_monster_grab() -> void:
	if !main_monster_grab_active || !is_instance_valid(player) || !is_instance_valid(main_monster_grabber) || !is_instance_valid(main_monster_grab_anchor):
		return
	player.global_position = main_monster_grab_anchor.global_position - Vector3.UP * 1.32
	var target_look := main_monster_grabber.global_position + Vector3.UP * 2.05
	var diff := target_look - player.global_position
	player.rotation.y = atan2(-diff.x, -diff.z)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.head.rotation.x = clampf(atan2(diff.y, maxf(0.001, Vector2(diff.x, diff.z).length())), -1.2, 1.2)

func end_main_monster_grab(monster:DungeonMainMonster) -> void:
	if !main_monster_grab_active || monster != main_monster_grabber:
		return
	var release_position := player.global_position
	var throw_direction := release_position - monster.global_position
	throw_direction.y = 0.0
	if throw_direction.length_squared() < 0.01:
		throw_direction = -monster.global_transform.basis.z
	main_monster_grab_active = false
	main_monster_grab_anchor = null
	main_monster_grabber = null
	player.global_position = release_position
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_physics_process(true)
	player.controls_enabled = true
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.head.position.y = player.base_head_y
	player.head.position.z = player.base_head_z
	player.head.rotation.z = 0.0
	player.apply_knockback(throw_direction.normalized() * 10.5 + Vector3.UP * 5.6, 0.92)
	player.shake_camera(0.14, 0.92)
	show_main_monster_blood(1.0)
	var grab_damage:float = maxf(1.0, player.current_hp * 0.85)
	var died := player.take_damage(grab_damage)
	sequence_running = false
	update_hud()
	if died:
		restart_after_caught(null)

func show_main_monster_blood(intensity:float) -> void:
	monster_damage_serial += 1
	var current_serial:int = monster_damage_serial
	var sound_delay := randf_range(0.0, 0.08)
	if sound_delay > 0.01:
		get_tree().create_timer(sound_delay).timeout.connect(func():
			if current_serial == monster_damage_serial and is_instance_valid(monster_damage_sound):
				monster_damage_sound.pitch_scale = randf_range(0.78, 0.98)
				monster_damage_sound.play()
		)
	else:
		if is_instance_valid(monster_damage_sound):
			monster_damage_sound.pitch_scale = randf_range(0.78, 0.98)
			monster_damage_sound.play()
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.38)
	blood_overlay.visible = true
	for child in blood_overlay.get_children():
		child.modulate.a = 0.0
		var target_alpha:float = randf_range(0.42, 0.82) * intensity
		create_tween().tween_property(child, "modulate:a", target_alpha, randf_range(0.05, 0.2)).set_delay(randf_range(0.0, 0.22))
	await get_tree().create_timer(0.8 + intensity * 0.45).timeout
	if current_serial != monster_damage_serial:
		return
	var fade := create_tween().set_parallel()
	for child in blood_overlay.get_children():
		fade.tween_property(child, "modulate:a", 0.0, 0.65)
	await fade.finished
	if current_serial == monster_damage_serial:
		blood_overlay.visible = false

func show_infected_grab_blood(intensity:float) -> void:
	monster_damage_serial += 1
	var current_serial:int = monster_damage_serial
	var sound_delay := randf_range(0.06, 0.24)
	get_tree().create_timer(sound_delay).timeout.connect(func():
		if current_serial != monster_damage_serial:
			return
		if is_instance_valid(zombie_grab_sound):
			zombie_grab_sound.pitch_scale = randf_range(0.85, 1.25)
			zombie_grab_sound.volume_db = randf_range(-1.0, 1.5)
			zombie_grab_sound.play()
		if is_instance_valid(monster_damage_sound):
			monster_damage_sound.pitch_scale = randf_range(1.08, 1.32)
			monster_damage_sound.volume_db = randf_range(-3.5, -0.5)
			monster_damage_sound.play()
	)
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.38)
	blood_overlay.visible = true
	for child in blood_overlay.get_children():
		child.modulate.a = 0.0
		var target_alpha:float = randf_range(0.42, 0.82) * intensity
		create_tween().tween_property(child, "modulate:a", target_alpha, randf_range(0.05, 0.2)).set_delay(randf_range(0.0, 0.22))
	await get_tree().create_timer(0.8 + intensity * 0.45).timeout
	if current_serial != monster_damage_serial:
		return
	var fade := create_tween().set_parallel()
	for child in blood_overlay.get_children():
		fade.tween_property(child, "modulate:a", 0.0, 0.65)
	await fade.finished
	if current_serial == monster_damage_serial:
		blood_overlay.visible = false

func begin_giant_grab(giant:DungeonGiantZombie, anchor:Marker3D) -> bool:
	if Global.debug_dungeon_invincible || sequence_running || !is_instance_valid(giant) || !is_instance_valid(anchor):
		return false
	giant_grab_active = true
	giant_grabber = giant
	giant_grab_anchor = anchor
	sequence_running = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.shake_camera(0.06, 0.4)
	return true

func update_giant_grab() -> void:
	if !giant_grab_active || !is_instance_valid(player) || !is_instance_valid(giant_grab_anchor):
		return
	player.global_position = giant_grab_anchor.global_position
	if is_instance_valid(giant_grabber):
		var target_look := giant_grabber.global_position + Vector3.UP * 3.2
		var diff := target_look - player.global_position
		player.rotation.y = atan2(-diff.x, -diff.z)
		player.rotation.x = 0.0
		player.rotation.z = 0.0
		player.head.rotation.x = clampf(atan2(diff.y, maxf(0.001, Vector2(diff.x, diff.z).length())), -1.2, 1.2)

func giant_grab_bleed(intensity:float) -> void:
	# Jato de sangue 3D + mancha vermelha na tela (sem recarregar a cena ainda)
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.4)
	flash_blood_damage_overlay(intensity)

func giant_wall_impact(intensity:float) -> void:
	# Batida contra a parede: tremor forte de câmera, sangue e mancha na tela
	if is_instance_valid(player):
		player.shake_camera(0.18, 0.42)
	spawn_blood_spurt(player.camera.global_position + player.camera_forward() * 0.4)
	if is_instance_valid(monster_damage_sound):
		monster_damage_sound.pitch_scale = randf_range(0.82, 1.02)
		monster_damage_sound.play()
	flash_blood_damage_overlay(intensity)

func finish_giant_grab_kill(giant:DungeonGiantZombie) -> void:
	if giant != giant_grabber:
		return
	giant_grab_active = false
	giant_grab_anchor = null
	giant_grabber = null
	restart_after_caught(null)

func begin_infected_grab(infected:DungeonInfected, anchor:Marker3D) -> bool:
	# Zumbi pequeno agarra e segura o player na mão (com som e timing próprios).
	if Global.debug_dungeon_invincible || sequence_running || !is_instance_valid(infected) || !is_instance_valid(anchor):
		return false
	infected_grab_active = true
	infected_grabber = infected
	infected_grab_anchor = anchor
	sequence_running = true
	player.controls_enabled = false
	player.velocity = Vector3.ZERO
	player.collision_layer = 0
	player.collision_mask = 0
	player.set_physics_process(false)
	player.shake_camera(0.05, 0.4)
	show_infected_grab_blood(0.5)
	return true

func update_infected_grab() -> void:
	if !infected_grab_active:
		return
	if !is_instance_valid(player) || !is_instance_valid(infected_grabber) || !is_instance_valid(infected_grab_anchor):
		# O agarrador sumiu (morreu/foi liberado): solta o player em segurança
		if is_instance_valid(player):
			player.collision_layer = 2
			player.collision_mask = 1
			player.set_physics_process(true)
			player.controls_enabled = true
			player.rotation.x = 0.0
			player.rotation.z = 0.0
			player.head.position.y = player.base_head_y
			player.head.position.z = player.base_head_z
			player.head.rotation.z = 0.0
		infected_grab_active = false
		infected_grab_anchor = null
		infected_grabber = null
		sequence_running = false
		update_hud()
		return
	player.global_position = infected_grab_anchor.global_position - Vector3.UP * 1.1
	var target_look := infected_grabber.global_position + Vector3.UP * 1.4
	var diff := target_look - player.global_position
	player.rotation.y = atan2(-diff.x, -diff.z)
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.head.rotation.x = clampf(atan2(diff.y, maxf(0.001, Vector2(diff.x, diff.z).length())), -1.2, 1.2)

func end_infected_grab(infected:DungeonInfected) -> void:
	# Solta arremessando o player com dano forte (com som e timing próprios).
	if !infected_grab_active || infected != infected_grabber:
		return
	var release_position := player.global_position
	var throw_direction := release_position - infected.global_position
	throw_direction.y = 0.0
	if throw_direction.length_squared() < 0.01:
		throw_direction = -infected.global_transform.basis.z
	infected_grab_active = false
	infected_grab_anchor = null
	infected_grabber = null
	player.global_position = release_position
	player.collision_layer = 2
	player.collision_mask = 1
	player.set_physics_process(true)
	player.controls_enabled = true
	player.rotation.x = 0.0
	player.rotation.z = 0.0
	player.head.position.y = player.base_head_y
	player.head.position.z = player.base_head_z
	player.head.rotation.z = 0.0
	player.apply_knockback(throw_direction.normalized() * 9.0 + Vector3.UP * 4.8, 0.85)
	player.shake_camera(0.12, 0.8)
	show_infected_grab_blood(0.9)
	var grab_damage:float = maxf(1.0, player.current_hp * 0.7)
	var died := player.take_damage(grab_damage)
	sequence_running = false
	update_hud()
	if died:
		restart_after_caught(infected)

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
