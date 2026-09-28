extends Node3D

@onready var seco: Node3D = $olindao_3d_animations
@onready var camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $olindao_3d_animations/AnimationPlayer
@onready var first_name: Label = $Titles/Names/Olindao
@onready var middle_name: Label = $Titles/Names/Tripa
@onready var last_name: Label = $Titles/Names/Maior
@onready var blackout: ColorRect = $Fade/Blackout
@onready var punch: AudioStreamPlayer = $Punch
@onready var suspense: AudioStreamPlayer = $Suspense

var orbit_angle: float = 0.0
var orbit_radius: float = 14.0

func _ready() -> void:
	first_name.text = tr("BOSS_INTRO_OLINDAO")
	middle_name.text = tr("BOSS_INTRO_TRIPA")
	last_name.text = tr("BOSS_INTRO_MAIOR")
	first_name.modulate.a = 0.0
	middle_name.modulate.a = 0.0
	last_name.modulate.a = 0.0
	blackout.color = Color.BLACK
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
	await get_tree().create_timer(4.0).timeout

	var fade_out := create_tween()
	fade_out.tween_property(blackout, "color:a", 1.0, 1.5)
	fade_out.parallel().tween_property(suspense, "volume_db", -40.0, 1.5)
	await fade_out.finished
	get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")
