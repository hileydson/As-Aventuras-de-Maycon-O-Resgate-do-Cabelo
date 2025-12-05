extends CharacterBody2D

@onready var maycon_batalha: AnimatedSprite2D = $AnimatedSprite2D

@onready var sound_double_jump: AudioStreamPlayer2D = $double_jump
@onready var sound_jump: AudioStreamPlayer2D = $jump
@onready var peido: AudioStreamPlayer = $"../Peido"
@onready var batalha_moves: AnimationPlayer = $"../batalha_moves"

@onready var defense_jump_1: Sprite2D = $"../Defense_Jump_1"
@onready var defense_jump_2: Sprite2D = $"../Defense_Jump_2"
@onready var defense_jump_3: Sprite2D = $"../Defense_Jump_3"
@onready var defense_jump_4: Sprite2D = $"../Defense_Jump_4"
@onready var defense_jump_5: Sprite2D = $"../Defense_Jump_5"
@onready var defense_jump_6: Sprite2D = $"../Defense_Jump_6"

@onready var defense_jump_time: Sprite2D = $"../Defense_jump_time"
@onready var defense_jump_x: Sprite2D = $"../Defense_jump_X"
@onready var timer_defense_label: Label = $"../timer_defense_label"
@onready var timer_defense: Timer = $"../Timer_defense"

@onready var hp_1: Node2D = $"../hp_1"
@onready var hp_2: Node2D = $"../hp_2"
@onready var hp_3: Node2D = $"../hp_3"
@onready var hp_4: Node2D = $"../hp_4"


const SPEED = 190.0
const JUMP_VELOCITY = -550.0

var DOUBLE_JUMP_COUNT = 0
var attack = false

var defense_limit_reached:bool = false
var defense_limit:int = 6
var defense_count:int = 0

var hp_limit:int = 4
var hp_limit_reached:bool = false
var hp_count:int = 0

func jump()->void:
	if Input.is_action_just_pressed("ui_accept") && maycon_batalha.animation != "jump_right" && is_on_floor() && !batalha_moves.is_playing():
		if defense_limit_reached:
			peido.play()
		else:
			sound_jump.play()
			maycon_batalha.play("jump_right")
			velocity.y = JUMP_VELOCITY
			defense_count = defense_count+1
		
				
func double_jump()->void:
	if Input.is_action_just_pressed("ui_accept") and !is_on_floor():
		if DOUBLE_JUMP_COUNT<1:
			sound_double_jump.play()
			velocity.y = JUMP_VELOCITY+50
			maycon_batalha.play("double_jump")
			DOUBLE_JUMP_COUNT = DOUBLE_JUMP_COUNT+1
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		DOUBLE_JUMP_COUNT = 0
		
func _physics_process(delta: float) -> void:
	
	control_defense_jump()
	
	if batalha_moves.battle_finished == false:
		jump()
		double_jump()
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if !maycon_batalha.is_playing():
		maycon_batalha.play("idle_right")
	
	move_and_slide()
	
	
func control_defense_jump() -> void:
	if timer_defense.time_left!=0.0 && timer_defense.time_left<2.0:
		timer_defense_label.visible = false
		defense_limit_reached = false
		defense_count = 0
		timer_defense.stop()
	elif timer_defense.time_left!=0.0:
		timer_defense_label.visible = true
		timer_defense_label.text = str("%02d" % timer_defense.time_left)
	
	#controls the defense
	if(defense_count == defense_limit):
		defense_limit_reached = true
		defense_jump_time.visible = true
		defense_jump_x.visible = true
		if timer_defense.time_left == 0.0:
			timer_defense.start()
	else:
		defense_limit_reached = false
		defense_jump_time.visible = false
		defense_jump_x.visible = false
		
	if defense_count == 0:
		defense_jump_1.visible = true
		defense_jump_2.visible = true
		defense_jump_3.visible = true	
		defense_jump_4.visible = true
		defense_jump_5.visible = true
		defense_jump_6.visible = true	
	if defense_count == 1:
		defense_jump_1.visible = true
		defense_jump_2.visible = true
		defense_jump_3.visible = true	
		defense_jump_4.visible = true
		defense_jump_5.visible = true
		defense_jump_6.visible = false	
	if defense_count == 2:
		defense_jump_1.visible = true
		defense_jump_2.visible = true
		defense_jump_3.visible = true	
		defense_jump_4.visible = true
		defense_jump_5.visible = false
		defense_jump_6.visible = false	
	if defense_count == 3:
		defense_jump_1.visible = true
		defense_jump_2.visible = true
		defense_jump_3.visible = true	
		defense_jump_4.visible = false
		defense_jump_5.visible = false
		defense_jump_6.visible = false		
	if defense_count == 4:
		defense_jump_1.visible = true
		defense_jump_2.visible = true
		defense_jump_3.visible = false	
		defense_jump_4.visible = false
		defense_jump_5.visible = false
		defense_jump_6.visible = false		
	if defense_count == 5:
		defense_jump_1.visible = true
		defense_jump_2.visible = false
		defense_jump_3.visible = false	
		defense_jump_4.visible = false
		defense_jump_5.visible = false
		defense_jump_6.visible = false		
	if defense_count == 6:
		defense_jump_1.visible = false
		defense_jump_2.visible = false
		defense_jump_3.visible = false	
		defense_jump_4.visible = false
		defense_jump_5.visible = false
		defense_jump_6.visible = false		
	


func _on_area_2d_body_entered(body: Node2D) -> void:
	hp_count = hp_count+1
	
	if hp_count == 1:
		hp_4.get_node("hp").play("explotion")
	if hp_count == 2:
		hp_3.get_node("hp").play("explotion")
	if hp_count == 3:
		hp_2.get_node("hp").play("explotion")
	if hp_count == 4:
		hp_1.get_node("hp").play("explotion")
		batalha_moves.died = true
	
