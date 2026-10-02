@tool
extends SceneTree

# Executar manualmente apenas para criar outra versão. Nunca roda ao abrir/jogar.
# Saída alternativa evita sobrescrever ajustes manuais na cena entregue.
const BASE := "res://scenes/3D/resgate_cabeludo/"
const CODE := "res://scripts/3D/resgate_cabeludo/"
const KENNEY := "res://assets/kenney/platformer_3d/"
var assets:Dictionary = {}
var mats:Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 73194
	call_deferred("build")

func material(color:String) -> StandardMaterial3D:
	if not mats.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.95
		mats[color] = mat
	return mats[color]

func group(parent:Node, label:String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

func model(parent:Node, label:String, path:String, at:Vector3, size:Vector3 = Vector3.ONE) -> Node3D:
	if not assets.has(path):
		assets[path] = load(path)
	var node:Node3D = assets[path].instantiate()
	node.name = label
	node.position = at
	node.scale = size
	parent.add_child(node)
	return node

func mesh(parent:Node, label:String, resource:Mesh, at:Vector3, color:String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = resource
	node.position = at
	node.material_override = material(color)
	node.visibility_range_end = 180.0
	parent.add_child(node)
	return node

func box(parent:Node, label:String, at:Vector3, size:Vector3, color:String, solid:bool = true) -> Node3D:
	var node := StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	var resource := BoxMesh.new()
	resource.size = size
	mesh(node, "Mesh", resource, Vector3.ZERO, color)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node

func sprite(parent:Node, label:String, path:String, at:Vector3, width:float) -> Sprite3D:
	var node := Sprite3D.new()
	node.name = label
	node.texture = load(path)
	node.pixel_size = width / node.texture.get_width()
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.position = at
	parent.add_child(node)
	return node

func element(parent:Node, label:String, kind:String, at:Vector3) -> Node3D:
	var node := group(parent, label)
	node.set_script(load(CODE + "element.gd"))
	node.kind = kind
	node.position = at
	return node

func label(parent:Node, title:String, at:Vector2, size:Vector2, font_size:int = 26) -> Label:
	var node := Label.new()
	node.name = title
	node.position = at
	node.size = size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_outline_color", Color("15291e"))
	node.add_theme_constant_override("outline_size", 7)
	parent.add_child(node)
	return node

func overlay(parent:Node) -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	parent.add_child(hud)
	return hud

func fade(parent:Node) -> void:
	var rect := ColorRect.new()
	rect.name = "Fade"
	rect.color = Color.BLACK
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func own(node:Node, root_node:Node) -> void:
	if node != root_node:
		node.owner = root_node
	if node != root_node and not node.scene_file_path.is_empty():
		return
	for child in node.get_children():
		own(child, root_node)

func save_scene(root_node:Node, path:String) -> void:
	own(root_node, root_node)
	var packed := PackedScene.new()
	assert(packed.pack(root_node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	print("RESGATE_BAKED ", path, " nodes=", root_node.find_children("*", "", true, false).size())
	root_node.free()

func build() -> void:
	var overwrite := OS.get_cmdline_user_args().has("--initial-build")
	var forest_path := BASE + ("resgate_cabeludo.tscn" if overwrite else "resgate_cabeludo_generated.tscn")
	var city_path := BASE + ("city_cutscene.tscn" if overwrite else "city_cutscene_generated.tscn")
	if overwrite and not OS.get_cmdline_user_args().has("--replace-built-scenes") and (FileAccess.file_exists(forest_path) or FileAccess.file_exists(city_path)):
		push_error("Initial build recusado: cenas já existem. Use a saída _generated para preservar ajustes.")
		quit(1)
		return
	build_forest(forest_path)
	build_city(city_path)
	quit()

func ground_y(distance:float) -> float:
	if distance >= 350 and distance < 700:
		return -18.0
	if distance >= 1070 and distance < 1370:
		return 30.0
	return 0.0

func build_forest(path:String) -> void:
	var root_node := Node3D.new()
	root_node.name = "ResgateCabeludo"
	root_node.set_script(load(CODE + "stage.gd"))
	root_node.process_mode = Node.PROCESS_MODE_ALWAYS
	root_node.add_to_group("resgate_stage", true)
	var environment := WorldEnvironment.new()
	environment.name = "Morning"
	environment.environment = Environment.new()
	var env := environment.environment
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("70bce0")
	sky_mat.sky_horizon_color = Color("ffe4aa")
	sky_mat.ground_horizon_color = Color("b1c692")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e4f1c9")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("b5d2a5")
	env.fog_density = 0.0025
	root_node.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "MorningSun"
	sun.rotation_degrees = Vector3(-32, -35, 0)
	sun.light_color = Color("fff0ca")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	root_node.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 5.5, 9.5)
	camera.rotation_degrees.x = -18
	camera.current = true
	camera.far = 260
	camera.fov = 65
	root_node.add_child(camera)
	var player := CharacterBody3D.new()
	player.name = "Maycon"
	player.set_script(load(CODE + "player.gd"))
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.collision_layer = 2
	player.collision_mask = 1
	player.floor_snap_length = 0.25
	root_node.add_child(player)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.65
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.83
	player.add_child(collision)
	var preview := model(player, "Preview", "res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb", Vector3.ZERO)
	preview.rotation.y = PI
	var scenery := group(root_node, "Forest")
	var entities := group(root_node, "Course")
	entities.process_mode = Node.PROCESS_MODE_PAUSABLE
	var effects := group(root_node, "Effects")
	effects.process_mode = Node.PROCESS_MODE_PAUSABLE
	var zones:Array[Node3D] = []
	for zone in ["01_Clareira", "02_Desfiladeiro", "03_Raizes", "04_Copas", "05_FlorestaAntiga"]:
		zones.append(group(scenery, zone))
	var ranges := [[-15, 350, 0], [350, 660, 1], [700, 1040, 2], [1070, 1370, 3], [1370, 1780, 4]]
	for section in ranges:
		var begin:int = section[0]
		var end:int = section[1]
		var zone:Node3D = zones[section[2]]
		var distance := begin
		while distance < end:
			var length := minf(20, end - distance)
			var height := ground_y(distance + 1)
			var gap := 3.2 if distance > begin + 60 and distance < end - 45 and posmod(distance - begin, 100) == 0 else 0.0
			var width := 8.0 if section[2] == 3 else 12.0
			box(zone, "Trail_%04d" % distance, Vector3(0, height - 1.0, -distance - (length - gap) * 0.5), Vector3(width, 2, length - gap), "876644" if section[2] == 3 else "617547")
			# Bordas vegetadas separadas da trilha; cada peça continua editável.
			for side in [-1, 1]:
				if section[2] != 3:
					box(zone, "Bank", Vector3(side * 14, height - 1.8, -distance - length * 0.5), Vector3(14, 3.2, length), "3f6a3c", false)
				else:
					box(zone, "RopeRail", Vector3(side * 4.1, height + 0.65, -distance - length * 0.5), Vector3(0.14, 0.14, length), "bea06a", false)
			distance += 20
	# Plataformas largas para pousar após cada trampolim.
	box(zones[2], "SpringLanding", Vector3(0, -1, -707), Vector3(16, 2, 14), "617547")
	box(zones[3], "CanopyLanding", Vector3(0, 29, -1077), Vector3(14, 2, 14), "876644")
	for d in range(0, 1780, 8):
		var h := ground_y(d)
		var zone := zones[0 if d < 350 else 1 if d < 700 else 2 if d < 1070 else 3 if d < 1370 else 4]
		for side in [-1, 1]:
			var x:float = side * rng.randf_range(9, 19)
			var tall := rng.randf_range(3.5, 6.5)
			var tree := model(zone, "Tree_%04d" % d, KENNEY + ("tree.glb" if d % 24 else "tree-pine.glb"), Vector3(x, h - (12 if d >= 1070 and d < 1370 else 0), -d), Vector3.ONE * tall)
			tree.rotation.y = rng.randf_range(0, TAU)
			for j in 2:
				var prop:String = ["plant.glb", "mushrooms.glb", "flowers.glb", "grass.glb", "rocks.glb"][(d / 8 + j) as int % 5]
				model(zone, "Understory", KENNEY + prop, Vector3(side * rng.randf_range(6.5, 10), h, -d - j * 3), Vector3.ONE * rng.randf_range(1.0, 2.2))
		if d % 40 == 0:
			var animal := element(entities, "Butterfly_%04d" % d, "butterfly", Vector3(3, h + 2.4, -d))
			var wing := SphereMesh.new()
			wing.radius = 0.22
			wing.height = 0.04
			mesh(animal, "Left", wing, Vector3(-0.18, 0, 0), "f3bc54")
			mesh(animal, "Right", wing, Vector3(0.18, 0, 0), "e8853d")
	for d in range(28, 1740, 16):
		if (d > 630 and d < 728) or (d > 1010 and d < 1100) or (d > 1340 and d < 1405) or (d > 330 and d < 380):
			continue
		var h := ground_y(d)
		var x := float((d / 16) as int % 3 - 1) * 2.6
		var crate := element(entities, "Crate_%04d" % d, "bounce_crate" if d % 48 == 28 else "crate", Vector3(x, h, -d))
		model(crate, "Visual", KENNEY + "crate.glb", Vector3.ZERO, Vector3.ONE)
		var body := box(crate, "Body", Vector3(0, 0.5, 0), Vector3(1, 1, 1), "b8854d")
		body.get_node("Mesh").visible = false
		if crate.kind == "bounce_crate":
			sprite(crate, "PentagramMark", "res://assets/3D/pentagram_item.png", Vector3(0, 1.25, 0), 0.55)
		for j in 3:
			var item := element(entities, "Pentagram_%04d_%d" % [d, j], "pentagram", Vector3(-x, h + 0.9, -d - j * 2))
			sprite(item, "Visual", "res://assets/3D/pentagram_item.png", Vector3.ZERO, 0.65)
	for d in range(48, 1730, 32):
		if (d > 620 and d < 730) or (d > 1000 and d < 1100) or (d > 1330 and d < 1410) or (d > 325 and d < 380):
			continue
		var enemy := group(entities, "Enemy_%04d" % d)
		enemy.set_script(load(CODE + "enemy.gd"))
		enemy.position = Vector3(0, ground_y(d), -d)
		enemy.behavior = ["patrol", "charge", "jumper", "caster"][(d / 32) as int % 4]
		enemy.blood_drop = d % 96 == 48
		if enemy.behavior == "caster":
			var tex := sprite(enemy, "Sprite", "res://assets/novas_imagens/inimigos/craftpix-net-131479-free-satyr-sprite-sheet-pixel-art-pack/Satyr_1/Walk.png", Vector3(0, 1, 0), 12)
			tex.hframes = 8
		else:
			model(enemy, "Visual", KENNEY + ["character-oopi.glb", "character-oodi.glb", "character-ooli.glb", "character-oozi.glb"][(d / 32) as int % 4], Vector3.ZERO, Vector3.ONE * 1.2)
	for d in range(90, 1720, 70):
		if (d > 620 and d < 735) or (d > 1000 and d < 1110) or (d > 1325 and d < 1415) or (d > 325 and d < 385):
			continue
		var hazard := element(entities, "SwingingLog_%04d" % d, "hazard", Vector3(0, ground_y(d) + 0.6, -d))
		hazard.travel = Vector3(4.4, 0, 0)
		hazard.frequency = 1.2
		var log_mesh := CylinderMesh.new()
		log_mesh.height = 2.4
		log_mesh.top_radius = 0.5
		log_mesh.bottom_radius = 0.5
		var log_visual := mesh(hazard, "Log", log_mesh, Vector3.ZERO, "6a432d")
		log_visual.rotation.x = PI * 0.5
	for d in [20, 220, 390, 590, 730, 940, 1100, 1280, 1420, 1620, 1760]:
		var checkpoint := element(entities, "Checkpoint_%04d" % d, "checkpoint", Vector3(0, ground_y(d), -d))
		model(checkpoint, "Flag", KENNEY + "flag.glb", Vector3(4.5, 0, 0), Vector3.ONE * 2)
	for pair in [[650, Vector3(0, 0.3, -708), 3.3], [1030, Vector3(0, 30.3, -1078), 3.4]]:
		var spring := element(entities, "MagicSpring_%d" % pair[0], "spring", Vector3(0, ground_y(pair[0]), -pair[0]))
		spring.launch_target = pair[1]
		spring.launch_duration = pair[2]
		model(spring, "Visual", KENNEY + "spring.glb", Vector3.ZERO, Vector3.ONE * 1.8)
		var light := OmniLight3D.new()
		light.position.y = 1.0
		light.light_color = Color("51e9ff")
		light.light_energy = 2
		light.omni_range = 5
		spring.add_child(light)
	build_arena(root_node)
	var intro := group(root_node, "Introduction")
	for point in [Vector3(12, 10, -80), Vector3(-12, -8, -500), Vector3(16, 42, -1210), Vector3(-13, 10, -1670)]:
		var marker := Marker3D.new()
		marker.name = "ForestShot"
		marker.position = point
		marker.rotation = Vector3(-0.25, 0.25 if point.x > 0 else -0.25, 0)
		intro.add_child(marker)
	build_hud(root_node)
	save_scene(root_node, path)

func build_arena(root_node:Node3D) -> void:
	var arena := group(root_node, "Arena")
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	box(arena, "Floor", Vector3(0, -1, -1800), Vector3(40, 2, 50), "617547")
	for side in [-1, 1]:
		box(arena, "Cliff", Vector3(side * 21, 5, -1800), Vector3(3, 12, 50), "51634b")
		for i in 4:
			box(arena, "ClimbStep", Vector3(side * (15 - i * 2.1), 0.7 * (i + 1), -1800), Vector3(2.8, 1.4 * (i + 1), 6), "857d60")
		for d in range(1780, 1825, 8):
			model(arena, "AncientTree", KENNEY + "tree.glb", Vector3(side * 18, 0, -d), Vector3.ONE * 7)
	box(arena, "EndWall", Vector3(0, 4, -1825), Vector3(40, 10, 2), "51634b")
	var gate := box(arena, "Gate", Vector3(0, 3, -1776), Vector3(40, 6, 1), "735635")
	gate.visible = false
	gate.get_node("CollisionShape3D").disabled = true
	var lips := group(arena, "Lips")
	lips.set_script(load(CODE + "lips.gd"))
	lips.position = Vector3(0, 0, -1800)
	model(lips, "Visual", "res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb", Vector3(0, 2.28, 0), Vector3.ONE * 2.4)
	sprite(lips, "Hair", "res://assets/novas_imagens/cabelo/cabelo_idle.png", Vector3(0, 2.7, 1.3), 1.5)
	var ring := CylinderMesh.new()
	ring.top_radius = 6
	ring.bottom_radius = 6
	ring.height = 0.04
	var warning := mesh(lips, "Warning", ring, Vector3.ZERO, "ed6240")
	warning.visible = false

func build_hud(root_node:Node3D) -> void:
	var hud := overlay(root_node)
	var stats := Control.new()
	stats.name = "Stats"
	hud.add_child(stats)
	label(stats, "Blood", Vector2(28, 15), Vector2(350, 36))
	var health := ProgressBar.new()
	health.name = "Health"
	health.position = Vector2(28, 55)
	health.size = Vector2(260, 18)
	health.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("be263c")
	health.add_theme_stylebox_override("fill", fill)
	stats.add_child(health)
	label(stats, "Charge", Vector2(28, 80), Vector2(470, 40), 23)
	label(stats, "Boss", Vector2(28, 122), Vector2(480, 40), 25)
	var hint := label(hud, "Hint", Vector2.ZERO, Vector2.ZERO, 21)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -60
	hint.offset_left = 20
	hint.offset_right = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := Control.new()
	title.name = "Title"
	hud.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var top := label(title, "Resgate", Vector2(-350, -105), Vector2(700, 115), 88)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_theme_color_override("font_color", Color("ffdb39"))
	var bottom := label(title, "Cabeludo", Vector2(-350, 12), Vector2(700, 80), 58)
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_theme_color_override("font_color", Color("ed343c"))
	var pause := label(hud, "Pause", Vector2.ZERO, Vector2.ZERO, 36)
	pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause.offset_left = -350
	pause.offset_right = 350
	pause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var power := TextureRect.new()
	power.name = "Power"
	power.texture = load("res://assets/3D/pentagram_item.png")
	power.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	power.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(power)
	power.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade(hud)

func build_city(path:String) -> void:
	var root_node := Node3D.new()
	root_node.name = "ResgateCityCutscene"
	root_node.set_script(load(CODE + "city_cutscene.gd"))
	var lips := group(root_node, "Lips")
	lips.position = Vector3(0, 0, 24)
	var model_lips := model(lips, "Visual", "res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb", Vector3(0, 1.8, 0), Vector3.ONE * 1.9)
	model_lips.rotation.y = PI
	var maycon := model(root_node, "Maycon", "res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb", Vector3(0, 0, 8))
	maycon.rotation.y = PI
	var plane:Node3D = load("res://scripts/3D/aviao_modelo.gd").criar_aviao("Plane")
	plane.position = Vector3(0, 30, -15)
	root_node.add_child(plane)
	sprite(root_node, "Hair", "res://assets/novas_imagens/cabelo/cabelo_idle.png", Vector3(0, 1.3, 0), 1.5)
	sprite(root_node, "Cigarro", "res://assets/novas_imagens/cigarro/cigarro.png", Vector3(12, 13, -102), 3.0)
	# Apoio próprio para manter o Cigarro sobre um telhado em qualquer ajuste da rua.
	box(root_node, "CigarroBuilding", Vector3(14, 5.2, -102), Vector3(10, 10.4, 12), "4d5261", false)
	box(root_node, "CigarroRoof", Vector3(14, 10.6, -102), Vector3(11, 0.5, 13), "7d8292", false)
	model(root_node, "Spring", KENNEY + "spring.glb", Vector3(0, 0, -113), Vector3.ONE * 1.8)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 65
	camera.far = 1600
	root_node.add_child(camera)
	var rim := DirectionalLight3D.new()
	rim.name = "NightRim"
	rim.rotation_degrees = Vector3(-38, -32, 0)
	rim.light_color = Color("9fc9ff")
	rim.light_energy = 0.42
	rim.shadow_enabled = false
	root_node.add_child(rim)
	var fill := OmniLight3D.new()
	fill.name = "ActionFill"
	fill.position = Vector3(0, 14, -90)
	fill.omni_range = 180
	fill.light_energy = 1.2
	fill.light_color = Color("bfd7ec")
	root_node.add_child(fill)
	var magic := CPUParticles3D.new()
	magic.name = "Magic"
	magic.emitting = false
	magic.one_shot = true
	magic.amount = 90
	magic.lifetime = 3.5
	magic.explosiveness = 0.8
	magic.direction = Vector3.UP
	magic.initial_velocity_min = 8
	magic.initial_velocity_max = 25
	magic.gravity = Vector3(0, -2, 0)
	magic.scale_amount_min = 0.07
	magic.scale_amount_max = 0.22
	var sparkle := SphereMesh.new()
	sparkle.material = material("7af7ee")
	magic.mesh = sparkle
	root_node.add_child(magic)
	var hud := overlay(root_node)
	var phrase := label(hud, "Phrase", Vector2.ZERO, Vector2(500, 65), 44)
	phrase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fade(hud)
	save_scene(root_node, path)
