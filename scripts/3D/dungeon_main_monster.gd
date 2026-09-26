class_name DungeonMainMonster
extends CharacterBody3D

const MODEL:PackedScene = preload("res://assets/modelo_3d/calabouco/Anim_Monster_1.glb")
const STEP_SOUND:AudioStream = preload("res://assets/novos_audios/calabouco_terror/dungeon_fall_impact.wav")
const PAIN_SOUND:AudioStream = preload("res://assets/novos_audios/calabouco_terror/zombie_pain_1.wav")
const ROAR_1:AudioStream = preload("res://assets/novos_audios/calabouco_terror/monster_roar_1.wav")
const ROAR_2:AudioStream = preload("res://assets/novos_audios/calabouco_terror/monster_roar_2.wav")
const ATTACK_1:AudioStream = preload("res://assets/novos_audios/calabouco_terror/monster_scream_1.wav")
const ATTACK_2:AudioStream = preload("res://assets/novos_audios/calabouco_terror/monster_scream_2.wav")

const MODEL_SCALE:float = 1.35
const PATROL_SPEED:float = 1.75
const CHASE_SPEED:float = 3.0
const ACTIVATION_DISTANCE:float = 16.0
const DISENGAGE_DISTANCE:float = 27.0
const TEMPORARY_DEFEAT_DAMAGE:int = 16
const TEMPORARY_DEFEAT_SECONDS:float = 5.0

var player:DungeonPlayer
var dungeon:Node
var model_root:Node3D
var animator:AnimationPlayer
var skeleton:Skeleton3D
var grab_attachment:BoneAttachment3D
var grab_anchor:Marker3D
var active_bone_recoils:Array[Dictionary] = []

var state:String = "patrol"
var active_hunt:bool = false
var damage_pressure:int = 0
var hit_cycle:int = 0
var action_timer:float = 0.0
var action_elapsed:float = 0.0
var attack_number:int = 0
var attack_impact_done:bool = false
var grab_active:bool = false
var grab_impact_time:float = 0.72
var grab_release_time:float = 1.95
var attack_cooldown:float = 2.0
var rest_timer:float = 0.0
var down_timer:float = 0.0
var rage_repeat_timer:float = 0.0
var step_timer:float = 0.0
var patrol_timeout:float = 0.0
var patrol_index:int = 0
var patrol_target_index:int = 0
var patrol_points:Array[Vector3] = []
var patrol_links:Dictionary = {}

var enraged_hunt:bool = false
const TRAMPOLINE_CORRIDOR_LIMIT_Z:float = -74.0

const NAV_NODES: Array[Vector3] = [
	Vector3(0, 0, -94),     # 0: Hub Centro
	Vector3(0, 0, -80),     # 1: Hub Norte (Entrada Corredor Trampolim)
	Vector3(0, 0, -53),     # 2: Trampolim Meio
	Vector3(0, 0, -25),     # 3: Trampolim Perto
	Vector3(0, 0, 3.5),     # 4: Trampolim
	Vector3(-18, 0, -94),   # 5: Hub Oeste (Saída para Intro)
	Vector3(-56, 0, -94),   # 6: Curva Intro
	Vector3(-56, 0, -118),  # 7: Intro Meio
	Vector3(-56, 0, -135),  # 8: Cela da Chave Azul
	Vector3(18, 0, -94),    # 9: Hub Leste (Saída para Blue)
	Vector3(56, 0, -94),    # 10: Curva Blue
	Vector3(56, 0, -118),   # 11: Blue Meio
	Vector3(56, 0, -135),   # 12: Cela da Chave Vermelha
	Vector3(-7, 0, -108),   # 13: Hub Sul-Oeste (Entrada Red)
	Vector3(-7, 0, -164),   # 14: Curva Red
	Vector3(-30, 0, -164),  # 15: Red Meio
	Vector3(-45, 0, -164),  # 16: Cela da Chave Verde
	Vector3(7, 0, -108),    # 17: Hub Sul-Leste (Entrada Green)
	Vector3(7, 0, -164),    # 18: Curva Green
	Vector3(30, 0, -164),   # 19: Green Meio
	Vector3(45, 0, -164)    # 20: Cela da Chave Final (chave da cela)
]

const NAV_LINKS: Dictionary = {
	0: [1, 5, 9, 13, 17],
	1: [0, 2],
	2: [1, 3],
	3: [2, 4],
	4: [3],
	5: [0, 6],
	6: [5, 7],
	7: [6, 8],
	8: [7],
	9: [0, 10],
	10: [9, 11],
	11: [10, 12],
	12: [11],
	13: [0, 14],
	14: [13, 15],
	15: [14, 16],
	16: [15],
	17: [0, 18],
	18: [17, 19],
	19: [18, 20],
	20: [19]
}

func has_cell_key() -> bool:
	return bool(Global.game_events.get("dungeon_key_taken", false))

func trigger_enrage_hunt() -> void:
	enraged_hunt = true
	active_hunt = true
	if state == "down" || state == "rest":
		state = "patrol"
		down_timer = 0.0
		damage_pressure = 0
	play_roar()

func get_closest_nav_node(pos: Vector3, allow_trampoline: bool = true) -> int:
	var best_idx: int = 0
	var best_dist: float = INF
	for i in range(NAV_NODES.size()):
		if !allow_trampoline && i in [1, 2, 3, 4]:
			continue
		var d := pos.distance_squared_to(NAV_NODES[i])
		if d < best_dist:
			best_dist = d
			best_idx = i
	return best_idx

func find_nav_path(start_node: int, goal_node: int, allow_trampoline: bool = true) -> Array[int]:
	if start_node == goal_node:
		return [start_node]
	var queue: Array[int] = [start_node]
	var parent: Dictionary = {start_node: -1}
	var visited: Dictionary = {start_node: true}
	var found: bool = false
	while !queue.is_empty():
		var curr := queue.pop_front() as int
		if curr == goal_node:
			found = true
			break
		var neighbors: Array = NAV_LINKS.get(curr, [])
		for next_node in neighbors:
			var n_int := int(next_node)
			if !allow_trampoline && n_int in [1, 2, 3, 4]:
				continue
			if !visited.has(n_int):
				visited[n_int] = true
				parent[n_int] = curr
				queue.append(n_int)
	if !found:
		return [start_node]
	var path: Array[int] = []
	var step: int = goal_node
	while step != -1:
		path.append(step)
		step = parent.get(step, -1)
	path.reverse()
	return path

func get_next_nav_waypoint(from_pos: Vector3, to_pos: Vector3) -> Vector3:
	var allow_tramp: bool = enraged_hunt || has_cell_key()
	var start_node := get_closest_nav_node(from_pos, allow_tramp)
	var goal_node := get_closest_nav_node(to_pos, allow_tramp)
	if start_node == goal_node:
		return to_pos
	var path := find_nav_path(start_node, goal_node, allow_tramp)
	if path.size() < 2:
		return to_pos
	var next_node := path[1]
	if from_pos.distance_to(NAV_NODES[start_node]) > 2.2:
		return NAV_NODES[start_node]
	return NAV_NODES[next_node]

var step_audio:AudioStreamPlayer3D
var pain_audio:AudioStreamPlayer3D
var roar_audio:AudioStreamPlayer3D
var attack_audio:AudioStreamPlayer3D

func setup(target:DungeonPlayer, owner_dungeon:Node) -> void:
	player = target
	dungeon = owner_dungeon
	build_body()
	build_patrol_graph()
	if has_cell_key():
		trigger_enrage_hunt()
	else:
		play_animation("Walk", true, 0.82)

func build_body() -> void:
	for child in get_children():
		child.queue_free()

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.72
	capsule.height = 2.75
	collision.shape = capsule
	collision.position.y = 1.38
	add_child(collision)

	model_root = MODEL.instantiate() as Node3D
	model_root.scale = Vector3.ONE * MODEL_SCALE
	model_root.rotation.y = PI # Modelo vinha de costas; gira no yaw para a frente apontar para -Z
	add_child(model_root)
	apply_horror_materials()
	animator = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
	if is_instance_valid(skeleton):
		grab_attachment = BoneAttachment3D.new()
		grab_attachment.name = "GrabHandAttachment"
		grab_attachment.bone_name = &"def_hand.R"
		skeleton.add_child(grab_attachment)
		grab_anchor = Marker3D.new()
		grab_anchor.name = "GrabAnchor"
		grab_anchor.position = Vector3(0.06, -0.18, 0.12)
		grab_attachment.add_child(grab_anchor)
	else:
		grab_anchor = Marker3D.new()
		grab_anchor.position = Vector3(0.45, 2.0, -0.9)
		add_child(grab_anchor)

	step_audio = make_audio(STEP_SOUND, -11.0, 30.0)
	pain_audio = make_audio(PAIN_SOUND, -3.5, 30.0)
	roar_audio = make_audio(ROAR_1, -2.0, 38.0)
	attack_audio = make_audio(ATTACK_1, -2.0, 34.0)

func apply_horror_materials() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.16, 0.135, 0.12)
	body_material.roughness = 0.74
	body_material.metallic = 0.05
	var jaw_material := StandardMaterial3D.new()
	jaw_material.albedo_color = Color(0.24, 0.035, 0.028)
	jaw_material.roughness = 0.58
	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.72, 0.008, 0.004)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.008, 0.002)
	eye_material.emission_energy_multiplier = 4.2
	var body_mesh := model_root.find_child("Monster_1_LP", true, false) as MeshInstance3D
	var jaw_mesh := model_root.find_child("Jaw_LP", true, false) as MeshInstance3D
	var eyes_mesh := model_root.find_child("Eyes_LP", true, false) as MeshInstance3D
	if is_instance_valid(body_mesh):
		body_mesh.material_override = body_material
	if is_instance_valid(jaw_mesh):
		jaw_mesh.material_override = jaw_material
	if is_instance_valid(eyes_mesh):
		eyes_mesh.material_override = eye_material

func make_audio(stream:AudioStream, volume_db:float, max_distance:float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volume_db
	audio.max_distance = max_distance
	audio.unit_size = 5.0
	add_child(audio)
	return audio

func build_patrol_graph() -> void:
	patrol_points = [
		Vector3(0, 0, -92), Vector3(-12, 0, -92), Vector3(12, 0, -92),
		Vector3(-31, 0, -94), Vector3(-56, 0, -94), Vector3(-56, 0, -118),
		Vector3(31, 0, -94), Vector3(56, 0, -94), Vector3(56, 0, -118)
	]
	patrol_links = {
		0: [1, 2, 3, 6],
		1: [0, 3],
		2: [0, 6],
		3: [0, 1, 4],
		4: [3, 5],
		5: [4],
		6: [0, 2, 7],
		7: [6, 8],
		8: [7]
	}
	patrol_index = closest_patrol_index(global_position)
	choose_next_patrol_target()

func closest_patrol_index(position_value:Vector3) -> int:
	var best_index:int = 0
	var best_distance:float = INF
	for index in patrol_points.size():
		var distance := position_value.distance_squared_to(patrol_points[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func choose_next_patrol_target() -> void:
	var choices:Array = patrol_links.get(patrol_index, [0]).duplicate()
	if !bool(Global.game_events.get("dungeon_blue_gate_open", false)):
		choices = choices.filter(func(idx): return int(idx) < 6)
	if choices.is_empty():
		choices = [0]
	patrol_target_index = int(choices.pick_random())
	patrol_timeout = 16.0

func _physics_process(delta:float) -> void:
	if !is_instance_valid(player):
		return
	if !is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if !enraged_hunt && has_cell_key():
		trigger_enrage_hunt()

	if state == "down":
		process_temporary_defeat(delta)
		move_and_slide()
		return
	if state == "hit":
		process_hit(delta)
		move_and_slide()
		return
	if state == "attack":
		process_attack(delta)
		move_and_slide()
		return
	if state == "rest":
		process_rest(delta)
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var player_distance := to_player.length()
	var player_hidden:bool = bool(dungeon.call("is_player_hidden"))
	var player_in_trampoline:bool = player.global_position.z > TRAMPOLINE_CORRIDOR_LIMIT_Z

	if enraged_hunt:
		active_hunt = true
	else:
		if !active_hunt && !player_hidden && !player_in_trampoline && player_distance <= ACTIVATION_DISTANCE && can_see_player():
			active_hunt = true
			play_roar()
		if active_hunt && (player_hidden || player_in_trampoline || player_distance >= DISENGAGE_DISTANCE):
			active_hunt = false
			patrol_index = closest_patrol_index(global_position)
			choose_next_patrol_target()

	if active_hunt:
		process_chase(to_player, player_distance)
	else:
		process_patrol(delta)

	if !enraged_hunt && !has_cell_key():
		if global_position.z > TRAMPOLINE_CORRIDOR_LIMIT_Z:
			global_position.z = TRAMPOLINE_CORRIDOR_LIMIT_Z
			velocity.z = minf(velocity.z, 0.0)

	move_and_slide()

	if !enraged_hunt && !has_cell_key():
		if global_position.z > TRAMPOLINE_CORRIDOR_LIMIT_Z:
			global_position.z = TRAMPOLINE_CORRIDOR_LIMIT_Z

	update_steps(delta, Vector2(velocity.x, velocity.z).length(), active_hunt)

func process_chase(to_player:Vector3, player_distance:float) -> void:
	if player_distance <= 2.75 && attack_cooldown <= 0.0:
		start_random_attack(player_distance)
		return
	var move_target: Vector3 = player.global_position
	if !can_see_player():
		move_target = get_next_nav_waypoint(global_position, player.global_position)
	look_at_horizontal(move_target)
	var move_dir := move_target - global_position
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
	var current_chase_speed := CHASE_SPEED * (1.12 if enraged_hunt else 1.0)
	velocity.x = move_dir.x * current_chase_speed
	velocity.z = move_dir.z * current_chase_speed
	play_animation("Run", true, 0.95)

func process_patrol(delta:float) -> void:
	patrol_timeout -= delta
	var target := patrol_points[patrol_target_index]
	var direction := target - global_position
	direction.y = 0.0
	if direction.length() < 1.1 || patrol_timeout <= 0.0:
		patrol_index = patrol_target_index if patrol_timeout > 0.0 else closest_patrol_index(global_position)
		if randf() < 0.38:
			state = "rest"
			rest_timer = randf_range(2.8, 6.0)
			velocity.x = 0.0
			velocity.z = 0.0
			play_animation("Idle_5", true, randf_range(0.82, 1.0))
		else:
			choose_next_patrol_target()
		return
	look_at_horizontal(target)
	direction = direction.normalized()
	velocity.x = direction.x * PATROL_SPEED
	velocity.z = direction.z * PATROL_SPEED
	play_animation("Walk", true, 0.82)

func process_rest(delta:float) -> void:
	if enraged_hunt:
		state = "patrol"
		active_hunt = true
		return
	velocity.x = 0.0
	velocity.z = 0.0
	rest_timer -= delta
	var distance := global_position.distance_to(player.global_position)
	var player_in_trampoline:bool = player.global_position.z > TRAMPOLINE_CORRIDOR_LIMIT_Z
	if distance <= ACTIVATION_DISTANCE && !player_in_trampoline && !bool(dungeon.call("is_player_hidden")) && can_see_player():
		state = "patrol"
		active_hunt = true
		play_roar()
		return
	if rest_timer <= 0.0:
		state = "patrol"
		choose_next_patrol_target()

func start_random_attack(_player_distance:float) -> void:
	# O monstro principal agora só tem o ataque de AGARRAR (os golpes foram removidos).
	attack_number = 6
	state = "attack"
	action_elapsed = 0.0
	attack_impact_done = false
	grab_impact_time = randf_range(0.66, 0.78)
	grab_release_time = randf_range(1.85, 2.22)
	velocity.x = 0.0
	velocity.z = 0.0
	attack_audio.stream = ATTACK_2
	attack_audio.pitch_scale = randf_range(0.82, 0.98)
	attack_audio.play()
	action_timer = play_animation("Attack_%d" % attack_number, false, 1.0)
	if action_timer <= 0.0:
		action_timer = 2.4

func process_attack(delta:float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	action_timer -= delta
	action_elapsed += delta
	look_at_horizontal(player.global_position)
	if !attack_impact_done && action_elapsed >= grab_impact_time:
		attack_impact_done = true
		if global_position.distance_to(player.global_position) <= 3.25:
			grab_active = bool(dungeon.call("begin_main_monster_grab", self, grab_anchor))
	if grab_active && (action_elapsed >= grab_release_time || action_timer <= 0.15):
		dungeon.call("end_main_monster_grab", self)
		grab_active = false
	if action_timer <= 0.0:
		if grab_active:
			dungeon.call("end_main_monster_grab", self)
			grab_active = false
		state = "patrol"
		attack_cooldown = randf_range(2.1, 3.7)

func process_hit(delta:float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	action_timer -= delta
	if action_timer <= 0.0:
		state = "patrol"
		active_hunt = true

func enter_temporary_defeat() -> void:
	if grab_active:
		dungeon.call("end_main_monster_grab", self)
		grab_active = false
	state = "down"
	active_hunt = false
	velocity = Vector3.ZERO
	down_timer = TEMPORARY_DEFEAT_SECONDS
	rage_repeat_timer = randf_range(11.0, 16.0)
	play_animation("Rage_1", false, 0.82)
	play_roar()

func process_temporary_defeat(delta:float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	down_timer -= delta
	rage_repeat_timer -= delta
	if rage_repeat_timer <= 0.0:
		rage_repeat_timer = randf_range(10.0, 15.0)
		play_animation("Rage_1", false, randf_range(0.75, 0.92))
		if randf() < 0.55:
			play_roar()
	elif is_instance_valid(animator) && !animator.is_playing():
		play_animation("Idle_5", true, 0.58)
	if down_timer <= 0.0:
		damage_pressure = 0
		state = "rest"
		rest_timer = 1.8
		attack_cooldown = 2.6
		play_animation("Rage_1", false, 1.05)
		play_roar()

func _process(delta: float) -> void:
	_update_bone_recoils(delta)

func trigger_bone_recoil(hit_pos: Vector3, hit_dir: Vector3) -> void:
	if !is_instance_valid(skeleton) or skeleton.get_bone_count() == 0:
		return
	var hit_skel_pos := skeleton.to_local(hit_pos)
	var closest_bone := -1
	var min_dist_sq := 999999.0
	for i in range(skeleton.get_bone_count()):
		var bone_pos := skeleton.get_bone_global_pose(i).origin
		var d_sq := hit_skel_pos.distance_squared_to(bone_pos)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest_bone = i
	if closest_bone == -1:
		return
	var local_hit_dir := (skeleton.global_transform.basis.inverse() * hit_dir).normalized()
	var kick_axis := local_hit_dir.cross(Vector3.UP).normalized()
	if kick_axis.length_squared() < 0.01:
		kick_axis = Vector3.RIGHT
	var rot_kick := Quaternion(kick_axis, deg_to_rad(randf_range(14.0, 22.0)))
	var pos_kick := local_hit_dir * 0.14
	active_bone_recoils.append({
		"bone": closest_bone,
		"pos_offset": pos_kick,
		"rot_offset": rot_kick,
		"elapsed": 0.0,
		"duration": 0.28
	})

func _update_bone_recoils(delta: float) -> void:
	if active_bone_recoils.is_empty() or !is_instance_valid(skeleton):
		return
	for i in range(active_bone_recoils.size() - 1, -1, -1):
		var recoil: Dictionary = active_bone_recoils[i]
		recoil.elapsed += delta
		var t: float = recoil.elapsed / recoil.duration
		if t >= 1.0:
			var b_idx: int = recoil.bone
			if b_idx < skeleton.get_bone_count():
				skeleton.set_bone_pose_position(b_idx, Vector3.ZERO)
				skeleton.set_bone_pose_rotation(b_idx, Quaternion.IDENTITY)
			active_bone_recoils.remove_at(i)
			continue
		var weight: float = (1.0 - t) * (1.0 - t)
		var b_idx: int = recoil.bone
		if b_idx < skeleton.get_bone_count():
			skeleton.set_bone_pose_position(b_idx, recoil.pos_offset * weight)
			var add_rot := Quaternion.IDENTITY.slerp(recoil.rot_offset, weight)
			skeleton.set_bone_pose_rotation(b_idx, add_rot)

func take_damage(amount:int, weapon_type:String = "pistol", hit_pos:Vector3 = Vector3.ZERO, hit_dir:Vector3 = Vector3.ZERO) -> void:
	if state == "down":
		return
	damage_pressure += amount
	hit_cycle = (hit_cycle % 3) + 1
	if is_instance_valid(pain_audio):
		pain_audio.pitch_scale = randf_range(0.78, 0.96)
		pain_audio.play()
	
	# Empurra o monstro fisicamente para trás
	var knock_dir := hit_dir.normalized() if hit_dir != Vector3.ZERO else -global_transform.basis.z
	global_position += knock_dir * (0.13 if weapon_type == "pistol" else 0.09)
	if hit_pos != Vector3.ZERO:
		trigger_bone_recoil(hit_pos, knock_dir)

	if damage_pressure >= TEMPORARY_DEFEAT_DAMAGE:
		enter_temporary_defeat()
		return
	if grab_active:
		dungeon.call("end_main_monster_grab", self)
		grab_active = false
	state = "hit"
	active_hunt = true
	velocity.x = 0.0
	velocity.z = 0.0
	var anim_dur := play_animation("hit_%d" % hit_cycle, false, 1.35)
	action_timer = minf(anim_dur if anim_dur > 0.0 else 0.45, 0.55)

func play_animation(animation_name:String, loop:bool, speed_scale:float) -> float:
	if !is_instance_valid(animator) || !animator.has_animation(animation_name):
		return 0.0
	var animation := animator.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if animator.current_animation != animation_name || !animator.is_playing():
		animator.play(animation_name, 0.15)
	animator.speed_scale = speed_scale
	return animation.length / maxf(speed_scale, 0.01)

func play_roar() -> void:
	if !is_instance_valid(roar_audio):
		return
	roar_audio.stream = ROAR_1 if randf() < 0.5 else ROAR_2
	roar_audio.pitch_scale = randf_range(0.82, 1.02)
	roar_audio.play()

func update_steps(delta:float, movement_speed:float, chasing:bool) -> void:
	if movement_speed < 0.15:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer > 0.0:
		return
	step_audio.pitch_scale = randf_range(0.48, 0.62)
	step_audio.play()
	step_timer = 0.48 if chasing else 0.72

func can_see_player() -> bool:
	if !is_instance_valid(player):
		return false
	if !enraged_hunt && !has_cell_key() && player.global_position.z > TRAMPOLINE_CORRIDOR_LIMIT_Z:
		return false
	var eye := global_position + Vector3.UP * 2.15
	var target := player.global_position + Vector3.UP * 1.05
	var query := PhysicsRayQueryParameters3D.create(eye, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() || hit.get("collider") == player

func look_at_horizontal(target:Vector3) -> void:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_squared_to(flat_target) > 0.001:
		look_at(flat_target, Vector3.UP)
