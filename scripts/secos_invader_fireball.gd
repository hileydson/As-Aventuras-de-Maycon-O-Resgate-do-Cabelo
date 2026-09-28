extends Node2D

var time:float = 0.0
var embers:Array[Dictionary] = []
var rng:RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	var glow:CanvasItemMaterial = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow


func _process(delta:float) -> void:
	time += delta
	for i in range(embers.size() - 1, -1, -1):
		var ember:Dictionary = embers[i]
		ember.position += ember.velocity * delta
		ember.life -= delta
		if ember.life <= 0.0:
			embers.remove_at(i)
	for i in range(3):
		_spawn_ember(false)
	queue_redraw()


func burst() -> void:
	for i in range(22):
		_spawn_ember(true)


func _spawn_ember(outward:bool) -> void:
	var angle:float = rng.randf_range(0.0, TAU)
	var speed:float = rng.randf_range(35.0, 115.0) if !outward else rng.randf_range(140.0, 320.0)
	embers.append({"position": Vector2.RIGHT.rotated(angle) * rng.randf_range(5.0, 20.0), "velocity": Vector2.RIGHT.rotated(angle) * speed + Vector2(0.0, -35.0), "life": rng.randf_range(0.28, 0.72), "radius": rng.randf_range(1.5, 4.0)})


func _draw() -> void:
	for i in range(5, 0, -1):
		draw_circle(Vector2.ZERO, 14.0 + float(i) * 8.0, Color(0.48, 0.04, 1.0, 0.018))
	for i in range(6):
		var angle:float = float(i) * TAU / 6.0 + time * 3.7
		var tip:Vector2 = Vector2.RIGHT.rotated(angle) * (22.0 + sin(time * 10.0 + float(i)) * 7.0)
		var side:Vector2 = Vector2.RIGHT.rotated(angle + 0.7) * 11.0
		draw_colored_polygon(PackedVector2Array([side, tip, -side]), Color(0.43, 0.04, 0.85, 0.27))
		draw_circle(Vector2.RIGHT.rotated(-angle * 1.35) * 13.0, 3.5, Color(0.95, 0.55, 1.0, 0.8))
	draw_circle(Vector2.ZERO, 19.0 + sin(time * 12.0) * 2.0, Color(0.38, 0.02, 0.69, 0.9))
	draw_arc(Vector2.ZERO, 15.0, time * 4.0, time * 4.0 + PI * 1.4, 25, Color(0.96, 0.36, 1.0), 3.0)
	draw_circle(Vector2.ZERO, 8.0, Color(0.96, 0.78, 1.0))
	for ember in embers:
		draw_circle(ember.position, ember.radius, Color(0.78, 0.25, 1.0, clampf(ember.life * 1.4, 0.0, 1.0)))
