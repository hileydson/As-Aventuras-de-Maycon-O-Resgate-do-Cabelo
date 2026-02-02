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

const SANGUE_SCENE = preload("res://scenes/3D/blood.tscn")

var shake_intensity = 0.0
var shake_decay = 5.0 # Quão rápido a tremedeira para

var gun_bullets_count=0
var danos_count = 0

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
	
	# HUD de sangue
	$hud_canvas/maycon_hp/hp_1.visible = Global.maycon_danos_first_3d_battle<=4
	$hud_canvas/maycon_hp/hp_2.visible = Global.maycon_danos_first_3d_battle<=3
	$hud_canvas/maycon_hp/hp_3.visible = Global.maycon_danos_first_3d_battle<=2
	$hud_canvas/maycon_hp/hp_4.visible = Global.maycon_danos_first_3d_battle<=1
	$hud_canvas/maycon_hp/hp_5.visible = Global.maycon_danos_first_3d_battle<=0
	
	#acabou de levar um dano
	if Global.maycon_danos_first_3d_battle != danos_count:
		danos_count = Global.maycon_danos_first_3d_battle
		Input.start_joy_vibration(0, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()
		
			
	#se pegou bala nova soma na contagem
	if Global.maycon_pegou_bullet:
		arma_sprite.play("reload")
		Global.maycon_pegou_bullet = false
		add_bullets_to_gun(4)
	
	#CONTA BALAS
	balas_numero.text = "X "+str(gun_bullets_count)
	
	#tela tremer
	if shake_intensity > 0:
		# Escolhe uma direção aleatória baseada na intensidade
		camera_3d.h_offset = randf_range(-1, 1) * shake_intensity
		camera_3d.v_offset = randf_range(-1, 1) * shake_intensity
		
		# Faz a intensidade diminuir com o tempo
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera_3d.h_offset = 0
		camera_3d.v_offset = 0
	
	# faz o tiro
	if Global.maycon_pegou_arma_first_3d_battle && Input.is_action_just_pressed("tiro") && arma_sprite.animation!="shoot" && gun_bullets_count!=0:
		atirar()
		shoot_fire.play("shoot")
		arma_sprite.play("shoot")
		Input.start_joy_vibration(0, 0.4, 0.1, 0.2)
		gun_shot.play()
		remove_bullets_from_gun()
	
	if Global.maycon_pegou_arma_first_3d_battle:
		if control_gun.visible == false:
			arma_sprite.play("reload")
		control_gun.visible = true
	else:
		control_gun.visible = false
	
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
		Input.start_joy_vibration(0, 0.2, 0.2, 0.2)
		

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
