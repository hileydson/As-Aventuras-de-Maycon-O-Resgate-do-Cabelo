extends Area3D
class_name PentagramItem3D

const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")
const HEAL_SOUND = preload("res://assets/novos_audios/sangue_fill_effect.mp3")

@export var heal_percent: float = 0.20
@export var respawn_time: float = 45.0

var time: float = 0.0
var base_y: float = 0.0
var is_collected: bool = false
var respawn_countdown: float = 0.0

var sprite: Sprite3D
var omni_light: OmniLight3D
var audio_player: AudioStreamPlayer3D
var collision: CollisionShape3D

func _init() -> void:
	# 1. Sprite3D do Pentagrama
	sprite = Sprite3D.new()
	sprite.name = "PentagramSprite"
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0055 # Diâmetro de ~2.8m, bem visível à distância
	sprite.shaded = false
	sprite.double_sided = true
	sprite.render_priority = 2
	add_child(sprite)
	
	# 2. Luz misteriosa pulsante (Magenta / Carmesim)
	omni_light = OmniLight3D.new()
	omni_light.name = "PentagramLight"
	omni_light.light_color = Color(1.0, 0.12, 0.42)
	omni_light.light_energy = 3.6
	omni_light.omni_range = 9.0
	omni_light.omni_attenuation = 1.1
	add_child(omni_light)
	
	# 3. Colisor esférico amplo para fácil coleta na moto
	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.4
	collision.shape = shape
	add_child(collision)
	
	# 4. Áudio 3D de recuperação de sangue
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "PickupSound"
	audio_player.stream = HEAL_SOUND
	audio_player.volume_db = 2.5
	audio_player.unit_size = 14.0
	audio_player.max_distance = 65.0
	add_child(audio_player)

func _ready() -> void:
	# Configurações de colisão
	collision_layer = 0
	collision_mask = 1 | 2 # Colide com player no chão ou moto
	monitoring = true
	monitorable = true
	
	time = randf_range(0.0, 20.0)
	if base_y == 0.0:
		base_y = position.y
	
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_collected:
		if respawn_countdown > 0.0:
			respawn_countdown -= delta
			if respawn_countdown <= 0.0:
				respawn()
		return
	
	# Animação de pulso contínuo para ser visto de longe
	time += delta
	var pulse: float = 1.0 + sin(time * 3.8) * 0.22 # Pulsação de escala ±22%
	sprite.scale = Vector3.ONE * pulse
	sprite.rotation.z = time * 1.1 # Giro místico lento
	omni_light.light_energy = 3.2 + sin(time * 4.4) * 1.6 # Farol pulsando luz nas ruas
	position.y = base_y + sin(time * 2.4) * 0.26 # Levitação suave

func _on_body_entered(body: Node3D) -> void:
	if is_collected:
		return
	var player: CharacterBody3D = null
	if body is CharacterBody3D:
		player = body
	elif body.is_in_group("player"):
		player = body as CharacterBody3D
	elif body.get_parent() is CharacterBody3D:
		player = body.get_parent() as CharacterBody3D
		
	if is_instance_valid(player) and !is_collected:
		collect(player)

func collect(player: CharacterBody3D) -> void:
	is_collected = true
	respawn_countdown = respawn_time
	
	# Cura 20% do sangue do jogador
	if player.has_method("curar_sangue"):
		player.curar_sangue(heal_percent)
	
	if is_inside_tree() and audio_player.is_inside_tree():
		audio_player.play()
	
	# Animação de absorção / coleta
	if is_inside_tree():
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", sprite.scale * 1.65, 0.28)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.28)
		tween.tween_property(omni_light, "light_energy", 0.0, 0.28)
		await tween.finished
	
	sprite.visible = false
	omni_light.visible = false

func respawn() -> void:
	is_collected = false
	sprite.visible = true
	sprite.modulate.a = 1.0
	sprite.scale = Vector3.ONE
	omni_light.visible = true
	omni_light.light_energy = 3.6

func set_ground_position(ground_pos: Vector3, float_offset: float = 1.35) -> void:
	position = ground_pos + Vector3(0.0, float_offset, 0.0)
	base_y = position.y
