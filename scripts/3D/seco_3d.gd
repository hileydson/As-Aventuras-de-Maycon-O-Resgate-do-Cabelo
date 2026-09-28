extends CharacterBody3D

@onready var growl_2: AudioStreamPlayer = $"../Growl2"
@onready var growl_3: AudioStreamPlayer = $"../Growl3"
@onready var seco_3d_power: AudioStreamPlayer = $"../Seco3dPower"
@onready var timer_enemy_attack: Timer = $"../Timer_enemy_attack"
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var progress_bar: ProgressBar = $"../CanvasLayer/ProgressBar"
@onready var mark_progressbar_two_player: Marker2D = $"../CanvasLayer/mark_progressbar_two_player"
@onready var olindao_3d_animations: Node3D = $"../olindao_3d_animations"
@onready var animation_tree: AnimationTree = $"../olindao_3d_animations/AnimationTree"

# Arraste o arquivo da OndaDePoder.tscn para cá no Inspetor
@export var onda_scene : PackedScene 

const ARENA_LIMIT: float = 19.0
const WALK_SPEED: float = 2.3
var model_offset: Vector3
var roam_target: Vector3
var roam_timer: float = 0.0
var attacking: bool = false

func disparar_onda():
	var nova_onda = onda_scene.instantiate()
	# Adicione 0.1 ou 0.2 no eixo Y para ela "flutuar" sobre o chão
	get_tree().current_scene.add_child(nova_onda)
	nova_onda.global_position = global_position + Vector3(0, 0.1, 0)
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	model_offset = olindao_3d_animations.global_position - global_position
	roam_target = global_position
	animation_tree.get("parameters/playback").travel("scream") # .get_node("AnimationPlayer").play("Skill_03")
	await get_tree().create_timer(1.2).timeout
	animation_tree.get("parameters/playback").travel("idle_slow_walk") #.get_node("AnimationPlayer").play("Walking")
	timer_enemy_attack.start()
	#await get_tree().create_timer(1.2).timeout	

func _physics_process(delta: float) -> void:
	if attacking:
		return

	roam_timer -= delta
	var direction := roam_target - global_position
	direction.y = 0.0
	if roam_timer <= 0.0 or direction.length() < 1.0:
		_pick_roam_target()
		direction = roam_target - global_position
		direction.y = 0.0

	if direction.length_squared() > 0.01:
		var step := direction.normalized() * minf(WALK_SPEED * delta, direction.length())
		global_position = Vector3(
			clampf(global_position.x + step.x, -ARENA_LIMIT, ARENA_LIMIT),
			0.0,
			clampf(global_position.z + step.z, -ARENA_LIMIT, ARENA_LIMIT)
		)
		olindao_3d_animations.global_position = global_position + model_offset
		olindao_3d_animations.rotation.y = lerp_angle(olindao_3d_animations.rotation.y, atan2(direction.x, direction.z), delta * 3.0)

func _pick_roam_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	var center := Vector3.ZERO
	if not players.is_empty():
		center = players.pick_random().global_position
	roam_target = Vector3(
		clampf(center.x + randf_range(-9.0, 9.0), -ARENA_LIMIT, ARENA_LIMIT),
		0.0,
		clampf(center.z + randf_range(-9.0, 9.0), -ARENA_LIMIT, ARENA_LIMIT)
	)
	roam_timer = randf_range(3.0, 5.5)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.is_two_player_active:
		progress_bar.global_position = mark_progressbar_two_player.global_position
		


func _on_timer_enemy_attack_timeout() -> void:
	attacking = true
	growl_2.play()
	animated_sprite_3d.play("power_attack_1")
	animation_tree.get("parameters/playback").travel("attack_1") #.get_node("AnimationPlayer").play("Slow_Orc_Walk")
	await get_tree().create_timer(0.6).timeout
	disparar_onda()
	await get_tree().create_timer(0.6).timeout
	attacking = false
	#await get_tree().create_timer(1.0).timeout
	#animation_tree.get("parameters/playback").travel("idle_slow_walk") #.get_node("AnimationPlayer").play("Walking")


func _on_animated_sprite_3d_animation_finished() -> void:
	animated_sprite_3d.play("idle")
