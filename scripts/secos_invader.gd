extends Node2D

const SURVIVAL_TIME:float = 90.0
const MAYCON_SCENE:PackedScene = preload("res://scenes/batalha_2d.tscn")
const SECO_SCENE:PackedScene = preload("res://scenes/inimigos/inimigo_boss_seco.tscn")
const BATTLE_MUSIC:AudioStream = preload("res://assets/novos_audios/battle.mp3")
const PUNCH_SOUND:AudioStream = preload("res://assets/novos_audios/punch_6.mp3")
const MAGIC_SOUND:AudioStream = preload("res://assets/novos_audios/inimigo_1_attack_magic.mp3")
const EXPLOSION_SOUND:AudioStream = preload("res://assets/novos_audios/seco_invader_boom_pixabay.mp3")
const CLOUD_SHADER:Shader = preload("res://scenes/secos_invader_clouds.gdshader")
const BLUR_SHADER:Shader = preload("res://scenes/secos_invader_blur.gdshader")
const FIREBALL_SCRIPT:Script = preload("res://scripts/secos_invader_fireball.gd")
const PAUSE_SCRIPT:Script = preload("res://scripts/secos_invader_pause.gd")
const DASH_SOUND:AudioStream = preload("res://assets/novos_audios/sliding.mp3")
const DASH_GAMEPAD_ICON:Texture2D = preload("res://assets/novas_imagens/buttons/360_A.png")
const DASH_KEYBOARD_ICON:Texture2D = preload("res://assets/novas_imagens/buttons/Blank_White_Super_Wide.png")

var screen:Vector2
var maycon:AnimatedSprite2D
var seco:AnimatedSprite2D
var music:AudioStreamPlayer
var punch:AudioStreamPlayer
var magic:AudioStreamPlayer
var explosion:AudioStreamPlayer
var dash_sound:AudioStreamPlayer
var title:Label
var hp_label:Label
var dash_button:Button
var start_label:Label
var finish_label:Label
var whiteout:ColorRect
var transition_black:ColorRect
var cloud_field:ColorRect
var blur_overlay:ColorRect
var fireball:Node2D
var pause_controller:CanvasLayer
var hp_bar:ProgressBar
var timeline:ProgressBar
var health:float
var max_health:float
var starting_health:float
var intro_time:float = 0.0
var elapsed:float = 0.0
var finale_time:float = 0.0
var shot_timer:float = 1.2
var seco_target_x:float = 0.0
var maycon_anchor:Vector2
var float_time:float = 0.0
var dash_time:float = 0.0
var dash_cooldown:float = 0.0
var dash_direction:Vector2 = Vector2.UP
var corner_push_time:float = 0.0
var corner_push_direction:Vector2 = Vector2.UP
var last_direction:Vector2 = Vector2.UP
var dash_ghost_time:float = 0.0
var invulnerable_time:float = 0.0
var blood_stain:float = 0.0
var phase:int = 0
var bullets:Array[Dictionary] = []
var blood:Array[Dictionary] = []
var sparks:Array[Dictionary] = []
var lines:Array[Dictionary] = []
var maycon_trail:Array[Dictionary] = []
var seco_trail:Array[Vector2] = []
var rng:RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	get_tree().paused = false
	rng.randomize()
	screen = get_viewport_rect().size
	seco_target_x = screen.x - 70.0
	max_health = Global.realtime_hp_max if Global.battle_mode == Global.battle_mode_realtime else 100.0
	starting_health = clampf(Global.realtime_hp, 1.0, max_health) if Global.battle_mode == Global.battle_mode_realtime else 100.0
	health = starting_health
	_build_clouds()
	_build_characters()
	_build_blur()
	_build_ui()
	pause_controller = CanvasLayer.new()
	pause_controller.name = "InvaderPause"
	pause_controller.set_script(PAUSE_SCRIPT)
	add_child(pause_controller)
	music = _sound(BATTLE_MUSIC, -12.0)
	punch = _sound(PUNCH_SOUND, -2.0)
	magic = _sound(MAGIC_SOUND, -13.0)
	explosion = _sound(EXPLOSION_SOUND, 3.0)
	explosion.pitch_scale = 0.68
	dash_sound = _sound(DASH_SOUND, -10.0)
	for i in range(30):
		lines.append({"x": rng.randf_range(0.0, screen.x), "y": rng.randf_range(0.0, screen.y), "length": rng.randf_range(100.0, 320.0), "speed": rng.randf_range(260.0, 540.0)})
	_update_hud()


func _build_clouds() -> void:
	var darkness:ColorRect = ColorRect.new()
	darkness.color = Color.BLACK
	darkness.size = screen
	darkness.z_index = -2
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(darkness)
	cloud_field = ColorRect.new()
	cloud_field.name = "DynamicClouds"
	cloud_field.size = screen
	cloud_field.z_index = -1
	cloud_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material:ShaderMaterial = ShaderMaterial.new()
	material.shader = CLOUD_SHADER
	cloud_field.material = material
	add_child(cloud_field)


func _build_characters() -> void:
	var battle_source:Node = MAYCON_SCENE.instantiate()
	var battle_sprite:AnimatedSprite2D = battle_source.get_node("Cenario de batalha/maycon_batalha")
	maycon = AnimatedSprite2D.new()
	maycon.name = "maycon_batalha"
	maycon.sprite_frames = battle_sprite.sprite_frames
	maycon.animation = "float"
	maycon.scale = Vector2(1.08, 1.08)
	maycon_anchor = Vector2(screen.x * 0.5, screen.y + 100.0)
	maycon.position = maycon_anchor
	add_child(maycon)
	maycon.play("float")
	battle_source.free()
	var seco_source:Node = SECO_SCENE.instantiate()
	seco = AnimatedSprite2D.new()
	seco.name = "inimigo_boss_seco"
	seco.sprite_frames = (seco_source as AnimatedSprite2D).sprite_frames
	seco.animation = "idle"
	seco.flip_h = true
	seco.scale = Vector2(0.8, 0.8)
	seco.position = Vector2(screen.x * 0.5, screen.y + 110.0)
	seco.visible = false
	add_child(seco)
	seco.play("idle")
	seco_source.free()
	fireball = Node2D.new()
	fireball.name = "SecoPurpleFire"
	fireball.z_index = 10
	fireball.visible = false
	fireball.set_script(FIREBALL_SCRIPT)
	add_child(fireball)


func _build_blur() -> void:
	blur_overlay = ColorRect.new()
	blur_overlay.name = "MotionBlur"
	blur_overlay.size = screen
	blur_overlay.z_index = 30
	blur_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_material:ShaderMaterial = ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	blur_overlay.material = blur_material
	add_child(blur_overlay)


func _build_ui() -> void:
	var hud:CanvasLayer = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	whiteout = ColorRect.new()
	whiteout.color = Color(1.0, 1.0, 1.0, 0.0)
	whiteout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	whiteout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(whiteout)
	title = Label.new()
	title.text = tr("SECO_INVADER_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.92, 0.85, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.6, 0.05, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.position = Vector2(0.0, screen.y * 0.44)
	title.size = Vector2(screen.x, 100.0)
	title.modulate.a = 0.0
	hud.add_child(title)
	hp_label = Label.new()
	hp_label.text = tr("UI_HEALTH")
	hp_label.position = Vector2(20.0, 11.0)
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.visible = false
	hud.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(20.0, 38.0)
	hp_bar.size = Vector2(132.0, 12.0)
	hp_bar.max_value = max_health
	hp_bar.show_percentage = false
	var hp_background:StyleBoxFlat = StyleBoxFlat.new()
	hp_background.bg_color = Color(0.08, 0.02, 0.06, 0.9)
	hp_background.border_color = Color(0.75, 0.11, 0.16)
	hp_background.set_border_width_all(2)
	hp_bar.add_theme_stylebox_override("background", hp_background)
	var hp_fill:StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.72, 0.015, 0.06)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.visible = false
	hud.add_child(hp_bar)
	dash_button = Button.new()
	dash_button.position = Vector2(165.0, 17.0)
	dash_button.size = Vector2(124.0, 32.0)
	dash_button.clip_contents = true
	dash_button.visible = false
	dash_button.pressed.connect(_try_dash)
	hud.add_child(dash_button)
	var gamepad_icon:Sprite2D = Sprite2D.new()
	gamepad_icon.texture = DASH_GAMEPAD_ICON
	gamepad_icon.position = Vector2(16.0, 16.0)
	gamepad_icon.scale = Vector2(0.22, 0.22)
	dash_button.add_child(gamepad_icon)
	var separator:Label = Label.new()
	separator.text = "/"
	separator.position = Vector2(29.0, 8.0)
	separator.add_theme_font_size_override("font_size", 11)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_button.add_child(separator)
	var keyboard_icon:Sprite2D = Sprite2D.new()
	keyboard_icon.texture = DASH_KEYBOARD_ICON
	keyboard_icon.position = Vector2(57.0, 16.0)
	keyboard_icon.scale = Vector2(0.38, 0.38)
	dash_button.add_child(keyboard_icon)
	var keyboard_label:Label = Label.new()
	keyboard_label.text = tr("SECO_INVADER_SPACE_KEY")
	keyboard_label.position = Vector2(38.0, 11.0)
	keyboard_label.size = Vector2(38.0, 11.0)
	keyboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyboard_label.add_theme_font_size_override("font_size", 7)
	keyboard_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.17))
	keyboard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_button.add_child(keyboard_label)
	var dash_label:Label = Label.new()
	dash_label.text = tr("POWER_DASH")
	dash_label.position = Vector2(81.0, 7.0)
	dash_label.add_theme_font_size_override("font_size", 11)
	dash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_button.add_child(dash_label)
	timeline = ProgressBar.new()
	timeline.position = Vector2(screen.x - 43.0, 76.0)
	timeline.size = Vector2(13.0, screen.y - 145.0)
	timeline.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	timeline.show_percentage = false
	var timeline_background:StyleBoxFlat = StyleBoxFlat.new()
	timeline_background.bg_color = Color(0.06, 0.08, 0.15, 0.85)
	timeline.add_theme_stylebox_override("background", timeline_background)
	var timeline_fill:StyleBoxFlat = StyleBoxFlat.new()
	timeline_fill.bg_color = Color(0.34, 0.62, 1.0)
	timeline.add_theme_stylebox_override("fill", timeline_fill)
	timeline.visible = false
	hud.add_child(timeline)
	finish_label = Label.new()
	finish_label.text = tr("SECO_INVADER_END")
	finish_label.position = Vector2(screen.x - 145.0, 45.0)
	finish_label.size = Vector2(105.0, 25.0)
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	finish_label.visible = false
	hud.add_child(finish_label)
	start_label = Label.new()
	start_label.text = tr("SECO_INVADER_START")
	start_label.position = Vector2(screen.x - 145.0, screen.y - 57.0)
	start_label.size = Vector2(105.0, 25.0)
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	start_label.visible = false
	hud.add_child(start_label)
	transition_black = ColorRect.new()
	transition_black.color = Color.BLACK
	transition_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(transition_black)


func _sound(stream:AudioStream, volume:float) -> AudioStreamPlayer:
	var player:AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func set_invader_paused(paused:bool) -> void:
	for player in [music, punch, magic, explosion, dash_sound]:
		player.stream_paused = paused


func _process(delta:float) -> void:
	if phase == 0:
		_update_intro(delta)
	elif phase == 1:
		_update_survival(delta)
	elif phase == 2:
		_update_finale(delta)
	_update_atmosphere(delta)
	_update_effects(delta)
	queue_redraw()


func _update_intro(delta:float) -> void:
	intro_time += delta
	transition_black.color.a = clampf(1.0 - intro_time / 1.15, 0.0, 1.0)
	var rise:float = smoothstep(0.0, 2.55, intro_time)
	maycon_anchor.y = lerpf(screen.y + 100.0, screen.y * 0.3, rise)
	maycon.position = maycon_anchor + Vector2(sin(float_time * 2.3) * 5.0, sin(float_time * 3.8) * 6.0)
	if intro_time >= 2.55:
		seco.visible = true
		fireball.visible = true
		seco.position.y = lerpf(screen.y + 110.0, screen.y - 105.0, smoothstep(2.55, 4.9, intro_time))
	if intro_time >= 3.55 && intro_time - delta < 3.55:
		title.modulate.a = 1.0
		punch.play()
		_spawn_sparks(Vector2(screen.x * 0.5, screen.y * 0.49), 45, Color(0.65, 0.17, 1.0))
	if intro_time > 5.1:
		title.modulate.a = maxf(0.0, 1.0 - (intro_time - 5.1) * 0.78)
	if intro_time >= 6.45:
		phase = 1
		title.visible = false
		hp_label.visible = true
		hp_bar.visible = true
		dash_button.visible = true
		timeline.visible = true
		start_label.visible = true
		finish_label.visible = true
		music.play()


func _update_survival(delta:float) -> void:
	elapsed += delta
	var progress:float = minf(1.0, elapsed / SURVIVAL_TIME)
	var input_direction:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction.length() > 0.15:
		last_direction = input_direction.normalized()
	var corner_width:float = screen.x * 0.065
	if corner_push_time <= 0.0 && maycon_anchor.y > screen.y * 0.63 && (maycon_anchor.x < 38.0 + corner_width || maycon_anchor.x > screen.x - 85.0 - corner_width):
		corner_push_time = 0.24
		corner_push_direction = (Vector2(screen.x * 0.5, screen.y * 0.5) - maycon_anchor).normalized()
		dash_time = 0.0
		_spawn_sparks(maycon.position, 20, Color(0.32, 0.76, 1.0))
	if Input.is_action_just_pressed("ui_accept"):
		_try_dash()
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if corner_push_time > 0.0:
		corner_push_time = maxf(0.0, corner_push_time - delta)
		maycon_anchor = maycon_anchor.move_toward(Vector2(screen.x * 0.5, screen.y * 0.5), 380.0 * delta)
	elif dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		maycon_anchor += dash_direction * 1050.0 * delta
		dash_ghost_time -= delta
		if dash_ghost_time <= 0.0:
			dash_ghost_time = 0.025
			_spawn_sparks(maycon.position, 9, Color(0.56, 0.65, 1.0))
	else:
		maycon_anchor += input_direction * (300.0 + progress * 65.0) * delta
	maycon_anchor.x = clampf(maycon_anchor.x, 38.0, screen.x - 85.0)
	maycon_anchor.y = clampf(maycon_anchor.y, 78.0, screen.y * 0.7)
	maycon.position = maycon_anchor + Vector2(sin(float_time * 2.0) * 8.0, sin(float_time * 3.4) * 8.0)
	var steering_direction:Vector2 = corner_push_direction if corner_push_time > 0.0 else (dash_direction if dash_time > 0.0 else input_direction)
	var target_rotation:float = Vector2.UP.angle_to(steering_direction) if steering_direction.length() > 0.15 else 0.0
	maycon.rotation = lerp_angle(maycon.rotation, target_rotation + sin(float_time * 1.7) * 0.035, 1.0 - exp(-3.4 * delta))
	if absf(seco.position.x - seco_target_x) < 7.0:
		seco_target_x = 68.0 if seco_target_x > screen.x * 0.5 else screen.x - 68.0
	seco.position.x = move_toward(seco.position.x, seco_target_x, (230.0 + progress * 440.0) * delta)
	seco.position.y = screen.y - 105.0 + sin(elapsed * 3.0) * 9.0
	fireball.position = seco.position + Vector2(-42.0, -8.0)
	if seco.animation != "attack_2" && !seco.is_playing():
		seco.play("idle")
	shot_timer -= delta
	if shot_timer <= 0.0:
		_fire_power(progress)
		shot_timer = lerpf(2.2, 0.22, progress) * rng.randf_range(0.78, 1.25)
	if invulnerable_time > 0.0:
		invulnerable_time -= delta
		maycon.modulate.a = 0.5 if fmod(elapsed * 14.0, 2.0) < 1.0 else 1.0
	else:
		maycon.modulate.a = 1.0
	_update_bullets(delta, progress)
	music.pitch_scale = 0.82 + progress * 0.8
	_update_hud()
	if elapsed >= SURVIVAL_TIME:
		phase = 2
		bullets.clear()
		seco.play("attack_2")
		_fire_power(1.0, true)


func _try_dash() -> void:
	if phase != 1 or dash_cooldown > 0.0 or corner_push_time > 0.0 or get_tree().paused:
		return
	var direction:Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	dash_direction = direction.normalized() if direction.length() > 0.15 else last_direction
	dash_time = 0.22
	dash_cooldown = 0.78
	dash_ghost_time = 0.0
	dash_sound.pitch_scale = rng.randf_range(1.3, 1.6)
	dash_sound.play()
	_spawn_sparks(maycon.position, 65, Color(0.46, 0.68, 1.0))
	Input.start_joy_vibration(0, 0.25, 0.4, 0.15)


func _fire_power(progress:float, giant:bool = false) -> void:
	seco.play("attack_2")
	var origin:Vector2 = fireball.position
	var target_x:float = rng.randf_range(50.0, screen.x - 100.0) if rng.randf() < 0.45 else clampf(maycon.position.x + rng.randf_range(-75.0, 75.0), 50.0, screen.x - 100.0)
	var velocity:Vector2 = Vector2(target_x - origin.x, -screen.y * 0.9).normalized() * (360.0 + 340.0 * progress)
	bullets.append({"position": origin, "velocity": velocity, "radius": 24.0 if !giant else screen.x * 0.47, "giant": giant, "trail": [origin], "spin": rng.randf_range(0.0, TAU)})
	_spawn_sparks(origin, 18 if !giant else 70, Color(0.74, 0.22, 1.0))
	fireball.call("burst")
	magic.pitch_scale = 0.8 + progress * 0.6
	magic.play()


func _update_bullets(delta:float, progress:float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet:Dictionary = bullets[i]
		bullet.position += bullet.velocity * delta
		bullet.trail.push_front(bullet.position)
		if bullet.trail.size() > 10:
			bullet.trail.pop_back()
		if rng.randf() < minf(1.0, delta * 75.0):
			_spawn_sparks(bullet.position + Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(-16.0, 16.0)), 2, Color(0.82, 0.3, 1.0))
		bullets[i] = bullet
		if bullet.position.y < -100.0:
			bullets.remove_at(i)
			continue
		if invulnerable_time <= 0.0 && dash_time <= 0.0 && bullet.position.distance_to(maycon.position) < bullet.radius + 22.0:
			bullets.remove_at(i)
			_take_hit(13.0 + progress * 7.0)


func _take_hit(damage:float) -> void:
	health = maxf(0.0, health - damage)
	if Global.battle_mode == Global.battle_mode_realtime:
		Global.realtime_hp = health
	invulnerable_time = 0.95
	punch.play()
	_spawn_blood(maycon.position)
	_spawn_sparks(maycon.position, 25, Color(0.95, 0.1, 0.2))
	_update_hud()
	if health <= 0.0:
		Global.realtime_hp = starting_health if Global.battle_mode == Global.battle_mode_realtime else Global.realtime_hp
		get_tree().change_scene_to_file.call_deferred("res://scenes/secos_invader.tscn")
		set_process(false)


func _update_finale(delta:float) -> void:
	finale_time += delta
	if bullets.size() > 0:
		var bullet:Dictionary = bullets[0]
		bullet.position.y -= 950.0 * delta
		bullet.radius += 170.0 * delta
		bullets[0] = bullet
	if finale_time > 0.58 && finale_time - delta <= 0.58:
		explosion.play()
		music.stop()
		_spawn_sparks(maycon.position, 120, Color.WHITE)
	whiteout.color.a = clampf((finale_time - 0.58) * 2.4, 0.0, 1.0)
	if finale_time >= 2.0:
		get_tree().change_scene_to_file.call_deferred("res://scenes/3D/maycon_platform_3d.tscn")
		set_process(false)


func _update_atmosphere(delta:float) -> void:
	float_time += delta
	var progress:float = clampf(elapsed / SURVIVAL_TIME, 0.0, 1.0)
	(cloud_field.material as ShaderMaterial).set_shader_parameter("speed_multiplier", 1.0 + progress * 2.0)
	var blur_strength:float = lerpf(0.013, 0.0011, smoothstep(0.0, 2.7, intro_time)) if phase == 0 else 0.0011 + progress * 0.0014 + (0.002 if dash_time > 0.0 else 0.0)
	(blur_overlay.material as ShaderMaterial).set_shader_parameter("strength", blur_strength)
	fireball.position = seco.position + Vector2(-42.0, -8.0)
	for line in lines:
		line.y += line.speed * (1.0 + progress * 3.5) * delta
		if line.y > screen.y + line.length:
			line.y = -line.length
			line.x = rng.randf_range(0.0, screen.x)
	maycon_trail.push_front({"position": maycon.position, "rotation": maycon.rotation})
	seco_trail.push_front(seco.position)
	if maycon_trail.size() > (22 if dash_time > 0.0 or corner_push_time > 0.0 else 14):
		maycon_trail.pop_back()
	if seco_trail.size() > 11:
		seco_trail.pop_back()
	if seco.visible:
		for i in range(3 if phase == 0 else 5):
			_spawn_sparks(seco.position + Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-35.0, 35.0)), 1, Color(0.61, 0.16, 1.0))


func _update_effects(delta:float) -> void:
	for i in range(sparks.size() - 1, -1, -1):
		var spark:Dictionary = sparks[i]
		spark.position += spark.velocity * delta
		spark.life -= delta
		if spark.life <= 0.0:
			sparks.remove_at(i)
	for i in range(blood.size() - 1, -1, -1):
		var drop:Dictionary = blood[i]
		drop.velocity.y += 180.0 * delta
		drop.position += drop.velocity * delta
		if drop.position.distance_to(seco.position) < 48.0:
			blood_stain = minf(1.0, blood_stain + 0.04)
			seco.modulate = Color(1.0, 1.0 - blood_stain * 0.3, 1.0 - blood_stain * 0.3)
			blood.remove_at(i)
		elif drop.position.y > screen.y + 40.0:
			blood.remove_at(i)


func _spawn_sparks(at:Vector2, count:int, color:Color) -> void:
	for i in range(count):
		var angle:float = rng.randf_range(0.0, TAU)
		var speed:float = rng.randf_range(70.0, 300.0)
		sparks.append({"position": at, "velocity": Vector2.RIGHT.rotated(angle) * speed, "life": rng.randf_range(0.2, 0.75), "color": color})


func _spawn_blood(at:Vector2) -> void:
	for i in range(35):
		blood.append({"position": at, "velocity": Vector2(rng.randf_range(-180.0, 180.0), rng.randf_range(-190.0, 150.0)), "radius": rng.randf_range(2.0, 6.0)})


func _update_hud() -> void:
	hp_bar.value = health
	dash_button.disabled = dash_cooldown > 0.0
	dash_button.modulate = Color(0.58, 0.58, 0.68) if dash_button.disabled else Color.WHITE
	timeline.value = clampf(elapsed / SURVIVAL_TIME * 100.0, 0.0, 100.0)


func _draw() -> void:
	for line in lines:
		draw_line(Vector2(line.x, line.y - line.length), Vector2(line.x, line.y), Color(0.12, 0.52, 1.0, 0.22), 1.0)
	for i in range(maycon_trail.size() - 1, -1, -1):
		var alpha:float = (1.0 - float(i) / float(maxi(1, maycon_trail.size()))) * (0.30 if dash_time > 0.0 or corner_push_time > 0.0 or phase == 0 else 0.15)
		var texture:Texture2D = maycon.sprite_frames.get_frame_texture("float", maycon.frame)
		draw_set_transform(maycon_trail[i].position, maycon_trail[i].rotation)
		draw_texture_rect(texture, Rect2(-texture.get_size() * maycon.scale * 0.5, texture.get_size() * maycon.scale), false, Color(0.42, 0.68, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)
	if corner_push_time > 0.0:
		var push_alpha:float = corner_push_time / 0.24
		draw_arc(maycon.position, 35.0 + (1.0 - push_alpha) * 28.0, 0.0, TAU, 48, Color(0.3, 0.75, 1.0, push_alpha * 0.65), 2.0)
	for i in range(seco_trail.size() - 1, -1, -1):
		draw_circle(seco_trail[i], 34.0 + i * 2.0, Color(0.44, 0.07, 0.9, (1.0 - float(i) / 9.0) * 0.045))
	for bullet in bullets:
		var point:Vector2 = bullet.position
		var radius:float = bullet.radius
		for i in range(bullet.trail.size() - 1, -1, -1):
			var trail_alpha:float = (1.0 - float(i) / float(maxi(1, bullet.trail.size()))) * 0.18
			draw_circle(bullet.trail[i], radius * (0.72 - float(i) * 0.045), Color(0.55, 0.08, 1.0, trail_alpha))
		for j in range(5, 0, -1):
			draw_circle(point, radius * (1.0 + j * 0.32), Color(0.5, 0.06, 1.0, 0.035))
		draw_circle(point, radius, Color(0.43, 0.03, 0.72, 0.95))
		draw_circle(point, radius * 0.62, Color(0.8, 0.34, 1.0, 0.94))
		draw_circle(point, radius * 0.29, Color(1.0, 0.88, 1.0))
		for orbit in range(7):
			var angle:float = float(orbit) * TAU / 7.0 + float(bullet.spin) + float_time * 4.0
			var orbit_point:Vector2 = point + Vector2.RIGHT.rotated(angle) * radius * 1.35
			draw_circle(orbit_point, maxf(3.0, radius * 0.12), Color(0.9, 0.35, 1.0, 0.8))
			draw_line(point + Vector2.RIGHT.rotated(angle) * radius * 0.8, orbit_point, Color(0.76, 0.3, 1.0, 0.65), 2.0)
		draw_arc(point, radius * 1.14, float_time * 3.0, float_time * 3.0 + PI * 1.25, 30, Color(0.92, 0.48, 1.0, 0.64), 2.0)
	for spark in sparks:
		draw_line(spark.position, spark.position - spark.velocity * 0.035, Color(spark.color.r, spark.color.g, spark.color.b, clampf(spark.life * 1.6, 0.0, 1.0)), 3.0)
	for drop in blood:
		draw_circle(drop.position, drop.radius, Color(0.7, 0.02, 0.04))
