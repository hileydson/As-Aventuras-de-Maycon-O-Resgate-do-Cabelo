extends Control

var health:float = 100.0
var progress:float = 0.0
var pentagram_charge:float = 0.0
var speed_factor:float = 0.0
var power_time:float = 0.0
var cooldown:float = 0.0
var player_screen:Vector2 = Vector2.ZERO
var ending_time:float = 0.0
var time:float = 0.0
var dash_glow:float = 0.0
var power_flash:float = 0.0
var hurt_flash:float = 0.0
var combo:int = 0
var combo_time:float = 0.0
var combo_position:Vector2 = Vector2.ZERO
var damage_value:int = 0
var explosion:float = -1.0
var death:bool = false
var paused_local:bool = false
var droplets:Array[Dictionary] = []

func set_state(new_health:float, new_progress:float, new_charge:float, new_cooldown:float, new_ending_time:float, new_player_screen:Vector2 = Vector2.ZERO, new_speed:float = 0.0, new_power_time:float = 0.0) -> void:
	health = new_health
	progress = new_progress
	pentagram_charge = new_charge
	speed_factor = new_speed
	power_time = new_power_time
	cooldown = new_cooldown
	player_screen = new_player_screen
	ending_time = new_ending_time
	queue_redraw()

func dash_flash() -> void:
	dash_glow = 0.7

func activate_power() -> void:
	power_flash = 1.0
	spawn_droplets(Vector2(size.x - 112.0, 112.0), 28)
	queue_redraw()

func set_pause(paused:bool) -> void:
	paused_local = paused
	queue_redraw()

func show_hit(where:Vector2, hits:int, damage:float, player_position:Vector2) -> void:
	combo = hits
	combo_position = where
	damage_value = int(round(damage))
	combo_time = 1.35
	hurt_flash = 1.0
	spawn_droplets(where, 65 + int(damage))
	spawn_droplets(player_position, 55)
	queue_redraw()

func explode_pentagram() -> void:
	explosion = 0.0
	spawn_droplets(Vector2(size.x - 105.0, 112.0), 84)
	queue_redraw()

func show_death() -> void:
	death = true
	hurt_flash = 1.0
	spawn_droplets(size * 0.5, 48)

func spawn_droplets(origin:Vector2, amount:int) -> void:
	for i in amount:
		var direction := Vector2.from_angle(randf() * TAU)
		droplets.append({"position":origin, "velocity":direction * randf_range(65.0, 500.0), "life":randf_range(0.45, 1.3), "radius":randf_range(2.0, 8.0)})

func _process(delta:float) -> void:
	time += delta
	dash_glow = maxf(0.0, dash_glow - delta * 2.2)
	power_flash = maxf(0.0, power_flash - delta * 0.85)
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.8)
	combo_time = maxf(0.0, combo_time - delta)
	if explosion >= 0.0:
		explosion += delta
	for i in range(droplets.size() - 1, -1, -1):
		var drop:Dictionary = droplets[i]
		drop["life"] = float(drop.life) - delta
		drop["position"] = drop.position + drop.velocity * delta
		drop["velocity"] = drop.velocity * (1.0 - delta * 1.1) + Vector2(0, 80.0) * delta
		if drop.life <= 0.0:
			droplets.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var width:float = size.x
	var height:float = size.y
	var font:Font = ThemeDB.fallback_font
	var center := Vector2(width - 112.0, 112.0)
	# The frame, shaft streaks and blood stay at the edge of the action.
	draw_rect(Rect2(0, 0, width, 6), Color(0.35, 0.025, 0.065, 0.9), true)
	draw_rect(Rect2(0, height - 5, width, 5), Color(0.04, 0.25, 0.32, 0.7), true)
	for i in 36:
		var seed:float = float(i) * 19.37
		var x:float = fposmod(seed * 47.0, width)
		var y:float = fposmod(time * (730.0 + speed_factor * 750.0 + float(i % 5) * 135.0) + seed * 31.0, height + 200.0) - 100.0
		var alpha:float = 0.09 + float(i % 4) * 0.03
		draw_line(Vector2(x, y), Vector2(x + (x - width * 0.5) * 0.1, y - 75.0 - float(i % 3) * 29.0), Color(0.45, 0.78, 1.0, alpha), 2.0)
	if player_screen != Vector2.ZERO && !death:
		for i in 14:
			var phase:float = fposmod(time * (2.4 + float(i % 3) * 0.25) + float(i) * 0.217, 1.0)
			var x_offset:float = sin(float(i) * 8.73) * 39.0
			var across:float = sin(float(i) * 2.93) * 15.0
			var start:Vector2 = player_screen + Vector2(x_offset, -72.0 + phase * 150.0)
			var streak_alpha:float = (0.25 + dash_glow * 0.25) * sin(phase * PI)
			draw_line(start, start + Vector2(across, -28.0 - float(i % 4) * 9.0), Color(0.58, 0.91, 1.0, streak_alpha), 2.0 if i % 3 else 3.0)
	draw_rect(Rect2(24, 23, 286, 80), Color(0.012, 0.018, 0.03, 0.78), true)
	draw_rect(Rect2(24, 23, 286, 80), Color(0.31, 0.67, 0.8, 0.65), false, 2.0)
	draw_string(font, Vector2(38, 51), tr("WELL_HEALTH"), HORIZONTAL_ALIGNMENT_LEFT, 180, 20, Color(1.0, 0.91, 0.87))
	draw_string(font, Vector2(239, 51), "%d%%" % int(ceil(health)), HORIZONTAL_ALIGNMENT_RIGHT, 55, 20, Color(1.0, 0.91, 0.87))
	draw_rect(Rect2(38, 64, 255, 24), Color(0.12, 0.025, 0.035), true)
	draw_rect(Rect2(42, 68, 247.0 * clampf(health / 100.0, 0.0, 1.0), 16), Color(0.72, 0.025, 0.09).lerp(Color(1.0, 0.24, 0.13), health / 100.0), true)
	for i in 10:
		var nx:float = 38.0 + float(i) * 25.5
		draw_line(Vector2(nx, 64), Vector2(nx, 88), Color(0.02, 0.01, 0.018, 0.45), 1.0)
	var hint_color := Color(0.65, 0.84, 0.94, 0.9)
	draw_string(font, Vector2(25, height - 45), tr("WELL_CONTROLS"), HORIZONTAL_ALIGNMENT_LEFT, width - 50, 17, hint_color)
	draw_rect(Rect2(24, height - 31, width - 48.0, 17), Color(0.012, 0.02, 0.035, 0.82), true)
	draw_rect(Rect2(28, height - 27, (width - 56.0) * progress, 9), Color(0.12, 0.72, 0.92).lerp(Color(0.97, 0.15, 0.23), speed_factor), true)
	var marker_x:float = 28.0 + (width - 56.0) * progress
	draw_circle(Vector2(marker_x, height - 22.5), 8.0, Color(0.82, 0.97, 1.0))
	draw_circle(Vector2(width - 28.0, height - 22.5), 5.0, Color(1.0, 0.22, 0.26))
	if cooldown > 0.0:
		draw_rect(Rect2(25, height - 11, 176.0 * (1.0 - cooldown / 0.6), 3), Color(0.25, 0.78, 0.9), true)
	draw_pentagram(center, pentagram_charge)
	if pentagram_charge >= 1.0 && power_time <= 0.0:
		draw_string(font, center + Vector2(-90.0, 91.0), tr("WELL_POWER_READY"), HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color(1.0, 0.82, 0.45, 0.7 + sin(time * 8.0) * 0.3))
	if power_time > 0.0:
		var glow:float = 0.08 + sin(time * 16.0) * 0.025
		draw_rect(Rect2(0, 0, width, height), Color(0.12, 0.68, 0.98, glow), true)
		draw_arc(player_screen, 95.0 + sin(time * 13.0) * 12.0, 0.0, TAU, 64, Color(0.35, 0.95, 1.0, 0.58), 5.0)
		draw_string(font, center + Vector2(-75.0, 91.0), tr("WELL_INVULNERABLE"), HORIZONTAL_ALIGNMENT_CENTER, 150, 18, Color(0.49, 0.94, 1.0))
	if power_flash > 0.0:
		draw_arc(size * 0.5, 80.0 + (1.0 - power_flash) * 520.0, 0.0, TAU, 64, Color(0.3, 0.93, 1.0, power_flash * 0.76), 7.0)
		draw_rect(Rect2(0, 0, width, height), Color(0.24, 0.85, 1.0, power_flash * 0.16), true)
	if hurt_flash > 0.0:
		draw_rect(Rect2(0, 0, width, height), Color(0.75, 0.0, 0.04, hurt_flash * 0.24), true)
	if combo_time > 0.0:
		var combo_alpha:float = minf(1.0, combo_time * 1.5)
		var popup_pos:Vector2 = combo_position + Vector2(-65, -72 - (1.35 - combo_time) * 35.0)
		draw_string(font, popup_pos, tr("WELL_HIT"), HORIZONTAL_ALIGNMENT_CENTER, 130, 30, Color(1.0, 0.15, 0.16, combo_alpha))
		draw_string(font, popup_pos + Vector2(9, 26), "-%d" % damage_value, HORIZONTAL_ALIGNMENT_CENTER, 110, 21, Color(1.0, 0.85, 0.8, combo_alpha))
	for drop in droplets:
		var drop_pos:Vector2 = drop.position
		var alpha:float = clampf(float(drop.life), 0.0, 1.0)
		draw_line(drop_pos, drop_pos - (drop.velocity as Vector2) * 0.045, Color(0.53, 0.0, 0.025, alpha * 0.62), maxf(1.0, float(drop.radius) * 0.55))
		draw_circle(drop_pos, float(drop.radius) * alpha, Color(0.72, 0.005, 0.045, alpha * 0.82))
		draw_circle(drop_pos + Vector2(-1.5, -1.5), maxf(1.0, float(drop.radius) * 0.32 * alpha), Color(1.0, 0.09, 0.1, alpha))
	if death:
		draw_rect(Rect2(0, 0, width, height), Color(0.13, 0.0, 0.02, clampf(ending_time / 1.25, 0.0, 1.0)), true)
	if explosion >= 0.0:
		draw_rect(Rect2(0, 0, width, height), Color(0.02, 0.0, 0.015, clampf((explosion - 0.72) / 1.45, 0.0, 1.0)), true)
	if paused_local:
		draw_rect(Rect2(0, 0, width, height), Color(0.008, 0.015, 0.03, 0.8), true)
		draw_string(font, Vector2(width * 0.5 - 200.0, height * 0.5 - 14.0), tr("MENU_PAUSE"), HORIZONTAL_ALIGNMENT_CENTER, 400, 46, Color(1.0, 0.83, 0.42))
		draw_string(font, Vector2(width * 0.5 - 290.0, height * 0.5 + 34.0), tr("MENU_PAUSE_HINT"), HORIZONTAL_ALIGNMENT_CENTER, 580, 21, Color(0.83, 0.92, 1.0))

func draw_pentagram(center:Vector2, energy:float) -> void:
	var pulse:float = 1.0 + sin(time * (3.0 + speed_factor * 10.0 + energy * 5.0)) * (0.035 + speed_factor * 0.09 + energy * 0.07)
	var radius:float = 55.0 * pulse
	var rotation_angle:float = -PI * 0.5 + time * (0.12 + speed_factor * 0.5 + energy * 0.3)
	var visibility:float = 1.0
	if explosion >= 0.0:
		visibility = 1.0 - smoothstep(0.06, 0.66, explosion)
		radius *= 1.0 + minf(explosion, 0.7) * 1.4
	var blood_color := Color(1.0, 0.04, 0.17, visibility)
	for i in range(3, 0, -1):
		draw_arc(center, radius + float(i) * 8.0, 0.0, TAU, 64, Color(0.9, 0.015, 0.09, visibility * (0.05 + energy * 0.06)), 7.0)
	draw_arc(center, radius + 9.0, rotation_angle, rotation_angle + TAU * energy, 60, Color(0.25, 0.86, 1.0, visibility * 0.78), 4.0)
	draw_arc(center, radius, 0.0, TAU, 64, blood_color, 4.0)
	var points:PackedVector2Array = []
	for i in 5:
		points.append(center + Vector2.from_angle(rotation_angle + float(i) * TAU / 5.0) * radius)
	var order := [0, 2, 4, 1, 3, 0]
	var star:PackedVector2Array = []
	for index in order:
		star.append(points[index])
	draw_polyline(star, Color(0.16, 0.0, 0.04, visibility * 0.95), 13.0, true)
	draw_polyline(star, Color(1.0, 0.045, 0.2, visibility), 5.0, true)
	draw_polyline(star, Color(1.0, 0.72, 0.34, visibility * 0.72), 1.5, true)
	for point in points:
		draw_circle(point, 3.0 + energy * 2.0, Color(1.0, 0.88, 0.8, visibility))
	for i in int(energy * 28.0):
		var angle:float = float(i) * 2.399963 + rotation_angle
		var distance:float = radius * (0.19 + absf(sin(float(i) * 1.7)) * 0.66)
		var stain:Vector2 = center + Vector2.from_angle(angle) * distance
		draw_circle(stain, 2.0 + float(i % 4), Color(0.75, 0.0, 0.035, visibility * 0.76))
