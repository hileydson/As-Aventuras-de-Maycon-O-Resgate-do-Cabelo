@tool
class_name DungeonGiantZombie
extends Node3D

# Zumbi GIGANTE que fica do lado de fora do mapa, na escuridão, olhando para dentro
# do cenário por uma abertura na parede, ou segurando a estrutura do calabouço.
# Usa o modelo real infected_zombie_animated em escala gigante, animado por AnimationPlayer
# com suporte a edição manual no viewport 3D da Godot e no Inspector.

const ZOMBIE_MODEL := preload("res://assets/horror_creatures/infected_zombie_animated.glb")

const ZOMBIE_GROWL := preload("res://assets/novos_audios/calabouco_terror/zombie_growl_2.wav")
const ZOMBIE_ROAR := preload("res://assets/novos_audios/calabouco_terror/monster_roar_1.wav")
const ZOMBIE_ROAR_2 := preload("res://assets/novos_audios/calabouco_terror/monster_roar_2.wav")
const ZOMBIE_SCREAM := preload("res://assets/novos_audios/calabouco_terror/monster_scream_1.wav")
const WALL_HIT := preload("res://assets/novos_audios/metal_batendo.mp3")
const WALL_HIT_HEAVY := preload("res://assets/novos_audios/calabouco_terror/giant_head_slam.ogg")
const MAYCON_SCREAM := preload("res://assets/novos_audios/maycon_falling_fase_1.mp3")

@export_group("Configurações do Zumbi Gigante")
@export var is_decorative_only: bool = false
@export var active_attack: bool = true
@export var model_scale: float = 3.0:
	set(val):
		model_scale = val
		if is_instance_valid(model_root):
			model_root.scale = Vector3.ONE * model_scale
@export_enum("watch", "prepare", "attack", "grab", "hold_structure", "idle") var default_pose: String = "watch":
	set(val):
		default_pose = val
		if is_instance_valid(animator) and animator.has_animation(val):
			animator.play(val)

@export_group("Zona de Ataque")
@export var zone_center: Vector3 = Vector3.ZERO
@export var zone_half: Vector3 = Vector3(6, 3, 6)

var player: DungeonPlayer
var dungeon: Node

# Configuração de posicionamento (mundo)
var face_dir: Vector3 = Vector3.FORWARD

# Nós
var model_root: Node3D
var skel: Skeleton3D
var animator: AnimationPlayer
var grab_attachment: BoneAttachment3D
var grab_anchor: Marker3D
var head_attachment: BoneAttachment3D
var head_top_attachment: BoneAttachment3D
var eye_lights: Array[OmniLight3D] = []

# Áudio
var growl_audio: AudioStreamPlayer3D
var roar_audio: AudioStreamPlayer3D
var impact_audio: AudioStreamPlayer3D
var scream_audio: AudioStreamPlayer

# Estado
var busy: bool = false
var state: String = "watch"
var cooldown: float = 0.0
var growl_cooldown: float = 0.0
var head_contact_cooldown: float = 0.0
var phase: float = 0.0

const CONSIDER_TIME: float = 0.9    # fica olhando um instante antes de decidir
const TELEGRAPH_TIME: float = 1.4   # tempo que o player tem para sair enquanto ele se prepara
const STRIKE_DELAY: float = 0.3     # momento do impacto dentro da animação de ataque
const GRAB_RADIUS: float = 3.8
const GRAB_WINDOW: float = 0.55     # a mão continua podendo agarrar durante todo o golpe
const REST_COOLDOWN: float = 4.0

# O crânio mede ~3.3 unidades do osso da cabeça até o topo (o modelo roda em ~15x),
# então ele é tratado como um segmento inteiro, e não como um ponto: era por isso que
# a testa encostava no player sem registrar nada.
const HEAD_CONTACT_RADIUS: float = 2.2
const HEAD_DUST_MAX_Y: float = 4.0      # só levanta poeira quando a cabeça está baixa
const HEAD_DUST_MIN_SPEED: float = 2.5  # e só quando está varrendo, não parada balançando
const HEAD_DUST_MIN_STEP: float = 0.9   # espaçamento entre as marcas do rastro
const HEAD_DUST_SPREAD: float = 3.5     # raio do espalhamento lateral de cada marca
const HEAD_DUST_SATELLITES: int = 2     # marcas extras jogadas ao redor de cada ponto
const HEAD_DUST_MAX_PER_PASS: int = 30  # teto por varrida, para não estourar partículas

var previous_head_position: Vector3 = Vector3.ZERO
var previous_head_top_position: Vector3 = Vector3.ZERO
var has_previous_head_position: bool = false
var last_dust_position: Vector3 = Vector3.ZERO
var has_last_dust_position: bool = false
var head_dust_budget: int = HEAD_DUST_MAX_PER_PASS

func _ready() -> void:
	ensure_body()
	if Engine.is_editor_hint():
		set_physics_process(false)
		if is_instance_valid(animator) and animator.has_animation(default_pose):
			animator.play(default_pose)
		return
	
	build_audio()
	if is_decorative_only or not active_attack:
		set_physics_process(false)
		if is_instance_valid(animator) and animator.has_animation(default_pose):
			animator.play(default_pose)

func ensure_body() -> void:
	if is_instance_valid(model_root):
		return
	var existing = find_child("infected_zombie_animated", false, false) as Node3D
	if existing != null:
		model_root = existing
		model_root.scale = Vector3.ONE * model_scale
		skel = model_root.find_child("Skeleton3D", true, false) as Skeleton3D
		animator = model_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator == null:
			animator = AnimationPlayer.new()
			animator.name = "AnimationPlayer"
			model_root.add_child(animator)
			if is_instance_valid(skel):
				animator.add_animation_library("", ZombieAnimationFactory.load_or_build(skel))
		elif not animator.has_animation_library(""):
			if is_instance_valid(skel):
				animator.add_animation_library("", ZombieAnimationFactory.load_or_build(skel))
		elif not animator.has_animation("hold_structure"):
			animator.remove_animation_library("")
			if is_instance_valid(skel):
				animator.add_animation_library("", ZombieAnimationFactory.load_or_build(skel))
		if is_instance_valid(animator) and animator.has_animation(default_pose):
			animator.play(default_pose)
		setup_grab_anchor()
		setup_eye_glow()
	else:
		build_body()

func setup(target: DungeonPlayer, owner_dungeon: Node, config: Dictionary = {}) -> void:
	player = target
	dungeon = owner_dungeon
	if not config.is_empty():
		if position == Vector3.ZERO and config.has("body_pos"):
			position = config.get("body_pos", position)
			face_dir = (config.get("face_dir", face_dir) as Vector3).normalized()
			rotation.y = atan2(face_dir.x, face_dir.z)
		if zone_center == Vector3.ZERO:
			zone_center = config.get("zone_center", position)
		if zone_half == Vector3(6, 3, 6):
			zone_half = config.get("zone_half", zone_half)
		if config.has("scale"):
			model_scale = config.get("scale", model_scale)
	elif zone_center == Vector3.ZERO:
		zone_center = position
	ensure_body()
	if growl_audio == null and not Engine.is_editor_hint():
		build_audio()
	if is_decorative_only or not active_attack:
		set_physics_process(false)
		if is_instance_valid(animator) and animator.has_animation(default_pose):
			animator.play(default_pose)

func build_body() -> void:
	if is_instance_valid(model_root):
		return
	model_root = ZOMBIE_MODEL.instantiate() as Node3D
	model_root.name = "infected_zombie_animated"
	model_root.scale = Vector3.ONE * model_scale
	add_child(model_root)
	skel = model_root.find_child("Skeleton3D", true, false) as Skeleton3D

	var old_player := model_root.find_child("AnimationPlayer", true, false)
	if is_instance_valid(old_player):
		old_player.queue_free()
	animator = AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	model_root.add_child(animator)
	if is_instance_valid(skel) and not animator.has_animation_library(""):
		animator.add_animation_library("", ZombieAnimationFactory.load_or_build(skel))
	if animator.has_animation(default_pose):
		animator.play(default_pose)

	setup_grab_anchor()
	setup_eye_glow()

func setup_grab_anchor() -> void:
	if find_child("GrabAnchor", true, false) != null:
		return
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
	if skel.find_child("HeadGlow", true, false) != null:
		return
	head_attachment = BoneAttachment3D.new()
	head_attachment.name = "HeadGlow"
	head_attachment.bone_name = &"CityDeadOutfit_Head"
	skel.add_child(head_attachment)
	head_top_attachment = BoneAttachment3D.new()
	head_top_attachment.name = "HeadTopPoint"
	head_top_attachment.bone_name = &"CityDeadOutfit_HeadTop_End"
	skel.add_child(head_top_attachment)
	for sx in [-0.06, 0.06]:
		var eye := OmniLight3D.new()
		eye.light_color = Color(1.0, 0.06, 0.02)
		eye.light_energy = 2.6
		eye.omni_range = 4.0
		eye.position = Vector3(sx, 0.06, 0.1)
		head_attachment.add_child(eye)
		eye_lights.append(eye)

func build_audio() -> void:
	if is_instance_valid(growl_audio):
		return
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
	if Engine.is_editor_hint():
		return
	if is_decorative_only or not active_attack:
		return
	if !is_instance_valid(player) or !is_instance_valid(dungeon):
		return
	phase += delta
	growl_cooldown = maxf(0.0, growl_cooldown - delta)
	cooldown = maxf(0.0, cooldown - delta)
	head_contact_cooldown = maxf(0.0, head_contact_cooldown - delta)
	for light in eye_lights:
		if is_instance_valid(light):
			light.light_energy = 2.2 + absf(sin(phase * 2.1)) * 1.5
	_track_head(delta)

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

func _track_head(delta:float) -> void:
	if !is_instance_valid(head_attachment):
		return
	var head_now := head_attachment.global_position
	var top_now := head_top_attachment.global_position if is_instance_valid(head_top_attachment) else head_now
	var head_before := previous_head_position if has_previous_head_position else head_now
	var top_before := previous_head_top_position if has_previous_head_position else top_now
	previous_head_position = head_now
	previous_head_top_position = top_now
	has_previous_head_position = true
	var head_speed := head_before.distance_to(head_now) / maxf(delta, 0.0001)
	# O crânio inteiro agora, mais o rastro da base e do topo no quadro: cobre tanto
	# encostar de raspão quanto a descida rápida demais para um teste por quadro.
	_check_head_contact([
		[head_now, top_now],
		[head_before, head_now],
		[top_before, top_now],
	])
	_spread_head_ground_dust(head_now, head_speed)

func _spread_head_ground_dust(head_now:Vector3, head_speed:float) -> void:
	if head_now.y > HEAD_DUST_MAX_Y || head_speed < HEAD_DUST_MIN_SPEED:
		head_dust_budget = HEAD_DUST_MAX_PER_PASS
		return
	if head_dust_budget <= 0:
		return
	if has_last_dust_position && last_dust_position.distance_to(head_now) < HEAD_DUST_MIN_STEP:
		return
	last_dust_position = head_now
	has_last_dust_position = true
	head_dust_budget -= 1
	dungeon.call("spawn_dust_landing", Vector3(head_now.x, 0.05, head_now.z))
	for _i in HEAD_DUST_SATELLITES:
		if head_dust_budget <= 0:
			return
		head_dust_budget -= 1
		var angulo := randf() * TAU
		var raio := randf_range(1.2, HEAD_DUST_SPREAD)
		dungeon.call("spawn_dust_landing", Vector3(head_now.x + cos(angulo) * raio, 0.05, head_now.z + sin(angulo) * raio))

func _check_head_contact(segmentos:Array) -> void:
	if head_contact_cooldown > 0.0:
		return
	var corpo_a := player.global_position + Vector3.UP * 0.15
	var corpo_b := player.global_position + Vector3.UP * 1.75
	var menor_distancia := INF
	var contact_point := Vector3.ZERO
	for segmento in segmentos:
		var pontos := Geometry3D.get_closest_points_between_segments(segmento[0], segmento[1], corpo_a, corpo_b)
		var distancia: float = pontos[0].distance_to(pontos[1])
		if distancia < menor_distancia:
			menor_distancia = distancia
			contact_point = pontos[0]
	if menor_distancia > HEAD_CONTACT_RADIUS:
		return
	var knockback := player.global_position - contact_point
	knockback.y = 0.0
	if knockback.length_squared() < 0.01:
		knockback = -global_transform.basis.z
	head_contact_cooldown = 1.15
	if is_instance_valid(impact_audio):
		impact_audio.stream = WALL_HIT_HEAVY
		impact_audio.volume_db = 7.0
		impact_audio.pitch_scale = randf_range(0.82, 0.96)
		impact_audio.play()
	dungeon.call("spawn_dust_landing", Vector3(contact_point.x, 0.05, contact_point.z))
	player.apply_knockback(knockback.normalized() * 13.0 + Vector3.UP * 4.5, 0.78)
	player.shake_camera(0.16, 0.55)
	dungeon.call("flash_blood_damage_overlay", 0.7)
	player.take_damage(player.max_hp * 0.25)

func player_in_zone() -> bool:
	if !is_instance_valid(player):
		return false
	var p := player.global_position
	var check_center = zone_center if zone_center != Vector3.ZERO else global_position
	return absf(p.x - check_center.x) <= zone_half.x \
		and absf(p.z - check_center.z) <= zone_half.z \
		and absf(p.y - check_center.y) <= zone_half.y + 2.0

func player_near() -> bool:
	if !is_instance_valid(player):
		return false
	var check_center = zone_center if zone_center != Vector3.ZERO else global_position
	return player.global_position.distance_to(check_center) <= zone_half.length() + 12.0

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

	# A mão fica "quente" durante todo o golpe: antes isso era testado num único
	# quadro, então o player podia estar bem na frente e mesmo assim escapar.
	var reached := false
	var window := GRAB_WINDOW
	while window > 0.0:
		if player_in_zone() and grab_anchor.global_position.distance_to(player.global_position + Vector3.UP * 0.9) <= GRAB_RADIUS:
			reached = true
			break
		await get_tree().physics_frame
		if not _valid():
			return
		window -= get_physics_process_delta_time()

	if reached:
		await do_grab_kill()
	else:
		# Errou: fecha a mão no vazio, recua e entra em cooldown
		if is_instance_valid(impact_audio):
			impact_audio.stream = WALL_HIT_HEAVY
			impact_audio.volume_db = 3.0
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
			impact_audio.volume_db = 3.0
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

func take_damage(_amount:int, _weapon_type:String = "pistol", _hit_pos:Vector3 = Vector3.ZERO, _hit_dir:Vector3 = Vector3.ZERO) -> void:
	if is_instance_valid(growl_audio) and not growl_audio.is_playing():
		growl_audio.pitch_scale = randf_range(0.85, 1.1)
		growl_audio.play()
