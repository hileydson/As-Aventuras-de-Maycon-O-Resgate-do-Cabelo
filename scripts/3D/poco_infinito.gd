extends Node3D

const SURVIVAL_TIME:float = 90.0
const WELL_RADIUS:float = 8.4
const PLAYER_LIMIT:float = 5.0
const SHAFT_SPEED:float = 24.5
const MAYCON_DEPTH:float = 7.0
const DASH_SMOKE_TEXTURE:Texture2D = preload("res://assets/novas_imagens/effects/smoke_animation.png")
const OBSTACLE_SCENES:Array[String] = [
	"res://assets/polyhaven/endless_well/wooden_crate_01/wooden_crate_01_1k.gltf",
	"res://assets/polyhaven/endless_well/barrel_03/barrel_03_1k.gltf",
	"res://assets/polyhaven/endless_well/rusted_wheel_rim_01/rusted_wheel_rim_01_1k.gltf",
	"res://assets/polyhaven/endless_well/wooden_bucket_01/wooden_bucket_01_1k.gltf"
]
const OBSTACLE_RADIUS:Array[float] = [1.35, 1.1, 0.95, 0.9]
const OBSTACLE_SCALE:Array[float] = [2.7, 2.5, 2.6, 2.7]

@onready var camera:Camera3D = $Camera3D
@onready var hud:Control = $CanvasLayer/HUD
@onready var dash_blur:ColorRect = $CanvasLayer/DashBlur

var maycon:Node3D
var maycon_animation:AnimationPlayer
var maycon_skeleton:Skeleton3D
var falling_limb_poses:Array[Dictionary] = []
var maycon_rim_light:OmniLight3D
var blood_spray:CPUParticles3D
var body_trails:Array[Dictionary] = []
var body_streaks:Array[Dictionary] = []
var power_aura:MeshInstance3D
var obstacles:Array[Dictionary] = []
var obstacle_pool:Array[Dictionary] = []
var shaft_sections:Array[Node3D] = []
var speed_lines:Array[Dictionary] = []
var dash_puffs:Array[Dictionary] = []
var rock_material:StandardMaterial3D
var trim_material:StandardMaterial3D
var shaft_line_material:StandardMaterial3D
var music:AudioStreamPlayer
var wind:AudioStreamPlayer
var dash_sound:AudioStreamPlayer
var hit_sound:AudioStreamPlayer
var scream_sound:AudioStreamPlayer
var explosion_sound:AudioStreamPlayer
var health:float = 100.0
var pentagram_charge:float = 0.0
var pentagram_invulnerability:float = 0.0
var hit_combo:int = 0
var last_hit_at:float = -100.0
var elapsed:float = 0.0
var speed_factor:float = 0.0
var locally_paused:bool = false
var spawn_timer:float = 1.2
var next_kind:int = 0
var next_obstacle_fast:bool = false
var player_pos:Vector2 = Vector2.ZERO
var falling_motion:Vector2 = Vector2.ZERO
var hit_tumble_time:float = 0.0
var hit_tumble_side:float = 1.0
var last_direction:Vector2 = Vector2.RIGHT
var dash_direction:Vector2 = Vector2.ZERO
var dash_time:float = 0.0
var dash_cooldown:float = 0.0
var puff_timer:float = 0.0
var camera_shake:float = 0.0
var hurt_invulnerability:float = 0.0
var finishing:bool = false
var ending_time:float = 0.0
var ending_success:bool = false
var ending_start_pitch:float = 0.0
var ending_scream_started:bool = false
var transition_sent:bool = false

func _ready() -> void:
	get_tree().paused = false
	GameSongs.stop(1)
	camera.position = Vector3(3.0, 1.25, 15.0)
	camera.look_at(Vector3(0.0, 0.0, -6.0), Vector3.UP)
	create_materials()
	create_shaft()
	create_maycon()
	create_blood_spray()
	create_speed_lines()
	create_obstacle_pool()
	music = make_audio("res://assets/novos_audios/battle.mp3", -11.0, 1.58, true)
	wind = make_audio("res://assets/novos_audios/cidade_intro_wind.mp3", -10.0, 1.45, true)
	dash_sound = make_audio("res://assets/audio/peido.mp3", -3.0)
	hit_sound = make_audio("res://assets/novos_audios/hurt_sound_3d.mp3", -4.0)
	scream_sound = make_audio("res://assets/novos_audios/maycon_falling_fase_1.mp3", -2.0)
	explosion_sound = make_audio("res://assets/novos_audios/explosao.mp3", -5.0)
	music.play()
	wind.play()
	hud.call("set_state", health, 0.0, 0.0, 0.0, 0.0)

func make_audio(path:String, volume:float, pitch:float = 1.0, looped:bool = false) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream:AudioStream = load(path)
	if looped:
		stream = stream.duplicate()
		stream.set("loop", true)
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	add_child(player)
	return player

func create_materials() -> void:
	rock_material = StandardMaterial3D.new()
	rock_material.albedo_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_diff_1k.jpg")
	rock_material.normal_enabled = true
	rock_material.normal_texture = load("res://assets/polyhaven/realtime_battle/castle_wall_normal_1k.jpg")
	rock_material.roughness = 0.95
	rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock_material.uv1_scale = Vector3(3, 5, 1)
	trim_material = StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.06, 0.13, 0.18)
	trim_material.metallic = 0.65
	trim_material.roughness = 0.38
	trim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft_line_material = StandardMaterial3D.new()
	shaft_line_material.albedo_color = Color(0.12, 0.14, 0.16)
	shaft_line_material.emission_enabled = true
	shaft_line_material.emission = Color(0.055, 0.065, 0.075)
	shaft_line_material.emission_energy_multiplier = 0.7
	shaft_line_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func create_shaft() -> void:
	for index in 5:
		var section := Node3D.new()
		section.position.z = -36.0 + float(index) * 18.0
		add_child(section)
		shaft_sections.append(section)
		var wall := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = WELL_RADIUS
		tube.bottom_radius = WELL_RADIUS
		tube.height = 18.1
		tube.cap_top = false
		tube.cap_bottom = false
		tube.radial_segments = 40
		tube.rings = 3
		wall.mesh = tube
		wall.rotation.x = PI * 0.5
		wall.material_override = rock_material
		section.add_child(wall)
		for ring_index in 3:
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = WELL_RADIUS - 0.23
			torus.outer_radius = WELL_RADIUS + 0.08
			torus.rings = 8
			torus.ring_segments = 48
			ring.mesh = torus
			ring.material_override = trim_material if ring_index != 1 else shaft_line_material
			ring.rotation.x = PI * 0.5
			ring.position.z = -8.8 + float(ring_index) * 8.8
			section.add_child(ring)
		for detail_index in 12:
			var angle:float = float(detail_index) * TAU / 12.0 + float(index) * 0.21
			var bracket := MeshInstance3D.new()
			var plate := BoxMesh.new()
			plate.size = Vector3(0.42, 2.5 + float(detail_index % 3), 0.18)
			bracket.mesh = plate
			bracket.material_override = trim_material
			bracket.position = Vector3(cos(angle) * 8.17, sin(angle) * 8.17, -6.5 + float(detail_index % 4) * 4.2)
			bracket.rotation.z = angle + PI * 0.5
			bracket.rotation.x = PI * 0.5
			section.add_child(bracket)

func create_maycon() -> void:
	var scene:PackedScene = load("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
	maycon = scene.instantiate()
	maycon.name = "MayconFalling"
	maycon.scale = Vector3.ONE * 3.25
	maycon.rotation = Vector3(1.1, PI + 0.35, 0.1)
	add_child(maycon)
	maycon_animation = maycon.get_node_or_null("AnimationPlayer") as AnimationPlayer
	maycon_skeleton = maycon.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	pose_falling_body()
	create_body_effects()

func pose_falling_body() -> void:
	# Hold the model's natural A pose and move only the limbs during the fall.
	if maycon_animation && maycon_animation.has_animation("Idle"):
		maycon_animation.play("Idle")
		maycon_animation.seek(0.0, true)
		maycon_animation.pause()
	for bone_name in ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftHand", "RightHand", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
		var bone_index:int = maycon_skeleton.find_bone(bone_name)
		if bone_index >= 0:
			falling_limb_poses.append({"name":bone_name, "index":bone_index, "rotation":maycon_skeleton.get_bone_pose_rotation(bone_index), "phase":float(falling_limb_poses.size()) * 1.7, "angle":0.0, "velocity":0.0})

func animate_falling_limbs(delta:float) -> void:
	for limb in falling_limb_poses:
		var is_arm:bool = "Arm" in limb.name or "Hand" in limb.name
		var is_hand:bool = "Hand" in limb.name
		var axis:Vector3 = Vector3.FORWARD if is_arm else Vector3.RIGHT
		var phase:float = limb.phase
		var side:float = 1.0 if "Left" in limb.name else -1.0
		var sway:float = sin(elapsed * 2.2 + phase) * (0.035 if is_arm else 0.05)
		var flutter:float = sin(elapsed * 5.6 + phase * 1.3) * (0.02 + speed_factor * 0.012)
		var drag:float = -falling_motion.x * side * (0.012 if is_hand else 0.007)
		drag += falling_motion.y * (0.007 if is_arm else 0.009)
		var target:float = clampf(sway + flutter + drag, -0.28, 0.28)
		var spring:float = 15.0 if is_hand else 23.0
		var damping:float = 6.0 if is_hand else 8.0
		limb["velocity"] = float(limb.velocity) + ((target - float(limb.angle)) * spring - float(limb.velocity) * damping) * delta
		limb["angle"] = clampf(float(limb.angle) + float(limb.velocity) * delta, -0.35, 0.35)
		maycon_skeleton.set_bone_pose_rotation(limb.index, limb.rotation * Quaternion(axis, float(limb.angle)))

func create_blood_spray() -> void:
	blood_spray = CPUParticles3D.new()
	blood_spray.name = "HitBloodSpray"
	blood_spray.amount = 145
	blood_spray.lifetime = 1.15
	blood_spray.one_shot = true
	blood_spray.explosiveness = 1.0
	blood_spray.local_coords = false
	blood_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	blood_spray.emission_sphere_radius = 0.55
	blood_spray.direction = Vector3(0.0, 0.0, 1.0)
	blood_spray.spread = 98.0
	blood_spray.gravity = Vector3(0.0, -1.5, 2.0)
	blood_spray.initial_velocity_min = 7.0
	blood_spray.initial_velocity_max = 16.0
	blood_spray.scale_amount_min = 0.55
	blood_spray.scale_amount_max = 1.5
	var blood_fade := Gradient.new()
	blood_fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	blood_fade.add_point(0.55, Color(0.8, 0.45, 0.45, 0.85))
	blood_fade.set_color(2, Color(0.5, 0.1, 0.1, 0.0))
	blood_spray.color_ramp = blood_fade
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.09
	droplet_mesh.height = 0.18
	droplet_mesh.radial_segments = 6
	droplet_mesh.rings = 3
	var blood_material := StandardMaterial3D.new()
	blood_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blood_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blood_material.albedo_color = Color(0.82, 0.015, 0.025, 0.9)
	droplet_mesh.material = blood_material
	blood_spray.mesh = droplet_mesh
	blood_spray.emitting = false
	add_child(blood_spray)

func create_body_effects() -> void:
	maycon_rim_light = OmniLight3D.new()
	maycon_rim_light.light_color = Color(0.2, 0.8, 1.0)
	maycon_rim_light.light_energy = 1.2
	maycon_rim_light.omni_range = 5.0
	add_child(maycon_rim_light)
	for i in 7:
		var shadow := MeshInstance3D.new()
		shadow.name = "FallingShadowTrail%d" % i
		var ribbon := CylinderMesh.new()
		ribbon.top_radius = 0.02
		ribbon.bottom_radius = 0.24 + float(i % 3) * 0.08
		ribbon.height = 2.0 + float(i % 3) * 0.65
		ribbon.radial_segments = 6
		shadow.mesh = ribbon
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.02, 0.08, 0.16, 0.08 + float(i % 3) * 0.018)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		shadow.material_override = material
		add_child(shadow)
		body_trails.append({"node":shadow, "side":(-1.0 if i % 2 else 1.0) * (0.35 + float(i % 4) * 0.28), "lag":float(i % 3) * 0.3})
	power_aura = MeshInstance3D.new()
	var aura_mesh := TorusMesh.new()
	aura_mesh.inner_radius = 1.55
	aura_mesh.outer_radius = 1.68
	aura_mesh.rings = 8
	aura_mesh.ring_segments = 48
	power_aura.mesh = aura_mesh
	power_aura.rotation.x = PI * 0.5
	var aura_material := StandardMaterial3D.new()
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.albedo_color = Color(0.19, 0.87, 1.0, 0.68)
	aura_material.emission_enabled = true
	aura_material.emission = Color(0.1, 0.68, 1.0)
	aura_material.emission_energy_multiplier = 3.0
	power_aura.material_override = aura_material
	power_aura.visible = false
	add_child(power_aura)
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	streak_material.albedo_color = Color(0.53, 0.56, 0.6, 0.38)
	streak_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 52:
		var streak := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.014, randf_range(0.22, 0.58))
		streak.mesh = mesh
		streak.material_override = streak_material
		streak.rotation.z = randf_range(-0.15, 0.15)
		add_child(streak)
		body_streaks.append({"node":streak, "phase":randf(), "offset":Vector2(randf_range(-0.55, 0.55), randf_range(-0.9, 1.0))})

func create_speed_lines() -> void:
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.albedo_color = Color(0.24, 0.72, 1.0, 0.5)
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 80:
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, randf_range(1.6, 4.8))
		streak.mesh = mesh
		streak.material_override = streak_material
		streak.position = Vector3(randf_range(-7.4, 7.4), randf_range(-7.4, 7.4), randf_range(-30.0, 7.0))
		add_child(streak)
		speed_lines.append({"node":streak, "speed":randf_range(50.0, 96.0)})

func _process(delta:float) -> void:
	if Input.is_action_just_pressed("ui_cancel") && !finishing:
		toggle_pause()
	if locally_paused:
		return
	elapsed += delta
	speed_factor = clampf(elapsed / SURVIVAL_TIME, 0.0, 1.0)
	animate_environment(delta)
	update_dash_puffs(delta)
	camera_shake = maxf(0.0, camera_shake - delta * 1.25)
	camera.position = Vector3(3.0, 1.25, 15.0) + Vector3(randf_range(-camera_shake, camera_shake), randf_range(-camera_shake, camera_shake), 0.0)
	camera.fov = 66.0 + (5.0 if dash_time > 0.0 else 0.0) + sin(elapsed * 3.5) * 0.35
	if finishing:
		dash_blur.visible = false
		update_ending(delta)
		hud.call("set_state", health, 1.0, pentagram_charge, 0.0, ending_time, Vector2.ZERO, speed_factor, 0.0)
		return
	if elapsed >= SURVIVAL_TIME:
		start_ending(true)
		return
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hurt_invulnerability = maxf(0.0, hurt_invulnerability - delta)
	pentagram_invulnerability = maxf(0.0, pentagram_invulnerability - delta)
	if pentagram_invulnerability <= 0.0:
		pentagram_charge = minf(1.0, pentagram_charge + delta * (0.023 + speed_factor * 0.025))
	if Input.is_action_just_pressed("key_q") && pentagram_charge >= 1.0 && pentagram_invulnerability <= 0.0:
		activate_pentagram()
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction.y = -input_direction.y
	if input_direction.length() > 0.15:
		last_direction = input_direction.normalized()
	if Input.is_action_just_pressed("ui_accept") && dash_cooldown <= 0.0:
		start_dash(input_direction)
	var previous_player_pos:Vector2 = player_pos
	if dash_time > 0.0:
		player_pos += dash_direction * (17.5 + speed_factor * 3.0) * delta
		puff_timer -= delta
		if puff_timer <= 0.0:
			puff_timer = 0.06
			spawn_dash_trail()
	else:
		player_pos += input_direction * (6.8 + speed_factor * 1.2) * delta
	player_pos.x = clampf(player_pos.x, -PLAYER_LIMIT, PLAYER_LIMIT)
	player_pos.y = clampf(player_pos.y, -PLAYER_LIMIT, PLAYER_LIMIT)
	falling_motion = falling_motion.lerp((player_pos - previous_player_pos) / maxf(delta, 0.001), minf(1.0, delta * 8.0))
	hit_tumble_time = maxf(0.0, hit_tumble_time - delta)
	var tumble_progress:float = 1.0 - hit_tumble_time / 1.05
	var tumble_angle:float = hit_tumble_side * TAU * (1.0 - pow(1.0 - tumble_progress, 2.2)) if hit_tumble_time > 0.0 else 0.0
	maycon.position = Vector3(player_pos.x, player_pos.y, MAYCON_DEPTH)
	maycon.rotation.z = sin(elapsed * 3.2) * 0.08 - player_pos.x * 0.035 - falling_motion.x * 0.012
	maycon.rotation.x = 1.1 + sin(elapsed * 2.1) * 0.045 + falling_motion.y * 0.007
	maycon.rotation.y = PI + 0.35 + falling_motion.x * 0.01
	if hit_tumble_time > 0.0:
		var tumble_transform:Transform3D = maycon.transform
		tumble_transform.basis = Basis(Vector3.FORWARD, tumble_angle) * tumble_transform.basis
		maycon.transform = tumble_transform
	animate_falling_limbs(delta)
	update_body_effects(delta)
	update_dash_blur()
	spawn_timer -= delta
	if spawn_timer <= 0.0 && obstacles.is_empty():
		spawn_obstacle()
	update_obstacles(delta)
	hud.call("set_state", health, speed_factor, pentagram_charge, dash_cooldown, 0.0, camera.unproject_position(maycon.position), speed_factor, pentagram_invulnerability)

func toggle_pause() -> void:
	locally_paused = !locally_paused
	music.stream_paused = locally_paused
	wind.stream_paused = locally_paused
	hud.call("set_pause", locally_paused)
	hud.set_process(!locally_paused)
	blood_spray.speed_scale = 0.0 if locally_paused else 1.0
	dash_blur.visible = false if locally_paused else dash_time > 0.0

func activate_pentagram() -> void:
	pentagram_charge = 0.0
	pentagram_invulnerability = 4.0
	hurt_invulnerability = maxf(hurt_invulnerability, 4.0)
	camera_shake = maxf(camera_shake, 0.42)
	explosion_sound.pitch_scale = 1.18
	explosion_sound.play()
	hud.call("activate_power")

func animate_environment(delta:float) -> void:
	var speed_multiplier:float = 1.0 + speed_factor * 1.65
	for section in shaft_sections:
		section.position.z += SHAFT_SPEED * speed_multiplier * delta
		if section.position.z > 36.0:
			section.position.z -= 90.0
	for streak_data in speed_lines:
		var streak:MeshInstance3D = streak_data.node
		streak.position.z += float(streak_data.speed) * speed_multiplier * delta
		if streak.position.z > 10.0:
			streak.position.z = -30.0
			streak.position.x = randf_range(-7.4, 7.4)
			streak.position.y = randf_range(-7.4, 7.4)
	$BloodLight.light_energy = 2.3 + sin(elapsed * (3.0 + speed_factor * 5.0)) * 0.45 + speed_factor * 1.2
	music.pitch_scale = 1.58 + speed_factor * 0.23
	wind.pitch_scale = 1.45 + speed_factor * 0.38

func update_body_effects(delta:float) -> void:
	maycon_rim_light.position = maycon.position + Vector3(0.9, 0.8, 1.4)
	maycon_rim_light.light_energy = 3.2 if pentagram_invulnerability > 0.0 else (2.4 if dash_time > 0.0 else 1.2)
	for trail_data in body_trails:
		var ghost:MeshInstance3D = trail_data.node
		var lag:float = trail_data.lag
		ghost.position = ghost.position.lerp(maycon.position + Vector3(trail_data.side, 0.7 + lag, -0.6 - lag), minf(1.0, delta * (5.5 - lag)))
		ghost.rotation.z = sin(elapsed * 3.0 + lag * 5.0) * 0.17
		ghost.visible = !finishing
		var shadow_material:StandardMaterial3D = ghost.material_override
		shadow_material.albedo_color.a = (0.08 + speed_factor * 0.045) * (1.5 if dash_time > 0.0 else 1.0)
	for streak_data in body_streaks:
		var streak:MeshInstance3D = streak_data.node
		var phase:float = fposmod(float(streak_data.phase) + elapsed * (3.5 if dash_time > 0.0 else 2.1 + speed_factor * 0.9), 1.0)
		var offset:Vector2 = streak_data.offset
		streak.position = maycon.position + Vector3(offset.x + 0.35, offset.y + 0.65, 0.2 + phase * 0.9)
		streak.scale.y = 1.55 if dash_time > 0.0 else 1.0
		streak.transparency = 0.28 + absf(phase - 0.5) * 0.75
		streak.visible = !finishing
	power_aura.visible = pentagram_invulnerability > 0.0 && !finishing
	if power_aura.visible:
		power_aura.position = maycon.position + Vector3(0.0, 0.0, 0.1)
		power_aura.scale = Vector3.ONE * (1.0 + sin(elapsed * 17.0) * 0.13)

func update_dash_blur() -> void:
	dash_blur.visible = dash_time > 0.0
	if !dash_blur.visible:
		return
	var from_screen:Vector2 = camera.unproject_position(maycon.position)
	var to_screen:Vector2 = camera.unproject_position(maycon.position + Vector3(dash_direction.x, dash_direction.y, 0.0))
	var screen_direction:Vector2 = (to_screen - from_screen).normalized()
	var material:ShaderMaterial = dash_blur.material
	material.set_shader_parameter("blur_direction", screen_direction)
	material.set_shader_parameter("blur_center", from_screen / get_viewport().get_visible_rect().size)
	material.set_shader_parameter("blur_strength", clampf(dash_time / 0.22, 0.0, 1.0))

func spawn_dash_burst() -> void:
	for i in 7:
		spawn_smoke_cloud(true)

func spawn_dash_trail() -> void:
	for i in 2:
		spawn_smoke_cloud(false)

func spawn_smoke_cloud(initial:bool) -> void:
	var cloud := Sprite3D.new()
	cloud.texture = DASH_SMOKE_TEXTURE
	cloud.hframes = 3
	cloud.vframes = 2
	cloud.frame = randi_range(0, 1)
	cloud.pixel_size = randf_range(0.009, 0.014) if initial else randf_range(0.007, 0.011)
	cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cloud.shaded = false
	cloud.transparent = true
	cloud.double_sided = true
	cloud.position = maycon.position - Vector3(dash_direction.x * 0.8, dash_direction.y * 0.8, 0.45)
	cloud.position += Vector3(randf_range(-0.48, 0.48), randf_range(-0.4, 0.4), randf_range(-0.55, 0.12))
	cloud.rotation.z = randf_range(-0.48, 0.48)
	var alpha:float = randf_range(0.36, 0.56) if initial else randf_range(0.23, 0.4)
	cloud.modulate = Color(randf_range(0.48, 0.62), randf_range(0.79, 0.92), randf_range(0.55, 0.71), alpha)
	add_child(cloud)
	var side:Vector2 = Vector2(-dash_direction.y, dash_direction.x) * randf_range(-2.1, 2.1)
	var velocity:Vector3 = Vector3(-dash_direction.x * 2.7 + side.x, -dash_direction.y * 2.7 + side.y + 0.65, randf_range(1.1, 2.4))
	var duration:float = randf_range(0.42, 0.64) if initial else randf_range(0.35, 0.5)
	dash_puffs.append({"node":cloud, "life":duration, "duration":duration, "velocity":velocity, "alpha":alpha, "start_frame":cloud.frame})

func update_dash_puffs(delta:float) -> void:
	for i in range(dash_puffs.size() - 1, -1, -1):
		var data:Dictionary = dash_puffs[i]
		var puff:Sprite3D = data.node
		data["life"] = float(data.life) - delta
		puff.position += data.velocity * delta
		puff.scale += Vector3.ONE * delta * 0.55
		var progress:float = 1.0 - clampf(float(data.life) / float(data.duration), 0.0, 1.0)
		puff.frame = mini(5, int(data.start_frame) + int(progress * 5.0))
		puff.modulate.a = (1.0 - smoothstep(0.2, 1.0, progress)) * float(data.alpha)
		if data.life <= 0.0:
			puff.queue_free()
			dash_puffs.remove_at(i)

func start_dash(direction:Vector2) -> void:
	dash_direction = direction.normalized() if direction.length() > 0.15 else last_direction
	dash_time = 0.22
	dash_cooldown = 0.6
	puff_timer = 0.0
	camera_shake = maxf(camera_shake, 0.12)
	dash_sound.pitch_scale = randf_range(0.7, 0.8)
	dash_sound.volume_db = -3.0
	dash_sound.play()
	spawn_dash_burst()
	hud.call("dash_flash")

func create_obstacle_pool() -> void:
	for kind in OBSTACLE_SCENES.size():
		var scene:PackedScene = load(OBSTACLE_SCENES[kind])
		var object := Node3D.new()
		object.name = "Debris_%d" % kind
		var mesh:Node3D = scene.instantiate()
		mesh.scale = Vector3.ONE * OBSTACLE_SCALE[kind]
		object.add_child(mesh)
		var fade_materials:Array[StandardMaterial3D] = []
		for child in mesh.find_children("*", "GeometryInstance3D", true, false):
			var part:MeshInstance3D = child as MeshInstance3D
			for surface in part.mesh.get_surface_count():
				var material:StandardMaterial3D = part.get_active_material(surface).duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				part.set_surface_override_material(surface, material)
				fade_materials.append(material)
		var object_light := OmniLight3D.new()
		object_light.light_color = Color(1.0, 0.92, 0.82)
		object_light.light_energy = 0.0
		object_light.omni_range = 9.5
		object_light.position.z = 2.4
		object.add_child(object_light)
		object.hide()
		add_child(object)
		obstacle_pool.append({"node":object, "fade_materials":fade_materials, "light":object_light})

func spawn_obstacle() -> void:
	var kind:int = next_kind
	next_kind = (next_kind + randi_range(1, 3)) % OBSTACLE_SCENES.size()
	var pool_item:Dictionary = obstacle_pool[kind]
	var object:Node3D = pool_item.node
	var radius:float = OBSTACLE_RADIUS[kind] * randf_range(0.88, 1.22)
	object.scale = Vector3.ONE * (radius / OBSTACLE_RADIUS[kind])
	object.rotation = Vector3.ZERO
	var origin := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 4.3
	if randf() < 0.3:
		origin = player_pos + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 0.55)
		origin.x = clampf(origin.x, -5.1, 5.1)
		origin.y = clampf(origin.y, -5.1, 5.1)
	object.position = Vector3(origin.x, origin.y, -36.0)
	set_obstacle_fade(pool_item, 0.0)
	(pool_item.light as OmniLight3D).light_energy = 0.0
	object.show()
	var drift := Vector2(randf_range(-0.35, 0.35), randf_range(-0.26, 0.26))
	var speed:float = (randf_range(21.5, 26.0) if next_obstacle_fast else randf_range(15.0, 18.5)) * (1.0 + speed_factor * 1.6)
	next_obstacle_fast = !next_obstacle_fast
	obstacles.append({"node":object, "position":object.position, "speed":speed, "drift":drift, "radius":radius, "kind":kind, "spin":randf_range(-3.2, 3.2), "resolved":false})
	spawn_timer = lerpf(0.6, 0.24, speed_factor)

func set_obstacle_fade(pool_item:Dictionary, fade:float) -> void:
	for material in pool_item.fade_materials:
		var color:Color = (material as StandardMaterial3D).albedo_color
		color.a = fade
		(material as StandardMaterial3D).albedo_color = color
	(pool_item.light as OmniLight3D).light_energy = 7.0 * fade

func update_obstacles(delta:float) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle:Dictionary = obstacles[i]
		var previous_z:float = obstacle.position.z
		var pos:Vector3 = obstacle.position
		pos.z += float(obstacle.speed) * delta
		pos.x += obstacle.drift.x * delta
		pos.y += obstacle.drift.y * delta
		obstacle["position"] = pos
		var node:Node3D = obstacle.node
		node.position = pos
		node.rotation += Vector3(float(obstacle.spin) * delta * 0.55, float(obstacle.spin) * delta, float(obstacle.spin) * delta * 0.35)
		var pool_item:Dictionary = obstacle_pool[int(obstacle.kind)]
		if previous_z <= -27.0:
			set_obstacle_fade(pool_item, smoothstep(-36.0, -27.0, pos.z))
		if previous_z < MAYCON_DEPTH && pos.z >= MAYCON_DEPTH && !obstacle.resolved:
			resolve_obstacle(obstacle)
			obstacle["resolved"] = true
		if pos.z > MAYCON_DEPTH + 4.0:
			node.hide()
			(pool_item.light as OmniLight3D).light_energy = 0.0
			obstacles.remove_at(i)
			spawn_timer = maxf(spawn_timer, randf_range(0.34, 0.6) * (1.0 - speed_factor * 0.48))

func resolve_obstacle(obstacle:Dictionary) -> void:
	var pos:Vector3 = obstacle.position
	var distance:float = player_pos.distance_to(Vector2(pos.x, pos.y))
	var collision_radius:float = float(obstacle.radius) + 0.75
	if distance < collision_radius:
		if hurt_invulnerability <= 0.0 && pentagram_invulnerability <= 0.0:
			apply_hit(obstacle)

func apply_hit(obstacle:Dictionary) -> void:
	var combo_window:bool = elapsed - last_hit_at <= 5.0
	hit_combo = hit_combo + 1 if combo_window else 1
	last_hit_at = elapsed
	var damage:float = 11.0 + float(obstacle.radius) * 10.0
	if hit_combo >= 3:
		damage *= 1.45
	health = maxf(0.0, health - damage)
	hurt_invulnerability = 0.9
	camera_shake = maxf(camera_shake, 0.52)
	hit_tumble_time = 1.05
	hit_tumble_side = -1.0 if randf() < 0.5 else 1.0
	falling_motion += Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
	hit_sound.pitch_scale = randf_range(0.88, 1.13)
	hit_sound.play()
	blood_spray.position = maycon.position
	blood_spray.restart()
	blood_spray.emitting = true
	var screen_pos:Vector2 = camera.unproject_position(obstacle.position)
	hud.call("show_hit", screen_pos, hit_combo, damage, camera.unproject_position(maycon.position))
	if health <= 0.0:
		start_ending(false)

func start_ending(success:bool) -> void:
	finishing = true
	for trail_data in body_trails:
		(trail_data.node as Node3D).visible = false
	for streak_data in body_streaks:
		(streak_data.node as MeshInstance3D).visible = false
	maycon_rim_light.light_energy = 0.0
	power_aura.visible = false
	ending_success = success
	if success:
		hit_tumble_time = 0.0
		falling_motion = Vector2.ZERO
		maycon.rotation = Vector3(1.1, PI + 0.35, 0.1)
	ending_start_pitch = maycon.rotation.x
	ending_time = 0.0
	ending_scream_started = false
	transition_sent = false
	if success:
		camera_shake = 0.7
		explosion_sound.play()
		hud.call("explode_pentagram")
	else:
		if maycon_animation && maycon_animation.has_animation("Dead"):
			maycon_animation.play("Dead")
		scream_sound.play()
		hud.call("show_death")

func update_ending(delta:float) -> void:
	ending_time += delta
	if ending_success:
		animate_falling_limbs(delta)
		var turn_progress:float = clampf((ending_time - 0.18) / 1.0, 0.0, 1.0)
		maycon.rotation.x = ending_start_pitch + smoothstep(0.0, 1.0, turn_progress) * PI
		if ending_time > 0.75 && !ending_scream_started:
			ending_scream_started = true
			scream_sound.play()
		if ending_time > 1.2:
			maycon.position.y -= 13.0 * delta
			maycon.position.z -= 9.0 * delta
		if ending_time > 2.5 && !transition_sent:
			transition_sent = true
			get_tree().change_scene_to_file("res://scenes/3D/cenario_3d_bofore_castle_1.tscn")
	else:
		if hit_tumble_time > 0.0:
			hit_tumble_time = maxf(0.0, hit_tumble_time - delta)
			var tumble_transform:Transform3D = maycon.transform
			tumble_transform.basis = Basis(Vector3.FORWARD, hit_tumble_side * 12.0 * delta) * tumble_transform.basis
			maycon.transform = tumble_transform
		if ending_time > 1.6 && !transition_sent:
			transition_sent = true
			GameSongs.play_song(1)
			get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")
