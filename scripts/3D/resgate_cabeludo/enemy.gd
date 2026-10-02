extends Node3D

const BATTLE = preload("res://scripts/realtime_battle.gd")
# Um conjunto de quadros por variante, reaproveitado por todos os inimigos iguais.
static var battle_frames:Dictionary = {}

@export_enum("patrol", "charge", "jumper") var behavior:String = "patrol"
@export var patrol_width:float = 3.5
@export var speed:float = 2.4
@export var blood_drop:bool = false
# Inimigo vindo da batalha em tempo real: mesma textura e mesmas animações de lá.
@export var variant_path:String = ""
@export_enum("minion", "dog") var variant_kind:String = "minion"
@export var variant_modulate:Color = Color.WHITE
@export var variant_height:float = 3.0
var home:Vector3
var phase:float = 0.0
var attack_clock:float = 2.0
var active:bool = true
var stage:Node3D
var battle_sprite:AnimatedSprite3D
var current_anim:String = ""

func _ready() -> void:
	home = global_position
	stage = get_tree().get_first_node_in_group("resgate_stage")
	add_to_group("resgate_enemies")
	if not variant_path.is_empty():
		build_battle_sprite()

func reset_element() -> void:
	active = true
	visible = true
	global_position = home
	phase = 0.0
	attack_clock = 2.0
	if battle_sprite:
		play_anim("run")

# Os quadros saem das mesmas funções que a batalha em tempo real usa, então a
# textura, a velocidade e o laço de cada animação são os de lá.
func load_frames() -> SpriteFrames:
	if battle_frames.has(variant_path):
		return battle_frames[variant_path]
	var builder:Node = BATTLE.new()
	var frames:SpriteFrames = null
	if variant_kind == "dog":
		frames = builder.build_dog_sprite_frames(variant_path)
	else:
		frames = builder.build_minion_sprite_frames(variant_path)
	builder.free()
	if frames != null and frames.get_animation_names().size() > 0:
		battle_frames[variant_path] = frames
		return frames
	return null

func build_battle_sprite() -> void:
	var frames := load_frames()
	if frames == null:
		return
	battle_sprite = AnimatedSprite3D.new()
	battle_sprite.name = "Battle"
	battle_sprite.sprite_frames = frames
	battle_sprite.modulate = variant_modulate
	battle_sprite.shaded = false
	battle_sprite.double_sided = true
	battle_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	battle_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(battle_sprite)
	var first:String = "run" if frames.has_animation("run") else frames.get_animation_names()[0]
	battle_sprite.play(first)
	current_anim = first
	# Cada folha tem o seu tamanho, então a escala sai da altura do quadro.
	var frame_tex:Texture2D = frames.get_frame_texture(first, 0)
	if frame_tex != null and frame_tex.get_height() > 0:
		battle_sprite.pixel_size = variant_height / float(frame_tex.get_height())
	battle_sprite.position.y = variant_height * 0.5

func play_anim(name:String) -> void:
	if battle_sprite == null or current_anim == name or not battle_sprite.sprite_frames.has_animation(name):
		return
	current_anim = name
	battle_sprite.play(name)

func _physics_process(delta:float) -> void:
	if not active or not is_instance_valid(stage) or not stage.player.control_enabled:
		return
	var player:CharacterBody3D = stage.player
	if absf(player.global_position.z - home.z) > 50.0:
		return
	phase += delta
	attack_clock -= delta
	var diff := player.global_position - global_position
	var distance := Vector2(diff.x, diff.z).length()
	if behavior == "charge" and distance < 10.0 and attack_clock < 0.0:
		var target := player.global_position
		target.y = home.y
		target.x = clampf(target.x, home.x - patrol_width, home.x + patrol_width)
		target.z = clampf(target.z, home.z - 4, home.z + 4)
		global_position = global_position.move_toward(target, speed * 2.0 * delta)
		if attack_clock < -1.2:
			attack_clock = 1.8
	else:
		global_position.x = home.x + sin(phase * speed * 0.5) * patrol_width
	if behavior == "jumper":
		global_position.y = home.y + absf(sin(phase * 2.2)) * 2.2
	if battle_sprite != null:
		battle_sprite.flip_h = diff.x < 0.0
		play_anim("attack" if distance < 2.6 else "run")
	elif has_node("Sprite"):
		$Sprite.frame = int(phase * 8.0) % $Sprite.hframes
	elif has_node("Visual"):
		$Visual.position.y = absf(sin(phase * 7.0)) * 0.12
	diff = player.global_position - global_position
	distance = Vector2(diff.x, diff.z).length()
	if distance < 0.95 and diff.y > 0.65 and diff.y < 2.1 and player.velocity.y < -0.8:
		player.bounce()
		defeat()
	elif distance < 0.85 and absf(diff.y) < 1.45:
		player.receive_damage(17.0, global_position)

func defeat() -> void:
	if not active:
		return
	active = false
	stage.burst(global_position + Vector3.UP, Color("c92942"), 14)
	stage.sound("hit")
	if blood_drop:
		stage.drop_blood(global_position + Vector3.UP * 0.5)
	# Com os quadros da batalha ele cai tocando a própria morte antes de sumir.
	if battle_sprite != null and battle_sprite.sprite_frames.has_animation("death"):
		play_anim("death")
		var fim := create_tween()
		fim.tween_interval(1.1)
		fim.tween_callback(func(): visible = false)
	else:
		visible = false
