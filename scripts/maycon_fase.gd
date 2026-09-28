extends CharacterBody2D

@onready var maycon: CharacterBody2D = $"."
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
@onready var run: AudioStreamPlayer2D = $run


var pausePlayer:bool = false
var animation_1_gone = false

var run_ghost_timer: float = 0.0
var run_dust_timer: float = 0.0

const SPEED_DEFAULT = 300.0
const SPEED_RUN = 500.0
var SPEED:float = SPEED_DEFAULT

const JUMP_VELOCITY = -400.0
var DOUBLE_JUMP_COUNT = 0
var is_jumping = false
var attack = false

func pause()->void:
	pausePlayer = true
func unpause()->void:
	pausePlayer = false
	
func jump(is_colliding_area2d:bool)->void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and !is_colliding_area2d:
		sound_jump.play()
		Input.start_joy_vibration(0, 0.2, 0.2, 0.1)
		is_jumping = true
		animated_sprite_2d.play("jump_right")
		velocity.y = JUMP_VELOCITY
		
				
func double_jump(is_colliding_area2d:bool)->void:
	if Input.is_action_just_pressed("ui_accept") and !is_on_floor() and !is_colliding_area2d:
		if DOUBLE_JUMP_COUNT<1:
			sound_double_jump.play()
			Input.start_joy_vibration(0, 0.2, 0.2, 0.2)
			velocity.y = JUMP_VELOCITY+50
			is_jumping = false
			animated_sprite_2d.play("double_jump")
			DOUBLE_JUMP_COUNT = DOUBLE_JUMP_COUNT+1

func _physics_process(delta: float) -> void:
	
	if get_node(".").visible == false:
		return	
		
	if pausePlayer == true:
		animated_sprite_2d.play("idle_right")
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		run_ghost_timer = 0.0
		run_dust_timer = 0.0
	else:
		is_jumping = false
		DOUBLE_JUMP_COUNT = 0
		
	# attack punch
	if Input.is_action_just_pressed("key_q"):
		var can_punch = false
		if animated_sprite_2d.animation != "attack_punch":
			can_punch = true
		elif animated_sprite_2d.sprite_frames:
			var punch_frames = animated_sprite_2d.sprite_frames.get_frame_count("attack_punch")
			if animated_sprite_2d.frame >= int(punch_frames / 2):
				can_punch = true
		if can_punch:
			punch.pitch_scale = randf_range(0.96, 1.10)
			punch.play()
			animated_sprite_2d.stop()
			animated_sprite_2d.frame = 0
			animated_sprite_2d.play("attack_punch")
	elif Input.is_action_pressed("key_q"):
		if animated_sprite_2d.animation != "attack_punch":
			punch.pitch_scale = 1.0
			punch.play()
			animated_sprite_2d.play("attack_punch")
		
	# attack punch
	if Input.is_action_pressed("key_w") : #&& !Input.is_action_pressed("key_down")
		if animated_sprite_2d.animation != "attack_kick":
			kick.play()
			animated_sprite_2d.play("attack_kick")
	
	var is_colliding_area2d:bool = $area2d.get_overlapping_areas().size() > 0
	# handles double jump 
	double_jump(is_colliding_area2d)
	# handles jump.
	jump(is_colliding_area2d)
	
	# ANIMACAO DE ANDAR PROS LADOS	
	if (Input.is_action_pressed("ui_left") || Input.is_action_pressed("ui_right")):	
		if is_on_floor() and !is_jumping and animated_sprite_2d.animation != "attack_punch" and animated_sprite_2d.animation != "attack_kick":
	
			if Input.is_action_pressed("run"):
				if !run.is_playing():
					run.play()
				if SPEED != SPEED_RUN:
					SPEED = SPEED_RUN
				if animated_sprite_2d.animation != "run":
					animated_sprite_2d.play("run")
				
				run_ghost_timer -= delta
				if run_ghost_timer <= 0.0:
					run_ghost_timer = 0.045
					_spawn_run_ghost()
				
				run_dust_timer -= delta
				if run_dust_timer <= 0.0:
					run_dust_timer = 0.075
					_spawn_run_dust()
			else:
				run_ghost_timer = 0.0
				run_dust_timer = 0.0
				if !sound_walk.is_playing():
					sound_walk.play()
				if SPEED != SPEED_DEFAULT:
					SPEED = SPEED_DEFAULT
				if animated_sprite_2d.animation != "right":
					animated_sprite_2d.play("right")

	if (!Input.is_action_pressed("ui_left") && !Input.is_action_pressed("ui_right")) and is_on_floor() and !is_jumping and animated_sprite_2d.animation != "attack_punch" and animated_sprite_2d.animation != "attack_kick" and animated_sprite_2d.animation != "down": 
			run_ghost_timer = 0.0
			run_dust_timer = 0.0
			if animated_sprite_2d.animation != "idle_right":
				animated_sprite_2d.play("idle_right")
	if is_on_floor() and !is_jumping and !animated_sprite_2d.is_playing():
		animated_sprite_2d.play("idle_right")
		

	# 1. Variáveis de controle
	var direction := Input.get_axis("ui_left", "ui_right")
	var esta_golpeando = Input.is_action_pressed("key_q") or Input.is_action_pressed("key_w")

	# 2. Lógica de Movimento (Só move se NÃO estiver golpeando)
	if not esta_golpeando:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		# Se estiver golpeando, força a parada imediata ou gradual
		var desaceleracao = 10000 
		velocity = velocity.move_toward(Vector2.ZERO, desaceleracao * delta)	

	# Se a direção for qualquer valor negativo (ex: -0.1, -0.5, -1.0)
	if direction < 0:
		animated_sprite_2d.flip_h = true
	# Se a direção for qualquer valor positivo (ex: 0.1, 0.5, 1.0)
	elif direction > 0:
		animated_sprite_2d.flip_h = false			
			

	move_and_slide()
	
	# --- NOVA LÓGICA DE IMPACTO ---
	# 1. Primeiro, pegamos qualquer colisão do movimento normal
	var col_alvo = null
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			col_alvo = c
			break

	# 2. Se não achou colisão (porque você está parado), usamos um teste de proximidade
	if col_alvo == null:
		var direcao = -20 if animated_sprite_2d.flip_h else 20
		# Testa uma colisão 20 pixels à frente
		col_alvo = move_and_collide(Vector2(direcao, 0), true, 0.08, true)

	# 3. Se temos uma colisão com RigidBody, verificamos o input FORA do loop
	if col_alvo and col_alvo.get_collider() is RigidBody2D:
		var corpo = col_alvo.get_collider()
		
		# Verificação direta de Input (tente usar just_pressed para testar se registra melhor)
		if Input.is_action_pressed("key_q") or Input.is_action_pressed("key_w"):
			
			# ACORDA o objeto (Obrigatório para RigidBody parado)
			corpo.sleeping = false
			
			# Aplica o coice no Maycon
			velocity = col_alvo.get_normal() * 1200 
			
			# Aplica o impulso no objeto
			var forca_impulso = 180.0
			var multiplicador = 3.0 if Input.is_action_pressed("key_w") else 1.0
			
			corpo.apply_central_impulse(-col_alvo.get_normal() * forca_impulso * multiplicador)
			


func _on_area_2d_body_entered(body: Node2D) -> void:
	
	if animation_1_gone:
		return
		
	pausePlayer = true
	transition.play("semi_fade_out")
	mk_dudun.play()
	
	
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_1")
	msg_box.visible = true
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_2")
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_3")
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_4")
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_5")
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_6")
	await get_tree().create_timer(3.0).timeout
	msg.text = tr("DIALOGUE_SECO_7")
	await get_tree().create_timer(3.0).timeout
		
	inimigo_seco.visible = false
	msg_box.visible = false
	explosao_portal.get_node("hp").play("explotion")
	
	transition.play("zoom_out")
	pausePlayer = false
	animation_1_gone = true



func _on_animated_sprite_2d_animation_finished() -> void:
	if not is_on_floor():
		return
	animated_sprite_2d.play("idle_right")


func _spawn_run_ghost() -> void:
	if !animated_sprite_2d or !animated_sprite_2d.sprite_frames:
		return
	var cur_tex = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, animated_sprite_2d.frame)
	if !cur_tex:
		return
	var target_parent = get_parent()
	if !target_parent:
		return
		
	var ghost = Sprite2D.new()
	ghost.texture = cur_tex
	ghost.centered = animated_sprite_2d.centered
	ghost.offset = animated_sprite_2d.offset
	ghost.flip_h = animated_sprite_2d.flip_h
	ghost.z_index = z_index
	
	target_parent.add_child(ghost)
	target_parent.move_child(ghost, get_index())
	
	ghost.global_position = animated_sprite_2d.global_position
	ghost.global_scale = animated_sprite_2d.global_scale
	ghost.global_rotation = animated_sprite_2d.global_rotation
	
	# Vulto nítido de alta visibilidade com desvanecimento suave
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.82)
	var tw = ghost.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ghost, "modulate", Color(1.0, 0.45, 0.35, 0.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", ghost.scale * 0.96, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(ghost.queue_free)


func _spawn_run_dust() -> void:
	var target_parent = get_parent()
	if !target_parent:
		return
	var facing = -1.0 if animated_sprite_2d.flip_h else 1.0
	var feet_pos = to_global(Vector2(-facing * 12.0 + randf_range(-3.0, 3.0), 50.0))
	var puff = RunDustPuff.new(Vector2(-facing * randf_range(35.0, 75.0), randf_range(-18.0, -6.0)))
	target_parent.add_child(puff)
	target_parent.move_child(puff, get_index())
	puff.global_position = feet_pos
	
	# Efeito complementar de linhas de vento/velocidade atrás do corpo
	if randf() < 0.65:
		var streak_pos = to_global(Vector2(-facing * 8.0, randf_range(12.0, 38.0)))
		var streak = RunSpeedStreak.new(facing, randf_range(28.0, 48.0))
		target_parent.add_child(streak)
		target_parent.move_child(streak, get_index())
		streak.global_position = streak_pos


class RunDustPuff extends Node2D:
	var velocity: Vector2
	var radius: float = 6.0
	var max_radius: float = 18.0
	var alpha: float = 0.85
	
	func _init(vel: Vector2) -> void:
		velocity = vel
		z_index = 0
		
	func _ready() -> void:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(self, "radius", max_radius, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "alpha", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(queue_free)
		
	func _process(delta: float) -> void:
		global_position += velocity * delta
		velocity *= maxf(0.0, 1.0 - delta * 3.5)
		queue_redraw()
		
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.3, 0.75))
		draw_circle(Vector2.ZERO, radius, Color(0.92, 0.90, 0.85, alpha * 0.75))
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 1.0, 1.0, alpha * 0.9))


class RunSpeedStreak extends Node2D:
	var length: float
	var alpha: float = 0.75
	var facing: float
	
	func _init(p_facing: float, p_length: float = 35.0) -> void:
		facing = p_facing
		length = p_length
		z_index = 0
		
	func _ready() -> void:
		var tw = create_tween().set_parallel(true)
		tw.tween_property(self, "length", length * 1.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "alpha", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(queue_free)
		
	func _process(_delta: float) -> void:
		queue_redraw()
		
	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(-facing * length, 0.0), Color(1.0, 1.0, 1.0, alpha), 2.2)


