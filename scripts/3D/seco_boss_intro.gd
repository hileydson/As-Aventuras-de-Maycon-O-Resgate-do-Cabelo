extends Node3D

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")

@onready var seco: Node3D = $olindao_3d_animations
@onready var camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $olindao_3d_animations/AnimationPlayer
@onready var first_name: Label = $Titles/Names/Olindao
@onready var middle_name: Label = $Titles/Names/Tripa
@onready var last_name: Label = $Titles/Names/Maior
@onready var em_3d: Label = $Titles/Em3D
@onready var blackout: ColorRect = $Fade/Blackout
@onready var punch: AudioStreamPlayer = $Punch
@onready var suspense: AudioStreamPlayer = $Suspense

var orbit_angle: float = 0.0
var orbit_radius: float = 14.0

func _ready() -> void:
	first_name.text = tr("BOSS_INTRO_OLINDAO")
	middle_name.text = tr("BOSS_INTRO_TRIPA")
	last_name.text = tr("BOSS_INTRO_MAIOR")
	em_3d.text = tr("BOSS_INTRO_3D")
	first_name.modulate.a = 0.0
	middle_name.modulate.a = 0.0
	last_name.modulate.a = 0.0
	em_3d.modulate.a = 0.0
	blackout.color = Color.BLACK
	_create_old_film_filter()
	animation_player.speed_scale = 0.45
	animation_player.play("Walking")
	suspense.play()
	_update_camera()
	_play_intro()

func _process(delta: float) -> void:
	orbit_angle += delta * 0.25
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(orbit_angle) * orbit_radius, 3.15, cos(orbit_angle) * orbit_radius)
	camera.look_at(seco.position + Vector3(0, 2.0, 0), Vector3.UP)

func _play_intro() -> void:
	var reveal := create_tween()
	reveal.tween_property(blackout, "color:a", 0.0, 2.0)
	await reveal.finished

	await get_tree().create_timer(1.0).timeout
	var approach := create_tween()
	approach.tween_property(self, "orbit_radius", 5.2, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await approach.finished
	await get_tree().create_timer(0.4).timeout
	punch.play()
	first_name.modulate.a = 1.0
	await get_tree().create_timer(1.0).timeout
	punch.play()
	middle_name.modulate.a = 1.0
	await get_tree().create_timer(1.0).timeout
	punch.play()
	last_name.modulate.a = 1.0
	await get_tree().create_timer(1.5).timeout
	punch.play()
	em_3d.modulate.a = 1.0
	await get_tree().create_timer(2.5).timeout

	var fade_out := create_tween()
	fade_out.tween_property(blackout, "color:a", 1.0, 1.5)
	fade_out.parallel().tween_property(suspense, "volume_db", -40.0, 1.5)
	await fade_out.finished
	get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")

func _create_old_film_filter() -> void:
	var film_layer := CanvasLayer.new()
	film_layer.name = "OldFilmFilter"
	film_layer.layer = 4
	add_child(film_layer)

	var film_rect := ColorRect.new()
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material := ShaderMaterial.new()
	material.shader = OLD_FILM_SHADER
	material.set_shader_parameter("sepia_amount", 0.16)
	material.set_shader_parameter("grain_amount", 0.025)
	material.set_shader_parameter("grain_speed", 20.0)
	material.set_shader_parameter("vignette_intensity", 0.28)
	material.set_shader_parameter("vignette_radius", 1.08)
	material.set_shader_parameter("flicker_intensity", 0.012)
	material.set_shader_parameter("scratch_intensity", 0.10)
	material.set_shader_parameter("dust_intensity", 0.12)
	material.set_shader_parameter("jitter_amount", 0.00012)
	film_rect.material = material
	film_layer.add_child(film_rect)
