extends Node2D

const ARENA_WIDTH:float = 2600.0
const MIN_Y:float = 405.0
const MAX_Y:float = 570.0
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
	"5":{"name":"Manga", "hp":120.0, "speed":155.0, "damage":18.0, "scale":1.0},
	"1001":{"name":"Seco", "hp":260.0, "speed":165.0, "damage":24.0, "scale":1.28}
}

var player:AnimatedSprite2D
var enemy:AnimatedSprite2D
var camera:Camera2D
var player_bar:ProgressBar
var enemy_bar:ProgressBar
var enemy_name_label:Label
var status_label:Label
var combo_label:Label
var exit_label:Label
var battle_song:AudioStreamPlayer
var hit_sound:AudioStreamPlayer
var hurt_sound:AudioStreamPlayer
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

func _ready() -> void:
	randomize()
	enemy_id = Global.realtime_enemy_id if ENEMY_SCENES.has(Global.realtime_enemy_id) else "1"
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
	queue_redraw()

func build_background() -> void:
	var background = preload("res://scripts/realtime_battle_background.gd").new()
	background.theme_id = Global.realtime_arena_theme
	background.arena_width = ARENA_WIDTH
	background.z_index = -100
	add_child(background)

func build_fighters() -> void:
	player = sprite_from_scene("res://scenes/maycon_batalha_default.tscn", true)
	player.name = "MayconRealtime"
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

func build_audio() -> void:
	battle_song = create_audio("res://assets/novos_audios/battle.mp3", -8.0)
	hit_sound = create_audio("res://assets/novos_audios/punch_3.mp3", -4.0)
	hurt_sound = create_audio("res://assets/novos_audios/hurt_sound.mp3", -3.0)
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
	if leaving:
		return
	if player_dead:
		return
	update_player(delta)
	if !enemy_dead:
		update_enemy(delta)
	elif exit_open && player_position.x >= ARENA_WIDTH - 150.0:
		finish_battle()
	update_fighter_transforms()
	update_bars()
	camera.position.x = clamp(player_position.x + 260.0, 576.0, ARENA_WIDTH - 576.0)
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
		hit_sound.pitch_scale = randf_range(0.9, 1.13)
		hit_sound.play()
		spawn_blood(enemy_position + Vector2(0, -45), 13 if kick else 8, (-1.0 if player.flip_h else 1.0))
		shake(5.0 if kick else 3.0, 0.18)
		combo_label.text = "%d HIT\nCOMBO" % combo if combo > 1 else ""
		if enemy_hp <= 0.0:
			defeat_enemy()

func update_enemy(delta:float) -> void:
	enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
	if enemy_attack_time > 0.0:
		var previous = enemy_attack_time
		enemy_attack_time = maxf(0.0, enemy_attack_time - delta)
		if enemy_hit_pending && previous > 0.28 && enemy_attack_time <= 0.28:
			enemy_hit_pending = false
			resolve_enemy_hit()
		if enemy_attack_time <= 0.0:
			play_if_changed(enemy, "idle")
		return

	var offset = player_position - enemy_position
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
		enemy_position += movement.normalized() * enemy_speed * delta
		enemy.flip_h = offset.x < 0.0
		play_if_changed(enemy, "run" if enemy.sprite_frames.has_animation("run") else "idle")
	if absf(enemy_position.x - player_position.x) < 58.0 && absf(enemy_position.y - player_position.y) < 42.0:
		var separation_side = signf(enemy_position.x - player_position.x)
		if separation_side == 0.0:
			separation_side = 1.0
		enemy_position.x = player_position.x + separation_side * 58.0
	enemy_position.x = clampf(enemy_position.x, 120.0, ARENA_WIDTH - 180.0)
	enemy_position.y = clampf(enemy_position.y, MIN_Y, MAX_Y)

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
		player_invulnerability = 0.82
		player_position.x += signf(distance.x) * 54.0
		player.play("damage")
		hurt_sound.play()
		spawn_blood(player_position + Vector2(0, -35), 16, signf(distance.x))
		shake(10.0, 0.38)
		Input.start_joy_vibration(0, 0.65, 0.85, 0.28)
		if player_hp <= 0.0:
			lose_battle()

func defeat_enemy() -> void:
	enemy_dead = true
	enemy_hit_pending = false
	enemy.play("pain")
	spawn_blood(enemy_position + Vector2(0, -35), 28, signf(enemy_position.x - player_position.x))
	shake(14.0, 0.55)
	exit_open = true
	exit_label.visible = true
	exit_label.text = tr_text("VITÓRIA!  AVANCE PARA A SAÍDA  →", "VICTORY!  MOVE TO THE EXIT  →")
	status_label.text = tr_text("CAMINHO LIBERADO", "PATH CLEARED")
	victory_sound.play()

func lose_battle() -> void:
	player_dead = true
	player.play("damage")
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
	battle_song.stop()
	Global.battle_started = false
	Global.back_to_main_camera = true
	GameSongs.process_mode = Node.PROCESS_MODE_INHERIT
	var fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	canvas.add_child(fade)
	var tween = create_tween()
	tween.tween_property(fade, "color", Color.BLACK, 0.65)
	await tween.finished
	var destination = Global.realtime_return_scene
	if destination.is_empty():
		destination = "res://scenes/menu.tscn"
	get_tree().change_scene_to_file(destination)

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
	if sprite.animation != animation_name:
		sprite.play(animation_name)

func spawn_blood(origin:Vector2, amount:int, direction:float) -> void:
	for index in amount:
		var velocity = Vector2(randf_range(70.0, 220.0) * direction + randf_range(-80.0, 80.0), randf_range(-330.0, -120.0))
		droplets.append({"position":origin + Vector2(randf_range(-12, 12), randf_range(-12, 10)), "velocity":velocity, "target_y":origin.y + randf_range(38, 88), "radius":randf_range(2.0, 5.5)})

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
