extends VideoStreamPlayer

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")

func _ready() -> void:
	_create_old_film_filter()

func _create_old_film_filter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var film_rect := ColorRect.new()
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = OLD_FILM_SHADER
	material.set_shader_parameter("sepia_amount", 0.48)
	material.set_shader_parameter("grain_amount", 0.082)
	material.set_shader_parameter("grain_speed", 24.0)
	material.set_shader_parameter("vignette_intensity", 0.85)
	material.set_shader_parameter("vignette_radius", 1.0)
	material.set_shader_parameter("flicker_intensity", 0.048)
	material.set_shader_parameter("scratch_intensity", 0.40)
	material.set_shader_parameter("dust_intensity", 0.45)
	material.set_shader_parameter("jitter_amount", 0.00065)
	film_rect.material = material
	layer.add_child(film_rect)

func _on_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_1.tscn")

func _process(delta):
	pass
