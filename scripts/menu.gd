extends Node3D

const MAYCON_SCENE = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const MAYCON_MENU_ANIMATIONS = preload("res://assets/novas_imagens/3d_enemies/menu_maycon_animations.res")
const MAYCON_LOOK_FORWARD_TEXTURE = preload("res://assets/novas_imagens/maycon/jamelao_float_1.png")
const MAYCON_WALK_TEXTURES = [
	preload("res://assets/images/andando_direita_1.png"),
	preload("res://assets/images/andando_direita_2.png"),
	preload("res://assets/images/andando_direita_3.png"),
	preload("res://assets/images/andando_direita_4.png"),
	preload("res://assets/images/andando_direita_5.png"),
	preload("res://assets/images/andando_direita_6.png"),
	preload("res://assets/images/andando_direita_7.png"),
]
const MENU_FONT = preload("res://assets/fonts/contrast.ttf")
const SKY_SHADER = preload("res://scenes/3D/menu_night_sky.gdshader")
const WATER_SHADER = preload("res://scenes/3D/menu_ocean.gdshader")
const SAND_SHADER = preload("res://scenes/3D/menu_sand.gdshader")
const GLOW_SHADER = preload("res://scenes/3D/menu_moon_glow.gdshader")
const MOON_SURFACE_SHADER = preload("res://scenes/3D/menu_moon_surface.gdshader")
const MEMORY_SHADER = preload("res://scenes/3D/menu_memory.gdshader")
const STAR_SHADER = preload("res://scenes/3D/menu_stars.gdshader")
const MIST_SHADER = preload("res://scenes/3D/menu_horizon_mist.gdshader")
const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")
const MENU_SOUND_CONTROLLER = preload("res://scripts/ui/menu_sound_controller.gd")

const LOOK_OUT_DURATION := 3.4
const WALK_START := 5.0
const WALK_DURATION := 28.0
const TURN_DURATION := 4.5
const MEMORY_START := 36.5
const MEMORY_FULL := 45.5
const MOON_POSITION := Vector3(2.0, 19.0, -86.0)
const MEMORY_POSITION := Vector3(27.0, 16.0, -63.0)
const TAKE_WIDE := 0
const TAKE_LOW := 1
const TAKE_POV := 2

@export var load_from_castle_1: bool = false
@export var load_from_outside_1: bool = false
@export var enable_debug_tab: bool = true

var elapsed := 0.0
var maycon: Node3D
var maycon_sprite: AnimatedSprite3D
var maycon_animation: AnimationPlayer
var maycon_skeleton: Skeleton3D
var maycon_head_bone := -1
var camera: Camera3D
var take_cameras: Array[Camera3D] = []
var take_rng := RandomNumberGenerator.new()
var take_order: Array[int] = []
var current_take := TAKE_WIDE
var previous_take := TAKE_WIDE
var transition_start := -10.0
var next_take_time := WALK_START + 4.5
var pov_start_time := -1.0
var pov_visit_count := 0
var pov_gaze_order: Array[int] = [0, 1, 2]
var pov_gaze_rate := 1.0
var memory_material: ShaderMaterial
var moon_glow_material: ShaderMaterial
var film_material: ShaderMaterial
var menu_panel: Control
var fade_rect: ColorRect
var memory_sound: AudioStreamPlayer
var sand_steps: AudioStreamPlayer
var memory_sound_played := false
var leaving := false
var menu_sounds: Node

var stack_main: VBoxContainer
var stack_slots: VBoxContainer
var stack_slot_actions: VBoxContainer
var btn_new_game: Button
var btn_load: Button
var slots_kicker: Label
var slots_title: Label
var slots_caption: Label
var slot_cards: Array[Button] = []
var selected_slot: int = 1
var slots_mode: String = "load" # "load" or "new_game"

var action_title: Label
var action_status_badge: Label
var action_fase_val: Label
var action_date_val: Label
var action_hp_val: Label
var action_mode_val: Label
var action_pentagrams_val: Label
var action_pentagrams_row: HBoxContainer
var action_empty_label: Label
var action_details_vbox: VBoxContainer
var btn_slot_load: Button
var btn_slot_delete: Button
var btn_slot_newgame: Button
var btn_slot_back: Button

var fullscreen_delete_dialog: Control
var delete_confirm_btn: Button
var delete_cancel_btn: Button
var delete_slot_label: Label
var delete_info_label: Label
var delete_cooldown: float = 0.0

var fullscreen_overwrite_dialog: Control
var overwrite_confirm_btn: Button
var overwrite_cancel_btn: Button
var overwrite_slot_label: Label
var overwrite_info_label: Label


func _ready() -> void:
	Global.load_from_castle_1 = load_from_castle_1
	Global.load_from_outside_1 = load_from_outside_1
	Global.show_debug_tab = enable_debug_tab
	take_rng.randomize()
	menu_sounds = MENU_SOUND_CONTROLLER.new()
	add_child(menu_sounds)
	_build_world()
	_build_film_filter()
	_build_interface()
	_build_audio()
	_update_cinematic(0.0, 0.0)
	var reveal := create_tween()
	reveal.tween_property(fade_rect, "color:a", 0.0, 2.8).set_trans(Tween.TRANS_SINE)
	reveal.parallel().tween_property(menu_panel, "modulate:a", 1.0, 3.6).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(btn_load):
		btn_load.grab_focus.call_deferred()


func _process(delta: float) -> void:
	if leaving:
		return
	elapsed += delta
	_update_cinematic(elapsed, delta)
	_update_delete_cooldown(delta)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if fullscreen_delete_dialog and fullscreen_delete_dialog.visible:
			menu_sounds.play_back()
			_close_delete_confirmation()
			get_viewport().set_input_as_handled()
		elif fullscreen_overwrite_dialog and fullscreen_overwrite_dialog.visible:
			menu_sounds.play_back()
			_close_overwrite_confirmation()
			get_viewport().set_input_as_handled()
		elif stack_slot_actions and stack_slot_actions.visible:
			menu_sounds.play_back()
			_show_slots_menu(slots_mode)
			get_viewport().set_input_as_handled()
		elif stack_slots and stack_slots.visible:
			menu_sounds.play_back()
			_show_main_menu()
			get_viewport().set_input_as_handled()



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
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("look_forward")
	sprite_frames.set_animation_loop("look_forward", true)
	sprite_frames.add_frame("look_forward", MAYCON_LOOK_FORWARD_TEXTURE)
	sprite_frames.add_animation("walk")
	sprite_frames.set_animation_loop("walk", true)
	for texture in MAYCON_WALK_TEXTURES:
		sprite_frames.add_frame("walk", texture, 0.51)
	maycon_sprite = AnimatedSprite3D.new()
	maycon_sprite.name = "MayconModel"
	maycon_sprite.sprite_frames = sprite_frames
	maycon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	maycon_sprite.pixel_size = 0.01
	maycon_sprite.position.y = 0.74
	maycon_sprite.play("look_forward")
	maycon.add_child(maycon_sprite)
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


func _adjust_maycon_materials(root: Node) -> void:
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not mi:
			continue
		if mi.material_override is BaseMaterial3D:
			var mat = mi.material_override.duplicate() as BaseMaterial3D
			mat.metallic = 0.0
			mat.roughness = 0.85
			mat.metallic_specular = 0.25
			mat.emission_enabled = false
			mi.material_override = mat
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat = mi.get_surface_override_material(s)
				if not mat:
					mat = mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					var dup = mat.duplicate() as BaseMaterial3D
					dup.metallic = 0.0
					dup.roughness = 0.85
					dup.metallic_specular = 0.25
					dup.emission_enabled = false
					mi.set_surface_override_material(s, dup)


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
	moon.position = MOON_POSITION
	add_child(moon)
	var halo := MeshInstance3D.new()
	halo.name = "MoonHalo"
	var halo_mesh := QuadMesh.new()
	halo_mesh.size = Vector2(34, 34)
	moon_glow_material = _material(GLOW_SHADER)
	halo_mesh.material = moon_glow_material
	halo.mesh = halo_mesh
	halo.position = MOON_POSITION + Vector3(0, 0, -1)
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
	ghost.position = MEMORY_POSITION
	add_child(ghost)


func _build_stars() -> void:
	var stars := MultiMeshInstance3D.new()
	stars.name = "DistantStars"
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mesh.radial_segments = 6
	mesh.rings = 4
	mesh.material = _material(STAR_SHADER)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = 720
	var rng := RandomNumberGenerator.new()
	rng.seed = 71521
	for i in range(multi.instance_count):
		var size := rng.randf_range(0.6, 1.35)
		var azimuth := rng.randf_range(0.0, TAU)
		var elevation := rng.randf_range(0.05, 1.45)
		var direction := Vector3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth))
		var position := direction * rng.randf_range(124.0, 142.0)
		multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(size, size, size)), position))
		multi.set_instance_color(i, Color(0.58 + rng.randf() * 0.30, 0.76 + rng.randf() * 0.20, 1.0))
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


func _update_cinematic(time: float, delta: float) -> void:
	var walk_end := WALK_START + WALK_DURATION
	var walking := time >= WALK_START and time < walk_end
	var walk := clampf((time - WALK_START) / WALK_DURATION, 0.0, 1.0)
	maycon.position.x = lerpf(-15.0, 7.0, walk)
	maycon.position.y = 0.08 + (sin((time - WALK_START) * 1.9) * 0.018 if walking else 0.0)
	var face_path := smoothstep(LOOK_OUT_DURATION, WALK_START, time)
	maycon.rotation.y = lerp_angle(PI, PI * 0.5, face_path)
	var moon_direction := MOON_POSITION - maycon.global_position
	var moon_yaw := atan2(moon_direction.x, moon_direction.z)
	maycon.rotation.y = lerp_angle(maycon.rotation.y, moon_yaw, smoothstep(walk_end, walk_end + TURN_DURATION, time))
	if walking and maycon_sprite and maycon_sprite.animation != &"walk":
		maycon_sprite.play("walk")
		if sand_steps:
			sand_steps.play()
	elif not walking and maycon_sprite and maycon_sprite.animation != &"look_forward":
		maycon_sprite.play("look_forward")
		if sand_steps:
			sand_steps.stop()
	_update_moon_gaze(time, walk_end, moon_direction)

	_update_take_cameras(time)
	while time >= next_take_time:
		_switch_take(next_take_time)
	var blend := smoothstep(transition_start, transition_start + 2.8, time)
	var pose := take_cameras[previous_take].global_transform.interpolate_with(take_cameras[current_take].global_transform, blend)
	if previous_take != current_take and blend < 1.0:
		pose.origin.y += sin(blend * PI) * 0.35
	var follow := 1.0 if delta <= 0.0 else 1.0 - exp(-delta * 4.0)
	var previous_camera_pose := camera.global_transform
	camera.global_transform = camera.global_transform.interpolate_with(pose, follow)
	var desired_fov := lerpf(take_cameras[previous_take].fov, take_cameras[current_take].fov, blend)
	camera.fov = lerpf(camera.fov, desired_fov + sin(time * 0.22) * 0.25, follow)
	if film_material:
		var motion := Vector2.ZERO
		if delta > 0.0 and delta < 0.1:
			var camera_right := camera.global_basis.x
			var camera_up := camera.global_basis.y
			var forward_change := previous_camera_pose.basis.z - camera.global_basis.z
			var position_change := camera.global_position - previous_camera_pose.origin
			motion = Vector2(-forward_change.dot(camera_right), forward_change.dot(camera_up)) * 0.85
			motion += Vector2(-position_change.dot(camera_right), position_change.dot(camera_up)) * 0.08
		film_material.set_shader_parameter("motion_blur_vector", motion.limit_length(0.004))
	var memory_hint := smoothstep(WALK_START + 14.0, WALK_START + 24.0, time) * 0.18
	var memory_glimpse := 0.0
	if current_take == TAKE_POV and pov_start_time >= 0.0:
		var gaze_time := (time - pov_start_time) * pov_gaze_rate
		memory_glimpse = 0.48 * _pov_memory_attention(gaze_time)
	memory_material.set_shader_parameter("reveal", maxf(maxf(memory_hint, memory_glimpse), smoothstep(MEMORY_START, MEMORY_FULL, time)))
	moon_glow_material.set_shader_parameter("pulse", 0.7 + sin(time * 0.38) * 0.08)
	if not memory_sound_played and current_take == TAKE_POV and blend >= 0.8 and memory_glimpse >= 0.28:
		var camera_forward := -camera.global_basis.z
		var direction_to_memory := (MEMORY_POSITION - camera.global_position).normalized()
		if camera_forward.dot(direction_to_memory) >= 0.94:
			memory_sound_played = true
			memory_sound.play()


func _update_moon_gaze(time: float, walk_end: float, moon_direction: Vector3) -> void:
	if not maycon_skeleton or maycon_head_bone < 0:
		return
	var gaze_weight := smoothstep(walk_end + 0.9, walk_end + TURN_DURATION + 1.0, time)
	var horizontal_distance := Vector2(moon_direction.x, moon_direction.z).length()
	var moon_elevation := atan2(moon_direction.y - 1.65, horizontal_distance)
	var head_pitch := clampf(moon_elevation * 1.35, 0.0, deg_to_rad(18.0)) * gaze_weight
	var head_pose := maycon_skeleton.get_bone_global_pose_no_override(maycon_head_bone)
	head_pose.basis = head_pose.basis * Basis(Vector3.RIGHT, -head_pitch)
	maycon_skeleton.set_bone_global_pose_override(maycon_head_bone, head_pose, 1.0, true)


func _switch_take(switch_time: float) -> void:
	if take_order.is_empty():
		take_order = [TAKE_WIDE, TAKE_LOW, TAKE_POV]
		take_order.erase(current_take)
	var next_index := take_rng.randi_range(0, take_order.size() - 1)
	previous_take = current_take
	current_take = take_order.pop_at(next_index)
	transition_start = switch_time
	if current_take == TAKE_POV:
		pov_start_time = switch_time
		var last_order := pov_gaze_order.duplicate()
		pov_gaze_order = [0, 1, 2]
		if pov_visit_count > 0:
			for i in range(pov_gaze_order.size() - 1, 0, -1):
				var swap_index := take_rng.randi_range(0, i)
				var previous_value := pov_gaze_order[i]
				pov_gaze_order[i] = pov_gaze_order[swap_index]
				pov_gaze_order[swap_index] = previous_value
			if pov_gaze_order == last_order:
				pov_gaze_order[0] = last_order[1]
				pov_gaze_order[1] = last_order[0]
		pov_gaze_rate = take_rng.randf_range(1.0, 1.12)
		pov_visit_count += 1
	var duration := take_rng.randf_range(11.5, 13.5) if current_take == TAKE_POV else take_rng.randf_range(7.0, 9.0)
	next_take_time = switch_time + duration


func _update_take_cameras(time: float) -> void:
	var drift := Vector3(sin(time * 0.13) * 0.48, sin(time * 0.19) * 0.13, cos(time * 0.11) * 0.22)
	var wide_from := Vector3(maycon.position.x + 1.0, 4.4, 22.0) + drift
	var wide_toward := Vector3(maycon.position.x - 7.0, 5.2, -30.0) + Vector3(sin(time * 0.09) * 0.25, sin(time * 0.14) * 0.12, 0.0)
	take_cameras[TAKE_WIDE].global_transform = _camera_pose(wide_from, wide_toward)
	take_cameras[TAKE_WIDE].fov = 51.0
	var low_from := maycon.position + Vector3(-2.2, 0.64, 2.8) + Vector3(sin(time * 1.1) * 0.06, sin(time * 1.8) * 0.035, 0.0)
	var low_toward := maycon.position + Vector3(0.0, 1.04, -13.0) + Vector3(sin(time * 0.23) * 0.18, 0.0, 0.0)
	take_cameras[TAKE_LOW].global_transform = _camera_pose(low_from, low_toward)
	take_cameras[TAKE_LOW].fov = 62.0
	var facing := Vector3(sin(maycon.rotation.y), 0.0, cos(maycon.rotation.y))
	var walk_end := WALK_START + WALK_DURATION
	var bob_weight := smoothstep(WALK_START, WALK_START + 0.8, time) * (1.0 - smoothstep(walk_end - 0.8, walk_end, time))
	var step_phase := (time - WALK_START) * 7.5
	var bob_height := (absf(sin(step_phase)) * 0.045 + sin(step_phase * 0.5) * 0.009) * bob_weight
	var bob_sway := sin(step_phase * 0.5) * 0.022 * bob_weight
	var eye := maycon.position + facing * 0.64 + Vector3(0.0, 1.55 + sin(time * 1.5) * 0.012 + bob_height, 0.0)
	eye += Vector3(facing.z, 0.0, -facing.x) * bob_sway
	var gaze_time := maxf((time - pov_start_time) * pov_gaze_rate, 0.0) if pov_start_time >= 0.0 else 0.0
	var pov_toward := _pov_gaze(eye, facing, gaze_time) + Vector3(sin(time * 0.29) * 0.12, sin(time * 0.21) * 0.07 + sin(step_phase) * 0.055 * bob_weight, 0.0)
	pov_toward = _blend_gaze(eye, pov_toward, MOON_POSITION, smoothstep(walk_end + 0.9, walk_end + TURN_DURATION + 1.0, time))
	take_cameras[TAKE_POV].global_transform = _camera_pose(eye, pov_toward)
	take_cameras[TAKE_POV].fov = 68.0


func _pov_gaze(eye: Vector3, facing: Vector3, gaze_time: float) -> Vector3:
	var forward := eye + facing * 17.0 + Vector3(0.0, -0.35, -1.5)
	var down := eye + facing * 6.0 + Vector3(0.0, -2.2, -0.7)
	var moon := MOON_POSITION
	var memory := MEMORY_POSITION
	var gaze_points: Array[Vector3] = [down, moon, memory]
	var first := gaze_points[pov_gaze_order[0]]
	var second := gaze_points[pov_gaze_order[1]]
	var third := gaze_points[pov_gaze_order[2]]
	if gaze_time < 1.2:
		return forward
	if gaze_time < 2.7:
		return _blend_gaze(eye, forward, first, smoothstep(1.2, 2.7, gaze_time))
	if gaze_time < 3.3:
		return first
	if gaze_time < 5.1:
		return _blend_gaze(eye, first, second, smoothstep(3.3, 5.1, gaze_time))
	if gaze_time < 5.8:
		return second
	if gaze_time < 7.6:
		return _blend_gaze(eye, second, third, smoothstep(5.8, 7.6, gaze_time))
	if gaze_time < 8.6:
		return third
	if gaze_time < 10.6:
		return _blend_gaze(eye, third, forward, smoothstep(8.6, 10.6, gaze_time))
	return forward


func _pov_memory_attention(gaze_time: float) -> float:
	var attention := 0.0
	if pov_gaze_order[0] == 2:
		attention = smoothstep(1.2, 2.7, gaze_time) * (1.0 - smoothstep(3.3, 5.1, gaze_time))
	if pov_gaze_order[1] == 2:
		attention = smoothstep(3.3, 5.1, gaze_time) * (1.0 - smoothstep(5.8, 7.6, gaze_time))
	if pov_gaze_order[2] == 2:
		attention = smoothstep(5.8, 7.6, gaze_time) * (1.0 - smoothstep(8.6, 10.6, gaze_time))
	return attention


func _blend_gaze(eye: Vector3, from: Vector3, toward: Vector3, weight: float) -> Vector3:
	return eye + (from - eye).normalized().slerp((toward - eye).normalized(), weight) * 18.0


func _camera_pose(from: Vector3, toward: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(toward - from), from)


func _build_film_filter() -> void:
	var film_layer := CanvasLayer.new()
	film_layer.name = "CinematicFilm"
	film_layer.layer = 0
	add_child(film_layer)
	var film_rect := ColorRect.new()
	film_rect.name = "FilmGrain"
	film_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film_material = _material(OLD_FILM_SHADER)
	film_material.set_shader_parameter("sepia_amount", 0.20)
	film_material.set_shader_parameter("grain_amount", 0.052)
	film_material.set_shader_parameter("grain_speed", 24.0)
	film_material.set_shader_parameter("vignette_intensity", 0.48)
	film_material.set_shader_parameter("vignette_radius", 1.0)
	film_material.set_shader_parameter("flicker_intensity", 0.022)
	film_material.set_shader_parameter("scratch_intensity", 0.24)
	film_material.set_shader_parameter("dust_intensity", 0.26)
	film_material.set_shader_parameter("jitter_amount", 0.00032)
	film_material.set_shader_parameter("motion_blur_mix", 0.45)
	film_rect.material = film_material
	film_layer.add_child(film_rect)


func _build_interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 1
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
	# 1. Main menu stack
	stack_main = VBoxContainer.new()
	stack_main.name = "Stack"
	stack_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack_main.add_theme_constant_override("separation", 3)
	menu_panel.add_child(stack_main)
	var title := _label("GAME_TITLE", 39, Color(0.95, 0.96, 0.92), true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack_main.add_child(title)
	stack_main.add_child(_label("GAME_SUBTITLE", 25, Color(0.75, 0.91, 0.92), true))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 34
	stack_main.add_child(spacer)
	var rule := ColorRect.new()
	rule.color = Color(0.35, 0.72, 0.77, 0.6)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_main.add_child(rule)
	stack_main.add_child(_label("MENU_NIGHT_CAPTION", 15, Color(0.67, 0.80, 0.82), false))
	var gap := Control.new()
	gap.custom_minimum_size.y = 16
	stack_main.add_child(gap)
	var buttons := VBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", 8)
	stack_main.add_child(buttons)
	btn_load = _menu_button("MENU_LOAD", "Load")
	buttons.add_child(btn_load)
	btn_load.pressed.connect(_on_load_pressed)
	btn_new_game = _menu_button("MENU_NEW_GAME", "NewGame")
	buttons.add_child(btn_new_game)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	var settings := _menu_button("MENU_SETTINGS", "Settings")
	buttons.add_child(settings)
	settings.pressed.connect(_on_settings_pressed)
	var exit_button := _menu_button("MENU_EXIT", "Exit")
	buttons.add_child(exit_button)
	exit_button.pressed.connect(_on_exit_pressed)

	btn_load.focus_neighbor_top = exit_button.get_path()
	btn_load.focus_neighbor_bottom = btn_new_game.get_path()
	btn_new_game.focus_neighbor_top = btn_load.get_path()
	btn_new_game.focus_neighbor_bottom = settings.get_path()
	settings.focus_neighbor_top = btn_new_game.get_path()
	settings.focus_neighbor_bottom = exit_button.get_path()
	exit_button.focus_neighbor_top = settings.get_path()
	exit_button.focus_neighbor_bottom = btn_load.get_path()

	# 2. Slot selection submenu stack
	stack_slots = VBoxContainer.new()
	stack_slots.name = "StackSlots"
	stack_slots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack_slots.add_theme_constant_override("separation", 3)
	stack_slots.visible = false
	menu_panel.add_child(stack_slots)
	slots_kicker = _label("MENU_SLOTS_TITLE", 15, Color(0.54, 0.82, 0.88), true)
	stack_slots.add_child(slots_kicker)
	slots_title = _label("MENU_LOAD", 32, Color(0.95, 0.96, 0.92), true)
	slots_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack_slots.add_child(slots_title)
	var spacer_slots := Control.new()
	spacer_slots.custom_minimum_size.y = 10
	stack_slots.add_child(spacer_slots)
	var rule_slots := ColorRect.new()
	rule_slots.color = Color(0.35, 0.72, 0.77, 0.6)
	rule_slots.custom_minimum_size = Vector2(0, 2)
	rule_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_slots.add_child(rule_slots)
	slots_caption = _label("MENU_SLOTS_DESC", 14, Color(0.67, 0.80, 0.82), false)
	stack_slots.add_child(slots_caption)
	var gap_slots := Control.new()
	gap_slots.custom_minimum_size.y = 12
	stack_slots.add_child(gap_slots)
	var slots_vbox := VBoxContainer.new()
	slots_vbox.name = "SlotsVBox"
	slots_vbox.add_theme_constant_override("separation", 8)
	stack_slots.add_child(slots_vbox)
	slot_cards.clear()
	for s in [1, 2, 3]:
		var card := _build_slot_card(s)
		slots_vbox.add_child(card)
		slot_cards.append(card)
	var gap_slots_back := Control.new()
	gap_slots_back.custom_minimum_size.y = 6
	stack_slots.add_child(gap_slots_back)
	var btn_slots_back := _menu_button("MENU_BACK", "SlotsBack")
	stack_slots.add_child(btn_slots_back)
	btn_slots_back.pressed.connect(_show_main_menu)

	if slot_cards.size() == 3:
		slot_cards[0].focus_neighbor_top = btn_slots_back.get_path()
		slot_cards[0].focus_neighbor_bottom = slot_cards[1].get_path()
		slot_cards[1].focus_neighbor_top = slot_cards[0].get_path()
		slot_cards[1].focus_neighbor_bottom = slot_cards[2].get_path()
		slot_cards[2].focus_neighbor_top = slot_cards[1].get_path()
		slot_cards[2].focus_neighbor_bottom = btn_slots_back.get_path()
		btn_slots_back.focus_neighbor_top = slot_cards[2].get_path()
		btn_slots_back.focus_neighbor_bottom = slot_cards[0].get_path()

	# 3. Slot actions submenu stack
	stack_slot_actions = VBoxContainer.new()
	stack_slot_actions.name = "StackSlotActions"
	stack_slot_actions.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack_slot_actions.add_theme_constant_override("separation", 3)
	stack_slot_actions.visible = false
	menu_panel.add_child(stack_slot_actions)
	var action_kicker := _label("MENU_SLOT_ACTION_TITLE", 15, Color(0.54, 0.82, 0.88), true)
	stack_slot_actions.add_child(action_kicker)
	action_title = _label("SLOT 1", 32, Color(0.95, 0.96, 0.92), true, false)
	stack_slot_actions.add_child(action_title)
	var spacer_act := Control.new()
	spacer_act.custom_minimum_size.y = 10
	stack_slot_actions.add_child(spacer_act)
	var rule_act := ColorRect.new()
	rule_act.color = Color(0.35, 0.72, 0.77, 0.6)
	rule_act.custom_minimum_size = Vector2(0, 2)
	rule_act.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_slot_actions.add_child(rule_act)
	var gap_act := Control.new()
	gap_act.custom_minimum_size.y = 8
	stack_slot_actions.add_child(gap_act)

	var details_panel := PanelContainer.new()
	var det_style := StyleBoxFlat.new()
	det_style.bg_color = Color(0.015, 0.07, 0.09, 0.6)
	det_style.border_color = Color(0.20, 0.52, 0.60, 0.42)
	det_style.set_border_width_all(1)
	det_style.set_corner_radius_all(6)
	det_style.content_margin_left = 16
	det_style.content_margin_right = 16
	det_style.content_margin_top = 12
	det_style.content_margin_bottom = 12
	details_panel.add_theme_stylebox_override("panel", det_style)
	stack_slot_actions.add_child(details_panel)

	var details_inner := VBoxContainer.new()
	details_inner.add_theme_constant_override("separation", 5)
	details_panel.add_child(details_inner)

	action_status_badge = Label.new()
	action_status_badge.add_theme_font_override("font", MENU_FONT)
	action_status_badge.add_theme_font_size_override("font_size", 14)
	details_inner.add_child(action_status_badge)

	action_empty_label = Label.new()
	action_empty_label.text = tr("MENU_SLOT_NO_DATA")
	action_empty_label.add_theme_font_override("font", MENU_FONT)
	action_empty_label.add_theme_font_size_override("font_size", 13)
	action_empty_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.70))
	details_inner.add_child(action_empty_label)

	action_details_vbox = VBoxContainer.new()
	action_details_vbox.add_theme_constant_override("separation", 4)
	details_inner.add_child(action_details_vbox)

	var r1 := _build_detail_row(tr("MENU_STAGE_LABEL"))
	action_details_vbox.add_child(r1[0])
	action_fase_val = r1[1]

	var r2 := _build_detail_row(tr("MENU_DATE_LABEL"))
	action_details_vbox.add_child(r2[0])
	action_date_val = r2[1]

	var r3 := _build_detail_row(tr("MENU_MODE_LABEL"))
	action_details_vbox.add_child(r3[0])
	action_mode_val = r3[1]

	var r4 := _build_detail_row(tr("MENU_HEALTH_LABEL"))
	action_details_vbox.add_child(r4[0])
	action_hp_val = r4[1]

	var r5 := _build_detail_row("Pentagramas")
	action_pentagrams_row = r5[0]
	action_details_vbox.add_child(action_pentagrams_row)
	action_pentagrams_val = r5[1]

	var gap_act_btns := Control.new()
	gap_act_btns.custom_minimum_size.y = 12
	stack_slot_actions.add_child(gap_act_btns)

	var act_buttons := VBoxContainer.new()
	act_buttons.add_theme_constant_override("separation", 8)
	stack_slot_actions.add_child(act_buttons)

	btn_slot_load = _menu_button("MENU_SLOT_LOAD_BTN", "BtnSlotLoad")
	act_buttons.add_child(btn_slot_load)
	btn_slot_load.pressed.connect(_load_selected_slot)

	btn_slot_delete = _menu_button("MENU_SLOT_DELETE_BTN", "BtnSlotDelete", true)
	act_buttons.add_child(btn_slot_delete)
	btn_slot_delete.pressed.connect(_open_delete_confirmation)

	btn_slot_newgame = _menu_button("MENU_SLOT_NEW_GAME", "BtnSlotNewGame")
	act_buttons.add_child(btn_slot_newgame)
	btn_slot_newgame.pressed.connect(func(): _start_new_game_on_slot(selected_slot))

	btn_slot_back = _menu_button("MENU_BACK", "BtnSlotBack")
	act_buttons.add_child(btn_slot_back)
	btn_slot_back.pressed.connect(func(): _show_slots_menu(slots_mode))

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

	_build_delete_dialog(root)
	_build_overwrite_dialog(root)


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


func _build_detail_row(label_text: String) -> Array:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = label_text + ":"
	lbl.custom_minimum_size = Vector2(100, 0)
	lbl.add_theme_font_override("font", MENU_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.80))
	row.add_child(lbl)
	var val := Label.new()
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_font_override("font", MENU_FONT)
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", Color(0.90, 0.96, 0.96))
	row.add_child(val)
	return [row, val]


func _build_slot_card(slot: int) -> Button:
	var btn := Button.new()
	btn.name = "SlotCard_%d" % slot
	btn.custom_minimum_size = Vector2(0, 64)
	_apply_menu_button_style(btn, false)
	btn.text = ""

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 18
	vbox.offset_right = -14
	vbox.offset_top = 8
	vbox.offset_bottom = -8
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top_row)

	var slot_title := Label.new()
	slot_title.name = "SlotTitle"
	slot_title.text = tr("MENU_SLOT_%d_LABEL" % slot).to_upper()
	slot_title.add_theme_font_override("font", MENU_FONT)
	slot_title.add_theme_font_size_override("font_size", 17)
	slot_title.add_theme_color_override("font_color", Color(0.88, 0.95, 0.96))
	slot_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.04, 0.7))
	slot_title.add_theme_constant_override("shadow_offset_x", 1)
	slot_title.add_theme_constant_override("shadow_offset_y", 1)
	top_row.add_child(slot_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)

	var status_badge := Label.new()
	status_badge.name = "StatusBadge"
	status_badge.add_theme_font_override("font", MENU_FONT)
	status_badge.add_theme_font_size_override("font_size", 13)
	status_badge.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.04, 0.7))
	status_badge.add_theme_constant_override("shadow_offset_x", 1)
	status_badge.add_theme_constant_override("shadow_offset_y", 1)
	top_row.add_child(status_badge)

	var bottom_label := Label.new()
	bottom_label.name = "BottomLabel"
	bottom_label.add_theme_font_override("font", MENU_FONT)
	bottom_label.add_theme_font_size_override("font_size", 13)
	bottom_label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.78))
	bottom_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.04, 0.7))
	bottom_label.add_theme_constant_override("shadow_offset_x", 1)
	bottom_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(bottom_label)

	btn.pressed.connect(func(): _on_slot_selected(slot))
	return btn


func _update_slot_cards() -> void:
	for slot in [1, 2, 3]:
		var btn: Button = slot_cards[slot - 1]
		var info: Dictionary = Global.get_slot_info(slot)
		var vbox: VBoxContainer = btn.get_node("VBox")
		var top_row: HBoxContainer = vbox.get_node("TopRow")
		var status_badge: Label = top_row.get_node("StatusBadge")
		var bottom_label: Label = vbox.get_node("BottomLabel")

		if info.get("exists", false):
			status_badge.text = "[ " + tr("MENU_SLOT_SAVED").to_upper() + " ]"
			status_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.75))
			bottom_label.text = "%s  •  %s" % [info.get("fase_display", ""), info.get("date", "")]
		else:
			status_badge.text = tr("MENU_SLOT_EMPTY").to_upper()
			status_badge.add_theme_color_override("font_color", Color(0.48, 0.58, 0.60))
			bottom_label.text = tr("MENU_SLOT_NO_DATA")


func _update_slot_actions_view() -> void:
	var info: Dictionary = Global.get_slot_info(selected_slot)
	var slot_name := tr("MENU_SLOT_%d_LABEL" % selected_slot).to_upper()
	action_title.text = slot_name

	if info.get("exists", false):
		action_status_badge.text = "[ " + tr("MENU_SLOT_SAVED").to_upper() + " ]"
		action_status_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.75))
		action_empty_label.visible = false
		action_details_vbox.visible = true

		action_fase_val.text = info.get("fase_display", "")
		action_date_val.text = info.get("date", "")
		action_hp_val.text = "%d HP" % int(info.get("hp", Global.realtime_hp_max))
		var is_realtime: bool = str(info.get("battle_mode", Global.battle_mode_realtime)) == Global.battle_mode_realtime
		action_mode_val.text = tr("MENU_MODE_REALTIME") if is_realtime else tr("MENU_MODE_STRATEGIC")

		var pentagrams: int = int(info.get("pentagrams", 0))
		if pentagrams > 0:
			action_pentagrams_row.visible = true
			action_pentagrams_val.text = str(pentagrams)
		else:
			action_pentagrams_row.visible = false

		btn_slot_load.visible = true
		btn_slot_load.disabled = false
		btn_slot_load.focus_mode = Control.FOCUS_ALL

		btn_slot_delete.visible = true
		btn_slot_delete.disabled = false
		btn_slot_delete.focus_mode = Control.FOCUS_ALL

		btn_slot_newgame.visible = false
		btn_slot_newgame.focus_mode = Control.FOCUS_NONE

		btn_slot_back.visible = true
		btn_slot_back.focus_mode = Control.FOCUS_ALL

		btn_slot_load.focus_neighbor_top = btn_slot_back.get_path()
		btn_slot_load.focus_neighbor_bottom = btn_slot_delete.get_path()
		btn_slot_delete.focus_neighbor_top = btn_slot_load.get_path()
		btn_slot_delete.focus_neighbor_bottom = btn_slot_back.get_path()
		btn_slot_back.focus_neighbor_top = btn_slot_delete.get_path()
		btn_slot_back.focus_neighbor_bottom = btn_slot_load.get_path()
	else:
		action_status_badge.text = tr("MENU_SLOT_EMPTY").to_upper()
		action_status_badge.add_theme_color_override("font_color", Color(0.48, 0.58, 0.60))
		action_empty_label.visible = true
		action_details_vbox.visible = false

		btn_slot_load.visible = false
		btn_slot_load.disabled = true
		btn_slot_load.focus_mode = Control.FOCUS_NONE

		btn_slot_delete.visible = false
		btn_slot_delete.disabled = true
		btn_slot_delete.focus_mode = Control.FOCUS_NONE

		btn_slot_newgame.visible = true
		btn_slot_newgame.focus_mode = Control.FOCUS_ALL

		btn_slot_back.visible = true
		btn_slot_back.focus_mode = Control.FOCUS_ALL

		btn_slot_newgame.focus_neighbor_top = btn_slot_back.get_path()
		btn_slot_newgame.focus_neighbor_bottom = btn_slot_back.get_path()
		btn_slot_back.focus_neighbor_top = btn_slot_newgame.get_path()
		btn_slot_back.focus_neighbor_bottom = btn_slot_newgame.get_path()


func _show_main_menu() -> void:
	stack_main.visible = true
	stack_slots.visible = false
	stack_slot_actions.visible = false
	if is_instance_valid(btn_load):
		btn_load.grab_focus.call_deferred()


func _show_slots_menu(mode: String = "load") -> void:
	slots_mode = mode
	stack_main.visible = false
	stack_slots.visible = true
	stack_slot_actions.visible = false
	if mode == "new_game":
		slots_kicker.text = tr("MENU_NEW_GAME").to_upper()
		slots_title.text = tr("MENU_SLOTS_TITLE")
		slots_caption.text = tr("MENU_SLOTS_NEWGAME_DESC")
	else:
		slots_kicker.text = tr("MENU_SLOTS_TITLE")
		slots_title.text = tr("MENU_LOAD").to_upper()
		slots_caption.text = tr("MENU_SLOTS_DESC")
	_update_slot_cards()
	if slot_cards.size() >= selected_slot and selected_slot > 0:
		slot_cards[selected_slot - 1].grab_focus.call_deferred()


func _show_slot_actions_menu() -> void:
	stack_main.visible = false
	stack_slots.visible = false
	stack_slot_actions.visible = true
	_update_slot_actions_view()
	var info: Dictionary = Global.get_slot_info(selected_slot)
	if info.get("exists", false):
		btn_slot_load.grab_focus.call_deferred()
	else:
		btn_slot_newgame.grab_focus.call_deferred()


func _on_slot_selected(slot: int) -> void:
	selected_slot = slot
	if slots_mode == "new_game":
		var info: Dictionary = Global.get_slot_info(slot)
		if info.get("exists", false):
			_open_overwrite_confirmation(slot)
		else:
			_start_new_game_on_slot(slot)
	else:
		_show_slot_actions_menu()


func _build_delete_dialog(root: Control) -> void:
	fullscreen_delete_dialog = Control.new()
	fullscreen_delete_dialog.name = "FullscreenDeleteDialog"
	fullscreen_delete_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullscreen_delete_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_delete_dialog.visible = false
	root.add_child(fullscreen_delete_dialog)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.005, 0.012, 0.022, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_delete_dialog.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	fullscreen_delete_dialog.add_child(center)

	var box_panel := PanelContainer.new()
	box_panel.custom_minimum_size = Vector2(490, 0)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.02, 0.045, 0.065, 0.98)
	box_style.border_color = Color(0.88, 0.22, 0.22, 0.88)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(8)
	box_style.content_margin_left = 26
	box_style.content_margin_right = 26
	box_style.content_margin_top = 24
	box_style.content_margin_bottom = 24
	box_panel.add_theme_stylebox_override("panel", box_style)
	center.add_child(box_panel)

	var box_vbox := VBoxContainer.new()
	box_vbox.add_theme_constant_override("separation", 10)
	box_panel.add_child(box_vbox)

	var warning_header := _label("!  ATENÇÃO", 15, Color(1.0, 0.35, 0.35), true, false)
	box_vbox.add_child(warning_header)

	var del_title := _label("MENU_DELETE_FULLSCREEN_TITLE", 22, Color(1.0, 0.95, 0.95), true)
	del_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_vbox.add_child(del_title)

	var red_rule := ColorRect.new()
	red_rule.color = Color(0.85, 0.25, 0.25, 0.75)
	red_rule.custom_minimum_size = Vector2(0, 2)
	red_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_vbox.add_child(red_rule)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box_vbox.add_child(gap)

	delete_slot_label = Label.new()
	delete_slot_label.add_theme_font_override("font", MENU_FONT)
	delete_slot_label.add_theme_font_size_override("font_size", 18)
	delete_slot_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
	box_vbox.add_child(delete_slot_label)

	delete_info_label = Label.new()
	delete_info_label.add_theme_font_override("font", MENU_FONT)
	delete_info_label.add_theme_font_size_override("font_size", 14)
	delete_info_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.85))
	box_vbox.add_child(delete_info_label)

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 4
	box_vbox.add_child(gap2)

	var desc := _label("MENU_DELETE_FULLSCREEN_DESC", 14, Color(0.88, 0.72, 0.72), false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_vbox.add_child(desc)

	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 12
	box_vbox.add_child(gap3)

	var del_buttons := VBoxContainer.new()
	del_buttons.add_theme_constant_override("separation", 8)
	box_vbox.add_child(del_buttons)

	delete_confirm_btn = _menu_button("MENU_DELETE_CONFIRM_NOW", "DeleteConfirmBtn", true)
	delete_confirm_btn.custom_minimum_size = Vector2(0, 48)
	delete_confirm_btn.disabled = true
	del_buttons.add_child(delete_confirm_btn)
	delete_confirm_btn.pressed.connect(_on_delete_confirmed)

	delete_cancel_btn = _menu_button("MENU_DELETE_CANCEL", "DeleteCancelBtn", false)
	delete_cancel_btn.custom_minimum_size = Vector2(0, 48)
	del_buttons.add_child(delete_cancel_btn)
	delete_cancel_btn.pressed.connect(_close_delete_confirmation)


func _open_delete_confirmation() -> void:
	var info: Dictionary = Global.get_slot_info(selected_slot)
	delete_slot_label.text = tr("MENU_SLOT_%d_LABEL" % selected_slot).to_upper()
	if info.get("exists", false):
		delete_info_label.text = "%s  •  %s" % [info.get("fase_display", ""), info.get("date", "")]
	else:
		delete_info_label.text = tr("MENU_SLOT_EMPTY")

	delete_cooldown = 2.5
	delete_confirm_btn.disabled = true
	delete_confirm_btn.focus_mode = Control.FOCUS_NONE
	delete_cancel_btn.focus_neighbor_top = delete_cancel_btn.get_path()
	delete_cancel_btn.focus_neighbor_bottom = delete_cancel_btn.get_path()
	var secs := int(ceil(delete_cooldown))
	delete_confirm_btn.text = tr("MENU_DELETE_COOLDOWN") % secs
	fullscreen_delete_dialog.visible = true
	delete_cancel_btn.grab_focus.call_deferred()


func _update_delete_cooldown(delta: float) -> void:
	if not fullscreen_delete_dialog or not fullscreen_delete_dialog.visible:
		return
	if delete_cooldown > 0.0:
		delete_cooldown -= delta
		if delete_cooldown <= 0.0:
			delete_cooldown = 0.0
			delete_confirm_btn.disabled = false
			delete_confirm_btn.focus_mode = Control.FOCUS_ALL
			delete_confirm_btn.text = tr("MENU_DELETE_CONFIRM_NOW")
			delete_confirm_btn.focus_neighbor_top = delete_cancel_btn.get_path()
			delete_confirm_btn.focus_neighbor_bottom = delete_cancel_btn.get_path()
			delete_cancel_btn.focus_neighbor_top = delete_confirm_btn.get_path()
			delete_cancel_btn.focus_neighbor_bottom = delete_confirm_btn.get_path()
		else:
			var secs := int(ceil(delete_cooldown))
			delete_confirm_btn.text = tr("MENU_DELETE_COOLDOWN") % secs


func _close_delete_confirmation() -> void:
	fullscreen_delete_dialog.visible = false
	delete_cooldown = 0.0
	btn_slot_delete.grab_focus.call_deferred()


func _on_delete_confirmed() -> void:
	if delete_cooldown > 0.0:
		return
	Global.delete_save_slot(selected_slot)
	fullscreen_delete_dialog.visible = false
	_update_slot_cards()
	_update_slot_actions_view()
	btn_slot_newgame.grab_focus.call_deferred()


func _build_overwrite_dialog(root: Control) -> void:
	fullscreen_overwrite_dialog = Control.new()
	fullscreen_overwrite_dialog.name = "FullscreenOverwriteDialog"
	fullscreen_overwrite_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fullscreen_overwrite_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_overwrite_dialog.visible = false
	root.add_child(fullscreen_overwrite_dialog)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.005, 0.012, 0.022, 0.94)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	fullscreen_overwrite_dialog.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	fullscreen_overwrite_dialog.add_child(center)

	var box_panel := PanelContainer.new()
	box_panel.custom_minimum_size = Vector2(490, 0)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.02, 0.045, 0.065, 0.98)
	box_style.border_color = Color(0.85, 0.55, 0.20, 0.88)
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(8)
	box_style.content_margin_left = 26
	box_style.content_margin_right = 26
	box_style.content_margin_top = 24
	box_style.content_margin_bottom = 24
	box_panel.add_theme_stylebox_override("panel", box_style)
	center.add_child(box_panel)

	var box_vbox := VBoxContainer.new()
	box_vbox.add_theme_constant_override("separation", 10)
	box_panel.add_child(box_vbox)

	var warning_header := _label("!  ATENÇÃO", 15, Color(1.0, 0.65, 0.2), true, false)
	box_vbox.add_child(warning_header)

	var ow_title := _label("MENU_OVERWRITE_TITLE", 22, Color(1.0, 0.95, 0.95), true)
	ow_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_vbox.add_child(ow_title)

	var amber_rule := ColorRect.new()
	amber_rule.color = Color(0.85, 0.55, 0.20, 0.75)
	amber_rule.custom_minimum_size = Vector2(0, 2)
	amber_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_vbox.add_child(amber_rule)

	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	box_vbox.add_child(gap)

	overwrite_slot_label = Label.new()
	overwrite_slot_label.add_theme_font_override("font", MENU_FONT)
	overwrite_slot_label.add_theme_font_size_override("font_size", 18)
	overwrite_slot_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.96))
	box_vbox.add_child(overwrite_slot_label)

	overwrite_info_label = Label.new()
	overwrite_info_label.add_theme_font_override("font", MENU_FONT)
	overwrite_info_label.add_theme_font_size_override("font_size", 14)
	overwrite_info_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.85))
	box_vbox.add_child(overwrite_info_label)

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 4
	box_vbox.add_child(gap2)

	var desc := _label("MENU_OVERWRITE_DESC", 14, Color(0.88, 0.82, 0.72), false)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_vbox.add_child(desc)

	var gap3 := Control.new()
	gap3.custom_minimum_size.y = 12
	box_vbox.add_child(gap3)

	var ow_buttons := VBoxContainer.new()
	ow_buttons.add_theme_constant_override("separation", 8)
	box_vbox.add_child(ow_buttons)

	overwrite_confirm_btn = _menu_button("MENU_OVERWRITE_CONFIRM", "OverwriteConfirmBtn", true)
	overwrite_confirm_btn.custom_minimum_size = Vector2(0, 48)
	ow_buttons.add_child(overwrite_confirm_btn)
	overwrite_confirm_btn.pressed.connect(_on_overwrite_confirmed)

	overwrite_cancel_btn = _menu_button("MENU_DELETE_CANCEL", "OverwriteCancelBtn", false)
	overwrite_cancel_btn.custom_minimum_size = Vector2(0, 48)
	ow_buttons.add_child(overwrite_cancel_btn)
	overwrite_cancel_btn.pressed.connect(_close_overwrite_confirmation)

	overwrite_confirm_btn.focus_neighbor_top = overwrite_cancel_btn.get_path()
	overwrite_confirm_btn.focus_neighbor_bottom = overwrite_cancel_btn.get_path()
	overwrite_cancel_btn.focus_neighbor_top = overwrite_confirm_btn.get_path()
	overwrite_cancel_btn.focus_neighbor_bottom = overwrite_confirm_btn.get_path()


func _open_overwrite_confirmation(slot: int) -> void:
	selected_slot = slot
	var info: Dictionary = Global.get_slot_info(slot)
	overwrite_slot_label.text = tr("MENU_SLOT_%d_LABEL" % slot).to_upper()
	overwrite_info_label.text = "%s  •  %s" % [info.get("fase_display", ""), info.get("date", "")]
	fullscreen_overwrite_dialog.visible = true
	overwrite_cancel_btn.grab_focus.call_deferred()


func _close_overwrite_confirmation() -> void:
	fullscreen_overwrite_dialog.visible = false
	if slot_cards.size() >= selected_slot and selected_slot > 0:
		slot_cards[selected_slot - 1].grab_focus.call_deferred()


func _on_overwrite_confirmed() -> void:
	fullscreen_overwrite_dialog.visible = false
	Global.delete_save_slot(selected_slot)
	_start_new_game_on_slot(selected_slot)


func _apply_menu_button_style(button: Button, is_danger: bool = false) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_font_size_override("font_size", 20)

	if is_danger:
		button.add_theme_color_override("font_color", Color(1.0, 0.78, 0.78))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.95))
		button.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.95))
		button.add_theme_color_override("font_disabled_color", Color(0.5, 0.35, 0.35, 0.7))
	else:
		button.add_theme_color_override("font_color", Color(0.84, 0.93, 0.93))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.82))
		button.add_theme_color_override("font_focus_color", Color(1.0, 0.97, 0.82))
		button.add_theme_color_override("font_disabled_color", Color(0.4, 0.53, 0.55, 0.7))

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		if is_danger:
			style.bg_color = Color(0.18, 0.03, 0.04, 0.35)
			style.border_width_left = 2
			style.border_color = Color(0.65, 0.20, 0.20, 0.5)
			style.content_margin_left = 18
			style.content_margin_right = 14
			if state == "hover" or state == "focus" or state == "pressed":
				style.bg_color = Color(0.45, 0.08, 0.12, 0.75)
				style.border_color = Color(1.0, 0.35, 0.35)
			elif state == "disabled":
				style.bg_color = Color(0.08, 0.02, 0.02, 0.15)
				style.border_color = Color(0.3, 0.12, 0.12, 0.25)
		else:
			style.bg_color = Color(0.015, 0.085, 0.11, 0.19)
			style.border_width_left = 2
			style.border_color = Color(0.20, 0.52, 0.60, 0.42)
			style.content_margin_left = 18
			style.content_margin_right = 14
			if state == "hover" or state == "focus" or state == "pressed":
				style.bg_color = Color(0.05, 0.20, 0.24, 0.68)
				style.border_color = Color(0.67, 0.92, 0.92)
			elif state == "disabled":
				style.bg_color = Color(0.01, 0.045, 0.06, 0.1)
				style.border_color = Color(0.17, 0.33, 0.36, 0.25)
		button.add_theme_stylebox_override(state, style)


func _menu_button(key: String, node_name: String, is_danger: bool = false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = tr(key).to_upper()
	button.custom_minimum_size = Vector2(0, 47)
	_apply_menu_button_style(button, is_danger)
	if is_instance_valid(menu_sounds):
		var sound_action := "back" if node_name.contains("Back") or node_name.contains("Cancel") else "confirm"
		menu_sounds.bind_button(button, sound_action)
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
	sand_steps.finished.connect(func(): if elapsed >= WALK_START and elapsed < WALK_START + WALK_DURATION and not leaving: sand_steps.play())
	add_child(sand_steps)
	memory_sound = AudioStreamPlayer.new()
	memory_sound.stream = load("res://assets/audio/kabelo_intro.mp3")
	memory_sound.volume_db = -8.0
	add_child(memory_sound)


func _on_new_game_pressed() -> void:
	if leaving:
		return
	if Global.has_any_save():
		_show_slots_menu("new_game")
	else:
		_start_new_game_on_slot(1)


func _on_load_pressed() -> void:
	if leaving:
		return
	_show_slots_menu("load")


func _start_new_game_on_slot(slot: int) -> void:
	if leaving:
		return
	leaving = true
	menu_sounds.play_start()
	Global.current_save_slot = slot
	Global.reset_default_values()
	Global.current_save_slot = slot
	var transition := create_tween()
	transition.tween_property(fade_rect, "color:a", 1.0, 1.7).set_trans(Tween.TRANS_SINE)
	await transition.finished
	get_tree().change_scene_to_file("res://scenes/battle_mode_selection.tscn")


func _load_selected_slot() -> void:
	if leaving:
		return
	leaving = true
	Global.current_save_slot = selected_slot
	var transition := create_tween()
	transition.tween_property(fade_rect, "color:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	await transition.finished
	Global.load_progress(selected_slot)


func _on_settings_pressed() -> void:
	get_node("ConfiguracoesDialog").abrir()


func _on_exit_pressed() -> void:
	get_tree().quit()
