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

func disparar_onda():
	var nova_onda = onda_scene.instantiate()
	# Adicione 0.1 ou 0.2 no eixo Y para ela "flutuar" sobre o chão
	nova_onda.global_position = global_position + Vector3(0, 0.1, 0)
	get_tree().current_scene.add_child(nova_onda)
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_tree.get("parameters/playback").travel("scream") # .get_node("AnimationPlayer").play("Skill_03")
	await get_tree().create_timer(1.2).timeout
	animation_tree.get("parameters/playback").travel("idle_slow_walk") #.get_node("AnimationPlayer").play("Walking")
	timer_enemy_attack.start()
	#await get_tree().create_timer(1.2).timeout	
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.is_two_player_active:
		progress_bar.global_position = mark_progressbar_two_player.global_position
		


func _on_timer_enemy_attack_timeout() -> void:
	growl_2.play()
	animated_sprite_3d.play("power_attack_1")
	animation_tree.get("parameters/playback").travel("attack_1") #.get_node("AnimationPlayer").play("Slow_Orc_Walk")
	await get_tree().create_timer(0.8).timeout
	disparar_onda()
	await get_tree().create_timer(1.0).timeout
	animation_tree.get("parameters/playback").travel("idle_slow_walk") #.get_node("AnimationPlayer").play("Walking")


func _on_animated_sprite_3d_animation_finished() -> void:
	animated_sprite_3d.play("idle")
