extends Node3D

const MAYCON_SCENE = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const MAYCON_MENU_ANIMATIONS = preload("res://assets/novas_imagens/3d_enemies/menu_maycon_animations.res")
const MENU_FONT = preload("res://assets/fonts/contrast.ttf")
const SKY_SHADER = preload("res://scenes/3D/menu_night_sky.gdshader")
const WATER_SHADER = preload("res://scenes/3D/menu_ocean.gdshader")
const SAND_SHADER = preload("res://scenes/3D/menu_sand.gdshader")
const GLOW_SHADER = preload("res://scenes/3D/menu_moon_glow.gdshader")
const MOON_SURFACE_SHADER = preload("res://scenes/3D/menu_moon_surface.gdshader")
const MEMORY_SHADER = preload("res://scenes/3D/menu_memory.gdshader")
const STAR_SHADER = preload("res://scenes/3D/menu_stars.gdshader")
const MIST_SHADER = preload("res://scenes/3D/menu_horizon_mist.gdshader")

const LOOK_OUT_DURATION := 3.4
const WALK_START := 5.0
const WALK_DURATION := 28.0
const TURN_DURATION := 4.5
const MEMORY_START := 36.5
const MEMORY_FULL := 45.5
const TAKE_WIDE := 0
const TAKE_LOW := 1
const TAKE_POV := 2

@export var load_from_castle_1: bool = false
@export var load_from_outside_1: bool = false
@export var enable_debug_tab: bool = true

var elapsed := 0.0
var maycon: Node3D
var maycon_animation: AnimationPlayer
var camera: Camera3D
var take_cameras: Array[Camera3D] = []
var take_rng := RandomNumberGenerator.new()
var take_order: Array[int] = []
var current_take := TAKE_WIDE
var previous_take := TAKE_WIDE
var transition_start := -10.0
var next_take_time := WALK_START + 4.5
var pov_start_time := -1.0
var memory_material: ShaderMaterial
var moon_glow_material: ShaderMaterial
var menu_panel: Control
var fade_rect: ColorRect
var memory_sound: AudioStreamPlayer
var sand_steps: AudioStreamPlayer
var memory_sound_played := false
var leaving := false


func _ready() -> void:
	Global.load_from_castle_1 = load_from_castle_1
	Global.load_from_outside_1 = load_from_outside_1
	Global.show_debug_tab = enable_debug_tab
	take_rng.randomize()
	_build_world()
	_build_interface()
	_build_audio()
	_update_cinematic(0.0, 0.0)
	var reveal := create_tween()
	reveal.tween_property(fade_rect, "color:a", 0.0, 2.8).set_trans(Tween.TRANS_SINE)
	reveal.parallel().tween_property(menu_panel, "modulate:a", 1.0, 3.6).set_trans(Tween.TRANS_SINE)
	get_node("UI/Layout/MenuPanel/Stack/Buttons/NewGame").grab_focus.call_deferred()


func _process(delta: float) -> void:
	if leaving:
		return
	elapsed += delta
	_update_cinematic(elapsed, delta)


func _material(shader: Shader) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = shader
	return result


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var world := Environment.new()
	var sky := Sky.new()
	sky.sky_material = _material(SKY_SHADER)
	world.background_mode = Environment.BG_SKY
	world.sky = sky
	world.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	world.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.fog_enabled = true
	world.fog_light_color = Color(0.055, 0.20, 0.25)
	world.fog_density = 0.006
	environment.environment = world
	add_child(environment)
	var moonlight := DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-35, -25, 0)
	moonlight.light_color = Color(0.55, 0.78, 0.94)
	moonlight.light_energy = 0.72
	moonlight.shadow_enabled = true
	add_child(moonlight)
	var horizon_light := OmniLight3D.new()
	horizon_light.position = Vector3(6, 6, -10)
	horizon_light.light_color = Color(0.12, 0.68, 0.78)
	horizon_light.light_energy = 0.8
	horizon_light.omni_range = 24.0
	add_child(horizon_light)
	_build_sand()
	_build_ocean()
	_build_mist()
	_build_moon()
	_build_stars()
	_build_memory()
	_build_beach_details()
	_add_palm(Vector3(19, 0, 2), 7.5)
	_add_palm(Vector3(-24, 0, 4), 5.8)
	maycon = Node3D.new()
	maycon.name = "MayconCinematic"
	maycon.position = Vector3(-15, 0.08, 2.7)
	add_child(maycon)
	var model := MAYCON_SCENE.instantiate()
	model.name = "MayconModel"
	maycon.add_child(model)
	maycon_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if maycon_animation:
		if not maycon_animation.has_animation("Walking"):
			if maycon_animation.get_animation_library_list().has(""):
				maycon_animation.remove_animation_library("")
			maycon_animation.add_animation_library("", MAYCON_MENU_ANIMATIONS)
		maycon_animation.get_animation("Walking").loop_mode = Animation.LOOP_LINEAR
		maycon_animation.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		maycon_animation.play("Idle")
		maycon_animation.speed_scale = 0.78
	camera = Camera3D.new()
	camera.name = "CinematicCamera"
	camera.fov = 57.0
	camera.near = 0.1
	camera.far = 260.0
	camera.current = true
	add_child(camera)
	for take_name in ["WideTake", "LowShoreTake", "MayconEyesTake"]:
		var take_camera := Camera3D.new()
		take_camera.name = take_name
		take_camera.current = false
		add_child(take_camera)
		take_cameras.append(take_camera)


func _build_sand() -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const X_STEPS := 92
	const Z_STEPS := 56
	for zi in range(Z_STEPS + 1):
		var z := float(zi) * 1.25 - 0.15
		for xi in range(X_STEPS + 1):
			var x := float(xi) * 1.55 - 66.0
			var swell := sin(x * 0.17) * 0.10 + sin(x * 0.43 + z * 0.26) * 0.055
			var dune := pow(maxf(z - 8.0, 0.0) / 34.0, 1.7) * 2.0
			var y := 0.02 + dune + swell * smoothstep(1.0, 5.0, z)
			vertices.append(Vector3(x, y, z))
			uvs.append(Vector2(x * 0.12, z * 0.12))
			if xi < X_STEPS and zi < Z_STEPS:
				var a := zi * (X_STEPS + 1) + xi
				indices.append_array(PackedInt32Array([a, a + X_STEPS + 1, a + 1, a + 1, a + X_STEPS + 1, a + X_STEPS + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material(SAND_SHADER))
	var sand := MeshInstance3D.new()
	sand.name = "MoonlitBeach"
	sand.mesh = mesh
	add_child(sand)


func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(170, 150)
	plane.subdivide_width = 124
	plane.subdivide_depth = 92
	plane.material = _material(WATER_SHADER)
	var ocean := MeshInstance3D.new()
	ocean.name = "MovingOcean"
	ocean.mesh = plane
	ocean.position = Vector3(6, -0.12, -75)
	add_child(ocean)
	var foam := MeshInstance3D.new()
	foam.name = "ShoreFoam"
	var foam_mesh := PlaneMesh.new()
	foam_mesh.size = Vector2(150, 2.3)
	foam_mesh.subdivide_width = 70
	foam_mesh.material = _material(WATER_SHADER)
	foam.mesh = foam_mesh
	foam.position = Vector3(6, -0.08, -0.45)
	add_child(foam)


func _build_moon() -> void:
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var sphere := SphereMesh.new()
	sphere.radius = 3.2
	sphere.height = 6.4
	sphere.radial_segments = 32
	sphere.rings = 16
	sphere.material = _material(MOON_SURFACE_SHADER)
	moon.mesh = sphere
	moon.position = Vector3(2, 19, -86)
	add_child(moon)
	var halo := MeshInstance3D.new()
	halo.name = "MoonHalo"
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(34, 34)
	moon_glow_material = _material(GLOW_SHADER)
	halo_mesh.material = moon_glow_material
	halo.mesh = halo_mesh
	halo.position = Vector3(2, 19, -87)
	add_child(halo)


func _build_mist() -> void:
	for i in range(2):
		var mist := MeshInstance3D.new()
		mist.name = "HorizonMist"
		var quad := QuadMesh.new()
		quad.size = Vector2(160, 14)
		quad.material = _material(MIST_SHADER)
		mist.mesh = quad
		mist.position = Vector3(0, 2.0 + i * 1.8, -46 - i * 16)
		add_child(mist)


func _build_memory() -> void:
	var ghost := MeshInstance3D.new()
	ghost.name = "CabeloInTheSky"
	var quad := QuadMesh.new()
	quad.size = Vector2(22, 26)
	memory_material = _material(MEMORY_SHADER)
	memory_material.set_shader_parameter("portrait", load("res://assets/images/TELA-intro-03 _0.png"))
	memory_material.set_shader_parameter("reveal", 0.0)
	quad.material = memory_material
	ghost.mesh = quad
	ghost.position = Vector3(27, 16, -63)
	add_child(ghost)


func _build_stars() -> void:
	var stars := MultiMeshInstance3D.new()
	stars.name = "DistantStars"
	var mesh := QuadMesh.new()
	mesh.material = _material(STAR_SHADER)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = 210
	var rng := RandomNumberGenerator.new()
	rng.seed = 71521
	for i in range(multi.instance_count):
		var size := rng.randf_range(0.20, 0.56)
		var position := Vector3(rng.randf_range(-110, 110), rng.randf_range(15, 72), -105)
		multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(size, size, size)), position))
		multi.set_instance_color(i, Color(0.58 + rng.randf() * 0.30, 0.76 + rng.randf() * 0.20, 1.0, rng.randf_range(0.45, 0.95)))
	stars.multimesh = multi
	add_child(stars)


func _add_palm(base: Vector3, height: float) -> void:
	var palm := Node3D.new()
	palm.name = "CoastalPalm"
	palm.position = base
	add_child(palm)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.08, 0.11, 0.105)
	bark.roughness = 1.0
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.025, 0.11, 0.11)
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaves.roughness = 1.0
	var points := []
	for i in range(7):
		var fraction := float(i) / 7.0
		points.append(Vector3(fraction * 1.4, fraction * height, sin(fraction * 2.0) * 0.3))
	points.append(Vector3(1.5, height, 0.3))
	for i in range(7):
		var direction: Vector3 = points[i + 1] - points[i]
		var section := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.height = direction.length() * 1.15
		cylinder.bottom_radius = lerpf(0.30, 0.14, float(i) / 7.0)
		cylinder.top_radius = lerpf(0.27, 0.10, float(i) / 7.0)
		cylinder.radial_segments = 6
		cylinder.material = bark
		section.mesh = cylinder
		section.position = (points[i] + points[i + 1]) * 0.5
		section.quaternion = Quaternion(Vector3.UP, direction.normalized())
		palm.add_child(section)
	var crown: Vector3 = points[7]
	for i in range(9):
		var angle := float(i) / 9.0 * TAU
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-direction.z, 0, direction.x)
		var reach := height * (0.45 if i % 2 == 0 else 0.34)
		var vertices := PackedVector3Array([
			crown,
			crown + direction * (reach * 0.47) + side * 0.55 + Vector3.UP * 0.45,
			crown + direction * (reach * 0.47) - side * 0.55 + Vector3.UP * 0.45,
			crown + direction * reach + Vector3.DOWN * (reach * 0.29)
		])
		var indices := PackedInt32Array([0, 1, 2, 1, 3, 2])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var leaf_mesh := ArrayMesh.new()
		leaf_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		leaf_mesh.surface_set_material(0, leaves)
		var leaf := MeshInstance3D.new()
		leaf.mesh = leaf_mesh
		palm.add_child(leaf)


func _build_beach_details() -> void:
	var stone_material := StandardMaterial3D.new()
	stone_material.albedo_color = Color(0.065, 0.13, 0.15)
	stone_material.roughness = 0.95
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = Color(0.025, 0.13, 0.14)
	grass_material.roughness = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 83914
	for i in range(82):
		var x := rng.randf_range(-48, 58)
		var z := rng.randf_range(5.5, 42.0)
		if absf(x) < 21 and z < 10:
			continue
		var size := rng.randf_range(0.16, 0.8)
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = size
		mesh.height = size * 0.72
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = stone_material
		rock.mesh = mesh
		rock.position = Vector3(x, 0.04, z)
		rock.rotation.y = rng.randf_range(0, TAU)
		add_child(rock)
	for i in range(140):
		var x := rng.randf_range(-58, 65)
		var z := rng.randf_range(12, 65)
		var tuft := MeshInstance3D.new()
		var blade := CylinderMesh.new()
		blade.top_radius = 0.0
		blade.bottom_radius = rng.randf_range(0.035, 0.09)
		blade.height = rng.randf_range(0.3, 1.1)
		blade.radial_segments = 3
		blade.material = grass_material
		tuft.mesh = blade
		tuft.position = Vector3(x, 0.28, z)
		tuft.rotation.z = rng.randf_range(-0.4, 0.4)
		add_child(tuft)


func _update_cinematic(time: float) -> void:
	var walk := clampf(time / WALK_DURATION, 0.0, 1.0)
	maycon.position.x = lerpf(-15.0, 7.0, walk)
	maycon.position.y = 0.08 + sin(time * 1.9) * 0.018 * (1.0 - walk)
	var turn := smoothstep(WALK_DURATION, WALK_DURATION + TURN_DURATION, time)
	maycon.rotation.y = lerp_angle(PI * 0.5, PI, turn)
	if time >= WALK_DURATION and maycon_animation and maycon_animation.current_animation != "Idle":
		maycon_animation.play("Idle", 1.8)
		if sand_steps:
			sand_steps.stop()
	var shot_a := _camera_pose(Vector3(maycon.position.x + 6, 3.4, 12), Vector3(maycon.position.x + 0.5, 1.4, -5.5))
	var shot_b := _camera_pose(Vector3(maycon.position.x + 8.5, 2.5, 3.5), Vector3(maycon.position.x - 1.3, 1.4, -4.8))
	var shot_c := _camera_pose(Vector3(maycon.position.x - 5, 1.5, 6.5), Vector3(maycon.position.x + 1, 1.8, -8))
	var shot_d := _camera_pose(Vector3(8, 4.4, 22), Vector3(0, 5.2, -30))
	var pose := shot_a.interpolate_with(shot_b, smoothstep(5.0, 13.0, time))
	pose = pose.interpolate_with(shot_c, smoothstep(15.0, 24.0, time))
	pose = pose.interpolate_with(shot_d, smoothstep(26.0, 39.0, time))
	if time > 39.0:
		var drift := (time - 39.0) * 0.09
		pose.origin += Vector3(sin(drift) * 1.6, sin(drift * 0.6) * 0.28, cos(drift) * 0.7)
	camera.global_transform = pose
	camera.fov = lerpf(57.0, 51.0, smoothstep(24.0, 40.0, time))
	memory_material.set_shader_parameter("reveal", smoothstep(MEMORY_START, MEMORY_FULL, time))
	moon_glow_material.set_shader_parameter("pulse", 0.7 + sin(time * 0.38) * 0.08)
	if time >= MEMORY_START and not memory_sound_played:
		memory_sound_played = true
		memory_sound.play()


func _camera_pose(from: Vector3, toward: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(toward - from), from)


func _build_interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var root := Control.new()
	root.name = "Layout"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(root)
	var veil := ColorRect.new()
	veil.name = "LeftVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veil_shader := Shader.new()
	veil_shader.code = "shader_type canvas_item; void fragment() { float shade = 0.78 * (1.0 - smoothstep(0.02, 0.68, UV.x)); shade += 0.10 * (1.0 - smoothstep(0.55, 1.0, UV.y)); COLOR = vec4(0.008, 0.026, 0.043, shade); }"
	veil.material = _material(veil_shader)
	root.add_child(veil)
	menu_panel = Control.new()
	menu_panel.name = "MenuPanel"
	menu_panel.anchor_left = 0.065
	menu_panel.anchor_top = 0.09
	menu_panel.anchor_right = 0.48
	menu_panel.anchor_bottom = 0.92
	menu_panel.modulate.a = 0.0
	root.add_child(menu_panel)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_theme_constant_override("separation", 3)
	menu_panel.add_child(stack)
	stack.add_child(_label("MENU_NIGHT_KICKER", 15, Color(0.54, 0.82, 0.88), true))
	var title := _label("GAME_TITLE", 39, Color(0.95, 0.96, 0.92), true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title)
	stack.add_child(_label("GAME_SUBTITLE", 25, Color(0.75, 0.91, 0.92), true))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 34
	stack.add_child(spacer)
	var rule := ColorRect.new()
	rule.color = Color(0.35, 0.72, 0.77, 0.6)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(rule)
	stack.add_child(_label("MENU_NIGHT_CAPTION", 15, Color(0.67, 0.80, 0.82), false))
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	stack.add_child(gap)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 8)
	stack.add_child(buttons)
	var new_game := _menu_button("MENU_NEW_GAME", "NewGame")
	buttons.add_child(new_game)
	new_game.pressed.connect(_on_new_game_pressed)
	var continue_button := _menu_button("MENU_CONTINUE", "Continue")
	continue_button.disabled = not Global.check_load()
	buttons.add_child(continue_button)
	continue_button.pressed.connect(_on_continue_pressed)
	var settings := _menu_button("MENU_SETTINGS", "Settings")
	buttons.add_child(settings)
	settings.pressed.connect(_on_settings_pressed)
	var exit_button := _menu_button("MENU_EXIT", "Exit")
	buttons.add_child(exit_button)
	exit_button.pressed.connect(_on_exit_pressed)
	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version")), 12, Color(0.72, 0.82, 0.82, 0.75), false, false)
	version.name = "Version"
	version.anchor_left = 0.90
	version.anchor_top = 0.94
	version.anchor_right = 0.98
	version.anchor_bottom = 0.98
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(version)
	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color(0.003, 0.012, 0.026, 1.0)
	root.add_child(fade_rect)


func _label(value: String, size: int, color: Color, upper: bool, translate: bool = true) -> Label:
	var result := Label.new()
	result.text = tr(value) if translate else value
	if upper:
		result.text = result.text.to_upper()
	result.add_theme_font_override("font", MENU_FONT)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.04, 0.7))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result


func _menu_button(key: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = tr(key).to_upper()
	button.custom_minimum_size = Vector2(0, 47)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.84, 0.93, 0.93))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.82))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.82))
	button.add_theme_color_override("font_disabled_color", Color(0.4, 0.53, 0.55, 0.7))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.015, 0.085, 0.11, 0.19)
		style.border_width_left = 2
		style.border_color = Color(0.20, 0.52, 0.60, 0.42)
		style.content_margin_left = 18
		style.content_margin_right = 14
		if state == "hover" or state == "focus" or state == "pressed":
			style.bg_color = Color(0.05, 0.20, 0.24, 0.68)
			style.border_color = Color(0.67, 0.92, 0.92)
		if state == "disabled":
			style.bg_color = Color(0.01, 0.045, 0.06, 0.1)
			style.border_color = Color(0.17, 0.33, 0.36, 0.25)
		button.add_theme_stylebox_override(state, style)
	return button


func _build_audio() -> void:
	var music := AudioStreamPlayer.new()
	music.stream = load("res://assets/novos_audios/jamelao_song.mp3")
	music.volume_db = -10.0
	music.finished.connect(func(): if not leaving: music.play())
	add_child(music)
	music.play()
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/novos_audios/cidade_intro_wind.mp3")
	wind.volume_db = -23.0
	wind.finished.connect(func(): if not leaving: wind.play())
	add_child(wind)
	wind.play()
	sand_steps = AudioStreamPlayer.new()
	sand_steps.stream = load("res://assets/audio/passos_areia.mp3")
	sand_steps.volume_db = -20.0
	sand_steps.finished.connect(func(): if elapsed < WALK_DURATION and not leaving: sand_steps.play())
	add_child(sand_steps)
	sand_steps.play()
	memory_sound = AudioStreamPlayer.new()
	memory_sound.stream = load("res://assets/audio/kabelo_intro.mp3")
	memory_sound.volume_db = -8.0
	add_child(memory_sound)


func _on_new_game_pressed() -> void:
	if leaving:
		return
	leaving = true
	Global.reset_default_values()
	var transition := create_tween()
	transition.tween_property(fade_rect, "color:a", 1.0, 1.7).set_trans(Tween.TRANS_SINE)
	await transition.finished
	get_tree().change_scene_to_file("res://scenes/battle_mode_selection.tscn")


func _on_continue_pressed() -> void:
	Global.load_progress()


func _on_settings_pressed() -> void:
	get_node("ConfiguracoesDialog").abrir()


func _on_exit_pressed() -> void:
	get_tree().quit()
