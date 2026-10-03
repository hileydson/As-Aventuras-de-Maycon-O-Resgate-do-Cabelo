extends Node3D

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
const PLANE_ENGINE = preload("res://assets/novos_audios/aviao.mp3")
const CITY_SONG = preload("res://assets/novos_audios/city_cutscene_song.mp3")
const STEP_SOUND = preload("res://assets/novos_audios/mario_part_sounds/passo.mp3")
const WIND_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
const BLUR_SHADER = preload("res://scenes/3D/resgate_cabeludo/city_cutscene_motion_blur.gdshader")
const PLANE_GRIP := Vector3(0.0, -3.07, 0.8)
const SONG_FADE_TIME := 6.0
# Blur de base sempre presente, mais o ganho sobre a velocidade do fundo na tela.
const BLUR_BASE := .06
const BLUR_GAIN := .22
const BLUR_MAX := .42
const BLUR_REFERENCE := 20.0
# Corte de memória: clarão âmbar curto, no mesmo tom da dissolução do Maycon.
const FLASH_COLOR := Color(1.0, .93, .82)
const FLASH_ALPHA := .62
const FLASH_TIME := .38
const FLASH_BLUR := .34

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
var maycon_running:bool = false
var lips_hanging:bool = false
var step_timer:float = 0.0
var step_audio:AudioStreamPlayer
var city_song:AudioStreamPlayer
var music_fading:bool = false
var camera_zoom:Tween
var hair_grip:BoneAttachment3D
var blur_material:ShaderMaterial
var flash_overlay:ColorRect
var flash_tween:Tween
var flash_blur:float = 0.0
var flashes:int = 0
var blur_strength:float = 0.0
var previous_camera:Transform3D

func _ready() -> void:
	Global.in_cutscene = true
	# A cidade usa contraste forte na gameplay; estes planos precisam mostrar os atores.
	var world:WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment")
	if world and world.environment:
		camera.environment = world.environment.duplicate()
		camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		# Anoitecer: continua legível, mas sem o dia claro que brigava com a gameplay.
		camera.environment.ambient_light_color = Color("5a6a86")
		camera.environment.ambient_light_energy = .32
		camera.environment.adjustment_enabled = true
		camera.environment.adjustment_brightness = .88
		camera.environment.adjustment_contrast = 1.16
		camera.environment.adjustment_saturation = 1.12
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
	hair.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	maycon.visible = false
	$Spring.visible = false
	$Magic.emitting = false
	$HUD/Fade.color.a = 0.0
	build_engine_sound()
	build_city_audio()
	build_plane_wind()
	build_motion_blur()
	build_memory_flash()
	call_deferred("sequence")

func build_city_audio() -> void:
	city_song = AudioStreamPlayer.new()
	city_song.name = "CityCutsceneSong"
	city_song.stream = CITY_SONG.duplicate()
	city_song.stream.loop = false
	city_song.volume_db = -7.0
	add_child(city_song)
	city_song.play()
	step_audio = AudioStreamPlayer.new()
	step_audio.name = "PassosMaycon"
	step_audio.stream = STEP_SOUND
	step_audio.volume_db = -5.0
	add_child(step_audio)

func build_motion_blur() -> void:
	var effect := ColorRect.new()
	effect.name = "MotionBlur"
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_material = ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	blur_material.set_shader_parameter("blur_strength", BLUR_BASE)
	blur_material.set_shader_parameter("blur_direction", Vector2(0,1))
	effect.material = blur_material
	$HUD.add_child(effect)
	$HUD.move_child(effect, 0)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	previous_camera = camera.global_transform

func build_memory_flash() -> void:
	flash_overlay = ColorRect.new()
	flash_overlay.name = "MemoryFlash"
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.color = Color(FLASH_COLOR, 0.0)
	$HUD.add_child(flash_overlay)
	# Acima dos planos e da frase, mas abaixo do fade que encerra a cena.
	$HUD.move_child(flash_overlay, $HUD/Fade.get_index())
	flash_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Cada troca de take corta como uma lembrança: clarão curto e um puxão no blur.
func memory_flash() -> void:
	if not flash_overlay:
		return
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_overlay.color = Color(FLASH_COLOR, FLASH_ALPHA)
	flash_blur = FLASH_BLUR
	flashes += 1
	flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "color:a", 0.0, FLASH_TIME * pace).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flash_tween.parallel().tween_property(self, "flash_blur", 0.0, FLASH_TIME * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Deslocamento de um ponto do mundo na tela, em frações de meia tela.
func screen_offset(view:Transform3D, fov_degrees:float, target:Vector3) -> Vector2:
	var local:Vector3 = view.affine_inverse() * target
	if local.z > -.05:
		return Vector2.ZERO
	var extent := tan(deg_to_rad(fov_degrees) * .5)
	var viewport:Vector2 = get_viewport().get_visible_rect().size
	var aspect := viewport.x / maxf(viewport.y, 1.0)
	return Vector2(local.x / (-local.z * extent * aspect), -local.y / (-local.z * extent))

# O fundo é o que escorre na tela quando a câmera corre: ele dita o blur.
func update_motion_blur(delta:float) -> void:
	if not blur_material:
		return
	var reference:Vector3 = previous_camera.origin - previous_camera.basis.z * BLUR_REFERENCE
	var drift := screen_offset(camera.global_transform, camera.fov, reference) / maxf(delta, .0001)
	blur_strength = minf(BLUR_BASE + flash_blur + drift.length() * BLUR_GAIN, BLUR_MAX)
	if drift.length() > .0001:
		blur_material.set_shader_parameter("blur_direction", drift.normalized())
	blur_material.set_shader_parameter("blur_strength", blur_strength)
	previous_camera = camera.global_transform

func fade_city_song(duration:float) -> void:
	if music_fading:
		return
	music_fading = true
	var fade := create_tween().set_ignore_time_scale(true)
	var remaining := maxf(.05,city_song.stream.get_length() - city_song.get_playback_position())
	fade.tween_property(city_song, "volume_db", -60.0, minf(duration,remaining))

func build_plane_wind() -> void:
	var vento := MultiMeshInstance3D.new()
	vento.name = "VentoDoAviao"
	vento.set_script(WIND_SCRIPT)
	vento.quantidade = 120
	vento.alcance_z = 100.0
	vento.raio_min = 7.0
	vento.raio_max = 38.0
	vento.velocidade = 90.0 / pace
	vento.z_limite = 40.0
	vento.espessura = 0.035
	vento.comprimento_min = 3.0
	vento.comprimento_max = 10.0
	vento.alpha_min = .12
	vento.alpha_max = .35
	plane.add_child(vento)
	# As partículas ficam no espaço por onde o avião passou, sem acompanhar o nó.
	for lado in [-1.0, 1.0]:
		var rastro := GPUParticles3D.new()
		rastro.name = "RastroDaAsa"
		rastro.amount = 180
		rastro.lifetime = 5.0 * pace
		rastro.local_coords = false
		rastro.draw_pass_1 = POEIRA.nuvem()
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3.BACK
		mat.spread = 3.0
		mat.initial_velocity_min = .3
		mat.initial_velocity_max = .8
		mat.gravity = Vector3.ZERO
		mat.scale_min = .22
		mat.scale_max = .5
		mat.color = Color(.84, .92, 1.0, .32)
		mat.alpha_curve = POEIRA.curva()
		rastro.process_material = mat
		rastro.visibility_aabb = AABB(Vector3(-35,-20,-35),Vector3(70,50,130))
		rastro.position = Vector3(lado * 13.5, -.4, 3)
		plane.add_child(rastro)

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
	# A faixa é mais curta que a cena: desvanece antes do fim natural, sem repetir.
	if city_song.playing and city_song.get_playback_position() >= city_song.stream.get_length() - SONG_FADE_TIME:
		fade_city_song(SONG_FADE_TIME)
	if maycon_running:
		step_timer -= delta
		if step_timer <= 0.0:
			step_audio.pitch_scale = randf_range(1.02, 1.1)
			step_audio.play()
			step_timer = .34 * pace
	elif step_audio.playing:
		step_audio.stop()
	if follow:
		camera.global_position = follow.global_position + global_basis * follow_offset
		if bob:
			camera.position.y += sin(time * 13.0) * 0.08
	if focus:
		camera.look_at(focus.global_position + global_basis * focus_offset)
		$ActionFill.global_position = focus.global_position+Vector3.UP*5
	if lips_running and not lips.get_parent() == plane:
		$Lips/Visual.position.y = 1.8 + absf(sin(time * 9.0)) * 0.18
		$Lips/Visual.rotation.z = sin(time * 9.0) * 0.035
		pose_lips_running(time * 9.0)
	if lips_hanging:
		pose_lips_hanging()
	if $HUD/Phrase.visible:
		var screen := camera.unproject_position($Cigarro.global_position + Vector3.UP * 2.0)
		$HUD/Phrase.position = screen - Vector2($HUD/Phrase.size.x * 0.5, 40)
	update_motion_blur(delta)

func animate(player:AnimationPlayer, name:String) -> void:
	if player and player.has_animation(name):
		player.play(name, 0.15)

func pose_lips_running(phase:float, carrying_hair:bool = false) -> void:
	if not lips_skeleton:
		return
	lips_skeleton.reset_bone_poses()
	var swing := sin(phase) * 0.75
	set_lips_bone("Hips", -0.13)
	set_lips_bone("Leg_Upper.L", swing)
	set_lips_bone("Leg_Upper.R", -swing)
	set_lips_bone("Leg_Lower.L", maxf(0.0, -swing) * 0.85)
	set_lips_bone("Leg_Lower.R", maxf(0.0, swing) * 0.85)
	aim_lips_arm("Arm_Upper.L", Vector3(0,-1,swing * .85).normalized())
	aim_lips_arm("Arm_Upper.R", Vector3(0,-1,-swing * .85).normalized())
	set_lips_bone("Arm_Lower.L", -.35)
	if attached or carrying_hair:
		# Cotovelo dobrado para segurar a folha acima do chão enquanto corre.
		aim_lips_arm("Arm_Lower.R", Vector3(0,.3 + sin(phase) * .12,1).normalized())
	else:
		set_lips_bone("Arm_Lower.R", -.35)
	set_lips_bone("Head", sin(phase * 2.0) * 0.04)

func set_lips_bone(bone_name:String, angle:float) -> void:
	var bone := lips_skeleton.find_bone(bone_name)
	if bone < 0:
		return
	# Gira a partir do descanso do osso. Substituir a orientacao virava o pe para
	# dentro da barriga.
	var descanso := lips_skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	lips_skeleton.set_bone_pose_rotation(bone, descanso * Quaternion(Vector3.RIGHT, angle))

func aim_lips_arm(bone_name:String, direction:Vector3) -> void:
	var bone := lips_skeleton.find_bone(bone_name)
	var rest := lips_skeleton.get_bone_global_rest(bone).basis
	var parent_pose := lips_skeleton.get_bone_global_pose(lips_skeleton.get_bone_parent(bone)).basis
	var aimed := Basis(Quaternion(rest.y.normalized(), direction)) * rest
	lips_skeleton.set_bone_pose_rotation(bone, (parent_pose.inverse() * aimed).get_rotation_quaternion())

func pose_lips_pickup() -> void:
	lips_skeleton.reset_bone_poses()
	set_lips_bone("Hips", -.12)
	aim_lips_arm("Arm_Upper.R", Vector3(0,-.6,.8).normalized())
	aim_lips_arm("Arm_Upper.L", Vector3(0,-1,-.15).normalized())
	aim_lips_arm("Arm_Lower.R", Vector3(0,.3,1).normalized())
	set_lips_bone("Head", .16)

func lips_hand_transform() -> Transform3D:
	var bone := lips_skeleton.find_bone("Arm_Lower.R")
	return lips_skeleton.global_transform * lips_skeleton.get_bone_global_pose(bone) * Transform3D(Basis.IDENTITY,Vector3(0,.3,0))

func paper_in_hand_transform() -> Transform3D:
	# Calibra com o braço abaixado, para a folha ficar legível durante a corrida.
	pose_lips_running(0.0, true)
	var bone := lips_skeleton.find_bone("Arm_Lower.R")
	var bone_basis := lips_skeleton.get_bone_global_pose(bone).basis
	var paper_basis := bone_basis.inverse() * Basis(Vector3.UP, PI + .18)
	# Compensa a escala do rig: o papel mantém o tamanho original do Cabelo.
	paper_basis = paper_basis.scaled(Vector3.ONE / lips_skeleton.global_basis.get_scale().y)
	var half_height := hair.sprite_frames.get_frame_texture(hair.animation,hair.frame).get_height() * hair.pixel_size * .5
	return Transform3D(paper_basis,Vector3(0,.3,0) - paper_basis.y * half_height)

func hold_hair_in_hand(paper_transform:Transform3D) -> void:
	hair_grip = BoneAttachment3D.new()
	hair_grip.name = "CabeloNaMao"
	hair_grip.bone_name = "Arm_Lower.R"
	lips_skeleton.add_child(hair_grip)
	hair.reparent(hair_grip, false)
	hair.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	hair.double_sided = true
	hair.transform = paper_transform
	attached = true

func pose_lips_hanging() -> void:
	if not lips_skeleton:
		return
	lips_skeleton.reset_bone_poses()
	# O eixo Y do braço aponta para o cotovelo; vira o braço inteiro para cima.
	aim_lips_arm("Arm_Upper.L", Vector3.UP)
	aim_lips_arm("Arm_Upper.R", Vector3(.12,-1,.25).normalized())
	aim_lips_arm("Arm_Lower.R", Vector3(.15,.2,1).normalized())
	set_lips_bone("Leg_Upper.L", .12 + sin(time * 3.0) * .06)
	set_lips_bone("Leg_Upper.R", -.14 + sin(time * 3.0) * .06)
	set_lips_bone("Leg_Lower.L", .25)
	set_lips_bone("Leg_Lower.R", .32)
	# Mantém a ponta da mão no mesmo ponto da fuselagem, inclusive no balanço.
	var lower := lips_skeleton.find_bone("Arm_Lower.L")
	var hand:Vector3 = lips_skeleton.get_bone_global_pose(lower) * Vector3(0,.3,0)
	var hand_in_plane:Vector3 = plane.to_local(lips_skeleton.to_global(hand))
	lips.position += PLANE_GRIP - hand_in_plane

func move(node:Node3D, destination:Vector3, duration:float) -> Tween:
	var tween := create_tween()
	tween.tween_property(node, "position", destination, duration * pace)
	return tween

func shot(actor:Node3D, offset:Vector3, target:Node3D, aim:Vector3, duration:float, first_person:bool = false, end_fov:float = 65.0) -> void:
	memory_flash()
	if camera_zoom and camera_zoom.is_valid():
		camera_zoom.kill()
	camera.fov = 65.0
	if end_fov < 65.0:
		camera_zoom = create_tween()
		camera_zoom.tween_property(camera, "fov", end_fov, duration * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	# Estende a mão antes de pegar o Cabelo pela borda, como uma folha de papel.
	lips_running = false
	lips_animation.stop()
	var paper_transform := paper_in_hand_transform()
	pose_lips_pickup()
	var right_arm := lips_skeleton.find_bone("Arm_Lower.R")
	var paper_target:Vector3 = (lips_skeleton.global_transform * lips_skeleton.get_bone_global_pose(right_arm) * paper_transform).origin
	arc(hair, to_local(paper_target), .5, 1.0)
	await shot(lips, Vector3(5, 3, 4), hair, Vector3.ZERO, 1.0)
	hold_hair_in_hand(paper_transform)
	lips_running = true
	animate(lips_animation, "Run")
	move(lips, Vector3(0, 0, -46), 11)
	move(plane, Vector3(0, 30, -64), 14)
	await shot(lips, Vector3(7, 5, 12), plane, Vector3.ZERO, 1.4)
	await shot(lips, Vector3(3.5, 3.8, 8), lips, Vector3.UP * 1.7, 4.6, false, 52)
	# O mesmo tempo do take antigo, repartido em ângulos distintos do mesmo trecho.
	await shot(lips, Vector3(-8.5, 2.8, 1.5), lips, Vector3.UP * 1.7, 1.7)
	await shot(lips, Vector3(1.5, 3.4, -8), lips, Vector3.UP * 1.7, 1.7)
	await shot(lips, Vector3(7.5, 3.2, -4.5), lips, Vector3.UP * 1.7, 1.6)
	lips_running = false
	lips.get_node("Visual").position.y = 1.8
	lips.get_node("Visual").rotation.z = 0.0
	animate(lips_animation, "Jump_Ascent")
	sound("res://assets/novos_audios/mario_part_sounds/lips_jump_grunt.mp3")
	POEIRA.saltar(self, lips.global_position)
	var lips_dust := POEIRA.rastro(lips)
	arc(lips, Vector3(.6, 23.4, -63.2), 8, 3)
	await shot(lips, Vector3(8, 1.5, 12), lips, Vector3.UP * 2.4, 3)
	lips.reparent(plane, true)
	lips_animation.stop()
	lips_hanging = true
	lips.position = Vector3(.6, -6.6, .8)
	pose_lips_hanging()
	POEIRA.apagar(lips_dust)
	await shot(lips, Vector3(11, -2, 17), lips, Vector3.UP * 2, 1.8)
	move(plane, Vector3(0, 42, -185), 26)
	maycon_entered = true
	maycon.visible = true
	maycon_running = true
	step_timer = 0.0
	move(maycon, Vector3(0, 0, -106), 18)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 3, true)
	await shot(maycon, Vector3(0, 1.65, -0.2), maycon, Vector3(0, 1.5, -20), 2, true)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 3, true)
	await shot(maycon, Vector3(-7, 3, 5), maycon, Vector3.UP * 1.1, 4, false, 48)
	await shot(maycon, Vector3(0, 1.65, -0.2), plane, Vector3.ZERO, 2, true)
	memory_flash()
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
	maycon_running = false
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
	var encontro:Vector3 = Vector3(0, 43, -198) + lips.position + Vector3(1, .4, 1)
	arc(maycon, encontro, 4, 2)
	await shot(maycon, Vector3(12, -2, 18), lips, Vector3.UP * 1.2, 2)
	sound("res://assets/novos_audios/punch_4.mp3")
	lips_hanging = false
	lips.reparent(self, true)
	animate(lips_animation, "Belly_Dive")
	# A pancada joga os dois de volta ao mesmo trampolim, ainda com Cabelo.
	var pouso:Vector3 = $Spring.position + Vector3(-.6, .85, 0)
	var queda := move(maycon, pouso, 4)
	queda.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var queda_lips := move(lips, pouso + Vector3(1.4, 0, .3), 4)
	queda_lips.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	move(plane, Vector3(0, 46, -265), 8)
	maycon.visible = true
	lips.visible = true
	await shot(maycon, Vector3(-10, 5, 18), maycon, Vector3.UP, 4)
	sound("res://assets/novos_audios/maycon_platform_landing.mp3")
	sound("res://assets/novos_audios/punch_4.mp3")
	POEIRA.pousar(self, $Spring.global_position)
	POEIRA.impulsionar(self, maycon.global_position)
	var spring_scale:Vector3 = $Spring.scale
	var quicar := create_tween()
	quicar.tween_property($Spring, "scale", spring_scale * Vector3(1.12,.55,1.12), .18 * pace)
	quicar.tween_property($Spring, "scale", spring_scale, .3 * pace).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(.18 * pace).timeout
	animate(maycon_animation, "Air_Flail")
	var rebote_poeira := POEIRA.rastro(maycon)
	# Avião segue para -z: o impulso cospe os dois no rumo oposto e muito mais alto.
	arc(maycon, Vector3(24, 168, 58), 26, 8)
	arc(lips, Vector3(27, 164, 60), 26, 8)
	# Primeiro mostra o segundo impulso; só então dissolve tudo em branco.
	memory_flash()
	follow = maycon
	follow_offset = Vector3(-12, 4, -22)
	focus = maycon
	focus_offset = Vector3.UP
	bob = false
	await get_tree().create_timer(1.0 * pace).timeout
	$HUD/Fade.color = Color(1,1,1,0)
	var fade := create_tween()
	fade.tween_property($HUD/Fade, "color:a", 1.0, 7.0 * pace).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_city_song(7.0 * pace)
	await fade.finished
	city_song.stop()
	POEIRA.apagar(rebote_poeira)
	Global.in_cutscene = false
	get_tree().change_scene_to_file(forest_scene)
