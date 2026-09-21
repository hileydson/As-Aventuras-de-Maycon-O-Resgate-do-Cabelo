extends "res://scripts/realtime_battle.gd"

const SPECIAL_PENTAGRAM_THRESHOLD:int = 15
const SPECIAL_RUSH_THRESHOLD:int = 20
const SPECIAL_METER_MAX:int = 20
const COMBO_MUSIC_STING_DURATION:float = 0.55
const PENTAGRAM_PULSE_COUNT:int = 18
const PENTAGRAM_CHARGE_DURATION:float = 7.0
const PENTAGRAM_REQUIRED_ROTATIONS:float = 5.0
const PENTAGRAM_BASE_SPEED:float = 0.25
const PENTAGRAM_MAX_SPEED:float = 3.6

var special_hits:int = 0
var special_active:bool = false
var special_meter:ProgressBar
var special_meter_label:Label
var special_prompt_label:Label
var special_overlay:Control
var special_charge_sound:AudioStreamPlayer
var special_rush_sound:AudioStreamPlayer
var special_punch_buffer:float = 0.0
var special_kick_buffer:float = 0.0
var special_dash_buffer:float = 0.0
var combo_music_sting_token:int = 0
var combo_music_sting_volume_db:float = -3.0
var pentagram_rotation_enabled:bool = false
var pentagram_charge:float = 0.0
var pentagram_accumulated_rotation:float = 0.0
var pentagram_last_stick:Vector2 = Vector2.ZERO
var pentagram_input_activity:float = 0.0
var pentagram_spin_speed:float = 0.0
var pentagram_peak_speed:float = 0.0
var pentagram_spin_direction:float = 1.0
var pentagram_is_near_end:bool = false

class SpecialOverlay:
	extends Control

	var mode:String = ""
	var energy:float = 0.0
	var spin:float = 0.0
	var spin_speed:float = 0.0
	var peak_spin_speed:float = 0.0
	var spin_direction:float = 1.0
	var is_near_end:bool = false
	var hit_count:int = 0
	var portrait_texture:Texture2D
	var effect_time:float = 0.0
	var pentagram_reveal:float = 0.0
	var rotation_progress:float = 0.0
	var blood_level:float = 0.0
	var impact_flash:float = 0.0
	var analog_hint_text:String = "GIRE O ANALÓGICO"
	var analog_input_activity:float = 0.0
	var pentagram_exploding:bool = false
	var explosion_progress:float = 0.0

	func _ready() -> void:
		position = Vector2.ZERO
		size = Vector2(1152, 648)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		visible = false

	func start_pentagram(texture:Texture2D, instruction_text:String = "GIRE O ANALÓGICO") -> void:
		mode = "pentagram"
		portrait_texture = texture
		analog_hint_text = instruction_text
		energy = 0.0
		spin = -PI * 0.5
		spin_speed = PENTAGRAM_BASE_SPEED
		peak_spin_speed = PENTAGRAM_BASE_SPEED
		spin_direction = 1.0
		is_near_end = false
		effect_time = 0.0
		pentagram_reveal = 0.0
		rotation_progress = 0.0
		blood_level = 0.0
		impact_flash = 0.0
		analog_input_activity = 0.0
		pentagram_exploding = false
		explosion_progress = 0.0
		visible = true
		queue_redraw()

	func add_pentagram_rotation(angle_delta:float, charge:float, activity:float, current_speed:float = 0.0, direction:float = 1.0) -> void:
		if pentagram_exploding && !is_near_end:
			return
		if absf(direction) > 0.01:
			spin_direction = 1.0 if direction > 0.0 else -1.0
		if current_speed > 0.0:
			spin_speed = maxf(spin_speed, current_speed)
			peak_spin_speed = maxf(peak_spin_speed, spin_speed)
		energy = clampf(charge, 0.0, 1.0)
		rotation_progress = energy
		analog_input_activity = clampf(activity, 0.0, 1.0)
		queue_redraw()

	func set_near_end(near_end:bool = true) -> void:
		is_near_end = near_end
		if is_near_end:
			spin_speed = maxf(spin_speed, peak_spin_speed)

	func start_pentagram_explosion() -> void:
		pentagram_exploding = true
		is_near_end = true
		spin_speed = maxf(spin_speed, peak_spin_speed)
		explosion_progress = 0.0
		analog_input_activity = 0.0
		impact_flash = 1.0
		queue_redraw()

	func register_pentagram_hit(blood_amount:float) -> void:
		blood_level = clampf(blood_level + blood_amount, 0.0, 1.0)
		impact_flash = 1.0
		queue_redraw()

	func start_rush() -> void:
		mode = "rush"
		energy = 0.0
		hit_count = 0
		effect_time = 0.0
		visible = true
		queue_redraw()

	func finish() -> void:
		visible = false
		mode = ""
		energy = 0.0
		hit_count = 0
		spin_speed = 0.0
		peak_spin_speed = 0.0
		spin_direction = 1.0
		is_near_end = false
		pentagram_reveal = 0.0
		rotation_progress = 0.0
		blood_level = 0.0
		impact_flash = 0.0
		analog_input_activity = 0.0
		pentagram_exploding = false
		explosion_progress = 0.0
		queue_redraw()

	func _process(delta:float) -> void:
		if !visible:
			return
		var unscaled_delta = delta / maxf(Engine.time_scale, 0.001)
		effect_time += unscaled_delta
		if mode == "pentagram":
			pentagram_reveal = clampf((effect_time - 0.3) / 0.82, 0.0, 1.0)
			if pentagram_exploding:
				explosion_progress = minf(1.0, explosion_progress + unscaled_delta / 1.2)
			else:
				analog_input_activity = maxf(0.0, analog_input_activity - unscaled_delta * 1.8)
			impact_flash = maxf(0.0, impact_flash - unscaled_delta * 4.2)
			if is_near_end || pentagram_exploding:
				spin_speed = maxf(spin_speed, peak_spin_speed)
			else:
				spin_speed = maxf(PENTAGRAM_BASE_SPEED, spin_speed - unscaled_delta * 0.55)
			peak_spin_speed = maxf(peak_spin_speed, spin_speed)
			spin += spin_direction * spin_speed * unscaled_delta
		queue_redraw()

	func _draw() -> void:
		if mode == "pentagram":
			draw_pentagram_force()
		elif mode == "rush":
			draw_rush_motion_blur()

	func draw_pentagram_force() -> void:
		var trace_progress = clampf(effect_time / 0.24, 0.0, 1.0)
		var intro_alpha = 1.0 - clampf((effect_time - 0.96) / 0.28, 0.0, 1.0)
		if intro_alpha > 0.0:
			var trace_start = Vector2(-30, 454)
			var trace_finish = Vector2(1182, 232)
			var traced_to = trace_start.lerp(trace_finish, trace_progress)
			draw_line(trace_start, traced_to, Color(0.12, 0.02, 0.18, 0.72 * intro_alpha), 30.0)
			draw_line(trace_start, traced_to, Color(1.0, 0.08, 0.38, intro_alpha), 7.0)
			draw_line(trace_start + Vector2(0, 15), traced_to + Vector2(0, 15), Color(0.28, 0.85, 1.0, 0.82 * intro_alpha), 2.0)
			var portrait_alpha = clampf((effect_time - 0.06) / 0.2, 0.0, 1.0) * intro_alpha
			if portrait_texture && portrait_alpha > 0.0:
				draw_texture_rect_region(portrait_texture, Rect2(-24, 218, 350, 398), Rect2(104, 28, 292, 332), Color(1.0, 1.0, 1.0, portrait_alpha))
				draw_line(Vector2(302, 214), Vector2(302, 616), Color(1.0, 0.16, 0.43, 0.8 * portrait_alpha), 5.0)
			var font = ThemeDB.fallback_font
			draw_string(font, Vector2(314, 174), "PENTAGRAM FORCE", HORIZONTAL_ALIGNMENT_CENTER, 770, 52, Color(1.0, 0.92, 0.68, intro_alpha))
			draw_string(font, Vector2(416, 213), "15 HIT SUPER", HORIZONTAL_ALIGNMENT_CENTER, 500, 19, Color(0.45, 0.86, 1.0, 0.94 * intro_alpha))

		if pentagram_reveal <= 0.0:
			return
		var reveal = smoothstep(0.0, 1.0, pentagram_reveal)
		var explosion_alpha = 1.0 - smoothstep(0.08, 1.0, explosion_progress) if pentagram_exploding else 1.0
		var symbol_alpha = reveal * explosion_alpha
		var pulse = 1.0 + sin(effect_time * 5.2) * 0.025
		var center = Vector2(576, 326)
		var explosion_scale = 1.0 + smoothstep(0.0, 1.0, explosion_progress) * 0.72 if pentagram_exploding else 1.0
		var radius = lerpf(24.0, 218.0, reveal) * pulse * explosion_scale
		for glow_index in range(4, 0, -1):
			var glow_alpha = (0.025 + energy * 0.025) * float(5 - glow_index) * symbol_alpha
			draw_arc(center, radius + glow_index * 9.0, 0.0, TAU, 96, Color(0.95, 0.04, 0.34, glow_alpha), glow_index * 5.0)
		draw_arc(center, radius + 13.0, spin, spin + TAU * 0.72, 72, Color(0.24, 0.82, 1.0, 0.82 * symbol_alpha), 4.0)
		draw_arc(center, radius, 0.0, TAU, 96, Color(1.0, 0.12, 0.36, symbol_alpha), 7.0)
		var outer_points:PackedVector2Array = []
		for point_index in 5:
			outer_points.append(center + Vector2.from_angle(spin + float(point_index) * TAU / 5.0) * radius)
		var star_order = [0, 2, 4, 1, 3, 0]
		var star_points:PackedVector2Array = []
		for point_index in star_order:
			star_points.append(outer_points[point_index])
		draw_polyline(star_points, Color(0.18, 0.015, 0.08, 0.82 * symbol_alpha), 22.0, true)
		draw_polyline(star_points, Color(1.0, 0.06, 0.28, symbol_alpha), 9.0, true)
		var blood_stain_count = int(round(blood_level * 34.0))
		for stain_index in blood_stain_count:
			var local_angle = fmod(float(stain_index) * 2.399963 + 0.35, TAU)
			var distance_factor = 0.14 + absf(sin(float(stain_index) * 1.731)) * 0.72
			var stain_position = center + Vector2.from_angle(local_angle + spin) * radius * distance_factor
			var stain_radius = 3.5 + fmod(float(stain_index) * 3.17, 8.5)
			draw_circle(stain_position, stain_radius, Color(0.42, 0.0, 0.035, 0.82 * symbol_alpha))
			draw_circle(stain_position + Vector2.from_angle(local_angle * 1.7) * stain_radius * 0.7, stain_radius * 0.48, Color(0.78, 0.015, 0.06, 0.76 * symbol_alpha))
		draw_polyline(star_points, Color(1.0, 0.76, 0.34, 0.88 * symbol_alpha), 2.0, true)
		for point in outer_points:
			draw_circle(point, 8.0 + energy * 5.0, Color(0.4, 0.9, 1.0, 0.92 * symbol_alpha))
			draw_circle(point, 3.0 + energy * 3.0, Color(1.0, 1.0, 1.0, symbol_alpha))
		if impact_flash > 0.0:
			draw_arc(center, radius + 22.0 + impact_flash * 18.0, 0.0, TAU, 96, Color(1.0, 0.82, 0.88, impact_flash * 0.72), 5.0)
		if energy > 0.42 && !pentagram_exploding:
			var lightning_count = 2 + int(energy * 4.0)
			for bolt_index in lightning_count:
				var bolt_angle = spin + float(bolt_index) * TAU / float(lightning_count)
				var bolt_end = center + Vector2.from_angle(bolt_angle) * lerpf(radius * 0.65, 520.0, energy)
				draw_lightning(center, bolt_end, bolt_index, energy * reveal)
		if pentagram_exploding:
			draw_pentagram_blood_explosion(center, radius)
		elif effect_time >= 1.08:
			draw_analog_rotation_hint()

	func draw_analog_rotation_hint() -> void:
		var font = ThemeDB.fallback_font
		var hint_pulse = 0.78 + sin(effect_time * 6.0) * 0.22
		var hint_color = Color(1.0, 0.9, 0.34, hint_pulse if analog_input_activity < 0.12 else 1.0)
		var stick_center = Vector2(911, 526)
		draw_circle(stick_center, 43.0, Color(0.015, 0.02, 0.05, 0.82))
		draw_arc(stick_center, 43.0, -PI * 0.2, TAU - PI * 0.2, 48, Color(0.35, 0.88, 1.0, 0.92), 4.0)
		var arrow_angle = effect_time * 2.4
		var arrow_tip = stick_center + Vector2.from_angle(arrow_angle) * 43.0
		var tangent = Vector2.from_angle(arrow_angle + PI * 0.5)
		draw_colored_polygon(PackedVector2Array([arrow_tip + tangent * 9.0, arrow_tip - tangent * 9.0, arrow_tip + Vector2.from_angle(arrow_angle) * 14.0]), Color(0.35, 0.88, 1.0, 0.96))
		var knob_position = stick_center + Vector2.from_angle(spin) * 23.0
		draw_circle(knob_position, 14.0, Color(0.16, 0.2, 0.3, 1.0))
		draw_circle(knob_position, 8.0, hint_color)
		draw_string(font, Vector2(615, 516), analog_hint_text, HORIZONTAL_ALIGNMENT_CENTER, 245, 24, hint_color)
		draw_string(font, Vector2(615, 544), "FORÇA DO PENTAGRAMA", HORIZONTAL_ALIGNMENT_CENTER, 245, 15, Color(0.76, 0.9, 1.0, 0.92))
		draw_rect(Rect2(630, 556, 215, 13), Color(0.015, 0.02, 0.05, 0.9), true)
		draw_rect(Rect2(633, 559, 209.0 * energy, 7), Color(1.0, 0.06, 0.3, 0.98), true)
		draw_rect(Rect2(630, 556, 215, 13), Color(0.35, 0.88, 1.0, 0.88), false, 2.0)

	func draw_pentagram_blood_explosion(center:Vector2, radius:float) -> void:
		var progress = smoothstep(0.0, 1.0, explosion_progress)
		for drop_index in 64:
			var delay = fmod(float(drop_index) * 0.071, 0.34)
			var travel = clampf((progress - delay) / maxf(0.01, 1.0 - delay), 0.0, 1.0)
			if travel <= 0.0:
				continue
			var angle = float(drop_index) * 2.399963 + sin(float(drop_index) * 1.37) * 0.28 + spin * 0.35
			var direction = Vector2.from_angle(angle)
			var drop_position = center + direction * (radius * 0.16 + travel * (235.0 + fmod(float(drop_index) * 17.0, 220.0)))
			var drop_alpha = (1.0 - travel) * 0.92
			var drop_radius = 3.0 + fmod(float(drop_index) * 2.73, 9.0)
			draw_line(drop_position - direction * (18.0 + travel * 28.0), drop_position, Color(0.48, 0.0, 0.035, drop_alpha * 0.72), maxf(2.0, drop_radius * 0.65))
			draw_circle(drop_position, drop_radius, Color(0.72, 0.0, 0.05, drop_alpha))
			draw_circle(drop_position - direction.orthogonal() * drop_radius * 0.34, drop_radius * 0.36, Color(1.0, 0.08, 0.14, drop_alpha * 0.88))

	func draw_rush_motion_blur() -> void:
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06, 0.16 + energy * 0.18))
		for line_index in 24:
			var line_phase = fposmod(float(line_index) * 47.0 + effect_time * (620.0 + energy * 1100.0), 780.0)
			var y = 72.0 + fposmod(float(line_index) * 61.0, 520.0)
			var line_length = 90.0 + energy * 310.0 + sin(line_index * 1.7) * 38.0
			var x = 1152.0 - line_phase
			var line_color = Color(0.2, 0.82, 1.0, 0.08 + energy * 0.24)
			draw_line(Vector2(x, y), Vector2(x - line_length, y), line_color, 2.0 + energy * 5.0)
			draw_line(Vector2(1152.0 - x, y + 8.0), Vector2(1152.0 - x + line_length * 0.65, y + 8.0), Color(1.0, 0.12, 0.38, line_color.a * 0.8), 2.0 + energy * 3.0)
		var title_scale = 1.0 + sin(effect_time * 14.0) * 0.035
		draw_string(font, Vector2(246, 112), "MAYCON RUSH", HORIZONTAL_ALIGNMENT_CENTER, 660, int(42.0 * title_scale), Color(1.0, 0.88, 0.32, 0.98))
		draw_string(font, Vector2(326, 164), "%02d / 50 HITS" % hit_count, HORIZONTAL_ALIGNMENT_CENTER, 500, 30, Color(0.35, 0.9, 1.0, 1.0))
		draw_line(Vector2(320, 180), Vector2(832, 180), Color(1.0, 0.12, 0.4, 0.65 + energy * 0.3), 5.0)
		if energy > 0.82:
			draw_circle(Vector2(576, 324), 54.0 + energy * 90.0, Color(1.0, 1.0, 1.0, (energy - 0.82) * 1.8))

	func draw_lightning(start:Vector2, finish:Vector2, bolt_index:int, strength:float) -> void:
		var points:PackedVector2Array = []
		var direction = finish - start
		var perpendicular = direction.normalized().orthogonal()
		var segments = 9
		for segment_index in range(segments + 1):
			var amount = float(segment_index) / float(segments)
			var envelope = sin(amount * PI)
			var jitter = sin(effect_time * (25.0 + bolt_index) + segment_index * 4.73 + bolt_index * 2.1) * 28.0 * envelope * strength
			points.append(start.lerp(finish, amount) + perpendicular * jitter)
		draw_polyline(points, Color(0.2, 0.36, 1.0, 0.42), 11.0, true)
		draw_polyline(points, Color(0.35, 0.9, 1.0, 0.95), 4.0, true)
		draw_polyline(points, Color.WHITE, 1.5, true)

func _ready() -> void:
	super._ready()
	build_special_hud()
	special_charge_sound = create_audio("res://assets/novos_audios/seco_3d_power.mp3", -2.0)
	special_rush_sound = create_audio("res://assets/novos_audios/modo_acelerando.mp3", -3.0)
	combo_music_sting_volume_db = victory_sound.volume_db

func _process(delta:float) -> void:
	if special_active:
		update_pentagram_rotation_input(delta)
		update_effects(delta)
		update_shake(delta)
		update_special_meter_hud()
		update_fighter_transforms()
		update_minion_transforms()
		update_bars()
		if stage_3d:
			stage_3d.update_camera(camera.get_screen_center_position().x)
		queue_redraw()
		return
	update_special_input_buffers(delta)
	if !battle_paused && intro_time <= 0.0 && !leaving && !player_dead && try_start_player_special():
		return
	super._process(delta)
	update_special_meter_hud()

func update_pentagram_rotation_input(delta:float) -> void:
	var unscaled_delta = delta / maxf(Engine.time_scale, 0.001)
	if !pentagram_rotation_enabled:
		if pentagram_is_near_end:
			pentagram_spin_speed = maxf(pentagram_spin_speed, pentagram_peak_speed)
			if special_overlay:
				special_overlay.call("add_pentagram_rotation", 0.0, pentagram_charge, 0.0, pentagram_spin_speed, pentagram_spin_direction)
		return
	var stick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var right_stick = Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if right_stick.length() > stick.length():
		stick = right_stick
	pentagram_input_activity = maxf(0.0, pentagram_input_activity - unscaled_delta * 1.8)
	if stick.length() < 0.52:
		pentagram_last_stick = Vector2.ZERO
		if pentagram_is_near_end:
			pentagram_spin_speed = maxf(pentagram_spin_speed, pentagram_peak_speed)
		else:
			pentagram_spin_speed = maxf(PENTAGRAM_BASE_SPEED, pentagram_spin_speed - unscaled_delta * 0.55)
		var speed_ratio = clampf((pentagram_spin_speed - PENTAGRAM_BASE_SPEED) / (PENTAGRAM_MAX_SPEED - PENTAGRAM_BASE_SPEED), 0.0, 1.0)
		pentagram_charge = maxf(pentagram_charge, speed_ratio) if pentagram_is_near_end else speed_ratio
		if special_overlay:
			special_overlay.call("add_pentagram_rotation", 0.0, pentagram_charge, pentagram_input_activity, pentagram_spin_speed, pentagram_spin_direction)
		return
	stick = stick.normalized()
	if pentagram_last_stick.length() > 0.5:
		var angle_delta = wrapf(stick.angle() - pentagram_last_stick.angle(), -PI, PI)
		if absf(angle_delta) >= 0.012 && absf(angle_delta) <= 1.25:
			var rotation_amount = absf(angle_delta)
			pentagram_spin_direction = 1.0 if angle_delta >= 0.0 else -1.0
			var input_rate = rotation_amount / maxf(unscaled_delta, 0.001)
			
			var current_ratio = clampf((pentagram_spin_speed - PENTAGRAM_BASE_SPEED) / (PENTAGRAM_MAX_SPEED - PENTAGRAM_BASE_SPEED), 0.0, 1.0)
			var resistance = 1.0 - pow(current_ratio, 1.6) * 0.62
			var rate_factor = clampf(input_rate / 7.5, 0.4, 1.6)
			var accel = rotation_amount * 0.14 * resistance * rate_factor
			
			pentagram_spin_speed = clampf(pentagram_spin_speed + accel, PENTAGRAM_BASE_SPEED, PENTAGRAM_MAX_SPEED)
			pentagram_peak_speed = maxf(pentagram_peak_speed, pentagram_spin_speed)
			
			var speed_ratio = clampf((pentagram_spin_speed - PENTAGRAM_BASE_SPEED) / (PENTAGRAM_MAX_SPEED - PENTAGRAM_BASE_SPEED), 0.0, 1.0)
			pentagram_charge = speed_ratio
			pentagram_input_activity = 1.0
			if special_overlay:
				special_overlay.call("add_pentagram_rotation", angle_delta, pentagram_charge, pentagram_input_activity, pentagram_spin_speed, pentagram_spin_direction)
	pentagram_last_stick = stick

func resolve_player_hit(kick:bool) -> void:
	var previous_combo = combo
	super.resolve_player_hit(kick)
	if combo > previous_combo:
		special_hits = mini(SPECIAL_METER_MAX, special_hits + 1)
		if combo % 5 == 0:
			limit_combo_music_sting()
		update_special_meter_hud()

func limit_combo_music_sting() -> void:
	combo_music_sting_token += 1
	var active_token = combo_music_sting_token
	if !victory_sound:
		return
	if enemy_dead:
		victory_sound.pitch_scale = 1.0
		victory_sound.volume_db = combo_music_sting_volume_db
		return
	await get_tree().create_timer(COMBO_MUSIC_STING_DURATION, true, false, true).timeout
	if active_token != combo_music_sting_token || !is_instance_valid(victory_sound):
		return
	if enemy_dead:
		victory_sound.pitch_scale = 1.0
		victory_sound.volume_db = combo_music_sting_volume_db
		return
	var fade = create_tween()
	fade.tween_property(victory_sound, "volume_db", -24.0, 0.16)
	await fade.finished
	if active_token != combo_music_sting_token || !is_instance_valid(victory_sound):
		return
	victory_sound.stop()
	victory_sound.pitch_scale = 1.0
	victory_sound.volume_db = combo_music_sting_volume_db

func build_special_hud() -> void:
	special_meter = ProgressBar.new()
	special_meter.position = Vector2(381, 615)
	special_meter.size = Vector2(390, 19)
	special_meter.min_value = 0.0
	special_meter.max_value = SPECIAL_METER_MAX
	special_meter.value = 0.0
	special_meter.show_percentage = false
	special_meter.z_index = 120
	var meter_background = StyleBoxFlat.new()
	meter_background.bg_color = Color(0.015, 0.02, 0.05, 0.94)
	meter_background.border_color = Color(0.35, 0.75, 1.0, 0.82)
	meter_background.set_border_width_all(2)
	meter_background.set_corner_radius_all(7)
	var meter_fill = StyleBoxFlat.new()
	meter_fill.bg_color = Color("b517ff")
	meter_fill.set_corner_radius_all(5)
	special_meter.add_theme_stylebox_override("background", meter_background)
	special_meter.add_theme_stylebox_override("fill", meter_fill)
	hud_canvas.add_child(special_meter)

	special_meter_label = Label.new()
	special_meter_label.position = Vector2(381, 586)
	special_meter_label.size = Vector2(390, 28)
	special_meter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_meter_label.add_theme_font_size_override("font_size", 18)
	special_meter_label.add_theme_color_override("font_color", Color("d8f3ff"))
	special_meter_label.add_theme_color_override("font_outline_color", Color("090014"))
	special_meter_label.add_theme_constant_override("outline_size", 5)
	special_meter_label.z_index = 121
	hud_canvas.add_child(special_meter_label)

	special_prompt_label = Label.new()
	special_prompt_label.position = Vector2(76, 548)
	special_prompt_label.size = Vector2(1000, 38)
	special_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	special_prompt_label.add_theme_font_size_override("font_size", 19)
	special_prompt_label.add_theme_color_override("font_color", Color("ffe66d"))
	special_prompt_label.add_theme_color_override("font_outline_color", Color("15001f"))
	special_prompt_label.add_theme_constant_override("outline_size", 6)
	special_prompt_label.z_index = 121
	hud_canvas.add_child(special_prompt_label)

	special_overlay = SpecialOverlay.new()
	special_overlay.z_index = 3500
	hud_canvas.add_child(special_overlay)
	update_special_meter_hud()

func update_special_meter_hud() -> void:
	if !special_meter:
		return
	special_meter.value = special_hits
	special_meter_label.text = tr_text("MEDIDOR DE HITS  %02d / %d", "HIT METER  %02d / %d") % [special_hits, SPECIAL_METER_MAX]
	var fill:StyleBoxFlat = special_meter.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	if special_hits >= SPECIAL_RUSH_THRESHOLD:
		fill.bg_color = Color("ff1744")
		special_prompt_label.text = tr_text("👊 Q/Y + 🦶 W/B: PENTAGRAM FORCE   |   🦶 W/B + 💨 ESPAÇO/A: MAYCON RUSH", "👊 Q/Y + 🦶 W/B: PENTAGRAM FORCE   |   🦶 W/B + 💨 SPACE/A: MAYCON RUSH")
		special_prompt_label.add_theme_color_override("font_color", Color("fff176"))
	elif special_hits >= SPECIAL_PENTAGRAM_THRESHOLD:
		fill.bg_color = Color("ff2a8b")
		special_prompt_label.text = tr_text("ESPECIAL PRONTO:  👊 Q/Y + 🦶 W/B  —  PENTAGRAM FORCE", "SPECIAL READY:  👊 Q/Y + 🦶 W/B  —  PENTAGRAM FORCE")
		special_prompt_label.add_theme_color_override("font_color", Color("ff80bf"))
	else:
		fill.bg_color = Color("8f2cff")
		special_prompt_label.text = tr_text("15 HITS: 👊 + 🦶   •   20 HITS: 🦶 + 💨", "15 HITS: 👊 + 🦶   •   20 HITS: 🦶 + 💨")
		special_prompt_label.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0, 0.82))
	special_meter.add_theme_stylebox_override("fill", fill)
	if special_hits >= SPECIAL_PENTAGRAM_THRESHOLD:
		var pulse = 0.72 + sin(Time.get_ticks_msec() * 0.009) * 0.28
		special_prompt_label.modulate = Color(1.0, 1.0, 1.0, pulse)
	else:
		special_prompt_label.modulate = Color.WHITE

func try_start_player_special() -> bool:
	var punch_kick_requested = special_punch_buffer > 0.0 && special_kick_buffer > 0.0
	var kick_dash_requested = special_kick_buffer > 0.0 && special_dash_buffer > 0.0
	if special_hits >= SPECIAL_RUSH_THRESHOLD && kick_dash_requested:
		clear_special_input_buffers()
		var rush_target = find_rush_target()
		if rush_target.is_empty():
			flash_no_rush_target()
			return true
		start_maycon_rush(rush_target)
		return true
	if special_hits >= SPECIAL_PENTAGRAM_THRESHOLD && punch_kick_requested:
		clear_special_input_buffers()
		start_pentagram_force()
		return true
	return false

func update_special_input_buffers(delta:float) -> void:
	special_punch_buffer = maxf(0.0, special_punch_buffer - delta)
	special_kick_buffer = maxf(0.0, special_kick_buffer - delta)
	special_dash_buffer = maxf(0.0, special_dash_buffer - delta)
	if Input.is_action_pressed("key_q"):
		special_punch_buffer = 0.18
	if Input.is_action_pressed("key_w"):
		special_kick_buffer = 0.18
	if Input.is_action_pressed("ui_accept"):
		special_dash_buffer = 0.18

func clear_special_input_buffers() -> void:
	special_punch_buffer = 0.0
	special_kick_buffer = 0.0
	special_dash_buffer = 0.0

func prepare_player_special() -> void:
	combo_music_sting_token += 1
	pentagram_rotation_enabled = false
	pentagram_charge = 0.0
	pentagram_accumulated_rotation = 0.0
	pentagram_last_stick = Vector2.ZERO
	pentagram_input_activity = 0.0
	if victory_sound && !enemy_dead:
		victory_sound.stop()
		victory_sound.pitch_scale = 1.0
		victory_sound.volume_db = combo_music_sting_volume_db
	special_active = true
	special_hits = 0
	player_attack_time = 0.0
	dodge_time = 0.0
	dodge_cooldown = 0.0
	player_invulnerability = 99.0
	enemy_attack_time = 0.0
	enemy_hit_pending = false
	clear_power_projectiles()
	for minion_index in minions.size():
		var minion = minions[minion_index]
		if minion.dead:
			continue
		minion.attack_time = 0.0
		minion.hit_pending = false
		minion.is_casting_wave = false
		play_if_changed(minion.sprite, "idle")
		minions[minion_index] = minion
	update_special_meter_hud()

func start_pentagram_force() -> void:
	if special_active || special_hits < SPECIAL_PENTAGRAM_THRESHOLD:
		return
	prepare_player_special()
	var previous_status = status_label.text
	var previous_zoom = camera.zoom
	var previous_camera_position = camera.position
	status_label.text = "PENTAGRAM FORCE"
	combo_label.text = ""
	Engine.time_scale = 0.28
	battle_song.pitch_scale = 0.72
	if special_charge_sound:
		special_charge_sound.pitch_scale = 0.82
		special_charge_sound.play()
	pentagram_spin_speed = PENTAGRAM_BASE_SPEED
	pentagram_peak_speed = PENTAGRAM_BASE_SPEED
	pentagram_spin_direction = 1.0
	pentagram_is_near_end = false
	pentagram_accumulated_rotation = 0.0
	pentagram_charge = 0.0
	pentagram_last_stick = Vector2.ZERO
	pentagram_input_activity = 0.0
	var portrait = load("res://assets/novas_imagens/3d_cenarios/maycon_on_3d/maycon_icon.png") as Texture2D
	special_overlay.call("start_pentagram", portrait, tr_text("GIRE O ANALÓGICO", "ROTATE THE ANALOG STICK"))
	camera.zoom = Vector2(0.92, 0.92)
	camera.position = Vector2(clampf((player_position.x + enemy_position.x) * 0.5, 576.0, ARENA_WIDTH - 576.0), 324.0)
	player.play("attack_punch")
	shake(8.0, 0.5)

	await get_tree().create_timer(1.14, true, false, true).timeout
	pentagram_rotation_enabled = true
	status_label.text = tr_text("GIRE O ANALÓGICO!", "ROTATE THE ANALOG STICK!")
	var charge_elapsed = 0.0
	var applied_pulses = 0
	while charge_elapsed < PENTAGRAM_CHARGE_DURATION:
		if !is_inside_tree():
			return
		await get_tree().create_timer(0.1, true, false, true).timeout
		charge_elapsed += 0.1
		if !pentagram_is_near_end && (charge_elapsed >= (PENTAGRAM_CHARGE_DURATION - 1.8) || pentagram_charge >= 0.96):
			pentagram_is_near_end = true
			if special_overlay:
				special_overlay.call("set_near_end", true)
		var target_pulses = int(floor(pentagram_charge * float(PENTAGRAM_PULSE_COUNT) + 0.001))
		if applied_pulses < target_pulses:
			var pulse_progress = float(applied_pulses + 1) / float(PENTAGRAM_PULSE_COUNT)
			special_overlay.call("register_pentagram_hit", 0.034 + pulse_progress * 0.024)
			apply_pentagram_damage_pulse(applied_pulses, false)
			if special_charge_sound:
				special_charge_sound.pitch_scale = lerpf(0.82, 1.16, pentagram_charge)
			shake(lerpf(3.5, 10.0, pentagram_charge), 0.2)
			applied_pulses += 1

	pentagram_rotation_enabled = false
	pentagram_is_near_end = true
	if special_overlay:
		special_overlay.call("set_near_end", true)
	pentagram_last_stick = Vector2.ZERO
	var final_target_pulses = int(floor(pentagram_charge * float(PENTAGRAM_PULSE_COUNT) + 0.001))
	while applied_pulses < final_target_pulses:
		if !is_inside_tree():
			return
		var pulse_progress = float(applied_pulses + 1) / float(PENTAGRAM_PULSE_COUNT)
		special_overlay.call("register_pentagram_hit", 0.034 + pulse_progress * 0.024)
		apply_pentagram_damage_pulse(applied_pulses, false)
		shake(lerpf(3.5, 10.0, pentagram_charge), 0.16)
		applied_pulses += 1
		await get_tree().create_timer(0.09, true, false, true).timeout

	if is_inside_tree():
		if pentagram_charge > 0.01:
			special_overlay.call("register_pentagram_hit", 0.22 * pentagram_charge)
			apply_pentagram_damage_pulse(PENTAGRAM_PULSE_COUNT, true, pentagram_charge)
		special_overlay.call("start_pentagram_explosion")
		spawn_blood_explosion(Vector2(camera.position.x, player_position.y - 105.0), 96)
		shake(28.0, 1.0)
		Input.start_joy_vibration(0, 0.9, 1.0, 0.8)
		await get_tree().create_timer(1.25, true, false, true).timeout
	finish_player_special(previous_status, previous_zoom, previous_camera_position)
	resolve_pentagram_deaths()

func apply_pentagram_damage_pulse(pulse_index:int, finisher:bool, strength:float = 1.0) -> void:
	var hit_direction = 1.0 if pulse_index % 2 == 0 else -1.0
	for minion_index in minions.size():
		var minion = minions[minion_index]
		if minion.dead:
			continue
		var damage = maxf(1.0, minion.max_hp * ((0.39 * strength) if finisher else 0.035))
		minion.hp = maxf(0.0, minion.hp - damage)
		minion.hit_pending = false
		minion.attack_time = 0.0
		minion.sprite.play("pain")
		spawn_blood(minion.position + Vector2(0, -28), 24 if finisher else 5, hit_direction)
		spawn_impact(minion.position + Vector2(0, -26), Color("70e7ff" if pulse_index % 2 == 0 else "ff2a8b"), hit_direction)
		minions[minion_index] = minion

	if !enemy_dead:
		var boss_damage = maxf(1.0, enemy_max_hp * ((0.125 * strength) if finisher else 0.0125))
		enemy_hp = maxf(0.0, enemy_hp - boss_damage)
		enemy_hit_pending = false
		enemy_attack_time = 0.0
		enemy.play("pain")
		spawn_blood(enemy_position + Vector2(0, -45), 34 if finisher else 7, hit_direction)
		spawn_impact(enemy_position + Vector2(0, -42), Color("fff176" if finisher else "b517ff"), hit_direction)
		if hit_sound:
			hit_sound.pitch_scale = lerpf(0.78, 1.25, float(pulse_index) / float(PENTAGRAM_PULSE_COUNT))
			hit_sound.play()

func resolve_pentagram_deaths() -> void:
	if enemy_hp <= 0.0 && !enemy_dead:
		defeat_enemy()
		return
	for minion_index in minions.size():
		var minion = minions[minion_index]
		if !minion.dead && minion.hp <= 0.0:
			defeat_minion(minion_index)

func find_rush_target() -> Dictionary:
	var closest_target:Dictionary = {}
	var closest_distance = INF
	if !enemy_dead:
		var enemy_offset = enemy_position - player_position
		if enemy_offset.x * player_facing >= 0.0:
			closest_distance = enemy_offset.length()
			closest_target = {"kind":"enemy", "index":-1}
	for minion_index in minions.size():
		var minion = minions[minion_index]
		if minion.dead:
			continue
		var minion_offset:Vector2 = minion.position - player_position
		var distance = minion_offset.length()
		if minion_offset.x * player_facing >= 0.0 && distance < closest_distance:
			closest_distance = distance
			closest_target = {"kind":"minion", "index":minion_index}
	return closest_target

func get_rush_target_position(target:Dictionary) -> Vector2:
	if target.get("kind", "") == "enemy":
		return enemy_position
	var minion_index = int(target.get("index", -1))
	if minion_index >= 0 && minion_index < minions.size():
		return minions[minion_index].position
	return player_position + Vector2(player_facing * 100.0, 0.0)

func is_rush_target_valid(target:Dictionary) -> bool:
	if target.get("kind", "") == "enemy":
		return !enemy_dead
	var minion_index = int(target.get("index", -1))
	return minion_index >= 0 && minion_index < minions.size() && !minions[minion_index].dead

func start_maycon_rush(target:Dictionary) -> void:
	if special_active || special_hits < SPECIAL_RUSH_THRESHOLD || !is_rush_target_valid(target):
		return
	prepare_player_special()
	var previous_status = status_label.text
	var previous_zoom = camera.zoom
	var previous_camera_position = camera.position
	status_label.text = tr_text("FÚRIA DE 50 GOLPES", "50-HIT MAYCON RUSH")
	combo_label.text = ""
	if special_rush_sound:
		special_rush_sound.pitch_scale = 1.0
		special_rush_sound.play()
	special_overlay.call("start_rush")

	var target_position = get_rush_target_position(target)
	player_facing = signf(target_position.x - player_position.x)
	if player_facing == 0.0:
		player_facing = 1.0
	player.flip_h = player_facing < 0.0
	var approach_start = player_position
	var approach_finish = Vector2(target_position.x - player_facing * 92.0, target_position.y)
	for approach_step in 6:
		var approach_progress = float(approach_step + 1) / 6.0
		player_position = approach_start.lerp(approach_finish, approach_progress)
		spawn_player_ghost()
		camera.position = player_position.lerp(target_position, 0.5)
		camera.zoom = Vector2.ONE.lerp(Vector2(1.72, 1.72), approach_progress)
		await get_tree().create_timer(0.035, true, false, true).timeout

	for hit_index in 50:
		if !is_inside_tree() || !is_rush_target_valid(target):
			break
		var progress = float(hit_index + 1) / 50.0
		target_position = get_rush_target_position(target)
		player_position = Vector2(target_position.x - player_facing * (84.0 + sin(hit_index * 2.2) * 12.0), target_position.y + sin(hit_index * 1.7) * 5.0)
		player.play("attack_punch" if hit_index % 2 == 0 else "attack_kick")
		special_overlay.set("hit_count", hit_index + 1)
		special_overlay.set("energy", progress)
		spawn_impact(target_position + Vector2(randf_range(-18.0, 18.0), randf_range(-70.0, -18.0)), Color("ffd166" if hit_index % 2 == 0 else "ff2a8b"), player_facing)
		spawn_blood(target_position + Vector2(0, -38), 3 if hit_index < 36 else 5, player_facing)
		if hit_index % 3 == 0:
			spawn_player_ghost()
		if hit_index % 2 == 0 && hit_sound:
			hit_sound.pitch_scale = lerpf(0.9, 1.52, progress)
			hit_sound.play()
		if hit_index % 5 == 0:
			shake(lerpf(4.0, 12.0, progress), 0.12)
		var hit_delay = lerpf(0.078, 0.018, pow(progress, 0.72))
		await get_tree().create_timer(hit_delay, true, false, true).timeout

	if is_inside_tree() && is_rush_target_valid(target):
		apply_maycon_rush_damage(target)
		special_overlay.set("energy", 1.0)
		spawn_blood_explosion(get_rush_target_position(target) + Vector2(0, -40), 72)
		shake(25.0, 0.76)
		Input.start_joy_vibration(0, 1.0, 1.0, 0.65)
		await get_tree().create_timer(0.52, true, false, true).timeout
	finish_player_special(previous_status, previous_zoom, previous_camera_position)

func apply_maycon_rush_damage(target:Dictionary) -> void:
	if target.get("kind", "") == "enemy" && !enemy_dead:
		enemy_hp = maxf(0.0, enemy_hp - enemy_max_hp * 0.6)
		enemy.play("pain")
		if enemy_hp <= 0.0:
			defeat_enemy()
		return
	var minion_index = int(target.get("index", -1))
	if minion_index < 0 || minion_index >= minions.size():
		return
	var minion = minions[minion_index]
	if minion.dead:
		return
	minion.hp = maxf(0.0, minion.hp - minion.max_hp * 0.6)
	minion.sprite.play("pain")
	minions[minion_index] = minion
	if minion.hp <= 0.0:
		defeat_minion(minion_index)

func finish_player_special(previous_status:String, previous_zoom:Vector2, previous_camera_position:Vector2) -> void:
	pentagram_rotation_enabled = false
	pentagram_last_stick = Vector2.ZERO
	pentagram_spin_speed = 0.0
	pentagram_peak_speed = 0.0
	pentagram_spin_direction = 1.0
	pentagram_is_near_end = false
	pentagram_accumulated_rotation = 0.0
	pentagram_charge = 0.0
	Engine.time_scale = 1.0
	player_invulnerability = 0.45
	player_attack_time = 0.0
	battle_song.pitch_scale = 1.0
	if special_charge_sound:
		special_charge_sound.stop()
	if special_rush_sound:
		special_rush_sound.stop()
	if special_overlay:
		special_overlay.call("finish")
	camera.zoom = previous_zoom
	camera.position = previous_camera_position
	if !enemy_dead:
		status_label.text = previous_status
	play_if_changed(player, "idle_right")
	special_active = false
	update_special_meter_hud()

func flash_no_rush_target() -> void:
	var previous_status = status_label.text
	status_label.text = tr_text("NENHUM INIMIGO À FRENTE", "NO ENEMY AHEAD")
	status_label.add_theme_color_override("font_color", Color("ff6b6b"))
	await get_tree().create_timer(0.85, true, false, true).timeout
	if !special_active && !enemy_dead:
		status_label.text = previous_status
		status_label.add_theme_color_override("font_color", Color("ffd166"))

func _exit_tree() -> void:
	combo_music_sting_token += 1
	pentagram_rotation_enabled = false
	pentagram_last_stick = Vector2.ZERO
	pentagram_spin_speed = 0.0
	pentagram_peak_speed = 0.0
	pentagram_is_near_end = false
	Engine.time_scale = 1.0
	if victory_sound:
		victory_sound.pitch_scale = 1.0
		victory_sound.volume_db = combo_music_sting_volume_db
	if special_overlay:
		special_overlay.call("finish")
	super._exit_tree()
