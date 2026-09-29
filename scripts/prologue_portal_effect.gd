extends Node2D

const PORTAL_RADIUS_X := 122.0
const PORTAL_RADIUS_Y := 160.0
const RIFT_POINTS := 96

var intensity := 0.35
var active := false
var elapsed := 0.0
var activation_elapsed := 99.0
var embers: Array[Dictionary] = []
var portal_light: PointLight2D
var abyss_light: PointLight2D
var outer_fire: CPUParticles2D
var inner_fire: CPUParticles2D
var spark_fire: CPUParticles2D
var ash_cloud: CPUParticles2D

func _ready() -> void:
	_build_particles()
	_build_light()
	for index in range(220):
		var angle := TAU * float(index) / 91.0
		embers.append({
			"angle": angle,
			"radius": lerpf(38.0, PORTAL_RADIUS_X * 1.35, float(index % 11) / 10.0),
			"speed": 0.45 + float(index % 9) * 0.11,
			"offset": float(index) * 0.37,
			"size": 1.2 + float(index % 5) * 0.75,
		})
	_apply_intensity()

func activate() -> void:
	active = true
	intensity = 1.0
	activation_elapsed = 0.0
	outer_fire.amount = 340
	inner_fire.amount = 220
	spark_fire.amount = 210
	ash_cloud.amount = 120
	outer_fire.restart()
	inner_fire.restart()
	spark_fire.restart()
	ash_cloud.restart()
	scale = Vector2(0.82, 0.82)
	var rupture := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rupture.tween_property(self, "scale", Vector2(1.08, 1.08), 0.34)
	rupture.tween_property(self, "scale", Vector2.ONE, 0.48)
	_apply_intensity()

func _process(delta: float) -> void:
	elapsed += delta
	activation_elapsed += delta
	if !active:
		intensity = lerpf(intensity, 0.42, delta * 1.6)
	_apply_intensity()
	queue_redraw()

func _build_particles() -> void:
	outer_fire = _create_fire_particles(Color(1.0, 0.12, 0.008, 0.88), PORTAL_RADIUS_X, 190)
	outer_fire.name = "OuterFireParticles"
	outer_fire.scale = Vector2(1.12, 1.48)
	add_child(outer_fire)
	inner_fire = _create_fire_particles(Color(1.0, 0.58, 0.035, 0.92), PORTAL_RADIUS_X * 0.62, 125)
	inner_fire.name = "InnerFireParticles"
	inner_fire.scale = Vector2(0.9, 1.34)
	inner_fire.initial_velocity_min = 38.0
	inner_fire.initial_velocity_max = 126.0
	inner_fire.scale_amount_min = 0.45
	inner_fire.scale_amount_max = 1.45
	add_child(inner_fire)
	spark_fire = _create_fire_particles(Color(1.0, 0.84, 0.22, 0.96), PORTAL_RADIUS_X * 1.08, 90)
	spark_fire.name = "PortalSparks"
	spark_fire.scale = Vector2(1.18, 1.48)
	spark_fire.lifetime = 1.8
	spark_fire.direction = Vector2(0, -1)
	spark_fire.spread = 88.0
	spark_fire.initial_velocity_min = 80.0
	spark_fire.initial_velocity_max = 220.0
	spark_fire.scale_amount_min = 0.3
	spark_fire.scale_amount_max = 0.8
	add_child(spark_fire)
	ash_cloud = _create_fire_particles(Color(0.12, 0.015, 0.02, 0.46), PORTAL_RADIUS_X * 1.25, 72)
	ash_cloud.name = "InfernalAsh"
	ash_cloud.scale = Vector2(1.2, 1.5)
	ash_cloud.lifetime = 3.6
	ash_cloud.gravity = Vector2(0, -36)
	ash_cloud.initial_velocity_min = 8.0
	ash_cloud.initial_velocity_max = 42.0
	ash_cloud.scale_amount_min = 1.2
	ash_cloud.scale_amount_max = 3.8
	add_child(ash_cloud)

func _create_fire_particles(particle_color: Color, radius: float, amount: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = amount
	particles.lifetime = 1.35
	particles.randomness = 0.72
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.direction = Vector2(0, -1)
	particles.spread = 46.0
	particles.gravity = Vector2(0, -180)
	particles.initial_velocity_min = 22.0
	particles.initial_velocity_max = 82.0
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.65
	particles.color = particle_color
	return particles

func _build_light() -> void:
	portal_light = PointLight2D.new()
	portal_light.name = "PortalFireLight"
	portal_light.texture = _create_light_texture()
	portal_light.color = Color(1.0, 0.22, 0.035)
	portal_light.energy = 1.1
	portal_light.texture_scale = 2.35
	portal_light.z_index = 1
	add_child(portal_light)
	abyss_light = PointLight2D.new()
	abyss_light.name = "AbyssCoreLight"
	abyss_light.texture = _create_light_texture()
	abyss_light.color = Color(0.48, 0.02, 0.22)
	abyss_light.energy = 0.72
	abyss_light.texture_scale = 1.25
	abyss_light.z_index = 1
	add_child(abyss_light)

func _create_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.72, 0.22, 1.0),
		Color(1.0, 0.18, 0.02, 0.72),
		Color(0.65, 0.03, 0.01, 0.16),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func _apply_intensity() -> void:
	if !is_instance_valid(portal_light):
		return
	var pulse := 0.86 + sin(elapsed * 8.0) * 0.1 + sin(elapsed * 19.0) * 0.04
	portal_light.energy = (0.72 + intensity * 3.0) * pulse
	portal_light.texture_scale = 1.75 + intensity * 1.12
	if is_instance_valid(abyss_light):
		abyss_light.energy = (0.38 + intensity * 1.1) * (1.0 + sin(elapsed * 4.3) * 0.16)
		abyss_light.texture_scale = 1.05 + intensity * 0.62

func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 5.0) * 0.026 + sin(elapsed * 12.0) * 0.012
	var rx := PORTAL_RADIUS_X * (0.76 + intensity * 0.24) * pulse
	var ry := PORTAL_RADIUS_Y * (0.76 + intensity * 0.24) * pulse

	# Sombra colossal e asas de fumaça que tiram o portal da silhueta de uma bola.
	for aura in range(7, 0, -1):
		var aura_points := _rift_contour(rx + aura * 17.0, ry + aura * 21.0, 0.025, aura * 0.7, RIFT_POINTS)
		draw_colored_polygon(aura_points, Color(0.2, 0.0, 0.025, 0.012 + aura * 0.009 * intensity))
	_draw_infernal_horns(rx, ry)

	# Fenda irregular: borda carbonizada, magma e um vazio púrpura profundo.
	var charred := _rift_contour(rx * 1.13, ry * 1.1, 0.065, elapsed * 1.8, RIFT_POINTS)
	draw_colored_polygon(charred, Color(0.055, 0.002, 0.008, 0.97))
	var magma_outer := _rift_contour(rx * 1.04, ry * 1.025, 0.055, elapsed * 2.4, RIFT_POINTS)
	draw_colored_polygon(magma_outer, Color(0.72, 0.018, 0.004, 0.9))
	var magma_inner := _rift_contour(rx * 0.94, ry * 0.94, 0.04, -elapsed * 3.0, RIFT_POINTS)
	draw_colored_polygon(magma_inner, Color(1.0, 0.19, 0.012, 0.82))
	var abyss := _rift_contour(rx * 0.79, ry * 0.82, 0.035, elapsed * 1.35, RIFT_POINTS)
	draw_colored_polygon(abyss, Color(0.012, 0.0, 0.025, 0.985))

	# Espirais internas sugerem um mundo em movimento do outro lado da fenda.
	for band in range(9):
		var band_scale := 0.74 - band * 0.061
		var vortex := _open_ellipse_arc(rx * band_scale, ry * band_scale, elapsed * (0.42 + band * 0.045) + band * 0.72, 4.65, 54)
		var band_color := Color(0.74 + band * 0.025, 0.018 + band * 0.012, 0.12 + band * 0.012, 0.18 + intensity * 0.055)
		draw_polyline(vortex, band_color, 2.2 + intensity * 1.7, true)

	_draw_runes(rx, ry)
	_draw_flame_crown(rx, ry)
	_draw_hell_lightning(rx, ry)

	for ember in embers:
		var angle := float(ember["angle"]) + elapsed * float(ember["speed"])
		var ember_radius := float(ember["radius"]) + sin(elapsed * 2.5 + float(ember["offset"])) * 12.0
		var point := Vector2(cos(angle), sin(angle) * 1.18) * ember_radius
		point.y -= fposmod(elapsed * (22.0 + float(ember["speed"]) * 11.0) + float(ember["offset"]) * 20.0, 118.0)
		var alpha := (0.22 + intensity * 0.68) * (0.7 + sin(elapsed * 6.0 + float(ember["offset"])) * 0.3)
		draw_circle(point, float(ember["size"]) * (0.8 + intensity), Color(1.0, 0.32 + intensity * 0.38, 0.03, alpha))

	# O rompimento inicial lança ondas de choque largas pela cena.
	if activation_elapsed < 2.2:
		var shock_t := activation_elapsed / 2.2
		for wave in range(3):
			var wave_t := clampf(shock_t * 1.55 - wave * 0.18, 0.0, 1.0)
			if wave_t > 0.0:
				var shock := _rift_contour(rx * (1.0 + wave_t * 1.25), ry * (1.0 + wave_t * 0.75), 0.018, wave, RIFT_POINTS)
				draw_polyline(shock, Color(1.0, 0.22, 0.035, (1.0 - wave_t) * 0.72), 8.0 * (1.0 - wave_t) + 1.0, true)

func _rift_contour(rx:float, ry:float, wobble:float, phase:float, samples:int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(samples):
		var angle := TAU * float(index) / float(samples)
		var distortion := 1.0 + sin(angle * 7.0 + phase) * wobble + sin(angle * 13.0 - phase * 1.7) * wobble * 0.45
		points.append(Vector2(cos(angle) * rx * distortion, sin(angle) * ry * distortion))
	return points

func _open_ellipse_arc(rx:float, ry:float, start:float, length:float, samples:int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(samples):
		var angle := start + length * float(index) / float(samples - 1)
		var pull := 0.82 + 0.18 * sin(float(index) / float(samples - 1) * PI)
		points.append(Vector2(cos(angle) * rx * pull, sin(angle) * ry * pull))
	return points

func _draw_infernal_horns(rx:float, ry:float) -> void:
	for side in [-1.0, 1.0]:
		var horn := PackedVector2Array([
			Vector2(side * rx * 0.72, -ry * 0.72),
			Vector2(side * rx * 1.22, -ry * 1.02),
			Vector2(side * rx * 1.46, -ry * 1.38),
			Vector2(side * rx * 1.08, -ry * 1.19),
			Vector2(side * rx * 0.55, -ry * 0.88),
		])
		draw_colored_polygon(horn, Color(0.035, 0.002, 0.006, 0.98))
		draw_polyline(horn, Color(0.86, 0.055, 0.012, 0.82), 5.0, true)
		var lower_claw := PackedVector2Array([
			Vector2(side * rx * 0.78, ry * 0.62),
			Vector2(side * rx * 1.32, ry * 0.92),
			Vector2(side * rx * 1.46, ry * 1.18),
			Vector2(side * rx * 1.02, ry * 0.98),
			Vector2(side * rx * 0.62, ry * 0.79),
		])
		draw_colored_polygon(lower_claw, Color(0.045, 0.002, 0.007, 0.94))
		draw_polyline(lower_claw, Color(0.66, 0.025, 0.008, 0.72), 4.0, true)

func _draw_runes(rx:float, ry:float) -> void:
	for index in range(16):
		var angle := TAU * float(index) / 16.0 + elapsed * (0.035 if index % 2 == 0 else -0.028)
		var normal := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-normal.y, normal.x)
		var center := Vector2(normal.x * rx * 1.23, normal.y * ry * 1.16)
		var rune_size := 7.0 + float(index % 3) * 2.0
		var rune_color := Color(1.0, 0.19 + float(index % 2) * 0.12, 0.015, 0.48 + intensity * 0.28)
		draw_line(center - tangent * rune_size, center + normal * rune_size, rune_color, 2.5, true)
		draw_line(center + normal * rune_size, center + tangent * rune_size, rune_color, 2.5, true)

func _draw_flame_crown(rx:float, ry:float) -> void:
	for index in range(22):
		var angle := TAU * float(index) / 22.0
		var edge := Vector2(cos(angle) * rx, sin(angle) * ry)
		var normal := Vector2(cos(angle), sin(angle)).normalized()
		var sideways := Vector2(-normal.y, normal.x)
		var flame_height := 24.0 + float(index % 5) * 9.0 + sin(elapsed * (6.0 + index % 4) + index) * 11.0
		var base_width := 8.0 + float(index % 3) * 2.0
		var flame := PackedVector2Array([
			edge - sideways * base_width,
			edge + normal * flame_height + sideways * sin(elapsed * 5.0 + index) * 8.0,
			edge + sideways * base_width,
		])
		draw_colored_polygon(flame, Color(1.0, 0.12 + float(index % 4) * 0.055, 0.008, 0.46 + intensity * 0.28))

func _draw_hell_lightning(rx:float, ry:float) -> void:
	for bolt_index in range(6):
		if (int(elapsed * 9.0) + bolt_index * 2) % 7 > 2:
			continue
		var start_angle := -2.65 + bolt_index * 1.06
		var start := Vector2(cos(start_angle) * rx * 0.72, sin(start_angle) * ry * 0.72)
		var end := Vector2(cos(start_angle + 0.42) * rx * 1.22, sin(start_angle + 0.42) * ry * 1.17)
		var bolt := PackedVector2Array([start])
		for segment in range(1, 6):
			var t := float(segment) / 6.0
			var point := start.lerp(end, t)
			point += Vector2(sin(elapsed * 37.0 + segment * 5.7 + bolt_index), cos(elapsed * 29.0 + segment * 3.1)) * 10.0
			bolt.append(point)
		bolt.append(end)
		draw_polyline(bolt, Color(1.0, 0.58, 0.12, 0.82), 3.2, true)
		draw_polyline(bolt, Color(1.0, 0.94, 0.62, 0.72), 1.1, true)
