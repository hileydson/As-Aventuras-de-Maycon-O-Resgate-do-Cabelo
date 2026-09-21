extends Node2D

const ARENA_WIDTH:float = 2600.0
const MIN_Y:float = 315.0
const MAX_Y:float = 585.0
const PLAYER_SPEED:float = 285.0

const ENEMY_SCENES = {
	"1":"res://scenes/inimigos/inimigo_camilita.tscn",
	"2":"res://scenes/inimigos/inimigo_bomba_pretti.tscn",
	"3":"res://scenes/inimigos/inimigo_fofo.tscn",
	"4":"res://scenes/inimigos/inimigo_xuruzika.tscn",
	"5":"res://scenes/inimigos/inimigo_manga.tscn",
	"1001":"res://scenes/inimigos/inimigo_boss_seco.tscn"
}

const ENEMY_STATS = {
	"1":{"name":"Camilita", "hp":70.0, "speed":145.0, "damage":12.0, "scale":1.05},
	"2":{"name":"Bomba Pretti", "hp":110.0, "speed":120.0, "damage":17.0, "scale":1.0},
	"3":{"name":"Fofo", "hp":140.0, "speed":105.0, "damage":20.0, "scale":1.12},
	"4":{"name":"Xuruzika", "hp":90.0, "speed":185.0, "damage":14.0, "scale":0.95},
	"5":{"name":"Manga", "hp":120.0, "speed":155.0, "damage":18.0, "scale":2.3},
	"1001":{"name":"Seco", "hp":260.0, "speed":165.0, "damage":24.0, "scale":1.28}
}

var player:AnimatedSprite2D
var enemy:AnimatedSprite2D
var camera:Camera2D
var stage_3d:CanvasLayer
var background_layer:Node2D
var player_bar:ProgressBar
var enemy_bar:ProgressBar
var enemy_name_label:Label
var status_label:Label
var combo_label:Label
var exit_label:Label
var battle_song:AudioStreamPlayer
var punch_sound:AudioStreamPlayer
var kick_sound:AudioStreamPlayer
var hit_sound:AudioStreamPlayer
var hurt_sound:AudioStreamPlayer
var enemy_death_sound:AudioStreamPlayer
var victory_sound:AudioStreamPlayer

var player_position := Vector2(280, 500)
var enemy_position := Vector2(1060, 475)
var player_hp:float = 210.0
var player_max_hp:float = 210.0
var enemy_hp:float = 100.0
var enemy_max_hp:float = 100.0
var enemy_speed:float = 135.0
var enemy_damage:float = 15.0
var enemy_name:String = "Enemy"
var enemy_id:String = "1"
var player_base_scale:float = 2.6
var enemy_base_scale:float = 1.0

var player_attack_time:float = 0.0
var player_invulnerability:float = 0.0
var dodge_time:float = 0.0
var dodge_cooldown:float = 0.0
var dodge_direction := Vector2.RIGHT
var enemy_attack_time:float = 0.0
var enemy_cooldown:float = 0.8
var enemy_hit_pending:bool = false
var enemy_dead:bool = false
var player_dead:bool = false
var exit_open:bool = false
var leaving:bool = false
var combo:int = 0
var combo_timeout:float = 0.0
var shake_strength:float = 0.0
var shake_time:float = 0.0
var droplets:Array[Dictionary] = []
var stains:Array[Dictionary] = []
var impacts:Array[Dictionary] = []
var intro_time:float = 1.45
var enemy_behavior:String = "approach"
var enemy_behavior_time:float = 0.0
var enemy_decision_cooldown:float = 1.0
var enemy_teleport_cooldown:float = 2.8
var enemy_pressure:int = 0
var enemy_strafe_direction := Vector2(0.0, 1.0)
var enemy_cover_target := Vector2.ZERO
var teleport_moved:bool = false
var enemy_explosion_time:float = 0.0
var transition_top:ColorRect
var transition_bottom:ColorRect
var transition_flash:ColorRect
var intro_label:Label

func _ready() -> void:
	randomize()
	enemy_id = Global.realtime_enemy_id if ENEMY_SCENES.has(Global.realtime_enemy_id) else "1"
	player_max_hp = Global.realtime_hp_max
	player_hp = clampf(Global.realtime_hp, 1.0, player_max_hp)
	build_background()
	build_fighters()
	build_world_bars()
	build_hud()
	build_audio()
	camera = Camera2D.new()
	camera.position = Vector2(576, 324)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_right = int(ARENA_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 648
	add_child(camera)
	camera.make_current()
	Global.battle_started = true
	status_label.text = tr_text("DERROTE %s E AVANCE", "DEFEAT %s AND MOVE FORWARD") % enemy_name.to_upper()
	battle_song.play()
	start_entry_sequence()
	queue_redraw()

func build_background() -> void:
	stage_3d = preload("res://scripts/realtime_battle_3d.gd").new()
	stage_3d.theme_id = Global.realtime_arena_theme
	stage_3d.arena_width = ARENA_WIDTH
	add_child(stage_3d)
	background_layer = preload("res://scripts/realtime_battle_background.gd").new()
	background_layer.theme_id = Global.realtime_arena_theme
	background_layer.arena_width = ARENA_WIDTH
	background_layer.z_index = -100
	add_child(background_layer)

func build_fighters() -> void:
	player = sprite_from_scene("res://scenes/maycon_fase.tscn", true)
	player.name = "MayconRealtime"
	var player_texture = player.sprite_frames.get_frame_texture("idle_right", 0)
	if player_texture:
		player_base_scale = 205.0 / maxf(1.0, player_texture.get_height())
	player.scale = Vector2(player_base_scale, player_base_scale)
	player.play("idle_right")
	add_child(player)

	var stats:Dictionary = ENEMY_STATS[enemy_id]
	enemy_name = stats.name
	enemy_max_hp = stats.hp
	enemy_hp = enemy_max_hp
	enemy_speed = stats.speed
	enemy_damage = stats.damage
	enemy = sprite_from_scene(ENEMY_SCENES[enemy_id], false)
	enemy.name = "EnemyRealtime"
	enemy.play("idle")
	var enemy_texture = enemy.sprite_frames.get_frame_texture("idle", 0)
	if enemy_texture:
		enemy_base_scale = (170.0 * float(stats.scale)) / maxf(1.0, enemy_texture.get_height())
	enemy.scale = Vector2(enemy_base_scale, enemy_base_scale)
	add_child(enemy)
	update_fighter_transforms()

func sprite_from_scene(path:String, nested_sprite:bool) -> AnimatedSprite2D:
	var source = load(path).instantiate()
	var source_sprite:AnimatedSprite2D = source.get_node("AnimatedSprite2D") if nested_sprite else source
	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = source_sprite.sprite_frames
	sprite.centered = source_sprite.centered
	sprite.offset = source_sprite.offset
	source.free()
	return sprite

func build_world_bars() -> void:
	player_bar = create_health_bar(Color("2dc653"), 118)
	enemy_bar = create_health_bar(Color("e63946"), 132)
	add_child(player_bar)
	add_child(enemy_bar)
	player_bar.max_value = player_max_hp
	player_bar.value = player_hp
	enemy_bar.max_value = enemy_max_hp
	enemy_bar.value = enemy_hp
	enemy_name_label = Label.new()
	enemy_name_label.text = enemy_name.to_upper()
	enemy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_name_label.size = Vector2(160, 22)
	enemy_name_label.add_theme_font_size_override("font_size", 13)
	enemy_name_label.add_theme_color_override("font_color", Color.WHITE)
	enemy_name_label.z_index = 2000
	add_child(enemy_name_label)

func create_health_bar(color:Color, width:float) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.size = Vector2(width, 13)
	bar.show_percentage = false
	bar.z_index = 2000
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.03, 0.03, 0.04, 0.9)
	background.border_color = Color(1, 1, 1, 0.5)
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func build_hud() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var vignette = ColorRect.new()
	vignette.anchor_right = 1.0
	vignette.offset_bottom = 76.0
	vignette.color = Color(0.02, 0.025, 0.04, 0.82)
	canvas.add_child(vignette)

	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(-390, 16)
	status_label.size = Vector2(780, 38)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 25)
	status_label.add_theme_color_override("font_color", Color("ffd166"))
	canvas.add_child(status_label)

	var controls = Label.new()
	controls.position = Vector2(20, 600)
	controls.text = tr_text("SETAS/ANALÓGICO: mover  •  Q: soco  •  W: chute  •  ESPAÇO/A: esquiva", "ARROWS/STICK: move  •  Q: punch  •  W: kick  •  SPACE/A: dodge")
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color(0.85, 0.9, 1, 0.9))
	canvas.add_child(controls)

	combo_label = Label.new()
	combo_label.position = Vector2(925, 92)
	combo_label.size = Vector2(200, 80)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_font_size_override("font_size", 28)
	combo_label.add_theme_color_override("font_color", Color("ff9f1c"))
	canvas.add_child(combo_label)

	exit_label = Label.new()
	exit_label.set_anchors_preset(Control.PRESET_CENTER)
	exit_label.position = Vector2(-260, 170)
	exit_label.size = Vector2(520, 50)
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.add_theme_font_size_override("font_size", 30)
	exit_label.add_theme_color_override("font_color", Color("80ed99"))
	exit_label.visible = false
	canvas.add_child(exit_label)

	transition_top = ColorRect.new()
	transition_top.position = Vector2(0, 0)
	transition_top.size = Vector2(1152, 324)
	transition_top.color = Color("07070d")
	transition_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(transition_top)
	transition_bottom = ColorRect.new()
	transition_bottom.position = Vector2(0, 324)
	transition_bottom.size = Vector2(1152, 324)
	transition_bottom.color = Color("07070d")
	transition_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(transition_bottom)
	transition_flash = ColorRect.new()
	transition_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_flash.color = Color(0.8, 0.05, 0.12, 0.0)
	transition_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(transition_flash)
	intro_label = Label.new()
	intro_label.set_anchors_preset(Control.PRESET_CENTER)
	intro_label.position = Vector2(-360, -35)
	intro_label.size = Vector2(720, 70)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.text = tr_text("ENTRANDO NA ARENA", "ENTERING THE ARENA")
	intro_label.add_theme_font_size_override("font_size", 34)
	intro_label.add_theme_color_override("font_color", Color("ffd166"))
	canvas.add_child(intro_label)

func start_entry_sequence() -> void:
	player.modulate = Color(1, 1, 1, 0)
	enemy.modulate = Color(1, 1, 1, 0)
	camera.zoom = Vector2(1.12, 1.12)
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(transition_top, "position:y", -324.0, 1.1).set_delay(0.25)
	tween.tween_property(transition_bottom, "position:y", 648.0, 1.1).set_delay(0.25)
	tween.tween_property(transition_flash, "color:a", 0.0, 0.8).from(0.72)
	tween.tween_property(intro_label, "modulate:a", 0.0, 0.55).set_delay(0.42)
	tween.tween_property(player, "modulate:a", 1.0, 0.55).set_delay(0.55)
	tween.tween_property(enemy, "modulate:a", 1.0, 0.55).set_delay(0.65)
	tween.tween_property(camera, "zoom", Vector2.ONE, 1.25)

func build_audio() -> void:
	battle_song = create_audio("res://assets/novos_audios/battle.mp3", -8.0)
	punch_sound = create_audio("res://assets/novos_audios/punch.mp3", -3.0)
	kick_sound = create_audio("res://assets/novos_audios/kick.mp3", -3.0)
	hit_sound = create_audio("res://assets/novos_audios/punch_3.mp3", -4.0)
	hurt_sound = create_audio("res://assets/novos_audios/hurt_sound.mp3", -3.0)
	enemy_death_sound = create_audio("res://assets/novos_audios/doom_pain.mp3", -2.0)
	victory_sound = create_audio("res://assets/novos_audios/victory_sound.mp3", -3.0)

func create_audio(path:String, volume:float) -> AudioStreamPlayer:
	var audio = AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.volume_db = volume
	add_child(audio)
	return audio

func _process(delta:float) -> void:
	update_effects(delta)
	update_shake(delta)
	if stage_3d:
		stage_3d.update_camera(player_position.x)
	if leaving:
		return
	if player_dead:
		return
	if intro_time > 0.0:
		intro_time = maxf(0.0, intro_time - delta)
		update_fighter_transforms()
		update_bars()
		queue_redraw()
		return
	update_player(delta)
	if !enemy_dead:
		update_enemy(delta)
	else:
		update_enemy_explosion(delta)
		if exit_open && player_position.x >= ARENA_WIDTH - 150.0:
			finish_battle()
	update_fighter_transforms()
	update_bars()
	camera.position.x = clamp(player_position.x + 260.0, 576.0, ARENA_WIDTH - 576.0)
	if background_layer:
		var visible_camera_center = camera.get_screen_center_position().x
		background_layer.position.x = (visible_camera_center - 576.0) * 0.96
	queue_redraw()

func update_player(delta:float) -> void:
	player_attack_time = maxf(0.0, player_attack_time - delta)
	player_invulnerability = maxf(0.0, player_invulnerability - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	combo_timeout = maxf(0.0, combo_timeout - delta)
	if combo_timeout <= 0.0:
		combo = 0
		combo_label.text = ""

	if dodge_time > 0.0:
		player_position += dodge_direction * 610.0 * delta
		player_invulnerability = maxf(player_invulnerability, 0.12)
		play_if_changed(player, "double_jump")
	elif player_attack_time <= 0.0:
		if Input.is_action_just_pressed("ui_accept") && dodge_cooldown <= 0.0:
			start_dodge()
			return
		if Input.is_action_just_pressed("key_q"):
			start_player_attack(false)
		elif Input.is_action_just_pressed("key_w"):
			start_player_attack(true)
		else:
			var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			if direction.length() > 0.1:
				player_position += direction.normalized() * PLAYER_SPEED * delta
				player.flip_h = direction.x < 0.0 if absf(direction.x) > 0.05 else player.flip_h
				play_if_changed(player, "right")
			else:
				play_if_changed(player, "idle_right")
	player_position.x = clampf(player_position.x, 80.0, ARENA_WIDTH - 80.0 if exit_open else 2130.0)
	player_position.y = clampf(player_position.y, MIN_Y, MAX_Y)

func start_dodge() -> void:
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction.length() < 0.1:
		input_direction = Vector2.LEFT if player.flip_h else Vector2.RIGHT
	dodge_direction = input_direction.normalized()
	dodge_time = 0.24
	dodge_cooldown = 0.72
	player_invulnerability = 0.34
	spawn_impact(player_position + Vector2(0, 25), Color("7bdff2"))

func start_player_attack(kick:bool) -> void:
	player_attack_time = 0.42 if kick else 0.32
	player.flip_h = enemy_position.x < player_position.x
	player.play("attack_kick" if kick else "attack_punch")
	var attack_sound = kick_sound if kick else punch_sound
	attack_sound.pitch_scale = randf_range(0.94, 1.06)
	attack_sound.play()
	var facing = -1.0 if player.flip_h else 1.0
	spawn_impact(player_position + Vector2(60.0 * facing, -35), Color("ffd166"))
	resolve_player_hit(kick)

func resolve_player_hit(kick:bool) -> void:
	if enemy_dead:
		return
	var distance = enemy_position - player_position
	var facing_ok = signf(distance.x) == (-1.0 if player.flip_h else 1.0)
	if absf(distance.x) <= (145.0 if kick else 115.0) && absf(distance.y) <= 64.0 && facing_ok:
		var damage = 19.0 if kick else 13.0
		combo += 1
		combo_timeout = 2.2
		damage += minf(combo * 1.5, 10.0)
		enemy_hp = maxf(0.0, enemy_hp - damage)
		enemy_position.x += (-1.0 if player.flip_h else 1.0) * (42.0 if kick else 25.0)
		enemy.play("pain")
		enemy_pressure += 2 if kick else 1
		hit_sound.pitch_scale = randf_range(0.9, 1.13)
		hit_sound.play()
		spawn_blood(enemy_position + Vector2(0, -45), 13 if kick else 8, (-1.0 if player.flip_h else 1.0))
		shake(5.0 if kick else 3.0, 0.18)
		combo_label.text = "%d HIT\nCOMBO" % combo if combo > 1 else ""
		if enemy_hp <= 0.0:
			defeat_enemy()
		elif enemy_pressure >= 3 && enemy_teleport_cooldown <= 0.0:
			begin_enemy_teleport()
		elif combo % 2 == 0:
			begin_enemy_retreat()

func update_enemy(delta:float) -> void:
	enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
	enemy_decision_cooldown = maxf(0.0, enemy_decision_cooldown - delta)
	enemy_teleport_cooldown = maxf(0.0, enemy_teleport_cooldown - delta)
	if enemy_attack_time > 0.0:
		var previous = enemy_attack_time
		enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
		if enemy_hit_pending && previous > 0.28 && enemy_attack_time <= 0.28:
			enemy_hit_pending = false
			resolve_enemy_hit()
		if enemy_attack_time <= 0.0:
			play_if_changed(enemy, "idle")
		return
	if enemy_behavior == "teleport":
		update_enemy_teleport(delta)
		return

	var offset = player_position - enemy_position
	if enemy_behavior == "retreat":
		enemy_behavior_time -= delta
		var retreat_direction = Vector2(-signf(offset.x), enemy_strafe_direction.y * 0.55).normalized()
		move_enemy(retreat_direction, enemy_speed * 1.35, delta)
		if enemy_behavior_time <= 0.0:
			begin_enemy_strafe()
		return
	if enemy_behavior == "strafe":
		enemy_behavior_time -= delta
		var strafe = Vector2(enemy_strafe_direction.x, enemy_strafe_direction.y * 1.15)
		if absf(offset.x) > 230.0:
			strafe.x += signf(offset.x) * 0.8
		move_enemy(strafe.normalized(), enemy_speed * 1.05, delta)
		if enemy_behavior_time <= 0.0:
			enemy_behavior = "approach"
			enemy_decision_cooldown = randf_range(0.7, 1.4)
		return
	if enemy_behavior == "cover":
		enemy_behavior_time -= delta
		var cover_offset = enemy_cover_target - enemy_position
		if cover_offset.length() > 34.0 && enemy_behavior_time > 0.0:
			move_enemy(cover_offset.normalized(), enemy_speed * 1.3, delta)
		else:
			enemy_behavior = "approach"
			enemy_cooldown = minf(enemy_cooldown, 0.2)
		return

	if enemy_decision_cooldown <= 0.0 && offset.length() > 145.0:
		var decision = randf()
		if decision < 0.28:
			begin_enemy_strafe()
			return
		elif decision < 0.46:
			begin_enemy_retreat()
			return
		elif decision < 0.62:
			begin_enemy_cover()
			return
		enemy_decision_cooldown = randf_range(0.8, 1.5)

	var close_enough = absf(offset.x) < 105.0 && absf(offset.y) < 48.0
	if close_enough && enemy_cooldown <= 0.0:
		start_enemy_attack()
		return

	var movement := Vector2.ZERO
	if absf(offset.x) > 82.0:
		movement.x = signf(offset.x)
	if absf(offset.y) > 30.0:
		movement.y = signf(offset.y) * 0.75
	if movement.length() > 0.0:
		move_enemy(movement.normalized(), enemy_speed, delta)
	if absf(enemy_position.x - player_position.x) < 58.0 && absf(enemy_position.y - player_position.y) < 42.0:
		var separation_side = signf(enemy_position.x - player_position.x)
		if separation_side == 0.0:
			separation_side = 1.0
		enemy_position.x = player_position.x + separation_side * 58.0
	enemy_position.x = clampf(enemy_position.x, 120.0, ARENA_WIDTH - 180.0)
	enemy_position.y = clampf(enemy_position.y, MIN_Y, MAX_Y)

func move_enemy(direction:Vector2, speed:float, delta:float) -> void:
	enemy_position += direction * speed * delta
	if absf(direction.x) > 0.05:
		enemy.flip_h = direction.x < 0.0
	play_if_changed(enemy, "run" if enemy.sprite_frames.has_animation("run") else "idle")
	enemy_position.x = clampf(enemy_position.x, 120.0, ARENA_WIDTH - 180.0)
	enemy_position.y = clampf(enemy_position.y, MIN_Y, MAX_Y)

func begin_enemy_retreat() -> void:
	if enemy_dead || enemy_behavior == "teleport":
		return
	enemy_behavior = "retreat"
	enemy_behavior_time = randf_range(0.45, 0.8)
	enemy_strafe_direction = Vector2(-signf(player_position.x - enemy_position.x), -1.0 if randf() < 0.5 else 1.0)
	enemy_decision_cooldown = 1.2

func begin_enemy_strafe() -> void:
	enemy_behavior = "strafe"
	enemy_behavior_time = randf_range(0.7, 1.25)
	enemy_strafe_direction = Vector2(randf_range(-0.35, 0.35), -1.0 if randf() < 0.5 else 1.0)

func begin_enemy_cover() -> void:
	var cover_points = [Vector2(620, 350), Vector2(1280, 560), Vector2(1880, 340), Vector2(2200, 550)]
	enemy_cover_target = cover_points.pick_random()
	enemy_behavior = "cover"
	enemy_behavior_time = 1.8
	enemy_decision_cooldown = 1.5

func begin_enemy_teleport() -> void:
	enemy_pressure = 0
	enemy_behavior = "teleport"
	enemy_behavior_time = 0.82
	enemy_teleport_cooldown = randf_range(4.0, 6.5)
	teleport_moved = false
	enemy_hit_pending = false
	spawn_impact(enemy_position + Vector2(0, -45), Color("d45cff"))

func update_enemy_teleport(delta:float) -> void:
	enemy_behavior_time -= delta
	if enemy_behavior_time > 0.42:
		enemy.modulate.a = clampf(remap(enemy_behavior_time, 0.82, 0.42, 1.0, 0.03), 0.03, 1.0)
	elif !teleport_moved:
		teleport_moved = true
		var side = -1.0 if player.flip_h else 1.0
		if randf() < 0.42:
			side *= -1.0
		enemy_position = Vector2(clampf(player_position.x + side * randf_range(125.0, 175.0), 120.0, ARENA_WIDTH - 180.0), clampf(player_position.y + randf_range(-60.0, 60.0), MIN_Y, MAX_Y))
		spawn_impact(enemy_position + Vector2(0, -45), Color("d45cff"))
	else:
		enemy.modulate.a = clampf(remap(enemy_behavior_time, 0.42, 0.0, 0.03, 1.0), 0.03, 1.0)
	if enemy_behavior_time <= 0.0:
		enemy.modulate.a = 1.0
		enemy_behavior = "approach"
		enemy_cooldown = 0.0
		if absf(player_position.x - enemy_position.x) < 190.0:
			start_enemy_attack()

func start_enemy_attack() -> void:
	enemy_attack_time = 0.68
	enemy_cooldown = randf_range(0.95, 1.55) if enemy_id != "1001" else randf_range(0.58, 1.0)
	enemy_hit_pending = true
	enemy.flip_h = player_position.x < enemy_position.x
	var attack_name = "attack_2" if enemy.sprite_frames.has_animation("attack_2") && randf() > 0.5 else "attack"
	enemy.play(attack_name)

func resolve_enemy_hit() -> void:
	if player_dead || player_invulnerability > 0.0:
		return
	var distance = player_position - enemy_position
	if absf(distance.x) <= 125.0 && absf(distance.y) <= 58.0:
		player_hp = maxf(0.0, player_hp - enemy_damage)
		Global.realtime_hp = player_hp
		player_invulnerability = 0.82
		player_position.x += signf(distance.x) * 54.0
		player.play("falling_down" if player.sprite_frames.has_animation("falling_down") else "damage")
		hurt_sound.play()
		spawn_blood(player_position + Vector2(0, -35), 16, signf(distance.x))
		shake(10.0, 0.38)
		Input.start_joy_vibration(0, 0.65, 0.85, 0.28)
		if player_hp <= 0.0:
			lose_battle()

func defeat_enemy() -> void:
	enemy_dead = true
	enemy_hit_pending = false
	Global.schedule_realtime_enemy_respawn()
	enemy.visible = false
	enemy_bar.visible = false
	enemy_name_label.visible = false
	battle_song.stop()
	enemy_death_sound.play()
	if enemy_id != "1001":
		victory_sound.play()
	Engine.time_scale = 0.24
	restore_normal_time_after_explosion()
	spawn_blood_explosion(enemy_position + Vector2(0, -45), 96)
	for index in range(7):
		spawn_impact(enemy_position + Vector2(randf_range(-55, 55), randf_range(-95, 15)), Color("d90429"))
	for index in range(8):
		stains.append({"position":enemy_position + Vector2(randf_range(-65, 65), randf_range(20, 58)), "radius":randf_range(16.0, 34.0), "alpha":randf_range(0.68, 0.94)})
	shake(22.0, 0.72)
	enemy_explosion_time = 0.92
	status_label.text = tr_text("EXPLOSÃO DE SANGUE!", "BLOOD EXPLOSION!")

func update_enemy_explosion(delta:float) -> void:
	if exit_open:
		return
	enemy_explosion_time = maxf(0.0, enemy_explosion_time - delta)
	if enemy_explosion_time <= 0.0:
		exit_open = true
		exit_label.visible = true
		exit_label.text = tr_text("VITÓRIA!  AVANCE PARA A SAÍDA  →", "VICTORY!  MOVE TO THE EXIT  →")
		status_label.text = tr_text("CAMINHO LIBERADO", "PATH CLEARED")

func restore_normal_time_after_explosion() -> void:
	await get_tree().create_timer(0.42, true, false, true).timeout
	Engine.time_scale = 1.0

func lose_battle() -> void:
	player_dead = true
	player.play("falling_down" if player.sprite_frames.has_animation("falling_down") else "damage")
	status_label.text = tr_text("VOCÊ CAIU", "YOU FELL")
	exit_label.visible = true
	exit_label.text = tr_text("Retornando ao último ponto salvo...", "Returning to the last save point...")
	battle_song.stop()
	await get_tree().create_timer(2.4).timeout
	Global.battle_started = false
	GameSongs.process_mode = Node.PROCESS_MODE_INHERIT
	Global.load_progress()

func finish_battle() -> void:
	leaving = true
	Engine.time_scale = 1.0
	battle_song.stop()
	Global.battle_started = false
	Global.back_to_main_camera = true
	Global.realtime_hp = player_hp
	Global.request_realtime_position_restore()
	GameSongs.process_mode = Node.PROCESS_MODE_INHERIT
	intro_label.text = tr_text("RETORNANDO À JORNADA", "RETURNING TO THE JOURNEY")
	intro_label.modulate.a = 0.0
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(transition_top, "position:y", 0.0, 0.72)
	tween.tween_property(transition_bottom, "position:y", 324.0, 0.72)
	tween.tween_property(transition_flash, "color", Color(0.55, 0.02, 0.08, 0.58), 0.45)
	tween.tween_property(intro_label, "modulate:a", 1.0, 0.4).set_delay(0.35)
	tween.tween_property(camera, "zoom", Vector2(1.14, 1.14), 0.72)
	await tween.finished
	var destination = Global.realtime_return_scene
	if destination.is_empty():
		destination = "res://scenes/menu.tscn"
	get_tree().change_scene_to_file(destination)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func update_fighter_transforms() -> void:
	player.position = player_position
	enemy.position = enemy_position
	player.z_index = int(player_position.y)
	enemy.z_index = int(enemy_position.y)
	var player_depth_scale = remap(player_position.y, MIN_Y, MAX_Y, 0.9, 1.18)
	var enemy_depth_scale = remap(enemy_position.y, MIN_Y, MAX_Y, 0.88, 1.15)
	player.scale = Vector2(player_depth_scale * player_base_scale, player_depth_scale * player_base_scale)
	enemy.scale = Vector2(enemy_depth_scale * enemy_base_scale, enemy_depth_scale * enemy_base_scale)

func update_bars() -> void:
	player_bar.value = player_hp
	enemy_bar.value = enemy_hp
	player_bar.position = player_position + Vector2(-59, 58)
	enemy_bar.position = enemy_position + Vector2(-66, -112)
	enemy_name_label.position = enemy_position + Vector2(-80, -138)
	player_bar.z_index = int(player_position.y) + 1
	enemy_bar.z_index = int(enemy_position.y) + 1
	enemy_name_label.z_index = int(enemy_position.y) + 1

func play_if_changed(sprite:AnimatedSprite2D, animation_name:String) -> void:
	if sprite.animation != animation_name || !sprite.is_playing():
		sprite.play(animation_name)

func spawn_blood(origin:Vector2, amount:int, direction:float) -> void:
	for index in amount:
		var velocity = Vector2(randf_range(70.0, 220.0) * direction + randf_range(-80.0, 80.0), randf_range(-330.0, -120.0))
		droplets.append({"position":origin + Vector2(randf_range(-12, 12), randf_range(-12, 10)), "velocity":velocity, "target_y":origin.y + randf_range(38, 88), "radius":randf_range(2.0, 5.5)})

func spawn_blood_explosion(origin:Vector2, amount:int) -> void:
	for index in amount:
		var velocity = Vector2(randf_range(-430.0, 430.0), randf_range(-560.0, -90.0))
		droplets.append({"position":origin + Vector2(randf_range(-24, 24), randf_range(-28, 24)), "velocity":velocity, "target_y":origin.y + randf_range(65, 145), "radius":randf_range(2.5, 9.5)})

func spawn_impact(position_value:Vector2, color:Color) -> void:
	impacts.append({"position":position_value, "life":0.22, "color":color})

func update_effects(delta:float) -> void:
	for index in range(droplets.size() - 1, -1, -1):
		var drop = droplets[index]
		drop.velocity.y += 620.0 * delta
		drop.position += drop.velocity * delta
		if drop.position.y >= drop.target_y:
			stains.append({"position":Vector2(drop.position.x, drop.target_y), "radius":randf_range(7.0, 18.0), "alpha":randf_range(0.48, 0.78)})
			droplets.remove_at(index)
		else:
			droplets[index] = drop
	while stains.size() > 90:
		stains.pop_front()
	for index in range(impacts.size() - 1, -1, -1):
		impacts[index].life -= delta
		if impacts[index].life <= 0.0:
			impacts.remove_at(index)

func shake(strength:float, duration:float) -> void:
	shake_strength = maxf(shake_strength, strength)
	shake_time = maxf(shake_time, duration)

func update_shake(delta:float) -> void:
	if !camera:
		return
	shake_time = maxf(0.0, shake_time - delta)
	if shake_time > 0.0:
		camera.offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
		shake_strength = move_toward(shake_strength, 0.0, 22.0 * delta)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, minf(1.0, delta * 16.0))

func _draw() -> void:
	for stain in stains:
		draw_set_transform(stain.position, 0.0, Vector2(1.8, 0.42))
		draw_circle(Vector2.ZERO, stain.radius, Color(0.34, 0.0, 0.025, stain.alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for drop in droplets:
		draw_circle(drop.position, drop.radius, Color("a8001c"))
	for impact in impacts:
		var progress = 1.0 - impact.life / 0.22
		draw_arc(impact.position, 25.0 + progress * 38.0, -1.0, 1.0, 14, Color(impact.color, 1.0 - progress), 5.0)
	if exit_open:
		draw_rect(Rect2(2470, 315, 90, 245), Color(0.18, 0.95, 0.45, 0.12))
		draw_line(Vector2(2490, 340), Vector2(2490, 535), Color("80ed99"), 6)
		draw_line(Vector2(2535, 340), Vector2(2535, 535), Color("80ed99"), 6)

func tr_text(pt:String, en:String) -> String:
	return en if Global.default_language == Global.language_en else pt
