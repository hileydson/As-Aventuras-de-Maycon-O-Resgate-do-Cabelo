extends CharacterBody3D

signal motorcycle_fire
signal motorcycle_chase_died

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
@onready var metralhadora_moto: Sprite2D = $hud_canvas/control_moto/MetralhadoraMoto
@onready var motorcycle_sprite: AnimatedSprite2D = $hud_canvas/control_moto/moto
@onready var motorcycle_shoot_buttons: Node2D = $hud_canvas/control_moto/hud_moto_buttons/ChaseShootButtons
@onready var moto_parada: AudioStreamPlayer = $hud_canvas/control_moto/moto_parada
@onready var moto_acelerando: AudioStreamPlayer = $hud_canvas/control_moto/ModoAcelerando
@onready var farol_moto_cigarro: SpotLight3D = $farol_moto_cigarro
@onready var rain: GPUParticles3D = $chuva
@onready var raining: AudioStreamPlayer = $Raining
@onready var two_player_icon: AnimatedSprite2D = $hud_canvas/two_player_icon
@onready var moto_re: AudioStreamPlayer = $hud_canvas/control_moto/ModoRe
@onready var run: AudioStreamPlayer2D = $run

@export var SPEED : float = 5.0
@export var JUMP_VELOCITY : float = 4.5
@export var MOUSE_SENSITIVITY = 0.003
@export var JOY_SENSITIVITY: float = 0.05 # Sensibilidade para o controle

var animation_tree_playback
var animation_tree

const SANGUE_SCENE = preload("res://scenes/3D/blood.tscn")

var shake_intensity = 0.0
var shake_decay = 5.0 # Quão rápido a tremedeira para
var estou_morto = false

var gun_bullets_count=0
var danos_count:int = 0
var danos_count_limit:int = 5

var device_id : int = 0

var gatilho_pressionado = false

var on_moto = false
var final_game_camera_offset_applied:bool = false
var motorcycle_chase:bool = false
var motorcycle_chase_death_emitted:bool = false
var motorcycle_turn_speed:float = 0.0
var motorcycle_fire_cooldown:float = 0.0
var motorcycle_muzzle:GPUParticles3D
var motorcycle_muzzle_light:OmniLight3D
var motorcycle_effect_root:Node2D
var motorcycle_sparks:CPUParticles2D
var motorcycle_casings:CPUParticles2D
var motorcycle_glow:Sprite2D
var motorcycle_screen_flash:ColorRect
var motorcycle_flash_time:float = 0.0
var motorcycle_gun_rest_position:Vector2
var motorcycle_bike_rest_position:Vector2
var motorcycle_visual_lag:float = 0.0
var motorcycle_gun_recoil:Vector2 = Vector2.ZERO


@export var SPRINT_SPEED = 9.0  # Velocidade ao correr
var estamina_atual = 100.0
var estamina_maxima = 100.0
var pode_correr = true # Trava para esperar voltar ao 100%
var esta_correndo = false

func set_final_game()->void:
	on_moto = true
	maycon_hp.visible = false
	control_lamp.visible = false
	control_gun.visible = false
	control_moto.visible = true
	farol_moto_cigarro.visible = true
	maycon_hp.visible = false
	camera.position.y = 2.514444
	final_game_camera_offset_applied = true
	moto_parada.play()
	set_motorcycle_chase(false)

func set_motorcycle_chase(active:bool) -> void:
	motorcycle_chase = active
	metralhadora_moto.visible = active
	motorcycle_shoot_buttons.visible = active
	if !active:
		motorcycle_turn_speed = 0.0
		motorcycle_flash_time = 0.0
		metralhadora_moto.position = motorcycle_gun_rest_position
		motorcycle_gun_recoil = Vector2.ZERO
		if is_instance_valid(motorcycle_muzzle):
			motorcycle_muzzle.emitting = false
		if is_instance_valid(motorcycle_effect_root):
			motorcycle_effect_root.visible = false
		if is_instance_valid(motorcycle_muzzle_light):
			motorcycle_muzzle_light.visible = false
		if is_instance_valid(motorcycle_screen_flash):
			motorcycle_screen_flash.visible = false
	elif !is_instance_valid(motorcycle_muzzle):
		motorcycle_muzzle = GPUParticles3D.new()
		motorcycle_muzzle.name = "MotorcycleMuzzle"
		motorcycle_muzzle.amount = 10
		motorcycle_muzzle.lifetime = 0.13
		motorcycle_muzzle.one_shot = true
		motorcycle_muzzle.explosiveness = 1.0
		var sparks := ParticleProcessMaterial.new()
		sparks.direction = Vector3(0.0, 0.0, -1.0)
		sparks.spread = 24.0
		sparks.initial_velocity_min = 2.5
		sparks.initial_velocity_max = 5.0
		sparks.gravity = Vector3.ZERO
		var fire_colors := Gradient.new()
		fire_colors.set_color(0, Color(1.0, 0.92, 0.23))
		fire_colors.set_color(1, Color(1.0, 0.12, 0.01, 0.0))
		var fire_ramp := GradientTexture1D.new()
		fire_ramp.gradient = fire_colors
		sparks.color_ramp = fire_ramp
		motorcycle_muzzle.process_material = sparks
		var spark_mesh := SphereMesh.new()
		spark_mesh.radius = 0.025
		spark_mesh.height = 0.05
		var spark_material := StandardMaterial3D.new()
		spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_material.vertex_color_use_as_albedo = true
		spark_mesh.material = spark_material
		motorcycle_muzzle.draw_pass_1 = spark_mesh
		camera_3d.add_child(motorcycle_muzzle)
		motorcycle_muzzle_light = OmniLight3D.new()
		motorcycle_muzzle_light.light_color = Color(1.0, 0.65, 0.16)
		motorcycle_muzzle_light.light_energy = 7.0
		motorcycle_muzzle_light.omni_range = 4.0
		motorcycle_muzzle_light.visible = false
		camera_3d.add_child(motorcycle_muzzle_light)
		build_motorcycle_muzzle_overlay()
	if active and is_instance_valid(motorcycle_effect_root):
		motorcycle_effect_root.visible = true

func build_motorcycle_muzzle_overlay() -> void:
	motorcycle_screen_flash = ColorRect.new()
	motorcycle_screen_flash.name = "MotorcycleScreenFlash"
	motorcycle_screen_flash.color = Color(1.0, 0.65, 0.18, 0.075)
	motorcycle_screen_flash.size = get_viewport().get_visible_rect().size
	motorcycle_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motorcycle_screen_flash.visible = false
	hud_canvas.add_child(motorcycle_screen_flash)
	motorcycle_effect_root = Node2D.new()
	motorcycle_effect_root.name = "MotorcycleShotEffects"
	hud_canvas.add_child(motorcycle_effect_root)
	var glow_gradient := Gradient.new()
	glow_gradient.set_color(0, Color(1.0, 0.89, 0.35, 0.9))
	glow_gradient.set_color(1, Color(1.0, 0.16, 0.01, 0.0))
	var glow_texture := GradientTexture2D.new()
	glow_texture.width = 160
	glow_texture.height = 160
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.gradient = glow_gradient
	motorcycle_glow = Sprite2D.new()
	motorcycle_glow.texture = glow_texture
	motorcycle_glow.visible = false
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motorcycle_glow.material = glow_material
	motorcycle_effect_root.add_child(motorcycle_glow)
	var spark_image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	spark_image.fill(Color.WHITE)
	motorcycle_sparks = CPUParticles2D.new()
	motorcycle_sparks.amount = 10
	motorcycle_sparks.lifetime = 0.17
	motorcycle_sparks.one_shot = true
	motorcycle_sparks.explosiveness = 1.0
	motorcycle_sparks.emitting = false
	motorcycle_sparks.direction = Vector2(0.0, -1.0)
	motorcycle_sparks.spread = 30.0
	motorcycle_sparks.initial_velocity_min = 90.0
	motorcycle_sparks.initial_velocity_max = 180.0
	motorcycle_sparks.gravity = Vector2(0.0, 35.0)
	motorcycle_sparks.texture = ImageTexture.create_from_image(spark_image)
	var spark_colors := Gradient.new()
	spark_colors.set_color(0, Color(1.0, 0.97, 0.38))
	spark_colors.set_color(1, Color(1.0, 0.15, 0.02, 0.0))
	motorcycle_sparks.color_ramp = spark_colors
	motorcycle_effect_root.add_child(motorcycle_sparks)
	var casing_image := Image.create(11, 4, false, Image.FORMAT_RGBA8)
	casing_image.fill(Color(0.88, 0.52, 0.13))
	for x in 11:
		casing_image.set_pixel(x, 0, Color(1.0, 0.83, 0.35))
	motorcycle_casings = CPUParticles2D.new()
	motorcycle_casings.amount = 2
	motorcycle_casings.lifetime = 0.45
	motorcycle_casings.one_shot = true
	motorcycle_casings.explosiveness = 1.0
	motorcycle_casings.emitting = false
	motorcycle_casings.position = Vector2(15.0, 8.0)
	motorcycle_casings.direction = Vector2(1.0, -0.25)
	motorcycle_casings.spread = 20.0
	motorcycle_casings.initial_velocity_min = 85.0
	motorcycle_casings.initial_velocity_max = 140.0
	motorcycle_casings.gravity = Vector2(0.0, 260.0)
	motorcycle_casings.texture = ImageTexture.create_from_image(casing_image)
	motorcycle_effect_root.add_child(motorcycle_casings)

func dismount_final_game()->void:
	set_motorcycle_chase(false)
	on_moto = false
	motorcycle_visual_lag = 0.0
	motorcycle_sprite.position = motorcycle_bike_rest_position
	control_moto.visible = false
	farol_moto_cigarro.visible = false
	moto_parada.stop()
	moto_acelerando.stop()
	moto_re.stop()
	# Volta para a altura original da câmera a pé.
	camera.position.y = 0.414444
	final_game_camera_offset_applied = false

func mount_final_game()->void:
	set_final_game()
	

func set_cigarro_3d_model()->void:
	animation_tree = cigarro_perfect_animations.get_node("AnimationTree")
	animation_tree_playback = animation_tree.get("parameters/playback")
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

func get_aim_assist_target(max_angle_deg: float = 16.0) -> Dictionary:
	if not Global.maycon_pegou_arma_first_3d_battle or on_moto or estou_morto:
		return {}
	if Global.aim_assist_strength <= 0.001 or not camera_3d:
		return {}
	
	var cam_pos = camera_3d.global_position
	var cam_forward = -camera_3d.global_transform.basis.z.normalized()
	var space_state = get_world_3d().direct_space_state
	
	var group_nodes = get_tree().get_nodes_in_group("enemy_hitbox")
	var best_candidate: Dictionary = {}
	var best_score: float = 999999.0
	
	for candidate in group_nodes:
		if not is_instance_valid(candidate) or not candidate.is_inside_tree():
			continue
		if candidate.get("hp") != null and candidate.hp <= 0:
			continue
		
		var target_pos = candidate.global_position
		target_pos.y += 0.3
		
		var to_target = target_pos - cam_pos
		var dist = to_target.length()
		if dist < 0.5 or dist > 55.0:
			continue
		
		var dir = to_target / dist
		var dot = clampf(cam_forward.dot(dir), -1.0, 1.0)
		var angle_deg = rad_to_deg(acos(dot))
		if angle_deg > max_angle_deg:
			continue
		
		# Teste de linha de visão com o cenário
		var ray_query = PhysicsRayQueryParameters3D.create(cam_pos, target_pos)
		ray_query.collision_mask = 1
		ray_query.exclude = [self.get_rid()]
		var hit = space_state.intersect_ray(ray_query)
		if hit and hit.collider != candidate and hit.collider != candidate.get_parent():
			continue
		
		var score = angle_deg * 2.0 + dist * 0.2
		if score < best_score:
			best_score = score
			best_candidate = {
				"target": candidate,
				"position": target_pos,
				"angle": angle_deg,
				"distance": dist
			}
			
	return best_candidate

func _aplicar_assistente_mira(delta: float, joy_look: Vector2) -> void:
	if not Global.maycon_pegou_arma_first_3d_battle or on_moto or estou_morto:
		return
	if Global.aim_assist_strength <= 0.001 or not camera_3d:
		return
	
	var assist_cone = 18.0 * Global.aim_assist_strength
	var target_data = get_aim_assist_target(assist_cone)
	if target_data.is_empty():
		return
	
	var target_pos = target_data["position"]
	var cam_pos = camera_3d.global_position
	var to_target = (target_pos - cam_pos).normalized()
	
	var local_dir = global_transform.basis.inverse() * to_target
	var yaw_diff = atan2(-local_dir.x, -local_dir.z)
	
	var cam_local_dir = camera_3d.global_transform.basis.inverse() * to_target
	var pitch_diff = atan2(cam_local_dir.y, -cam_local_dir.z)
	
	var mouse_vel_len = 0.0
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_vel_len = Input.get_last_mouse_velocity().length()
	
	var is_actively_aiming = (joy_look.length() > 0.13) or (mouse_vel_len > 0.1)
	var pull_mult = 3.2 if is_actively_aiming else 1.0
	var pull_speed = Global.aim_assist_strength * pull_mult * delta
	
	rotate_y(clampf(yaw_diff * pull_speed, -0.04, 0.04))
	camera_3d.rotate_x(clampf(pitch_diff * pull_speed, -0.04, 0.04))
	camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

func atirar():
	var alvo = null
	var ponto_impacto = Vector3.ZERO
	
	# 1. Verifica se o raio direto atingiu algo com receber_dano
	if raycast.is_colliding():
		var col = raycast.get_collider()
		if col and col.has_method("receber_dano"):
			alvo = col
			ponto_impacto = raycast.get_collision_point()
	
	# 2. Se a mira direta falhou mas o assistente está ativo, tenta magnetismo no tiro
	if alvo == null and Global.aim_assist_strength > 0.0:
		var assist_data = get_aim_assist_target(10.0 * Global.aim_assist_strength)
		if not assist_data.is_empty():
			alvo = assist_data["target"]
			ponto_impacto = assist_data["position"]
	
	# 3. Aplica dano e efeito de sangue no alvo atingido
	if alvo and alvo.has_method("receber_dano"):
		alvo.receber_dano(3)
		var sangue = SANGUE_SCENE.instantiate()
		get_tree().current_scene.add_child(sangue)
		sangue.global_position = ponto_impacto


func change_sprite_two_player()->void:
	animacao_player_2.visible = false
	animacao.visible = false
	set_cigarro_3d_model()

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	motorcycle_gun_rest_position = metralhadora_moto.position
	motorcycle_bike_rest_position = motorcycle_sprite.position
	#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)                                                                                               
	
	danos_count = 0
	
	#seta o nome para o caso de single player... se for two palyers tem um rename
	#if Global.is_two_player_active==false:
	#	self.name = "Maycon"
	
	#MAYCON EH O PADRAO
	animation_tree = maycon_3d_model_ia_animations.get_node("AnimationTree")
	animation_tree_playback = animation_tree.get("parameters/playback")
	#animation_tree.set("parameters/conditions/dead", false)
	
	

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
	if motorcycle_chase:
		if danos_count >= danos_count_limit:
			return
		danos_count = mini(danos_count_limit, danos_count + dano)
		Input.start_joy_vibration(device_id, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()
		if danos_count >= danos_count_limit and !motorcycle_chase_death_emitted:
			motorcycle_chase_death_emitted = true
			motorcycle_chase_died.emit()
		return
	# Acabou de levar um dano - Vibra apenas o controle do jogador atual
	if (danos_count <= danos_count_limit):
		danos_count += dano
		Input.start_joy_vibration(device_id, 0.5, 0.7, 0.3)
		aplicar_shake(0.4)
		hurt_sound_3d.play()


func _physics_process(delta):
	motorcycle_fire_cooldown = maxf(0.0, motorcycle_fire_cooldown - delta)
	motorcycle_flash_time = maxf(0.0, motorcycle_flash_time - delta)
	if on_moto:
		var target_lag := clampf(-motorcycle_turn_speed * 10.0, -14.0, 14.0)
		motorcycle_visual_lag = lerpf(motorcycle_visual_lag, target_lag, minf(1.0, delta * 5.0))
		motorcycle_sprite.position = motorcycle_bike_rest_position + Vector2(motorcycle_visual_lag, 0.0)
		motorcycle_gun_recoil = motorcycle_gun_recoil.lerp(Vector2.ZERO, minf(1.0, delta * 15.0))
		metralhadora_moto.position = motorcycle_gun_rest_position + Vector2(motorcycle_visual_lag * 1.15, 0.0) + motorcycle_gun_recoil
	if motorcycle_chase and on_moto:
		var firing := Input.get_joy_axis(device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5 or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if firing:
			metralhadora_moto.position += Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
		var muzzle_screen := metralhadora_moto.to_global(Vector2(0.0, -metralhadora_moto.texture.get_height() * 0.44))
		motorcycle_effect_root.position = muzzle_screen
		var muzzle_world := camera_3d.project_position(muzzle_screen, 1.9)
		motorcycle_muzzle.position = camera_3d.to_local(muzzle_world)
		motorcycle_muzzle_light.position = motorcycle_muzzle.position
		motorcycle_glow.visible = motorcycle_flash_time > 0.0
		motorcycle_muzzle_light.visible = motorcycle_flash_time > 0.0
		motorcycle_screen_flash.visible = motorcycle_flash_time > 0.0
		if motorcycle_flash_time > 0.0:
			motorcycle_glow.modulate.a = motorcycle_flash_time / 0.11
			motorcycle_glow.scale = Vector2.ONE * (0.75 + randf_range(0.0, 0.18))
			motorcycle_screen_flash.modulate.a = motorcycle_flash_time / 0.11
			motorcycle_screen_flash.size = get_viewport().get_visible_rect().size
		if firing:
			if motorcycle_fire_cooldown <= 0.0:
				motorcycle_fire_cooldown = 0.15
				motorcycle_flash_time = 0.11
				motorcycle_gun_recoil = Vector2(randf_range(-2.5, 2.5), randf_range(4.0, 7.0))
				metralhadora_moto.position += motorcycle_gun_recoil
				motorcycle_effect_root.position = metralhadora_moto.to_global(Vector2(0.0, -metralhadora_moto.texture.get_height() * 0.44))
				muzzle_world = camera_3d.project_position(motorcycle_effect_root.position, 1.9)
				motorcycle_muzzle.position = camera_3d.to_local(muzzle_world)
				motorcycle_muzzle_light.position = motorcycle_muzzle.position
				motorcycle_glow.visible = true
				motorcycle_glow.modulate.a = 1.0
				motorcycle_muzzle_light.visible = true
				motorcycle_screen_flash.visible = true
				motorcycle_screen_flash.modulate.a = 1.0
				gun_shot.play()
				motorcycle_muzzle.restart()
				motorcycle_muzzle.emitting = true
				motorcycle_sparks.restart()
				motorcycle_sparks.emitting = true
				motorcycle_casings.restart()
				motorcycle_casings.emitting = true
				motorcycle_fire.emit()
	# --- 1. CONFIGURAÇÕES TÉCNICAS E HUD ---
	if Global.is_two_player_active:
		gun.global_position = $hud_canvas/gun_position_2_players.global_position
		if name == "Cigarro":
			two_player_icon.play("cigarro")
		two_player_icon.visible = true
		
	if Global.maycon_pegou_lamp_3d_world and !on_moto:
		control_lamp.visible = true
	else:
		control_lamp.visible = false
		
	# HUD de HP
	$hud_canvas/maycon_hp/hp_1.visible = danos_count <= 4
	$hud_canvas/maycon_hp/hp_2.visible = danos_count <= 3
	$hud_canvas/maycon_hp/hp_3.visible = danos_count <= 2
	$hud_canvas/maycon_hp/hp_4.visible = danos_count <= 1
	$hud_canvas/maycon_hp/hp_5.visible = danos_count <= 0
	
	if motorcycle_chase and danos_count >= danos_count_limit:
		return
	if danos_count == danos_count_limit:
		danos_count += 1 
		Global.players_dead_count += 1
		if Global.is_two_player_active:
			animacao.play("died")
			animation_tree_playback.travel("dead")
			estou_morto = true
			self.remove_from_group("players") 
			if Global.players_dead_count == 1:
				two_player_died.visible = true
			await get_tree().create_timer(3.0).timeout 	
			self.process_mode = Node.PROCESS_MODE_DISABLED
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
	if Global.maycon_pegou_arma_first_3d_battle and !on_moto:
		control_gun.visible = true
		hud_gun_buttons.visible = true
	else:
		control_gun.visible = false
		hud_gun_buttons.visible = false

	
# --- 3. LÓGICA DE OLHAR (Moto: analógico esquerdo; a pé: direito) ---
	var joy_look = Vector2.ZERO
	if on_moto:
		joy_look = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X), 0)
	else:
		joy_look = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y))

	# Ignora pequenos movimentos involuntários do analógico da moto.
	if on_moto:
		if absf(joy_look.x) < 0.13:
			joy_look.x = 0.0
		var mouse_turn := 0.0
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			mouse_turn = clampf(Input.get_last_mouse_velocity().x * MOUSE_SENSITIVITY * 0.28, -1.4, 1.4)
		var target_turn := clampf(-joy_look.x * 1.4 - mouse_turn, -1.4, 1.4)
		motorcycle_turn_speed = move_toward(motorcycle_turn_speed, target_turn, 3.2 * delta)
		rotate_y(motorcycle_turn_speed * delta)
	elif joy_look.length() > 0.13:
		rotate_y(-joy_look.x * JOY_SENSITIVITY)
		if camera_3d and not on_moto:
			camera_3d.rotate_x(-joy_look.y * JOY_SENSITIVITY)
			camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))


	# --- LÓGICA DE OLHAR (MOUSE) ---
	# Só processa o mouse se ele estiver capturado (preso na tela)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Pega a velocidade do mouse no frame atual
		var mouse_velocity = Input.get_last_mouse_velocity()
		
		# Verificamos se há movimento para evitar cálculos desnecessários
		if mouse_velocity.length() > 0.1:
			# Rotação Horizontal (Maycon vira para os lados)
			# Multiplicamos por delta para a velocidade ser consistente
			var rotation_y = -mouse_velocity.x * MOUSE_SENSITIVITY * delta
			if not on_moto:
				rotate_y(rotation_y)
			
			# Rotação Vertical (Câmera olha para cima e para baixo)
			if camera_3d and not on_moto:
				var rotation_x = -mouse_velocity.y * MOUSE_SENSITIVITY * delta
				camera_3d.rotate_x(rotation_x)
				
				# Trava a visão para não girar 360 graus verticalmente
				camera_3d.rotation.x = clamp(camera_3d.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	# Assistente de mira (atração suave da retícula)
	_aplicar_assistente_mira(delta, joy_look)

	# --- 4. FÍSICA GLOBAL ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Pulo (Bloqueado na moto)
	var apertou_pulo = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A) or Input.is_key_pressed(KEY_SPACE)
	if apertou_pulo and is_on_floor() and not on_moto:
		velocity.y = JUMP_VELOCITY
		jump.play()

	# --- 5. MOVIMENTO (MOTO VS A PÉ) ---
	if on_moto:
		var acelerar_moto = Input.is_joy_button_pressed(device_id, JOY_BUTTON_A) or Input.is_key_pressed(KEY_SPACE)
		var re_moto = Input.is_joy_button_pressed(device_id, JOY_BUTTON_B) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		
		var forward_dir = -transform.basis.z 
		
		if acelerar_moto:
			# ACELERAÇÃO PARA FRENTE (Até 20)
			var target_vel = forward_dir * 20.0
			velocity.x = move_toward(velocity.x, target_vel.x, 13.0 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, 13.0 * delta)
			if !moto_acelerando.is_playing():moto_acelerando.play()
			Input.start_joy_vibration(device_id, 0.2, 0.1, 0.1)
		elif re_moto:
			# RÉ (Mais devagar, até 10)
			var target_vel = -forward_dir * 10.0
			velocity.x = move_toward(velocity.x, target_vel.x, 6.0 * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, 6.0 * delta)
			if !moto_re.is_playing():moto_re.play()
			Input.start_joy_vibration(device_id, 0.08, 0.1, 0.1)
		else:
			# DESACELERAÇÃO (Fricção)
			velocity.x = move_toward(velocity.x, 0, 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 8.0 * delta)
			moto_acelerando.stop()
			moto_re.stop()
		
		
		
	else:
		# --- LÓGICA DE ESTAMINA E SPRINT ---
		var apertou_sprint = Input.is_joy_button_pressed(device_id, JOY_BUTTON_RIGHT_SHOULDER) or Input.is_key_pressed(KEY_SHIFT)
		
		# Tenta correr: Precisa apertar o botão, ter estamina, ter permissão e estar se movendo
		if apertou_sprint and estamina_atual > 0 and pode_correr and velocity.length() > 0.1:
			esta_correndo = true
			estamina_atual -= 40.0 * delta # Gasta 40 por segundo (dura 2.5 seg)
			if estamina_atual <= 0:
				estamina_atual = 0
				pode_correr = false # Acabou? Trava até recuperar tudo
			if !run.is_playing(): run.play()
		else:
			esta_correndo = false
			# Regeneração: Se não está correndo, recupera estamina
			estamina_atual += 20.0 * delta # Recupera 20 por segundo (leva 5 seg)
			if estamina_atual >= estamina_maxima:
				estamina_atual = estamina_maxima
				pode_correr = true # Recuperou 100%? Pode correr de novo
		
		if velocity.length() > 0.5 and is_on_floor():
			if !run.is_playing() and !walk.is_playing(): walk.play()
			# Logica da lampada
			if Global.maycon_pegou_lamp_fire_3d_world and !on_moto:
				lamp.play("walk_with_light")
				lamp_light.visible = true
			else:
				lamp.play("walk")
				lamp_light.visible = false	
			
			# Logica da arma
			if Global.maycon_pegou_arma_first_3d_battle and !on_moto:
				arma_sprite.play("walk")
				control_gun.visible = true
		
		# Exemplo: Se não pode correr, deixa a HUD de balas ou o ícone do player meio vermelho/transparente
		if not pode_correr:
			$hud_canvas/maycon_hp.modulate = Color(1, 0.5, 0.5, 0.8) # Tom avermelhado
		else:
			$hud_canvas/maycon_hp.modulate = Color(1, 1, 1, 1) # Normal	
		# Define a velocidade atual baseada no estado
		var velocidade_final = SPRINT_SPEED if esta_correndo else SPEED

		# --- SEU CÓDIGO DE MOVIMENTO A PÉ AJUSTADO ---
		var raw_input = Vector2(Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y))
		var input_dir = Vector2.ZERO
		if raw_input.length() > 0.2: input_dir = raw_input
		
		# (Mantenha seu código de teclado ui_right, etc aqui...)

		
		# Se não estiver usando analógico (ou for o Player 1), verifica o Teclado (WASD + Setas)
		if device_id == 0 and input_dir.length() < 0.1:
			# get_vector mapeia automaticamente 4 direções para um Vector2
			# Certifique-se de que essas ações (W,A,S,D) estão no seu Input Map
			input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		if direction:
			# USA A VELOCIDADE FINAL AQUI
			velocity.x = direction.x * velocidade_final
			velocity.z = direction.z * velocidade_final
			
			# Ajuste de animação: se estiver correndo rápido, pode mudar o scale da animação
			animacao.play("run")
			if esta_correndo:
				animacao.speed_scale = 1.5 # Deixa a animação de correr mais rápida visualmente
			else:
				animacao.speed_scale = 1.0
				
			if !estou_morto: animation_tree_playback.travel("run")
			# ... resto do seu código de flip_h e arma ...
		else:
			velocity.x = move_toward(velocity.x, 0, velocidade_final)
			velocity.z = move_toward(velocity.z, 0, velocidade_final)
			if !estou_morto: animation_tree_playback.travel("idle")
			animacao.speed_scale = 1.0

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
	if !estou_morto: animation_tree_playback.travel("idle")


func _on_animacao_player_2_animation_finished() -> void:
	animacao.play("idle")
	if !estou_morto: animation_tree_playback.travel("idle")


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	
	#INUTILIZADO ATEH EU APRENDER A USAR ESSE ANIMATION TREE
	
	#print("NOME:" + name + "  --  "+anim_name)
	if (name=="Maycon" and anim_name == "Walking") or (name=="Cigarro" and anim_name == "Casual_Walk"): # EH COMO FOI IMPORTADO... OS NOMES NAO BATEM COM AS ANIMACOES--- e os nomes estao trocados tb
		print("PLAYED DEAD")
		
		#animation_tree.set("parameters/conditions/dead", true)
		# animation_tree_playback.travel("dead")
		
		#if Global.players_dead_count == 1:
		#	two_player_died.visible = true
		#self.process_mode = Node.PROCESS_MODE_DISABLED
