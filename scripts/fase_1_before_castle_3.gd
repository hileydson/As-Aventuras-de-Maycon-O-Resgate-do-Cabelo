extends Sprite2D

const INTRO_BLUR_SHADER:Shader = preload("res://scenes/secos_invader_blur.gdshader")

@onready var animacoes: AnimationPlayer = $animacoes
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var back_from_slum: Marker2D = $"../back_from_slum"
@onready var pos_passagem_pestilenta: Marker2D = $"../pos_passagem_pestilenta"
@onready var seco: AnimatedSprite2D = $"../inimigo_boss_seco"
var entering_well:bool = false
var seco_intro_started:bool = false
var seco_intro_time:float = 0.0
var intro_camera:Camera2D
var intro_kick:AudioStreamPlayer
var intro_scream:AudioStreamPlayer
var intro_blur:ColorRect
var intro_black:ColorRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_progress(get_tree().current_scene.name)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"

	if Global.from_slum:
		GameSongs.play_song(1)
		Global.from_slum = false
		maycon_fase.global_position = back_from_slum.global_position
	if Global.game_events.get("passagem_pestilenta_feita", false):
		maycon_fase.global_position = pos_passagem_pestilenta.global_position
	var seco_original:AnimatedSprite2D = seco
	seco = AnimatedSprite2D.new()
	seco.name = "seco_intro"
	seco.sprite_frames = seco_original.sprite_frames
	seco.position = seco_original.global_position
	seco.rotation = seco_original.global_rotation
	seco.scale = seco_original.global_scale
	seco.flip_h = seco_original.flip_h
	seco.z_index = seco_original.z_index
	get_tree().current_scene.add_child.call_deferred(seco)
	seco_original.queue_free()
	seco.visible = false
	intro_kick = AudioStreamPlayer.new()
	intro_kick.stream = preload("res://assets/novos_audios/kick.mp3")
	add_child(intro_kick)
	intro_scream = AudioStreamPlayer.new()
	intro_scream.stream = preload("res://assets/novos_audios/seco_scream.mp3")
	intro_scream.volume_db = -5.0
	add_child(intro_scream)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !seco.is_inside_tree():
		return
	if seco_intro_started:
		_update_seco_intro(delta)
		return
	if entering_well:
		return
	if !entering_well && !Global.battle_started && maycon_fase.global_position.x >= seco.global_position.x - 35.0 && maycon_fase.global_position.x < 3170.0:
		_start_seco_intro()
		return
	
	# previne bug da batalha iniciar e nao haver collision com o maycon
	if Global.battle_started:
		maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
	#pra VOLTAR
	if Global.back_to_main_camera:
		Global.back_to_main_camera = false
		camera.make_current()


	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout


func _on_next_scene_body_entered(body: Node2D) -> void:
	if body != maycon_fase or entering_well:
		return
	_start_seco_intro()


func _start_seco_intro() -> void:
	if entering_well:
		return
	entering_well = true
	seco_intro_started = true
	var battle_intro:AnimationPlayer = get_tree().current_scene.get_node_or_null("battle/Cenario de batalha/batalha_moves") as AnimationPlayer
	if battle_intro && battle_intro.has_method("suppress_opening_explosion"):
		battle_intro.suppress_opening_explosion()
	for song in GameSongs.get_children():
		if song is AudioStreamPlayer:
			song.stop()
	var battle_song:AudioStreamPlayer2D = get_tree().current_scene.get_node_or_null("battle/Cenario de batalha/Battle_Song") as AudioStreamPlayer2D
	if battle_song:
		battle_song.stop()
	intro_scream.play()
	maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	maycon_fase.velocity = Vector2.ZERO
	seco.visible = true
	seco.play("idle")
	intro_camera = Camera2D.new()
	intro_camera.zoom = camera.zoom
	intro_camera.global_position = camera.global_position
	intro_camera.limit_left = -100000
	intro_camera.limit_top = -100000
	intro_camera.limit_right = 100000
	intro_camera.limit_bottom = 100000
	get_tree().current_scene.add_child(intro_camera)
	intro_camera.make_current()
	camera.enabled = false
	var blur_layer:CanvasLayer = CanvasLayer.new()
	blur_layer.layer = 10
	get_tree().current_scene.add_child(blur_layer)
	intro_blur = ColorRect.new()
	intro_blur.size = get_viewport_rect().size
	intro_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_blur.visible = false
	var blur_material:ShaderMaterial = ShaderMaterial.new()
	blur_material.shader = INTRO_BLUR_SHADER
	intro_blur.material = blur_material
	blur_layer.add_child(intro_blur)
	intro_black = ColorRect.new()
	intro_black.color = Color(0.0, 0.0, 0.0, 0.0)
	intro_black.size = get_viewport_rect().size
	intro_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_layer.add_child(intro_black)


func _update_seco_intro(delta:float) -> void:
	seco_intro_time += delta
	queue_redraw()
	intro_blur.visible = seco_intro_time >= 1.15
	(intro_blur.material as ShaderMaterial).set_shader_parameter("strength", clampf((seco_intro_time - 1.15) * 0.02, 0.0, 0.016))
	intro_black.color.a = clampf((seco_intro_time - 1.65) / 0.8, 0.0, 1.0)
	var seco_position:Vector2 = seco.global_position
	var maycon_position:Vector2 = maycon_fase.global_position
	if seco_intro_time < 0.8:
		seco.global_position = seco_position.move_toward(Vector2(maycon_position.x, maycon_position.y + 180.0), 610.0 * delta)
		intro_camera.global_position = intro_camera.global_position.lerp(seco.global_position, minf(1.0, delta * 7.0))
		intro_camera.zoom = intro_camera.zoom.lerp(Vector2(1.15, 1.15), minf(1.0, delta * 5.0))
		if seco_intro_time > 0.45 && seco.animation != "attack":
			seco.play("attack")
	elif seco_intro_time < 1.15:
		seco.global_position = seco_position.move_toward(maycon_position, 1000.0 * delta)
		intro_camera.global_position = intro_camera.global_position.lerp(seco.global_position, minf(1.0, delta * 7.0))
	elif seco_intro_time < 2.45:
		if seco_intro_time - delta < 1.15:
			create_tween().tween_property(intro_scream, "volume_db", -30.0, 0.8)
			intro_kick.play()
			var maycon_scream:AudioStreamPlayer = AudioStreamPlayer.new()
			maycon_scream.stream = preload("res://assets/novos_audios/maycon_falling_fase_1_transition.mp3")
			maycon_scream.volume_db = -3.0
			Global.add_child(maycon_scream)
			maycon_scream.finished.connect(maycon_scream.queue_free)
			maycon_scream.play()
			var dimensional_whoosh:AudioStreamPlayer = AudioStreamPlayer.new()
			dimensional_whoosh.stream = preload("res://assets/novos_audios/seco_kick_dimensional_whoosh_pixabay.mp3")
			dimensional_whoosh.volume_db = -9.0
			add_child(dimensional_whoosh)
			dimensional_whoosh.play()
			var whoosh_fade:Tween = create_tween()
			whoosh_fade.tween_interval(0.55)
			whoosh_fade.tween_property(dimensional_whoosh, "volume_db", -45.0, 0.65)
			whoosh_fade.tween_callback(dimensional_whoosh.queue_free)
			Input.start_joy_vibration(0, 0.8, 0.8, 0.25)
		maycon_fase.global_position += Vector2(0.0, -1700.0 * delta)
		seco.global_position += Vector2(0.0, -1580.0 * delta)
		intro_camera.global_position = intro_camera.global_position.lerp(maycon_fase.global_position, minf(1.0, delta * 8.0))
		intro_camera.zoom = intro_camera.zoom.lerp(Vector2(0.7, 0.7), minf(1.0, delta * 5.0))
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/secos_invader.tscn")
		seco_intro_started = false


func _draw() -> void:
	if !seco_intro_started or seco_intro_time < 1.15:
		return
	var center:Vector2 = to_local(maycon_fase.global_position)
	var force:float = clampf((seco_intro_time - 1.15) * 1.6, 0.0, 1.0)
	for i in range(32):
		var x:float = center.x + sin(float(i) * 37.1) * 900.0
		var y:float = center.y + fmod(float(i) * 197.0 + seco_intro_time * 700.0, 1050.0) - 525.0
		draw_line(Vector2(x, y - 100.0 - force * 500.0), Vector2(x, y), Color(0.4, 0.7, 1.0, force * 0.65), 2.0)


func _on_dead_line_body_entered(body: Node2D) -> void:
	if body != maycon_fase || entering_well:
		return
	entering_well = true
	var battle_intro:AnimationPlayer = get_tree().current_scene.get_node_or_null("battle/Cenario de batalha/batalha_moves") as AnimationPlayer
	if battle_intro && battle_intro.has_method("suppress_opening_explosion"):
		battle_intro.suppress_opening_explosion()
	maycon_fase.velocity = Vector2.ZERO
	maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	Global.start_well_entry_scream()
	var fade_layer:CanvasLayer = CanvasLayer.new()
	fade_layer.layer = 100
	get_parent().add_child(fade_layer)
	var blackout:ColorRect = ColorRect.new()
	blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(blackout)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade_tween:Tween = create_tween()
	fade_tween.tween_property(blackout, "color:a", 1.0, 0.85)
	await fade_tween.finished
	get_tree().change_scene_to_file("res://scenes/3D/poco_infinito.tscn")


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_2.tscn")


func _on_portal_slum_body_entered(body: Node2D) -> void:
	_on_dead_line_body_entered(body)
