extends Control

var health:float = 100.0
var dodges:int = 0
var target:int = 20
var cooldown:float = 0.0
var threat_z:float = -1.0
var threat_position:Vector2 = Vector2.ZERO
var ending_time:float = 0.0
var time:float = 0.0
var dodge_flash:float = 0.0
var dash_glow:float = 0.0
var hurt_flash:float = 0.0
var combo:int = 0
var combo_time:float = 0.0
var combo_position:Vector2 = Vector2.ZERO
var damage_value:int = 0
var explosion:float = -1.0
var death:bool = false
var droplets:Array[Dictionary] = []

func set_state(new_health:float, new_dodges:int, new_target:int, new_cooldown:float, new_threat_z:float, new_ending_time:float, new_threat_position:Vector2 = Vector2.ZERO) -> void:
	health = new_health
	dodges = new_dodges
	target = new_target
	cooldown = new_cooldown
	threat_z = new_threat_z
	threat_position = new_threat_position
	ending_time = new_ending_time
	queue_redraw()

func dash_flash() -> void:
	dash_glow = 0.7

func show_dodge(count:int, total:int) -> void:
	dodges = count
	target = total
	dodge_flash = 1.0
	spawn_droplets(Vector2(size.x - 105.0, 112.0), 12)
	queue_redraw()

func show_hit(where:Vector2, hits:int, damage:float) -> void:
	combo = hits
	combo_position = where
	damage_value = int(round(damage))
	combo_time = 1.35
	hurt_flash = 1.0
	spawn_droplets(where, 34)
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
	dodge_flash = maxf(0.0, dodge_flash - delta * 1.5)
	dash_glow = maxf(0.0, dash_glow - delta * 2.2)
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
	var energy:float = float(dodges) / maxf(1.0, float(target))
	var center := Vector2(width - 112.0, 112.0)
	# The frame, shaft streaks and blood stay at the edge of the action.
	draw_rect(Rect2(0, 0, width, 6), Color(0.35, 0.025, 0.065, 0.9), true)
	draw_rect(Rect2(0, height - 5, width, 5), Color(0.04, 0.25, 0.32, 0.7), true)
	for i in 36:
		var seed:float = float(i) * 19.37
		var x:float = fposmod(seed * 47.0, width)
		var y:float = fposmod(time * (640.0 + float(i % 5) * 110.0) + seed * 31.0, height + 200.0) - 100.0
		var alpha:float = 0.09 + float(i % 4) * 0.03
		draw_line(Vector2(x, y), Vector2(x + (x - width * 0.5) * 0.1, y - 75.0 - float(i % 3) * 29.0), Color(0.45, 0.78, 1.0, alpha), 2.0)
	draw_rect(Rect2(24, 23, 286, 80), Color(0.012, 0.018, 0.03, 0.78), true)
	draw_rect(Rect2(24, 23, 286, 80), Color(0.31, 0.67, 0.8, 0.65), false, 2.0)
	draw_string(font, Vector2(38, 51), tr("WELL_HEALTH"), HORIZONTAL_ALIGNMENT_LEFT, 180, 20, Color(1.0, 0.91, 0.87))
	draw_string(font, Vector2(239, 51), "%d%%" % int(ceil(health)), HORIZONTAL_ALIGNMENT_RIGHT, 55, 20, Color(1.0, 0.91, 0.87))
	draw_rect(Rect2(38, 64, 255, 24), Color(0.12, 0.025, 0.035), true)
	draw_rect(Rect2(42, 68, 247.0 * clampf(health / 100.0, 0.0, 1.0), 16), Color(0.72, 0.025, 0.09).lerp(Color(1.0, 0.24, 0.13), health / 100.0), true)
	for i in 10:
		var nx:float = 38.0 + float(i) * 25.5
		draw_line(Vector2(nx, 64), Vector2(nx, 88), Color(0.02, 0.01, 0.018, 0.45), 1.0)
	draw_rect(Rect2(24, 110, 286, 42), Color(0.012, 0.018, 0.03, 0.75), true)
	draw_string(font, Vector2(39, 138), tr("WELL_DODGES"), HORIZONTAL_ALIGNMENT_LEFT, 194, 19, Color(0.68, 0.87, 1.0))
	draw_string(font, Vector2(215, 139), "%02d / %02d" % [dodges, target], HORIZONTAL_ALIGNMENT_RIGHT, 80, 21, Color(1.0, 0.84, 0.55))
	var hint_color := Color(0.65, 0.84, 0.94, 0.9)
	draw_string(font, Vector2(25, height - 44), tr("WELL_CONTROLS"), HORIZONTAL_ALIGNMENT_LEFT, width - 50, 18, hint_color)
	if cooldown > 0.0:
		draw_rect(Rect2(25, height - 29, 176.0 * (1.0 - cooldown / 0.6), 5), Color(0.25, 0.78, 0.9), true)
	else:
		draw_rect(Rect2(25, height - 29, 176, 5), Color(0.32, 0.97, 0.78, 0.8), true)
	if threat_z < -1.3 && threat_z > -22.0:
		var approach:float = clampf((threat_z + 22.0) / 20.7, 0.0, 1.0)
		var warning_radius:float = 22.0 + approach * 48.0
		var marker_color := Color(1.0, 0.53, 0.17, 0.35 + approach * 0.55)
		draw_arc(threat_position, warning_radius, time * 0.7, time * 0.7 + TAU * 0.72, 40, marker_color, 2.0 + approach * 2.0)
		draw_line(threat_position + Vector2(-10, -warning_radius - 9), threat_position + Vector2(10, -warning_radius - 9), marker_color, 3.0)
		draw_line(threat_position + Vector2(0, -warning_radius - 15), threat_position + Vector2(0, -warning_radius - 3), marker_color, 2.0)
	if threat_z >= -8.0 && threat_z <= -1.3:
		var warning_pulse:float = 0.68 + sin(time * 18.0) * 0.32
		draw_arc(size * 0.5, 94.0 + sin(time * 15.0) * 4.0, 0.0, TAU, 48, Color(0.3, 0.92, 1.0, warning_pulse), 5.0)
		draw_string(font, size * 0.5 + Vector2(-100, 127), tr("WELL_DASH_NOW"), HORIZONTAL_ALIGNMENT_CENTER, 200, 25, Color(0.9, 1.0, 1.0, warning_pulse))
	if dash_glow > 0.0:
		draw_arc(size * 0.5, 118.0 + (1.0 - dash_glow) * 64.0, 0.0, TAU, 48, Color(0.3, 0.96, 1.0, dash_glow * 0.65), 6.0)
	draw_pentagram(center, energy)
	if dodge_flash > 0.0:
		var flash_alpha:float = dodge_flash * dodge_flash
		draw_rect(Rect2(0, 0, width, height), Color(0.32, 0.8, 1.0, flash_alpha * 0.09), true)
		draw_arc(size * 0.5, 145.0 + (1.0 - dodge_flash) * 115.0, 0.0, TAU, 64, Color(0.34, 0.88, 1.0, flash_alpha * 0.72), 4.0)
		draw_string(font, Vector2(width * 0.5 - 250.0, height * 0.28), tr("WELL_PERFECT_DODGE"), HORIZONTAL_ALIGNMENT_CENTER, 500, 34, Color(1.0, 0.91, 0.65, flash_alpha))
		draw_string(font, Vector2(width * 0.5 - 200.0, height * 0.28 + 41.0), "%02d / %02d" % [dodges, target], HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(0.45, 0.95, 1.0, flash_alpha))
	if hurt_flash > 0.0:
		draw_rect(Rect2(0, 0, width, height), Color(0.75, 0.0, 0.04, hurt_flash * 0.24), true)
	if combo_time > 0.0:
		var combo_alpha:float = minf(1.0, combo_time * 1.5)
		var popup_pos:Vector2 = combo_position + Vector2(-65, -72 - (1.35 - combo_time) * 35.0)
		draw_string(font, popup_pos, "%s %d" % [tr("WELL_HIT"), combo], HORIZONTAL_ALIGNMENT_CENTER, 130, 30, Color(1.0, 0.15, 0.16, combo_alpha))
		draw_string(font, popup_pos + Vector2(9, 26), "-%d" % damage_value, HORIZONTAL_ALIGNMENT_CENTER, 110, 21, Color(1.0, 0.85, 0.8, combo_alpha))
	for drop in droplets:
		var drop_pos:Vector2 = drop.position
		var alpha:float = clampf(float(drop.life), 0.0, 1.0)
		draw_circle(drop_pos, float(drop.radius) * alpha, Color(0.72, 0.005, 0.045, alpha * 0.82))
		draw_circle(drop_pos + Vector2(-1.5, -1.5), maxf(1.0, float(drop.radius) * 0.32 * alpha), Color(1.0, 0.09, 0.1, alpha))
	if death:
		draw_rect(Rect2(0, 0, width, height), Color(0.13, 0.0, 0.02, clampf(ending_time / 1.25, 0.0, 1.0)), true)
	if explosion >= 0.0:
		draw_rect(Rect2(0, 0, width, height), Color(0.02, 0.0, 0.015, clampf((explosion - 0.72) / 1.45, 0.0, 1.0)), true)

func draw_pentagram(center:Vector2, energy:float) -> void:
	var pulse:float = 1.0 + sin(time * (3.0 + energy * 7.0)) * (0.035 + energy * 0.11)
	var radius:float = 55.0 * pulse
	var rotation_angle:float = -PI * 0.5 + time * (0.12 + energy * 0.48)
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
	if explosion < 0.0:
		draw_string(ThemeDB.fallback_font, center + Vector2(-42, 7), "%02d" % dodges, HORIZONTAL_ALIGNMENT_CENTER, 84, 24, Color(1.0, 0.9, 0.84, visibility))
