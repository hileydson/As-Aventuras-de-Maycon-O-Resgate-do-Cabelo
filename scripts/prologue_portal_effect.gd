extends Node2D

const PORTAL_RADIUS := 86.0

var intensity := 0.35
var active := false
var elapsed := 0.0
var embers: Array[Dictionary] = []
var portal_light: PointLight2D
var outer_fire: CPUParticles2D
var inner_fire: CPUParticles2D

func _ready() -> void:
	_build_particles()
	_build_light()
	for index in range(72):
		var angle := TAU * float(index) / 72.0
		embers.append({
			"angle": angle,
			"radius": lerpf(28.0, PORTAL_RADIUS, float(index % 9) / 8.0),
			"speed": 0.7 + float(index % 7) * 0.13,
			"offset": float(index) * 0.37,
			"size": 1.4 + float(index % 4) * 0.8,
		})
	_apply_intensity()

func activate() -> void:
	active = true
	intensity = 1.0
	outer_fire.amount = 170
	inner_fire.amount = 120
	outer_fire.restart()
	inner_fire.restart()
	_apply_intensity()

func _process(delta: float) -> void:
	elapsed += delta
	if !active:
		intensity = lerpf(intensity, 0.42, delta * 1.6)
	_apply_intensity()
	queue_redraw()

func _build_particles() -> void:
	outer_fire = _create_fire_particles(Color(1.0, 0.18, 0.015, 0.86), PORTAL_RADIUS, 90)
	outer_fire.name = "OuterFireParticles"
	add_child(outer_fire)
	inner_fire = _create_fire_particles(Color(1.0, 0.70, 0.10, 0.90), PORTAL_RADIUS * 0.66, 55)
	inner_fire.name = "InnerFireParticles"
	inner_fire.initial_velocity_min = 38.0
	inner_fire.initial_velocity_max = 104.0
	inner_fire.scale_amount_min = 0.45
	inner_fire.scale_amount_max = 1.2
	add_child(inner_fire)

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
	portal_light.energy = 0.55
	portal_light.texture_scale = 1.45
	portal_light.z_index = 1
	add_child(portal_light)

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
	return texture

func _apply_intensity() -> void:
	if !is_instance_valid(portal_light):
		return
	var pulse := 0.9 + sin(elapsed * 8.0) * 0.1
	portal_light.energy = (0.36 + intensity * 1.55) * pulse
	portal_light.texture_scale = 1.1 + intensity * 0.72

func _draw() -> void:
	var pulse := 1.0 + sin(elapsed * 5.0) * 0.035
	var radius := PORTAL_RADIUS * (0.72 + intensity * 0.28) * pulse
	draw_circle(Vector2.ZERO, radius * 1.08, Color(0.55, 0.01, 0.0, 0.10 + intensity * 0.14))
	draw_circle(Vector2.ZERO, radius * 0.78, Color(0.08, 0.0, 0.02, 0.54))
	for ring in range(4):
		var ring_radius := radius - ring * 10.0 + sin(elapsed * (3.0 + ring) + ring) * 3.0
		var ring_color := Color(1.0, 0.15 + ring * 0.09, 0.015, 0.28 + intensity * 0.12)
		draw_arc(Vector2.ZERO, ring_radius, elapsed * (0.45 + ring * 0.08), TAU + elapsed * (0.45 + ring * 0.08), 64, ring_color, 2.0 + intensity * 2.0)
	for ember in embers:
		var angle := float(ember["angle"]) + elapsed * float(ember["speed"])
		var ember_radius := float(ember["radius"]) + sin(elapsed * 2.5 + float(ember["offset"])) * 12.0
		var point := Vector2(cos(angle), sin(angle) * 0.62) * ember_radius
		point.y -= fposmod(elapsed * (18.0 + float(ember["speed"]) * 10.0) + float(ember["offset"]) * 20.0, 86.0)
		var alpha := (0.22 + intensity * 0.68) * (0.7 + sin(elapsed * 6.0 + float(ember["offset"])) * 0.3)
		draw_circle(point, float(ember["size"]) * (0.8 + intensity), Color(1.0, 0.32 + intensity * 0.38, 0.03, alpha))
