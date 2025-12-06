extends AnimationPlayer

@onready var maycon: CharacterBody2D = $"../Maycon"
@onready var maycon_batalha: AnimatedSprite2D = $"../maycon_batalha"
@onready var maycon_batalha_default: AnimatedSprite2D = $"../maycon_batalha_default"
@onready var passos_areia: AudioStreamPlayer = $"../PassosAreia"
@onready var battle_song: AudioStreamPlayer2D = $"../Battle_Song"
@onready var victory_sound: AudioStreamPlayer2D = $"../victory_sound"
@onready var destroy: GPUParticles2D = $"../../Inimigos/destroy"

@onready var batalha_moves: AnimationPlayer = $"../batalha_moves"
@onready var peido: AudioStreamPlayer = $"../Peido"

@onready var attack_power_1: Sprite2D = $"../Attack_power_1"
@onready var attack_power_2: Sprite2D = $"../Attack_power_2"
@onready var attack_power_3: Sprite2D = $"../Attack_power_3"

@onready var attack_power_time: Sprite2D = $"../Attack_power_time"
@onready var attack_power_x: Sprite2D = $"../Attack_power_X"
@onready var timer_power: Timer = $"../Timer_power"
@onready var timer_power_label: Label = $"../timer_power_label"
@onready var ds_pain: AudioStreamPlayer = $"../DsPain"
@onready var victory_label: Label = $"../victory_label"

@onready var destroy_maycon: GPUParticles2D = $"../Maycon/destroy_maycon"
@onready var you_died_label: Label = $"../you_died_label"
@onready var fade: Node2D = $"../fade"


var power_limit_reached:bool = false
var power_limit:int = 3
var power_count:int = 0

var battle_finished:bool = false
var enemy_hurt:bool = false
var enemy_attacking:bool = false

var died:bool = false

func change_enemy_hurt(boolean:bool)->void:
	enemy_hurt = boolean

func maycon_died()->void:
	destroy_maycon.visible = true
	battle_song.stop()
	you_died_label.visible = true
	maycon.get_node("AnimatedSprite2D").stop()
	#get_node("Cenario de batalha").get_tree().paused
	
	if battle_finished==false:
		ds_pain.play()
		#victory_sound.play()
		battle_finished = true
	
	await get_tree().create_timer(4.0).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func victory()->void:
	destroy.visible = true
	battle_song.stop()
	victory_label.visible = true
	
	if battle_finished==false:
		ds_pain.play()
		victory_sound.play()
		battle_finished = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	maycon_batalha.play("float")
	maycon_batalha_default.play("idle")
	battle_song.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# PLOTAR INIMIGO EM BATALHA
	if Global.battle_next_enemy != 0:
		pass
	elif Global.battle_next_boss != 0:
		pass
		
	if died:
		maycon_died()
	
	if batalha_moves.enemy_attacking == true:
		return
	
	control_attack_power()	
	
	if !batalha_moves.is_playing():
		maycon_batalha_default.play("idle")
		
	if battle_finished==false:
		if Input.is_action_pressed("key_q") && !batalha_moves.is_playing() && maycon.get_node("AnimatedSprite2D").animation == "idle_right":
			if power_limit_reached:
				peido.play()
			else:
				batalha_moves.play("punch")
				power_count = power_count+1
			
		if Input.is_action_pressed("key_w") && !batalha_moves.is_playing() && maycon.get_node("AnimatedSprite2D").animation == "idle_right":
			if power_limit_reached:
				peido.play()
			else:
				batalha_moves.play("kick")
				power_count = power_count+1



func control_attack_power() -> void:
	if timer_power.time_left!=0.0 && timer_power.time_left<2.0:
		timer_power_label.visible = false
		power_limit_reached = false
		power_count = 0
		timer_power.stop()
	elif timer_power.time_left!=0.0:
		timer_power_label.visible = true
		timer_power_label.text = str("%02d" % timer_power.time_left)
	
	#controls the power
	if(power_count == power_limit):
		power_limit_reached = true
		attack_power_time.visible = true
		attack_power_x.visible = true
		if timer_power.time_left == 0.0:
			timer_power.start()
	else:
		power_limit_reached = false
		attack_power_time.visible = false
		attack_power_x.visible = false
		
	if power_count == 0:
		attack_power_1.visible = true
		attack_power_2.visible = true
		attack_power_3.visible = true		
	if power_count == 1:
		attack_power_1.visible = true
		attack_power_2.visible = true
		attack_power_3.visible = false
	if power_count == 2:
		attack_power_1.visible = true
		attack_power_2.visible = false
		attack_power_3.visible = false		
	if power_count == 3:
		attack_power_1.visible = false
		attack_power_2.visible = false
		attack_power_3.visible = false		
