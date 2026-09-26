class_name DungeonGiantZombie
extends Node3D

# Zumbi GIGANTE que fica do lado de fora do mapa, na escuridão, olhando para dentro
# do cenário por uma abertura na parede. Usa o modelo real infected_zombie_animated
# (mesmo dos outros infectados) porém em escala gigante, e é animado por um
# AnimationPlayer com animações de verdade (geradas por ZombieAnimationFactory e
# salvas em .res para edição). Quando o player passa, ele fica olhando, se prepara
# (aguarda um instante), depois ataca enfiando a mão. Se agarrar, balança o player e
# o mata espirrando sangue.

const ZOMBIE_MODEL := preload("res://assets/horror_creatures/infected_zombie_animated.glb")

const ZOMBIE_GROWL := preload("res://assets/novos_audios/calabouco_terror/zombie_growl_2.wav")
const ZOMBIE_ROAR := preload("res://assets/novos_audios/calabouco_terror/monster_roar_1.wav")
const ZOMBIE_ROAR_2 := preload("res://assets/novos_audios/calabouco_terror/monster_roar_2.wav")
const ZOMBIE_SCREAM := preload("res://assets/novos_audios/calabouco_terror/monster_scream_1.wav")
const WALL_HIT := preload("res://assets/novos_audios/metal_batendo.mp3")
const WALL_HIT_HEAVY := preload("res://assets/novos_audios/calabouco_terror/dungeon_fall_impact.wav")
const MAYCON_SCREAM := preload("res://assets/novos_audios/maycon_falling_fase_1.mp3")

var player:DungeonPlayer
var dungeon:Node

# Configuração de posicionamento (mundo)
var face_dir:Vector3 = Vector3.FORWARD
var zone_center:Vector3 = Vector3.ZERO
var zone_half:Vector3 = Vector3(6, 3, 6)
var model_scale:float = 2.4

# Nós
var model_root:Node3D
var skel:Skeleton3D
var animator:AnimationPlayer
var grab_attachment:BoneAttachment3D
var grab_anchor:Marker3D
var eye_lights:Array[OmniLight3D] = []

# Áudio
var growl_audio:AudioStreamPlayer3D
var roar_audio:AudioStreamPlayer3D
var impact_audio:AudioStreamPlayer3D
var scream_audio:AudioStreamPlayer

# Estado
var busy:bool = false
var state:String = "watch"
var cooldown:float = 0.0
var growl_cooldown:float = 0.0
var phase:float = 0.0

const CONSIDER_TIME:float = 0.9    # fica olhando um instante antes de decidir
const TELEGRAPH_TIME:float = 1.4   # tempo que o player tem para sair enquanto ele se prepara
const STRIKE_DELAY:float = 0.3     # momento do impacto dentro da animação de ataque
const GRAB_RADIUS:float = 3.2
const REST_COOLDOWN:float = 4.0

func setup(target:DungeonPlayer, owner_dungeon:Node, config:Dictionary) -> void:
	player = target
	dungeon = owner_dungeon
	position = config.get("body_pos", Vector3.ZERO)
	face_dir = (config.get("face_dir", Vector3.FORWARD) as Vector3).normalized()
	zone_center = config.get("zone_center", position)
	zone_half = config.get("zone_half", Vector3(6, 3, 6))
	model_scale = config.get("scale", 2.4)
	# A frente do modelo (+Z local) aponta para dentro do cenário
	rotation.y = atan2(face_dir.x, face_dir.z)
	build_body()
	build_audio()

func build_body() -> void:
	model_root = ZOMBIE_MODEL.instantiate() as Node3D
	model_root.scale = Vector3.ONE * model_scale
	add_child(model_root)
	skel = model_root.find_child("Skeleton3D", true, false) as Skeleton3D

	# Descarta o AnimationPlayer do glb (animações achatadas) e cria um novo com
	# animações reais e editáveis.
	var old_player := model_root.find_child("AnimationPlayer", true, false)
	if is_instance_valid(old_player):
		old_player.queue_free()
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	model_root.add_child(animator)
	animator.add_animation_library("", ZombieAnimationFactory.load_or_build(skel))
	animator.play("watch")

	setup_grab_anchor()
	setup_eye_glow()

func setup_grab_anchor() -> void:
	grab_attachment = BoneAttachment3D.new()
	grab_attachment.name = "GrabHandAttachment"
	if is_instance_valid(skel):
		grab_attachment.bone_name = &"CityDeadOutfit_RightHand"
		skel.add_child(grab_attachment)
	else:
		add_child(grab_attachment)
	grab_anchor = Marker3D.new()
	grab_anchor.name = "GrabAnchor"
	grab_anchor.position = Vector3(0, 0, 0.05)
	grab_attachment.add_child(grab_anchor)

func setup_eye_glow() -> void:
	if not is_instance_valid(skel):
		return
	var head_att := BoneAttachment3D.new()
	head_att.name = "HeadGlow"
	head_att.bone_name = &"CityDeadOutfit_Head"
	skel.add_child(head_att)
	for sx in [-0.06, 0.06]:
		var eye := OmniLight3D.new()
		eye.light_color = Color(1.0, 0.06, 0.02)
		eye.light_energy = 2.6
		eye.omni_range = 4.0
		eye.position = Vector3(sx, 0.06, 0.1)
		head_att.add_child(eye)
		eye_lights.append(eye)

func build_audio() -> void:
	growl_audio = make_audio_3d(ZOMBIE_GROWL, -2.0, 45.0)
	roar_audio = make_audio_3d(ZOMBIE_ROAR, 0.0, 52.0)
	impact_audio = make_audio_3d(WALL_HIT, 3.0, 46.0)
	scream_audio = AudioStreamPlayer.new()
	scream_audio.stream = MAYCON_SCREAM
	scream_audio.volume_db = 2.0
	add_child(scream_audio)

func make_audio_3d(stream:AudioStream, volume_db:float, max_distance:float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.volume_db = volume_db
	audio.max_distance = max_distance
	audio.unit_size = 8.0
	if is_instance_valid(skel):
		var att := BoneAttachment3D.new()
		att.bone_name = &"CityDeadOutfit_Head"
		skel.add_child(att)
		att.add_child(audio)
	else:
		add_child(audio)
	return audio

func _physics_process(delta:float) -> void:
	if !is_instance_valid(player):
		return
	phase += delta
	growl_cooldown = maxf(0.0, growl_cooldown - delta)
	cooldown = maxf(0.0, cooldown - delta)
	for light in eye_lights:
		if is_instance_valid(light):
			light.light_energy = 2.2 + absf(sin(phase * 2.1)) * 1.5

	if busy:
		return
	var sequence_running:bool = bool(dungeon.get("sequence_running"))
	if not sequence_running and cooldown <= 0.0 and player_in_zone():
		attempt_grab()
	elif growl_cooldown <= 0.0 and player_near():
		growl_cooldown = randf_range(4.5, 8.0)
		if is_instance_valid(growl_audio):
			growl_audio.pitch_scale = randf_range(0.72, 0.9)
			growl_audio.play()

func player_in_zone() -> bool:
	var p := player.global_position
	return absf(p.x - zone_center.x) <= zone_half.x \
		and absf(p.z - zone_center.z) <= zone_half.z \
		and absf(p.y - zone_center.y) <= zone_half.y + 2.0

func player_near() -> bool:
	return player.global_position.distance_to(zone_center) <= zone_half.length() + 12.0

func attempt_grab() -> void:
	busy = true
	# 1) Fica olhando o player um instante
	state = "watch"
	if is_instance_valid(growl_audio):
		growl_audio.pitch_scale = randf_range(0.7, 0.85)
		growl_audio.play()
	await get_tree().create_timer(CONSIDER_TIME).timeout
	if not _valid():
		return
	if not player_in_zone():
		reset_to_watch()
		return

	# 2) Se prepara (aguarda um instante bom) — dá tempo do player correr
	state = "prepare"
	if is_instance_valid(animator):
		animator.play("prepare", 0.25)
	if is_instance_valid(roar_audio):
		roar_audio.stream = ZOMBIE_ROAR if randf() < 0.5 else ZOMBIE_ROAR_2
		roar_audio.pitch_scale = randf_range(0.82, 0.98)
		roar_audio.play()
	await get_tree().create_timer(TELEGRAPH_TIME).timeout
	if not _valid():
		return
	if not player_in_zone():
		reset_to_watch()
		return

	# 3) Ataca (enfia a mão)
	state = "attack"
	if is_instance_valid(animator):
		animator.play("attack", 0.1)
	if is_instance_valid(roar_audio):
		roar_audio.stream = ZOMBIE_SCREAM
		roar_audio.pitch_scale = randf_range(0.9, 1.05)
		roar_audio.play()
	await get_tree().create_timer(STRIKE_DELAY).timeout
	if not _valid():
		return

	if player_in_zone() and grab_anchor.global_position.distance_to(player.global_position + Vector3.UP * 0.9) <= GRAB_RADIUS:
		await do_grab_kill()
	else:
		# Errou: fecha a mão no vazio, recua e entra em cooldown
		if is_instance_valid(impact_audio):
			impact_audio.stream = WALL_HIT_HEAVY
			impact_audio.pitch_scale = randf_range(0.7, 0.85)
			impact_audio.play()
		if is_instance_valid(player):
			player.shake_camera(0.08, 0.35)
		await get_tree().create_timer(0.5).timeout
		reset_to_watch()

func reset_to_watch() -> void:
	if is_instance_valid(animator):
		animator.play("watch", 0.35)
	cooldown = REST_COOLDOWN
	state = "watch"
	busy = false

func do_grab_kill() -> void:
	state = "grab"
	if not bool(dungeon.call("begin_giant_grab", self, grab_anchor)):
		reset_to_watch()
		return
	if is_instance_valid(animator):
		animator.play("grab", 0.12)
	if is_instance_valid(roar_audio):
		roar_audio.stream = ZOMBIE_SCREAM
		roar_audio.pitch_scale = randf_range(0.85, 1.0)
		roar_audio.play()
	play_maycon_scream()
	dungeon.call("giant_grab_bleed", 0.6)

	# Balança o player: cada extremo do balanço vira uma batida contra a parede
	var slams := 4
	for i in slams:
		await get_tree().create_timer(0.45).timeout
		if not _valid():
			return
		if is_instance_valid(impact_audio):
			impact_audio.stream = WALL_HIT if i % 2 == 0 else WALL_HIT_HEAVY
			impact_audio.pitch_scale = randf_range(0.72, 0.95)
			impact_audio.play()
		if i == 0 or randf() < 0.7:
			play_maycon_scream()
		dungeon.call("giant_wall_impact", 0.9)

	dungeon.call("giant_grab_bleed", 1.0)
	if is_instance_valid(roar_audio):
		roar_audio.stream = ZOMBIE_ROAR
		roar_audio.pitch_scale = 0.8
		roar_audio.play()
	dungeon.call("finish_giant_grab_kill", self)

func play_maycon_scream() -> void:
	if is_instance_valid(scream_audio):
		scream_audio.pitch_scale = randf_range(1.0, 1.15)
		scream_audio.play()

func _valid() -> bool:
	return is_instance_valid(self) and is_instance_valid(player) and is_instance_valid(dungeon)
