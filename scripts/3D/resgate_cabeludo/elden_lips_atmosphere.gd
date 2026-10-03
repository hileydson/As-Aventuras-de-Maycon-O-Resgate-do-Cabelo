extends Node3D

const AMBIENCE = preload("res://assets/novos_audios/calabouco_terror/dungeon_ambience_pixabay.mp3")
const BOOM = preload("res://assets/novos_audios/seco_invader_boom_pixabay.mp3")
const GATE = preload("res://assets/novos_audios/calabouco_terror/gate_opening_heavy.mp3")
const GROWL = preload("res://assets/novos_audios/calabouco_terror/zombie_growl_pixabay.mp3")
const BATTLE_SCORE = preload("res://assets/novos_audios/last_battle.mp3")
const SCORE_OVERLAP := 1.0
const SFX = {
	"hit":[preload("res://assets/novos_audios/elden_lips/sfx/wood_body_1.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/wood_body_2.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/wood_body_3.ogg")],
	"heavy_hit":[preload("res://assets/novos_audios/elden_lips/sfx/wood_body_heavy.ogg")],
	"pain":[preload("res://assets/novos_audios/elden_lips/sfx/lips_pain_1.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/lips_pain_2.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/lips_pain_3.ogg")],
	"hurt":[preload("res://assets/novos_audios/elden_lips/sfx/maycon_hurt.ogg")],
	"block":[preload("res://assets/novos_audios/elden_lips/sfx/shield_1.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/shield_2.ogg"),preload("res://assets/novos_audios/elden_lips/sfx/shield_3.ogg")],
	"swing":[preload("res://assets/novos_audios/elden_lips/sfx/blade_swish.ogg")],
	"food_sweep":[preload("res://assets/novos_audios/elden_lips/sfx/food_sweep.ogg")],
	"food_launch":[preload("res://assets/novos_audios/elden_lips/sfx/food_launch.ogg")],
	"food_charge":[preload("res://assets/novos_audios/elden_lips/sfx/food_charge.ogg")],
	"slam":[preload("res://assets/novos_audios/elden_lips/sfx/food_slam.ogg")],
	"splat":[preload("res://assets/novos_audios/elden_lips/sfx/tomato_splat.ogg")],
	"equip":[preload("res://assets/novos_audios/elden_lips/sfx/wood_equip.ogg")],
	"step":[preload("res://assets/novos_audios/elden_lips/sfx/boss_step.ogg")],
	"shift":[preload("res://assets/novos_audios/elden_lips/sfx/world_shift.ogg")],
	"thunder":[preload("res://assets/novos_audios/elden_lips/sfx/storm_thunder.ogg")],
	"gate":[GATE],"roar":[GROWL],"boom":[BOOM]}
const STORM_WIND = preload("res://assets/novos_audios/elden_lips/sfx/storm_wind.ogg")
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
var wind_audio:AudioStreamPlayer
var world_blend:float = 0.0
var phase_heat:float = 0.0
var transition:Tween
var phase_tween:Tween
var dark_materials_applied:bool = false
var weather:Node3D
var rain:CPUParticles3D
var mist:CPUParticles3D
var lightning:MeshInstance3D
var storm_timer:float = 8.0
var lightning_time:float = 0.0
var thunder_delay:float = -1.0
var ritual_columns:Array[Dictionary] = []
var eye:MeshInstance3D
var pupil:MeshInstance3D
var ritual_materials:Array[Dictionary] = []
var score_timer:Timer
var score_active:bool = false
var score_turn:int = 0
var score_fade:Tween

func setup(owner_stage:Node3D) -> void:
	stage = owner_stage
	original_environment = stage.get_node("Morning").environment
	original_sun_energy = stage.get_node("MorningSun").light_energy
	original_sun_color = stage.get_node("MorningSun").light_color
	base = music(BATTLE_SCORE,-80)
	rage = music(BATTLE_SCORE,-80)
	base.stream.loop = false
	rage.stream.loop = false
	score_timer = Timer.new()
	score_timer.one_shot = true
	score_timer.timeout.connect(chain_score)
	add_child(score_timer)
	drone = music(AMBIENCE,-80)
	wind_audio = music(STORM_WIND,-80)
	drone.finished.connect(func():
		if active: drone.play())
	for i in 14:
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

func enter(smooth:bool = true) -> void:
	active = true
	if decor == null:
		build_ritual()
		build_weather()
		for node in decor.find_children("*","MeshInstance3D",true,false):
			if node.material_override is StandardMaterial3D:
				node.material_override = node.material_override.duplicate()
				node.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ritual_materials.append({"material":node.material_override,"alpha":node.material_override.albedo_color.a})
	if transition and transition.is_running(): transition.kill()
	if phase_tween and phase_tween.is_running(): phase_tween.kill()
	phase_heat = 0
	world_blend = 0.0 if smooth else 1.0
	dark_materials_applied = false
	storm_timer = 10.0
	lightning_time = 0
	thunder_delay = -1
	decor.visible = true
	weather.visible = true
	rain.emitting = true
	mist.emitting = true
	for light in lights: light.light_color = Color("80bcad")
	environment = original_environment.duplicate() as Environment
	stage.get_node("Morning").environment = environment
	environment.fog_enabled = true
	environment.fog_density = 0
	environment.fog_sky_affect = 1.0
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.adjustment_enabled = true
	transition = create_tween().set_parallel(true)
	transition.tween_property(self,"world_blend",1.0,4.8 if smooth else .05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for slot in stage.song_slots:
		transition.tween_property(slot,"volume_db",-80.0,3.0)
	var birds := stage.get_node_or_null("Ambiente")
	if birds: transition.tween_property(birds,"volume_db",-80.0,3.2)
	drone.play()
	wind_audio.play()
	transition.tween_property(drone,"volume_db",-23.0,4.0)
	transition.tween_property(wind_audio,"volume_db",-24.0,4.5)
	if smooth: play_sound("shift",stage.player.global_position,-13)
	if is_instance_valid(stage.wind): stage.wind.visible = false

func start_score() -> void:
	if score_fade and score_fade.is_running(): score_fade.kill()
	score_timer.stop()
	base.stop()
	rage.stop()
	base.volume_db = -12.0
	rage.volume_db = -12.0
	score_turn = 0
	score_active = true
	chain_score()

# Mesmo padrão da música da fase: dois players emendam a cauda no início.
func chain_score() -> void:
	if not score_active: return
	var slot:AudioStreamPlayer = base if score_turn==0 else rage
	score_turn = 1-score_turn
	slot.play()
	score_timer.start(maxf(.01,BATTLE_SCORE.get_length()-SCORE_OVERLAP))

func second_phase() -> void:
	phase_tween = create_tween()
	phase_tween.tween_property(self,"phase_heat",1.0,2.0)
	storm_timer = .25
	play_sound("roar",stage.boss.global_position)

func stop_score(duration:float = 1.5) -> void:
	score_active = false
	score_timer.stop()
	if score_fade and score_fade.is_running(): score_fade.kill()
	score_fade = create_tween().set_parallel(true)
	for player in [base,rage,drone,wind_audio]: score_fade.tween_property(player,"volume_db",-80.0,duration)

func leave() -> void:
	active = false
	stop_score(2.5)
	stage.get_node("Morning").environment = original_environment
	var recover := create_tween().set_parallel(true)
	recover.tween_property(stage.get_node("MorningSun"),"light_energy",original_sun_energy,2.0)
	recover.tween_property(stage.get_node("MorningSun"),"light_color",original_sun_color,2.0)
	if decor: decor.visible = false
	if weather: weather.visible = false
	rain.emitting = false
	mist.emitting = false
	for mesh in arena_materials:
		mesh.material_override = arena_materials[mesh].original

func play_sound(kind:String,at:Vector3,volume:float = -9.0,pitch:float = 1.0) -> void:
	if not SFX.has(kind): return
	var first := 0 if kind in ["pain","hurt"] else 2 if kind in ["thunder","shift","roar"] else 5
	var end := 2 if first==0 else 5 if first==2 else sound_pool.size()
	for i in range(first,end):
		var sound := sound_pool[i]
		if sound.playing: continue
		var variants:Array = SFX[kind]
		sound.stream = variants[randi()%variants.size()]
		sound.global_position = at
		sound.volume_db = volume
		sound.pitch_scale = pitch*randf_range(.96,1.04) if kind not in ["thunder","shift","gate"] else pitch
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
		ritual_columns.append({"node":column,"position":column.position,"height":mesh.height})
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
	eye = MeshInstance3D.new()
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
	pupil = MeshInstance3D.new()
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

func build_weather() -> void:
	weather = Node3D.new()
	weather.name = "EldenStorm"
	add_child(weather)
	rain = CPUParticles3D.new()
	rain.amount = 135
	rain.lifetime = 1.3
	rain.preprocess = 1.3
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(17,2,17)
	rain.direction = Vector3(-.28,-1,.12)
	rain.spread = 8
	rain.gravity = Vector3(-2,-4,.5)
	rain.initial_velocity_min = 8
	rain.initial_velocity_max = 11
	var drop := BoxMesh.new()
	drop.size = Vector3(.009,.28,.009)
	rain.mesh = drop
	var rain_mat := material(Color(.46,.64,.73,.15))
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain.material_override = rain_mat
	weather.add_child(rain)
	rain.position = Vector3(0,9,-1799)
	mist = CPUParticles3D.new()
	mist.amount = 34
	mist.lifetime = 8
	mist.preprocess = 8
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(17,.08,14)
	mist.direction = Vector3(1,.04,-.3)
	mist.gravity = Vector3(.06,0,0)
	mist.initial_velocity_min = .3
	mist.initial_velocity_max = .65
	mist.scale_amount_min = .7
	mist.scale_amount_max = 1.6
	var cloud := SphereMesh.new()
	cloud.radius = 1.4
	cloud.height = .32
	cloud.radial_segments = 8
	cloud.rings = 4
	mist.mesh = cloud
	var mist_mat := material(Color(.25,.35,.36,.045))
	mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.material_override = mist_mat
	weather.add_child(mist)
	mist.position = Vector3(0,.35,-1800)
	lightning = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in [Vector3(0,15,0),Vector3(-1,12,0),Vector3(1,10,0),Vector3(-.4,7,0),Vector3(.2,3,0)]:
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	lightning.mesh = mesh
	lightning.material_override = material(Color("c2deef"),3)
	lightning.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	weather.add_child(lightning)
	lightning.visible = false

func _process(delta:float) -> void:
	if not active: return
	time += delta
	var blend := smoothstep(0,1,world_blend)
	if blend>.55 and not dark_materials_applied:
		for mesh in arena_materials: mesh.material_override = arena_materials[mesh].dark
		dark_materials_applied = true
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	for data in ritual_materials: data.material.albedo_color.a = data.alpha*smoothstep(.12,.90,world_blend)
	var sun:DirectionalLight3D = stage.get_node("MorningSun")
	var flash := 0.0
	if world_blend>.90:
		storm_timer -= delta
		if storm_timer<=0:
			storm_timer = randf_range(12,22)*(1.0-phase_heat*.15)
			lightning_time = .38
			thunder_delay = randf_range(.6,1.2)
			lightning.position = Vector3([-19.0,19.0][randi()%2],0,randf_range(-1815,-1794))
		lightning_time = maxf(0,lightning_time-delta)
		flash = .55 if lightning_time>.26 or lightning_time>.10 and lightning_time<.17 else 0.0
		if thunder_delay>=0:
			thunder_delay -= delta
			if thunder_delay<0: play_sound("thunder",lightning.position,-17,.9)
	lightning.visible = flash>0
	sun.light_energy = lerpf(original_sun_energy,.38,blend)+flash
	sun.light_color = original_sun_color.lerp(Color("8596bd"),blend)
	environment.background_energy_multiplier = lerpf(original_environment.background_energy_multiplier,.055,blend)
	environment.background_color = original_environment.background_color.lerp(Color("080b13"),blend)
	environment.ambient_light_color = original_environment.ambient_light_color.lerp(Color("667b91"),blend)
	environment.ambient_light_energy = lerpf(original_environment.ambient_light_energy,.45,blend)+flash*.35
	environment.fog_density = lerpf(original_environment.fog_density if original_environment.fog_enabled else 0.0,.025,blend)+sin(time*.53)*.0025*blend
	environment.fog_light_color = Color("1c2634").lerp(Color("35202d"),phase_heat)
	environment.adjustment_saturation = lerpf(original_environment.adjustment_saturation if original_environment.adjustment_enabled else 1.0,.35,blend)
	environment.adjustment_contrast = lerpf(original_environment.adjustment_contrast if original_environment.adjustment_enabled else 1.0,1.16,blend)
	rain.material_override.albedo_color.a = .15*blend
	rain.gravity.x = -2+sin(time*.38)*1.4
	mist.material_override.albedo_color.a = .045*blend
	mist.direction = Vector3(1,.04,sin(time*.19)*.5)
	for column in ritual_columns:
		column.node.position.y = column.position.y-(1-smoothstep(.25,.95,world_blend))*(column.height+1)
	eye.scale = Vector3.ONE*(.95+.05*blend+sin(time*.42)*.012*blend)
	pupil.scale = eye.scale
	eye.rotation.z = sin(time*.23)*.06
	if is_instance_valid(hero_light): hero_light.position = stage.player.position+Vector3(0,2.4,1.8)
	for i in lights.size():
		lights[i].light_color = Color("80bcad").lerp(Color("cf5461"),phase_heat)
		lights[i].light_energy = (2.2+sin(time*2.4+float(i)*2.0)*.35)*blend
