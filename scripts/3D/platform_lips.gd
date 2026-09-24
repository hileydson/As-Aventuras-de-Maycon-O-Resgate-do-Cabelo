extends Node3D

const MODEL = preload("res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb")
const GRUNT_SOUND = preload("res://assets/novos_audios/mario_part_sounds/lips_jump_grunt.mp3")
const SCREAM_SOUND = preload("res://assets/novos_audios/mario_part_sounds/lips_scream_air.mp3")
const SLAM_SOUND = preload("res://assets/novos_audios/mario_part_sounds/lips_butt_slam.mp3")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const PUNCH_SOUND = preload("res://assets/novos_audios/punch_4.mp3")

const LIPS_SCALE = Vector3(3.8, 3.8, 3.8)
const SLAM_RADIUS = 8.5
const CRUSH_RADIUS = 4.2
const PEAK_JUMP_HEIGHT = 19.0
const JUMP_DURATION = 2.7

enum State {
	SIT,
	TURN,
	CROUCH,
	LEAP,
	FLOP,
	GET_UP
}

var boss_name: String = "Lips Gargaróker"
var max_hp: int = 4
var hp: int = 4
var hurt_invulnerable_timer: float = 0.0
var is_defeated: bool = false
var hits_current_power: int = 0
const MAX_HITS_PER_POWER: int = 2

func reset_power_hits() -> void:
	hits_current_power = 0

signal hp_changed(current_hp: int, max_hp: int)
signal boss_defeated()

var stage: Node3D
var maycon: CharacterBody3D
var model: Node3D
var animation_player: AnimationPlayer

var current_state: State = State.SIT
var state_timer: float = 0.0
var sit_duration: float = 3.2

var current_hub_index: int = 3
var target_hub_index: int = -1
var start_position: Vector3
var target_position: Vector3
var leap_progress: float = 0.0
var has_screamed_in_air: bool = false
var has_dealt_slam_damage: bool = false

var grunt_audio: AudioStreamPlayer3D
var scream_audio: AudioStreamPlayer3D
var slam_audio: AudioStreamPlayer3D
var punch_audio: AudioStreamPlayer3D

var target_indicator: Node3D
var indicator_mat: StandardMaterial3D
var shockwave_mesh_inst: MeshInstance3D
var shockwave_mat: StandardMaterial3D
var shockwave_time: float = 0.0

var dust_particles: GPUParticles3D
var bottom_smoke_particles: GPUParticles3D
var air_trail_particles: GPUParticles3D

func setup(owner_stage: Node3D, player: CharacterBody3D, initial_hub: int = 3) -> void:
	stage = owner_stage
	maycon = player
	current_hub_index = initial_hub

func _ready() -> void:
	# 1. Instantiate 3D Rigged Model
	model = MODEL.instantiate()
	model.name = "LipsRiggedModel"
	model.scale = LIPS_SCALE
	# Offset to place butt on ground (calculated from mesh bbox min.y = -0.951)
	model.position.y = 3.61
	add_child(model)
	
	animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		_play_anim("Idle", 0.0)
	
	# 2. Setup Audio Players
	grunt_audio = _create_audio_player(GRUNT_SOUND, 22.0, 75.0, 2.0)
	scream_audio = _create_audio_player(SCREAM_SOUND, 30.0, 95.0, 3.0)
	slam_audio = _create_audio_player(SLAM_SOUND, 35.0, 110.0, 4.0)
	punch_audio = _create_audio_player(PUNCH_SOUND, 25.0, 85.0, 3.0)

	# 3. Create Shockwave Visual
	_build_shockwave_fx()

	# 4. Create Dust Particles Emitter
	_build_dust_particles()
	_build_smoke_effects()

	# 5. Create Target Indicator (Warning zone on landing platform)
	_build_target_indicator()

	# 6. Snap to initial hub position
	if stage and "HUBS" in stage and current_hub_index < stage.HUBS.size():
		var hub_coord: Vector3 = stage.HUBS[current_hub_index]
		global_position = Vector3(hub_coord.x, hub_coord.y + 0.18, hub_coord.z)

	_snap_to_ground()
	current_state = State.SIT
	state_timer = randf_range(2.5, 3.8)

func reset_position(hub_idx: int = 4) -> void:
	if is_defeated:
		return
	current_hub_index = hub_idx
	target_hub_index = hub_idx
	if stage and "HUBS" in stage and current_hub_index < stage.HUBS.size():
		var hub_coord: Vector3 = stage.HUBS[current_hub_index]
		global_position = Vector3(hub_coord.x, hub_coord.y + 0.18, hub_coord.z)
	_snap_to_ground()
	current_state = State.SIT
	state_timer = randf_range(2.5, 3.8)
	if is_instance_valid(target_indicator):
		target_indicator.visible = false
	_play_anim("Idle", 0.35)

func _create_audio_player(stream: AudioStream, unit_size: float, max_dist: float, vol_db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.unit_size = unit_size
	player.max_distance = max_dist
	player.volume_db = vol_db
	player.position.y = 2.5
	add_child(player)
	return player

func _build_target_indicator() -> void:
	target_indicator = Node3D.new()
	target_indicator.name = "LipsTargetIndicator"
	target_indicator.visible = false
	
	# Outer red pulsing ring
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = SLAM_RADIUS
	ring_mesh.bottom_radius = SLAM_RADIUS
	ring_mesh.height = 0.05
	ring_mesh.radial_segments = 36
	
	indicator_mat = StandardMaterial3D.new()
	indicator_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	indicator_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	indicator_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.45)
	indicator_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var outer_ring := MeshInstance3D.new()
	outer_ring.mesh = ring_mesh
	outer_ring.material_override = indicator_mat
	target_indicator.add_child(outer_ring)

	# Inner core danger circle
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = CRUSH_RADIUS
	core_mesh.bottom_radius = CRUSH_RADIUS
	core_mesh.height = 0.06
	core_mesh.radial_segments = 24
	
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_mat.albedo_color = Color(1.0, 0.85, 0.15, 0.55)
	core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var core_circle := MeshInstance3D.new()
	core_circle.mesh = core_mesh
	core_circle.material_override = core_mat
	target_indicator.add_child(core_circle)

	# Warning text label above landing platform
	var label := Label3D.new()
	label.text = "CUIDADO: BUNDAÇO!"
	label.font_size = 54
	label.outline_size = 6
	label.modulate = Color(1.0, 0.2, 0.2, 0.95)
	label.outline_modulate = Color(0.1, 0.0, 0.0, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.2
	target_indicator.add_child(label)

	get_tree().root.add_child.call_deferred(target_indicator)

func _build_shockwave_fx() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 1.2
	torus.rings = 24
	torus.ring_segments = 12
	
	shockwave_mat = StandardMaterial3D.new()
	shockwave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shockwave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shockwave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shockwave_mat.albedo_color = Color(1.0, 0.85, 0.6, 0.0)
	shockwave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	shockwave_mesh_inst = MeshInstance3D.new()
	shockwave_mesh_inst.mesh = torus
	shockwave_mesh_inst.material_override = shockwave_mat
	shockwave_mesh_inst.position.y = 0.12
	shockwave_mesh_inst.scale = Vector3.ZERO
	add_child(shockwave_mesh_inst)

func _build_dust_particles() -> void:
	dust_particles = GPUParticles3D.new()
	dust_particles.emitting = false
	dust_particles.one_shot = true
	dust_particles.amount = 140
	dust_particles.lifetime = 1.6
	dust_particles.explosiveness = 0.96
	dust_particles.position.y = 0.2
	
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0.5, 0)
	mat.spread = 85.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0, -6.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.8
	dust_particles.process_material = mat
	
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.70
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.albedo_color = Color(0.85, 0.80, 0.70, 0.38)
	sphere.material = dust_mat
	dust_particles.draw_pass_1 = sphere
	
	add_child(dust_particles)

func _build_smoke_effects() -> void:
	# 1. Fumaça saindo de baixo do Lips quando estiver no chão / flutuando
	bottom_smoke_particles = GPUParticles3D.new()
	bottom_smoke_particles.name = "LipsBottomSmoke"
	bottom_smoke_particles.amount = 75
	bottom_smoke_particles.lifetime = 1.5
	bottom_smoke_particles.explosiveness = 0.0
	bottom_smoke_particles.position.y = 0.35
	
	var b_mat := ParticleProcessMaterial.new()
	b_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	b_mat.emission_ring_radius = 2.4
	b_mat.emission_ring_inner_radius = 0.6
	b_mat.emission_ring_height = 0.25
	b_mat.emission_ring_axis = Vector3(0, 1, 0)
	b_mat.direction = Vector3(0, 1.0, 0)
	b_mat.spread = 45.0
	b_mat.initial_velocity_min = 1.2
	b_mat.initial_velocity_max = 2.6
	b_mat.gravity = Vector3(0, 0.45, 0)
	b_mat.scale_min = 0.9
	b_mat.scale_max = 2.2
	bottom_smoke_particles.process_material = b_mat
	
	var b_sphere := SphereMesh.new()
	b_sphere.radius = 0.45
	b_sphere.height = 0.90
	var b_smoke_mat := StandardMaterial3D.new()
	b_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_smoke_mat.albedo_color = Color(0.92, 0.90, 0.96, 0.38)
	b_sphere.material = b_smoke_mat
	bottom_smoke_particles.draw_pass_1 = b_sphere
	add_child(bottom_smoke_particles)
	bottom_smoke_particles.emitting = true

	# 2. Rastro contínuo no ar por onde ele passar durante o pulo
	air_trail_particles = GPUParticles3D.new()
	air_trail_particles.name = "LipsAirTrail"
	air_trail_particles.local_coords = false # Fica no mundo desenhando o rastro tridimensional
	air_trail_particles.amount = 180
	air_trail_particles.lifetime = 2.2
	air_trail_particles.explosiveness = 0.0
	air_trail_particles.position.y = 1.6
	
	var a_mat := ParticleProcessMaterial.new()
	a_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	a_mat.emission_sphere_radius = 1.3
	a_mat.direction = Vector3(0, 0.15, 0)
	a_mat.spread = 40.0
	a_mat.initial_velocity_min = 0.6
	a_mat.initial_velocity_max = 1.8
	a_mat.gravity = Vector3(0, -0.3, 0)
	a_mat.scale_min = 1.2
	a_mat.scale_max = 3.2
	air_trail_particles.process_material = a_mat
	
	var a_sphere := SphereMesh.new()
	a_sphere.radius = 0.55
	a_sphere.height = 1.10
	var a_smoke_mat := StandardMaterial3D.new()
	a_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a_smoke_mat.albedo_color = Color(0.94, 0.92, 0.98, 0.45)
	a_sphere.material = a_smoke_mat
	air_trail_particles.draw_pass_1 = a_sphere
	add_child(air_trail_particles)
	air_trail_particles.emitting = false

func _physics_process(delta: float) -> void:
	if is_defeated:
		if model and not model.visible:
			model.visible = true
		return

	if hurt_invulnerable_timer > 0.0:
		hurt_invulnerable_timer -= delta
		var blink := sin(Time.get_ticks_msec() * 0.035) > 0.0
		if model:
			model.visible = blink or hurt_invulnerable_timer <= 0.0
	elif model and not model.visible:
		model.visible = true

	if is_instance_valid(bottom_smoke_particles):
		bottom_smoke_particles.emitting = (current_state != State.LEAP)
	if is_instance_valid(air_trail_particles):
		air_trail_particles.emitting = (current_state == State.LEAP)

	_check_maycon_collision()
	_update_shockwave(delta)
	_update_target_indicator(delta)

	match current_state:
		State.SIT:
			_process_sit(delta)
		State.TURN:
			_process_turn(delta)
		State.CROUCH:
			_process_crouch(delta)
		State.LEAP:
			_process_leap(delta)
		State.FLOP:
			_process_flop(delta)
		State.GET_UP:
			_process_get_up(delta)

func _process_sit(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_choose_next_hub()
		_start_turn()

func _start_turn() -> void:
	current_state = State.TURN
	state_timer = 1.1
	_play_anim("Turn", 0.30)

	# Exibir indicador de área de impacto na plataforma de destino
	if is_instance_valid(target_indicator):
		target_indicator.global_position = target_position + Vector3.UP * 0.15
		target_indicator.visible = true

func _process_turn(delta: float) -> void:
	state_timer -= delta
	# Girar suavemente voltando o corpo para a plataforma alvo
	var flat_dir := Vector3(target_position.x - global_position.x, 0, target_position.z - global_position.z).normalized()
	if flat_dir.length_squared() > 0.001:
		var target_yaw := atan2(flat_dir.x, flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 6.5)
	
	if state_timer <= 0.0:
		_start_jump_prep()

func _start_jump_prep() -> void:
	current_state = State.CROUCH
	state_timer = 1.1
	# Assegurar alinhamento final com o destino
	var flat_dir := Vector3(target_position.x - global_position.x, 0, target_position.z - global_position.z).normalized()
	if flat_dir.length_squared() > 0.001:
		rotation.y = atan2(flat_dir.x, flat_dir.z)
	_play_anim("Jump_Prep", 0.25)
	grunt_audio.play()

func _process_crouch(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_launch_leap()

func _launch_leap() -> void:
	current_state = State.LEAP
	start_position = global_position
	leap_progress = 0.0
	has_screamed_in_air = false
	has_dealt_slam_damage = false
	_play_anim("Jump_Ascent", 0.18)

	# Efeito de poeira no impulso de lançamento
	dust_particles.emitting = true

func _process_leap(delta: float) -> void:
	leap_progress += delta / JUMP_DURATION
	var t := clampf(leap_progress, 0.0, 1.0)
	
	# Trajetória parabólica
	var flat_pos := start_position.lerp(target_position, t)
	var arc_height := sin(t * PI) * PEAK_JUMP_HEIGHT
	global_position = flat_pos + Vector3(0, arc_height, 0)

	# Manter rotação voltada para o pulo
	var flat_dir := Vector3(target_position.x - start_position.x, 0, target_position.z - start_position.z).normalized()
	if flat_dir.length_squared() > 0.001:
		rotation.y = atan2(flat_dir.x, flat_dir.z)

	# Transição no ar para pose de mergulho de cara/barriga para baixo com urro
	if t >= 0.38 and not has_screamed_in_air:
		has_screamed_in_air = true
		_play_anim("Belly_Dive", 0.35)
		scream_audio.play()

	# Aterrissagem
	if leap_progress >= 1.0:
		_trigger_belly_flop()

func _trigger_belly_flop() -> void:
	current_state = State.FLOP
	current_hub_index = target_hub_index
	state_timer = 1.2
	global_position = target_position
	_snap_to_ground()
	
	# Cai de cara e barriga no chão!
	_play_anim("Belly_Flop", 0.10)
	slam_audio.play()

	# Esconder indicador de alvo
	if is_instance_valid(target_indicator):
		target_indicator.visible = false

	# Onda de choque visual e poeira intensa
	_spawn_shockwave()
	dust_particles.emitting = true

	# Tremor na câmera
	if is_instance_valid(maycon) and "camera_shake" in maycon:
		maycon.camera_shake = 0.70

	# Dano no impacto (apenas em Maycon)
	_apply_slam_damage()

func _process_flop(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		_start_get_up()

func _start_get_up() -> void:
	current_state = State.GET_UP
	state_timer = 1.6
	_play_anim("Get_Up", 0.28)

func _process_get_up(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0.0:
		current_state = State.SIT
		current_hub_index = target_hub_index
		state_timer = randf_range(2.6, 4.0)
		_play_anim("Idle", 0.35)

func _apply_slam_damage() -> void:
	if not is_instance_valid(maycon) or has_dealt_slam_damage:
		return
	has_dealt_slam_damage = true

	var horizontal_dist := Vector2(maycon.global_position.x - global_position.x, maycon.global_position.z - global_position.z).length()
	var vertical_diff := absf(maycon.global_position.y - global_position.y)

	# If Maycon is within the slam radius on the target platform
	if horizontal_dist < SLAM_RADIUS and vertical_diff < 3.5:
		if horizontal_dist < CRUSH_RADIUS:
			# Direct crush under giant butt!
			if maycon.has_method("receive_damage"):
				maycon.receive_damage(55.0, global_position)
		else:
			# Outer shockwave zone
			if maycon.has_method("receive_damage"):
				maycon.receive_damage(30.0, global_position)

func _spawn_shockwave() -> void:
	shockwave_time = 0.65
	if is_instance_valid(shockwave_mesh_inst):
		shockwave_mesh_inst.scale = Vector3(1.0, 1.0, 1.0)

func _update_shockwave(delta: float) -> void:
	if shockwave_time > 0.0 and is_instance_valid(shockwave_mesh_inst):
		shockwave_time -= delta
		var progress := 1.0 - (shockwave_time / 0.65)
		var scale_val: float = lerpf(1.5, SLAM_RADIUS * 1.5, progress)
		shockwave_mesh_inst.scale = Vector3(scale_val, 1.0, scale_val)
		if shockwave_mat:
			var alpha: float = lerpf(0.85, 0.0, progress * progress)
			shockwave_mat.albedo_color = Color(1.0, 0.80, 0.55, alpha)
	elif is_instance_valid(shockwave_mesh_inst) and shockwave_mesh_inst.scale != Vector3.ZERO:
		shockwave_mesh_inst.scale = Vector3.ZERO

func _update_target_indicator(_delta: float) -> void:
	if not is_instance_valid(target_indicator) or not target_indicator.visible:
		return
	var pulse := (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
	if indicator_mat:
		indicator_mat.albedo_color = Color(1.0, 0.15, 0.15, lerpf(0.35, 0.75, pulse))

func _choose_next_hub() -> void:
	if not stage or not ("HUBS" in stage):
		target_position = global_position
		return

	var hubs: Array = stage.HUBS
	var neighbors: Array[int] = []
	var curr_pos: Vector3 = hubs[current_hub_index]

	for i in range(hubs.size()):
		if i == current_hub_index:
			continue
		var dist: float = curr_pos.distance_to(hubs[i])
		# Adjacent hubs within leaping range (~20m to 55m)
		if dist < 58.0:
			neighbors.append(i)

	if neighbors.is_empty():
		for i in range(hubs.size()):
			if i != current_hub_index:
				neighbors.append(i)

	# Check if Maycon is on one of the neighbor hubs
	var maycon_hub := _find_nearest_hub_to_position(maycon.global_position if is_instance_valid(maycon) else curr_pos)
	
	if maycon_hub in neighbors and randf() < 0.45:
		target_hub_index = maycon_hub
	else:
		target_hub_index = neighbors[randi() % neighbors.size()]

	var raw_dest: Vector3 = hubs[target_hub_index]
	target_position = Vector3(raw_dest.x, raw_dest.y + 0.18, raw_dest.z)

func _find_nearest_hub_to_position(pos: Vector3) -> int:
	if not stage or not ("HUBS" in stage):
		return 0
	var hubs: Array = stage.HUBS
	var nearest_idx := 0
	var min_dist := 9999.0
	for i in range(hubs.size()):
		var d: float = pos.distance_to(hubs[i])
		if d < min_dist:
			min_dist = d
			nearest_idx = i
	return nearest_idx

func _snap_to_ground() -> void:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 4.0, global_position - Vector3.UP * 8.0, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y

func _play_anim(anim_name: String, custom_blend: float = 0.28) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name, custom_blend)

func _check_maycon_collision() -> void:
	if not is_instance_valid(maycon) or is_defeated:
		return
	
	var horizontal_dist := Vector2(maycon.global_position.x - global_position.x, maycon.global_position.z - global_position.z).length()
	var vertical_diff := absf(maycon.global_position.y - global_position.y)

	# Lips is a giant with scale 3.8. Radius ~4.6, height ~5.8.
	if horizontal_dist < 4.6 and vertical_diff < 5.8:
		var maycon_invincible: bool = (maycon.get("is_invincible") == true) or (is_instance_valid(stage) and stage.get("is_invincible") == true)
		if maycon_invincible:
			# Limite de no máximo 2 acertos consecutivos durante este poder de invencibilidade
			if hits_current_power < MAX_HITS_PER_POWER:
				if hurt_invulnerable_timer <= 0.0:
					take_hit_from_maycon()
			# Se já atingiu 2 vezes nesta mesma ativação da invencibilidade,
			# Maycon NÃO toma dano nem recoil do Lips pois continua invencível!
		else:
			# Maycon não está invencível: reseta contador para permitir acertos no próximo poder
			hits_current_power = 0
			# Not invincible: if Maycon walks into Lips on the ground, knock him back
			if hurt_invulnerable_timer <= 0.0 and current_state in [State.SIT, State.TURN, State.CROUCH, State.FLOP, State.GET_UP] and maycon.get("hurt_time") != null and maycon.hurt_time <= 0.0:
				if maycon.has_method("receive_damage"):
					maycon.receive_damage(25.0, global_position)

func take_hit_from_maycon() -> void:
	if is_defeated or hurt_invulnerable_timer > 0.0:
		return
	
	hits_current_power += 1
	hurt_invulnerable_timer = 1.2
	hp = maxi(0, hp - 1)
	hp_changed.emit(hp, max_hp)
	if stage and stage.has_method("update_boss_lips_hp"):
		stage.update_boss_lips_hp(hp, max_hp)
		
	# 1. Tirar muito sangue do Lips! ("faça com que seja possivel tirar sangue do lips")
	_spawn_boss_blood()

	# 2. Som de impacto pesado e urro de dor
	if punch_audio:
		punch_audio.pitch_scale = randf_range(0.85, 1.05)
		punch_audio.play()
	if scream_audio:
		scream_audio.pitch_scale = randf_range(0.70, 0.82)
		scream_audio.play()

	# 3. Screen shake e flash de dano
	if is_instance_valid(maycon) and "camera_shake" in maycon:
		maycon.camera_shake = 0.85
	if stage and stage.get("blood_overlay"):
		stage.blood_overlay.call("flash")

	# 4. Derrota cinematográfica se zerar vida (4 acertos)
	if hp <= 0:
		is_defeated = true
		hurt_invulnerable_timer = 0.0
		if model:
			model.visible = true
		if is_instance_valid(target_indicator):
			target_indicator.visible = false
		if is_instance_valid(bottom_smoke_particles):
			bottom_smoke_particles.emitting = false
		if is_instance_valid(air_trail_particles):
			air_trail_particles.emitting = true
		boss_defeated.emit()
		if stage and stage.has_method("start_boss_lips_death_cutscene"):
			stage.start_boss_lips_death_cutscene(self)
		else:
			_defeat_boss()
		return

	# 5. Se ainda tiver vida: é o Lips quem sofre o recuo/afastamento pelo poder do Maycon (Maycon não sofre recoil!)
	var recoil_dir := (global_position - maycon.global_position).normalized() if is_instance_valid(maycon) else Vector3.ZERO
	if recoil_dir.length_squared() < 0.01:
		recoil_dir = -global_transform.basis.z
	recoil_dir.y = 0.0
	recoil_dir = recoil_dir.normalized()

	var target_recoil_pos := global_position + recoil_dir * 5.2
	var space := get_world_3d().direct_space_state
	var ground_check := PhysicsRayQueryParameters3D.create(target_recoil_pos + Vector3.UP * 2.0, target_recoil_pos - Vector3.UP * 8.0, 1)
	var ground_hit := space.intersect_ray(ground_check)
	if ground_hit.is_empty():
		target_recoil_pos = global_position + recoil_dir * 2.2

	var lips_recoil_tw := create_tween().bind_node(self).set_parallel(true)
	lips_recoil_tw.tween_property(self, "global_position", target_recoil_pos, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(model):
		var tilt_dir := -recoil_dir
		lips_recoil_tw.tween_property(model, "rotation:x", model.rotation.x + tilt_dir.z * 0.45, 0.16).set_trans(Tween.TRANS_QUAD)
		lips_recoil_tw.chain().tween_property(model, "rotation:x", 0.0, 0.22)
	
	# Assim que o dano acontece e o recuo termina, ele já se prepara para sair de lá e sai logo depois!
	lips_recoil_tw.chain().tween_callback(func():
		if not is_defeated:
			_start_flee()
	)

func _choose_flee_hub() -> void:
	if not stage or not ("HUBS" in stage):
		target_position = global_position
		return

	var hubs: Array = stage.HUBS
	var curr_pos: Vector3 = hubs[current_hub_index]
	var maycon_pos: Vector3 = maycon.global_position if is_instance_valid(maycon) else curr_pos
	var maycon_hub := _find_nearest_hub_to_position(maycon_pos)

	var candidate_hubs: Array[int] = []
	for i in range(hubs.size()):
		if i == current_hub_index:
			continue
		var dist: float = curr_pos.distance_to(hubs[i])
		if dist < 65.0:
			candidate_hubs.append(i)

	if candidate_hubs.is_empty():
		for i in range(hubs.size()):
			if i != current_hub_index:
				candidate_hubs.append(i)

	# Fugir para longe do Maycon: escolher o hub candidato que maximiza a distância do Maycon
	var best_hub: int = candidate_hubs[0]
	var max_dist_to_maycon: float = -1.0
	for h_idx in candidate_hubs:
		if h_idx == maycon_hub and candidate_hubs.size() > 1:
			continue
		var dist_to_m: float = hubs[h_idx].distance_to(maycon_pos)
		if dist_to_m > max_dist_to_maycon:
			max_dist_to_maycon = dist_to_m
			best_hub = h_idx

	target_hub_index = best_hub
	var raw_dest: Vector3 = hubs[target_hub_index]
	target_position = Vector3(raw_dest.x, raw_dest.y + 0.18, raw_dest.z)

func _start_flee() -> void:
	if is_defeated:
		return
	current_hub_index = _find_nearest_hub_to_position(global_position)
	_snap_to_ground()
	_choose_flee_hub()
	
	if is_instance_valid(target_indicator):
		target_indicator.global_position = target_position + Vector3.UP * 0.15
		target_indicator.visible = true

	var flat_dir := Vector3(target_position.x - global_position.x, 0, target_position.z - global_position.z).normalized()
	if flat_dir.length_squared() > 0.001:
		rotation.y = atan2(flat_dir.x, flat_dir.z)

	# Prepara-se para sair agachando com grunhido e logo depois sai voando
	current_state = State.CROUCH
	state_timer = 0.55
	_play_anim("Jump_Prep", 0.15)
	if grunt_audio:
		grunt_audio.pitch_scale = randf_range(0.95, 1.15)
		grunt_audio.play()

func _spawn_boss_blood() -> void:
	if not is_instance_valid(stage):
		return
	for i in range(10):
		var blood := BLOOD_SCENE.instantiate()
		blood.position = global_position + Vector3(randf_range(-1.8, 1.8), randf_range(1.5, 4.8), randf_range(-1.8, 1.8))
		blood.scale = Vector3.ONE * randf_range(1.8, 2.8)
		stage.effects.add_child(blood)
		get_tree().create_timer(2.4).timeout.connect(blood.queue_free)
	
	# Manchas de sangue no chão
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position - Vector3.UP * 8.0, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		var ground_y: float = hit.position.y
		for i in range(6):
			var angle := randf() * TAU
			var dist := randf_range(0.8, 3.5)
			var stain := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = randf_range(0.35, 0.75)
			mesh.height = 0.02
			stain.mesh = mesh
			if stage.materials.has("blood"):
				stain.material_override = stage.materials["blood"]
			stain.position = Vector3(global_position.x + cos(angle) * dist, ground_y + 0.02 + float(i) * 0.001, global_position.z + sin(angle) * dist)
			stage.effects.add_child(stain)

func _defeat_boss() -> void:
	is_defeated = true
	boss_defeated.emit()
	if is_instance_valid(target_indicator):
		target_indicator.visible = false
	
	# Efeito massivo de explosão de sangue
	if is_instance_valid(stage):
		for i in range(16):
			var blood := BLOOD_SCENE.instantiate()
			blood.position = global_position + Vector3(randf_range(-2.5, 2.5), randf_range(1.0, 6.0), randf_range(-2.5, 2.5))
			blood.scale = Vector3.ONE * randf_range(2.5, 3.8)
			stage.effects.add_child(blood)
			get_tree().create_timer(3.0).timeout.connect(blood.queue_free)
	
	# Som de derrota
	if scream_audio:
		scream_audio.pitch_scale = 0.55
		scream_audio.play()
	
	# Encolher com tween e sumir
	var tween := create_tween().bind_node(self).set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y - 3.0, 1.8)
	
	# Notificar a fase que Lips foi derrotado!
	if stage and stage.has_method("boss_lips_defeated"):
		stage.boss_lips_defeated()
		
	tween.chain().tween_callback(queue_free)

func _exit_tree() -> void:
	if is_instance_valid(target_indicator):
		target_indicator.queue_free()
