extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_double_jump: AudioStreamPlayer2D = $double_jump
@onready var sound_walk: AudioStreamPlayer2D = $walk
@onready var sound_jump: AudioStreamPlayer2D = $jump
@onready var kick: AudioStreamPlayer = $Kick
@onready var punch: AudioStreamPlayer = $Punch
@onready var mk_dudun: AudioStreamPlayer = $"../MkDudun"
@onready var transition: AnimationPlayer = $"../Transition"
@onready var msg: Label = $"../msg_box/text"
@onready var msg_box: ColorRect = $"../msg_box"
@onready var explosao_portal: Node2D = $"../explosao_portal"
@onready var inimigo_seco: Node2D = $"../Inimigo_seco"


var pausePlayer:bool = false
var animation_1_gone = false

const SPEED = 150.0
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
	
	if pausePlayer == true:
		animated_sprite_2d.play("idle_right")
		return
	
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


func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if animation_1_gone:
		return
		
	pausePlayer = true
	transition.play("semi_fade_out")
	mk_dudun.play()
	msg_box.visible = true
	
	if(Global.default_language == Global.language_pt_br):
		await get_tree().create_timer(3.0).timeout
		msg.text = "Maycon seu safado!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Esquece o cabelo!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Levarei ele para um lugar..."
		await get_tree().create_timer(3.0).timeout
		msg.text = "Somente lá voce contrará ele!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Venha seu safado!"
		await get_tree().create_timer(3.0).timeout
	else:
		await get_tree().create_timer(3.0).timeout
		msg.text = "Maycon you asshole!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Forget about cabelo!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Im gonna take him to another place!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Only there you can rescue him!"
		await get_tree().create_timer(3.0).timeout
		msg.text = "Come on! you asshole!"
		await get_tree().create_timer(3.0).timeout
		
	inimigo_seco.visible = false
	msg_box.visible = false
	explosao_portal.get_node("hp").play("explotion")
	
	transition.play("zoom_out")
	pausePlayer = false
	animation_1_gone = true
