extends Node2D

var ground_position := Vector2.ZERO
var bob_offset: float = 0.0
var timer: float = 0.0
var pulse_time: float = 0.0
var is_collected: bool = false

# Salto parabólico inicial ao surgir da derrota do capanga
var bouncing: bool = true
var height_offset: float = -32.0
var vel_y: float = -135.0
var vel_x: float = 0.0
var bounce_count: int = 0
var max_bounces: int = 2

# Micro partículas flutuantes ao redor
var sparkles: Array[Dictionary] = []
var sparkle_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_as_relative = false
	z_index = int(ground_position.y)

func setup(spawn_pos: Vector2) -> void:
	ground_position = spawn_pos
	position = spawn_pos
	z_index = int(spawn_pos.y)
	height_offset = -32.0
	vel_y = randf_range(-145.0, -110.0)
	vel_x = randf_range(-30.0, 30.0)
	bouncing = true
	bounce_count = 0
	timer = randf() * 2.0
	pulse_time = randf() * 2.0
	queue_redraw()

func _process(delta: float) -> void:
	timer += delta
	pulse_time += delta * 4.4
	
	if bouncing:
		vel_y += 650.0 * delta
		height_offset += vel_y * delta
		position.x += vel_x * delta
		ground_position.x = position.x
		if height_offset >= 0.0:
			height_offset = 0.0
			bounce_count += 1
			vel_x *= 0.45
			if bounce_count >= max_bounces:
				bouncing = false
				height_offset = 0.0
				vel_x = 0.0
			else:
				vel_y = -vel_y * 0.42
	else:
		bob_offset = sin(timer * 3.8) * 5.5 - 18.0
		
	if !is_collected:
		sparkle_timer -= delta
		if sparkle_timer <= 0.0:
			sparkle_timer = randf_range(0.11, 0.2)
			var cur_h = height_offset if bouncing else bob_offset
			sparkles.append({
				"pos": Vector2(randf_range(-14.0, 14.0), cur_h + randf_range(-6.0, 8.0)),
				"vel": Vector2(randf_range(-10.0, 10.0), randf_range(-40.0, -18.0)),
				"life": randf_range(0.35, 0.55),
				"max_life": 0.55,
				"radius": randf_range(1.6, 3.2),
				"color": Color("ff758f") if randf() > 0.4 else Color("ffccd5")
			})
			
	for i in range(sparkles.size() - 1, -1, -1):
		var sp = sparkles[i]
		sp.life -= delta
		if sp.life <= 0.0:
			sparkles.remove_at(i)
		else:
			sp.pos += sp.vel * delta
			sparkles[i] = sp
			
	queue_redraw()

func _draw() -> void:
	var current_y = height_offset if bouncing else bob_offset
	var shadow_factor = clampf(1.0 - absf(current_y) / 50.0, 0.35, 1.0)
	
	# Sombra no chao (perspectiva 2.5D)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.85 * shadow_factor, 0.55 * shadow_factor))
	draw_circle(Vector2.ZERO, 13.5, Color(0.12, 0.0, 0.02, 0.46 * shadow_factor))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	var center = Vector2(0.0, current_y)
	
	# Halo / aura de sangue pulsante
	var pulse = 0.5 + 0.5 * sin(pulse_time)
	var halo_rad = 22.0 + pulse * 6.5
	draw_circle(center, halo_rad, Color(0.9, 0.05, 0.2, 0.16 + pulse * 0.12))
	draw_circle(center, halo_rad * 0.68, Color(1.0, 0.15, 0.3, 0.28 + pulse * 0.16))
	
	# Desenho estilizado da gota/frasco de sangue
	# Base arredondada escura
	draw_circle(center + Vector2(0, 3), 11.0, Color("590d22"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -19),
		center + Vector2(-10.5, 2),
		center + Vector2(10.5, 2)
	]), Color("590d22"))
	
	# Corpo interno carmesim
	draw_circle(center + Vector2(0, 3), 9.0, Color("a4133c"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -16),
		center + Vector2(-8.2, 2),
		center + Vector2(8.2, 2)
	]), Color("a4133c"))
	
	# Sangue vibrante
	draw_circle(center + Vector2(0, 3), 6.5, Color("ff4d6d"))
	draw_circle(center + Vector2(0, 2), 3.8, Color("ff758f"))
	
	# Brilho de vidro / reflexo especular
	draw_circle(center + Vector2(-3.8, -2), 3.2, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(center + Vector2(-2.6, -5.5), 1.7, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(center + Vector2(3.5, 4.5), 1.8, Color(1.0, 0.85, 0.9, 0.65))
	
	# Partículas de brilho flutuantes
	for sp in sparkles:
		var sp_alpha = clampf(sp.life / sp.max_life, 0.0, 1.0)
		draw_circle(sp.pos, sp.radius, Color(sp.color.r, sp.color.g, sp.color.b, sp_alpha * 0.85))

func collect() -> void:
	if is_collected:
		return
	is_collected = true

	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(2.3, 2.3), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)
