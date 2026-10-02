extends Node3D

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
const PLANE_ENGINE = preload("res://assets/novos_audios/aviao.mp3")

@export var forest_scene:String = "res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn"
@export var pace:float = 1.0
@onready var lips:Node3D = $Lips
@onready var maycon:Node3D = $Maycon
@onready var plane:Node3D = $Plane
@onready var camera:Camera3D = $Camera3D
@onready var hair: AnimatedSprite3D = $Hair
var follow:Node3D
var focus:Node3D
var follow_offset:Vector3
var focus_offset:Vector3
var bob:bool = false
var time:float = 0.0
var attached:bool = false
var lips_running:bool = false
var maycon_entered:bool = false
var lips_animation:AnimationPlayer
var maycon_animation:AnimationPlayer
var lips_skeleton:Skeleton3D

func _ready() -> void:
	Global.in_cutscene = true
	lips_animation = lips.find_child("AnimationPlayer", true, false)
	lips_skeleton = lips.find_child("Skeleton3D", true, false) as Skeleton3D
	maycon_animation = maycon.find_child("AnimationPlayer", true, false)
	# Mesmos ajustes de material usados pelo controlador original.
	var original = load("res://scripts/3D/platform_maycon.gd").new()
	original._adjust_maycon_materials(maycon)
	original.free()
	var library:AnimationLibrary = maycon_animation.get_animation_library("") if maycon_animation and maycon_animation.has_animation_library("") else null
	if library and not library.has_animation("Air_Flail"):
		library.add_animation("Air_Flail", load("res://assets/novas_imagens/3d_enemies/maycon_air_flail.res"))
	$HUD/Phrase.text = tr("RESGATE_CIGARRO")
	$HUD/Phrase.visible = false
	maycon.visible = false
	$Spring.visible = false
	$Magic.emitting = false
	$HUD/Fade.color.a = 0.0
	build_engine_sound()
	call_deferred("sequence")

# O avião estava passando sem som nenhum; o motor agora acompanha ele em loop.
func build_engine_sound() -> void:
	var motor := AudioStreamPlayer3D.new()
	motor.name = "Motor"
	motor.stream = PLANE_ENGINE
	motor.unit_size = 36.0
	motor.volume_db = -3.0
	plane.add_child(motor)
	# Os mp3 do projeto não são importados em loop, então o som é reiniciado no fim.
	motor.finished.connect(func():
		if is_instance_valid(motor):
			motor.play())
	motor.play()

func _process(delta:float) -> void:
	time += delta
	if follow:
		camera.global_position = follow.global_position + global_basis * follow_offset
		if bob:
			camera.position.y += sin(time * 13.0) * 0.08
	if focus:
		camera.look_at(focus.global_position + global_basis * focus_offset)
	if attached:
		hair.position = Vector3(0, 2.3, 0.95)
	if lips_running and not lips.get_parent() == plane:
		$Lips/Visual.position.y = 1.8 + absf(sin(time * 9.0)) * 0.18
		$Lips/Visual.rotation.z = sin(time * 9.0) * 0.035
		pose_lips_running(time * 9.0)
	if $HUD/Phrase.visible:
		var screen := camera.unproject_position($Cigarro.global_position + Vector3.UP * 2.0)
		$HUD/Phrase.position = screen - Vector2($HUD/Phrase.size.x * 0.5, 40)

func animate(player:AnimationPlayer, name:String) -> void:
	if player and player.has_animation(name):
		player.play(name, 0.15)

func pose_lips_running(phase:float) -> void:
	if not lips_skeleton:
		return
	lips_skeleton.reset_bone_poses()
	var swing := sin(phase) * 0.75
	set_lips_bone("Hips", -0.13)
	set_lips_bone("Leg_Upper.L", swing)
	set_lips_bone("Leg_Upper.R", -swing)
	set_lips_bone("Leg_Lower.L", maxf(0.0, -swing) * 0.85)
	set_lips_bone("Leg_Lower.R", maxf(0.0, swing) * 0.85)
	set_lips_bone("Arm_Upper.L", -swing * 0.85)
	set_lips_bone("Arm_Upper.R", swing * 0.85)
	set_lips_bone("Head", sin(phase * 2.0) * 0.04)

func set_lips_bone(bone_name:String, angle:float) -> void:
	var bone := lips_skeleton.find_bone(bone_name)
	if bone < 0:
		return
	# Gira a partir do descanso do osso. Substituir a orientacao virava o pe para
	# dentro da barriga.
	var descanso := lips_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	lips_skeleton.set_bone_pose_rotation(bone, descanso * Quaternion(Vector3.RIGHT, angle))

func move(node:Node3D, destination:Vector3, duration:float) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "position", destination, duration * pace)
	return tween

func shot(actor:Node3D, offset:Vector3, target:Node3D, aim:Vector3, duration:float, first_person:bool = false) -> void:
	follow = actor
	follow_offset = offset
	focus = target
	focus_offset = aim
	bob = first_person
	lips.visible = not (first_person and actor == lips)
	maycon.visible = maycon_entered and not (first_person and actor == maycon)
	await get_tree().create_timer(duration * pace).timeout

func arc(node:Node3D, destination:Vector3, height:float, duration:float) -> Tween:
	var start := node.position
	var tween := create_tween()
	tween.tween_method(func(t:float): node.position = start.lerp(destination, t) + Vector3.UP * sin(t * PI) * height, 0.0, 1.0, duration * pace)
	return tween

func sound(path:String) -> void:
	var audio := AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = -7
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func sequence() -> void:
	animate(lips_animation, "Run")
	lips_running = true
	animate(maycon_animation, "Arise")
	move(lips, Vector3(0, 0, 0), 3.5)
	await shot(hair, Vector3(9, 5, 9), lips, Vector3.UP * 2, 3.5)
	# Pega o cabelo original; ele permanece preso nas costas em todos os planos.
	arc(hair, lips.position + Vector3(0, 2.3, 0.95), 3, 1.0)
	await shot(lips, Vector3(5, 3, 4), hair, Vector3.ZERO, 1.0)
	hair.reparent(lips, true)
	attached = true
	move(lips, Vector3(0, 0, -46), 11)
	move(plane, Vector3(0, 30, -64), 14)
	await shot(lips, Vector3(0, 3.2, -0.3), plane, Vector3.ZERO, 4, true)
	await shot(lips, Vector3(0, 3.2, -0.3), lips, Vector3(0, 3, -22), 2, true)
	await shot(lips, Vector3(5, 5, 10), plane, Vector3.ZERO, 5)
	animate(lips_animation, "Jump_Ascent")
	sound("res://assets/novos_audios/mario_part_sounds/lips_jump_grunt.mp3")
	arc(lips, Vector3(0, 26, -64), 12, 3)
	await shot(lips, Vector3(9, 4, 13), plane, Vector3.ZERO, 3)
	lips.reparent(plane, true)
	lips_running = false
	if lips_skeleton:
		lips_skeleton.reset_bone_poses()
	lips.position = Vector3(0, -4, 0)
	animate(lips_animation, "Jump_Ascent")
	if lips_animation and lips_animation.is_playing():
		lips_animation.seek(lips_animation.current_animation_length * 0.5, true)
		lips_animation.pause()
	move(plane, Vector3(0, 42, -185), 26)
	maycon_entered = true
	maycon.visible = true
	move(maycon, Vector3(0, 0, -106), 18)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 3, true)
	await shot(maycon, Vector3(0, 1.65, -0.2), maycon, Vector3(0, 1.5, -20), 2, true)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 3, true)
	await shot(maycon, Vector3(-7, 3, 5), maycon, Vector3(0, 1, -3), 4)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 2, true)
	follow = maycon
	follow_offset = Vector3(0, 1.65, -0.2)
	focus = $Cigarro
	focus_offset = Vector3.ZERO
	var zoom := create_tween()
	zoom.tween_property(camera, "fov", 18.0, 1.1 * pace)
	await zoom.finished
	$HUD/Phrase.visible = true
	await get_tree().create_timer(1.8 * pace).timeout
	$HUD/Phrase.visible = false
	zoom = create_tween()
	zoom.tween_property(camera, "fov", 65.0, 1.1 * pace)
	await zoom.finished
	$Spring.visible = true
	$Spring.position = $Cigarro.position
	arc($Spring, Vector3(0, 0.2, -113), 3, 2)
	move(maycon, Vector3(0, 0, -113), 2)
	await shot(maycon, Vector3(8, 4, 6), $Spring, Vector3.ZERO, 2)
	$Magic.global_position = maycon.global_position
	$Magic.emitting = true
	animate(maycon_animation, "Air_Flail")
	sound("res://assets/novos_audios/maycon_platform_landing.mp3")
	# Mesma poeira do avião: o chão do trampolim estoura e ela sobe junto com ele.
	POEIRA.pousar(self, maycon.global_position)
	POEIRA.impulsionar(self, maycon.global_position + Vector3.UP * 0.6)
	var salto_poeira := POEIRA.rastro(maycon)
	arc(maycon, Vector3(0, 70, -175), 12, 4)
	await shot(maycon, Vector3(7, 4, 13), plane, Vector3.ZERO, 4)
	POEIRA.apagar(salto_poeira)
	move(plane, Vector3(0, 43, -198), 2)
	arc(maycon, Vector3(0, 43, -198), 4, 2)
	await shot(maycon, Vector3(7, 5, 12), lips, Vector3.ZERO, 2)
	sound("res://assets/novos_audios/punch_4.mp3")
	lips.reparent(self, true)
	animate(lips_animation, "Belly_Dive")
	move(lips, Vector3(0, -28, -215), 4)
	move(maycon, Vector3(1, -26, -215), 4)
	move(plane, Vector3(0, 46, -265), 8)
	follow = plane
	follow_offset = Vector3(12, 7, 32)
	focus = plane
	focus_offset = Vector3.ZERO
	maycon.visible = true
	lips.visible = true
	await get_tree().create_timer(3 * pace).timeout
	var fade := create_tween()
	fade.tween_property($HUD/Fade, "color:a", 1.0, 5.0 * pace)
	await fade.finished
	Global.in_cutscene = false
	get_tree().change_scene_to_file(forest_scene)
