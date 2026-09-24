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

class StruggleAnalogWidget extends Control:
	var struggle_score:float = 0.0
	var required_struggle:float = 20.0
	var latched_time:float = 0.0
	var min_latch_time:float = 4.0
	var max_latch_time:float = 7.0
	var visual_spin:float = 0.0
	var anim_time:float = 0.0
	var has_input:bool = false

	func update_state(score:float, req:float, l_time:float, min_t:float, max_t:float, spin_delta:float, is_inputting:bool, delta:float) -> void:
		struggle_score = score
		required_struggle = req
		latched_time = l_time
		min_latch_time = min_t
		max_latch_time = max_t
		anim_time += delta
		has_input = is_inputting
		if is_inputting and absf(spin_delta) > 0.0:
			visual_spin += spin_delta * 1.5
		else:
			visual_spin += delta * 3.4
		queue_redraw()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var w := size.x
		var h := size.y
		
		# 1. Main Background Panel
		var panel_rect := Rect2(0, 0, w, h)
		draw_rect(panel_rect, Color(0.015, 0.01, 0.03, 0.94), true)
		
		# Neon borders
		var border_col_1 := Color(1.0, 0.12, 0.35, 0.95)
		var border_col_2 := Color(0.2, 0.85, 1.0, 0.9)
		draw_rect(panel_rect, border_col_1, false, 2.5)
		draw_line(Vector2(0, 3), Vector2(w, 3), border_col_2, 1.5)
		draw_line(Vector2(0, h - 3), Vector2(w, h - 3), border_col_2, 1.5)
		
		# 2. Rotating Analog Stick Simulation (Inspired by realtime_battle_specials.gd)
		var stick_center := Vector2(62.0, h * 0.5)
		var stick_radius := 38.0
		
		# Base well
		draw_circle(stick_center, stick_radius, Color(0.02, 0.025, 0.06, 0.98))
		draw_circle(stick_center, stick_radius - 2.0, Color(0.06, 0.09, 0.16, 0.8))
		
		# Outer luminous arc
		var pulse := 0.75 + sin(anim_time * 6.0) * 0.25
		var arc_color := Color(0.35, 0.88, 1.0, 0.95)
		draw_arc(stick_center, stick_radius, -PI * 0.2, TAU - PI * 0.2, 48, arc_color, 3.5)
		
		# Rotating arrow tip indicating circular motion
		var arrow_angle := anim_time * 3.6
		var arrow_tip := stick_center + Vector2.from_angle(arrow_angle) * stick_radius
		var tangent := Vector2.from_angle(arrow_angle + PI * 0.5)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip + tangent * 7.5,
			arrow_tip - tangent * 7.5,
			arrow_tip + Vector2.from_angle(arrow_angle) * 12.0
		]), Color(0.35, 0.88, 1.0, 0.98))
		
		# Orbiting analog knob
		var knob_pos := stick_center + Vector2.from_angle(visual_spin) * 20.0
		var knob_color := Color(1.0, 0.9, 0.35, 1.0 if has_input else pulse)
		draw_circle(knob_pos, 13.5, Color(0.16, 0.2, 0.3, 1.0))
		draw_circle(knob_pos, 8.5, knob_color)
		draw_circle(knob_pos, 3.5, Color.WHITE)
		
		# Center crosshairs
		draw_line(stick_center - Vector2(7, 0), stick_center + Vector2(7, 0), Color(0.35, 0.45, 0.55, 0.6), 1.5)
		draw_line(stick_center - Vector2(0, 7), stick_center + Vector2(0, 7), Color(0.35, 0.45, 0.55, 0.6), 1.5)
		
		# 3. Text & Progress Bar
		var text_x := 122.0
		var title_text := tr("PLATFORM_SHAKE_OFF")
		draw_string(font, Vector2(text_x, 26.0), title_text, HORIZONTAL_ALIGNMENT_LEFT, 290, 16, Color(1.0, 0.92, 0.5, 1.0))
		
		# Status instruction text
		var status_text := ""
		var status_col: Color
		if latched_time < min_latch_time:
			var rem := min_latch_time - latched_time
			status_text = "%s (%0.1fs)" % [tr("PLATFORM_HOLD_ON"), rem]
			status_col = Color(1.0, 0.35, 0.35, 0.95)
		else:
			status_text = tr("PLATFORM_BREAK_FREE")
			status_col = Color(0.3, 0.98, 0.5, 1.0)
		draw_string(font, Vector2(text_x, 46.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, 290, 13, status_col)
		
		# Progress Bar
		var bar_x := text_x
		var bar_y := 55.0
		var bar_w := 280.0
		var bar_h := 18.0
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.015, 0.02, 0.05, 0.95), true)
		
		var progress := 0.0
		if latched_time < min_latch_time:
			var lock_progress := latched_time / min_latch_time
			progress = minf(struggle_score / required_struggle, 0.92) * lock_progress
		else:
			progress = clampf(struggle_score / required_struggle, 0.0, 1.0)
			
		var fill_w := bar_w * progress
		var fill_color := Color(1.0, 0.1, 0.35) if latched_time < min_latch_time else Color(0.2, 0.9, 0.45)
		if fill_w > 4.0:
			draw_rect(Rect2(bar_x + 2, bar_y + 2, fill_w - 4, bar_h - 4), fill_color, true)
			draw_line(Vector2(bar_x + 2, bar_y + 4), Vector2(bar_x + fill_w - 2, bar_y + 4), Color(1.0, 1.0, 1.0, 0.55), 1.5)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), border_col_2, false, 2.0)

static var current_combatant:Area3D = null

static func is_someone_in_combat(excluding:Area3D = null) -> bool:
	if is_instance_valid(current_combatant) and current_combatant != excluding:
		if current_combatant.active and current_combatant.state in [State.CHASE, State.ATTACK, State.LATCHED, State.STUNNED]:
			return true
	return false

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

# Mouse struggle rotation tracking
var mouse_rotation_accum:float = 0.0
var prev_mouse_dir:Vector2 = Vector2.ZERO
var has_prev_mouse_dir:bool = false

# UI Struggle widget
var struggle_hud:CanvasLayer
var struggle_widget:StruggleAnalogWidget

func setup(variant_idx:int, player:CharacterBody3D, world:Node3D) -> void:
	variant = variant_idx % MODELS.size()
	maycon = player
	stage = world
	home_position = global_position
	
	# Instantiate rigged model
	model = MODELS[variant].instantiate()
	model.scale = Vector3.ONE * 0.72
	model.position.y = 0.684 # Feet align precisely with local Y = 0.0
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
	capsule.radius = 0.52
	capsule.height = 1.38
	shape.shape = capsule
	shape.position.y = 0.69
	add_child(shape)
	
	collision_layer = 4
	collision_mask = 2 # Detect Maycon (Layer 2)
	
	body_entered.connect(_on_body_entered)
	
	_build_blue_aura()
	_build_struggle_hud()
	
	_check_floor_contact()
	home_position = global_position
	
	jump_cooldown = randf_range(1.0, 2.5)
	set_physics_process(true)

func _build_blue_aura() -> void:
	var aura_mesh := SphereMesh.new()
	aura_mesh.radius = 1.05
	aura_mesh.height = 1.95
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
	blue_aura.position.y = 0.72
	blue_aura.visible = false
	add_child(blue_aura)

func _build_struggle_hud() -> void:
	struggle_hud = CanvasLayer.new()
	struggle_hud.layer = 25
	
	struggle_widget = StruggleAnalogWidget.new()
	struggle_widget.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	struggle_widget.position = Vector2(-210.0, -120.0)
	struggle_widget.custom_minimum_size = Vector2(420.0, 88.0)
	struggle_widget.size = Vector2(420.0, 88.0)
	struggle_widget.pivot_offset = Vector2(210.0, 44.0)
	struggle_widget.visible = false
	struggle_hud.add_child(struggle_widget)
	
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

func _unhandled_input(event:InputEvent) -> void:
	if state != State.LATCHED:
		return
	if event is InputEventMouseMotion:
		var motion:Vector2 = event.relative
		if motion.length() > 2.0:
			var cur_dir := motion.normalized()
			if has_prev_mouse_dir:
				var angle_delta := absf(wrapf(cur_dir.angle() - prev_mouse_dir.angle(), -PI, PI))
				if angle_delta >= 0.05 and angle_delta <= 1.8:
					mouse_rotation_accum += angle_delta
			prev_mouse_dir = cur_dir
			has_prev_mouse_dir = true

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
	
	# AI Logic: Allow ONLY one Mini Seco in combat with Maycon at a time!
	var someone_fighting := is_someone_in_combat(self)
	
	if someone_fighting:
		# Another monster is fighting Maycon: leave and wander far away from the combat zone
		if current_combatant == self:
			current_combatant = null
		state = State.PATROL
		
		# If near Maycon / combat center, steer away from the fight
		if dist < 16.0:
			var away_dir := -diff.normalized()
			away_dir.y = 0.0
			if away_dir.length_squared() < 0.01:
				away_dir = Vector3(1.0, 0.0, 0.0)
				
			if is_on_floor and jump_cooldown <= 0.0 and _detect_obstacle_or_gap(away_dir):
				_jump()
				
			velocity.x = away_dir.x * (move_speed * 0.65)
			velocity.z = away_dir.z * (move_speed * 0.65)
			model.rotation.y = lerp_angle(model.rotation.y, atan2(away_dir.x, away_dir.z), minf(delta_eff * 6.0, 1.0))
			_play_anim("Run" if is_on_floor else "Jump")
		else:
			# Far enough away: wander calmly around home position
			var to_home := home_position - global_position
			to_home.y = 0.0
			if to_home.length() > 0.8:
				var dir := to_home.normalized()
				velocity.x = dir.x * (move_speed * 0.35)
				velocity.z = dir.z * (move_speed * 0.35)
				model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), minf(delta_eff * 4.0, 1.0))
				_play_anim("Run")
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				_play_anim("Idle")
		return
		
	# No other monster is fighting Maycon: can engage if close
	if dist < 14.0 and absf(height_diff) < 8.0:
		current_combatant = self
		state = State.CHASE
	else:
		if current_combatant == self:
			current_combatant = null
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
	var fwd_query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.65, global_position + Vector3.UP * 0.65 + dir * 1.3, 1)
	var fwd_hit := space.intersect_ray(fwd_query)
	if not fwd_hit.is_empty():
		return true
	# Raycast down in front to check for gap / ledge
	var ground_ahead_query := PhysicsRayQueryParameters3D.create(global_position + dir * 1.2 + Vector3.UP * 0.35, global_position + dir * 1.2 - Vector3.UP * 1.8, 1)
	var ground_ahead := space.intersect_ray(ground_ahead_query)
	if ground_ahead.is_empty():
		return true # Gap ahead, jump across!
	return false

func _check_floor_contact() -> void:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.85, global_position - Vector3.UP * 0.45, 1)
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
		
	# Regra: não agarrar Maycon se ele estiver no ar! Somente consegue agarrar se Maycon estiver no chão.
	if not maycon.is_on_floor():
		if maycon.velocity.y < 0.5 and maycon.global_position.y > global_position.y:
			_get_stomped()
		return
		
	# Do not attack or latch if another monster is already fighting Maycon
	if is_someone_in_combat(self):
		return
		
	# If Maycon already has an enemy latched, don't double-latch
	if maycon.get("latched_count") != null and maycon.latched_count > 0:
		return

	# Otherwise, claim combat slot and latch onto Maycon!
	current_combatant = self
	_start_latch()

func _get_stomped() -> void:
	if current_combatant == self:
		current_combatant = null
	if state == State.LATCHED and is_instance_valid(maycon) and maycon.has_method("set_latched"):
		maycon.set_latched(false)
	if is_instance_valid(struggle_widget):
		struggle_widget.visible = false
	active = false
	monitoring = false
	var is_inv: bool = (is_instance_valid(stage) and stage.get("is_invincible") == true) or (is_instance_valid(maycon) and maycon.get("is_invincible") == true)
	if not is_inv:
		maycon.bounce()
	else:
		_launch_mini_seco_away()
	stage.enemy_stomped(self)

func _launch_mini_seco_away() -> void:
	if not is_instance_valid(model) or not is_instance_valid(maycon):
		return
	var away := (global_position - maycon.global_position).normalized()
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	if is_instance_valid(stage) and "effects" in stage:
		var corpse := model.duplicate() as Node3D
		corpse.position = global_position
		corpse.rotation = model.rotation
		corpse.scale = model.scale
		stage.effects.add_child(corpse)
		var fly_target := global_position + Vector3(away.x * 14.0, 7.0, away.z * 14.0)
		var fly_tw := stage.create_tween().bind_node(corpse).set_parallel(true)
		fly_tw.tween_property(corpse, "position", fly_target, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly_tw.tween_property(corpse, "rotation", Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)), 0.55)
		fly_tw.tween_property(corpse, "scale", Vector3.ZERO, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly_tw.chain().tween_callback(corpse.queue_free)

func _start_latch() -> void:
	state = State.LATCHED
	latched_time = 0.0
	struggle_score = 0.0
	has_prev_angle = false
	mouse_rotation_accum = 0.0
	has_prev_mouse_dir = false
	blood_tick_timer = 0.0
	damage_tick_timer = 0.0
	
	_play_anim("Latch", 0.05)
	
	if is_instance_valid(struggle_widget):
		struggle_widget.visible = true
		
	# Slow Maycon down while carrying this creature
	if maycon.has_method("set_latched"):
		maycon.set_latched(true)
	if maycon.has_method("receive_damage"):
		# Trigger initial bite damage
		maycon.receive_damage(8.0, global_position)
		
	# Initial blood burst projected from top of head down to the ground
	stage.call("_spawn_blood", maycon.global_position + Vector3.UP * 1.45, true)
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
	
	# Clamp position on top of Maycon's head
	var forward := Vector3(sin(maycon.visual.rotation.y), 0.0, cos(maycon.visual.rotation.y))
	global_position = maycon.global_position + forward * 0.08 + Vector3.UP * 1.42
	model.rotation.y = maycon.visual.rotation.y + PI
	
	# 1. Analog Sticks (Both Left and Right) & Keyboard WASD
	var left_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var right_stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	var key_stick := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var active_stick := left_stick
	if right_stick.length() > active_stick.length():
		active_stick = right_stick
	if key_stick.length() > active_stick.length():
		active_stick = key_stick
		
	var rotation_input_amount := 0.0
	var is_inputting := false
	var spin_delta := 0.0
	
	if active_stick.length() > 0.35:
		var cur_angle := active_stick.angle()
		if has_prev_angle:
			var raw_delta := wrapf(cur_angle - prev_input_angle, -PI, PI)
			var angle_diff := absf(raw_delta)
			if angle_diff >= 0.02 and angle_diff <= 1.5:
				rotation_input_amount += angle_diff
				spin_delta = raw_delta
				is_inputting = true
		prev_input_angle = cur_angle
		has_prev_angle = true
	else:
		has_prev_angle = false
		
	# 2. Mouse Rotation Input
	if mouse_rotation_accum > 0.0:
		rotation_input_amount += mouse_rotation_accum
		spin_delta = mouse_rotation_accum
		is_inputting = true
		mouse_rotation_accum = 0.0
		
	struggle_score += rotation_input_amount
	
	# Update struggle HUD widget
	if is_instance_valid(struggle_widget) and struggle_widget.visible:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.015) * 0.06
		struggle_widget.scale = Vector2(pulse, pulse)
		struggle_widget.update_state(struggle_score, REQUIRED_STRUGGLE, latched_time, MIN_LATCH_TIME, MAX_LATCH_TIME, spin_delta, is_inputting, delta_eff)
			
	# === BLOOD SPRAY: Falls from Maycon's head down to the ground ===
	blood_tick_timer -= delta_eff
	if blood_tick_timer <= 0.0:
		blood_tick_timer = 0.16 # High frequency blood fountain
		var blood_origin := maycon.global_position + Vector3.UP * 1.42 + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.25), randf_range(-0.2, 0.2))
		if stage.has_method("spawn_latched_blood"):
			stage.spawn_latched_blood(blood_origin)
		else:
			stage.call("_spawn_blood", blood_origin, false)
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
	# Rule 2: Shaking analog sticks / mouse / WASD detaches once t >= 4.0s
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
	
	if is_instance_valid(struggle_widget):
		struggle_widget.visible = false
		
	_play_anim("Stunned", 0.08)
	
	# Flung back off Maycon
	var forward := Vector3(sin(maycon.visual.rotation.y), 0.0, cos(maycon.visual.rotation.y))
	var fling_dir := -forward if flung_by_player else forward
	velocity = fling_dir * (7.5 if flung_by_player else 3.5) + Vector3.UP * 4.5
	is_on_floor = false
	
	# Spawn final separation blood burst from head
	stage.call("_spawn_blood", maycon.global_position + Vector3.UP * 1.45, true)

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
		if current_combatant == self:
			current_combatant = null
		state = State.PATROL
		_play_anim("Idle")
		jump_cooldown = 1.0

func _exit_tree() -> void:
	if current_combatant == self:
		current_combatant = null
	if state == State.LATCHED and is_instance_valid(maycon) and maycon.has_method("set_latched"):
		maycon.set_latched(false)
	if is_instance_valid(struggle_hud):
		struggle_hud.queue_free()
