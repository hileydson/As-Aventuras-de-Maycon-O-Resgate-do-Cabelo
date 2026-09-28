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
var beam: MeshInstance3D
var omni_light: OmniLight3D
var audio_player: AudioStreamPlayer3D
var collision: CollisionShape3D

func _init() -> void:
	# 1. Feixe de luz vertical luminoso (visível de longe por cima de muros e curvas)
	beam = MeshInstance3D.new()
	beam.name = "LightBeacon"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 1.1
	cyl.height = 24.0
	beam.mesh = cyl
	var beam_mat := StandardMaterial3D.new()
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.12, 0.45, 0.42)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	beam.position.y = 11.0
	add_child(beam)

	# 2. Sprite3D do Pentagrama
	sprite = Sprite3D.new()
	sprite.name = "PentagramSprite"
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = 0.0075 # Diâmetro de ~3.84m, visível de muito longe
	sprite.shaded = false
	sprite.double_sided = true
	sprite.render_priority = 3
	add_child(sprite)
	
	# 3. Luz misteriosa pulsante (Magenta / Carmesim)
	omni_light = OmniLight3D.new()
	omni_light.name = "PentagramLight"
	omni_light.light_color = Color(1.0, 0.15, 0.45)
	omni_light.light_energy = 5.0
	omni_light.omni_range = 22.0
	omni_light.omni_attenuation = 0.9
	add_child(omni_light)
	
	# 4. Colisor esférico amplo para fácil coleta na moto
	collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.8
	collision.shape = shape
	add_child(collision)
	
	# 5. Áudio 3D de recuperação de sangue
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
	omni_light.light_energy = 4.2 + sin(time * 4.4) * 2.2 # Farol pulsando luz nas ruas
	position.y = base_y + sin(time * 2.4) * 0.28 # Levitação suave
	if is_instance_valid(beam) and beam.material_override is StandardMaterial3D:
		var bm: StandardMaterial3D = beam.material_override
		bm.albedo_color.a = 0.35 + sin(time * 3.6) * 0.15

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
		# Somente permite coletar durante a perseguição
		if not player.motorcycle_chase:
			return
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
		if is_instance_valid(beam) and beam.material_override is StandardMaterial3D:
			tween.tween_property(beam.material_override, "albedo_color:a", 0.0, 0.28)
		await tween.finished
	
	sprite.visible = false
	omni_light.visible = false
	if is_instance_valid(beam):
		beam.visible = false

func respawn() -> void:
	is_collected = false
	sprite.visible = true
	sprite.modulate.a = 1.0
	sprite.scale = Vector3.ONE
	omni_light.visible = true
	omni_light.light_energy = 5.0
	if is_instance_valid(beam):
		beam.visible = true
		if beam.material_override is StandardMaterial3D:
			(beam.material_override as StandardMaterial3D).albedo_color.a = 0.42

func set_ground_position(ground_pos: Vector3, float_offset: float = 2.0) -> void:
	position = ground_pos + Vector3(0.0, float_offset, 0.0)
	base_y = position.y
