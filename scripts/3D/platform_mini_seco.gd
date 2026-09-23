extends Area3D

const MODELS = [
	preload("res://assets/modelo_3d/mario_3d_models/mini_seco_blue_rigged.glb"),
	preload("res://assets/modelo_3d/mario_3d_models/mini_seco_orange_rigged.glb"),
	preload("res://assets/modelo_3d/mario_3d_models/mini_seco_red_rigged.glb")
]

enum State {
	IDLE,
	PATROL,
	CHASE,
	JUMPING,
	ATTACK,
	LATCHED,
	STUNNED
}

var maycon:CharacterBody3D
var stage:Node3D
var model:Node3D
var anim_player:AnimationPlayer
var blue_aura:MeshInstance3D

var variant:int = 0
var state:State = State.PATROL
var active:bool = true
var is_slow_motion:bool = false

var home_position:Vector3
var velocity:Vector3 = Vector3.ZERO
var is_on_floor:bool = true

var move_speed:float = 4.2
var jump_force:float = 9.2
var jump_cooldown:float = 0.0
var stun_timer:float = 0.0

# Latch & Blood Drain Variables
var latched_time:float = 0.0
var MIN_LATCH_TIME:float = 4.0
var MAX_LATCH_TIME:float = 7.0
var struggle_score:float = 0.0
var REQUIRED_STRUGGLE:float = 20.0
var prev_input_angle:float = 0.0
var has_prev_angle:bool = false
var blood_tick_timer:float = 0.0
var damage_tick_timer:float = 0.0

# UI Struggle widget
var struggle_hud:CanvasLayer
var struggle_panel:PanelContainer
var struggle_bar:ProgressBar
var struggle_icon:Label

func setup(variant_idx:int, player:CharacterBody3D, world:Node3D) -> void:
	variant = variant_idx % MODELS.size()
	maycon = player
	stage = world
	home_position = global_position
	
	# Instantiate rigged model
	model = MODELS[variant].instantiate()
	model.scale = Vector3.ONE * 0.58
	# Align visual: model in blender faced -Y, in Godot -Z is forward
	add_child(model)
	
	anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_play_anim("Idle")
	
	# Variant stat tuning
	match variant:
		0: # Blue: High Jumper, steady runner
			move_speed = 4.0
			jump_force = 11.2
		1: # Orange: Agility Sprinter
			move_speed = 5.2
			jump_force = 9.0
		2: # Red: Berserk Pouncer
			move_speed = 4.6
			jump_force = 10.0
			
	# Collision Shape
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.44
	capsule.height = 1.15
	shape.shape = capsule
	shape.position.y = 0.58
	add_child(shape)
	
	collision_layer = 4
	collision_mask = 2 # Detect Maycon (Layer 2)
	
	body_entered.connect(_on_body_entered)
	
	_build_blue_aura()
	_build_struggle_hud()
	
	jump_cooldown = randf_range(1.0, 2.5)
	set_physics_process(true)

func _build_blue_aura() -> void:
	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = 0.85
	aura_mesh.height = 1.6
	aura_mesh.radial_segments = 16
	aura_mesh.rings = 8
	blue_aura = MeshInstance3D.new()
	blue_aura.mesh = aura_mesh
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.albedo_color = Color(0.18, 0.65, 1.0, 0.45)
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blue_aura.material_override = aura_mat
	blue_aura.position.y = 0.6
	blue_aura.visible = false
	add_child(blue_aura)

func _build_struggle_hud() -> void:
	struggle_hud = CanvasLayer.new()
	struggle_hud.layer = 25
	
	struggle_panel = PanelContainer.new()
	struggle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	struggle_panel.position = Vector2(-170.0, -145.0)
	struggle_panel.custom_minimum_size = Vector2(340.0, 68.0)
	struggle_panel.pivot_offset = Vector2(170.0, 34.0)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.35, 0.05, 0.08, 0.92)
	style.border_color = Color("ff2a55")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.9, 0.1, 0.2, 0.55)
	style.shadow_size = 14
	style.set_content_margin_all(8)
	struggle_panel.add_theme_stylebox_override("panel", style)
	struggle_hud.add_child(struggle_panel)
	
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	struggle_panel.add_child(col)
	
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 8)
	col.add_child(top_row)
	
	struggle_icon = Label.new()
	struggle_icon.text = "↺ 🕹 ↻"
	struggle_icon.add_theme_font_size_override("font_size", 18)
	struggle_icon.add_theme_color_override("font_color", Color("ffd700"))
	top_row.add_child(struggle_icon)
	
	var label := Label.new()
	label.text = tr("PLATFORM_SHAKE_OFF")
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("ffffff"))
	top_row.add_child(label)
	
	struggle_bar = ProgressBar.new()
	struggle_bar.custom_minimum_size = Vector2(280.0, 14.0)
	struggle_bar.max_value = REQUIRED_STRUGGLE
	struggle_bar.value = 0.0
	struggle_bar.show_percentage = false
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("ff2a70")
	bar_fill.set_corner_radius_all(6)
	struggle_bar.add_theme_stylebox_override("fill", bar_fill)
	col.add_child(struggle_bar)
	
	struggle_panel.visible = false
	add_child(struggle_hud)

func set_slow_motion(active_val:bool) -> void:
	is_slow_motion = active_val
	if is_instance_valid(blue_aura):
		blue_aura.visible = active_val
	if is_instance_valid(anim_player):
		anim_player.speed_scale = 0.15 if active_val else 1.0

func _play_anim(anim_name:String, blend:float = 0.15) -> void:
	if not is_instance_valid(anim_player):
		return
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name or not anim_player.is_playing():
			anim_player.play(anim_name, blend)

func _physics_process(delta:float) -> void:
	if not active or not is_instance_valid(maycon):
		return
		
	var delta_eff := delta * (0.10 if is_slow_motion else 1.0)
	
	if is_slow_motion and is_instance_valid(blue_aura):
		blue_aura.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.007) * 0.08)
		
	match state:
		State.LATCHED:
			_process_latched(delta_eff)
			return
		State.STUNNED:
			_process_stunned(delta_eff)
			return
			
	jump_cooldown = maxf(jump_cooldown - delta_eff, 0.0)
	
	# Gravity & Ground Check
	if not is_on_floor:
		velocity.y -= 22.0 * delta_eff
	else:
		velocity.y = maxf(velocity.y, 0.0)
		
	var move_pos := global_position + velocity * delta_eff
	global_position = move_pos
	
	_check_floor_contact()
	
	var diff := maycon.global_position - global_position
	var horiz := Vector2(diff.x, diff.z)
	var dist := horiz.length()
	var height_diff := maycon.global_position.y - global_position.y
	
	# AI Logic
	if dist < 14.0 and absf(height_diff) < 8.0:
		state = State.CHASE
	else:
		state = State.PATROL
		
	if state == State.CHASE:
		var dir := diff.normalized()
		dir.y = 0.0
		
		# Rotate model smoothly towards target
		if dir.length_squared() > 0.01:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(delta_eff * 9.0, 1.0))
			
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		
		# Jump Conditions:
		# 1. Maycon is on an elevated platform
		# 2. Obstacle or gap ahead
		# 3. Aggressive leaping chase
		var obstacle_ahead := _detect_obstacle_or_gap(dir)
		var player_elevated := height_diff > 0.75
		
		if is_on_floor and jump_cooldown <= 0.0 and (player_elevated or obstacle_ahead or (dist < 6.0 and randf() < 0.28)):
			_jump()
			
		if is_on_floor:
			_play_anim("Run")
		else:
			_play_anim("Jump")
			
		# Close range leap attack
		if dist < 2.8 and is_on_floor and absf(height_diff) < 1.5:
			_pounce_attack(dir)
			
	elif state == State.PATROL:
		# Gentle wandering around home position
		var to_home := home_position - global_position
		to_home.y = 0.0
		if to_home.length() > 0.6:
			var dir := to_home.normalized()
			velocity.x = dir.x * (move_speed * 0.4)
			velocity.z = dir.z * (move_speed * 0.4)
			model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(delta_eff * 5.0, 1.0))
			_play_anim("Run")
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_play_anim("Idle")

func _jump() -> void:
	velocity.y = jump_force
	is_on_floor = false
	jump_cooldown = randf_range(1.6, 2.8)
	_play_anim("Jump", 0.08)

func _pounce_attack(dir:Vector3) -> void:
	velocity.y = 4.8
	velocity.x = dir.x * (move_speed * 1.35)
	velocity.z = dir.z * (move_speed * 1.35)
	is_on_floor = false
	_play_anim("Attack", 0.08)

func _detect_obstacle_or_gap(dir:Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	# Raycast forward for wall / obstacle
	var fwd_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.UP * 0.3 + dir * 1.2, 1)
	var fwd_hit := space.intersect_ray(fwd_query)
	if not fwd_hit.is_empty():
		return true
	# Raycast down in front to check for gap / ledge
	var ground_ahead_query := PhysicsRayQueryParameters3D.create(global_position + dir * 1.1 + Vector3.UP * 0.2, global_position + dir * 1.1 - Vector3.UP * 1.8, 1)
	var ground_ahead := space.intersect_ray(ground_ahead_query)
	if ground_ahead.is_empty():
		return true # Gap ahead, jump across!
	return false

func _check_floor_contact() -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position - Vector3.UP * 0.45, 1)
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		if velocity.y <= 0.0:
			global_position.y = hit.position.y
			velocity.y = 0.0
			is_on_floor = true
	else:
		is_on_floor = false

func _on_body_entered(body:Node3D) -> void:
	if not active or body != maycon:
		return
	if state == State.LATCHED or state == State.STUNNED:
		return
		
	# Check Stomp: Maycon jumping down onto enemy
	if is_slow_motion or stage.get("is_invincible") == true or maycon.get("is_invincible") == true:
		_get_stomped()
		return
		
	if maycon.velocity.y < -1.5 and maycon.global_position.y > global_position.y + 0.5:
		_get_stomped()
		return
		
	# If Maycon already has an enemy latched, don't double-latch; deliver quick swipe damage instead
	if maycon.get("latched_count") != null and maycon.latched_count > 0:
		if maycon.has_method("receive_damage"):
			maycon.receive_damage(6.0, global_position)
		return

	# Otherwise, latch onto Maycon!
	_start_latch()

func _get_stomped() -> void:
	if state == State.LATCHED and is_instance_valid(maycon) and maycon.has_method("set_latched"):
		maycon.set_latched(false)
	if is_instance_valid(struggle_panel):
		struggle_panel.visible = false
	active = false
	monitoring = false
	maycon.bounce()
	stage.enemy_stomped(self)

func _start_latch() -> void:
	state = State.LATCHED
	latched_time = 0.0
	struggle_score = 0.0
	has_prev_angle = false
	blood_tick_timer = 0.0
	damage_tick_timer = 0.0
	
	_play_anim("Latch", 0.05)
	
	if is_instance_valid(struggle_panel):
		struggle_panel.visible = true
		struggle_bar.value = 0.0
		
	# Slow Maycon down while carrying this creature
	if maycon.has_method("set_latched"):
		maycon.set_latched(true)
	if maycon.has_method("receive_damage"):
		# Trigger initial bite damage
		maycon.receive_damage(8.0, global_position)
		
	# Huge initial blood explosion
	stage.call("_spawn_blood", maycon.global_position + Vector3.UP * 0.85, true)
	Input.start_joy_vibration(0, 0.5, 0.7, 0.3)

func _process_latched(delta_eff:float) -> void:
	if not is_instance_valid(maycon) or stage.get("death_in_progress") == true or stage.get("exit_started") == true:
		_detach(false)
		return
		
	# Detach immediately if Maycon triggers invincibility
	if is_slow_motion or stage.get("is_invincible") == true or maycon.get("is_invincible") == true:
		_detach(true)
		_get_stomped()
		return
		
	latched_time += delta_eff
	
	# Clamp position onto Maycon's torso / shoulder facing Maycon
	var forward := Vector3(sin(maycon.visual.rotation.y), 0.0, cos(maycon.visual.rotation.y))
	global_position = maycon.global_position + forward * 0.38 + Vector3.UP * 0.75
	model.rotation.y = maycon.visual.rotation.y + PI
	
	# Struggle rotation input tracking (Analog stick or WASD)
	var joy_vec := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var key_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var stick_input := joy_vec if joy_vec.length() > 0.35 else key_vec
	
	if stick_input.length() > 0.4:
		var curr_angle := stick_input.angle()
		if has_prev_angle:
			var angle_diff := absf(wrapf(curr_angle - prev_input_angle, -PI, PI))
			struggle_score += angle_diff
		prev_input_angle = curr_angle
		has_prev_angle = true
	else:
		has_prev_angle = false
		
	# Animate struggle HUD icon
	if is_instance_valid(struggle_panel) and struggle_panel.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.015) * 0.08
		struggle_panel.scale = Vector2(pulse, pulse)
		struggle_icon.rotation += delta_eff * 12.0
		# Show struggle progress (unlocks at 4s)
		if latched_time < MIN_LATCH_TIME:
			var lock_progress := latched_time / MIN_LATCH_TIME
			struggle_bar.value = minf(struggle_score, REQUIRED_STRUGGLE * 0.92 * lock_progress)
		else:
			struggle_bar.value = struggle_score
			
	# === BLOOD SPRAY: "espirrando sangue pra todo lado, bastante sangue" ===
	blood_tick_timer -= delta_eff
	if blood_tick_timer <= 0.0:
		blood_tick_timer = 0.16 # High frequency blood fountain
		var blood_origin := maycon.global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.45, 1.25), randf_range(-0.35, 0.35))
		stage.call("_spawn_blood", blood_origin, true)
		if stage.blood_overlay:
			stage.blood_overlay.call("flash")
		Input.start_joy_vibration(0, 0.32, 0.45, 0.12)
		
	# === PROGRESSIVE HP DRAIN ===
	damage_tick_timer -= delta_eff
	if damage_tick_timer <= 0.0:
		damage_tick_timer = 0.5
		# Escalating damage over time: more time = more HP lost
		var drain := 3.5 if latched_time < MIN_LATCH_TIME else 6.5
		stage.set_stage_hp(maxf(0.0, stage.stage_hp - drain))
		stage.update_hud()
		if is_instance_valid(stage.damage_punch_audio):
			stage.damage_punch_audio.pitch_scale = randf_range(1.08, 1.22)
			stage.damage_punch_audio.play()
		if stage.stage_hp <= 0.0:
			_detach(false)
			maycon.start_player_death("enemy")
			return
			
	# === DETACHMENT RULES ===
	# Rule 1: Minimum latch duration is 4 seconds
	# Rule 2: Shaking analog stick detaches once t >= 4.0s
	# Rule 3: Maximum latch duration is 7 seconds
	if latched_time >= MIN_LATCH_TIME and struggle_score >= REQUIRED_STRUGGLE:
		_detach(true) # Shaken off by player!
	elif latched_time >= MAX_LATCH_TIME:
		_detach(false) # Detaches naturally after 7s!

func _detach(flung_by_player:bool) -> void:
	if is_instance_valid(maycon) and maycon.has_method("set_latched"):
		maycon.set_latched(false)
	state = State.STUNNED
	stun_timer = 2.8
	
	if is_instance_valid(struggle_panel):
		struggle_panel.visible = false
		
	_play_anim("Stunned", 0.08)
	
	# Flung back off Maycon
	var forward := Vector3(sin(maycon.visual.rotation.y), 0.0, cos(maycon.visual.rotation.y))
	var fling_dir := -forward if flung_by_player else forward
	velocity = fling_dir * (7.5 if flung_by_player else 3.5) + Vector3.UP * 4.5
	is_on_floor = false
	
	# Spawn final separation blood burst
	stage.call("_spawn_blood", global_position + Vector3.UP * 0.7, true)

func _process_stunned(delta_eff:float) -> void:
	stun_timer -= delta_eff
	
	if not is_on_floor:
		velocity.y -= 22.0 * delta_eff
		velocity.x *= 0.94
		velocity.z *= 0.94
		global_position += velocity * delta_eff
		_check_floor_contact()
	else:
		velocity = Vector3.ZERO
		
	if stun_timer <= 0.0:
		state = State.PATROL
		_play_anim("Idle")
		jump_cooldown = 1.0

func _exit_tree() -> void:
	if state == State.LATCHED and is_instance_valid(maycon) and maycon.has_method("set_latched"):
		maycon.set_latched(false)
	if is_instance_valid(struggle_hud):
		struggle_hud.queue_free()

