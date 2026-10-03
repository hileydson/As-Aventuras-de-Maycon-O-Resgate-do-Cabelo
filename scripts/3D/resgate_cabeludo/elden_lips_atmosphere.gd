extends Node3D

const AMBIENCE = preload("res://assets/novos_audios/calabouco_terror/dungeon_ambience_pixabay.mp3")
const BOOM = preload("res://assets/novos_audios/seco_invader_boom_pixabay.mp3")
const WHOOSH = preload("res://assets/novos_audios/seco_kick_dimensional_whoosh_pixabay.mp3")
const GATE = preload("res://assets/novos_audios/calabouco_terror/gate_opening_heavy.mp3")
const GROWL = preload("res://assets/novos_audios/calabouco_terror/zombie_growl_pixabay.mp3")
const WOOD = preload("res://assets/novos_audios/mario_part_sounds/wood_barrier_break.mp3")
const IMPACT = preload("res://assets/novos_audios/calabouco_terror/giant_head_slam.ogg")
const BASE_SCORE = preload("res://assets/novos_audios/elden_lips/ritual.ogg")
const RAGE_SCORE = preload("res://assets/novos_audios/elden_lips/frenzy.ogg")
var stage:Node3D
var environment:Environment
var original_environment:Environment
var original_sun_energy:float
var original_sun_color:Color
var base:AudioStreamPlayer
var rage:AudioStreamPlayer
var drone:AudioStreamPlayer
var lights:Array[OmniLight3D] = []
var decor:Node3D
var active:bool = false
var time:float = 0.0
var sound_pool:Array[AudioStreamPlayer3D] = []
var arena_materials:Dictionary = {}
var hero_light:OmniLight3D

func setup(owner_stage:Node3D) -> void:
	stage = owner_stage
	original_environment = stage.get_node("Morning").environment
	original_sun_energy = stage.get_node("MorningSun").light_energy
	original_sun_color = stage.get_node("MorningSun").light_color
	base = music(BASE_SCORE,-80)
	rage = music(RAGE_SCORE,-80)
	drone = music(AMBIENCE,-80)
	drone.finished.connect(func():
		if active: drone.play())
	for i in 12:
		var sound := AudioStreamPlayer3D.new()
		sound.max_distance = 45
		sound.unit_size = 14
		sound.max_db = 1.0
		add_child(sound)
		sound_pool.append(sound)

func music(stream:AudioStream,volume:float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream.duplicate() as AudioStream
	if player.stream is AudioStreamOggVorbis:
		player.stream.loop = true
	player.volume_db = volume
	add_child(player)
	return player

func enter() -> void:
	active = true
	if decor == null:
		build_ritual()
	decor.visible = true
	for light in lights: light.light_color = Color("80bcad")
	for mesh in arena_materials:
		mesh.material_override = arena_materials[mesh].dark
	environment = original_environment.duplicate() as Environment
	stage.get_node("Morning").environment = environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080b13")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("667b91")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("1c2634")
	environment.fog_density = 0.025
	environment.fog_sky_affect = 1.0
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 0.35
	var transition := create_tween().set_parallel(true)
	transition.tween_property(stage.get_node("MorningSun"),"light_energy",0.38,2.4)
	transition.tween_property(stage.get_node("MorningSun"),"light_color",Color("8596bd"),2.4)
	for slot in stage.song_slots:
		transition.tween_property(slot,"volume_db",-80.0,1.5)
	var birds := stage.get_node_or_null("Ambiente")
	if birds: transition.tween_property(birds,"volume_db",-80.0,1.4)
	drone.play()
	transition.tween_property(drone,"volume_db",-19.0,2.0)
	if is_instance_valid(stage.wind): stage.wind.visible = false

func start_score() -> void:
	base.play()
	rage.play()
	create_tween().tween_property(base,"volume_db",-12.0,2.0)

func second_phase() -> void:
	create_tween().tween_property(rage,"volume_db",-12.0,2.5)
	create_tween().tween_property(environment,"fog_light_color",Color("35202d"),2.0)
	for light in lights:
		create_tween().tween_property(light,"light_color",Color("cf5461"),2.0)
	play_sound("roar",stage.boss.global_position)

func stop_score(duration:float = 1.5) -> void:
	var fade := create_tween().set_parallel(true)
	for player in [base,rage,drone]: fade.tween_property(player,"volume_db",-80.0,duration)

func leave() -> void:
	active = false
	stop_score(2.5)
	stage.get_node("Morning").environment = original_environment
	var recover := create_tween().set_parallel(true)
	recover.tween_property(stage.get_node("MorningSun"),"light_energy",original_sun_energy,2.0)
	recover.tween_property(stage.get_node("MorningSun"),"light_color",original_sun_color,2.0)
	if decor: decor.visible = false
	for mesh in arena_materials:
		mesh.material_override = arena_materials[mesh].original

func play_sound(kind:String,at:Vector3,volume:float = -9.0,pitch:float = 1.0) -> void:
	var streams := {"slam":IMPACT,"boom":BOOM,"swing":WHOOSH,"gate":GATE,"roar":GROWL,"block":WOOD,"equip":WOOD}
	if not streams.has(kind): return
	for sound in sound_pool:
		if sound.playing: continue
		sound.stream = streams[kind]
		sound.global_position = at
		sound.volume_db = volume
		sound.pitch_scale = pitch
		sound.play()
		return

func material(color:Color,emission:float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func build_ritual() -> void:
	decor = Node3D.new()
	decor.name = "RitualEldenLips"
	add_child(decor)
	var floor_mesh := stage.get_node("Arena/Floor/Mesh") as MeshInstance3D
	var floor_mat := material(Color("636170"))
	floor_mat.albedo_texture = preload("res://assets/polyhaven/realtime_battle/cobblestone_floor_diff_1k.jpg")
	floor_mat.normal_enabled = true
	floor_mat.normal_texture = preload("res://assets/polyhaven/realtime_battle/cobblestone_floor_normal_1k.jpg")
	floor_mat.uv1_scale = Vector3(10,8,1)
	arena_materials[floor_mesh] = {"original":floor_mesh.material_override,"dark":floor_mat}
	# Cada material é exclusivo desta arena e volta ao original na vitória.
	for mesh in stage.get_node("Arena").find_children("*","MeshInstance3D",true,false):
		if mesh==floor_mesh or stage.boss.is_ancestor_of(mesh) or stage.cage.is_ancestor_of(mesh): continue
		var ash_mat := material(Color("373a43"))
		arena_materials[mesh] = {"original":mesh.material_override,"dark":ash_mat}
	hero_light = OmniLight3D.new()
	hero_light.light_color = Color("c6b394")
	hero_light.light_energy = 1.5
	hero_light.omni_range = 7
	decor.add_child(hero_light)
	var stone := material(Color("25232c"))
	stone.albedo_texture = preload("res://assets/polyhaven/realtime_battle/castle_wall_diff_1k.jpg")
	for i in 12:
		# Entrada e jaula livres para os planos da introdução e a câmera de combate.
		if i in [3,9]: continue
		var angle := TAU * float(i) / 12.0
		var point := Vector3(cos(angle)*16,0,-1800+sin(angle)*14)
		var column := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.65
		mesh.height = 3.4 + float(i%3)*0.5
		mesh.radial_segments = 7
		column.mesh = mesh
		column.material_override = stone
		decor.add_child(column)
		column.position = point + Vector3.UP * mesh.height*.5
		column.rotation.z = sin(float(i)*3.1)*0.12
		var light := OmniLight3D.new()
		light.light_color = Color("80bcad")
		light.light_energy = 2.2
		light.omni_range = 7
		decor.add_child(light)
		light.position = point + Vector3.UP*(mesh.height+0.3)
		lights.append(light)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.13
		flame_mesh.height = 0.55
		flame.mesh = flame_mesh
		flame.material_override = material(Color("82d7bf"),4)
		light.add_child(flame)
	# Névoa de partículas em CPU funciona também no renderizador Compatibility.
	var ashes := CPUParticles3D.new()
	ashes.amount = 150
	ashes.lifetime = 9
	ashes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ashes.emission_box_extents = Vector3(17,4,13)
	ashes.direction = Vector3.UP
	ashes.gravity = Vector3(0,0.08,0)
	ashes.initial_velocity_min = 0.12
	ashes.initial_velocity_max = 0.3
	ashes.scale_amount_min = 0.025
	ashes.scale_amount_max = 0.06
	var ash := SphereMesh.new()
	ash.radius = 0.5
	ash.height = 1
	ash.radial_segments = 4
	ash.rings = 3
	ashes.mesh = ash
	ashes.material_override = material(Color("8da696"),0.6)
	decor.add_child(ashes)
	ashes.position = Vector3(0,3,-1800)
	# Luz de recorte garante que madeira, silhuetas e jaula permaneçam legíveis.
	var rim := OmniLight3D.new()
	rim.light_color = Color("b67c5c")
	rim.light_energy = 3.8
	rim.omni_range = 13
	decor.add_child(rim)
	rim.position = Vector3(0,6,-1810)
	# Eclipse em forma de olho sobre a jaula; o centro escuro olha para a arena.
	var eye := MeshInstance3D.new()
	var halo := TorusMesh.new()
	halo.inner_radius = 2.6
	halo.outer_radius = 2.85
	halo.rings = 64
	halo.ring_segments = 12
	eye.mesh = halo
	eye.material_override = material(Color("be9b83"),2.3)
	decor.add_child(eye)
	eye.position = Vector3(0,10,-1823)
	eye.rotation.x = PI*.5
	var pupil := MeshInstance3D.new()
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 2.4
	pupil_mesh.height = 4.8
	pupil.mesh = pupil_mesh
	pupil.material_override = material(Color("08080d"))
	decor.add_child(pupil)
	pupil.position = eye.position
	var sigil_mat := material(Color("526a67"),.65)
	for r in [6.0,9.0]:
		var sigil := MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = r-.035
		shape.outer_radius = r+.035
		shape.rings = 64
		shape.ring_segments = 6
		sigil.mesh = shape
		sigil.material_override = sigil_mat
		decor.add_child(sigil)
		sigil.position = Vector3(0,.015,-1800)

func _process(delta:float) -> void:
	if not active: return
	time += delta
	if is_instance_valid(hero_light): hero_light.position = stage.player.position+Vector3(0,2.4,1.8)
	for i in lights.size():
		lights[i].light_energy = 2.2 + sin(time*2.4+float(i)*2.0)*0.35
