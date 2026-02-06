extends CharacterBody3D

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY = 0.003
@export var JOY_SENSITIVITY = 0.05 # Sensibilidade para o controle
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
@onready var hurt_sound_3d: AudioStreamPlayer = $"../../HurtSound3d"
@onready var color_rect: ColorRect = $hud_canvas/ColorRect
@onready var camera = $Camera3D
@onready var hud_gun_buttons: Node2D = $hud_canvas/control_gun/hud_gun_buttons
@onready var lamp_light: OmniLight3D = $Camera3D/lamp_light
@onready var lamp: AnimatedSprite2D = $hud_canvas/control_lamp/lamp
@onready var control_lamp: Control = $hud_canvas/control_lamp
@onready var animacao: AnimatedSprite3D = $Camera3D/animacao

const SANGUE_SCENE = preload("res://scenes/3D/blood.tscn")

var shake_intensity = 0.0
var shake_decay = 5.0 # Quão rápido a tremedeira para

var gun_bullets_count=0
var danos_count = 0

var device_id : int = 0

func set_device_id(id: int):
	device_id = id
	print("Maycon configurado para o controle: ", device_id) # Isso vai confirmar no console
	
func add_bullets_to_gun(number:int):
	gun_bullets_count = gun_bullets_count+number
	#gun_bullets_count = 50+number #TODO: TESTE

func remove_bullets_from_gun()->void:
	if gun_bullets_count != 0:
		gun_bullets_count = gun_bullets_count-1

@onready var raycast = $Camera3D/RayCast3D

func atirar():
	# Verifica se o raio está encostando em algo
	if raycast.is_colliding():
		var alvo = raycast.get_collider() # Pega o objeto atingido
		
		# Verifica se o alvo tem a função de receber dano
		if alvo.has_method("receber_dano"):
			alvo.receber_dano(3)
			
			# Opcional: Criar uma marca de impacto ou faísca no local exato
			var ponto_impacto = raycast.get_collision_point()
			#criar_impacto_visual(ponto_impacto)
			
			# --- LÓGICA DO SANGUE ---
			var sangue = SANGUE_SCENE.instantiate()
			get_tree().current_scene.add_child(sangue)
			
			# Coloca o sangue no PONTO EXATO onde o tiro bateu
			sangue.global_position = raycast.get_collision_point()
			
			# Opcional: Faz o sangue espirrar na direção oposta ao tiro
			# sangue.look_at(raycast.get_collision_point() + raycast.get_collision_normal())

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion:
		# Aqui é onde a mágica acontece
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
func _unhandled_input(event):
	# O mouse continua funcionando normalmente aqui
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func aplicar_shake(valor: float):
	shake_intensity = valor
	
	# 2. Efeito de Flash com Tween
	var tween = create_tween()
	# Faz o Alpha ir para 0.5 (metade opaco) em 0.05 segundos (muito rápido)
	tween.tween_property(color_rect, "modulate:a", 0.5, 0.05)
	# Faz o Alpha voltar para 0.0 (invisível) em 0.2 segundos
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)
	
	

func _physics_process(delta):
	
	if Global.maycon_pegou_lamp_3d_world:
		control_lamp.visible = true
	else:
		control_lamp.visible = false
	
	# HUD de sangue
	$hud_canvas/maycon_hp/hp_1.visible = Global.maycon_danos_first_3d_battle<=4
	$hud_canvas/maycon_hp/hp_2.visible = Global.maycon_danos_first_3d_battle<=3
	$hud_canvas/maycon_hp/hp_3.visible = Global.maycon_danos_first_3d_battle<=2
	$hud_canvas/maycon_hp/hp_4.visible = Global.maycon_danos_first_3d_battle<=1
	$hud_canvas/maycon_hp/hp_5.visible = Global.maycon_danos_first_3d_battle<=0
	
	# Acabou de levar um dano - Vibra apenas o controle do jogador atual
	if Global.maycon_danos_first_3d_battle != danos_count:
		danos_count = Global.maycon_danos_first_3d_battle
		Input.start_joy_vibration(device_id, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()
		
	# Se pegou bala nova soma na contagem
	if Global.maycon_pegou_bullet:
		arma_sprite.play("reload")
		Global.maycon_pegou_bullet = false
		add_bullets_to_gun(4)
	
	# CONTA BALAS
	balas_numero.text = "X "+str(gun_bullets_count)
	
	# Tela tremer
	if shake_intensity > 0:
		camera_3d.h_offset = randf_range(-1, 1) * shake_intensity
		camera_3d.v_offset = randf_range(-1, 1) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera_3d.h_offset = 0
		camera_3d.v_offset = 0
	
	# Faz o tiro - Detecta o botão de tiro específico deste dispositivo
	var apertou_tiro = Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER) or (device_id == 0 and Input.is_action_just_pressed("tiro"))
	
	if Global.maycon_pegou_arma_first_3d_battle && apertou_tiro && arma_sprite.animation!="shoot" && gun_bullets_count!=0:
		atirar()
		shoot_fire.play("shoot")
		arma_sprite.play("shoot")
		Input.start_joy_vibration(device_id, 0.4, 0.1, 0.2)
		gun_shot.play()
		remove_bullets_from_gun()
	
	if Global.maycon_pegou_arma_first_3d_battle:
		if control_gun.visible == false:
			arma_sprite.play("reload")
		control_gun.visible = true
		hud_gun_buttons.visible = true
	else:
		control_gun.visible = false
		hud_gun_buttons.visible = false
	
	# --- LÓGICA DO ANALÓGICO DIREITO (OLHAR) ---
	var joy_look = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)

	if joy_look.length() > 0.1: 
		# Giro lateral (Gira o corpo)
		rotate_y(-joy_look.x * JOY_SENSITIVITY)
		
		# Giro vertical (Gira a câmera de forma independente do corpo)
		if camera_3d:
			camera_3d.rotate_x(-joy_look.y * JOY_SENSITIVITY)
			camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Movimentação normal (Física)
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- PULO INDEPENDENTE (Ajustado) ---
	# Verifica o botão A do controle atual. A tecla 'ui_accept' só funciona para o Player 1.
	var apertou_pulo = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A) # or (device_id == 0 and Input.is_action_just_pressed("ui_accept"))

	if apertou_pulo and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump.play()
		arma_sprite.play("walk")
		print(device_id)
		Input.start_joy_vibration(device_id, 0.2, 0.2, 0.2)
		
	# --- DIREÇÃO DE MOVIMENTO (Analógico Esquerdo com Deadzone) ---
	var raw_input = Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)
	
	var input_dir = Vector2.ZERO
	if raw_input.length() > 0.2: # Deadzone para evitar drift
		input_dir = raw_input
	
	# Teclado apenas para o Player 1 como reserva
	if device_id == 0 and input_dir.length() < 0.1:
		var k_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		var k_y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		input_dir = Vector2(k_x, k_y)

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if !direction.is_zero_approx():
		animacao.play("run")
		
	if !direction.is_zero_approx() && !walk.is_playing() && is_on_floor() && !(velocity == Vector3.ZERO):
		walk.play()
		arma_sprite.play("walk")
		
		if Global.maycon_pegou_lamp_fire_3d_world:
			lamp.play("walk_with_light")
			lamp_light.visible = true
		else:
			lamp.play("walk")
			lamp_light.visible = false
	
	if direction:
		var forward_dot = transform.basis.z.dot(direction)
		if forward_dot < 0:
			animacao.flip_h = false
		else:
			animacao.flip_h = true
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()


func _on_animated_sprite_2d_animation_finished() -> void:
	arma_sprite.play("idle")


func _on_lamp_animation_finished() -> void:
		if Global.maycon_pegou_lamp_fire_3d_world:
			lamp.play("idle_with_light")
		else:
			lamp.play("idle")


func _on_animacao_animation_finished() -> void:
	animacao.play("idle")
