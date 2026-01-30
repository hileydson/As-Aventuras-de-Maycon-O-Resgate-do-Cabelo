extends CharacterBody3D

@onready var growl_2: AudioStreamPlayer = $"../Growl2"
@onready var growl_3: AudioStreamPlayer = $"../Growl3"
@onready var seco_3d_power: AudioStreamPlayer = $"../Seco3dPower"
@onready var timer_enemy_attack: Timer = $"../Timer_enemy_attack"
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D

# Arraste o arquivo da OndaDePoder.tscn para cá no Inspetor
@export var onda_scene : PackedScene 

func disparar_onda():
	var nova_onda = onda_scene.instantiate()
	# Adicione 0.1 ou 0.2 no eixo Y para ela "flutuar" sobre o chão
	nova_onda.global_position = global_position + Vector3(0, 0.2, 0)
	get_tree().current_scene.add_child(nova_onda)
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	timer_enemy_attack.start()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		


func _on_timer_enemy_attack_timeout() -> void:
	growl_2.play()
	animated_sprite_3d.play("power_attack_1")
	disparar_onda()


func _on_animated_sprite_3d_animation_finished() -> void:
	animated_sprite_3d.play("idle")
