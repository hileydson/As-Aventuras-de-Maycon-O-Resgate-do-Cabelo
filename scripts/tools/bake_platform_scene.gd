@tool
extends SceneTree

const SCENE_PATH = "res://scenes/3D/maycon_platform_3d.tscn"
const ASSET_ROOT = "res://assets/kenney/platformer_3d/"
const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")
const BLADE_SCRIPT = preload("res://scripts/3D/platform_blade.gd")
const HAND_SCRIPT = preload("res://scripts/3D/platform_hand.gd")
const ENEMY_SCRIPT = preload("res://scripts/3D/platform_enemy.gd")
const MINI_SECO_SCRIPT = preload("res://scripts/3D/platform_mini_seco.gd")
const LIPS_SCRIPT = preload("res://scripts/3D/platform_lips.gd")

const BLADE_ROUTE_IDS = [2, 5, 8, 11]
const HAND_HUB_IDS = [1, 4, 7, 10, 12]
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

var materials: Dictionary = {}
var assets: Dictionary = {}

func _init() -> void:
	print("====================================================")
	print("  Iniciando Bake do Cenário: MayconPlatform3D")
	print("====================================================")

	var base_scene: PackedScene = load(SCENE_PATH)
	if not base_scene:
		printerr("Erro ao carregar a cena: ", SCENE_PATH)
		quit(1)
		return

	var root: Node3D = base_scene.instantiate()
	if not root:
		printerr("Erro ao instanciar raiz da cena!")
		quit(1)
		return

	_clean_previous_baked_nodes(root)
	_build_materials()

	# 1. Ambiente e Iluminação
	_bake_environment(root)

	# 2. Nós organizadores principais
	var geometry := Node3D.new()
	geometry.name = "Cenario"
	root.add_child(geometry)

	var hazards := Node3D.new()
	hazards.name = "Armadilhas"
	root.add_child(hazards)

	var enemies := Node3D.new()
	enemies.name = "Inimigos"
	root.add_child(enemies)

	var effects := Node3D.new()
	effects.name = "Efeitos"
	root.add_child(effects)

	# 3. Construção do mundo
	_bake_clouds(geometry)
	_bake_hubs_and_routes(geometry, hazards, root)
	_bake_elevated_areas(geometry)
	_bake_hands(hazards, root)
	_bake_finish(geometry, root)
	_bake_scatter_details(geometry)
	_bake_blue_particles(root)
	_bake_pentagrams(geometry)

	# 4. Spawns e entidades
	_bake_enemies(enemies, root)
	_bake_mini_secos(enemies, root)
	_bake_lips(enemies, root)

	# 5. Configurar owners recursivamente para todos os nós criados
	print("Configurando owners para persistência no editor...")
	_assign_owner_recursive(root, root)

	# 6. Salvar cena .tscn
	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		printerr("Erro ao empacotar cena: ", pack_result)
		quit(1)
		return

	var save_result := ResourceSaver.save(packed, SCENE_PATH)
	if save_result != OK:
		printerr("Erro ao salvar cena em ", SCENE_PATH, ": ", save_result)
		quit(1)
		return

	print("====================================================")
	print("  SUCESSO: Cena '", SCENE_PATH, "' atualizada com sucesso!")
	print("  Agora todos os nós do cenário e elementos estão")
	print("  salvos e editáveis diretamente no Godot Editor!")
	print("====================================================")
	quit(0)

func _clean_previous_baked_nodes(root: Node3D) -> void:
	var to_remove := [
		"WorldEnvironment", "DirectionalLight3D", "WaterPlane", "DistantPillars",
		"Cenario", "Armadilhas", "Inimigos", "Efeitos", "GiantWoodenBarrier",
		"ExitHoleArrow", "ParticulasAzuis", "FinishHoleLight"
	]
	for node_name in to_remove:
		var node = root.get_node_or_null(node_name)
		if is_instance_valid(node):
			root.remove_child(node)
			node.queue_free()

func _assign_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	
	# Se for uma instância externa (GLB importado), não alteramos os filhos internos
	if node.scene_file_path != "" and node != scene_root:
		return

	for child in node.get_children():
		_assign_owner_recursive(child, scene_root)

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

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _bake_environment(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("91c8e7")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e0e6ef")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("a8d0e6")
	env.fog_density = 0.004

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	root.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff0c9")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	root.add_child(sun)

	var water := _box_node(Vector3(0.0, -18.0, -83.0), Vector3(300.0, 1.0, 360.0), "water", false)
	water.name = "WaterPlane"
	root.add_child(water)

	var pillars := Node3D.new()
	pillars.name = "DistantPillars"
	root.add_child(pillars)
	for i in range(34):
		var z := 55.0 - float(i) * 8.0
		for side in [-1.0, 1.0]:
			var height := 8.0 + float((i * 7) % 9)
			var pillar := _box_node(Vector3(side * (77.0 + float((i * 3) % 9)), -9.0 + height * 0.5, z), Vector3(8.0 + float(i % 3) * 3.0, height, 8.0), "stone_dark", false)
			pillar.name = "Pilar_%d_%s" % [i, "L" if side < 0 else "R"]
			pillars.add_child(pillar)

func _box_node(center: Vector3, size: Vector3, material_name: String, solid: bool = true) -> Node3D:
	var node := Node3D.new()
	node.position = center
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

func _bake_clouds(parent: Node3D) -> void:
	var clouds_group := Node3D.new()
	clouds_group.name = "Nuvens"
	parent.add_child(clouds_group)

	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 12
	cloud_mesh.rings = 6
	var cloud_material := StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.albedo_color = Color("f8faff")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91573
	for i in range(25):
		var center := Vector3(rng.randf_range(-95.0, 95.0), rng.randf_range(18.0, 32.0), rng.randf_range(-215.0, 75.0))
		for puff_index in range(4):
			var puff := MeshInstance3D.new()
			puff.mesh = cloud_mesh
			puff.material_override = cloud_material
			puff.position = center + Vector3(float(puff_index) * 3.2 - 4.8, rng.randf_range(-1.2, 1.2), rng.randf_range(-2.0, 2.0))
			puff.scale = Vector3(rng.randf_range(3.5, 5.5), rng.randf_range(1.2, 2.2), rng.randf_range(2.3, 4.2))
			clouds_group.add_child(puff)

func _bake_asset(name: String, position: Vector3, scale: float = 1.0, rotation: float = 0.0, parent: Node3D = null) -> Node3D:
	if not assets.has(name):
		assets[name] = load(ASSET_ROOT + name + ".glb")
	var scene: PackedScene = assets[name]
	var model: Node3D = scene.instantiate()
	model.position = position
	model.scale = Vector3.ONE * scale
	model.rotation.y = rotation
	if parent:
		parent.add_child(model)
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

func _bake_platform(top: Vector3, footprint: Vector2, material_name: String = "grass", parent: Node3D = null) -> void:
	var base := _box_node(top - Vector3.UP * 0.75, Vector3(footprint.x, 1.5, footprint.y), "earth" if material_name == "grass" else "stone_dark")
	var top_box := _box_node(top + Vector3.UP * 0.09, Vector3(footprint.x, 0.18, footprint.y), material_name)
	parent.add_child(base)
	parent.add_child(top_box)

func _bake_hubs_and_routes(geometry: Node3D, hazards: Node3D, root: Node3D) -> void:
	var hubs_group := Node3D.new()
	hubs_group.name = "Hubs"
	geometry.add_child(hubs_group)

	for i in range(HUBS.size()):
		var hub: Vector3 = HUBS[i]
		var size := Vector2(23.0, 20.0) if i == 0 or i == HUBS.size() - 1 else Vector2(19.0, 17.0)
		var hub_node := Node3D.new()
		hub_node.name = "Hub_%d" % i
		hubs_group.add_child(hub_node)
		_bake_platform(hub, size, "grass", hub_node)
		for side in [-1.0, 1.0]:
			for corner in [-1.0, 1.0]:
				_bake_asset("block-grass-large", hub + Vector3(side * (size.x * 0.5 - 1.2), -0.2, corner * (size.y * 0.5 - 1.0)), 1.2, float(i) * 0.4, hub_node)

	var routes_group := Node3D.new()
	routes_group.name = "Rotas"
	geometry.add_child(routes_group)

	for route_index in range(ROUTES.size()):
		var route: Vector2i = ROUTES[route_index]
		var start: Vector3 = HUBS[route.x]
		var finish: Vector3 = HUBS[route.y]
		var steps := ceili(start.distance_to(finish) / 4.2)
		var route_node := Node3D.new()
		route_node.name = "Rota_%d_%d" % [route.x, route.y]
		routes_group.add_child(route_node)

		for i in range(1, steps):
			var point := start.lerp(finish, float(i) / float(steps))
			if route_index in BLADE_ROUTE_IDS and i == floori(float(steps) * 0.5):
				var blade := Node3D.new()
				blade.set_script(BLADE_SCRIPT)
				blade.name = "Navalha_%d" % route_index
				blade.position = point
				hazards.add_child(blade)
				continue
			var mat_name := "wood" if i % 4 == 0 else "stone" if i % 4 == 1 else "grass_light"
			_bake_platform(point, Vector2(3.5, 3.5), mat_name, route_node)
			if i % 5 == 0:
				_bake_asset("rocks", point + Vector3(-1.6, 0.25, 0.0), 0.7, float(i), route_node)

func _bake_hands(hazards: Node3D, root: Node3D) -> void:
	for index in HAND_HUB_IDS:
		var hand := Node3D.new()
		hand.set_script(HAND_SCRIPT)
		hand.name = "MaoEsmagadora_%d" % index
		hand.position = HUBS[index] + Vector3(0.0, 0.0, -1.8)
		hazards.add_child(hand)

func _bake_elevated_areas(geometry: Node3D) -> void:
	var elevated_group := Node3D.new()
	elevated_group.name = "AreasElevadas"
	geometry.add_child(elevated_group)

	for hub_index in range(1, HUBS.size() - 1):
		var hub: Vector3 = HUBS[hub_index]
		var side := -1.0 if hub.x < 0.0 else 1.0
		var hub_elev := Node3D.new()
		hub_elev.name = "Elevado_Hub_%d" % hub_index
		elevated_group.add_child(hub_elev)

		for step in range(1, 5):
			var top := hub + Vector3(side * (1.0 + float(step) * 2.0), float(step) * 0.82, 5.0 - float(step) * 2.1)
			_bake_platform(top, Vector2(3.5, 3.5), "grass_light", hub_elev)
		var balcony := hub + Vector3(side * 11.0, 4.1, -4.0)
		_bake_platform(balcony, Vector2(7.0, 7.0), "grass", hub_elev)
		_bake_asset("star", balcony + Vector3.UP * 1.1, 1.6, 0.0, hub_elev)
		for step in range(2):
			var overlook := hub + Vector3(side * (13.0 + float(step) * 4.1), 4.1 - float(step) * 0.7, -4.0 - float(step) * 3.3)
			_bake_platform(overlook, Vector2(3.4, 3.4), "stone", hub_elev)

func _bake_finish(geometry: Node3D, root: Node3D) -> void:
	var finish_group := Node3D.new()
	finish_group.name = "FinishArea"
	geometry.add_child(finish_group)

	_bake_platform(Vector3(0.0, 0.0, -195.0), Vector2(17.0, 5.0), "grass", finish_group)
	for side in [-1.0, 1.0]:
		_bake_platform(Vector3(side * 6.0, 0.0, -206.0), Vector2(8.0, 14.0), "stone", finish_group)
	for z in [-200.0, -212.0]:
		_bake_platform(Vector3(0.0, 0.0, z), Vector2(4.0, 4.0), "stone", finish_group)
	_bake_asset("flag", Vector3(-5.0, 0.15, -199.0), 6.0, PI * 0.5, finish_group)

	var ring_node := Node3D.new()
	ring_node.name = "GoldenRing"
	finish_group.add_child(ring_node)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var ring := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		ring.mesh = mesh
		ring.material_override = materials["gold"]
		ring.position = Vector3(cos(angle) * 2.4, 0.34, -206.0 + sin(angle) * 2.4)
		ring_node.add_child(ring)

	var beam := OmniLight3D.new()
	beam.name = "FinishHoleLight"
	beam.position = Vector3(0.0, -0.5, -206.0)
	beam.light_color = Color("ffc45b")
	beam.light_energy = 1.5
	beam.omni_range = 6.0
	root.add_child(beam)

	_bake_exit_arrow(root)
	_bake_giant_wooden_barrier(root)

func _bake_exit_arrow(root: Node3D) -> void:
	var exit_arrow := Node3D.new()
	exit_arrow.name = "ExitHoleArrow"
	exit_arrow.position = Vector3(0.0, 4.8, -206.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.12, 0.15, 0.95)

	var shaft := MeshInstance3D.new()
	shaft.name = "Shaft"
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.35
	shaft_mesh.bottom_radius = 0.35
	shaft_mesh.height = 1.8
	shaft_mesh.radial_segments = 16
	shaft.mesh = shaft_mesh
	shaft.material_override = mat
	shaft.position.y = 0.9
	exit_arrow.add_child(shaft)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 1.05
	head_mesh.height = 1.4
	head_mesh.radial_segments = 16
	head.mesh = head_mesh
	head.material_override = mat
	head.rotation.x = PI
	head.position.y = -0.4
	exit_arrow.add_child(head)

	var arrow_light := OmniLight3D.new()
	arrow_light.name = "ArrowLight"
	arrow_light.light_color = Color(1.0, 0.2, 0.2)
	arrow_light.light_energy = 2.2
	arrow_light.omni_range = 7.0
	exit_arrow.add_child(arrow_light)

	root.add_child(exit_arrow)

func _bake_giant_wooden_barrier(root: Node3D) -> void:
	var boss_barrier := StaticBody3D.new()
	boss_barrier.name = "GiantWoodenBarrier"
	boss_barrier.position = Vector3(0.0, 0.0, -193.2)

	var boss_barrier_collider := CollisionShape3D.new()
	boss_barrier_collider.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(20.0, 10.0, 3.0)
	boss_barrier_collider.shape = box_shape
	boss_barrier_collider.position = Vector3(0.0, 5.0, 0.0)
	boss_barrier.add_child(boss_barrier_collider)

	var wood_mat: StandardMaterial3D = materials["wood"]
	var dark_wood_mat: StandardMaterial3D = materials["earth_dark"]
	var metal_mat: StandardMaterial3D = materials["stone_dark"]

	var logs_group := Node3D.new()
	logs_group.name = "Logs"
	boss_barrier.add_child(logs_group)

	var rng := RandomNumberGenerator.new()
	rng.seed = 448811
	for i in range(18):
		var log_inst := MeshInstance3D.new()
		var log_mesh := CylinderMesh.new()
		var log_h := rng.randf_range(8.2, 9.8)
		log_mesh.top_radius = rng.randf_range(0.48, 0.62)
		log_mesh.bottom_radius = rng.randf_range(0.55, 0.70)
		log_mesh.height = log_h
		log_mesh.radial_segments = 14
		log_inst.mesh = log_mesh
		log_inst.material_override = wood_mat if i % 2 == 0 else dark_wood_mat
		var offset_x: float = -9.2 + float(i) * 1.08 + rng.randf_range(-0.08, 0.08)
		log_inst.position = Vector3(offset_x, log_h * 0.5, rng.randf_range(-0.25, 0.25))
		log_inst.rotation = Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.04, 0.04))
		logs_group.add_child(log_inst)

	var beams_group := Node3D.new()
	beams_group.name = "Beams"
	boss_barrier.add_child(beams_group)

	var beam_heights := [1.8, 4.4, 7.0]
	for bh in beam_heights:
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(20.2, 0.75, 0.85)
		beam.mesh = beam_mesh
		beam.material_override = wood_mat
		beam.position = Vector3(0.0, bh, 0.45)
		beams_group.add_child(beam)

		for mx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.55, 0.85, 0.95)
			band.mesh = band_mesh
			band.material_override = metal_mat
			band.position = Vector3(mx, bh, 0.45)
			beams_group.add_child(band)

	for angle in [-0.42, 0.42]:
		var diag := MeshInstance3D.new()
		var diag_mesh := BoxMesh.new()
		diag_mesh.size = Vector3(18.5, 0.55, 0.65)
		diag.mesh = diag_mesh
		diag.material_override = dark_wood_mat
		diag.position = Vector3(0.0, 4.4, 0.6)
		diag.rotation.z = angle
		beams_group.add_child(diag)

	var sign_board := MeshInstance3D.new()
	sign_board.name = "SignBoard"
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(9.2, 2.2, 0.35)
	sign_board.mesh = sign_mesh
	sign_board.material_override = dark_wood_mat
	sign_board.position = Vector3(0.0, 3.6, 0.95)
	boss_barrier.add_child(sign_board)

	var sign_border := MeshInstance3D.new()
	sign_border.name = "SignBorder"
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(9.5, 2.45, 0.25)
	sign_border.mesh = border_mesh
	sign_border.material_override = materials["gold"]
	sign_border.position = Vector3(0.0, 3.6, 0.85)
	boss_barrier.add_child(sign_border)

	var label_3d := Label3D.new()
	label_3d.name = "BarrierSignLabel"
	label_3d.text = tr("PLATFORM_BARRIER_SIGN")
	label_3d.font_size = 46
	label_3d.outline_size = 14
	label_3d.modulate = Color(1.0, 0.88, 0.3)
	label_3d.outline_modulate = Color(0.12, 0.02, 0.02)
	label_3d.position = Vector3(0.0, 3.6, 1.15)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_barrier.add_child(label_3d)

	root.add_child(boss_barrier)

func _bake_scatter_details(geometry: Node3D) -> void:
	var details_group := Node3D.new()
	details_group.name = "DetalhesDecorativos"
	geometry.add_child(details_group)

	var rng := RandomNumberGenerator.new()
	rng.seed = 746302
	for i in range(HUBS.size()):
		var hub: Vector3 = HUBS[i]
		var half := 10.0 if i == 0 or i == HUBS.size() - 1 else 8.0
		for j in range(18):
			var side := -1.0 if j % 2 == 0 else 1.0
			var x := side * rng.randf_range(half - 2.6, half - 0.9)
			var pos := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			var aname := "tree" if j % 5 == 0 else "tree-pine-small" if j % 5 == 1 else "flowers" if j % 5 == 2 else "rocks" if j % 5 == 3 else "mushrooms"
			var size := rng.randf_range(1.3, 2.8) if aname.begins_with("tree") else rng.randf_range(0.8, 1.9)
			_bake_asset(aname, pos, size, rng.randf_range(0.0, TAU), details_group)
		for j in range(6):
			var x := rng.randf_range(-half + 3.0, half - 3.0)
			var pos := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			_bake_asset("grass" if j % 2 == 0 else "flowers-tall", pos, rng.randf_range(0.8, 1.5), 0.0, details_group)
		for j in range(2):
			var side := -1.0 if j == 0 else 1.0
			_bake_asset("crate" if j == 0 else "barrel", hub + Vector3(side * (half - 2.2), 0.18, -4.0 + float(j) * 7.0), 1.6, float(j), details_group)

	var sign_model := _bake_asset("sign", HUBS[0] + Vector3(3.6, 0.15, -2.0), 2.8, 0.0, details_group)
	sign_model.name = "StartSignModel"

	var sign_back := MeshInstance3D.new()
	sign_back.name = "StartSignBack"
	var sign_back_mesh := BoxMesh.new()
	sign_back_mesh.size = Vector3(4.75, 1.05, 0.16)
	sign_back.mesh = sign_back_mesh
	sign_back.material_override = materials["gold"]
	sign_back.position = sign_model.position + Vector3(0.0, 1.58, 0.18)
	details_group.add_child(sign_back)

	var sign_face := MeshInstance3D.new()
	sign_face.name = "StartSignFace"
	var sign_face_mesh := BoxMesh.new()
	sign_face_mesh.size = Vector3(4.55, 0.86, 0.18)
	sign_face.mesh = sign_face_mesh
	sign_face.material_override = materials["wood"]
	sign_face.position = sign_back.position + Vector3(0.0, 0.0, 0.03)
	details_group.add_child(sign_face)

	var sign_text := Label3D.new()
	sign_text.name = "StartSignText"
	sign_text.text = tr("PLATFORM_START_SIGN")
	sign_text.font_size = 48
	sign_text.pixel_size = 0.0062
	sign_text.outline_size = 4
	sign_text.modulate = Color("fff3d0")
	sign_text.outline_modulate = Color("4e2c34")
	sign_text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_text.double_sided = true
	sign_text.position = sign_face.position + Vector3(0.0, 0.0, 0.12)
	details_group.add_child(sign_text)

func _bake_blue_particles(root: Node3D) -> void:
	var particle_mat := ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_mat.emission_box_extents = Vector3(55.0, 16.0, 120.0)
	particle_mat.direction = Vector3(0.0, 1.0, 0.0)
	particle_mat.spread = 22.0
	particle_mat.gravity = Vector3(0.0, 0.25, 0.0)
	particle_mat.initial_velocity_min = 0.4
	particle_mat.initial_velocity_max = 1.2
	particle_mat.color = Color("76d5ff")

	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18

	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = Color("8ee2ff")
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_mat.albedo_color.a = 0.72
	sphere.material = draw_mat

	var particles := GPUParticles3D.new()
	particles.name = "ParticulasAzuis"
	particles.process_material = particle_mat
	particles.draw_pass_1 = sphere
	particles.amount = 140
	particles.lifetime = 6.0
	particles.position = Vector3(0.0, 8.0, -80.0)
	root.add_child(particles)

func _bake_pentagrams(geometry: Node3D) -> void:
	var pent_group := Node3D.new()
	pent_group.name = "Pentagramas"
	geometry.add_child(pent_group)

	for i in range(1, HUBS.size()):
		_bake_single_pentagram("hub_%d" % i, HUBS[i] + Vector3.UP * 1.45, pent_group)
	for i in range(ROUTES.size()):
		var route: Vector2i = ROUTES[i]
		var steps := ceili(HUBS[route.x].distance_to(HUBS[route.y]) / 4.2)
		var middle_step := floori(float(steps) * 0.5) + (1 if i in BLADE_ROUTE_IDS else 0)
		var middle: Vector3 = HUBS[route.x].lerp(HUBS[route.y], float(middle_step) / float(steps))
		_bake_single_pentagram("route_%d" % i, middle + Vector3.UP * 1.45, pent_group)
	for i in range(1, HUBS.size() - 1):
		var hub: Vector3 = HUBS[i]
		var side := -1.0 if hub.x < 0.0 else 1.0
		_bake_single_pentagram("high_%d" % i, hub + Vector3(side * 11.0, 5.55, -4.0), pent_group)

func _bake_single_pentagram(id: String, position: Vector3, parent: Node3D) -> void:
	var item := Node3D.new()
	item.name = "Pentagrama_" + id
	item.position = position
	var sprite := Sprite3D.new()
	sprite.name = "Sprite3D"
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.pixel_size = 0.0031
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	item.add_child(sprite)
	parent.add_child(item)

func _bake_enemies(enemies: Node3D, root: Node3D) -> void:
	for i in range(HUBS.size()):
		for j in range(3 if i == 0 else 4):
			var enemy := Area3D.new()
			enemy.set_script(ENEMY_SCRIPT)
			enemy.name = "Inimigo_%d_%d" % [i, j]
			var x := -5.0 + float(j % 2) * 10.0
			var z := -4.0 + float(j / 2) * 7.0
			enemy.position = HUBS[i] + Vector3(x, 0.2, z)
			enemies.add_child(enemy)

func _bake_mini_secos(enemies: Node3D, root: Node3D) -> void:
	for hub_index in range(1, HUBS.size() - 1):
		var hub: Vector3 = HUBS[hub_index]
		var side := -1.0 if hub.x < 0.0 else 1.0
		var balcony := hub + Vector3(side * 11.0, 4.3, -4.0)
		var seco_balcony := Area3D.new()
		seco_balcony.set_script(MINI_SECO_SCRIPT)
		seco_balcony.name = "MiniSeco_Balcony_%d" % hub_index
		seco_balcony.position = balcony
		enemies.add_child(seco_balcony)

		if hub_index % 2 == 1:
			var overlook := hub + Vector3(side * 17.2, 3.6, -7.3)
			var seco_overlook := Area3D.new()
			seco_overlook.set_script(MINI_SECO_SCRIPT)
			seco_overlook.name = "MiniSeco_Overlook_%d" % hub_index
			seco_overlook.position = overlook
			enemies.add_child(seco_overlook)

	for hub_index in [2, 4, 6, 8, 10, 12]:
		var hub: Vector3 = HUBS[hub_index]
		var seco_hub := Area3D.new()
		seco_hub.set_script(MINI_SECO_SCRIPT)
		seco_hub.name = "MiniSeco_Hub_%d" % hub_index
		seco_hub.position = hub + Vector3(-3.5 if hub_index % 4 == 0 else 3.5, 0.3, 2.0)
		enemies.add_child(seco_hub)

func _bake_lips(enemies: Node3D, root: Node3D) -> void:
	var lips := Node3D.new()
	lips.set_script(LIPS_SCRIPT)
	lips.name = "LipsGargaroker"
	lips.position = HUBS[4] + Vector3(0.0, 0.2, 0.0)
	enemies.add_child(lips)
