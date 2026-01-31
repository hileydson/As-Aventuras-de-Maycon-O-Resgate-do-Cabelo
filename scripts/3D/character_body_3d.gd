extends CharacterBody3D

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY = 0.003
@export var JOY_SENSITIVITY = 0.05 # Sensibilidade para o controle
@onready var walk: AudioStreamPlayer2D = $"../walk"
@onready var jump: AudioStreamPlayer2D = $"../jump"
@onready var arma_canvas: CanvasLayer = $arma_canvas
@onready var arma_sprite: AnimatedSprite2D = $arma_canvas/Control/arma_sprite
@onready var gun_load: AudioStreamPlayer = $"../GunLoad"
@onready var gun_shot: AudioStreamPlayer = $"../GunShot"

@onready var camera = $Camera3D

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	# O mouse continua funcionando normalmente aqui
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	# faz o tiro
	if Global.maycon_pegou_arma_first_3d_battle && Input.is_action_just_pressed("tiro") && arma_sprite.animation!="shoot":
		arma_sprite.play("shoot")
		gun_shot.play()
	
	if Global.maycon_pegou_arma_first_3d_battle:
		arma_canvas.visible = true
	else:
		arma_canvas.visible = false
	
	# --- LÓGICA DO ANALÓGICO DIREITO ---
	var joy_look = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if joy_look.length() > 0:
		# Rotaciona o corpo (horizontal) e a câmera (vertical)
		rotate_y(-joy_look.x * JOY_SENSITIVITY)
		camera.rotate_x(-joy_look.y * JOY_SENSITIVITY)
		
		# Trava a câmera para não dar um "looping" vertical
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	# -----------------------------------

	# Movimentação normal (WASD / Analógico Esquerdo)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump.play()
		arma_sprite.play("walk")
		

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if !direction.is_zero_approx() && !walk.is_playing():
		walk.play()
		arma_sprite.play("walk")
	
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	


func _on_animated_sprite_2d_animation_finished() -> void:
	arma_sprite.play("idle")
