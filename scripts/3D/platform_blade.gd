extends Node3D

const SAW_SOUND = preload("res://assets/novos_audios/mario_part_sounds/serra.mp3")

var stage:Node3D
var maycon:CharacterBody3D
var rotor:Node3D
var spin_speed:float = 4.8
var sweep_time:float = 0.0

func setup(owner_stage:Node3D, player:CharacterBody3D, direction:Vector3, index:int) -> void:
	stage = owner_stage
	maycon = player
	rotation.y = atan2(direction.x, direction.z)
	spin_speed = 4.8 if index % 2 == 0 else -5.6
	sweep_time = float(index) * 1.7

func _ready() -> void:
	var saw_audio := AudioStreamPlayer3D.new()
	var saw_stream:AudioStreamMP3 = SAW_SOUND.duplicate()
	saw_stream.loop = true
	saw_audio.stream = saw_stream
	saw_audio.position.y = 1.05
	saw_audio.unit_size = 9.0
	saw_audio.max_distance = 36.0
	saw_audio.volume_db = -3.0
	saw_audio.finished.connect(func():
		if is_instance_valid(saw_audio):
			saw_audio.play(0.0)
	)
	add_child(saw_audio)
	var start_pos:float = fmod(sweep_time, 6.0)
	saw_audio.play(start_pos)
	var iron := _material(Color("667483"), 0.82)
	var edge := _material(Color("dce7ee"), 0.92)
	var dark := _material(Color("28303d"), 0.74)
	var red := _material(Color("bd253c"), 0.36)
	rotor = Node3D.new()
	rotor.name = "NavalhaGiratoria"
	rotor.position.y = 1.05
	add_child(rotor)
	var rim := CylinderMesh.new()
	rim.top_radius = 1.49
	rim.bottom_radius = 1.49
	rim.height = 0.28
	rim.radial_segments = 36
	_part(rotor, rim, dark, Vector3.ZERO).rotation.x = PI * 0.5
	var face := CylinderMesh.new()
	face.top_radius = 1.37
	face.bottom_radius = 1.37
	face.height = 0.34
	face.radial_segments = 36
	_part(rotor, face, iron, Vector3.ZERO).rotation.x = PI * 0.5
	var tooth_mesh := PrismMesh.new()
	tooth_mesh.size = Vector3(0.47, 0.62, 0.30)
	for i in range(18):
		var angle := float(i) * TAU / 18.0
		var tooth := _part(rotor, tooth_mesh, edge, Vector3(sin(angle) * 1.52, cos(angle) * 1.52, 0.0))
		tooth.rotation.z = -angle
	var hub := CylinderMesh.new()
	hub.top_radius = 0.42
	hub.bottom_radius = 0.42
	hub.height = 0.48
	hub.radial_segments = 16
	_part(rotor, hub, red, Vector3.ZERO).rotation.x = PI * 0.5
	var axle := CylinderMesh.new()
	axle.top_radius = 0.16
	axle.bottom_radius = 0.16
	axle.height = 4.0
	axle.radial_segments = 10
	_part(self, axle, dark, Vector3(0.0, 1.05, 0.0)).rotation.x = PI * 0.5
	for side in [-1.0, 1.0]:
		var bracket := BoxMesh.new()
		bracket.size = Vector3(0.55, 1.6, 0.55)
		_part(self, bracket, iron, Vector3(0.0, 0.38, side * 2.05))
	var contact := Area3D.new()
	contact.collision_layer = 0
	contact.collision_mask = 2
	rotor.add_child(contact)
	var shape := CollisionShape3D.new()
	var disc := CylinderShape3D.new()
	disc.radius = 1.78
	disc.height = 0.46
	shape.shape = disc
	shape.rotation.x = PI * 0.5
	contact.add_child(shape)
	contact.body_entered.connect(_on_body_entered)

func _physics_process(delta:float) -> void:
	sweep_time += delta
	rotor.position.x = sin(sweep_time * 1.25) * 0.45
	rotor.rotation.z += spin_speed * delta

func _on_body_entered(body:Node3D) -> void:
	if body == maycon:
		stage.call_deferred("start_player_death", "blade", self)

func _part(parent:Node3D, mesh:Mesh, material:Material, at:Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	parent.add_child(part)
	return part

func _material(color:Color, metal:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = 0.28
	return material
