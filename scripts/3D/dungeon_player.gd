class_name DungeonPlayer
extends CharacterBody3D

const STEP_SOUND:AudioStreamMP3 = preload("res://assets/novos_audios/mario_part_sounds/passo.mp3")
const SERVICE_PISTOL_MODEL:PackedScene = preload("res://assets/modelo_3d/calabouco/service_pistol_4k.glb")
const SMG_MODEL:PackedScene = preload("res://assets/modelo_3d/calabouco/SMG.fbx")
const SMG_ALBEDO:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_BaseColor.png")
const SMG_NORMAL:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Normal.png")
const SMG_METALLIC:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Metallic.png")
const SMG_ROUGHNESS:Texture2D = preload("res://assets/modelo_3d/calabouco/SMG_DefaultMaterial_Roughness.png")
const PISTOL_REST_POSITION := Vector3(0.24, -0.27, -0.34)
const PISTOL_REST_ROTATION := Vector3(-0.035, 0.06, -0.025)
const SMG_REST_POSITION := Vector3(0.25, -0.23, -0.35)
const SMG_REST_ROTATION := Vector3(-0.03, 0.05, -0.02)

var weapon_bob_time:float = 0.0
var weapon_recoil_offset:Vector3 = Vector3.ZERO
var weapon_recoil_rot_x:float = 0.0

# Pose de mira (delta a partir do repouso, em graus) para levantar os braços à frente da câmera.
const RIGHT_ARM_AIM_EULER := Vector3(100.0, 0.0, 0.0)
const RIGHT_FOREARM_AIM_EULER := Vector3(-20.0, 0.0, 0.0)
const LEFT_ARM_AIM_EULER := Vector3(0.0, 0.0, 0.0)
const LEFT_FOREARM_AIM_EULER := Vector3(0.0, 0.0, 0.0)
const MAYCON_MODEL:PackedScene = preload("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
const MAYCON_AIR_FLAIL:Resource = preload("res://assets/novas_imagens/3d_enemies/maycon_air_flail.res")

signal interact_pressed
signal fired(origin:Vector3, direction:Vector3)
signal flashlight_toggled(enabled:bool)
signal ammo_changed(current:int, reserve:int, weapon_name:String)
signal reload_started
signal reload_finished
signal hp_changed(current:float, max_val:float)
signal stamina_changed(current:float, max_val:float)
signal player_died

@export var walk_speed:float = 4.2
@export var sprint_speed:float = 6.8
@export var mouse_sensitivity:float = 0.0022
@export var joy_sensitivity:float = 2.4

@onready var head:Node3D = $Head
@onready var camera:Camera3D = $Head/Camera3D
@onready var flashlight:SpotLight3D = $Head/Camera3D/Flashlight
@onready var flashlight_spill:SpotLight3D = $Head/Camera3D/FlashlightSpill
@onready var muzzle_light:OmniLight3D = $Head/Camera3D/MuzzleLight

var has_flashlight:bool = false
var flashlight_on:bool = false
var has_gun:bool = false
var weapon_mode:String = ""
var controls_enabled:bool = true
var fire_cooldown:float = 0.0
var head_bob_time:float = 0.0
var base_head_y:float = 1.58
var base_head_z:float = -0.20
var gun_view:Node3D
var weapon_model:Node3D
var right_hand_mount:Node3D
var muzzle_marker:Marker3D
var casing_eject_marker:Marker3D
var step_audio:AudioStreamPlayer
var step_timer:float = 0.0
var maycon_body:Node3D
var maycon_anim:AnimationPlayer
var maycon_skeleton:Skeleton3D
var head_bone_indices:Array[int] = []
var right_hand_bone:int = -1
var right_arm_bone:int = -1
var right_forearm_bone:int = -1
var left_arm_bone:int = -1
var left_forearm_bone:int = -1

var pistol_clip:int = 4
var pistol_reserve:int = 8
const PISTOL_CLIP_SIZE:int = 4

var machinegun_clip:int = 15
var machinegun_reserve:int = 30
const MACHINEGUN_CLIP_SIZE:int = 15

var is_reloading:bool = false
var reload_audio:AudioStreamPlayer
var dry_fire_audio:AudioStreamPlayer
var knockback_timer:float = 0.0
var flashlight_reflection:ColorRect
var flashlight_reflection_material:ShaderMaterial
var flashlight_reflection_strength:float = 0.0
var flashlight_reflection_time:float = 0.0

var max_hp:float = 100.0
var current_hp:float = 100.0
var max_stamina:float = 100.0
var current_stamina:float = 100.0
var can_sprint:bool = true
var is_sprinting:bool = false
var damage_immune_timer:float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	flashlight.visible = false
	flashlight_spill.visible = false
	muzzle_light.visible = false
	step_audio = AudioStreamPlayer.new()
	step_audio.stream = STEP_SOUND
	step_audio.volume_db = -8.5
	add_child(step_audio)
	
	reload_audio = AudioStreamPlayer.new()
	reload_audio.stream = load("res://assets/novos_audios/gun_load.mp3")
	reload_audio.volume_db = -2.0
	add_child(reload_audio)
	
	dry_fire_audio = AudioStreamPlayer.new()
	dry_fire_audio.stream = load("res://assets/novos_audios/pause_sfxr.wav")
	dry_fire_audio.volume_db = -6.0
	dry_fire_audio.pitch_scale = 1.8
	add_child(dry_fire_audio)
	
	build_flashlight_reflection()
	build_maycon_body()
	build_view_gun()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseMotion && controls_enabled && Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x - event.relative.y * mouse_sensitivity, -1.35, 1.35)
	if event is InputEventKey && event.pressed && event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if !controls_enabled:
		return
	var is_pressed_event:bool = (event is InputEventKey || event is InputEventMouseButton || event is InputEventJoypadButton) && event.pressed
	if !is_pressed_event || event.is_echo():
		return
	if (event is InputEventMouseButton && event.button_index == MOUSE_BUTTON_RIGHT) || (event is InputEventJoypadButton && event.button_index == JOY_BUTTON_Y):
		toggle_flashlight()
	elif (event is InputEventKey && event.physical_keycode == KEY_E) || (event is InputEventJoypadButton && event.button_index == JOY_BUTTON_A):
		interact_pressed.emit()
	elif (event is InputEventKey && event.physical_keycode == KEY_R) || (event is InputEventJoypadButton && (event.button_index == JOY_BUTTON_B || event.button_index == JOY_BUTTON_X)):
		start_reload()

func _physics_process(delta:float) -> void:
	update_flashlight_reflection(delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	damage_immune_timer = maxf(0.0, damage_immune_timer - delta)
	if knockback_timer > 0.0:
		knockback_timer = maxf(0.0, knockback_timer - delta)
		if !is_on_floor():
			velocity.y -= 18.0 * delta
		move_and_slide()
		_update_footsteps(delta, false, false)
		_update_maycon_animations(delta, false, false, Vector2.ZERO)
		return
	if !is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.2
	if !controls_enabled:
		_update_footsteps(delta, false, false)
		_update_maycon_animations(delta, false, false, Vector2.ZERO)
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		move_and_slide()
		if current_stamina < max_stamina:
			current_stamina = minf(max_stamina, current_stamina + 24.0 * delta)
			stamina_changed.emit(current_stamina, max_stamina)
		return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y)).normalized()
	var has_movement_input := input_vector.length_squared() > 0.01

	# --- CONTROLE DE ESTAMINA E SPRINT (Impede corrida infinita) ---
	var sprint_desired: bool = is_sprint_pressed() and has_movement_input
	if sprint_desired and can_sprint and current_stamina > 0.0:
		is_sprinting = true
		current_stamina = maxf(0.0, current_stamina - 36.0 * delta) # ~2.8 segundos de sprint
		if current_stamina <= 0.0:
			can_sprint = false # Cansou completamente!
	else:
		is_sprinting = false
		if current_stamina < max_stamina:
			var regen_rate := 24.0 if !has_movement_input else 18.0
			current_stamina = minf(max_stamina, current_stamina + regen_rate * delta)
			if !can_sprint and current_stamina >= 25.0:
				can_sprint = true # Recuperou fôlego suficiente para voltar a correr
	
	stamina_changed.emit(current_stamina, max_stamina)
	var speed := sprint_speed if is_sprinting else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4 && is_on_floor()
	_update_footsteps(delta, moving, is_sprinting)
	_update_maycon_animations(delta, moving, is_sprinting, input_vector)
	if moving:
		head_bob_time += delta * (11.0 if is_sprinting else 8.0)
		head.position.y = base_head_y + sin(head_bob_time) * 0.035
		head.position.z = base_head_z
	else:
		head.position.y = lerpf(head.position.y, base_head_y, delta * 8.0)
		head.position.z = lerpf(head.position.z, base_head_z, delta * 8.0)

	# Weapon Bobbing (andando vs correndo)
	if is_instance_valid(gun_view) && has_gun:
		var rest_pos := get_weapon_rest_position()
		var rest_rot := get_weapon_rest_rotation()
		if moving:
			var bob_freq: float = 11.5 if is_sprinting else 7.5
			var bob_x_amp: float = 0.016 if is_sprinting else 0.007
			var bob_y_amp: float = 0.014 if is_sprinting else 0.0055
			var bob_rot_z: float = 0.032 if is_sprinting else 0.012
			weapon_bob_time += delta * bob_freq
			var target_pos := rest_pos + Vector3(
				cos(weapon_bob_time * 0.5) * bob_x_amp,
				sin(weapon_bob_time) * bob_y_amp,
				0.0
			) + weapon_recoil_offset
			var target_rot := rest_rot + Vector3(
				sin(weapon_bob_time) * (bob_y_amp * 0.4) + weapon_recoil_rot_x,
				0.0,
				cos(weapon_bob_time * 0.5) * bob_rot_z
			)
			gun_view.position = gun_view.position.lerp(target_pos, delta * 12.0)
			gun_view.rotation = gun_view.rotation.lerp(target_rot, delta * 12.0)
		else:
			var target_pos := rest_pos + weapon_recoil_offset
			var target_rot := rest_rot + Vector3(weapon_recoil_rot_x, 0.0, 0.0)
			gun_view.position = gun_view.position.lerp(target_pos, delta * 8.0)
			gun_view.rotation = gun_view.rotation.lerp(target_rot, delta * 8.0)
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.12:
		rotate_y(-look.x * joy_sensitivity * delta)
		head.rotation.x = clamp(head.rotation.x - look.y * joy_sensitivity * delta, -1.35, 1.35)
	if has_gun && !is_reloading && fire_cooldown <= 0.0 && (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) || Input.is_action_pressed("tiro")):
		fire_cooldown = 0.095 if weapon_mode == "machinegun" else 0.32
		fire()

func is_sprint_pressed() -> bool:
	# Não usa a action global "run" (ela inclui o botão X do controle em outras cenas).
	# Aqui, no calabouço, só corre com Shift ou RB — X fica livre para recarregar.
	return (
		Input.is_key_pressed(KEY_SHIFT)
		or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
		or Input.is_joy_button_pressed(1, JOY_BUTTON_RIGHT_SHOULDER)
	)

func set_flashlight_available(value:bool) -> void:
	has_flashlight = value
	if !value:
		flashlight_on = false
	flashlight.visible = flashlight_on
	flashlight_spill.visible = flashlight_on

func set_gun_available(value:bool) -> void:
	has_gun = value
	if value && weapon_mode == "":
		weapon_mode = "machinegun"
	if is_instance_valid(gun_view):
		gun_view.visible = value
		update_view_gun()

func set_weapon(mode:String) -> void:
	weapon_mode = mode
	has_gun = mode != ""
	if is_instance_valid(gun_view):
		gun_view.visible = has_gun
		update_view_gun()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func toggle_flashlight() -> void:
	if !has_flashlight:
		return
	flashlight_on = !flashlight_on
	flashlight.visible = flashlight_on
	flashlight_spill.visible = flashlight_on
	flashlight_toggled.emit(flashlight_on)

func build_flashlight_reflection() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "FlashlightCameraReflection"
	overlay_layer.layer = -1
	overlay_layer.add_to_group("hide_on_pause")
	add_child(overlay_layer)
	flashlight_reflection = ColorRect.new()
	flashlight_reflection.name = "LensReflection"
	flashlight_reflection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flashlight_reflection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reflection_shader := Shader.new()
	reflection_shader.code = """
shader_type canvas_item;
render_mode unshaded;

uniform float intensity = 0.0;
uniform float flare_time = 0.0;

float soft_orb(vec2 uv, vec2 center, float radius, float softness) {
	float distance_to_center = length((uv - center) * vec2(1.0, 1.72));
	return 1.0 - smoothstep(radius, radius + softness, distance_to_center);
}

void fragment() {
	vec2 uv = UV;
	float breathe = 0.96 + sin(flare_time * 2.1) * 0.025 + sin(flare_time * 6.7) * 0.012;
	vec2 center = vec2(0.535, 0.52 + sin(flare_time * 1.35) * 0.0025);
	float core = soft_orb(uv, center, 0.055, 0.19) * 0.075;
	float inner = soft_orb(uv, center, 0.015, 0.055) * 0.065;
	float ring_distance = length((uv - center) * vec2(1.0, 1.72));
	float ring = (1.0 - smoothstep(0.012, 0.035, abs(ring_distance - 0.225))) * 0.018;
	vec2 axis = center - uv;
	float ghost_a = soft_orb(uv, center + axis * 1.7 + vec2(-0.19, 0.12), 0.012, 0.052) * 0.032;
	float ghost_b = soft_orb(uv, center + axis * 0.8 + vec2(0.22, -0.14), 0.02, 0.065) * 0.024;
	float streak = exp(-abs(uv.y - center.y) * 115.0) * exp(-abs(uv.x - center.x) * 3.8) * 0.012;
	float alpha = (core + inner + ring + ghost_a + ghost_b + streak) * intensity * breathe;
	vec3 warm_light = mix(vec3(1.0, 0.76, 0.42), vec3(0.72, 0.88, 1.0), clamp(ring + ghost_b, 0.0, 1.0));
	COLOR = vec4(warm_light, alpha);
}
"""
	flashlight_reflection_material = ShaderMaterial.new()
	flashlight_reflection_material.shader = reflection_shader
	flashlight_reflection.material = flashlight_reflection_material
	overlay_layer.add_child(flashlight_reflection)

func update_flashlight_reflection(delta:float) -> void:
	if !is_instance_valid(flashlight_reflection_material):
		return
	flashlight_reflection_time += delta
	var target_strength:float = 1.0 if has_flashlight && flashlight_on else 0.0
	flashlight_reflection_strength = move_toward(flashlight_reflection_strength, target_strength, delta * 3.6)
	flashlight_reflection_material.set_shader_parameter("intensity", flashlight_reflection_strength)
	flashlight_reflection_material.set_shader_parameter("flare_time", flashlight_reflection_time)

func apply_knockback(force:Vector3, duration:float = 0.65) -> void:
	velocity = force
	knockback_timer = duration

func _update_footsteps(delta:float, moving:bool, running:bool) -> void:
	if !moving:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer > 0.0:
		return
	step_audio.pitch_scale = randf_range(1.02, 1.12) if running else randf_range(0.94, 1.04)
	step_audio.play()
	step_timer = 0.38 if running else 0.46

func get_current_clip() -> int:
	return pistol_clip if weapon_mode == "pistol" else (machinegun_clip if weapon_mode == "machinegun" else 0)

func get_current_reserve() -> int:
	return pistol_reserve if weapon_mode == "pistol" else (machinegun_reserve if weapon_mode == "machinegun" else 0)

func add_ammo(type:String, amount:int) -> void:
	if type == "pistol":
		pistol_reserve += amount
	elif type == "machinegun":
		machinegun_reserve += amount
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func start_reload() -> void:
	if is_reloading || !has_gun:
		return
	if weapon_mode == "pistol" && (pistol_clip >= PISTOL_CLIP_SIZE || pistol_reserve <= 0):
		return
	if weapon_mode == "machinegun" && (machinegun_clip >= MACHINEGUN_CLIP_SIZE || machinegun_reserve <= 0):
		return
		
	is_reloading = true
	var dur:float = 1.0 if weapon_mode == "pistol" else 1.5
	reload_started.emit()
	if is_instance_valid(reload_audio):
		reload_audio.play()
		
	# Animação de inclinar/abaixar a arma durante recarga
	if is_instance_valid(gun_view):
		var rest_pos:Vector3 = get_weapon_rest_position()
		var target_down:Vector3 = rest_pos + Vector3(0, -0.28, 0.12)
		var t := create_tween()
		t.tween_property(gun_view, "position", target_down, dur * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_interval(dur * 0.15)
		t.tween_property(gun_view, "position", rest_pos, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	await get_tree().create_timer(dur).timeout
	if !is_reloading:
		return
	if weapon_mode == "pistol":
		var needed := PISTOL_CLIP_SIZE - pistol_clip
		var take_amount := mini(needed, pistol_reserve)
		pistol_clip += take_amount
		pistol_reserve -= take_amount
	elif weapon_mode == "machinegun":
		var needed := MACHINEGUN_CLIP_SIZE - machinegun_clip
		var take_amount := mini(needed, machinegun_reserve)
		machinegun_clip += take_amount
		machinegun_reserve -= take_amount
	is_reloading = false
	reload_finished.emit()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)

func eject_casing() -> void:
	var casing := RigidBody3D.new()
	casing.name = "EjectedCasing"
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.011 if weapon_mode == "pistol" else 0.009
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 0.034 if weapon_mode == "pistol" else 0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.68, 0.19)
	mat.metallic = 0.95
	mat.roughness = 0.16
	cyl.material = mat
	mesh_inst.mesh = cyl
	mesh_inst.rotation.z = PI * 0.5
	casing.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	var col_shape := SphereShape3D.new()
	col_shape.radius = 0.02
	col.shape = col_shape
	casing.add_child(col)
	casing.collision_layer = 0
	casing.collision_mask = 1
	casing.mass = 0.02
	get_parent().add_child(casing)
	var spawn_transform := casing_eject_marker.global_transform if is_instance_valid(casing_eject_marker) else camera.global_transform.translated_local(Vector3(0.3, -0.2, -0.45))
	casing.global_transform = spawn_transform
	var eject_dir := camera.global_transform.basis * Vector3(randf_range(3.2, 4.8), randf_range(2.0, 3.4), randf_range(0.2, 1.0))
	casing.linear_velocity = eject_dir
	casing.angular_velocity = Vector3(randf_range(-24, 24), randf_range(-24, 24), randf_range(-24, 24))
	get_tree().create_timer(4.0).timeout.connect(casing.queue_free)

func play_muzzle_flash() -> void:
	if !is_instance_valid(muzzle_marker):
		return
	var flash_root := Node3D.new()
	flash_root.name = "MuzzleFlash"
	get_parent().add_child(flash_root)
	flash_root.global_transform = muzzle_marker.global_transform
	var flash_material := StandardMaterial3D.new()
	flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1.0, 0.58, 0.08, 0.96)
	flash_material.emission_enabled = true
	flash_material.emission = Color(1.0, 0.22, 0.015)
	flash_material.emission_energy_multiplier = 8.0
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.052
	flame_mesh.height = 0.3
	flame_mesh.material = flash_material
	flame.mesh = flame_mesh
	flame.rotation.x = PI * 0.5
	flame.position.z = -0.12
	flash_root.add_child(flame)
	var core_material := StandardMaterial3D.new()
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(1.0, 0.94, 0.55, 1.0)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.62, 0.08)
	core_material.emission_energy_multiplier = 12.0
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.022
	core_mesh.height = 0.2
	core_mesh.material = core_material
	core.mesh = core_mesh
	core.rotation.x = PI * 0.5
	core.position.z = -0.1
	flash_root.add_child(core)
	var sparks := CPUParticles3D.new()
	sparks.amount = 22 if weapon_mode == "machinegun" else 16
	sparks.lifetime = 0.18
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.direction = Vector3(0, 0, -1)
	sparks.spread = 24.0
	sparks.initial_velocity_min = 4.5
	sparks.initial_velocity_max = 10.5
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.35
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.006
	spark_mesh.height = 0.035
	spark_mesh.material = flash_material
	sparks.mesh = spark_mesh
	flash_root.add_child(sparks)
	sparks.emitting = true
	muzzle_light.position = camera.to_local(muzzle_marker.global_position)
	muzzle_light.light_energy = 7.0 if weapon_mode == "machinegun" else 5.8
	muzzle_light.visible = true
	var flash_tween := create_tween().set_parallel()
	flash_tween.tween_property(flash_root, "scale", Vector3(0.2, 0.2, 0.55), 0.055).from(Vector3(1.15, 1.15, 1.4))
	flash_tween.tween_property(flash_material, "albedo_color:a", 0.0, 0.07)
	flash_tween.tween_property(core_material, "albedo_color:a", 0.0, 0.055)
	get_tree().create_timer(0.075).timeout.connect(func():
		muzzle_light.visible = false
		flash_root.queue_free()
	)

func fire() -> void:
	if is_reloading:
		return
	if weapon_mode == "pistol":
		if pistol_clip <= 0:
			if pistol_reserve > 0:
				start_reload()
			elif is_instance_valid(dry_fire_audio):
				dry_fire_audio.play()
			return
		pistol_clip -= 1
	elif weapon_mode == "machinegun":
		if machinegun_clip <= 0:
			if machinegun_reserve > 0:
				start_reload()
			elif is_instance_valid(dry_fire_audio):
				dry_fire_audio.play()
			return
		machinegun_clip -= 1
	else:
		return
		
	eject_casing()
	play_muzzle_flash()
	ammo_changed.emit(get_current_clip(), get_current_reserve(), weapon_mode)
	
	var direction := -camera.global_transform.basis.z
	fired.emit(camera.global_position, direction)
	camera.rotation.z = randf_range(-0.012, 0.012)
	create_tween().tween_property(camera, "rotation:z", 0.0, 0.07)
	if is_instance_valid(gun_view):
		weapon_recoil_offset = Vector3(0, 0.02, 0.06)
		weapon_recoil_rot_x = -0.055
		var recoil := create_tween().set_parallel()
		recoil.tween_property(self, "weapon_recoil_offset", Vector3.ZERO, 0.085).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil.tween_property(self, "weapon_recoil_rot_x", 0.0, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	if get_current_clip() == 0 && get_current_reserve() > 0:
		start_reload()

func build_view_gun() -> void:
	gun_view = Node3D.new()
	gun_view.name = "WeaponView"
	gun_view.visible = false
	var mount := _create_weapon_mount()
	mount.add_child(gun_view)
	muzzle_marker = Marker3D.new()
	muzzle_marker.name = "MuzzleMarker"
	gun_view.add_child(muzzle_marker)
	casing_eject_marker = Marker3D.new()
	casing_eject_marker.name = "CasingEjectMarker"
	gun_view.add_child(casing_eject_marker)
	update_view_gun()

# Encaixe da arma na câmera para visualização FPS clássica
func _create_weapon_mount() -> Node3D:
	return camera

func update_view_gun() -> void:
	if !is_instance_valid(gun_view):
		return
	if is_instance_valid(weapon_model):
		weapon_model.queue_free()
	gun_view.scale = Vector3.ONE
	weapon_model = (SERVICE_PISTOL_MODEL if weapon_mode == "pistol" else SMG_MODEL).instantiate() as Node3D
	weapon_model.name = "ServicePistolModel" if weapon_mode == "pistol" else "SMGModel"
	gun_view.add_child(weapon_model)
	if weapon_mode == "pistol":
		weapon_model.scale = Vector3.ONE * 1.55
		weapon_model.rotation.y = PI * 0.5
		hide_service_pistol_loose_parts(weapon_model)
		muzzle_marker.position = Vector3(0, 0.035, -0.185)
		casing_eject_marker.position = Vector3(0.045, 0.07, -0.035)
	else:
		weapon_model.scale = Vector3.ONE * 0.86
		weapon_model.rotation.y = PI
		apply_smg_material(weapon_model)
		muzzle_marker.position = Vector3(0, 0.035, -0.34)
		casing_eject_marker.position = Vector3(0.07, 0.075, -0.08)
	
	# Desativar sombra projetada das armas em primeira pessoa (evita sombras gigantes à frente)
	for mesh in weapon_model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	gun_view.position = get_weapon_rest_position()
	gun_view.rotation = get_weapon_rest_rotation()

func get_weapon_rest_position() -> Vector3:
	return PISTOL_REST_POSITION if weapon_mode == "pistol" else SMG_REST_POSITION

func get_weapon_rest_rotation() -> Vector3:
	return PISTOL_REST_ROTATION if weapon_mode == "pistol" else SMG_REST_ROTATION

# Levanta os braços do modelo numa pose de mira, por cima da animação, quando armado e corpo visível.
func _apply_aim_pose() -> void:
	if !is_instance_valid(maycon_skeleton) || !has_gun || !is_instance_valid(maycon_body) || !maycon_body.visible:
		return
	_pose_bone(right_arm_bone, RIGHT_ARM_AIM_EULER)
	_pose_bone(right_forearm_bone, RIGHT_FOREARM_AIM_EULER)
	_pose_bone(left_arm_bone, LEFT_ARM_AIM_EULER)
	_pose_bone(left_forearm_bone, LEFT_FOREARM_AIM_EULER)

func _pose_bone(idx:int, euler_deg:Vector3) -> void:
	if idx == -1:
		return
	var rest_q := maycon_skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	# delta aplicado no espaço do OSSO-PAI (torso), para o pitch girar o braço para a frente.
	maycon_skeleton.set_bone_pose_rotation(idx, Quaternion.from_euler(_deg_vec(euler_deg)) * rest_q)

func _deg_vec(euler_deg:Vector3) -> Vector3:
	return Vector3(deg_to_rad(euler_deg.x), deg_to_rad(euler_deg.y), deg_to_rad(euler_deg.z))

func hide_service_pistol_loose_parts(model:Node3D) -> void:
	for node_name in ["service_pistol_bullet", "service_pistol_magazine_loaded"]:
		var loose_part := model.find_child(node_name, true, false) as Node3D
		if is_instance_valid(loose_part):
			loose_part.visible = false

func apply_smg_material(model:Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = SMG_ALBEDO
	material.normal_enabled = true
	material.normal_texture = SMG_NORMAL
	material.metallic = 1.0
	material.metallic_texture = SMG_METALLIC
	material.roughness = 1.0
	material.roughness_texture = SMG_ROUGHNESS
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material

func camera_forward() -> Vector3:
	return -camera.global_transform.basis.z

func shake_camera(intensity:float = 0.06, duration:float = 0.6) -> void:
	var tween := create_tween()
	var steps := int(duration / 0.05)
	for i in steps:
		var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		var rot := randf_range(-intensity * 0.4, intensity * 0.4)
		tween.tween_property(camera, "position", Vector3(0, 0, 0) + offset, 0.05)
		tween.parallel().tween_property(camera, "rotation:z", rot, 0.05)
	tween.tween_property(camera, "position", Vector3.ZERO, 0.1)
	tween.parallel().tween_property(camera, "rotation:z", 0.0, 0.1)

func take_damage(amount:float) -> bool:
	var global_node = get_node_or_null("/root/Global")
	if is_instance_valid(global_node) && "debug_dungeon_invincible" in global_node && global_node.debug_dungeon_invincible:
		return false
	if damage_immune_timer > 0.0 || current_hp <= 0.0:
		return false
	damage_immune_timer = 0.45
	current_hp = maxf(0.0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	shake_camera(0.08, 0.42)
	if current_hp <= 0.0:
		player_died.emit()
		return true
	return false

func heal(amount:float) -> void:
	current_hp = minf(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)

func curar_sangue(percentual:float = 0.20) -> int:
	var heal_amt := max_hp * percentual
	heal(heal_amt)
	return int(heal_amt)

func build_maycon_body() -> void:
	maycon_body = MAYCON_MODEL.instantiate() as Node3D
	maycon_body.name = "MayconBody"
	maycon_body.rotation.y = PI
	maycon_body.position = Vector3(0, 0, 0)
	maycon_body.visible = false
	_adjust_maycon_materials(maycon_body)
	add_child(maycon_body)
	
	maycon_anim = maycon_body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_instance_valid(maycon_anim):
		if !maycon_anim.has_animation_library(""):
			var glb_state := MAYCON_MODEL.get_state()
			for i in range(glb_state.get_node_count()):
				if glb_state.get_node_type(i) == "AnimationPlayer":
					for pidx in range(glb_state.get_node_property_count(i)):
						var pval = glb_state.get_node_property_value(i, pidx)
						if pval is AnimationLibrary:
							maycon_anim.add_animation_library("", pval)
							break
					break
		var lib: AnimationLibrary = maycon_anim.get_animation_library("") if maycon_anim.has_animation_library("") else null
		if lib and MAYCON_AIR_FLAIL and !lib.has_animation("Air_Flail"):
			lib.add_animation("Air_Flail", MAYCON_AIR_FLAIL)
		
		for anim_name in ["Walking", "Skill_03", "Arise", "Air_Flail"]:
			if maycon_anim.has_animation(anim_name):
				var a := maycon_anim.get_animation(anim_name)
				if is_instance_valid(a):
					a.loop_mode = Animation.LOOP_LINEAR
	
	for c in maycon_body.find_children("*", "Skeleton3D", true, false):
		maycon_skeleton = c as Skeleton3D
		break
	if is_instance_valid(maycon_skeleton):
		head_bone_indices.clear()
		for b_name in ["neck", "Head", "head_end", "headfront"]:
			var b_idx := maycon_skeleton.find_bone(b_name)
			if b_idx != -1:
				head_bone_indices.append(b_idx)
				maycon_skeleton.set_bone_pose_scale(b_idx, Vector3.ZERO)
		right_hand_bone = maycon_skeleton.find_bone("RightHand")
		right_arm_bone = maycon_skeleton.find_bone("RightArm")
		right_forearm_bone = maycon_skeleton.find_bone("RightForeArm")
		left_arm_bone = maycon_skeleton.find_bone("LeftArm")
		left_forearm_bone = maycon_skeleton.find_bone("LeftForeArm")

	_play_maycon_animation("Walking")

func _adjust_maycon_materials(root_node: Node) -> void:
	var decap_shader := Shader.new()
	decap_shader.code = """
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float cutoff_y = 1.34;

varying float v_y;

void vertex() {
	v_y = VERTEX.y;
	if (v_y > cutoff_y) {
		VERTEX = vec3(0.0, -100.0, 0.0);
	}
}

void fragment() {
	if (v_y > cutoff_y) {
		discard;
	}
	vec4 col = texture(albedo_texture, UV);
	ALBEDO = col.rgb;
	METALLIC = 0.0;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
"""
	for mesh in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not mi:
			continue
		var tex: Texture2D = null
		if mi.material_override is BaseMaterial3D:
			tex = (mi.material_override as BaseMaterial3D).albedo_texture
		elif mi.mesh && mi.mesh.get_surface_count() > 0:
			var mat = mi.mesh.surface_get_material(0)
			if mat is BaseMaterial3D:
				tex = (mat as BaseMaterial3D).albedo_texture
		if !tex:
			tex = load("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations_texture_0.png")
		
		var s_mat := ShaderMaterial.new()
		s_mat.shader = decap_shader
		s_mat.set_shader_parameter("albedo_texture", tex)
		s_mat.set_shader_parameter("cutoff_y", 1.34)
		mi.material_override = s_mat

func _play_maycon_animation(anim_name:String) -> void:
	if is_instance_valid(maycon_anim) and maycon_anim.has_animation(anim_name) and (maycon_anim.current_animation != anim_name or not maycon_anim.is_playing()):
		var previous := maycon_anim.current_animation
		var blend := 0.24 if previous in ["Skill_03", "Arise"] and anim_name in ["Skill_03", "Arise"] else 0.10 if anim_name == "Air_Flail" or previous == "Air_Flail" else 0.08
		maycon_anim.play(anim_name, blend)

func _update_maycon_animations(_delta:float, moving:bool, running:bool, input_vector:Vector2) -> void:
	if !is_instance_valid(maycon_body) or !maycon_body.visible or !is_instance_valid(maycon_anim):
		return
	if !is_on_floor():
		_play_maycon_animation("Air_Flail")
		maycon_anim.speed_scale = 0.62
	elif moving:
		if running:
			_play_maycon_animation("Arise")
			maycon_anim.speed_scale = 1.15
		else:
			_play_maycon_animation("Skill_03")
			if input_vector.y > 0.1:
				maycon_anim.speed_scale = -1.45
			else:
				maycon_anim.speed_scale = 1.45
	else:
		_play_maycon_animation("Walking")
		maycon_anim.speed_scale = 1.0
	
	if is_instance_valid(maycon_skeleton):
		for b_idx in head_bone_indices:
			maycon_skeleton.set_bone_pose_scale(b_idx, Vector3.ZERO)
		_apply_aim_pose()

func set_body_visible(val:bool) -> void:
	if is_instance_valid(maycon_body):
		maycon_body.visible = val
