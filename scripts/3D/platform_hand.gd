extends Node3D

const SLAM_SOUND = preload("res://assets/novos_audios/mario_part_sounds/mao_caindo.mp3")

var stage:Node3D
var maycon:CharacterBody3D
var palm:Node3D
var shadow_material:StandardMaterial3D
var rng := RandomNumberGenerator.new()
var state:int = 0
var timer:float = 0.0
var crushing:bool = false
var crush_time:float = 0.0
var impact_audio:AudioStreamPlayer3D
var crush_was_raised:bool = false
var is_slow_motion:bool = false
var blue_aura:MeshInstance3D

func setup(owner_stage:Node3D, player:CharacterBody3D, index:int) -> void:
	stage = owner_stage
	maycon = player
	rng.seed = 83471 + index * 173
	timer = rng.randf_range(0.9, 2.4)

func _ready() -> void:
	impact_audio = AudioStreamPlayer3D.new()
	impact_audio.stream = SLAM_SOUND
	impact_audio.position.y = 0.5
	impact_audio.unit_size = 14.0
	impact_audio.max_distance = 45.0
	impact_audio.volume_db = 0.0
	add_child(impact_audio)
	var skin := _material(Color("9a7194"), 0.8)
	var shade := _material(Color("6a496d"), 0.88)
	var nail := _material(Color("d34d6e"), 0.35)
	palm = Node3D.new()
	palm.name = "MaoGigante"
	palm.position.y = 4.5
	add_child(palm)
	var aura_mesh := BoxMesh.new()
	aura_mesh.size = Vector3(3.2, 1.8, 3.2)
	blue_aura = MeshInstance3D.new()
	blue_aura.mesh = aura_mesh
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.albedo_color = Color(0.18, 0.65, 1.0, 0.40)
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blue_aura.material_override = aura_mat
	blue_aura.position = Vector3(0.0, 0.0, -0.35)
	blue_aura.visible = false
	palm.add_child(blue_aura)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_part(palm, sphere, skin, Vector3.ZERO, Vector3(1.33, 0.37, 0.87))
	for i in range(4):
		var x := -0.84 + float(i) * 0.56
		_part(palm, sphere, skin, Vector3(x, -0.06, -0.88), Vector3(0.23, 0.25, 0.81 - absf(float(i) - 1.5) * 0.08))
		var nail_mesh := BoxMesh.new()
		nail_mesh.size = Vector3(0.28, 0.08, 0.25)
		_part(palm, nail_mesh, nail, Vector3(x, -0.05, -1.53), Vector3.ONE)
	var thumb := _part(palm, sphere, skin, Vector3(1.27, -0.03, 0.33), Vector3(0.29, 0.26, 0.65))
	thumb.rotation.y = -0.75
	var wrist := CylinderMesh.new()
	wrist.top_radius = 0.43
	wrist.bottom_radius = 0.56
	wrist.height = 1.2
	_part(palm, wrist, shade, Vector3(0.0, 0.86, 0.36), Vector3.ONE)
	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.6
	cuff.bottom_radius = 0.6
	cuff.height = 0.25
	_part(palm, cuff, nail, Vector3(0.0, 1.43, 0.36), Vector3.ONE)
	var contact := Area3D.new()
	contact.collision_layer = 0
	contact.collision_mask = 2
	contact.position = Vector3(0.0, 0.0, -0.35)
	palm.add_child(contact)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.85, 1.5, 2.9)
	shape.shape = box
	contact.add_child(shape)
	contact.body_entered.connect(_on_body_entered)
	shadow_material = StandardMaterial3D.new()
	shadow_material.albedo_color = Color(0.64, 0.04, 0.15, 0.16)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 1.45
	shadow_mesh.bottom_radius = 1.45
	shadow_mesh.height = 0.025
	var shadow := MeshInstance3D.new()
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_material
	shadow.position = Vector3(0.0, 0.13, -0.25)
	add_child(shadow)

func set_slow_motion(active_val:bool) -> void:
	is_slow_motion = active_val
	if is_instance_valid(blue_aura):
		blue_aura.visible = active_val

func _physics_process(delta:float) -> void:
	var delta_eff := delta * (0.10 if is_slow_motion else 1.0)
	if is_slow_motion and is_instance_valid(blue_aura):
		blue_aura.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06)
	if crushing:
		crush_time += delta_eff
		palm.position.y = 0.55 + absf(sin(crush_time * 9.0)) * 0.68
		if palm.position.y > 0.95:
			crush_was_raised = true
		elif crush_was_raised and palm.position.y < 0.7:
			impact_audio.play()
			crush_was_raised = false
		_set_shadow_alpha(0.52)
		return
	timer -= delta_eff
	match state:
		0:
			palm.position.y = 4.5
			_set_shadow_alpha(0.16)
			if timer <= 0.0:
				state = 1
				timer = 0.55
		1:
			var progress := 1.0 - maxf(timer, 0.0) / 0.55
			palm.position.y = lerpf(4.5, 3.1, progress)
			_set_shadow_alpha(0.27 + absf(sin(progress * PI * 4.0)) * 0.2)
			if timer <= 0.0:
				state = 2
				timer = 0.24
		2:
			var progress := 1.0 - maxf(timer, 0.0) / 0.24
			palm.position.y = lerpf(3.1, 0.55, progress * progress)
			_set_shadow_alpha(0.5)
			if timer <= 0.0:
				state = 3
				timer = 0.28
				impact_audio.play()
		3:
			palm.position.y = 0.55
			if timer <= 0.0:
				state = 4
				timer = 0.72
		4:
			var progress := 1.0 - maxf(timer, 0.0) / 0.72
			palm.position.y = lerpf(0.55, 4.5, smoothstep(0.0, 1.0, progress))
			_set_shadow_alpha(lerpf(0.5, 0.16, progress))
			if timer <= 0.0:
				state = 0
				timer = rng.randf_range(1.0, 2.8)

func begin_crush() -> void:
	crushing = true
	crush_time = 0.0
	crush_was_raised = false

func reset_after_death() -> void:
	crushing = false
	impact_audio.stop()
	state = 0
	timer = rng.randf_range(1.5, 3.0)
	palm.position.y = 4.5
	_set_shadow_alpha(0.16)

func _on_body_entered(body:Node3D) -> void:
	if body == maycon:
		if is_slow_motion or stage.get("is_invincible") == true or maycon.get("is_invincible") == true:
			return
		stage.call_deferred("start_player_death", "hand", self)

func _set_shadow_alpha(alpha:float) -> void:
	var color := shadow_material.albedo_color
	color.a = alpha
	shadow_material.albedo_color = color

func _part(parent:Node3D, mesh:Mesh, material:Material, at:Vector3, size:Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.scale = size
	parent.add_child(part)
	return part

func _material(color:Color, roughness:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
