extends Node3D

const DODGES_TO_ESCAPE:int = 20
const WELL_RADIUS:float = 8.4
const PLAYER_LIMIT:float = 5.0
const DASH_WINDOW_START:float = -8.0
const DASH_WINDOW_END:float = -1.3
const SHAFT_SPEED:float = 21.0
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
var obstacles:Array[Dictionary] = []
var shaft_sections:Array[Node3D] = []
var speed_lines:Array[Dictionary] = []
var dash_puffs:Array[Dictionary] = []
var rock_material:StandardMaterial3D
var trim_material:StandardMaterial3D
var red_material:StandardMaterial3D
var music:AudioStreamPlayer
var wind:AudioStreamPlayer
var dash_sound:AudioStreamPlayer
var hit_sound:AudioStreamPlayer
var evade_sound:AudioStreamPlayer
var scream_sound:AudioStreamPlayer
var explosion_sound:AudioStreamPlayer
var health:float = 100.0
var dodges:int = 0
var hit_combo:int = 0
var last_hit_at:float = -100.0
var elapsed:float = 0.0
var spawn_timer:float = 1.2
var next_kind:int = 0
var next_obstacle_fast:bool = false
var player_pos:Vector2 = Vector2.ZERO
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
	create_speed_lines()
	music = make_audio("res://assets/novos_audios/battle.mp3", -11.0, 1.5, true)
	wind = make_audio("res://assets/novos_audios/cidade_intro_wind.mp3", -10.0, 1.35, true)
	dash_sound = make_audio("res://assets/audio/peido.mp3", -3.0)
	hit_sound = make_audio("res://assets/novos_audios/hurt_sound_3d.mp3", -4.0)
	evade_sound = make_audio("res://assets/novos_audios/punch_1.mp3", -6.0)
	scream_sound = make_audio("res://assets/novos_audios/maycon_falling_fase_1.mp3", -2.0)
	explosion_sound = make_audio("res://assets/novos_audios/explosao.mp3", -5.0)
	music.play()
	wind.play()
	hud.call("set_state", health, dodges, DODGES_TO_ESCAPE, 0.0, -1.0, 0.0)

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
	red_material = StandardMaterial3D.new()
	red_material.albedo_color = Color(0.58, 0.025, 0.07)
	red_material.emission_enabled = true
	red_material.emission = Color(0.8, 0.025, 0.055)
	red_material.emission_energy_multiplier = 2.0
	red_material.cull_mode = BaseMaterial3D.CULL_DISABLED

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
			ring.material_override = trim_material if ring_index != 1 else red_material
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
	maycon.scale = Vector3.ONE * 2.8
	maycon.rotation = Vector3(1.1, PI + 0.35, 0.1)
	add_child(maycon)
	maycon_animation = maycon.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if maycon_animation:
		if maycon_animation.has_animation("BeHit_FlyUp"):
			maycon_animation.play("BeHit_FlyUp")
		elif maycon_animation.get_animation_list().size() > 0:
			maycon_animation.play(maycon_animation.get_animation_list()[0])

func create_speed_lines() -> void:
	var streak_material := StandardMaterial3D.new()
	streak_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_material.albedo_color = Color(0.24, 0.72, 1.0, 0.5)
	streak_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 64:
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.035, randf_range(1.6, 4.8))
		streak.mesh = mesh
		streak.material_override = streak_material
		streak.position = Vector3(randf_range(-7.4, 7.4), randf_range(-7.4, 7.4), randf_range(-30.0, 7.0))
		add_child(streak)
		speed_lines.append({"node":streak, "speed":randf_range(42.0, 82.0)})

func _process(delta:float) -> void:
	elapsed += delta
	animate_environment(delta)
	update_dash_puffs(delta)
	camera_shake = maxf(0.0, camera_shake - delta * 1.25)
	camera.position = Vector3(3.0, 1.25, 15.0) + Vector3(randf_range(-camera_shake, camera_shake), randf_range(-camera_shake, camera_shake), 0.0)
	camera.fov = 66.0 + (5.0 if dash_time > 0.0 else 0.0) + sin(elapsed * 3.5) * 0.35
	if finishing:
		dash_blur.visible = false
		update_ending(delta)
		hud.call("set_state", health, dodges, DODGES_TO_ESCAPE, dash_cooldown, -1.0, ending_time)
		return
	if maycon_animation && maycon_animation.has_animation("BeHit_FlyUp") && !maycon_animation.is_playing():
		maycon_animation.play("BeHit_FlyUp")
	dash_time = maxf(0.0, dash_time - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hurt_invulnerability = maxf(0.0, hurt_invulnerability - delta)
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction.y = -input_direction.y
	if input_direction.length() > 0.15:
		last_direction = input_direction.normalized()
	if Input.is_action_just_pressed("ui_accept") && dash_cooldown <= 0.0:
		start_dash(input_direction)
	if dash_time > 0.0:
		player_pos += dash_direction * 15.5 * delta
		puff_timer -= delta
		if puff_timer <= 0.0:
			puff_timer = 0.055
			spawn_dash_puff()
	else:
		player_pos += input_direction * 6.2 * delta
	player_pos.x = clampf(player_pos.x, -PLAYER_LIMIT, PLAYER_LIMIT)
	player_pos.y = clampf(player_pos.y, -PLAYER_LIMIT, PLAYER_LIMIT)
	maycon.position = Vector3(player_pos.x, player_pos.y, 0.0)
	maycon.rotation.z = sin(elapsed * 3.2) * 0.08 - player_pos.x * 0.035
	maycon.rotation.x = 1.1 + sin(elapsed * 2.1) * 0.045
	update_dash_blur()
	spawn_timer -= delta
	if spawn_timer <= 0.0 && obstacles.size() == 0:
		spawn_obstacle()
	update_obstacles(delta)
	var threat_z:float = -1.0
	var threat_screen:Vector2 = Vector2.ZERO
	if obstacles.size() > 0:
		threat_z = float(obstacles[0]["position"].z)
		threat_screen = camera.unproject_position(obstacles[0]["position"])
	if dash_time > 0.0:
		threat_z = -1.0
	hud.call("set_state", health, dodges, DODGES_TO_ESCAPE, dash_cooldown, threat_z, 0.0, threat_screen)

func animate_environment(delta:float) -> void:
	for section in shaft_sections:
		section.position.z += SHAFT_SPEED * delta
		if section.position.z > 36.0:
			section.position.z -= 90.0
	for streak_data in speed_lines:
		var streak:MeshInstance3D = streak_data.node
		streak.position.z += float(streak_data.speed) * delta
		if streak.position.z > 10.0:
			streak.position.z = -30.0
			streak.position.x = randf_range(-7.4, 7.4)
			streak.position.y = randf_range(-7.4, 7.4)
	$BloodLight.light_energy = 2.3 + sin(elapsed * 3.0) * 0.45 + float(dodges) * 0.035

func update_dash_blur() -> void:
	dash_blur.visible = dash_time > 0.0
	if !dash_blur.visible:
		return
	var from_screen:Vector2 = camera.unproject_position(Vector3(player_pos.x, player_pos.y, 0.0))
	var to_screen:Vector2 = camera.unproject_position(Vector3(player_pos.x + dash_direction.x, player_pos.y + dash_direction.y, 0.0))
	var screen_direction:Vector2 = (to_screen - from_screen).normalized()
	var material:ShaderMaterial = dash_blur.material
	material.set_shader_parameter("blur_direction", screen_direction)
	material.set_shader_parameter("blur_strength", clampf(dash_time / 0.22, 0.0, 1.0))

func spawn_dash_puff() -> void:
	var puff := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = randf_range(0.16, 0.3)
	sphere.height = sphere.radius * 2.0
	puff.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.26, 0.95, 0.72, 0.68)
	material.emission_enabled = true
	material.emission = Color(0.15, 0.7, 0.65)
	puff.material_override = material
	puff.position = Vector3(player_pos.x - dash_direction.x * 0.65, player_pos.y - dash_direction.y * 0.65, 0.3)
	add_child(puff)
	dash_puffs.append({"node":puff, "life":0.52, "drift":Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))})

func update_dash_puffs(delta:float) -> void:
	for i in range(dash_puffs.size() - 1, -1, -1):
		var data:Dictionary = dash_puffs[i]
		var puff:MeshInstance3D = data.node
		data["life"] = float(data.life) - delta
		puff.position.x += data.drift.x * delta
		puff.position.y += data.drift.y * delta
		puff.position.z += 2.0 * delta
		puff.scale += Vector3.ONE * delta * 1.8
		var material:StandardMaterial3D = puff.material_override
		material.albedo_color.a = clampf(float(data.life) / 0.52, 0.0, 1.0) * 0.68
		if data.life <= 0.0:
			puff.queue_free()
			dash_puffs.remove_at(i)

func start_dash(direction:Vector2) -> void:
	var target:Dictionary = {}
	for obstacle in obstacles:
		var position:Vector3 = obstacle.position
		var time_to_impact:float = -position.z / float(obstacle.get("speed", 10.0))
		var predicted := Vector2(position.x, position.y) + (obstacle.get("drift", Vector2.ZERO) as Vector2) * time_to_impact
		var distance:float = player_pos.distance_to(predicted)
		if position.z >= DASH_WINDOW_START && position.z <= DASH_WINDOW_END && distance <= float(obstacle.radius) + 0.87:
			target = obstacle
			break
	if target.is_empty():
		return
	target["dash_primed"] = true
	dash_direction = direction.normalized() if direction.length() > 0.15 else last_direction
	dash_time = 0.22
	dash_cooldown = 0.6
	puff_timer = 0.0
	camera_shake = maxf(camera_shake, 0.12)
	dash_sound.pitch_scale = randf_range(0.95, 1.12)
	dash_sound.play()
	hud.call("dash_flash")

func spawn_obstacle() -> void:
	var kind:int = next_kind
	next_kind = (next_kind + randi_range(1, 3)) % OBSTACLE_SCENES.size()
	var scene:PackedScene = load(OBSTACLE_SCENES[kind])
	var object := Node3D.new()
	object.name = "Debris_%d" % kind
	var mesh:Node3D = scene.instantiate()
	mesh.scale = Vector3.ONE * OBSTACLE_SCALE[kind]
	object.add_child(mesh)
	var radius:float = OBSTACLE_RADIUS[kind] * randf_range(0.88, 1.22)
	object.scale = Vector3.ONE * (radius / OBSTACLE_RADIUS[kind])
	var offset := Vector2(randf_range(-1.35, 1.35), randf_range(-1.35, 1.35))
	if offset.length() < 0.7:
		offset = Vector2.from_angle(randf() * TAU) * 0.9
	var origin := player_pos + offset
	origin.x = clampf(origin.x, -4.3, 4.3)
	origin.y = clampf(origin.y, -4.3, 4.3)
	object.position = Vector3(origin.x, origin.y, -30.0)
	var trail := MeshInstance3D.new()
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = radius * 0.16
	trail_mesh.bottom_radius = radius * 0.04
	trail_mesh.height = 2.9
	trail_mesh.radial_segments = 8
	trail.mesh = trail_mesh
	trail.rotation.x = PI * 0.5
	trail.position.z = -1.7
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.albedo_color = Color(1.0, 0.16, 0.055, 0.3) if kind % 2 == 0 else Color(0.3, 0.8, 1.0, 0.32)
	trail.material_override = trail_material
	object.add_child(trail)
	add_child(object)
	var drift := Vector2(randf_range(-0.35, 0.35), randf_range(-0.26, 0.26))
	var speed:float = randf_range(19.0, 22.5) if next_obstacle_fast else randf_range(13.0, 16.0)
	next_obstacle_fast = !next_obstacle_fast
	obstacles.append({"node":object, "position":object.position, "speed":speed, "drift":drift, "radius":radius, "kind":kind, "spin":randf_range(-3.2, 3.2), "dash_primed":false, "resolved":false})
	spawn_timer = 0.55

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
		if previous_z < 0.0 && pos.z >= 0.0 && !obstacle.resolved:
			resolve_obstacle(obstacle)
			obstacle["resolved"] = true
		if pos.z > 9.0:
			node.queue_free()
			obstacles.remove_at(i)
			spawn_timer = maxf(spawn_timer, randf_range(0.42, 0.85))

func resolve_obstacle(obstacle:Dictionary) -> void:
	var pos:Vector3 = obstacle.position
	var distance:float = player_pos.distance_to(Vector2(pos.x, pos.y))
	var collision_radius:float = float(obstacle.radius) + 0.75
	if distance < collision_radius:
		if hurt_invulnerability <= 0.0:
			apply_hit(obstacle)
	elif obstacle.dash_primed && distance >= collision_radius:
		award_dodge()

func apply_hit(obstacle:Dictionary) -> void:
	var combo_window:bool = elapsed - last_hit_at <= 5.0
	hit_combo = hit_combo + 1 if combo_window else 1
	last_hit_at = elapsed
	var damage:float = 11.0 + float(obstacle.radius) * 10.0
	if hit_combo >= 3:
		damage *= 1.45
	health = maxf(0.0, health - damage)
	hurt_invulnerability = 0.9
	camera_shake = maxf(camera_shake, 0.36)
	hit_sound.pitch_scale = randf_range(0.88, 1.13)
	hit_sound.play()
	var screen_pos:Vector2 = camera.unproject_position(obstacle.position)
	hud.call("show_hit", screen_pos, hit_combo, damage)
	if health <= 0.0:
		start_ending(false)

func award_dodge() -> void:
	dodges += 1
	camera_shake = maxf(camera_shake, 0.16)
	evade_sound.pitch_scale = lerpf(0.9, 1.35, float(dodges) / float(DODGES_TO_ESCAPE))
	evade_sound.play()
	hud.call("show_dodge", dodges, DODGES_TO_ESCAPE)
	if dodges >= DODGES_TO_ESCAPE:
		start_ending(true)

func start_ending(success:bool) -> void:
	finishing = true
	ending_success = success
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
		if ending_time > 0.75 && !ending_scream_started:
			ending_scream_started = true
			scream_sound.play()
		if ending_time > 1.0:
			maycon.position.y -= 13.0 * delta
			maycon.position.z -= 9.0 * delta
		if ending_time > 2.5 && !transition_sent:
			transition_sent = true
			get_tree().change_scene_to_file("res://scenes/3D/cenario_3d_bofore_castle_1.tscn")
	else:
		if ending_time > 1.6 && !transition_sent:
			transition_sent = true
			GameSongs.play_song(1)
			get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")
