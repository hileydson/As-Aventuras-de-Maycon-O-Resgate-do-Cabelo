extends Control

var spots:Array[Dictionary] = []
var fade_tween:Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0

func flash() -> void:
	spots.clear()
	for i in range(27):
		var edge := i % 4
		var position := Vector2(randf(), randf())
		if edge == 0:
			position.y *= 0.22
		elif edge == 1:
			position.y = 0.78 + position.y * 0.22
		elif edge == 2:
			position.x *= 0.18
		else:
			position.x = 0.82 + position.x * 0.18
		var outline := PackedFloat32Array()
		for point_index in range(12):
			outline.append(randf_range(0.48, 1.42))
		spots.append({"position":position, "radius":randf_range(9.0, 19.0), "shade":randf_range(0.48, 0.85), "outline":outline})
	modulate.a = 0.95
	queue_redraw()
	if fade_tween and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.65, 0.02, 0.08, 0.12), true)
	for spot in spots:
		var center:Vector2 = spot.position * size
		var radius:float = spot.radius
		var polygon := PackedVector2Array()
		for point_index in range(12):
			var angle := float(point_index) / 12.0 * TAU
			polygon.append(center + Vector2(cos(angle), sin(angle)) * radius * spot.outline[point_index])
		var blood_color := Color(0.48, 0.005, 0.045, spot.shade)
		draw_colored_polygon(polygon, blood_color)
		for drop_index in range(5):
			var angle := float(drop_index) * 2.37 + radius
			var offset := Vector2(cos(angle), sin(angle)) * radius * (1.35 + float(drop_index) * 0.28)
			draw_circle(center + offset, radius * (0.08 + float(drop_index % 2) * 0.04), blood_color)
