extends CharacterBody3D

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY = 0.003
@export var JOY_SENSITIVITY = 0.05 

@onready var walk: AudioStreamPlayer2D = $"../walk"
@onready var jump: AudioStreamPlayer2D = $"../jump"
@onready var hud_canvas: CanvasLayer = $hud_canvas
@onready var arma_sprite: AnimatedSprite2D = $hud_canvas/control_gun/arma_sprite
@onready var gun_load: AudioStreamPlayer = $"../GunLoad"
@onready var gun_shot: AudioStreamPlayer = $"../GunShot"
@onready var shoot_fire: AnimatedSprite2D = $hud_canvas/control_gun/shoot
@onready var balas_numero: Label = $hud_canvas/control_gun/balas_numero
@onready var control_gun: Control = $hud_canvas/control_gun
@onready var camera_3d: Camera3D = $Camera3D
@onready var raycast = $Camera3D/RayCast3D
@onready var hurt_sound_3d: AudioStreamPlayer = $"../../HurtSound3d"
@onready var color_rect: ColorRect = $hud_canvas/ColorRect
@onready var hud_gun_buttons: Node2D = $hud_canvas/control_gun/hud_gun_buttons
@onready var lamp_light: OmniLight3D = $Camera3D/lamp_light
@onready var lamp: AnimatedSprite2D = $hud_canvas/control_lamp/lamp
@onready var control_lamp: Control = $hud_canvas/control_lamp

const SANGUE_SCENE = preload("res://scenes/3D/blood.tscn")

var gatilho_pressionado: bool = false
var shake_intensity = 0.0
var shake_decay = 5.0 
var gun_bullets_count = 0
var danos_count = 0
var device_id: int = 0 

func set_device_id(id: int):
	device_id = id
	print("Maycon configurado para o Controle ID: ", device_id)

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Mouse APENAS para o Player 1 (ID 0)
	if device_id == 0 and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_3d.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func add_bullets_to_gun(number:int):
	gun_bullets_count += number

func remove_bullets_from_gun():
	if gun_bullets_count > 0:
		gun_bullets_count -= 1

func atirar():
	if raycast.is_colliding():
		var alvo = raycast.get_collider()
		if alvo.has_method("receber_dano"):
			alvo.receber_dano(3)
			var sangue = SANGUE_SCENE.instantiate()
			get_tree().current_scene.add_child(sangue)
			sangue.global_position = raycast.get_collision_point()

func aplicar_shake(valor: float):
	shake_intensity = valor
	var tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.5, 0.05)
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)

func _physics_process(delta):
	# --- HUD E VIDA ---
	$hud_canvas/maycon_hp/hp_1.visible = Global.maycon_danos_first_3d_battle <= 4
	$hud_canvas/maycon_hp/hp_2.visible = Global.maycon_danos_first_3d_battle <= 3
	$hud_canvas/maycon_hp/hp_3.visible = Global.maycon_danos_first_3d_battle <= 2
	$hud_canvas/maycon_hp/hp_4.visible = Global.maycon_danos_first_3d_battle <= 1
	$hud_canvas/maycon_hp/hp_5.visible = Global.maycon_danos_first_3d_battle <= 0
	
	if Global.maycon_danos_first_3d_battle != danos_count:
		danos_count = Global.maycon_danos_first_3d_battle
		Input.start_joy_vibration(device_id, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()
			
	if Global.maycon_pegou_bullet:
		arma_sprite.play("reload")
		Global.maycon_pegou_bullet = false
		add_bullets_to_gun(4)
	
	balas_numero.text = "X " + str(gun_bullets_count)
	
	# --- SHAKE DA CAMERA ---
	if shake_intensity > 0:
		camera_3d.h_offset = randf_range(-1, 1) * shake_intensity
		camera_3d.v_offset = randf_range(-1, 1) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera_3d.h_offset = 0
		camera_3d.v_offset = 0

	# --- TIRO ---
	var input_tiro = (device_id == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or \
					 Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER) or \
					 Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5

	if input_tiro and not gatilho_pressionado:
		if Global.maycon_pegou_arma_first_3d_battle and gun_bullets_count > 0:
			atirar()
			shoot_fire.play("shoot")
			arma_sprite.play("shoot")
			Input.start_joy_vibration(device_id, 0.4, 0.1, 0.2)
			gun_shot.play()
			remove_bullets_from_gun()
	gatilho_pressionado = input_tiro

	# --- MIRA (ANALÓGICO DIREITO) ---
	var look_x = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X)
	var look_y = Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	
	if Vector2(look_x, look_y).length() > 0.15:
		rotate_y(-look_x * JOY_SENSITIVITY)
		camera_3d.rotate_x(-look_y * JOY_SENSITIVITY)
		camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# --- MOVIMENTO ---
	if not is_on_floor():
		velocity += get_gravity() * delta
# No _physics_process do Maycon:
	var pressionou_pulo = false
	if device_id == 0:
		pressionou_pulo = Input.is_action_just_pressed("ui_accept") or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	else:
		pressionou_pulo = Input.is_joy_button_pressed(1, JOY_BUTTON_A)

	if pressionou_pulo and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump.play()
		arma_sprite.play("walk")


	# Direção
	var move_x = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
	var move_y = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	# DENTRO DO _physics_process DO MAYCON

	# 1. Captura o analógico ESQUERDO baseado no ID do player
	var input_dir = Vector2(move_x, move_y)

	# 2. Teclado SÓ funciona para o Player 1 (ID 0)
	if device_id == 0:
		var teclado = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if teclado.length() > 0:
			input_dir = teclado

	# 3. Deadzone (Para o boneco não andar sozinho se o controle estiver velho)
	if input_dir.length() < 0.2:
		input_dir = Vector2.ZERO



	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	
	if direction.length() > 0.1:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		if is_on_floor():
			if !walk.is_playing(): walk.play()
			arma_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

# --- SINAIS ---
func _on_animated_sprite_2d_animation_finished():
	arma_sprite.play("idle")

func _on_lamp_animation_finished():
	if Global.maycon_pegou_lamp_fire_3d_world:
		lamp.play("idle_with_light")
	else:
		lamp.play("idle")
