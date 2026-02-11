extends CharacterBody3D

@onready var hud_canvas: CanvasLayer = $hud_canvas
@onready var arma_sprite: AnimatedSprite2D = $hud_canvas/control_gun/gun/arma_sprite
@onready var shoot_fire: AnimatedSprite2D = $hud_canvas/control_gun/gun/shoot
@onready var balas_numero: Label = $hud_canvas/control_gun/balas_numero
@onready var control_gun: Control = $hud_canvas/control_gun
@onready var camera_3d: Camera3D = $Camera3D
@onready var color_rect: ColorRect = $hud_canvas/ColorRect
@onready var camera = $Camera3D
@onready var hud_gun_buttons: Node2D = $hud_canvas/control_gun/hud_gun_buttons
@onready var lamp_light: OmniLight3D = $Camera3D/lamp_light
@onready var lamp: AnimatedSprite2D = $hud_canvas/control_lamp/lamp
@onready var control_lamp: Control = $hud_canvas/control_lamp
@onready var animacao: AnimatedSprite3D = $Camera3D/animacao
@onready var jump: AudioStreamPlayer2D = $jump
@onready var walk: AudioStreamPlayer2D = $walk
@onready var gun_load: AudioStreamPlayer2D = $GunLoad
@onready var gun_shot: AudioStreamPlayer2D = $GunShot
@onready var hurt_sound_3d: AudioStreamPlayer2D = $HurtSound3d
@onready var gun: Control = $hud_canvas/control_gun/gun
@onready var animacao_player_2: AnimatedSprite3D = $Camera3D/animacao_player_2
@onready var hp_position_2_players: Marker2D = $hud_canvas/hp_position_2_players
@onready var maycon_hp: Node2D = $hud_canvas/maycon_hp
@onready var two_player_died: Node2D = $Camera3D/two_player_died
@onready var maycon_3d_model_ia_animations: Node3D = $maycon_3d_model_ia_animations
@onready var cigarro_perfect_animations: Node3D = $cigarro_perfect_animations
@onready var control_moto: Control = $hud_canvas/control_moto
@onready var moto_parada: AudioStreamPlayer = $hud_canvas/control_moto/moto_parada
@onready var moto_acelerando: AudioStreamPlayer = $hud_canvas/control_moto/ModoAcelerando
@onready var farol_moto_cigarro: SpotLight3D = $farol_moto_cigarro
@onready var rain: GPUParticles3D = $chuva
@onready var raining: AudioStreamPlayer = $Raining

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY = 0.003
@export var JOY_SENSITIVITY: float = 0.05 # Sensibilidade para o controle

var animation_tree_playback

const SANGUE_SCENE = preload("res://scenes/3D/blood.tscn")

var shake_intensity = 0.0
var shake_decay = 5.0 # Quão rápido a tremedeira para

var gun_bullets_count=0
var danos_count:int = 0
var danos_count_limit:int = 5

var device_id : int = 0

var gatilho_pressionado = false

var on_moto = false

func set_final_game()->void:
	on_moto = true
	control_lamp.visible = false
	control_gun.visible = false
	control_moto.visible = true
	farol_moto_cigarro.visible = true
	maycon_hp.visible = false
	camera.position.y += 2.1
	moto_parada.play()
	

func set_cigarro_3d_model()->void:
	animation_tree_playback = cigarro_perfect_animations.get_node("AnimationTree").get("parameters/playback")
	maycon_3d_model_ia_animations.visible = false
	cigarro_perfect_animations.visible = true
	

func set_device_id(id: int):
	device_id = id
	print("Maycon configurado para o controle: ", device_id) # Isso vai confirmar no console
	
func add_bullets_to_gun(number:int):
	arma_sprite.play("reload")
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

func change_sprite_two_player()->void:
	animacao_player_2.visible = false
	animacao.visible = false
	set_cigarro_3d_model()

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)j  asf                                                                                                   
	
	#seta o nome para o caso de single player... se for two palyers tem um rename
	#if Global.is_two_player_active==false:
	#	self.name = "Maycon"
	
	#MAYCON EH O PADRAO
	animation_tree_playback = maycon_3d_model_ia_animations.get_node("AnimationTree").get("parameters/playback")

func set_rain(is_raining:bool)->void:
	if is_raining:
		rain.visible = true
		#raining.play()
	else:
		rain.visible = false	
		#if raining.playing:
			#raining.stop()


func aplicar_shake(valor: float):
	shake_intensity = valor
	
	# 2. Efeito de Flash com Tween
	var tween = create_tween()
	# Faz o Alpha ir para 0.5 (metade opaco) em 0.05 segundos (muito rápido)
	tween.tween_property(color_rect, "modulate:a", 0.5, 0.05)
	# Faz o Alpha voltar para 0.0 (invisível) em 0.2 segundos
	tween.tween_property(color_rect, "modulate:a", 0.0, 0.2)
	
	

func levou_dano(dano:int)->void:
	# Acabou de levar um dano - Vibra apenas o controle do jogador atual
	if (danos_count <= danos_count_limit):
		danos_count += dano
		Input.start_joy_vibration(device_id, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()


func _physics_process(delta):
	# --- 1. CONFIGURAÇÕES TÉCNICAS E HUD ---
	if Global.is_two_player_active:
		gun.global_position = $hud_canvas/gun_position_2_players.global_position
	
	# HUD de HP
	$hud_canvas/maycon_hp/hp_1.visible = danos_count <= 4
	$hud_canvas/maycon_hp/hp_2.visible = danos_count <= 3
	$hud_canvas/maycon_hp/hp_3.visible = danos_count <= 2
	$hud_canvas/maycon_hp/hp_4.visible = danos_count <= 1
	$hud_canvas/maycon_hp/hp_5.visible = danos_count <= 0
	
	if danos_count == danos_count_limit:
		danos_count += 1 
		Global.players_dead_count += 1
		if Global.is_two_player_active:
			self.process_mode = Node.PROCESS_MODE_DISABLED
			if Global.players_dead_count == 1:
				two_player_died.visible = true
			animacao.play("died")
			animation_tree_playback.travel("dead")
			self.remove_from_group("players") 
		return

	balas_numero.text = "X " + str(gun_bullets_count)
	
	# Tela tremer
	if shake_intensity > 0:
		camera_3d.h_offset = randf_range(-1, 1) * shake_intensity
		camera_3d.v_offset = randf_range(-1, 1) * shake_intensity
		shake_intensity = lerp(shake_intensity, 0.0, shake_decay * delta)
	else:
		camera_3d.h_offset = 0
		camera_3d.v_offset = 0

	# --- 2. LÓGICA DE TIRO (Apenas se NÃO estiver na moto) ---
	var apertou_tiro = false
	if not on_moto:
		var trigger_right = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT)
		if trigger_right > 0.5: 
			if not gatilho_pressionado:
				apertou_tiro = true
				gatilho_pressionado = true
		else:
			gatilho_pressionado = false
			
		if device_id == 0 and Input.is_action_just_pressed("tiro"):
			apertou_tiro = true
		
		if Global.maycon_pegou_arma_first_3d_battle && apertou_tiro && arma_sprite.animation != "shoot" && gun_bullets_count != 0:
			atirar()
			shoot_fire.play("shoot")
			arma_sprite.play("shoot")
			Input.start_joy_vibration(device_id, 0.4, 0.1, 0.2)
			gun_shot.play()
			remove_bullets_from_gun()
	
	# Controle visual da arma
	if Global.maycon_pegou_arma_first_3d_battle:
		control_gun.visible = true
		hud_gun_buttons.visible = true
	else:
		control_gun.visible = false
		hud_gun_buttons.visible = false

	# --- 3. LÓGICA DE OLHAR (Analógico Direito) ---
	var joy_look = Vector2.ZERO
	if on_moto:
		joy_look = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X), 0)
	else:
		joy_look = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y))

	if joy_look.length() > 0.1:
		rotate_y(-joy_look.x * JOY_SENSITIVITY)
		if camera_3d and not on_moto:
			camera_3d.rotate_x(-joy_look.y * JOY_SENSITIVITY)
			camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# --- 4. FÍSICA GLOBAL ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo (Bloqueado na moto)
	var apertou_pulo = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A) 
	if apertou_pulo and is_on_floor() and not on_moto:
		velocity.y = JUMP_VELOCITY
		jump.play()

	# --- 5. MOVIMENTO (MOTO VS A PÉ) ---
	if on_moto:
		var r2_acelerar = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT)
		var l2_re = Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_LEFT)
		
		var forward_dir = -transform.basis.z 
		
		if r2_acelerar > 0.1:
			# ACELERAÇÃO PARA FRENTE (Até 20)
			var target_vel = forward_dir * 20.0
			velocity.x = move_toward(velocity.x, target_vel.x, 12.0 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, 12.0 * delta)
			if !moto_acelerando.is_playing():moto_acelerando.play()
			Input.start_joy_vibration(device_id, 0.2, 0.1, 0.1)
		elif l2_re > 0.1:
			# RÉ (Mais devagar, até 10)
			var target_vel = -forward_dir * 10.0
			velocity.x = move_toward(velocity.x, target_vel.x, 6.0 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, 6.0 * delta)
			Input.start_joy_vibration(device_id, 0.08, 0.1, 0.1)
		else:
			# DESACELERAÇÃO (Fricção)
			velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 8.0 * delta)
			moto_acelerando.stop()
		
		if velocity.length() > 0.5:
			if !walk.is_playing(): walk.play()
		
		
		
	else:
		# MOVIMENTO A PÉ
		var raw_input = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y))
		var input_dir = Vector2.ZERO
		if raw_input.length() > 0.2: input_dir = raw_input
		
		if device_id == 0 and input_dir.length() < 0.1:
			var k_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
			var k_y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
			input_dir = Vector2(k_x, k_y)

		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			animacao.play("run")
			animation_tree_playback.travel("run")
			
			var forward_dot = transform.basis.z.dot(direction)
			animacao.flip_h = forward_dot >= 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			animation_tree_playback.travel("idle")

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
	animation_tree_playback.travel("idle")


func _on_animacao_player_2_animation_finished() -> void:
	animacao.play("idle")
	animation_tree_playback.travel("idle")
