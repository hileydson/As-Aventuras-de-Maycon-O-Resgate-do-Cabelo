extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var sound_double_jump: AudioStreamPlayer2D = $double_jump
@onready var sound_walk: AudioStreamPlayer2D = $walk
@onready var sound_jump: AudioStreamPlayer2D = $jump
@onready var kick: AudioStreamPlayer = $Kick
@onready var punch: AudioStreamPlayer = $Punch
@onready var mk_dudun: AudioStreamPlayer = $"../MkDudun"
@onready var transition: AnimationPlayer = $"../Transition"
@onready var msg: Label = $"../balao_conversa/text"
@onready var balao_conversa: AnimatedSprite2D = $"../balao_conversa"
@onready var explosao_portal: Node2D = $"../explosao_portal"
@onready var inimigo_seco: Node2D = $"../Inimigo_seco"
@onready var explosao: AudioStreamPlayer = $"../Explosao"
@onready var fire_cracling: AudioStreamPlayer = $"../FireCracling"
@onready var fires_above_seco: Node2D = $"../fires_above_seco"
@onready var logo_inimigo_seco: AnimatedSprite2D = $"../node_logo_seco/logo_inimigo_seco"
@onready var node_logo_seco: Node2D = $"../node_logo_seco"
@onready var mark_balao_seco: Marker2D = $"../mark_balao_seco"

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
	
	
	# Se a direção for qualquer valor negativo (ex: -0.1, -0.5, -1.0)
	if direction < 0:
		animated_sprite_2d.flip_h = true
	# Se a direção for qualquer valor positivo (ex: 0.1, 0.5, 1.0)
	elif direction > 0:
		animated_sprite_2d.flip_h = false	
			
	move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if animation_1_gone:
		return
		
	pausePlayer = true
	transition.play("semi_fade_out")
	mk_dudun.play()
	$"../ScarySmile".stop()
	node_logo_seco.visible = true
	logo_inimigo_seco.play("default")
	
	await get_tree().create_timer(4.0).timeout
	fires_above_seco.visible = false
	
	await get_tree().create_timer(3.0).timeout
	node_logo_seco.visible = false
	inimigo_seco.get_node("AnimatedSprite2D").play("talking")
	inimigo_seco.get_node("AnimatedSprite2D").modulate = Color(1,1,1,1)
	
	#CHAMA BALAOZINHO
	var balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
	if Global.default_language == Global.language_pt_br:
		balao_.falas = ["...", "Maycon seu safado!", "Esquece o cabelo!", "Levarei ele para um outro lugar...", "Somente lá voce encontrará ele!", "Venha seu safado!", "Entre!", "Entre no fogo que queima gostoso!!"]
	else:
		balao_.falas = ["...", "Maycon you asshole!", "Forget about cabelo!", "Im gonna take him to another place!", "A not real one!", "Only there you can rescue him!", "Come on! you asshole!", "Enter!", "Touch the fire!!"]
	
	#PEGAR O SINAL FINAL DE CONVERSA E FADEOUT
	balao_.conversa_terminou.connect(conversa_terminou)
	
	mark_balao_seco.add_child(balao_)
	
	
func conversa_terminou()->void:
	inimigo_seco.visible = false
	balao_conversa.visible = false
	explosao_portal.get_node("hp").play("explotion")
	explosao.play()
	
	transition.play("zoom_out")
	pausePlayer = false
	animation_1_gone = true
