extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_double_jump: AudioStreamPlayer2D = $double_jump
@onready var sound_walk: AudioStreamPlayer2D = $walk
@onready var sound_jump: AudioStreamPlayer2D = $jump
@onready var kick: AudioStreamPlayer = $Kick
@onready var punch: AudioStreamPlayer = $Punch


const SPEED = 190.0
const JUMP_VELOCITY = -400.0

var DOUBLE_JUMP_COUNT = 0
var attack = false

func jump()->void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		sound_jump.play()
		animated_sprite_2d.play("jump_right")
		velocity.y = JUMP_VELOCITY
		
				
func double_jump()->void:
	if Input.is_action_just_pressed("ui_accept") and !is_on_floor():
		if DOUBLE_JUMP_COUNT<1:
			sound_double_jump.play()
			velocity.y = JUMP_VELOCITY+50
			animated_sprite_2d.play("double_jump")
			DOUBLE_JUMP_COUNT = DOUBLE_JUMP_COUNT+1
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		DOUBLE_JUMP_COUNT = 0
		
func _physics_process(delta: float) -> void:
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	# attack
	if Input.is_action_pressed("key_w"):
		if animated_sprite_2d.animation != "attack_punch":
			punch.play()
			animated_sprite_2d.play("attack_punch")
		
	if Input.is_action_pressed("key_q"):
		if animated_sprite_2d.animation != "attack_kick":
			kick.play()
			animated_sprite_2d.play("attack_kick")

	# handles double jump 
	double_jump()
	
	# handles jump.
	jump()
	
			
	# ANIMACAO DE ANDAR PROS LADOS	
	if (Input.is_action_pressed("ui_left") || Input.is_action_pressed("ui_right")) && !Input.is_action_just_pressed("ui_accept"):	
		if is_on_floor() && animated_sprite_2d.animation != "attack_punch" && animated_sprite_2d.animation != "attack_kick" :
			if !sound_walk.is_playing():
				sound_walk.play()
			animated_sprite_2d.play("right")

	#ANIMACAO IDLE
	#if !Input.is_action_pressed("ui_left") && !Input.is_action_pressed("ui_right") && !Input.is_action_just_pressed("ui_accept")  && !Input.is_action_just_pressed("key_q") && !Input.is_action_just_pressed("key_w") && is_on_floor():		
	if !animated_sprite_2d.is_playing():
		animated_sprite_2d.play("idle_right")
		
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if direction == -1:
		animated_sprite_2d.flip_h = true
	if direction == 1:
		animated_sprite_2d.flip_h = false			
			
	move_and_slide()
