extends CanvasLayer

var theme_id:String = "forest_road"
var arena_width:float = 2600.0
var stage_root:Node3D
var camera_3d:Camera3D
var display:TextureRect

const VIEWPORT_SIZE := Vector2i(1152, 648)
const COBBLE_DIFF := "res://assets/polyhaven/realtime_battle/cobblestone_floor_diff_1k.jpg"
const COBBLE_NORMAL := "res://assets/polyhaven/realtime_battle/cobblestone_floor_normal_1k.jpg"
const FOREST_DIFF := "res://assets/polyhaven/realtime_battle/forest_ground_diff_1k.jpg"
const FOREST_NORMAL := "res://assets/polyhaven/realtime_battle/forest_ground_normal_1k.jpg"
const WALL_DIFF := "res://assets/polyhaven/realtime_battle/castle_wall_diff_1k.jpg"
const WALL_NORMAL := "res://assets/polyhaven/realtime_battle/castle_wall_normal_1k.jpg"

func _ready() -> void:
	layer = -20
	build_viewport()
	build_world()

func build_viewport() -> void:
	var viewport = SubViewport.new()
	viewport.name = "Arena3DViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	viewport.own_world_3d = true
	add_child(viewport)
	stage_root = Node3D.new()
	stage_root.name = "Arena3D"
	viewport.add_child(stage_root)
	display = TextureRect.new()
	display.name = "Arena3DDisplay"
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

func build_world() -> void:
	var palette = get_palette()
	var world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = palette.sky_top
	sky_material.sky_horizon_color = palette.sky_horizon
	sky_material.ground_bottom_color = palette.ground_dark
	sky_material.ground_horizon_color = palette.sky_horizon.darkened(0.4)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = palette.ambient
	environment.ambient_light_energy = 0.72
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = palette.fog
	environment.fog_light_energy = 0.58
	environment.fog_density = 0.018
	environment.fog_sky_affect = 0.58
	world_environment.environment = environment
	stage_root.add_child(world_environment)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = palette.sun
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	stage_root.add_child(sun)

	camera_3d = Camera3D.new()
	camera_3d.position = Vector3(-17.5, 5.2, 11.8)
	camera_3d.fov = 54.0
	stage_root.add_child(camera_3d)
	camera_3d.look_at(Vector3(-17.5, 1.2, -1.5))
	camera_3d.current = true

	var use_forest_floor = theme_id == "forest_road"
	var floor_material = create_material(
		palette.floor_tint,
		FOREST_DIFF if use_forest_floor else COBBLE_DIFF,
		FOREST_NORMAL if use_forest_floor else COBBLE_NORMAL,
		10.0
	)
	add_plane(Vector3(0, -0.08, 0), Vector2(48, 13), floor_material)
	var back_wall_material = create_material(palette.wall_tint, WALL_DIFF, WALL_NORMAL, 7.0)
	if theme_id != "forest_road" && theme_id != "ash_wasteland":
		add_box(Vector3(0, 2.5, -5.2), Vector3(49, 5.0, 0.55), back_wall_material)
	build_theme_details(palette, back_wall_material)
	build_depth_props(palette)

func update_camera(player_x:float) -> void:
	if camera_3d == null:
		return
	var ratio = clampf(player_x / arena_width, 0.0, 1.0)
	var target_x = lerpf(-17.5, 17.5, ratio)
	camera_3d.position.x = lerpf(camera_3d.position.x, target_x, 0.09)
	camera_3d.look_at(Vector3(camera_3d.position.x, 1.15, -1.8))

func build_theme_details(palette:Dictionary, wall_material:StandardMaterial3D) -> void:
	match theme_id:
		"forest_road":
			for x in range(-22, 25, 4):
				add_tree(Vector3(x, 0, -4.3 + randf_range(-0.7, 0.45)), palette, 1.1 + randf_range(-0.15, 0.35))
			for x in [-15.0, -4.0, 8.0, 18.0]:
				add_rock(Vector3(x, 0.2, -1.8), palette.rock, 0.8)
		"ash_wasteland":
			for x in range(-22, 24, 5):
				add_rock(Vector3(x, 0.3, -3.0 + randf_range(-1.0, 1.0)), palette.rock, randf_range(0.8, 1.65))
				add_dead_tree(Vector3(x + 1.8, 0, -4.5), palette)
			for x in [-18.0, -7.0, 4.0, 15.0]:
				add_fire_light(Vector3(x, 0.7, -2.8), palette.fire)
		"throne_ruins":
			build_castle_columns(palette, wall_material, true)
			add_throne(Vector3(18, 0, -3.9), palette)
			for x in [-17.0, -8.0, 2.0, 11.0, 20.0]:
				add_fire_light(Vector3(x, 1.35, -4.65), palette.fire)
		"moon_courtyard":
			build_castle_columns(palette, wall_material, false)
			add_fountain(Vector3(0, 0, -2.0), palette)
			for x in [-18.0, -9.0, 9.0, 18.0]:
				add_magic_light(Vector3(x, 1.8, -4.3), palette.fire)
		_:
			build_castle_columns(palette, wall_material, false)
			for x in [-18.0, -10.0, -2.0, 6.0, 14.0, 22.0]:
				add_fire_light(Vector3(x, 1.35, -4.65), palette.fire)
			if theme_id == "abandoned_dungeon":
				for x in [-13.0, 0.0, 13.0]:
					add_rubble(Vector3(x, 0.12, -2.4), palette)

func build_depth_props(palette:Dictionary) -> void:
	for x in [-20.0, -11.0, -2.0, 7.0, 16.0, 23.0]:
		var shadow_material = create_material(Color(palette.rock, 0.88), "", "", 1.0)
		add_box(Vector3(x, 0.28, 4.9), Vector3(randf_range(0.8, 1.7), 0.55, randf_range(0.6, 1.2)), shadow_material, Vector3(0, randf_range(-35, 35), 0))

func build_castle_columns(palette:Dictionary, wall_material:StandardMaterial3D, ruined:bool) -> void:
	for x in range(-21, 24, 6):
		var height = randf_range(2.8, 5.2) if ruined else 5.2
		add_cylinder(Vector3(x, height * 0.5, -4.55), 0.52, height, wall_material)
		add_box(Vector3(x, height + 0.18, -4.55), Vector3(1.35, 0.35, 1.1), wall_material)
		if !ruined:
			add_box(Vector3(x + 3.0, 4.7, -4.8), Vector3(4.8, 0.45, 0.75), wall_material)

func add_tree(position_value:Vector3, palette:Dictionary, size_value:float) -> void:
	var trunk_material = create_material(Color("3b2418"), "", "", 1.0)
	var leaf_material = create_material(palette.leaf, "", "", 1.0)
	add_cylinder(position_value + Vector3(0, 1.4 * size_value, 0), 0.22 * size_value, 2.8 * size_value, trunk_material)
	add_sphere(position_value + Vector3(0, 3.25 * size_value, 0), Vector3(1.25, 1.5, 1.0) * size_value, leaf_material)
	add_sphere(position_value + Vector3(-0.8, 2.9, 0.15) * size_value, Vector3.ONE * 0.85 * size_value, leaf_material)
	add_sphere(position_value + Vector3(0.9, 3.05, -0.1) * size_value, Vector3.ONE * 0.9 * size_value, leaf_material)

func add_dead_tree(position_value:Vector3, palette:Dictionary) -> void:
	var material = create_material(palette.rock.darkened(0.35), "", "", 1.0)
	add_cylinder(position_value + Vector3(0, 1.6, 0), 0.16, 3.2, material, Vector3(0, 0, randf_range(-9, 9)))
	add_cylinder(position_value + Vector3(0.35, 2.6, 0), 0.08, 1.4, material, Vector3(0, 0, -50))

func add_fire_light(position_value:Vector3, color:Color) -> void:
	var flame_material = create_material(color, "", "", 1.0, color * 3.2)
	add_sphere(position_value, Vector3(0.16, 0.32, 0.16), flame_material)
	var light = OmniLight3D.new()
	light.position = position_value
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 5.5
	light.shadow_enabled = true
	stage_root.add_child(light)

func add_magic_light(position_value:Vector3, color:Color) -> void:
	var crystal_material = create_material(color, "", "", 1.0, color * 2.5)
	add_box(position_value, Vector3(0.28, 0.9, 0.28), crystal_material, Vector3(0, 0, 45))
	var light = OmniLight3D.new()
	light.position = position_value
	light.light_color = color
	light.light_energy = 2.8
	light.omni_range = 4.5
	stage_root.add_child(light)

func add_rock(position_value:Vector3, color:Color, size_value:float) -> void:
	var material = create_material(color, "", "", 1.0)
	add_sphere(position_value, Vector3(1.2, 0.65, 0.9) * size_value, material)

func add_rubble(position_value:Vector3, palette:Dictionary) -> void:
	for index in range(7):
		add_box(position_value + Vector3(randf_range(-1.2, 1.2), randf_range(0.05, 0.3), randf_range(-0.6, 0.6)), Vector3(randf_range(0.25, 0.7), randf_range(0.18, 0.45), randf_range(0.25, 0.65)), create_material(palette.rock, "", "", 1.0), Vector3(randf_range(-20, 20), randf_range(-45, 45), randf_range(-20, 20)))

func add_throne(position_value:Vector3, palette:Dictionary) -> void:
	var material = create_material(palette.accent, "", "", 1.0, palette.accent * 0.35)
	add_box(position_value + Vector3(0, 1.35, 0), Vector3(2.3, 2.7, 0.65), material)
	add_box(position_value + Vector3(0, 0.45, 0.75), Vector3(2.7, 0.45, 2.0), material)
	add_box(position_value + Vector3(-1.5, 1.1, 0.4), Vector3(0.45, 1.4, 0.55), material)
	add_box(position_value + Vector3(1.5, 1.1, 0.4), Vector3(0.45, 1.4, 0.55), material)

func add_fountain(position_value:Vector3, palette:Dictionary) -> void:
	var stone = create_material(palette.rock, "", "", 1.0)
	var water = create_material(Color("55c7e8"), "", "", 1.0, Color("2aaee8") * 0.5)
	add_cylinder(position_value + Vector3(0, 0.28, 0), 1.6, 0.42, stone)
	add_cylinder(position_value + Vector3(0, 0.54, 0), 1.28, 0.12, water)
	add_cylinder(position_value + Vector3(0, 1.0, 0), 0.18, 1.5, stone)
	add_sphere(position_value + Vector3(0, 1.85, 0), Vector3.ONE * 0.3, water)

func add_plane(position_value:Vector3, size_value:Vector2, material:Material) -> void:
	var mesh = PlaneMesh.new()
	mesh.size = size_value
	mesh.material = material
	add_mesh(mesh, position_value)

func add_box(position_value:Vector3, size_value:Vector3, material:Material, rotation_value:Vector3 = Vector3.ZERO) -> void:
	var mesh = BoxMesh.new()
	mesh.size = size_value
	mesh.material = material
	add_mesh(mesh, position_value, Vector3.ONE, rotation_value)

func add_cylinder(position_value:Vector3, radius:float, height:float, material:Material, rotation_value:Vector3 = Vector3.ZERO) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = height
	mesh.radial_segments = 12
	mesh.material = material
	add_mesh(mesh, position_value, Vector3.ONE, rotation_value)

func add_sphere(position_value:Vector3, scale_value:Vector3, material:Material) -> void:
	var mesh = SphereMesh.new()
	mesh.height = 2.0
	mesh.radius = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	add_mesh(mesh, position_value, scale_value)

func add_mesh(mesh:Mesh, position_value:Vector3, scale_value:Vector3 = Vector3.ONE, rotation_value:Vector3 = Vector3.ZERO) -> void:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation_degrees = rotation_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	stage_root.add_child(instance)

func create_material(color:Color, texture_path:String, normal_path:String, uv_scale:float, emission:Color = Color.BLACK) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	if !texture_path.is_empty() && ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
	if !normal_path.is_empty() && ResourceLoader.exists(normal_path):
		material.normal_enabled = true
		material.normal_texture = load(normal_path)
		material.normal_scale = 0.8
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.25
	return material

func get_palette() -> Dictionary:
	match theme_id:
		"inferno_castle":
			return {"sky_top":Color("130510"), "sky_horizon":Color("7a241d"), "ground_dark":Color("160b0c"), "ambient":Color("8f4b4c"), "sun":Color("ff8a4a"), "fog":Color("49151c"), "floor_tint":Color("8e6762"), "wall_tint":Color("7b554f"), "rock":Color("463331"), "leaf":Color("3c1b21"), "fire":Color("ff5b1a"), "accent":Color("9e263d")}
		"abandoned_dungeon":
			return {"sky_top":Color("07141b"), "sky_horizon":Color("234c54"), "ground_dark":Color("081013"), "ambient":Color("59808a"), "sun":Color("9de8ed"), "fog":Color("173b43"), "floor_tint":Color("768884"), "wall_tint":Color("687c78"), "rock":Color("40504e"), "leaf":Color("253e38"), "fire":Color("56e3df"), "accent":Color("3aa4a0")}
		"ash_wasteland":
			return {"sky_top":Color("190f19"), "sky_horizon":Color("81544c"), "ground_dark":Color("170f12"), "ambient":Color("806260"), "sun":Color("ffba86"), "fog":Color("513638"), "floor_tint":Color("806d67"), "wall_tint":Color("6d5a55"), "rock":Color("4b3c3d"), "leaf":Color("39262a"), "fire":Color("ff7b32"), "accent":Color("aa4c3a")}
		"throne_ruins":
			return {"sky_top":Color("080512"), "sky_horizon":Color("4c235f"), "ground_dark":Color("0b0711"), "ambient":Color("775b91"), "sun":Color("dfb3ff"), "fog":Color("32173e"), "floor_tint":Color("75637e"), "wall_tint":Color("66506f"), "rock":Color("3f3449"), "leaf":Color("2d1b39"), "fire":Color("ff3f81"), "accent":Color("8d2f79")}
		"moon_courtyard":
			return {"sky_top":Color("020a18"), "sky_horizon":Color("16496c"), "ground_dark":Color("030a11"), "ambient":Color("5986a8"), "sun":Color("d5f2ff"), "fog":Color("153d57"), "floor_tint":Color("71899a"), "wall_tint":Color("667b8d"), "rock":Color("435767"), "leaf":Color("173b3d"), "fire":Color("63d9ff"), "accent":Color("326d9b")}
		_:
			return {"sky_top":Color("06131a"), "sky_horizon":Color("3d6b64"), "ground_dark":Color("07110e"), "ambient":Color("77988b"), "sun":Color("ffe7ae"), "fog":Color("28493f"), "floor_tint":Color("819078"), "wall_tint":Color("746e61"), "rock":Color("485149"), "leaf":Color("244e3b"), "fire":Color("ffd166"), "accent":Color("587b56")}
