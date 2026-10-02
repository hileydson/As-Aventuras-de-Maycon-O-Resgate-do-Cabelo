extends Node3D

const ELEMENT = preload("res://scripts/3D/resgate_cabeludo/element.gd")
const PENTAGRAM = preload("res://assets/3D/pentagram_item.png")
const BLOOD = preload("res://assets/novas_imagens/objects/sangue_fill.png")
# Mesmas linhas de vento do combate aéreo e da queda do Maycon.
const WIND_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
# Mesmo pause do avião e do Super Maycon Brother.
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const AMBIENCE = preload("res://assets/novos_audios/song_birds.mp3")
const STAGE_SONG = preload("res://assets/novos_audios/last_song.mp3")
# A música emenda em si mesma estes segundos antes de acabar.
const SONG_OVERLAP := 3.0
const SOUNDS = {
	"hit": preload("res://assets/novos_audios/punch_4.mp3"),
	"wood": preload("res://assets/novos_audios/mario_part_sounds/wood_barrier_break.mp3"),
	"spring": preload("res://assets/novos_audios/maycon_platform_landing.mp3"),
	"heal": preload("res://assets/novos_audios/sangue_fill_effect.mp3"),
	"power": preload("res://assets/novos_audios/inimigo_1_attack_magic.mp3"),
	"grunt": preload("res://assets/novos_audios/mario_part_sounds/lips_jump_grunt.mp3"),
	"slam": preload("res://assets/novos_audios/mario_part_sounds/lips_butt_slam.mp3")
}

@export var show_intro:bool = true
@onready var player = $Maycon
@onready var camera:Camera3D = $Camera3D
@onready var boss = $Arena/Lips
@onready var fade:ColorRect = $HUD/Fade
var hp:float = 100.0
var pentagrams:int = 0
var checkpoint_position := Vector3(0, 0.1, 0)
var checkpoint_charge:int = 0
var saved_elements:Dictionary = {}
var last_checkpoint:Node3D
var finishing:bool = false
var respawning:bool = false
# O platform_pause.gd consulta estes dois antes de abrir e chama exit_to_menu().
var exit_started:bool = false
var death_in_progress:bool = false
var intro_active:bool = true
var old_cutscene:bool = false
var song_slots:Array[AudioStreamPlayer] = []
var song_turn:int = 0

func _ready() -> void:
	old_cutscene = Global.in_cutscene
	Global.in_cutscene = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$HUD/Title/Resgate.text = tr("RESGATE_TITLE_TOP")
	$HUD/Title/Cabeludo.text = tr("RESGATE_TITLE_BOTTOM")
	$HUD/Title.visible = false
	$HUD/Power.visible = false
	$HUD/Stats.visible = false
	fade.color = Color.BLACK
	build_hud()
	build_wind()
	build_pause()
	update_hud()
	call_deferred("opening")

# No HUD fica só a barra de sangue com a palavra VIDA dentro dela. O aviso de
# checkpoint mora sozinho no canto inferior direito.
func build_hud() -> void:
	for extra in ["Blood", "Charge", "Boss"]:
		if $HUD/Stats.has_node(extra):
			$HUD/Stats.get_node(extra).queue_free()
	var bar:ProgressBar = $HUD/Stats/Health
	bar.position = Vector2(28, 24)
	bar.size = Vector2(300, 34)
	var life := Label.new()
	life.name = "Vida"
	life.text = tr("RESGATE_LIFE")
	life.add_theme_font_size_override("font_size", 20)
	life.add_theme_color_override("font_outline_color", Color("15291e"))
	life.add_theme_constant_override("outline_size", 6)
	life.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	life.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(life)
	life.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var hint:Label = $HUD/Hint
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -300
	hint.offset_top = -56
	hint.offset_right = -24
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = ""

func build_pause() -> void:
	var pause := CanvasLayer.new()
	pause.name = "PauseFofo"
	pause.set_script(PAUSE_SCRIPT)
	add_child(pause)

# Linhas de vento passando pela câmera o tempo todo em que a fase avança.
func build_wind() -> void:
	var wind := MultiMeshInstance3D.new()
	wind.name = "LinhasDeVento"
	wind.set_script(WIND_SCRIPT)
	wind.quantidade = 120
	wind.alcance_z = 120.0
	wind.raio_min = 1.7
	wind.raio_max = 17.0
	wind.velocidade = 56.0
	wind.z_limite = 11.0
	wind.espessura = 0.045
	wind.comprimento_min = 2.5
	wind.comprimento_max = 7.5
	wind.alpha_min = 0.10
	wind.alpha_max = 0.26
	camera.add_child(wind)

func _exit_tree() -> void:
	Global.in_cutscene = old_cutscene
	Engine.time_scale = 1.0
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false

func _unhandled_input(event:InputEvent) -> void:
	if player.control_enabled and event.is_action_pressed("key_e"):
		use_power()

func _physics_process(_delta:float) -> void:
	if finishing or get_tree().paused:
		return
	if player.control_enabled and not player.arena_mode and player.position.z < -1778:
		player.arena_mode = true
		$Arena/Gate/CollisionShape3D.disabled = false
		$Arena/Gate.visible = true
		boss.start()
		update_hud()

func opening() -> void:
	start_stage_song()
	lay_player_down()
	if show_intro and not OS.get_cmdline_user_args().has("--resgate-skip-intro"):
		camera.position = Vector3(22, 15, 18)
		camera.look_at(Vector3(0, 2, -30))
		await fade_to(0.0, 1.2)
		for shot in $Introduction.get_children():
			camera.global_transform = shot.global_transform
			var pan := create_tween()
			pan.tween_property(camera, "position", camera.position + camera.basis.x * 5, 0.7)
			await pan.finished
		camera.position = boss.global_position + Vector3(8, 6, 10)
		camera.look_at(boss.global_position + Vector3.UP * 1.5)
		await get_tree().create_timer(1.1).timeout
		# As palavras entram no meio da vinda, e não depois dela.
		show_title()
		# Vinda disparada do Lips até o Maycon, pelo desfiladeiro e pelas copas.
		for point in [Vector3(0, 18, -1500), Vector3(0, 42, -1300), Vector3(0, 42, -1090), Vector3(0, 15, -900), Vector3(0, -5, -620), Vector3(0, -5, -400), Vector3(0, 14, -300), Vector3(0, 2.8, 5.6)]:
			var start := camera.position
			var pan := create_tween()
			pan.tween_method(func(t:float):
				camera.position = start.lerp(point, t)
				camera.look_at(camera.position + Vector3(0, -5, 12) if point.z < -100 else player.position + Vector3.UP)
			, 0.0, 1.0, 0.42)
			await pan.finished
	else:
		show_title()
	# Sem fade no fim da vinda: a câmera assume o posto de jogo e a fase já começa.
	camera.position = player.position + Vector3(0, 2.8, 5.6)
	camera.look_at(player.position + Vector3(0, 1.3, -4.0))
	if fade.color.a > 0.0:
		await fade_to(0.0, 0.8)
	await rise_player()
	player._play_animation("Walking")
	$HUD/Stats.visible = true
	start_ambience()
	intro_active = false
	Global.in_cutscene = false
	player.control_enabled = true

func show_title() -> void:
	$HUD/Title.visible = true
	sound("hit")
	var title := create_tween()
	title.tween_property($HUD/Title, "modulate:a", 1.0, 0.15).from(0.0)
	title.tween_interval(2.2)
	title.tween_property($HUD/Title, "modulate:a", 0.6, 0.6)
	title.tween_property($HUD/Title, "modulate:a", 0.0, 0.4)
	title.tween_callback(func(): $HUD/Title.visible = false)

# Maycon começa caído, igual à abertura do interior do avião, e se levanta ali
# mesmo antes de o jogador assumir o controle.
func lay_player_down() -> void:
	player.visual.rotation.x = -PI * 0.5
	player.visual.position.y = 0.14

func rise_player() -> void:
	var rise := create_tween()
	rise.tween_property(player.visual, "rotation:x", 0.0, 0.85).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(player.visual, "position:y", 0.0, 0.85)
	await rise.finished
	# Balança a cabeça tonto, como ele faz ao acordar no avião.
	var sway := create_tween()
	sway.tween_property(player.visual, "rotation:z", 0.13, 0.18)
	sway.tween_property(player.visual, "rotation:z", -0.13, 0.3)
	sway.tween_property(player.visual, "rotation:z", 0.0, 0.22)
	await sway.finished

func start_stage_song() -> void:
	for i in 2:
		var slot := AudioStreamPlayer.new()
		slot.name = "LastSong%d" % i
		slot.stream = STAGE_SONG
		slot.volume_db = -9.0
		add_child(slot)
		song_slots.append(slot)
	chain_song()

# Emenda a música em si mesma antes do fim, então a virada nunca deixa silêncio.
func chain_song() -> void:
	if finishing or song_slots.is_empty():
		return
	var slot:AudioStreamPlayer = song_slots[song_turn]
	song_turn = 1 - song_turn
	slot.play()
	var wait := maxf(1.0, STAGE_SONG.get_length() - SONG_OVERLAP)
	get_tree().create_timer(wait, true, false, true).timeout.connect(chain_song)

func start_ambience() -> void:
	var birds := AudioStreamPlayer.new()
	birds.name = "Ambiente"
	birds.stream = AMBIENCE
	birds.volume_db = -13.0
	add_child(birds)
	# Os mp3 do projeto não são importados em loop, então o som é reiniciado no fim.
	birds.finished.connect(func():
		if is_instance_valid(birds):
			birds.play())
	birds.play()

func fade_to(alpha:float, duration:float) -> void:
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(fade, "color:a", alpha, duration)
	await tween.finished

func sound(key:String) -> void:
	var audio := AudioStreamPlayer.new()
	audio.stream = SOUNDS[key]
	audio.volume_db = -6.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func update_hud() -> void:
	$HUD/Stats/Health.value = hp

func collect() -> void:
	pentagrams += 1
	update_hud()

func heal(amount:float) -> void:
	hp = minf(100.0, hp + amount)
	sound("heal")
	update_hud()

func damage(amount:float) -> void:
	hp = maxf(0, hp - amount)
	sound("hit")
	update_hud()
	if hp <= 0:
		respawn()

func fall_limit(z:float) -> float:
	if z < -350 and z > -695:
		return -32.0
	# Só vale sobre a ponte das copas; depois dela a queda até a floresta é o caminho normal.
	if z < -1070 and z > -1370:
		return 15.0
	return -12.0

# Meia largura da pista em cada trecho. O Maycon nunca sai dela de lado: ele só
# cai nos buracos entre as plataformas.
func track_limit(z:float) -> float:
	if z < -1775:
		return 19.0
	if z < -1070 and z > -1370:
		return 3.6
	return 5.6

func checkpoint(node:Node3D) -> void:
	if node == last_checkpoint or node.global_position.z >= checkpoint_position.z:
		return
	last_checkpoint = node
	checkpoint_position = node.global_position + Vector3(0, 0.2, -2)
	checkpoint_charge = pentagrams
	saved_elements.clear()
	for item in get_tree().get_nodes_in_group("resgate_elements"):
		saved_elements[item.get_instance_id()] = {"active": item.active, "remaining": item.remaining}
	for item in get_tree().get_nodes_in_group("resgate_enemies"):
		saved_elements[item.get_instance_id()] = {"active": item.active}
	show_checkpoint()
	burst(node.global_position + Vector3.UP, Color("ffd86c"), 16)

# Só a palavra, no canto inferior direito, e some sozinha.
func show_checkpoint() -> void:
	var hint:Label = $HUD/Hint
	hint.text = tr("RESGATE_CHECKPOINT")
	var aviso := create_tween().bind_node(hint)
	aviso.tween_property(hint, "modulate:a", 1.0, 0.2).from(0.0)
	aviso.tween_interval(1.8)
	aviso.tween_property(hint, "modulate:a", 0.0, 0.5)
	aviso.tween_callback(func(): hint.text = "")

func respawn() -> void:
	if respawning or finishing or exit_started:
		return
	respawning = true
	death_in_progress = true
	player.control_enabled = false
	player.step_audio.stop()
	await fade_to(1, 0.7)
	player.position = checkpoint_position
	player.velocity = Vector3.ZERO
	player.launch_time = 0.0
	player.hurt_time = 2.0
	player.arena_mode = false
	boss.active = false
	boss.position = Vector3(0, 0, -1800)
	boss.hp = 4
	$Arena/Gate/CollisionShape3D.disabled = true
	$Arena/Gate.visible = false
	for item in get_tree().get_nodes_in_group("resgate_elements") + get_tree().get_nodes_in_group("resgate_enemies"):
		if item.is_in_group("resgate_transient"):
			item.queue_free()
			continue
		item.reset_element()
		var saved:Dictionary = saved_elements.get(item.get_instance_id(), {})
		if not saved.get("active", true):
			item.active = false
			item.visible = false
			if item.has_method("retire"):
				item.retire()
		if "remaining" in saved:
			item.remaining = saved.remaining
	hp = 100
	pentagrams = checkpoint_charge
	update_hud()
	camera.position = player.position + Vector3(0, 2.8, 5.6)
	camera.look_at(player.position + Vector3(0, 1.3, -4.0))
	await fade_to(0, 0.7)
	player.control_enabled = true
	respawning = false
	death_in_progress = false

# Saída pelo menu do pause, no mesmo formato do avião e do Super Maycon Brother.
# Este trecho final não é ponto de save, igual à Cidade Perdida, então nada é gravado.
func exit_to_menu() -> void:
	if exit_started:
		return
	exit_started = true
	player.control_enabled = false
	player.step_audio.stop()
	get_tree().paused = false
	for slot in song_slots:
		if is_instance_valid(slot):
			slot.stop()
	fade.color = Color(0, 0, 0, fade.color.a)
	await fade_to(1.0, 0.7)
	Global.back_to_main_camera = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")

func release_pentagrams(at:Vector3, count:int) -> void:
	for i in count:
		var item := pickup(at + Vector3((i - (count - 1) * 0.5) * 0.5, 0.25, 0), false)
		item.cooldown = 0.1

func pickup(at:Vector3, blood:bool) -> Node3D:
	var item := Node3D.new()
	item.set_script(ELEMENT)
	item.kind = "blood" if blood else "pentagram"
	item.position = at
	var visual := Sprite3D.new()
	visual.name = "Visual"
	visual.texture = BLOOD if blood else PENTAGRAM
	visual.pixel_size = 1.0 / float(visual.texture.get_width())
	visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.add_child(visual)
	$Effects.add_child(item)
	item.add_to_group("resgate_transient")
	return item

func drop_blood(at:Vector3) -> void:
	pickup(at, true)

func use_power() -> void:
	if pentagrams < 20 or finishing:
		return
	pentagrams -= 20
	sound("power")
	$HUD/Power.visible = true
	$HUD/Power.modulate.a = 0.85
	var tween := create_tween()
	tween.tween_property($HUD/Power, "modulate:a", 0.0, 0.9)
	tween.tween_callback(func(): $HUD/Power.visible = false)
	for enemy in get_tree().get_nodes_in_group("resgate_enemies"):
		if not enemy.active:
			continue
		var target:Vector3 = enemy.global_position + Vector3.UP
		if camera.global_position.distance_to(target) > 55.0 or camera.is_position_behind(target) or not get_viewport().get_visible_rect().has_point(camera.unproject_position(target)):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			enemy.defeat()
	update_hud()

func burst(at:Vector3, color:Color, count:int) -> void:
	var fx := CPUParticles3D.new()
	fx.emitting = false
	fx.one_shot = true
	fx.amount = count
	fx.lifetime = 0.7
	fx.explosiveness = 1.0
	fx.direction = Vector3.UP
	fx.spread = 80.0
	fx.initial_velocity_min = 2.0
	fx.initial_velocity_max = 6.0
	fx.gravity = Vector3(0, -14, 0)
	fx.scale_amount_min = 0.08
	fx.scale_amount_max = 0.22
	var mesh := SphereMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	fx.mesh = mesh
	$Effects.add_child(fx)
	fx.global_position = at
	fx.finished.connect(fx.queue_free)
	fx.emitting = true

func finish() -> void:
	if finishing:
		return
	finishing = true
	exit_started = true
	player.control_enabled = false
	player.step_audio.stop()
	Global.in_cutscene = true
	Engine.time_scale = 0.06
	fade.color = Color(1, 1, 1, 0)
	await fade_to(1.0, 5.5)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/3D/resgate_cabeludo/ending_bridge.tscn")
