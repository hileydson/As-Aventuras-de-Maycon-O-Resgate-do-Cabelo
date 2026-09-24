extends Node3D

const ENEMY_SCRIPT = preload("res://scripts/3D/platform_enemy.gd")
const MINI_SECO_SCRIPT = preload("res://scripts/3D/platform_mini_seco.gd")
const LIPS_SCRIPT = preload("res://scripts/3D/platform_lips.gd")
const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const ASSET_ROOT = "res://assets/kenney/platformer_3d/"
const PENTAGRAM_TEXTURE = preload("res://assets/3D/pentagram_item.png")
const PAUSE_SCRIPT = preload("res://scripts/3D/platform_pause.gd")
const BLOOD_OVERLAY_SCRIPT = preload("res://scripts/3D/platform_blood_overlay.gd")
const BLADE_SCRIPT = preload("res://scripts/3D/platform_blade.gd")
const HAND_SCRIPT = preload("res://scripts/3D/platform_hand.gd")
const INVINCIBLE_OVERLAY_SCRIPT = preload("res://scripts/3D/platform_invincible_overlay.gd")
const FREEZE_SOUND = preload("res://assets/novos_audios/special_freeze_distorted.mp3")
const MAYCON_SCREAM = preload("res://assets/novos_audios/maycon_falling_fase_1.mp3")
const ENEMY_EXPLOSION_SOUND = preload("res://assets/novos_audios/mario_part_sounds/fart_explotion.mp3")
const EXPLOSION_SOUND = preload("res://assets/novos_audios/explosao.mp3")
const PICKUP_SOUND = preload("res://assets/audio/plim.mp3")
const DAMAGE_PUNCH_SOUND = preload("res://assets/novos_audios/punch_3.mp3")
const WOOD_BREAK_SOUND = preload("res://assets/novos_audios/mario_part_sounds/wood_barrier_break.mp3")
const LANDING_SOUND = preload("res://assets/novos_audios/maycon_platform_landing.mp3")
const FART_SMOKE = preload("res://assets/novas_imagens/effects/smoke_animation.png")
const PUNCH_IMPACT_SOUND = preload("res://assets/novos_audios/punch.mp3")
const FONT_CONTRAST = preload("res://assets/fonts/contrast.ttf")
const BLADE_ROUTE_IDS = [2, 5, 8, 11]
const HAND_HUB_IDS = [1, 4, 7, 10, 12]
const HUBS = [
	Vector3(0, 0, 32), Vector3(-25, 1, 8), Vector3(25, 0.5, 8),
	Vector3(-44, 2, -24), Vector3(44, 1.5, -24),
	Vector3(-25, 2.8, -54), Vector3(25, 0.5, -54),
	Vector3(-48, 1.2, -87), Vector3(48, 3, -87),
	Vector3(-23, 0.5, -118), Vector3(23, 2, -118),
	Vector3(-43, 2.8, -151), Vector3(43, 0.5, -151),
	Vector3(0, 0, -183)
]
const ROUTES = [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 4),
	Vector2i(3, 5), Vector2i(4, 6), Vector2i(5, 7), Vector2i(6, 8),
	Vector2i(7, 9), Vector2i(8, 10), Vector2i(9, 11), Vector2i(10, 12),
	Vector2i(11, 13), Vector2i(12, 13),
	Vector2i(3, 4), Vector2i(5, 6), Vector2i(7, 8), Vector2i(9, 10)
]

@onready var maycon:CharacterBody3D = $Maycon

var materials:Dictionary = {}
var assets:Dictionary = {}
var geometry:Node3D
var enemies:Node3D
var effects:Node3D
var hazards:Node3D
var scream_audio:AudioStreamPlayer
var pickup_audio:AudioStreamPlayer
var damage_punch_audio:AudioStreamPlayer
var hp_bar:ProgressBar
var hp_label:Label
var pentagram_label:Label
var blood_overlay:Control
var heal_flash:ColorRect
var heal_tween:Tween
var fade_rect:ColorRect
var enemy_trail_mesh:CylinderMesh
var trail_materials:Array[StandardMaterial3D] = []
var pentagram_nodes:Dictionary = {}
var exit_started:bool = false
var blood_pickups:Array[Node3D] = []
var blood_stains:Array[Node3D] = []
var total_stomps:int = 0
var stage_hp_max:float = 100.0
var stage_hp:float = 100.0
var use_realtime_hp:bool = false
var death_in_progress:bool = false
var is_invincible:bool = false
var is_slow_motion:bool = false
var invincibility_time_left:float = 0.0
var last_invincible_milestone:int = 0
var pentagrams_collected_session:int = 0
var special_ready:bool = false
var invincible_overlay:CanvasLayer
var lips_enemy:Node3D
var cutscene_running:bool = false

var pentagram_spawners:Dictionary = {}
var boss_barrier:Node3D
var boss_barrier_collider:CollisionShape3D
var boss_hud_container:Control
var boss_hp_bar:ProgressBar
var boss_name_label:Label
var path_open_announcement:Label
var exit_arrow:Node3D
var exit_arrow_mat:StandardMaterial3D
var landing_audio:AudioStreamPlayer
var intro_active:bool = true
var intro_time:float = 0.0
const INTRO_DURATION:float = 1.75
const INTRO_P0 = Vector3(0.0, -5.5, 45.0)
const INTRO_P1 = Vector3(0.0, 12.0, 48.5)
const INTRO_P2 = Vector3(0.0, 9.5, 38.0)
const INTRO_P3 = Vector3(0.0, 0.18, 32.0)

func _ready() -> void:
	get_tree().paused = false
	use_realtime_hp = Global.battle_mode == Global.battle_mode_realtime
	stage_hp_max = Global.realtime_hp_max if use_realtime_hp else 100.0
	stage_hp = clampf(Global.realtime_hp, 1.0, stage_hp_max) if use_realtime_hp else 100.0
	set_stage_hp(stage_hp)
	Global.save_progress("fase_3d_platform")
	GameSongs.play_song(1)
	_setup_audio_buses()
	scream_audio = AudioStreamPlayer.new()
	scream_audio.stream = MAYCON_SCREAM
	add_child(scream_audio)
	pickup_audio = AudioStreamPlayer.new()
	pickup_audio.stream = PICKUP_SOUND
	pickup_audio.bus = "ItemReverb"
	pickup_audio.volume_db = -11.0
	add_child(pickup_audio)
	damage_punch_audio = AudioStreamPlayer.new()
	damage_punch_audio.stream = DAMAGE_PUNCH_SOUND
	damage_punch_audio.volume_db = 0.0
	add_child(damage_punch_audio)
	landing_audio = AudioStreamPlayer.new()
	landing_audio.stream = LANDING_SOUND
	landing_audio.volume_db = 2.0
	add_child(landing_audio)
	_build_materials()
	if has_node("Cenario"):
		_bind_baked_scene()
	else:
		_build_all_procedural()
	_build_hud()
	_build_pause()
	_build_fade()
	invincible_overlay = CanvasLayer.new()
	invincible_overlay.set_script(INVINCIBLE_OVERLAY_SCRIPT)
	invincible_overlay.special_activated.connect(activate_special)
	add_child(invincible_overlay)
	if Global.platform_pentagrams >= 10:
		last_invincible_milestone = Global.platform_pentagrams / 10
		set_special_ready(true)
	update_hud()
	_start_intro()

func _physics_process(delta:float) -> void:
	if intro_active:
		_process_intro(delta)
		return
	if cutscene_running:
		return
	if is_invincible:
		invincibility_time_left = maxf(invincibility_time_left - delta, 0.0)
		if invincibility_time_left <= 0.0:
			end_invincibility()
	if exit_started or death_in_progress:
		return
	if maycon.global_position.y < -7.0:
		var point := maycon.global_position
		if absf(point.x) < 2.3 and point.z < -202.8 and point.z > -210.5:
			_exit_stage()
		else:
			start_player_death("fall")
		return
	for i in range(blood_pickups.size() - 1, -1, -1):
		var pickup := blood_pickups[i]
		if not is_instance_valid(pickup):
			blood_pickups.remove_at(i)
			continue
		pickup.rotate_y(delta * 2.0)
		if pickup.global_position.distance_to(maycon.global_position + Vector3.UP) < 1.4:
			set_stage_hp(stage_hp + stage_hp_max * 0.1)
			blood_pickups.remove_at(i)
			pickup.queue_free()
			_flash_heal()
			_play_pickup_sound(false)
			update_hud()
	for id in pentagram_nodes.keys():
		var item:Node3D = pentagram_nodes[id]
		if not is_instance_valid(item):
			continue
		item.rotate_y(delta * 1.3)
		if item.global_position.distance_to(maycon.global_position + Vector3.UP * 0.9) < 1.35:
			# Limite de 10 pentagramas para liberar o poder: não deixa pegar mais novos até ativar/gastar o poder
			if Global.platform_pentagrams >= 10:
				continue
			_spawn_color_burst(item.global_position, true)
			_play_pickup_sound(true)
			Global.platform_pentagrams += 1
			pentagrams_collected_session += 1
			pentagram_nodes.erase(id)
			item.queue_free()
			if pentagram_spawners.has(id):
				pentagram_spawners[id].active = false
				pentagram_spawners[id].timer = 28.0
			Global.save_progress("fase_3d_platform")
			update_hud()
			_check_invincibility_milestone()

	# Respawn de pentagramas após tempo para formar loop de gameplay
	for id in pentagram_spawners.keys():
		var spawner: Dictionary = pentagram_spawners[id]
		if not spawner.active:
			spawner.timer -= delta
			if spawner.timer <= 0.0:
				spawner.active = true
				_respawn_pentagram(id, spawner.pos)

	# Atualizar seta vermelha pulsando e flutuando em cima do buraco de saída da fase
	if is_instance_valid(exit_arrow):
		var t := Time.get_ticks_msec() * 0.001
		exit_arrow.position.y = 4.8 + sin(t * 3.5) * 0.45
		var scale_pulse := 1.0 + sin(t * 5.0) * 0.15
		exit_arrow.scale = Vector3(scale_pulse, scale_pulse, scale_pulse)
		exit_arrow.rotate_y(delta * 1.6)
		if exit_arrow_mat:
			var glow := 0.75 + sin(t * 6.5) * 0.25
			exit_arrow_mat.albedo_color = Color(1.0, 0.12 * glow, 0.15 * glow, 0.95)

func _build_materials() -> void:
	materials["grass"] = _material(Color("529755"), 0.9)
	materials["grass_light"] = _material(Color("75ae64"), 0.9)
	materials["earth"] = _material(Color("8f6248"), 1.0)
	materials["earth_dark"] = _material(Color("614335"), 1.0)
	materials["stone"] = _material(Color("c8b8a0"), 0.95)
	materials["stone_dark"] = _material(Color("827c83"), 1.0)
	materials["gold"] = _material(Color("f9ca51"), 0.32)
	materials["red"] = _material(Color("b71d3b"), 0.8)
	materials["blood"] = _material(Color("700016"), 0.46)
	materials["water"] = _material(Color("61b5ca"), 0.3)
	materials["wood"] = _material(Color("915b39"), 1.0)
	materials["leaves"] = _material(Color("43835c"), 1.0)
	materials["pine"] = _material(Color("345e54"), 1.0)
	materials["flower"] = _material(Color("ee8fac"), 0.9)
	materials["mushroom"] = _material(Color("e46f52"), 0.9)
	enemy_trail_mesh = CylinderMesh.new()
	enemy_trail_mesh.top_radius = 0.25
	enemy_trail_mesh.bottom_radius = 0.27
	enemy_trail_mesh.height = 0.02
	enemy_trail_mesh.radial_segments = 10
	for color in [Color("ee8bb1"), Color("72c7e0"), Color("f2bd65"), Color("ad91d6")]:
		var trail_material := _material(color, 1.0)
		trail_material.albedo_color.a = 0.65
		trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		trail_materials.append(trail_material)

func _material(color:Color, roughness:float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _build_all_procedural() -> void:
	_build_environment()
	geometry = Node3D.new()
	geometry.name = "Cenario"
	add_child(geometry)
	_build_clouds()
	enemies = Node3D.new()
	enemies.name = "Inimigos"
	add_child(enemies)
	effects = Node3D.new()
	effects.name = "Efeitos"
	add_child(effects)
	hazards = Node3D.new()
	hazards.name = "Armadilhas"
	add_child(hazards)
	_build_hubs_and_routes()
	_build_elevated_areas()
	_build_hands()
	_build_finish()
	_scatter_details()
	_spawn_enemies()
	_spawn_mini_secos()
	_spawn_lips()
	_spawn_pentagrams()
	_build_blue_particles()

func _bind_baked_scene() -> void:
	geometry = $Cenario

	hazards = get_node_or_null("Armadilhas")
	if not hazards:
		hazards = Node3D.new()
		hazards.name = "Armadilhas"
		add_child(hazards)

	enemies = get_node_or_null("Inimigos")
	if not enemies:
		enemies = Node3D.new()
		enemies.name = "Inimigos"
		add_child(enemies)

	effects = get_node_or_null("Efeitos")
	if not effects:
		effects = Node3D.new()
		effects.name = "Efeitos"
		add_child(effects)

	boss_barrier = get_node_or_null("GiantWoodenBarrier")
	if boss_barrier:
		boss_barrier_collider = boss_barrier.get_node_or_null("CollisionShape3D")

	exit_arrow = get_node_or_null("ExitHoleArrow")
	if exit_arrow:
		var shaft = exit_arrow.get_node_or_null("Shaft")
		if shaft is MeshInstance3D and shaft.material_override is StandardMaterial3D:
			exit_arrow_mat = shaft.material_override
	if not exit_arrow_mat:
		exit_arrow_mat = StandardMaterial3D.new()
		exit_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		exit_arrow_mat.albedo_color = Color(1.0, 0.12, 0.15, 0.95)

	# Reconectar / indexar pentagramas salvos na cena
	var pent_group = geometry.get_node_or_null("Pentagramas")
	if pent_group:
		for pent in pent_group.get_children():
			var p_name: String = pent.name
			if p_name.begins_with("Pentagrama_"):
				var id := p_name.replace("Pentagrama_", "")
				pentagram_nodes[id] = pent
				pentagram_spawners[id] = {"pos": pent.position, "timer": 0.0, "active": true}
	else:
		_spawn_pentagrams()

	# Configurar entidades de Inimigos
	if enemies:
		var seco_idx := 0
		for child in enemies.get_children():
			if child.name.begins_with("Inimigo_"):
				var parts := child.name.split("_")
				if parts.size() >= 3:
					var i := parts[1].to_int()
					var j := parts[2].to_int()
					if child.has_method("setup"):
						child.setup((i + j) % 4, maycon, self, (i + j) % 4)
			elif child.name.begins_with("MiniSeco_"):
				if child.has_method("setup"):
					child.setup(seco_idx % 3, maycon, self)
					seco_idx += 1
			elif child.name == "LipsGargaroker":
				lips_enemy = child
				if lips_enemy.has_method("setup"):
					lips_enemy.setup(self, maycon, 4)

		if not lips_enemy:
			_spawn_lips()

	# Configurar armadilhas existentes
	if hazards:
		for child in hazards.get_children():
			if child.name.begins_with("Navalha_"):
				var idx := child.name.replace("Navalha_", "").to_int()
				if idx < ROUTES.size():
					var route: Vector2i = ROUTES[idx]
					var dir: Vector3 = (Vector3(HUBS[route.y]) - Vector3(HUBS[route.x])).normalized()
					if child.has_method("setup"):
						child.setup(self, maycon, dir, idx)
			elif child.name.begins_with("MaoEsmagadora_"):
				var idx := child.name.replace("MaoEsmagadora_", "").to_int()
				if child.has_method("setup"):
					child.setup(self, maycon, idx)

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91c8e7")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e0e6ef")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("a8d0e6")
	environment.fog_density = 0.004
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff0c9")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)
	# The distant water and stone silhouettes make the floating islands feel like a world.
	_box(Vector3(0.0, -18.0, -83.0), Vector3(300.0, 1.0, 360.0), "water", false)
	for i in range(34):
		var z := 55.0 - float(i) * 8.0
		for side in [-1.0, 1.0]:
			var height := 8.0 + float((i * 7) % 9)
			_box(Vector3(side * (77.0 + float((i * 3) % 9)), -9.0 + height * 0.5, z), Vector3(8.0 + float(i % 3) * 3.0, height, 8.0), "stone_dark", false)

func _box(center:Vector3, size:Vector3, material_name:String, solid:bool = true) -> Node3D:
	var parent := geometry if is_instance_valid(geometry) else self
	var node := Node3D.new()
	node.position = center
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = materials[material_name]
	node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node

func _build_clouds() -> void:
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 1.0
	cloud_mesh.height = 2.0
	cloud_mesh.radial_segments = 12
	cloud_mesh.rings = 6
	var cloud_material := StandardMaterial3D.new()
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.albedo_color = Color("f8faff")
	var cloud_rng := RandomNumberGenerator.new()
	cloud_rng.seed = 91573
	for i in range(25):
		var center := Vector3(cloud_rng.randf_range(-95.0, 95.0), cloud_rng.randf_range(18.0, 32.0), cloud_rng.randf_range(-215.0, 75.0))
		for puff_index in range(4):
			var puff := MeshInstance3D.new()
			puff.mesh = cloud_mesh
			puff.material_override = cloud_material
			puff.position = center + Vector3(float(puff_index) * 3.2 - 4.8, cloud_rng.randf_range(-1.2, 1.2), cloud_rng.randf_range(-2.0, 2.0))
			puff.scale = Vector3(cloud_rng.randf_range(3.5, 5.5), cloud_rng.randf_range(1.2, 2.2), cloud_rng.randf_range(2.3, 4.2))
			geometry.add_child(puff)

func _asset(name:String, position:Vector3, scale:float = 1.0, rotation:float = 0.0) -> Node3D:
	if not assets.has(name):
		assets[name] = load(ASSET_ROOT + name + ".glb")
	var scene:PackedScene = assets[name]
	var model:Node3D = scene.instantiate()
	model.position = position
	model.scale = Vector3.ONE * scale
	model.rotation.y = rotation
	geometry.add_child(model)
	var tint := "stone"
	if name.begins_with("tree-pine"):
		tint = "pine"
	elif name.begins_with("tree") or name == "grass" or name == "plant":
		tint = "leaves"
	elif name.begins_with("flower"):
		tint = "flower"
	elif name == "mushrooms":
		tint = "mushroom"
	elif name.begins_with("block-grass"):
		tint = "grass_light"
	elif name.begins_with("coin") or name == "star":
		tint = "gold"
	elif name == "flag" or name == "heart":
		tint = "red"
	elif name == "crate" or name == "barrel" or name.begins_with("fence") or name == "sign":
		tint = "wood"
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = materials[tint]
	return model

func _platform(top:Vector3, footprint:Vector2, material_name:String = "grass") -> void:
	_box(top - Vector3.UP * 0.75, Vector3(footprint.x, 1.5, footprint.y), "earth" if material_name == "grass" else "stone_dark")
	_box(top + Vector3.UP * 0.09, Vector3(footprint.x, 0.18, footprint.y), material_name)

func _build_hubs_and_routes() -> void:
	for i in range(HUBS.size()):
		var hub:Vector3 = HUBS[i]
		var size := Vector2(23.0, 20.0) if i == 0 or i == HUBS.size() - 1 else Vector2(19.0, 17.0)
		_platform(hub, size)
		for side in [-1.0, 1.0]:
			for corner in [-1.0, 1.0]:
				_asset("block-grass-large", hub + Vector3(side * (size.x * 0.5 - 1.2), -0.2, corner * (size.y * 0.5 - 1.0)), 1.2, float(i) * 0.4)
	for route_index in range(ROUTES.size()):
		var route:Vector2i = ROUTES[route_index]
		var start:Vector3 = HUBS[route.x]
		var finish:Vector3 = HUBS[route.y]
		var steps := ceili(start.distance_to(finish) / 4.2)
		for i in range(1, steps):
			var point := start.lerp(finish, float(i) / float(steps))
			if route_index in BLADE_ROUTE_IDS and i == floori(float(steps) * 0.5):
				_spawn_blade(point, (finish - start).normalized(), route_index)
				continue
			var material_name := "wood" if i % 4 == 0 else "stone" if i % 4 == 1 else "grass_light"
			_platform(point, Vector2(3.5, 3.5), material_name)
			if i % 5 == 0:
				_asset("rocks", point + Vector3(-1.6, 0.25, 0.0), 0.7, float(i))

func _spawn_blade(point:Vector3, direction:Vector3, index:int) -> void:
	var blade := Node3D.new()
	blade.set_script(BLADE_SCRIPT)
	blade.name = "Navalha_%d" % index
	blade.position = point
	blade.call("setup", self, maycon, direction, index)
	hazards.add_child(blade)

func _build_hands() -> void:
	for index in HAND_HUB_IDS:
		var hand := Node3D.new()
		hand.set_script(HAND_SCRIPT)
		hand.name = "MaoEsmagadora_%d" % index
		hand.position = HUBS[index] + Vector3(0.0, 0.0, -1.8)
		hand.call("setup", self, maycon, index)
		hazards.add_child(hand)

func _build_elevated_areas() -> void:
	for hub_index in range(1, HUBS.size() - 1):
		var hub:Vector3 = HUBS[hub_index]
		var side := -1.0 if hub.x < 0.0 else 1.0
		for step in range(1, 5):
			var top := hub + Vector3(side * (1.0 + float(step) * 2.0), float(step) * 0.82, 5.0 - float(step) * 2.1)
			_platform(top, Vector2(3.5, 3.5), "grass_light")
		var balcony := hub + Vector3(side * 11.0, 4.1, -4.0)
		_platform(balcony, Vector2(7.0, 7.0), "grass")
		_asset("star", balcony + Vector3.UP * 1.1, 1.6)
		for step in range(2):
			var overlook := hub + Vector3(side * (13.0 + float(step) * 4.1), 4.1 - float(step) * 0.7, -4.0 - float(step) * 3.3)
			_platform(overlook, Vector2(3.4, 3.4), "stone")

func _build_finish() -> void:
	# The final flag surrounds a real opening; only the side and end caps are solid.
	_platform(Vector3(0.0, 0.0, -195.0), Vector2(17.0, 5.0))
	for side in [-1.0, 1.0]:
		_platform(Vector3(side * 6.0, 0.0, -206.0), Vector2(8.0, 14.0), "stone")
	for z in [-200.0, -212.0]:
		_platform(Vector3(0.0, 0.0, z), Vector2(4.0, 4.0), "stone")
	_asset("flag", Vector3(-5.0, 0.15, -199.0), 6.0, PI * 0.5)
	for i in range(12):
		var angle := float(i) / 12.0 * TAU
		var ring := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22
		mesh.height = 0.44
		ring.mesh = mesh
		ring.material_override = materials["gold"]
		ring.position = Vector3(cos(angle) * 2.4, 0.34, -206.0 + sin(angle) * 2.4)
		geometry.add_child(ring)
	var beam := OmniLight3D.new()
	beam.position = Vector3(0.0, -0.5, -206.0)
	beam.light_color = Color("ffc45b")
	beam.light_energy = 1.5
	beam.omni_range = 6.0
	add_child(beam)
	_build_exit_arrow()
	_build_giant_wooden_barrier()

func _build_exit_arrow() -> void:
	exit_arrow = Node3D.new()
	exit_arrow.name = "ExitHoleArrow"
	exit_arrow.position = Vector3(0.0, 4.8, -206.0)
	
	exit_arrow_mat = StandardMaterial3D.new()
	exit_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	exit_arrow_mat.albedo_color = Color(1.0, 0.12, 0.15, 0.95)
	
	# Haste cilíndrica da seta
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.35
	shaft_mesh.bottom_radius = 0.35
	shaft_mesh.height = 1.8
	shaft_mesh.radial_segments = 16
	shaft.mesh = shaft_mesh
	shaft.material_override = exit_arrow_mat
	shaft.position.y = 0.9
	exit_arrow.add_child(shaft)
	
	# Ponta cônica invertida apontando diretamente para o buraco (para baixo)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 1.05
	head_mesh.height = 1.4
	head_mesh.radial_segments = 16
	head.mesh = head_mesh
	head.material_override = exit_arrow_mat
	head.rotation.x = PI # Aponta para baixo
	head.position.y = -0.4
	exit_arrow.add_child(head)
	
	# Luz vermelha suave para destacar a seta e o buraco
	var arrow_light := OmniLight3D.new()
	arrow_light.light_color = Color(1.0, 0.2, 0.2)
	arrow_light.light_energy = 2.2
	arrow_light.omni_range = 7.0
	exit_arrow.add_child(arrow_light)
	
	add_child(exit_arrow)

func _build_giant_wooden_barrier() -> void:
	boss_barrier = StaticBody3D.new()
	boss_barrier.name = "GiantWoodenBarrier"
	boss_barrier.position = Vector3(0.0, 0.0, -193.2)
	
	boss_barrier_collider = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(20.0, 10.0, 3.0)
	boss_barrier_collider.shape = box_shape
	boss_barrier_collider.position = Vector3(0.0, 5.0, 0.0)
	boss_barrier.add_child(boss_barrier_collider)

	var wood_mat: StandardMaterial3D = materials["wood"]
	var dark_wood_mat: StandardMaterial3D = materials["earth_dark"]
	var metal_mat: StandardMaterial3D = materials["stone_dark"]

	for i in range(18):
		var log_inst := MeshInstance3D.new()
		var log_mesh := CylinderMesh.new()
		var log_h := randf_range(8.2, 9.8)
		log_mesh.top_radius = randf_range(0.48, 0.62)
		log_mesh.bottom_radius = randf_range(0.55, 0.70)
		log_mesh.height = log_h
		log_mesh.radial_segments = 14
		log_inst.mesh = log_mesh
		log_inst.material_override = wood_mat if i % 2 == 0 else dark_wood_mat
		var offset_x: float = -9.2 + float(i) * 1.08 + randf_range(-0.08, 0.08)
		log_inst.position = Vector3(offset_x, log_h * 0.5, randf_range(-0.25, 0.25))
		log_inst.rotation = Vector3(randf_range(-0.03, 0.03), randf_range(-0.2, 0.2), randf_range(-0.04, 0.04))
		boss_barrier.add_child(log_inst)

	var beam_heights := [1.8, 4.4, 7.0]
	for bh in beam_heights:
		var beam := MeshInstance3D.new()
		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(20.2, 0.75, 0.85)
		beam.mesh = beam_mesh
		beam.material_override = wood_mat
		beam.position = Vector3(0.0, bh, 0.45)
		boss_barrier.add_child(beam)
		
		for mx in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			var band := MeshInstance3D.new()
			var band_mesh := BoxMesh.new()
			band_mesh.size = Vector3(0.55, 0.85, 0.95)
			band.mesh = band_mesh
			band.material_override = metal_mat
			band.position = Vector3(mx, bh, 0.45)
			boss_barrier.add_child(band)

	for angle in [-0.42, 0.42]:
		var diag := MeshInstance3D.new()
		var diag_mesh := BoxMesh.new()
		diag_mesh.size = Vector3(18.5, 0.55, 0.65)
		diag.mesh = diag_mesh
		diag.material_override = dark_wood_mat
		diag.position = Vector3(0.0, 4.4, 0.6)
		diag.rotation.z = angle
		boss_barrier.add_child(diag)

	var sign_board := MeshInstance3D.new()
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(9.2, 2.2, 0.35)
	sign_board.mesh = sign_mesh
	sign_board.material_override = dark_wood_mat
	sign_board.position = Vector3(0.0, 3.6, 0.95)
	boss_barrier.add_child(sign_board)

	var sign_border := MeshInstance3D.new()
	var border_mesh := BoxMesh.new()
	border_mesh.size = Vector3(9.5, 2.45, 0.25)
	sign_border.mesh = border_mesh
	sign_border.material_override = materials["gold"]
	sign_border.position = Vector3(0.0, 3.6, 0.85)
	boss_barrier.add_child(sign_border)

	var label_3d := Label3D.new()
	label_3d.text = tr("PLATFORM_BARRIER_SIGN")
	label_3d.font_size = 46
	label_3d.outline_size = 14
	label_3d.modulate = Color(1.0, 0.88, 0.3)
	label_3d.outline_modulate = Color(0.12, 0.02, 0.02)
	label_3d.position = Vector3(0.0, 3.6, 1.15)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_3d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_barrier.add_child(label_3d)

	add_child(boss_barrier)

func _show_path_open_announcement() -> void:
	if not is_instance_valid(path_open_announcement):
		return
	path_open_announcement.visible = true
	path_open_announcement.modulate.a = 0.0
	path_open_announcement.scale = Vector2(0.6, 0.6)
	var banner_tween := create_tween().bind_node(path_open_announcement).set_parallel(true)
	banner_tween.tween_property(path_open_announcement, "modulate:a", 1.0, 0.4)
	banner_tween.tween_property(path_open_announcement, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_interval(3.8)
	banner_tween.chain().tween_property(path_open_announcement, "modulate:a", 0.0, 1.0)
	banner_tween.chain().tween_callback(func():
		if is_instance_valid(path_open_announcement):
			path_open_announcement.visible = false
	)

func open_wooden_barrier() -> void:
	if not is_instance_valid(boss_barrier):
		return
	
	if is_instance_valid(boss_barrier_collider):
		boss_barrier_collider.set_deferred("disabled", true)
	
	var break_audio := AudioStreamPlayer.new()
	break_audio.stream = WOOD_BREAK_SOUND
	break_audio.volume_db = 6.0
	add_child(break_audio)
	break_audio.play()
	get_tree().create_timer(4.5).timeout.connect(break_audio.queue_free)

	if is_instance_valid(maycon) and "camera_shake" in maycon:
		maycon.camera_shake = 1.0

	_spawn_color_burst(boss_barrier.global_position + Vector3(0, 4.0, 0), false)
	for i in range(12):
		var blood := BLOOD_SCENE.instantiate()
		blood.position = boss_barrier.global_position + Vector3(randf_range(-6.0, 6.0), randf_range(1.0, 6.0), randf_range(-1.0, 1.0))
		blood.scale = Vector3.ONE * randf_range(2.0, 3.2)
		effects.add_child(blood)
		get_tree().create_timer(3.0).timeout.connect(blood.queue_free)

	var tween := create_tween().bind_node(boss_barrier).set_parallel(true)
	for child in boss_barrier.get_children():
		if child is CollisionShape3D:
			continue
		if child is Node3D:
			var spread_x := randf_range(-10.0, 10.0)
			var spread_y := randf_range(2.0, 9.0)
			var spread_z := randf_range(-14.0, 6.0)
			tween.tween_property(child, "position", child.position + Vector3(spread_x, spread_y, spread_z), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "rotation", child.rotation + Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)), 1.6)
			tween.tween_property(child, "scale", Vector3.ZERO, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(boss_barrier.queue_free)

	if not cutscene_running:
		_show_path_open_announcement()

func _spawn_death_blast(at: Vector3) -> void:
	# 1. Som de explosão massivo em camadas
	var exp_aud := AudioStreamPlayer.new()
	exp_aud.stream = EXPLOSION_SOUND
	exp_aud.volume_db = 4.0
	exp_aud.pitch_scale = 0.92
	add_child(exp_aud)
	exp_aud.play()
	get_tree().create_timer(3.5).timeout.connect(exp_aud.queue_free)

	var fart_exp_aud := AudioStreamPlayer.new()
	fart_exp_aud.stream = ENEMY_EXPLOSION_SOUND
	fart_exp_aud.volume_db = 2.0
	fart_exp_aud.pitch_scale = 0.85
	add_child(fart_exp_aud)
	fart_exp_aud.play()
	get_tree().create_timer(3.0).timeout.connect(fart_exp_aud.queue_free)

	# 2. Flash de Luz Intenso
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.28)
	light.light_energy = 9.0
	light.omni_range = 24.0
	light.position = at
	effects.add_child(light)
	var lt_tw := create_tween().bind_node(light)
	lt_tw.tween_property(light, "light_energy", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lt_tw.chain().tween_callback(light.queue_free)

	# 3. Anel de Choque / Blast Wave em Expansão
	var shock_mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.75
	torus.rings = 16
	torus.ring_segments = 32
	shock_mesh.mesh = torus
	var shock_mat := StandardMaterial3D.new()
	shock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shock_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shock_mat.albedo_color = Color(1.0, 0.78, 0.25, 0.95)
	shock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shock_mesh.material_override = shock_mat
	shock_mesh.position = at
	shock_mesh.scale = Vector3.ONE * 0.4
	effects.add_child(shock_mesh)

	var sw_tw := create_tween().bind_node(shock_mesh).set_parallel(true)
	sw_tw.tween_property(shock_mesh, "scale", Vector3.ONE * 10.5, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tw.tween_property(shock_mat, "albedo_color:a", 0.0, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sw_tw.chain().tween_callback(shock_mesh.queue_free)

	# 4. Partículas de Explosão e Fumaça
	var parts := CPUParticles3D.new()
	parts.position = at
	parts.amount = 85
	parts.lifetime = 0.85
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	parts.emission_sphere_radius = 1.0
	parts.direction = Vector3(0.0, 0.6, -1.0)
	parts.spread = 120.0
	parts.initial_velocity_min = 14.0
	parts.initial_velocity_max = 26.0
	parts.gravity = Vector3(0.0, -8.0, 0.0)
	parts.scale_amount_min = 1.5
	parts.scale_amount_max = 3.2
	var part_mat := StandardMaterial3D.new()
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.albedo_color = Color(1.0, 0.55, 0.15)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	sphere_mesh.material = part_mat
	parts.mesh = sphere_mesh
	effects.add_child(parts)
	parts.emitting = true
	get_tree().create_timer(1.2).timeout.connect(parts.queue_free)

	# 5. Spray violento de sangue
	for i in range(8):
		var blood := BLOOD_SCENE.instantiate()
		blood.position = at + Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 1.2), randf_range(-1.2, 1.2))
		blood.scale = Vector3.ONE * randf_range(2.2, 3.8)
		effects.add_child(blood)
		get_tree().create_timer(2.5).timeout.connect(blood.queue_free)

func start_boss_lips_death_cutscene(lips_boss: Node3D) -> void:
	if cutscene_running:
		return
	cutscene_running = true

	# 0. Imediatamente zerar contador de pentagramas e retirar o poder do pentagrama
	Global.platform_pentagrams = 0
	pentagrams_collected_session = 0
	last_invincible_milestone = 0
	set_special_ready(false)
	update_hud()
	Global.save_progress("fase_3d_platform")
	end_invincibility()

	# 1. Congelar e estabilizar totalmente o Maycon no chão onde o golpe fatal foi dado
	if is_instance_valid(maycon):
		if maycon.has_method("set_cutscene_active"):
			maycon.set_cutscene_active(true)
		maycon.control_enabled = false
		maycon.velocity = Vector3.ZERO
		maycon.set("saved_cutscene_velocity", Vector3.ZERO)

		# Assenta pés do Maycon firmemente no chão se estiver no ar
		var space_state := get_world_3d().direct_space_state
		var ground_ray := PhysicsRayQueryParameters3D.create(maycon.global_position + Vector3.UP * 1.5, maycon.global_position - Vector3.UP * 12.0, 1)
		var ground_hit := space_state.intersect_ray(ground_ray)
		if not ground_hit.is_empty():
			maycon.global_position.y = ground_hit.position.y

		# Estabiliza visual do modelo para nunca piscar ou tremer
		if "visual" in maycon and is_instance_valid(maycon.visual):
			maycon.visual.visible = true
			maycon.visual.scale = Vector3.ONE
			maycon.visual.position = Vector3.ZERO
			maycon.visual.rotation.x = 0.0
			maycon.visual.rotation.z = 0.0

		# Oculta aura de invencibilidade para não piscar luzes
		if "invincibility_aura" in maycon and is_instance_valid(maycon.invincibility_aura):
			maycon.invincibility_aura.visible = false

		# Pausa process_mode do Maycon durante a cutscene (garante 0 oscilações ou deslocamentos)
		maycon.process_mode = Node.PROCESS_MODE_DISABLED

	if is_instance_valid(invincible_overlay):
		invincible_overlay.visible = false

	# 2. Congelar tempo para inimigos e perigos restantes
	if is_instance_valid(enemies):
		enemies.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(hazards):
		hazards.process_mode = Node.PROCESS_MODE_DISABLED

	# 3. Atualizar barra de vida e título do boss
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.value = 0.0
	if is_instance_valid(boss_name_label):
		boss_name_label.text = "☠ " + tr("PLATFORM_BOSS_DEFEATED") + " ☠"
		boss_name_label.add_theme_color_override("font_color", Color("66ff88"))

	var p_start: Vector3 = lips_boss.global_position
	var p_barrier: Vector3 = Vector3(0.0, 3.8, -193.2)

	# 4. MEGA EXPLOSÃO no momento do impacto fatal (motivo de ser arremessado pra tão longe!)
	_spawn_death_blast(p_start + Vector3(0.0, 1.4, 0.0))

	# 5. Criar Câmera de Cutscene dinâmica
	var cutscene_cam := Camera3D.new()
	cutscene_cam.name = "BossDeathCutsceneCam"
	cutscene_cam.fov = 68.0
	add_child(cutscene_cam)

	# Posição inicial da câmera perto do Lips
	cutscene_cam.global_position = p_start + Vector3(5.5, 3.2, 7.5)
	cutscene_cam.look_at(p_start + Vector3(0.0, 0.5, -2.0), Vector3.UP)
	cutscene_cam.make_current()

	# Tremor inicial na câmera pelo impacto da explosão
	var initial_shake := create_tween()
	for i in range(8):
		initial_shake.tween_property(cutscene_cam, "h_offset", randf_range(-0.55, 0.55), 0.03)
		initial_shake.parallel().tween_property(cutscene_cam, "v_offset", randf_range(-0.55, 0.55), 0.03)
	initial_shake.tween_property(cutscene_cam, "h_offset", 0.0, 0.05)
	initial_shake.parallel().tween_property(cutscene_cam, "v_offset", 0.0, 0.05)

	# Urro dramático do Lips
	if is_instance_valid(lips_boss) and lips_boss.get("scream_audio") != null:
		var s_aud: AudioStreamPlayer3D = lips_boss.scream_audio
		s_aud.pitch_scale = 0.60
		s_aud.play()
	elif scream_audio:
		scream_audio.pitch_scale = 0.62
		scream_audio.volume_db = 2.5
		scream_audio.play()

	# Garantir Lips 100% visível sem piscar
	if is_instance_valid(lips_boss) and "model" in lips_boss and is_instance_valid(lips_boss.model):
		lips_boss.model.visible = true

	# 6. Arremesso Lento do Lips impulsionado pela explosão em direção à cerca de madeira
	var flight_duration := 3.4
	var flight_tw := create_tween()
	flight_tw.tween_method(func(prog: float):
		if not is_instance_valid(lips_boss):
			return
		var px := lerpf(p_start.x, p_barrier.x, prog)
		var pz := lerpf(p_start.z, p_barrier.z, prog)
		var base_y := lerpf(p_start.y, p_barrier.y, prog)
		var arc_peak := maxf(p_start.y, 4.0) + 5.5
		var py := base_y + sin(prog * PI) * arc_peak
		lips_boss.global_position = Vector3(px, py, pz)

		# Rotação lenta no ar
		lips_boss.rotation.x = prog * TAU * 1.5
		lips_boss.rotation.y += 0.03
		lips_boss.rotation.z = sin(prog * TAU) * 0.45

		# Câmera acompanha o Lips
		if is_instance_valid(cutscene_cam):
			var desired_cam := lips_boss.global_position + Vector3(5.5, 3.2, 7.5)
			cutscene_cam.global_position = cutscene_cam.global_position.lerp(desired_cam, 0.22)
			cutscene_cam.look_at(lips_boss.global_position + Vector3(0.0, 0.5, -2.0), Vector3.UP)

		# Partículas ocasionais de sangue
		if randf() < 0.25:
			var blood := BLOOD_SCENE.instantiate()
			blood.position = lips_boss.global_position + Vector3(randf_range(-1.2, 1.2), randf_range(-0.5, 0.8), randf_range(-1.2, 1.2))
			blood.scale = Vector3.ONE * randf_range(1.5, 2.5)
			effects.add_child(blood)
			get_tree().create_timer(1.8).timeout.connect(blood.queue_free)
	, 0.0, 1.0, flight_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await flight_tw.finished

	# 7. Colisão e quebra da cerca de madeira!
	if is_instance_valid(lips_boss):
		lips_boss.global_position = p_barrier

	open_wooden_barrier()

	# Tremor na câmera pelo impacto na cerca
	if is_instance_valid(cutscene_cam):
		var shake_tw := create_tween()
		for i in range(10):
			shake_tw.tween_property(cutscene_cam, "h_offset", randf_range(-0.5, 0.5), 0.03)
			shake_tw.parallel().tween_property(cutscene_cam, "v_offset", randf_range(-0.5, 0.5), 0.03)
		shake_tw.tween_property(cutscene_cam, "h_offset", 0.0, 0.05)
		shake_tw.parallel().tween_property(cutscene_cam, "v_offset", 0.0, 0.05)

	# 8. CONTINUAÇÃO RUMO AO INFINITO: Lips não desvia nem cai no buraco da seta, continua voando pra frente no horizonte infinito!
	if is_instance_valid(cutscene_cam):
		cutscene_cam.global_position = Vector3(3.2, 5.2, -191.0)
		cutscene_cam.look_at(Vector3(0.0, 7.0, -450.0), Vector3.UP)

	if is_instance_valid(lips_boss):
		var infinite_tw := create_tween().set_parallel(true)
		infinite_tw.tween_property(lips_boss, "global_position:z", -520.0, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		infinite_tw.tween_property(lips_boss, "global_position:y", 14.0, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		infinite_tw.tween_property(lips_boss, "global_position:x", 0.0, 2.4)
		infinite_tw.tween_property(lips_boss, "rotation:x", lips_boss.rotation.x + 16.0, 2.4)
		infinite_tw.tween_property(lips_boss, "rotation:z", lips_boss.rotation.z + 8.0, 2.4)
		infinite_tw.tween_property(lips_boss, "scale", Vector3.ONE * 0.05, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if is_instance_valid(lips_boss) and lips_boss.get("scream_audio") != null:
			var s_aud: AudioStreamPlayer3D = lips_boss.scream_audio
			var s_tw := create_tween().bind_node(s_aud)
			s_tw.tween_property(s_aud, "volume_db", -45.0, 2.2)
		elif scream_audio:
			var s_tw := create_tween().bind_node(scream_audio)
			s_tw.tween_property(scream_audio, "volume_db", -45.0, 2.2)
		await infinite_tw.finished

	# Pausa para ver o horizonte límpido e desimpedido
	await get_tree().create_timer(0.8).timeout

	# 9. Fade out de transição para tela preta
	if is_instance_valid(fade_rect):
		fade_rect.color = Color.BLACK
		var fade_out := create_tween().bind_node(fade_rect)
		fade_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await fade_out.finished

	# 10. Durante a tela preta: limpar Lips, restaurar câmera do Maycon, desobstruir e despausar
	if is_instance_valid(lips_boss):
		lips_boss.queue_free()
	if is_instance_valid(cutscene_cam):
		cutscene_cam.queue_free()
	if is_instance_valid(boss_hud_container):
		boss_hud_container.visible = false

	# Reposicionar suavemente a câmera do Maycon atrás dele antes de abrir o fade
	if is_instance_valid(maycon) and is_instance_valid(maycon.camera):
		maycon.camera.global_position = maycon.global_position + Vector3(0.0, 3.1, 11.0)
		maycon.camera.look_at(maycon.global_position + Vector3(0.0, 1.35, 0.0), Vector3.UP)
		maycon.camera.make_current()

	# Descongelar Maycon de forma limpa e estável
	if is_instance_valid(maycon):
		maycon.process_mode = Node.PROCESS_MODE_INHERIT
		if maycon.has_method("set_cutscene_active"):
			maycon.set_cutscene_active(false)
		else:
			maycon.set("cutscene_active", false)
		maycon.control_enabled = true
		maycon.velocity = Vector3.ZERO
		maycon.set("saved_cutscene_velocity", Vector3.ZERO)

	if is_instance_valid(enemies):
		enemies.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(hazards):
		hazards.process_mode = Node.PROCESS_MODE_INHERIT

	cutscene_running = false

	# 11. Fade in de volta para o Maycon
	if is_instance_valid(fade_rect):
		var fade_in := create_tween().bind_node(fade_rect)
		fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await fade_in.finished

	# 12. Mostrar banner triunfante de caminho livre
	_show_path_open_announcement()

func update_boss_lips_hp(current_hp: int, _max_hp: int) -> void:
	if not is_instance_valid(boss_hp_bar):
		return
	var hp_tw := create_tween().bind_node(boss_hp_bar)
	hp_tw.tween_property(boss_hp_bar, "value", float(current_hp), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	if is_instance_valid(boss_name_label):
		boss_name_label.text = "💥 " + tr("PLATFORM_BOSS_HIT") + " 💥"
		boss_name_label.add_theme_color_override("font_color", Color("ffeedd"))
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(boss_name_label) and current_hp > 0:
				boss_name_label.text = "★ " + tr("PLATFORM_BOSS_NAME") + " ★"
				boss_name_label.add_theme_color_override("font_color", Color("f9ca51"))
		)

func boss_lips_defeated() -> void:
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.value = 0.0
	if is_instance_valid(boss_name_label):
		boss_name_label.text = "☠ " + tr("PLATFORM_BOSS_DEFEATED") + " ☠"
		boss_name_label.add_theme_color_override("font_color", Color("66ff88"))
	
	if not cutscene_running:
		open_wooden_barrier()
	
	if is_instance_valid(boss_hud_container):
		var hud_tw := create_tween().bind_node(boss_hud_container)
		hud_tw.tween_interval(3.5)
		hud_tw.tween_property(boss_hud_container, "modulate:a", 0.0, 1.2)
		hud_tw.chain().tween_callback(func():
			if is_instance_valid(boss_hud_container):
				boss_hud_container.visible = false
		)


func _scatter_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 746302
	for i in range(HUBS.size()):
		var hub:Vector3 = HUBS[i]
		var half := 10.0 if i == 0 or i == HUBS.size() - 1 else 8.0
		for j in range(18):
			var side := -1.0 if j % 2 == 0 else 1.0
			var x := side * rng.randf_range(half - 2.6, half - 0.9)
			var position := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			var name := "tree" if j % 5 == 0 else "tree-pine-small" if j % 5 == 1 else "flowers" if j % 5 == 2 else "rocks" if j % 5 == 3 else "mushrooms"
			var size := rng.randf_range(1.3, 2.8) if name.begins_with("tree") else rng.randf_range(0.8, 1.9)
			_asset(name, position, size, rng.randf_range(0.0, TAU))
		for j in range(6):
			var x := rng.randf_range(-half + 3.0, half - 3.0)
			var position := hub + Vector3(x, 0.18, rng.randf_range(-6.0, 6.0))
			_asset("grass" if j % 2 == 0 else "flowers-tall", position, rng.randf_range(0.8, 1.5))
		for j in range(2):
			var side := -1.0 if j == 0 else 1.0
			_asset("crate" if j == 0 else "barrel", hub + Vector3(side * (half - 2.2), 0.18, -4.0 + float(j) * 7.0), 1.6, float(j))
	var sign := _asset("sign", HUBS[0] + Vector3(3.6, 0.15, -2.0), 2.8)
	var sign_back := MeshInstance3D.new()
	var sign_back_mesh := BoxMesh.new()
	sign_back_mesh.size = Vector3(4.75, 1.05, 0.16)
	sign_back.mesh = sign_back_mesh
	sign_back.material_override = materials["gold"]
	sign_back.position = sign.position + Vector3(0.0, 1.58, 0.18)
	geometry.add_child(sign_back)
	var sign_face := MeshInstance3D.new()
	var sign_face_mesh := BoxMesh.new()
	sign_face_mesh.size = Vector3(4.55, 0.86, 0.18)
	sign_face.mesh = sign_face_mesh
	sign_face.material_override = materials["wood"]
	sign_face.position = sign_back.position + Vector3(0.0, 0.0, 0.03)
	geometry.add_child(sign_face)
	var sign_text := Label3D.new()
	sign_text.text = tr("PLATFORM_START_SIGN")
	sign_text.font_size = 48
	sign_text.pixel_size = 0.0062
	sign_text.outline_size = 4
	sign_text.modulate = Color("fff3d0")
	sign_text.outline_modulate = Color("4e2c34")
	sign_text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign_text.double_sided = true
	sign_text.position = sign_face.position + Vector3(0.0, 0.0, 0.12)
	geometry.add_child(sign_text)

func _spawn_enemies() -> void:
	for i in range(HUBS.size()):
		for j in range(3 if i == 0 else 4):
			var enemy := Area3D.new()
			enemy.set_script(ENEMY_SCRIPT)
			enemy.name = "Inimigo_%d_%d" % [i, j]
			enemies.add_child(enemy)
			var x := -5.0 + float(j % 2) * 10.0
			var z := -4.0 + float(j / 2) * 7.0
			enemy.position = HUBS[i] + Vector3(x, 0.2, z)
			enemy.setup((i + j) % 4, maycon, self, (i + j) % 4)

func _spawn_mini_secos() -> void:
	var seco_idx := 0
	# 1. Spawn on elevated balconies and overlooks (reaching places standard enemies cannot)
	for hub_index in range(1, HUBS.size() - 1):
		var hub:Vector3 = HUBS[hub_index]
		var side := -1.0 if hub.x < 0.0 else 1.0
		var balcony := hub + Vector3(side * 11.0, 4.3, -4.0)
		var seco_balcony := Area3D.new()
		seco_balcony.set_script(MINI_SECO_SCRIPT)
		seco_balcony.name = "MiniSeco_Balcony_%d" % hub_index
		enemies.add_child(seco_balcony)
		seco_balcony.position = balcony
		seco_balcony.setup(seco_idx % 3, maycon, self)
		seco_idx += 1
		
		# Also spawn on step overlooks
		if hub_index % 2 == 1:
			var overlook := hub + Vector3(side * 17.2, 3.6, -7.3)
			var seco_overlook := Area3D.new()
			seco_overlook.set_script(MINI_SECO_SCRIPT)
			seco_overlook.name = "MiniSeco_Overlook_%d" % hub_index
			enemies.add_child(seco_overlook)
			seco_overlook.position = overlook
			seco_overlook.setup(seco_idx % 3, maycon, self)
			seco_idx += 1

	# 2. Spawn on key intermediate hubs (hubs 2, 4, 6, 8, 10, 12)
	for hub_index in [2, 4, 6, 8, 10, 12]:
		var hub:Vector3 = HUBS[hub_index]
		var seco_hub := Area3D.new()
		seco_hub.set_script(MINI_SECO_SCRIPT)
		seco_hub.name = "MiniSeco_Hub_%d" % hub_index
		enemies.add_child(seco_hub)
		seco_hub.position = hub + Vector3(-3.5 if hub_index % 4 == 0 else 3.5, 0.3, 2.0)
		seco_hub.setup(seco_idx % 3, maycon, self)
		seco_idx += 1

func _spawn_lips() -> void:
	lips_enemy = Node3D.new()
	lips_enemy.set_script(LIPS_SCRIPT)
	lips_enemy.name = "LipsGargaroker"
	enemies.add_child(lips_enemy)
	lips_enemy.setup(self, maycon, 4)

func _spawn_pentagrams() -> void:
	for i in range(1, HUBS.size()):
		_spawn_pentagram("hub_%d" % i, HUBS[i] + Vector3.UP * 1.45)
	for i in range(ROUTES.size()):
		var route:Vector2i = ROUTES[i]
		var steps := ceili(HUBS[route.x].distance_to(HUBS[route.y]) / 4.2)
		var middle_step := floori(float(steps) * 0.5) + (1 if i in BLADE_ROUTE_IDS else 0)
		var middle:Vector3 = HUBS[route.x].lerp(HUBS[route.y], float(middle_step) / float(steps))
		_spawn_pentagram("route_%d" % i, middle + Vector3.UP * 1.45)
	for i in range(1, HUBS.size() - 1):
		var hub:Vector3 = HUBS[i]
		var side := -1.0 if hub.x < 0.0 else 1.0
		_spawn_pentagram("high_%d" % i, hub + Vector3(side * 11.0, 5.55, -4.0))

func _spawn_pentagram(id:String, position:Vector3) -> void:
	pentagram_spawners[id] = {"pos": position, "timer": 0.0, "active": true}
	var item := Node3D.new()
	item.name = "Pentagrama_" + id
	item.position = position
	var sprite := Sprite3D.new()
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.pixel_size = 0.0031
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	item.add_child(sprite)
	geometry.add_child(item)
	pentagram_nodes[id] = item

func _respawn_pentagram(id:String, position:Vector3) -> void:
	if pentagram_nodes.has(id) and is_instance_valid(pentagram_nodes[id]):
		return
	var item := Node3D.new()
	item.name = "Pentagrama_" + id
	item.position = position
	item.scale = Vector3.ZERO
	var sprite := Sprite3D.new()
	sprite.texture = PENTAGRAM_TEXTURE
	sprite.pixel_size = 0.0031
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	item.add_child(sprite)
	geometry.add_child(item)
	pentagram_nodes[id] = item
	
	_spawn_color_burst(position, false)
	var tween := create_tween().bind_node(item)
	tween.tween_property(item, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_blue_particles() -> void:
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(7.0, 2.0, 112.0)
	particle_material.direction = Vector3.DOWN
	particle_material.spread = 16.0
	particle_material.initial_velocity_min = 4.0
	particle_material.initial_velocity_max = 7.0
	particle_material.gravity = Vector3(0.0, -2.8, 0.0)
	particle_material.color = Color(0.28, 0.72, 1.0, 0.75)
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	trail_material.albedo_color = Color(0.37, 0.76, 1.0, 0.7)
	var trail_mesh := QuadMesh.new()
	trail_mesh.size = Vector2(0.08, 0.45)
	trail_mesh.material = trail_material
	for x in [-59.0, 0.0, 59.0]:
		var particles := GPUParticles3D.new()
		particles.name = "ChuvaAzulDoCenario"
		particles.position = Vector3(x, 13.0, -82.0)
		particles.amount = 260
		particles.lifetime = 5.0
		particles.process_material = particle_material
		particles.draw_pass_1 = trail_mesh
		particles.local_coords = false
		particles.emitting = true
		add_child(particles)
	for hub_index in [0, 3, 4, 7, 8, 11, 12]:
		var hub:Vector3 = HUBS[hub_index]
		for side in [-1.0, 1.0]:
			var edge_material:ParticleProcessMaterial = particle_material.duplicate()
			edge_material.emission_box_extents = Vector3(1.5, 1.0, 8.0)
			var edge_particles := GPUParticles3D.new()
			edge_particles.name = "CascataAzulNaBorda"
			edge_particles.position = hub + Vector3(side * 12.5, 11.0, 0.0)
			edge_particles.amount = 90
			edge_particles.lifetime = 4.2
			edge_particles.process_material = edge_material
			edge_particles.draw_pass_1 = trail_mesh
			edge_particles.local_coords = false
			edge_particles.emitting = true
			add_child(edge_particles)

func has_ground_at(point:Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.5, point - Vector3.UP * 3.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func enemy_defeated(enemy:Area3D) -> void:
	var at:Vector3 = enemy.global_position
	var explosion_audio := AudioStreamPlayer3D.new()
	explosion_audio.stream = ENEMY_EXPLOSION_SOUND
	explosion_audio.unit_size = 14.0
	explosion_audio.max_distance = 50.0
	explosion_audio.volume_db = 0.0
	effects.add_child(explosion_audio)
	explosion_audio.global_position = at
	explosion_audio.finished.connect(explosion_audio.queue_free)
	explosion_audio.play()
	_spawn_enemy_death_blood(at)
	_spawn_color_burst(at + Vector3.UP * 0.8, false)
	if randf() < 0.35:
		var drop := _asset("heart", at + Vector3.UP * 1.1, 1.0)
		blood_pickups.append(drop)
	enemy.queue_free()

func _spawn_enemy_death_blood(at:Vector3) -> void:
	# Floor stains and primary burst (floor stains count unchanged)
	_spawn_blood(at, true)
	# Additional intense radial blood sprays in all directions
	for i in range(5):
		var blood := BLOOD_SCENE.instantiate()
		var y_off := randf_range(0.3, 1.0)
		blood.position = at + Vector3(randf_range(-0.25, 0.25), y_off, randf_range(-0.25, 0.25))
		blood.rotation.y = float(i) * (TAU / 5.0) + randf_range(-0.25, 0.25)
		blood.rotation.x = randf_range(-0.35, 0.35)
		var particles := blood.get_node_or_null("GPUParticles3D") as GPUParticles3D
		if particles:
			particles.amount = 220
			particles.explosiveness = 0.98
		effects.add_child(blood)
		get_tree().create_timer(2.2).timeout.connect(blood.queue_free)

func _setup_audio_buses() -> void:
	var bus_idx := AudioServer.get_bus_index("ItemReverb")
	if bus_idx == -1:
		bus_idx = AudioServer.bus_count
		AudioServer.add_bus(bus_idx)
		AudioServer.set_bus_name(bus_idx, "ItemReverb")
		AudioServer.set_bus_send(bus_idx, "Master")
		AudioServer.set_bus_volume_db(bus_idx, -5.0)
		
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.88
		reverb.damping = 0.22
		reverb.spread = 1.0
		reverb.wet = 0.90
		reverb.dry = 0.30
		reverb.hipass = 0.05
		reverb.predelay_msec = 20.0
		AudioServer.add_bus_effect(bus_idx, reverb)
		
		var delay := AudioEffectDelay.new()
		delay.dry = 0.40
		delay.tap1_active = true
		delay.tap1_delay_ms = 130.0
		delay.tap1_level_db = -4.0
		delay.tap2_active = true
		delay.tap2_delay_ms = 260.0
		delay.tap2_level_db = -8.0
		delay.feedback_active = true
		delay.feedback_delay_ms = 180.0
		delay.feedback_level_db = -7.0
		delay.feedback_lowpass = 14000.0
		AudioServer.add_bus_effect(bus_idx, delay)

func _play_pickup_sound(pentagram:bool) -> void:
	var base_pitch := 1.25 if pentagram else 0.92
	var orig_vol := -10.0 if pentagram else -12.5
	
	# 1. Som original nítido e suave tocando por cima (foreground)
	var orig_sfx := AudioStreamPlayer.new()
	orig_sfx.stream = PICKUP_SOUND
	orig_sfx.pitch_scale = base_pitch
	orig_sfx.volume_db = orig_vol
	add_child(orig_sfx)
	orig_sfx.finished.connect(orig_sfx.queue_free)
	orig_sfx.play()

	# 2. Som com eco e reverb tocando por trás em volume ainda mais baixo (background ambient tail)
	var bg_vol := orig_vol - 8.5
	var bg_sfx := AudioStreamPlayer.new()
	bg_sfx.stream = PICKUP_SOUND
	bg_sfx.bus = "ItemReverb"
	bg_sfx.pitch_scale = base_pitch
	bg_sfx.volume_db = bg_vol
	add_child(bg_sfx)
	bg_sfx.finished.connect(bg_sfx.queue_free)
	bg_sfx.play()

	# Ecos em cascata mais baixos por trás
	var echo_delays := [0.13, 0.26, 0.39, 0.54]
	var echo_vols := [-5.0, -9.0, -13.0, -17.0]
	var echo_pitches := [1.02, 1.05, 1.08, 1.11]
	for idx in range(echo_delays.size()):
		var delay_time:float = echo_delays[idx]
		var echo_vol:float = bg_vol + echo_vols[idx]
		var echo_pitch:float = base_pitch * echo_pitches[idx]
		get_tree().create_timer(delay_time).timeout.connect(func():
			if not is_instance_valid(self):
				return
			var echo_sfx := AudioStreamPlayer.new()
			echo_sfx.stream = PICKUP_SOUND
			echo_sfx.bus = "ItemReverb"
			echo_sfx.pitch_scale = echo_pitch
			echo_sfx.volume_db = echo_vol
			add_child(echo_sfx)
			echo_sfx.finished.connect(echo_sfx.queue_free)
			echo_sfx.play()
		)

func enemy_stomped(enemy:Area3D) -> void:
	enemy_defeated(enemy)
	total_stomps += 1

func _unhandled_input(event:InputEvent) -> void:
	if special_ready and not is_invincible and not death_in_progress and not exit_started:
		var pressed_y := false
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y and event.pressed:
			pressed_y = true
		elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_Y or event.keycode == KEY_Y or event.physical_keycode == KEY_Q or event.keycode == KEY_Q):
			pressed_y = true
		elif event.is_action_pressed("key_q"):
			pressed_y = true
		if pressed_y:
			activate_special()
			get_viewport().set_input_as_handled()

func _check_invincibility_milestone() -> void:
	var total := Global.platform_pentagrams
	var milestone := total / 10
	if (total >= 10 and milestone > last_invincible_milestone) or (pentagrams_collected_session > 0 and pentagrams_collected_session % 10 == 0):
		last_invincible_milestone = maxi(last_invincible_milestone, milestone)
		set_special_ready(true)

func set_special_ready(ready_val:bool) -> void:
	special_ready = ready_val
	if is_instance_valid(invincible_overlay) and invincible_overlay.has_method("set_special_prompt_visible"):
		invincible_overlay.set_special_prompt_visible(ready_val)
	if ready_val:
		var ready_sfx := AudioStreamPlayer.new()
		ready_sfx.stream = FREEZE_SOUND
		ready_sfx.volume_db = -3.0
		add_child(ready_sfx)
		ready_sfx.finished.connect(ready_sfx.queue_free)
		ready_sfx.play()

func activate_special() -> void:
	if not special_ready or is_invincible or death_in_progress or exit_started:
		return
	set_special_ready(false)
	Global.platform_pentagrams = 0
	last_invincible_milestone = 0
	pentagrams_collected_session = 0
	update_hud()
	Global.save_progress("fase_3d_platform")
	start_invincibility(10.0)

func start_invincibility(duration:float = 10.0) -> void:
	is_invincible = true
	is_slow_motion = true
	invincibility_time_left = duration

	# Acelera bastante a música durante o poder (sem tocar sons adicionais)
	GameSongs.set_song_pitch(1.55)

	if is_instance_valid(maycon):
		maycon.set_invincible(true, duration)

	for enemy in enemies.get_children():
		if is_instance_valid(enemy) and enemy.has_method("set_slow_motion"):
			enemy.set_slow_motion(true)

	for hazard in hazards.get_children():
		if is_instance_valid(hazard) and hazard.has_method("set_slow_motion"):
			hazard.set_slow_motion(true)

	if is_instance_valid(invincible_overlay) and invincible_overlay.has_method("start_invincibility"):
		invincible_overlay.start_invincibility(duration)

	if is_instance_valid(lips_enemy) and lips_enemy.has_method("reset_power_hits"):
		lips_enemy.reset_power_hits()

func end_invincibility() -> void:
	is_invincible = false
	is_slow_motion = false
	invincibility_time_left = 0.0

	GameSongs.set_song_pitch(1.0)

	if is_instance_valid(maycon):
		maycon.set_invincible(false, 0.0)

	for enemy in enemies.get_children():
		if is_instance_valid(enemy) and enemy.has_method("set_slow_motion"):
			enemy.set_slow_motion(false)

	for hazard in hazards.get_children():
		if is_instance_valid(hazard) and hazard.has_method("set_slow_motion"):
			hazard.set_slow_motion(false)

	if is_instance_valid(invincible_overlay) and invincible_overlay.has_method("stop_invincibility"):
		invincible_overlay.stop_invincibility()

	if is_instance_valid(lips_enemy) and lips_enemy.has_method("reset_power_hits"):
		lips_enemy.reset_power_hits()

func spawn_enemy_trail(at:Vector3, archetype:int) -> void:
	var mark := MeshInstance3D.new()
	mark.mesh = enemy_trail_mesh
	mark.material_override = trail_materials[archetype % trail_materials.size()]
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.position = at + Vector3(0.0, 0.018, 0.0)
	mark.rotation.y = randf_range(0.0, TAU)
	effects.add_child(mark)
	var tween := create_tween().bind_node(mark)
	tween.tween_property(mark, "scale", Vector3.ZERO, 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(mark.queue_free)

func _spawn_blood(at:Vector3, leave_stain:bool) -> void:
	var blood := BLOOD_SCENE.instantiate()
	blood.position = at
	effects.add_child(blood)
	get_tree().create_timer(2.0).timeout.connect(blood.queue_free)
	if not leave_stain:
		return
	var space := get_world_3d().direct_space_state
	var ground_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 12.0, 1)
	var ground_hit := space.intersect_ray(ground_query)
	if ground_hit.is_empty():
		return
	var ground_y:float = ground_hit.position.y
	for i in range(12):
		var angle := float(i) * 2.39996
		var distance := 0.2 + float(i % 4) * 0.35
		var stain := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.18 + float(i % 3) * 0.1
		mesh.height = 0.02
		stain.mesh = mesh
		stain.material_override = materials["blood"]
		stain.position = Vector3(at.x + cos(angle) * distance, ground_y + 0.02 + float(i) * 0.0005, at.z + sin(angle) * distance)
		effects.add_child(stain)
		blood_stains.append(stain)
		if blood_stains.size() > 260:
			blood_stains.pop_front().queue_free()

func spawn_latched_blood(at:Vector3) -> void:
	var blood := BLOOD_SCENE.instantiate()
	blood.position = at
	effects.add_child(blood)
	get_tree().create_timer(1.8).timeout.connect(blood.queue_free)
	var space := get_world_3d().direct_space_state
	var ground_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at - Vector3.UP * 12.0, 1)
	var ground_hit := space.intersect_ray(ground_query)
	if ground_hit.is_empty():
		return
	var ground_y:float = ground_hit.position.y
	for i in range(2):
		var angle := randf() * TAU
		var distance := randf_range(0.08, 0.55)
		var stain := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = randf_range(0.12, 0.22)
		mesh.height = 0.02
		stain.mesh = mesh
		stain.material_override = materials["blood"]
		stain.position = Vector3(at.x + cos(angle) * distance, ground_y + 0.02 + float(randi() % 6) * 0.0008, at.z + sin(angle) * distance)
		effects.add_child(stain)
		blood_stains.append(stain)
		if blood_stains.size() > 260:
			blood_stains.pop_front().queue_free()

func _spawn_color_burst(at:Vector3, pickup:bool) -> void:
	var colors := [Color("ffda60"), Color("ff6fb1"), Color("71d3ff"), Color("a985ff"), Color("8ee899"), Color("ff9369")]
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.095
	spark_mesh.height = 0.19
	spark_mesh.radial_segments = 8
	spark_mesh.rings = 4
	var spark_materials:Array[StandardMaterial3D] = []
	for color in colors:
		var material := _material(color, 0.24)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_materials.append(material)
	for i in range(36 if pickup else 56):
		var spark := MeshInstance3D.new()
		spark.mesh = spark_mesh
		spark.material_override = spark_materials[i % spark_materials.size()]
		spark.position = at
		spark.scale = Vector3.ONE * randf_range(0.8, 1.7)
		effects.add_child(spark)
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(0.25, 1.1), randf_range(-1.0, 1.0)).normalized()
		var distance := randf_range(1.1, 2.5) if pickup else randf_range(1.2, 3.2)
		var tween := create_tween().bind_node(spark).set_parallel(true)
		tween.tween_property(spark, "position", at + direction * distance, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(spark.queue_free)
	if pickup:
		var flash := Sprite3D.new()
		flash.texture = PENTAGRAM_TEXTURE
		flash.pixel_size = 0.0031
		flash.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		flash.shaded = false
		flash.double_sided = true
		flash.position = at
		effects.add_child(flash)
		var flash_tween := create_tween().bind_node(flash).set_parallel(true)
		flash_tween.tween_property(flash, "scale", Vector3.ONE * 2.1, 0.48)
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.48)
		flash_tween.chain().tween_callback(flash.queue_free)

func player_hit(at:Vector3) -> void:
	if is_instance_valid(damage_punch_audio):
		damage_punch_audio.pitch_scale = randf_range(0.95, 1.05)
		damage_punch_audio.play()
	var ground_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at - Vector3.UP * 3.0, 1)
	var ground := get_world_3d().direct_space_state.intersect_ray(ground_query)
	_spawn_blood(ground.position if not ground.is_empty() else at, not ground.is_empty())
	blood_overlay.call("flash")

func _flash_heal() -> void:
	heal_flash.modulate.a = 1.0
	if heal_tween and heal_tween.is_valid():
		heal_tween.kill()
	heal_tween = create_tween().bind_node(heal_flash)
	heal_tween.tween_property(heal_flash, "modulate:a", 0.0, 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func respawn(reset_health:bool) -> void:
	maycon.global_position = Vector3(0.0, 1.4, 32.0)
	maycon.velocity = Vector3.ZERO
	maycon.preparing_jump = false
	maycon.jump_windup = 0.0
	maycon.takeoff_stretch = 0.0
	maycon.jumps = 0
	maycon.visual.scale = Vector3.ONE
	maycon.visual.position.y = 0.0
	maycon.hurt_time = 2.0
	maycon.camera.global_position = Vector3(0.0, 7.0, 43.0)
	maycon.current_camera_distance = 11.0
	maycon.death_hazard = ""
	maycon.death_hazard_node = null
	if is_instance_valid(lips_enemy) and lips_enemy.has_method("reset_position"):
		lips_enemy.reset_position(4)
	if reset_health:
		set_stage_hp(stage_hp_max)
	else:
		set_stage_hp(maxf(15.0, stage_hp - 8.0))
	update_hud()

func set_stage_hp(value:float) -> void:
	stage_hp = clampf(value, 0.0, stage_hp_max)
	if use_realtime_hp:
		Global.realtime_hp = stage_hp

func start_player_death(kind:String, hazard:Node3D = null) -> void:
	if death_in_progress or exit_started:
		return
	if is_invincible:
		end_invincibility()
	death_in_progress = true
	maycon.control_enabled = false
	var old_collision_layer := maycon.collision_layer
	var old_collision_mask := maycon.collision_mask
	var is_hazard_death := (kind == "blade" or kind == "hand")
	if is_hazard_death:
		maycon.dying = true
		maycon.death_hazard = kind
		maycon.death_hazard_node = hazard
		maycon.velocity = Vector3.ZERO
		maycon.collision_layer = 0
		maycon.collision_mask = 0
		set_stage_hp(0.0)
		update_hud()
		maycon.camera_shake = 0.35
		if kind == "blade":
			var rotor:Node3D = hazard.get("rotor")
			maycon.reparent(rotor, true)
			maycon.position = Vector3(0.9, -0.45, 0.0)
			maycon.rotation = Vector3(0.0, 0.0, 0.65)
		else:
			hazard.call("begin_crush")
			var palm:Node3D = hazard.get("palm")
			maycon.reparent(palm, true)
			maycon.position = Vector3(0.0, -0.34, -0.25)
			maycon.rotation = Vector3.ZERO
			maycon.visual.scale = Vector3(1.32, 0.48, 1.32)
	scream_audio.volume_db = -2.0
	scream_audio.play()
	var fade_delay := 2.6 if is_hazard_death else 0.55
	var fade_duration := 2.0 if is_hazard_death else 2.65
	var fade := create_tween().bind_node(fade_rect)
	fade.tween_interval(fade_delay)
	fade.tween_property(fade_rect, "modulate:a", 1.0, fade_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var scream_fade := create_tween().bind_node(scream_audio)
	scream_fade.tween_interval(fade_delay)
	scream_fade.tween_property(scream_audio, "volume_db", -48.0, fade_duration)
	if is_hazard_death:
		for i in range(24):
			var at := maycon.global_position + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.7), randf_range(-0.5, 0.5))
			if kind == "hand" and i % 2 == 0:
				_spawn_blood(hazard.global_position + Vector3(randf_range(-0.8, 0.8), 0.18, randf_range(-0.8, 0.8)), true)
			else:
				_spawn_blood(at, false)
			if kind == "hand" and i % 2 == 0:
				maycon.camera_shake = 0.20
			elif kind == "blade":
				maycon.camera_shake = 0.14
			if i % 3 == 0:
				blood_overlay.call("flash")
			await get_tree().create_timer(0.2).timeout
	else:
		await get_tree().create_timer(3.2).timeout
	if fade.is_running():
		await fade.finished
	if maycon.get_parent() != self:
		maycon.reparent(self, true)
	maycon.rotation = Vector3.ZERO
	maycon.collision_layer = old_collision_layer
	maycon.collision_mask = old_collision_mask
	if kind == "hand" and is_instance_valid(hazard):
		hazard.call("reset_after_death")
	respawn(kind != "fall")
	maycon.dying = false
	maycon.death_hazard = ""
	maycon.death_hazard_node = null
	maycon.call("_play_animation", "Walking")
	scream_audio.stop()
	var fade_in := create_tween().bind_node(fade_rect)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished
	death_in_progress = false
	maycon.control_enabled = true

func _exit_stage() -> void:
	if is_invincible:
		end_invincibility()
	exit_started = true
	get_tree().paused = false
	maycon.control_enabled = false
	await _fade_out()
	Global.platform_arrival_pending = true
	Global.save_progress("fase_4")
	get_tree().change_scene_to_file.call_deferred("res://scenes/fase_1_before_castle_4.tscn")

func exit_to_menu() -> void:
	if exit_started:
		return
	if is_invincible:
		end_invincibility()
	exit_started = true
	get_tree().paused = false
	maycon.control_enabled = false
	await _fade_out()
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	Global.save_progress("fase_3d_platform")
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu.tscn")

func _fade_out() -> void:
	var tween := create_tween().bind_node(fade_rect)
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TransicaoDaFase"
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.WHITE
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade_rect)
	maycon.control_enabled = false
	var tween := create_tween().bind_node(fade_rect)
	tween.tween_property(fade_rect, "modulate:a", 0.0, 1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_fade_in)

func _finish_fade_in() -> void:
	if not intro_active and not exit_started and is_instance_valid(maycon):
		if maycon.get("landing_recovery_time") == null or maycon.landing_recovery_time <= 0.0:
			maycon.control_enabled = true

func _start_intro() -> void:
	intro_active = true
	intro_time = 0.0
	if is_instance_valid(maycon):
		maycon.intro_mode = true
		maycon.control_enabled = false
		maycon.global_position = INTRO_P0
		maycon.velocity = Vector3.ZERO
		if is_instance_valid(maycon.visual):
			maycon.visual.rotation.x = -0.32
			maycon.visual.rotation.y = PI
			maycon.visual.rotation.z = 0.0
		maycon._play_animation("Air_Flail")
		if is_instance_valid(maycon.animation_player):
			maycon.animation_player.speed_scale = 0.65
		if is_instance_valid(maycon.camera):
			var focus := INTRO_P0 + Vector3(0.0, 1.35, 0.0)
			maycon.camera.global_position = focus + Vector3(0.0, 4.2, 11.0)
			maycon.camera.look_at(focus, Vector3.UP)

func _process_intro(delta: float) -> void:
	intro_time += delta
	var t := clampf(intro_time / INTRO_DURATION, 0.0, 1.0)
	var pos := _bezier_3d(INTRO_P0, INTRO_P1, INTRO_P2, INTRO_P3, t)
	
	if is_instance_valid(maycon):
		maycon.global_position = pos
		maycon.velocity = Vector3.ZERO
		maycon._play_animation("Air_Flail")
		if is_instance_valid(maycon.animation_player):
			maycon.animation_player.speed_scale = 0.65
		if is_instance_valid(maycon.visual):
			maycon.visual.rotation.y = PI
			var target_pitch := -0.32 if t < 0.52 else 0.28
			maycon.visual.rotation.x = lerpf(maycon.visual.rotation.x, target_pitch, minf(delta * 9.0, 1.0))
			maycon.visual.rotation.z = sin(intro_time * 5.5) * 0.07
		
		if is_instance_valid(maycon.camera):
			var focus := pos + Vector3(0.0, 1.35, 0.0)
			var desired_cam := focus + Vector3(0.0, 4.2, 11.0)
			maycon.camera.global_position = maycon.camera.global_position.lerp(desired_cam, minf(delta * 9.0, 1.0))
			maycon.camera.look_at(focus, Vector3.UP)
	
	if t >= 1.0:
		_finish_intro()

func _finish_intro() -> void:
	intro_active = false
	if is_instance_valid(maycon):
		maycon.global_position = INTRO_P3
		maycon.velocity = Vector3.ZERO
		maycon.intro_mode = false
		if is_instance_valid(maycon.visual):
			maycon.visual.rotation.x = 0.0
			maycon.visual.rotation.z = 0.0
			maycon.visual.rotation.y = PI
		maycon._play_animation("Walking")
		maycon.camera_shake = 0.65
		if maycon.has_method("start_landing_cooldown"):
			maycon.start_landing_cooldown(4.4)
		else:
			maycon.control_enabled = false
	
	if is_instance_valid(landing_audio):
		landing_audio.pitch_scale = randf_range(0.96, 1.04)
		landing_audio.play()
	
	_spawn_landing_dust(INTRO_P3)
	_show_super_maycon_brother_banner()

func _show_super_maycon_brother_banner() -> void:
	var title_layer := CanvasLayer.new()
	title_layer.name = "SuperMayconTitleLayer"
	title_layer.layer = 35
	title_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(title_layer)
	
	var root_ctrl := Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(root_ctrl)
	
	var title_box := Control.new()
	title_box.set_anchors_preset(Control.PRESET_CENTER)
	title_box.custom_minimum_size = Vector2(980.0, 160.0)
	title_box.size = Vector2(980.0, 160.0)
	title_box.pivot_offset = Vector2(490.0, 80.0)
	title_box.position = -title_box.pivot_offset
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(title_box)
	
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_CENTER)
	glow.size = Vector2(850.0, 130.0)
	glow.position = -glow.size * 0.5 + Vector2(490.0, 80.0)
	glow.color = Color(1.0, 0.90, 0.45, 0.22)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_child(glow)
	
	var label := RichTextLabel.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	label.add_theme_font_override("normal_font", FONT_CONTRAST)
	label.add_theme_font_size_override("normal_font_size", 68)
	label.add_theme_constant_override("outline_size", 16)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.06, 0.10, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 6)
	label.add_theme_constant_override("shadow_offset_y", 8)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	
	var title_text := tr("PLATFORM_TITLE_SUPER_MAYCON")
	var rainbow_colors := [
		"#FF2D55", "#FF9500", "#FFCC00", "#34C759", "#00B0FF",
		"#AF52DE", "#FF3B30", "#FFD60A", "#30D158", "#00C7BE",
		"#BF5AF2", "#FF2D55", "#FF9500", "#FFCC00", "#34C759",
		"#00B0FF", "#AF52DE", "#FF3B30", "#FFD60A", "#30D158"
	]
	var bbcode := "[center][wave amp=28.0 freq=4.0]"
	var color_idx := 0
	for char in title_text:
		if char == " ":
			bbcode += "  "
		else:
			var col: String = rainbow_colors[color_idx % rainbow_colors.size()]
			bbcode += "[color=" + col + "]" + char + "[/color]"
			color_idx += 1
	bbcode += "[/wave][/center]"
	label.text = bbcode
	title_box.add_child(label)
	
	var punch_audio := AudioStreamPlayer.new()
	punch_audio.stream = PUNCH_IMPACT_SOUND
	punch_audio.volume_db = 4.0
	add_child(punch_audio)
	
	title_box.scale = Vector2(3.2, 3.2)
	title_box.modulate.a = 0.0
	
	var tw := create_tween().bind_node(title_box)
	tw.set_parallel(true)
	tw.tween_property(title_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_box, "modulate:a", 1.0, 0.12)
	tw.chain().tween_callback(func():
		punch_audio.play()
		if is_instance_valid(maycon) and "camera_shake" in maycon:
			maycon.camera_shake = 0.6
		var viewport_center := root_ctrl.get_viewport_rect().size * 0.5
		_spawn_purpurina(root_ctrl, viewport_center)
	)
	
	# Momento com a frase na tela demorando bem mais (3.8s)
	tw.chain().tween_interval(3.8)
	tw.chain().tween_property(title_box, "scale", Vector2(1.18, 1.18), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(title_box, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func():
		title_layer.queue_free()
		punch_audio.queue_free()
		if is_instance_valid(maycon) and not exit_started and not death_in_progress:
			maycon.control_enabled = true
	)

func _spawn_purpurina(parent: Control, center: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	
	var glitter_colors := [
		Color("ffd700"), Color("fff066"), Color("ffffff"), Color("ff5fa2"),
		Color("00e5ff"), Color("b388ff"), Color("76ff03"), Color("ff9100"),
		Color("ff4081"), Color("ffff00"), Color("e040fb"), Color("64ffda")
	]
	
	# 1. Grande explosão radial de purpurina (70 fragmentos cintilantes)
	var count := 70
	for i in range(count):
		var star := Polygon2D.new()
		var r := randf_range(7.0, 16.0)
		var star_points := PackedVector2Array([
			Vector2(0, -r),
			Vector2(r * 0.32, -r * 0.32),
			Vector2(r, 0),
			Vector2(r * 0.32, r * 0.32),
			Vector2(0, r),
			Vector2(-r * 0.32, r * 0.32),
			Vector2(-r, 0),
			Vector2(-r * 0.32, -r * 0.32)
		])
		star.polygon = star_points
		star.color = glitter_colors[i % glitter_colors.size()]
		star.position = center + Vector2(randf_range(-160.0, 160.0), randf_range(-30.0, 30.0))
		star.scale = Vector2.ONE * randf_range(0.4, 0.8)
		parent.add_child(star)
		
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(180.0, 560.0)
		var target_pos := center + Vector2(cos(angle) * dist * 1.5, sin(angle) * dist)
		var duration := randf_range(1.6, 2.5)
		
		var tw := create_tween().bind_node(star).set_parallel(true)
		tw.tween_property(star, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(star, "rotation", randf_range(-14.0, 14.0), duration)
		tw.tween_property(star, "scale", Vector2.ONE * randf_range(1.1, 1.8), duration * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(star, "scale", Vector2.ZERO, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(star, "modulate:a", 0.0, duration * 0.6)
		tw.chain().tween_callback(star.queue_free)
	
	# 2. Purpurina flutuante contínua cintilando ao longo de toda a exibição (65 sparkles)
	for i in range(65):
		var sparkle := Polygon2D.new()
		var r := randf_range(5.0, 12.0)
		sparkle.polygon = PackedVector2Array([
			Vector2(0, -r), Vector2(r * 0.28, 0), Vector2(0, r), Vector2(-r * 0.28, 0)
		])
		sparkle.color = glitter_colors[randi() % glitter_colors.size()]
		var offset := Vector2(randf_range(-460.0, 460.0), randf_range(-80.0, 80.0))
		sparkle.position = center + offset
		sparkle.scale = Vector2.ZERO
		parent.add_child(sparkle)
		
		var delay := randf_range(0.05, 3.2)
		var float_dur := randf_range(1.0, 1.6)
		var float_tw := create_tween().bind_node(sparkle)
		float_tw.tween_interval(delay)
		float_tw.tween_property(sparkle, "scale", Vector2.ONE * randf_range(0.9, 1.6), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		float_tw.parallel().tween_property(sparkle, "rotation", randf_range(-4.5, 4.5), float_dur)
		float_tw.parallel().tween_property(sparkle, "position:y", sparkle.position.y - randf_range(25.0, 75.0), float_dur)
		float_tw.tween_property(sparkle, "scale", Vector2.ZERO, 0.4)
		float_tw.parallel().tween_property(sparkle, "modulate:a", 0.0, 0.4)
		float_tw.chain().tween_callback(sparkle.queue_free)

func _bezier_3d(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	var tt := t * t
	var uu := u * u
	var uuu := uu * u
	var ttt := tt * t
	return uuu * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + ttt * p3

func _spawn_landing_dust(at: Vector3) -> void:
	if not is_instance_valid(effects):
		return
	
	var puff_count := 18
	for i in range(puff_count):
		var angle := float(i) / float(puff_count) * TAU + randf_range(-0.12, 0.12)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var puff := Sprite3D.new()
		puff.texture = FART_SMOKE
		puff.hframes = 3
		puff.vframes = 2
		puff.frame = randi_range(0, 2)
		puff.pixel_size = randf_range(0.012, 0.018)
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.shaded = false
		puff.transparent = true
		puff.double_sided = true
		puff.position = at + dir * 0.35 + Vector3(0.0, 0.15, 0.0)
		var tone := randf_range(0.82, 0.94)
		puff.modulate = Color(tone, tone * 0.94, tone * 0.82, randf_range(0.80, 0.95))
		puff.scale = Vector3.ONE * 0.4
		effects.add_child(puff)
		
		var target_pos := at + dir * randf_range(2.6, 4.2) + Vector3(0.0, randf_range(0.2, 0.7), 0.0)
		var duration := randf_range(0.65, 0.95)
		var tw := create_tween().bind_node(puff).set_parallel(true)
		tw.tween_property(puff, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * randf_range(1.6, 2.5), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(puff.queue_free)
	
	for i in range(8):
		var center_puff := Sprite3D.new()
		center_puff.texture = FART_SMOKE
		center_puff.hframes = 3
		center_puff.vframes = 2
		center_puff.frame = randi_range(1, 3)
		center_puff.pixel_size = randf_range(0.015, 0.022)
		center_puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		center_puff.shaded = false
		center_puff.transparent = true
		center_puff.double_sided = true
		center_puff.position = at + Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.35), randf_range(-0.4, 0.4))
		var tone := randf_range(0.86, 0.96)
		center_puff.modulate = Color(tone, tone * 0.93, tone * 0.85, randf_range(0.75, 0.90))
		center_puff.scale = Vector3.ONE * 0.5
		effects.add_child(center_puff)
		
		var lift_pos := center_puff.position + Vector3(randf_range(-0.5, 0.5), randf_range(1.2, 2.2), randf_range(-0.5, 0.5))
		var duration := randf_range(0.75, 1.1)
		var center_tw := create_tween().bind_node(center_puff).set_parallel(true)
		center_tw.tween_property(center_puff, "position", lift_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		center_tw.tween_property(center_puff, "scale", Vector3.ONE * randf_range(2.0, 3.2), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		center_tw.tween_property(center_puff, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		center_tw.chain().tween_callback(center_puff.queue_free)
	
	var dust_mesh := BoxMesh.new()
	dust_mesh.size = Vector3(0.12, 0.12, 0.12)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dust_mat.albedo_color = Color("8c6a46")
	
	for i in range(24):
		var particle := MeshInstance3D.new()
		particle.mesh = dust_mesh
		particle.material_override = dust_mat
		particle.position = at + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
		particle.scale = Vector3.ONE * randf_range(0.6, 1.3)
		effects.add_child(particle)
		
		var spread_angle := randf_range(0.0, TAU)
		var spread_dist := randf_range(1.4, 3.2)
		var end_pos := at + Vector3(cos(spread_angle) * spread_dist, randf_range(0.1, 0.3), sin(spread_angle) * spread_dist)
		var peak_y := at.y + randf_range(1.2, 2.5)
		
		var part_tw := create_tween().bind_node(particle)
		part_tw.set_parallel(true)
		part_tw.tween_property(particle, "position:x", end_pos.x, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		part_tw.tween_property(particle, "position:z", end_pos.z, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		part_tw.tween_property(particle, "rotation", Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.65)
		
		var y_tw := create_tween().bind_node(particle)
		y_tw.tween_property(particle, "position:y", peak_y, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		y_tw.tween_property(particle, "position:y", end_pos.y, 0.37).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		part_tw.chain().tween_property(particle, "scale", Vector3.ZERO, 0.15)
		part_tw.chain().tween_callback(particle.queue_free)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var count_panel := HBoxContainer.new()
	count_panel.anchor_left = 1.0
	count_panel.anchor_right = 1.0
	count_panel.offset_left = -135.0
	count_panel.offset_right = -12.0
	count_panel.offset_top = 9.0
	count_panel.offset_bottom = 53.0
	canvas.add_child(count_panel)
	count_panel.add_child(_hud_icon(PENTAGRAM_TEXTURE, Vector2(42.0, 42.0)))
	pentagram_label = Label.new()
	pentagram_label.add_theme_font_size_override("font_size", 28)
	pentagram_label.add_theme_color_override("font_color", Color("d72343"))
	count_panel.add_child(pentagram_label)
	var background := PanelContainer.new()
	background.anchor_top = 1.0
	background.anchor_bottom = 1.0
	background.offset_left = 12.0
	background.offset_right = 348.0
	background.offset_top = -97.0
	background.offset_bottom = -12.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.10, 0.14, 0.8)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(6)
	background.add_theme_stylebox_override("panel", panel_style)
	canvas.add_child(background)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	background.add_child(column)
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 12)
	column.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(310.0, 12.0)
	hp_bar.show_percentage = false
	hp_bar.max_value = stage_hp_max
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("b1223e")
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color("3a1924")
	hp_bar.add_theme_stylebox_override("background", bar_back)
	column.add_child(hp_bar)
	var control_panel := HBoxContainer.new()
	control_panel.add_theme_constant_override("separation", 6)
	column.add_child(control_panel)
	control_panel.add_child(_hud_icon(load("res://assets/novas_imagens/buttons/360_A.png"), Vector2(26.0, 26.0)))
	var jump_label := Label.new()
	jump_label.text = tr("PLATFORM_JUMP_HINT")
	jump_label.add_theme_font_size_override("font_size", 13)
	control_panel.add_child(jump_label)
	control_panel.add_child(_hud_icon(load("res://assets/novas_imagens/buttons/360_X.png"), Vector2(26.0, 26.0)))
	var run_label := Label.new()
	run_label.text = tr("PLATFORM_RUN_HINT")
	run_label.add_theme_font_size_override("font_size", 13)
	control_panel.add_child(run_label)
	control_panel.add_child(_hud_icon(load("res://assets/novas_imagens/buttons/360_Y.png"), Vector2(26.0, 26.0)))
	var special_label := Label.new()
	special_label.text = tr("PLATFORM_SPECIAL_HINT")
	special_label.add_theme_font_size_override("font_size", 13)
	control_panel.add_child(special_label)
	blood_overlay = Control.new()
	blood_overlay.set_script(BLOOD_OVERLAY_SCRIPT)
	canvas.add_child(blood_overlay)
	heal_flash = ColorRect.new()
	heal_flash.color = Color(0.25, 0.73, 1.0, 0.38)
	heal_flash.modulate.a = 0.0
	heal_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heal_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(heal_flash)

	# Boss HP HUD (Top Center)
	boss_hud_container = PanelContainer.new()
	boss_hud_container.name = "BossHUD"
	boss_hud_container.anchor_left = 0.5
	boss_hud_container.anchor_right = 0.5
	boss_hud_container.offset_left = -210.0
	boss_hud_container.offset_right = 210.0
	boss_hud_container.offset_top = 14.0
	boss_hud_container.offset_bottom = 68.0
	boss_hud_container.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var boss_style := StyleBoxFlat.new()
	boss_style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	boss_style.border_color = Color(0.85, 0.72, 0.28, 0.9)
	boss_style.set_border_width_all(2)
	boss_style.set_corner_radius_all(8)
	boss_style.set_content_margin_all(8)
	boss_hud_container.add_theme_stylebox_override("panel", boss_style)
	canvas.add_child(boss_hud_container)

	var boss_vbox := VBoxContainer.new()
	boss_vbox.add_theme_constant_override("separation", 3)
	boss_hud_container.add_child(boss_vbox)

	var boss_top_row := HBoxContainer.new()
	boss_vbox.add_child(boss_top_row)

	boss_name_label = Label.new()
	boss_name_label.text = "★ " + tr("PLATFORM_BOSS_NAME") + " ★"
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 14)
	boss_name_label.add_theme_color_override("font_color", Color("f9ca51"))
	boss_top_row.add_child(boss_name_label)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(400.0, 14.0)
	boss_hp_bar.show_percentage = false
	boss_hp_bar.max_value = 4.0
	boss_hp_bar.value = 4.0
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color("c71a36")
	boss_fill.set_corner_radius_all(3)
	boss_hp_bar.add_theme_stylebox_override("fill", boss_fill)
	var boss_back := StyleBoxFlat.new()
	boss_back.bg_color = Color(0.22, 0.08, 0.12, 0.95)
	boss_back.set_corner_radius_all(3)
	boss_hp_bar.add_theme_stylebox_override("background", boss_back)
	boss_vbox.add_child(boss_hp_bar)

	# Banner de anúncio "CAMINHO LIBERADO!"
	path_open_announcement = Label.new()
	path_open_announcement.name = "PathOpenAnnouncement"
	path_open_announcement.anchor_left = 0.5
	path_open_announcement.anchor_right = 0.5
	path_open_announcement.anchor_top = 0.5
	path_open_announcement.anchor_bottom = 0.5
	path_open_announcement.offset_left = -400.0
	path_open_announcement.offset_right = 400.0
	path_open_announcement.offset_top = -60.0
	path_open_announcement.offset_bottom = 60.0
	path_open_announcement.grow_horizontal = Control.GROW_DIRECTION_BOTH
	path_open_announcement.grow_vertical = Control.GROW_DIRECTION_BOTH
	path_open_announcement.pivot_offset = Vector2(400.0, 60.0)
	path_open_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_open_announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	path_open_announcement.text = tr("PLATFORM_PATH_OPEN")
	path_open_announcement.add_theme_font_size_override("font_size", 28)
	path_open_announcement.add_theme_color_override("font_color", Color("ffd700"))
	path_open_announcement.add_theme_color_override("font_outline_color", Color("1a0a00"))
	path_open_announcement.add_theme_constant_override("outline_size", 8)
	path_open_announcement.visible = false
	canvas.add_child(path_open_announcement)

func _build_pause() -> void:
	var pause := CanvasLayer.new()
	pause.name = "PauseFofo"
	pause.set_script(PAUSE_SCRIPT)
	add_child(pause)

func _hud_icon(texture:Texture2D, size:Vector2) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func update_hud() -> void:
	if not is_instance_valid(hp_bar):
		return
	hp_bar.value = stage_hp
	hp_label.text = tr("UI_HEALTH")
	pentagram_label.text = str(Global.platform_pentagrams)
