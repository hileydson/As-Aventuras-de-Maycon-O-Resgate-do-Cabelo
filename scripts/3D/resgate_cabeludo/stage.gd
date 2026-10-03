extends Node3D

const ELEMENT = preload("res://scripts/3D/resgate_cabeludo/element.gd")
const PENTAGRAM = preload("res://assets/3D/pentagram_item.png")
const BLOOD = preload("res://assets/novas_imagens/objects/sangue_fill.png")
# Mesmas linhas de vento do combate aéreo e da queda do Maycon.
const WIND_SCRIPT = preload("res://scripts/3D/aviao_linhas_vento.gd")
# Mesmo pause do avião e do Super Maycon Brother.
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
const JAULA = preload("res://scripts/3D/resgate_cabeludo/jaula.gd")
const ELDEN_LIPS = preload("res://scripts/3D/resgate_cabeludo/elden_lips.gd")
# Mesmo Maycon 2D do menu principal, o do olhar para frente.
const MAYCON_2D = preload("res://assets/novas_imagens/maycon/jamelao_float_1.png")
# Mesmo blur direcional do dash do Poço Infinito, usado aqui como motion blur.
const BLUR_SHADER = preload("res://scenes/3D/poco_infinito_dash_blur.gdshader")
const BLUR_CUTSCENE := 0.72
const BLUR_GAMEPLAY := 0.16
const AMBIENCE = preload("res://assets/novos_audios/song_birds.mp3")
const STAGE_SONG = preload("res://assets/novos_audios/last_song.mp3")
# Mesmo som de coleta do Super Maycon Brother.
const PICKUP_SOUND = preload("res://assets/audio/plim.mp3")
# Pancada do Lips chegando no chão da arena.
const IMPACT_SOUND = preload("res://assets/novos_audios/impact_sound.mp3")
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
@export var preview_final_battle:bool = false
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
var pentagram_label:Label
var pentagram_panel:HBoxContainer
var pentagram_icon:TextureRect
var blur_material:ShaderMaterial
var song_slots:Array[AudioStreamPlayer] = []
var song_turn:int = 0
var wind:MultiMeshInstance3D
var cage:RigidBody3D
var boss_bar:TextureProgressBar
var final_battle:Node3D

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
	build_blur()
	build_wind()
	build_cage()
	build_pause()
	final_battle = Node3D.new()
	final_battle.name = "EldenLips"
	final_battle.set_script(ELDEN_LIPS)
	add_child(final_battle)
	final_battle.setup(self)
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
	# Contador de pentagramas em cima, no mesmo formato do Super Maycon Brother.
	var count_panel := HBoxContainer.new()
	count_panel.name = "Pentagramas"
	count_panel.anchor_left = 1.0
	count_panel.anchor_right = 1.0
	count_panel.offset_left = -135.0
	count_panel.offset_right = -12.0
	count_panel.offset_top = 9.0
	count_panel.offset_bottom = 41.0
	count_panel.visible = false
	$HUD.add_child(count_panel)
	var icon := TextureRect.new()
	icon.texture = PENTAGRAM
	icon.custom_minimum_size = Vector2(32.0, 32.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	count_panel.add_child(icon)
	pentagram_panel = count_panel
	pentagram_icon = icon
	pentagram_label = Label.new()
	pentagram_label.add_theme_font_size_override("font_size", 22)
	pentagram_label.add_theme_color_override("font_color", Color("d72343"))
	pentagram_label.add_theme_color_override("font_outline_color", Color("15291e"))
	pentagram_label.add_theme_constant_override("outline_size", 6)
	count_panel.add_child(pentagram_label)
	build_boss_bar()
	var hint:Label = $HUD/Hint
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -300
	hint.offset_top = -56
	hint.offset_right = -24
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = ""

# O sangue do Lips fica embaixo, no meio da tela, e só aparece na batalha.
func build_boss_bar() -> void:
	boss_bar = TextureProgressBar.new()
	boss_bar.name = "SangueDoLips"
	boss_bar.nine_patch_stretch = true
	boss_bar.texture_under = BLOOD
	boss_bar.texture_progress = BLOOD
	boss_bar.tint_under = Color(0.12, 0.05, 0.07, 0.75)
	boss_bar.tint_progress = Color("d72343")
	boss_bar.min_value = 0.0
	boss_bar.max_value = 4.0
	boss_bar.value = 4.0
	boss_bar.visible = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(boss_bar)
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.anchor_top = 1.0
	boss_bar.anchor_bottom = 1.0
	boss_bar.offset_left = -210.0
	boss_bar.offset_right = 210.0
	boss_bar.offset_top = -74.0
	boss_bar.offset_bottom = -30.0

# Motion blur de tela cheia. Entra antes do resto do HUD para o título, o aviso
# e o fade não saírem borrados.
func build_blur() -> void:
	blur_material = ShaderMaterial.new()
	blur_material.shader = BLUR_SHADER
	var rect := ColorRect.new()
	rect.name = "MotionBlur"
	rect.material = blur_material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$HUD.move_child(rect, 0)
	set_blur(0.0, Vector2(0.5, 0.5))

func set_blur(strength:float, center:Vector2) -> void:
	if blur_material == null:
		return
	blur_material.set_shader_parameter("blur_strength", strength)
	blur_material.set_shader_parameter("blur_center", center)
	blur_material.set_shader_parameter("blur_direction", Vector2(0.0, 1.0))

# A jaula fica no fundo da arena com o cabelo dentro, e o cabelo sai do Lips.
func build_cage() -> void:
	cage = RigidBody3D.new()
	cage.name = "Jaula"
	cage.set_script(JAULA)
	$Arena.add_child(cage)
	cage.position = Vector3(0, 1.4, -1814)
	# O quique é limitado pelo centro da arena, não pelo ponto onde ela nasceu.
	cage.centro = Vector3(0, 1.4, -1800)

# O cabelo chega nas costas do Lips e só então é trancado na jaula.
func lock_hair_in_cage() -> void:
	if not is_instance_valid(cage) or cage.has_node("Hair"):
		return
	# Ele pode estar nas costas do Lips ou no meio do voo, solto na fase.
	var cabelo:Node = boss.get_node_or_null("Hair")
	if cabelo == null:
		cabelo = get_node_or_null("Hair")
	if cabelo == null:
		return
	cage.guardar(cabelo)

func build_pause() -> void:
	var pause := CanvasLayer.new()
	pause.name = "PauseFofo"
	pause.set_script(PAUSE_SCRIPT)
	add_child(pause)

# Linhas de vento passando pela câmera o tempo todo em que a fase avança. Elas
# só entram depois da queda do Lips, onde a câmera ainda está parada.
func build_wind() -> void:
	wind = MultiMeshInstance3D.new()
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
	wind.visible = false
	camera.add_child(wind)

func _exit_tree() -> void:
	Global.in_cutscene = old_cutscene
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false

func _unhandled_input(event:InputEvent) -> void:
	pass # O dash mora no player.gd, no B do controle e na tecla V.

func _physics_process(_delta:float) -> void:
	if finishing or get_tree().paused:
		return
	if player.control_enabled and not player.arena_mode and player.position.z < -1778:
		final_battle.begin()

func opening() -> void:
	if preview_final_battle or Global.debug_resgate_cabeludo_boss or OS.get_cmdline_user_args().has("--elden-lips-preview"):
		Global.debug_resgate_cabeludo_boss = false
		lock_hair_in_cage()
		player.position = Vector3(0,0.08,-1779)
		fade.color.a = 0.0
		final_battle.begin()
		return
	lay_player_down()
	await lips_arrival()
	lock_hair_in_cage()
	# Vento só a partir daqui: na queda do Lips a câmera está parada.
	if is_instance_valid(wind):
		wind.visible = true
	start_stage_song()
	set_blur(BLUR_CUTSCENE, Vector2(0.5, 0.5))
	if show_intro and not OS.get_cmdline_user_args().has("--resgate-skip-intro"):
		# A música entra e a câmera já sai do Lips em direção ao Maycon, sem parar
		# para olhar ele caído.
		# As palavras entram no meio da vinda e ficam até a hora de jogar.
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
	# Só agora a frase sai, e é neste instante que o Maycon se levanta do chão.
	hide_title()
	set_blur(BLUR_GAMEPLAY, Vector2(0.5, 0.28))
	await rise_player()
	player._play_animation("Walking")
	$HUD/Stats.visible = true
	$HUD/Pentagramas.visible = true
	start_ambience()
	intro_active = false
	Global.in_cutscene = false
	player.control_enabled = true

func show_title() -> void:
	$HUD/Title.visible = true
	sound("hit")
	var title := create_tween()
	title.tween_property($HUD/Title, "modulate:a", 1.0, 0.15).from(0.0)

func hide_title() -> void:
	if not $HUD/Title.visible:
		return
	var title := create_tween()
	title.tween_property($HUD/Title, "modulate:a", 0.0, 0.45)
	title.tween_callback(func(): $HUD/Title.visible = false)
	await title.finished

# Antes de tudo: o Lips despenca do céu com o cabelo nas costas, soltando poeira,
# e bate na arena. Só depois começa a cutscene com a música.
func lips_arrival() -> void:
	if not show_intro or OS.get_cmdline_user_args().has("--resgate-skip-intro"):
		return
	var pouso:Vector3 = boss.position
	boss.position = pouso + Vector3(0, 72, 0)
	camera.position = pouso + Vector3(15, 11, 23)
	camera.look_at(pouso + Vector3.UP * 3)
	set_blur(BLUR_CUTSCENE, Vector2(0.5, 0.5))
	await fade_to(0.0, 0.4)
	var rastro := POEIRA.rastro(boss)
	var queda := create_tween()
	queda.tween_property(boss, "position", pouso, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await queda.finished
	POEIRA.apagar(rastro)
	# A arena inteira desaparece na poeira: um anel de baforadas em volta do pouso.
	POEIRA.pousar(self, pouso)
	POEIRA.impulsionar(self, pouso + Vector3.UP * 0.8)
	for volta in 12:
		var angulo := TAU * float(volta) / 12.0
		var raio := 5.0 if volta % 2 == 0 else 9.5
		POEIRA.pousar(self, pouso + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio))
	sound("slam")
	burst(pouso + Vector3.UP, Color("c9b785"), 34)
	# A pancada toca e a câmera foca na cara do cabelo tremendo por um tempo mais curto e dinâmico.
	impact_sound(pouso)
	await shake_on_hair(3.8)

# Enquanto a pancada toca, a câmera chega perto da cara do cabelo e treme. O
# tremor é forte na batida e vai morrendo até o tempo determinado.
func shake_on_hair(duracao:float) -> void:
	var cabelo:Node3D = boss.get_node_or_null("Hair") as Node3D
	if cabelo == null:
		cabelo = boss
	# No meio do tremor o cabelo salta das costas dele e cai dentro da jaula; a
	# câmera continua colada nele durante o voo.
	hair_to_cage()
	var tremor := create_tween()
	tremor.tween_method(func(t:float):
		if not is_instance_valid(cabelo):
			return
		var cara:Vector3 = cabelo.global_position
		# Perde força aos poucos, mas nunca para antes do fim do som.
		var forca:float = lerpf(0.42, 0.05, t)
		camera.global_position = cara + Vector3(1.7, 0.55, 3.0) + Vector3(randf_range(-forca, forca), randf_range(-forca, forca), randf_range(-forca, forca))
		camera.look_at(cara + Vector3(randf_range(-forca, forca) * 0.3, randf_range(-forca, forca) * 0.3, 0.0))
	, 0.0, 1.0, duracao)
	await tremor.finished

# O cabelo é arremessado para o alto com o tranco do pouso e desce dentro da
# jaula. Roda junto com o tremor da câmera, que o acompanha o tempo todo.
func hair_to_cage() -> void:
	var cabelo:Node3D = boss.get_node_or_null("Hair") as Node3D
	if cabelo == null or not is_instance_valid(cage):
		return
	# Billboard já no voo: a câmera gira em volta dele e ele segue de frente.
	if cabelo is AnimatedSprite3D:
		(cabelo as AnimatedSprite3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(cabelo) or not is_instance_valid(cage):
		return
	# Solta das costas do Lips e passa a voar por conta própria.
	var onde:Vector3 = cabelo.global_position
	cabelo.get_parent().remove_child(cabelo)
	add_child(cabelo)
	cabelo.global_position = onde
	POEIRA.saltar(self, onde)
	sound("spring")
	var destino:Vector3 = cage.global_position
	var alto := Vector3((onde.x + destino.x) * 0.5, onde.y + 13.0, (onde.z + destino.z) * 0.5)
	var subida := create_tween()
	subida.tween_method(func(t:float):
		if is_instance_valid(cabelo):
			cabelo.global_position = onde.lerp(alto, t)
	, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await subida.finished
	var queda := create_tween()
	queda.tween_method(func(t:float):
		if is_instance_valid(cabelo):
			cabelo.global_position = alto.lerp(cage.global_position, t)
	, 0.0, 1.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await queda.finished
	# Pousou lá dentro: a jaula chacoalha com o peso dele.
	lock_hair_in_cage()
	POEIRA.aterrar(self, cage.global_position)
	burst(cage.global_position, Color("c9b785"), 24)
	sound("wood")

# Maycon começa caído, igual à abertura do interior do avião, e se levanta ali
# mesmo antes de o jogador assumir o controle.
func lay_player_down() -> void:
	var ap:AnimationPlayer = player.animation_player
	if ap != null and ap.has_animation("RunFast"):
		# Primeiro quadro do RunFast: ele já aparece caído no chão.
		ap.play("RunFast")
		ap.seek(0, true)
		ap.pause()
		return
	player.visual.rotation.x = -PI * 0.5
	player.visual.position.y = 0.14

func rise_player() -> void:
	# RunFast é a animação de levantar do chão, a mesma da abertura do avião.
	var ap:AnimationPlayer = player.animation_player
	if ap != null and ap.has_animation("RunFast"):
		player.visual.rotation.x = 0.0
		player.visual.position.y = 0.0
		ap.speed_scale = 1.0
		ap.play("RunFast")
		await get_tree().create_timer(ap.get_animation("RunFast").length + 0.1).timeout
		return
	# Sem a animação na importação do modelo, o levantar é feito na mão.
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
	if finishing or song_slots.is_empty() or (is_instance_valid(final_battle) and final_battle.engaged):
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

# Pancada do pouso do Lips. Devolve só quando o som termina, para a cutscene
# esperar por ele.
func impact_sound(_at:Vector3) -> void:
	var audio := AudioStreamPlayer.new()
	audio.name = "Impacto"
	audio.stream = IMPACT_SOUND
	audio.volume_db = -2.0
	add_child(audio)
	audio.play()
	# A espera sai do tamanho do arquivo: o sinal "finished" não chega em todos os
	# drivers de áudio.
	await get_tree().create_timer(IMPACT_SOUND.get_length()).timeout
	audio.queue_free()

func sound(key:String) -> void:
	var audio := AudioStreamPlayer.new()
	audio.stream = SOUNDS[key]
	audio.volume_db = -6.0
	add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()

func update_hud() -> void:
	$HUD/Stats/Health.value = hp
	if is_instance_valid(pentagram_label):
		pentagram_label.text = str(pentagrams)
	if is_instance_valid(boss_bar):
		boss_bar.visible = boss.active and not finishing and not (is_instance_valid(final_battle) and final_battle.engaged)
		boss_bar.value = float(boss.hp)

func collect(at:Vector3 = Vector3.ZERO) -> void:
	pentagrams += 1
	update_hud()
	pickup_burst(at if at != Vector3.ZERO else player.global_position + Vector3.UP)
	pickup_sound()

# O dash cobra pentagramas; devolve falso quando não há o bastante.
func spend_pentagrams(amount:int) -> bool:
	if pentagrams < amount or finishing or exit_started:
		return false
	pentagrams -= amount
	update_hud()
	pentagram_spent_effect(amount)
	return true

# O contador avisa o que saiu: o troco sobe em vermelho e o ícone leva um soco.
func pentagram_spent_effect(amount:int) -> void:
	if not is_instance_valid(pentagram_panel):
		return
	var troco := Label.new()
	troco.name = "PentagramaGasto"
	troco.text = "-%d" % amount
	troco.add_theme_font_size_override("font_size", 26)
	troco.add_theme_color_override("font_color", Color("ff5a6e"))
	troco.add_theme_color_override("font_outline_color", Color("15291e"))
	troco.add_theme_constant_override("outline_size", 7)
	troco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(troco)
	# Os dois moram no mesmo HUD, então basta copiar o canto do contador: mexer
	# nas âncoras depois de posicionar jogaria o troco fora da tela.
	troco.position = pentagram_panel.position + Vector2(pentagram_panel.size.x * 0.5, pentagram_panel.size.y)
	var sobe := create_tween().bind_node(troco).set_parallel(true)
	sobe.tween_property(troco, "position:y", troco.position.y - 42.0, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sobe.tween_property(troco, "modulate:a", 0.0, 0.75).set_delay(0.2)
	sobe.chain().tween_callback(troco.queue_free)
	# Soco no contador: ele cresce e volta, com o número piscando em branco.
	pentagram_panel.pivot_offset = pentagram_panel.size * 0.5
	var soco := create_tween().bind_node(pentagram_panel)
	soco.tween_property(pentagram_panel, "scale", Vector2.ONE * 1.32, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	soco.tween_property(pentagram_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if is_instance_valid(pentagram_label):
		pentagram_label.add_theme_color_override("font_color", Color.WHITE)
		var volta := create_tween().bind_node(pentagram_label)
		volta.tween_interval(0.16)
		volta.tween_callback(func(): pentagram_label.add_theme_color_override("font_color", Color("d72343")))
	# O ícone apaga e acende junto com a cobrança.
	if is_instance_valid(pentagram_icon):
		var brilho := create_tween().bind_node(pentagram_icon)
		brilho.tween_property(pentagram_icon, "modulate", Color(1.0, 0.45, 0.5, 0.35), 0.1)
		brilho.tween_property(pentagram_icon, "modulate", Color.WHITE, 0.3)

# Mesmo estouro de cores da coleta no Super Maycon Brother.
func pickup_burst(at:Vector3) -> void:
	var colors := [Color("ffda60"), Color("ff6fb1"), Color("71d3ff"), Color("a985ff"), Color("8ee899"), Color("ff9369")]
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.095
	spark_mesh.height = 0.19
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	for i in 36:
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = mat
		spark.position = at
		spark.scale = Vector3.ONE * randf_range(0.8, 1.7)
		$Effects.add_child(spark)
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.1), randf_range(-1.0, 1.0)).normalized()
		var distance := randf_range(1.1, 2.5)
		var tween := create_tween().bind_node(spark).set_parallel(true)
		tween.tween_property(spark, "position", at + direction * distance, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(spark.queue_free)
	var flash := Sprite3D.new()
	flash.texture = PENTAGRAM
	flash.pixel_size = 0.0031
	flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flash.shaded = false
	flash.position = at
	$Effects.add_child(flash)
	var brilho := create_tween().bind_node(flash).set_parallel(true)
	brilho.tween_property(flash, "scale", Vector3.ONE * 3.0, 0.35)
	brilho.tween_property(flash, "modulate:a", 0.0, 0.35)
	brilho.chain().tween_callback(flash.queue_free)

# Som nítido por cima e ecos em cascata atrás, como no Super Maycon Brother.
func pickup_sound() -> void:
	var base_pitch := 1.25
	var orig_vol := -10.0
	var orig := AudioStreamPlayer.new()
	orig.stream = PICKUP_SOUND
	orig.pitch_scale = base_pitch
	orig.volume_db = orig_vol
	add_child(orig)
	orig.finished.connect(orig.queue_free)
	orig.play()
	var bg_vol := orig_vol - 8.5
	var echo_delays := [0.13, 0.26, 0.39, 0.54]
	var echo_vols := [-5.0, -9.0, -13.0, -17.0]
	var echo_pitches := [1.02, 1.05, 1.08, 1.11]
	for idx in echo_delays.size():
		var delay_time:float = echo_delays[idx]
		var echo_vol:float = bg_vol + echo_vols[idx]
		var echo_pitch:float = base_pitch * echo_pitches[idx]
		get_tree().create_timer(delay_time).timeout.connect(func():
			if not is_instance_valid(self):
				return
			var echo := AudioStreamPlayer.new()
			echo.stream = PICKUP_SOUND
			if AudioServer.get_bus_index("ItemReverb") >= 0:
				echo.bus = "ItemReverb"
			echo.pitch_scale = echo_pitch
			echo.volume_db = echo_vol
			add_child(echo)
			echo.finished.connect(echo.queue_free)
			echo.play())

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
	if is_instance_valid(final_battle) and final_battle.engaged:
		final_battle.retry()
		return
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
	# Fora da arena a câmera volta a ser da fase, então o ponteiro volta também.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.velocity = Vector3.ZERO
	if is_instance_valid(boss_bar):
		boss_bar.visible = false
	$HUD/Stats.visible = false
	$HUD/Pentagramas.visible = false
	if is_instance_valid(wind):
		wind.visible = false
	set_blur(BLUR_CUTSCENE, Vector2(0.5, 0.5))
	await victory_cutscene()
	fade.color = Color(1, 1, 1, 0)
	await fade_to(1.0, 3.0)
	get_tree().change_scene_to_file("res://scenes/3D/resgate_cabeludo/ending_bridge.tscn")

# Fim da fase: o Maycon se levanta, vai até a jaula e vira o Maycon 2D do menu.
func victory_cutscene() -> void:
	# A jaula para de quicar para o plano ficar firme.
	if is_instance_valid(cage):
		cage.freeze = true
		cage.rotation = Vector3.ZERO
	var jaula_pos:Vector3 = cage.global_position if is_instance_valid(cage) else player.global_position + Vector3(0, 1.4, -8)
	# Ele cai no chão e se levanta ali mesmo, como na abertura.
	lay_player_down()
	await camera_atras(2.2, 0.9)
	await rise_player()
	# Caminhada até a jaula, parando a poucos passos dela.
	var parada:Vector3 = jaula_pos + (player.global_position - jaula_pos).normalized() * 3.2
	parada.y = player.global_position.y
	player.visual.rotation.y = atan2(jaula_pos.x - parada.x, jaula_pos.z - parada.z)
	var saida:Vector3 = player.global_position
	var passos := create_tween()
	passos.tween_method(func(t:float):
		player.global_position = saida.lerp(parada, t)
		encaixar_camera(0.0)
	, 0.0, 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	await passos.finished
	await transformar_em_2d()
	await despedida()

# Câmera nas costas do Maycon, com a jaula logo à frente.
func camera_atras(atras:float, duracao:float) -> void:
	var alvo := postura_camera(atras)
	var vinda := create_tween()
	vinda.tween_method(func(t:float):
		camera.global_position = camera.global_position.lerp(alvo, t)
		camera.look_at(mira_camera())
	, 0.0, 1.0, duracao)
	await vinda.finished

func postura_camera(atras:float) -> Vector3:
	# O modelo do Maycon aponta para o próprio +z: é para lá que ele corre.
	var frente:Vector3 = player.visual.global_transform.basis.z
	frente.y = 0.0
	if frente.length_squared() < 0.01:
		frente = Vector3.FORWARD
	return player.global_position - frente.normalized() * (3.4 + atras) + Vector3(0.8, 2.3, 0.0)

func mira_camera() -> Vector3:
	return player.global_position + Vector3.UP * 1.5

func encaixar_camera(atras:float) -> void:
	camera.global_position = postura_camera(atras)
	camera.look_at(mira_camera())

# A transformação é lenta e cheia de magia: o Maycon 3D se desfaz enquanto o
# Maycon 2D do menu aparece no lugar dele.
func transformar_em_2d() -> void:
	var dois_d := Sprite3D.new()
	dois_d.name = "Maycon2D"
	dois_d.texture = MAYCON_2D
	dois_d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dois_d.shaded = false
	dois_d.double_sided = true
	dois_d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Mesmo tamanho do Maycon 2D do menu principal.
	dois_d.pixel_size = 0.01
	dois_d.scale = Vector3.ONE * 1.4
	dois_d.modulate = Color(1, 1, 1, 0)
	$Effects.add_child(dois_d)
	dois_d.global_position = player.global_position + Vector3.UP * (0.74 * 1.4)
	# Magia girando em volta dele antes de a troca começar.
	for volta in 3:
		pickup_burst(player.global_position + Vector3.UP * randf_range(0.6, 1.8))
		pickup_sound()
		await get_tree().create_timer(0.45).timeout
	var base:Vector3 = player.visual.scale
	var troca := create_tween().set_parallel(true)
	troca.tween_property(player.visual, "scale", base * 0.05, 2.4).set_trans(Tween.TRANS_SINE)
	troca.tween_property(dois_d, "modulate:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	for volta in 4:
		troca.tween_callback(func(): pickup_burst(player.global_position + Vector3.UP * randf_range(0.5, 2.0))).set_delay(0.5 * float(volta))
	await troca.finished
	player.visual.visible = false
	player.visual.scale = base
	burst(dois_d.global_position, Color("ffe9a3"), 30)

# A frase entra devagar no meio da tela e fica seis segundos.
func despedida() -> void:
	var frase := Label.new()
	frase.name = "Despedida"
	frase.text = tr("RESGATE_HOME")
	frase.add_theme_font_size_override("font_size", 46)
	frase.add_theme_color_override("font_color", Color("fdf6e3"))
	frase.add_theme_color_override("font_outline_color", Color("15291e"))
	frase.add_theme_constant_override("outline_size", 10)
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frase.modulate.a = 0.0
	$HUD.add_child(frase)
	frase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var entrada := create_tween()
	entrada.tween_property(frase, "modulate:a", 1.0, 2.0)
	await entrada.finished
	await get_tree().create_timer(6.0).timeout
