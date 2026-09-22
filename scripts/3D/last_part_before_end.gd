extends Node3D

const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const STAGE_INFORMANT := 0
const STAGE_FELLAS := 1
const STAGE_DISMOUNT := 2
const STAGE_FIGHT := 3
const STAGE_SURRENDER := 4
const STAGE_CABELO := 5

@onready var maycon_3d: Node3D = $maycon_3d
@onready var fade: Node2D = $fade
@onready var cutscene_inicio: AnimationPlayer = $cutscene/cutscene_inicio
@onready var the_almost_end_song: AudioStreamPlayer = $TheAlmostEndSong
@onready var luz_mapa: DirectionalLight3D = $pause_3d_moto_cidade/luz_mapa
@onready var balao_marker: Marker2D = $balao
@onready var cabelo: AnimatedSprite3D = $cabelo
@onready var cabelo_area: Area3D = $cabelo/Area3D
@onready var informant: AnimatedSprite3D = $cigarro
@onready var informant_area: Area3D = $cigarro/area_3d_cigarro
@onready var fellas: AnimatedSprite3D = $lipao
@onready var fellas_area: Area3D = $lipao/area_3d_lips

var stage:int = STAGE_INFORMANT
var balao_:CanvasLayer
var player:CharacterBody3D
var objective_ui:CanvasLayer
var objective_label:Label
var weapon_root:Node3D
var loose_wood:Node3D
var attacking:bool = false
var fight_finishing:bool = false
var informant_dialog_available:bool = true
var informant_dialog_start_position:Vector3
var thug_data:Array[Dictionary] = []
var fellas_original_scale:Vector3
var fellas_original_position:Vector3
var fellas_member_original_positions:Dictionary = {}
var motorcycle_rotation_before_dismount:Vector3
var motorcycle_camera_rotation_before_dismount:Vector3

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	fellas_original_scale = fellas.scale
	fellas_original_position = fellas.position
	for member in [$lipao/iago, $lipao/luks, $lipao/tony]:
		fellas_member_original_positions[member] = member.position
	configure_fellas_billboards()
	build_objective_ui()
	objective_ui.visible = false
	set_story_stage(STAGE_INFORMANT)
	player.get_node("hud_canvas/maycon_hp").visible = false
	Global.in_cutscene = true
	luz_mapa.visible = true
	maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
	cutscene_inicio.play("intro_mapa")

func _unhandled_input(event:InputEvent) -> void:
	if stage == STAGE_DISMOUNT && event.is_action_pressed("key_e"):
		get_viewport().set_input_as_handled()
		begin_pickup_cutscene()
	elif stage == STAGE_FIGHT && event.is_action_pressed("tiro"):
		get_viewport().set_input_as_handled()
		attack_with_wood()

func build_objective_ui() -> void:
	objective_ui = CanvasLayer.new()
	objective_ui.layer = 90
	add_child(objective_ui)
	objective_label = Label.new()
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-330, 32)
	objective_label.size = Vector2(660, 54)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 22)
	objective_label.add_theme_color_override("font_color", Color("ffe6a7"))
	objective_label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.01, 0.95))
	objective_label.add_theme_constant_override("outline_size", 7)
	objective_ui.add_child(objective_label)

func set_story_stage(new_stage:int) -> void:
	stage = new_stage
	informant.visible = true
	fellas.visible = stage >= STAGE_FELLAS
	fellas_area.monitoring = stage == STAGE_FELLAS
	cabelo.visible = stage == STAGE_CABELO
	cabelo_area.monitoring = stage == STAGE_CABELO
	update_map_objectives(false)
	match stage:
		STAGE_INFORMANT:
			objective_label.text = localized("Procure uma pista no sul da cidade", "Find a clue in the south of the city")
		STAGE_FELLAS:
			objective_label.text = localized("Encontre os Fellas ao norte", "Find the Fellas up north")
		STAGE_DISMOUNT:
			objective_label.text = localized("Pressione E / START para descer da moto", "Press E / START to get off the motorcycle")
		STAGE_FIGHT:
			objective_label.text = localized("BOTÃO ESQUERDO / RT: acerte os Fellas com a madeira", "LEFT BUTTON / RT: hit the Fellas with the wood")
		STAGE_SURRENDER:
			objective_label.text = ""
		STAGE_CABELO:
			objective_label.text = localized("O Cabelo está no Posto Estrela da Serra!", "Cabelo is at the Serra Star Gas Station!")

func localized(pt_br:String, english:String) -> String:
	return pt_br if Global.default_language == Global.language_pt_br else english

func configure_fellas_billboards() -> void:
	for member in [fellas, $lipao/iago, $lipao/luks, $lipao/tony]:
		if member is SpriteBase3D:
			member.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func update_map_objectives(map_open:bool) -> void:
	$cigarro/mapa_cabelo.visible = map_open && stage == STAGE_INFORMANT
	$lipao/mapa_cabelo.visible = map_open && stage >= STAGE_FELLAS && stage < STAGE_CABELO
	$cabelo/mapa_cabelo.visible = map_open && stage == STAGE_CABELO

func _on_chao_body_entered(_body:Node3D) -> void:
	get_tree().reload_current_scene()

func _on_area_3d_body_entered(body:Node3D) -> void:
	if body is CharacterBody3D && stage == STAGE_CABELO:
		player.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(1.5).timeout
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/demo_end.tscn")

func _on_cutscene_inicio_animation_finished(anim_name:StringName) -> void:
	if anim_name != "intro_mapa":
		return
	maycon_3d.process_mode = Node.PROCESS_MODE_INHERIT
	luz_mapa.visible = false
	fade.get_node("Transition").play("fade_in")
	player.set_final_game()
	player.get_node("hud_canvas/maycon_hp").visible = false
	the_almost_end_song.play()
	player.set_rain(true)
	objective_ui.visible = true
	Global.in_cutscene = false

func _on_area_3d_cigarro_body_entered(body:Node3D) -> void:
	if !(body is CharacterBody3D) || !informant_dialog_available || ![STAGE_INFORMANT, STAGE_FELLAS, STAGE_CABELO].has(stage) || is_instance_valid(balao_):
		return
	informant_dialog_available = false
	informant_dialog_start_position = body.global_position
	Global.in_cutscene = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
	balao_.falas = [
		"...",
		localized("Maycon, acho que vi quem levou o Cabelo.", "Maycon, I think I saw who took Cabelo."),
		localized("Tem um grupo de malandros aí pra cima.", "There's a gang of troublemakers up the road."),
		localized("Acho que eles pegaram o Cabelo.", "I think they took Cabelo."),
		localized("Eles estavam muito estranhos.", "They were acting very suspicious."),
		localized("Principalmente um tal de Tony.", "Especially a guy named Tony."),
		localized("Ele parece ser o mais malandro deles.", "He looks like the shadiest one of them."),
		localized("Eles se chamam de Fellas.", "They call themselves the Fellas.")
	]
	balao_.balao_sem_seta = true
	balao_.conversa_terminou.connect(on_informant_dialog_finished, CONNECT_ONE_SHOT)
	balao_marker.add_child(balao_)

func on_informant_dialog_finished() -> void:
	if stage == STAGE_INFORMANT:
		set_story_stage(STAGE_FELLAS)
	Global.in_cutscene = false
	player.process_mode = Node.PROCESS_MODE_INHERIT

func _on_area_3d_cigarro_body_exited(body:Node3D) -> void:
	if body is CharacterBody3D && !Global.in_cutscene && body.process_mode != Node.PROCESS_MODE_DISABLED && body.global_position.distance_to(informant_dialog_start_position) > 0.25:
		informant_dialog_available = true

func _on_area_3d_lips_body_entered(body:Node3D) -> void:
	if !(body is CharacterBody3D) || stage != STAGE_FELLAS || is_instance_valid(balao_):
		return
	Global.in_cutscene = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
	balao_.falas = [
		"...",
		localized("Olha só quem chegou... o heróizinho da cidade.", "Look who showed up... the city's little hero."),
		localized("Nós somos os caras. Você não é nada!", "We're the real deal. You're nothing!"),
		localized("Estamos sendo pagos para ficar com o Cabelo, portanto mete o pé!", "We're being paid to keep Cabelo, so get lost!"),
		localized("Some daqui, mané, antes que o Tony perca a paciência!", "Get out of here, loser, before Tony loses his patience!"),
		localized("Você não assusta nem criança, seu otário!", "You couldn't scare a child, you clown!")
	]
	balao_.balao_sem_seta = true
	balao_.conversa_terminou.connect(on_fellas_dialog_finished, CONNECT_ONE_SHOT)
	balao_marker.add_child(balao_)

func on_fellas_dialog_finished() -> void:
	set_story_stage(STAGE_DISMOUNT)
	Global.in_cutscene = true

func _on_area_3d_lips_body_exited(body:Node3D) -> void:
	if body is CharacterBody3D && is_instance_valid(balao_) && stage != STAGE_FELLAS:
		balao_.queue_free()

func begin_pickup_cutscene() -> void:
	if stage != STAGE_DISMOUNT:
		return
	objective_label.text = ""
	var player_camera:Camera3D = player.get_node("Camera3D")
	motorcycle_rotation_before_dismount = player.rotation
	motorcycle_camera_rotation_before_dismount = player_camera.rotation
	player.dismount_final_game()
	player.velocity = Vector3.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED
	loose_wood = create_wood_prop()
	loose_wood.global_position = fellas.global_position + Vector3(10.0, 0.3, 5.0)
	loose_wood.rotation_degrees.z = 90.0
	player_camera.make_current()
	var wood_floor_position := Vector3(loose_wood.global_position.x, player.global_position.y, loose_wood.global_position.z)
	var approach_direction := player.global_position - wood_floor_position
	approach_direction.y = 0.0
	approach_direction = approach_direction.normalized()
	var walk_target := wood_floor_position + approach_direction * 2.2
	var walk_transform := player.global_transform
	walk_transform.origin = walk_target
	walk_transform = walk_transform.looking_at(wood_floor_position, Vector3.UP)
	if player.walk:
		player.walk.play()
	if player.animation_tree_playback:
		player.animation_tree_playback.travel("run")
	var walk_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk_tween.tween_property(player, "global_transform", walk_transform, 3.8)
	await walk_tween.finished
	player.walk.stop()
	if player.animation_tree_playback:
		player.animation_tree_playback.travel("idle")
	var standing_camera_position := player_camera.position
	var standing_camera_rotation := player_camera.rotation
	var crouched_camera_position := standing_camera_position + Vector3(0.0, -1.15, 0.18)
	var crouched_camera_rotation := standing_camera_rotation
	crouched_camera_rotation.x = deg_to_rad(-52.0)
	var crouch_tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(player_camera, "position", crouched_camera_position, 1.7)
	crouch_tween.tween_property(player_camera, "rotation", crouched_camera_rotation, 1.7)
	await crouch_tween.finished
	await get_tree().create_timer(0.65).timeout
	loose_wood.queue_free()
	build_first_person_weapon(player_camera)
	await get_tree().create_timer(0.65).timeout
	var stand_tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stand_tween.tween_property(player_camera, "position", standing_camera_position, 1.7)
	stand_tween.tween_property(player_camera, "rotation", standing_camera_rotation, 1.7)
	await stand_tween.finished
	setup_thugs()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Global.in_cutscene = false
	set_story_stage(STAGE_FIGHT)

func create_wood_prop() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var wood := MeshInstance3D.new()
	var wood_mesh := CylinderMesh.new()
	wood_mesh.top_radius = 0.13
	wood_mesh.bottom_radius = 0.18
	wood_mesh.height = 2.4
	wood.mesh = wood_mesh
	var wood_material := StandardMaterial3D.new()
	wood_material.albedo_color = Color("6b351b")
	wood_material.roughness = 0.92
	wood.material_override = wood_material
	root.add_child(wood)
	return root

func build_first_person_weapon(player_camera:Camera3D) -> void:
	weapon_root = Node3D.new()
	weapon_root.name = "WoodWeapon"
	weapon_root.position = Vector3(0.62, -0.55, -1.15)
	weapon_root.rotation_degrees = Vector3(-18.0, 0.0, -25.0)
	player_camera.add_child(weapon_root)
	var wood_container := create_wood_prop()
	var wood := wood_container.get_child(0)
	wood.reparent(weapon_root)
	wood_container.queue_free()
	wood.position = Vector3(-0.12, 0.36, -0.18)
	wood.rotation_degrees.z = -28.0

func setup_thugs() -> void:
	thug_data.clear()
	# Os sprites originais têm cerca de cinco metros de altura. A redução é
	# aplicada somente durante o trecho em primeira pessoa.
	fellas.scale = fellas_original_scale * 0.42
	var thugs:Array[Node3D] = [$lipao/iago, $lipao/luks, $lipao/tony]
	var spread := [Vector3(-10.0, 0.0, 4.0), Vector3(0.0, 0.0, 1.0), Vector3(10.0, 0.0, 4.0)]
	for index in thugs.size():
		var thug := thugs[index]
		thug.position = spread[index]
		add_thug_to_fight(thug)
	add_thug_to_fight(fellas)

func add_thug_to_fight(thug:Node3D) -> void:
	var shout := Label3D.new()
	shout.position = Vector3(0.0, 3.7, 0.0)
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.font_size = 38
	shout.outline_size = 10
	shout.modulate = Color("fff1a8")
	shout.text = ""
	thug.add_child(shout)
	thug_data.append({"node":thug, "hp":3, "shout":shout})

func attack_with_wood() -> void:
	if attacking || fight_finishing || !is_instance_valid(weapon_root):
		return
	attacking = true
	var start_rotation := weapon_root.rotation
	var swing_rotation := start_rotation + Vector3(deg_to_rad(-48.0), deg_to_rad(-32.0), deg_to_rad(62.0))
	var swing := create_tween().set_trans(Tween.TRANS_QUAD)
	swing.tween_property(weapon_root, "rotation", swing_rotation, 0.11).set_ease(Tween.EASE_IN)
	swing.tween_callback(resolve_wood_hit)
	swing.tween_property(weapon_root, "rotation", start_rotation, 0.22).set_ease(Tween.EASE_OUT)
	await swing.finished
	attacking = false

func resolve_wood_hit() -> void:
	var closest:Dictionary = {}
	var closest_distance := 10.0
	var camera:Camera3D = player.get_node("Camera3D")
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	for data in thug_data:
		if int(data["hp"]) <= 0:
			continue
		var thug:Node3D = data["node"]
		var to_thug := thug.global_position - player.global_position
		var distance := Vector2(to_thug.x, to_thug.z).length()
		var flat_direction := Vector3(to_thug.x, 0.0, to_thug.z).normalized()
		if distance < closest_distance && forward.dot(flat_direction) > 0.35:
			closest = data
			closest_distance = distance
	if closest.is_empty():
		return
	closest["hp"] = int(closest["hp"]) - 1
	spawn_hit_blood(closest["node"])
	Input.start_joy_vibration(0, 0.7, 0.85, 0.22)
	player.aplicar_shake(0.32)
	make_thug_retreat(closest)
	if all_thugs_injured():
		finish_fight()

func spawn_hit_blood(thug:Node3D) -> void:
	for _index in 3:
		var blood := BLOOD_SCENE.instantiate()
		add_child(blood)
		blood.global_position = thug.global_position + Vector3(randf_range(-0.8, 0.8), randf_range(1.0, 2.6), randf_range(-0.5, 0.5))

func make_thug_retreat(data:Dictionary) -> void:
	var thug:Node3D = data["node"]
	var shout:Label3D = data["shout"]
	var shouts_pt := ["SAI VAZADO!", "SAI DAÍ, BUNDÃO!", "SAI NO SAPATO, OTÁRIO!", "PARA COM ISSO, MALUCO!"]
	var shouts_en := ["BACK OFF!", "GET AWAY, JERK!", "GET LOST, LOSER!", "STOP IT, MANIAC!"]
	shout.text = (shouts_pt if Global.default_language == Global.language_pt_br else shouts_en).pick_random()
	var away := thug.global_position - player.global_position
	away.y = 0.0
	away = away.normalized()
	var sideways := Vector3(-away.z, 0.0, away.x) * randf_range(-2.8, 2.8)
	var retreat_to := thug.global_position + away * 3.8 + sideways
	var retreat := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	retreat.tween_property(thug, "global_position", retreat_to, 0.42)
	retreat.tween_interval(0.9)
	retreat.tween_callback(func(): shout.text = "")

func all_thugs_injured() -> bool:
	for data in thug_data:
		if int(data["hp"]) > 0:
			return false
	return true

func finish_fight() -> void:
	if fight_finishing:
		return
	fight_finishing = true
	set_story_stage(STAGE_SURRENDER)
	Global.in_cutscene = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(0.7).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(weapon_root):
		weapon_root.queue_free()
	fellas.position = fellas_original_position
	fellas.scale = fellas_original_scale
	for member in fellas_member_original_positions:
		member.position = fellas_member_original_positions[member]
	player.mount_final_game()
	player.global_position = fellas.global_position + Vector3(0.0, 0.0, 18.0)
	player.rotation = motorcycle_rotation_before_dismount
	var player_camera:Camera3D = player.get_node("Camera3D")
	player_camera.rotation = motorcycle_camera_rotation_before_dismount
	player_camera.h_offset = 0.0
	player_camera.v_offset = 0.0
	player.velocity = Vector3.ZERO
	for data in thug_data:
		var thug:Node3D = data["node"]
		thug.modulate = Color(0.62, 0.2, 0.2, 1.0)
		(data["shout"] as Label3D).text = ""
	fade.get_node("Transition").play("fade_in")
	await get_tree().create_timer(1.2).timeout
	show_surrender_dialog()

func show_surrender_dialog() -> void:
	balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
	balao_.falas = [
		localized("Tá bom, tá bom! Perdoa a gente, Maycon!", "All right, all right! Forgive us, Maycon!"),
		localized("Foi o Tony que fechou o acordo. A gente só queria a grana!", "Tony made the deal. We just wanted the money!"),
		localized("Deixamos o Cabelo perto do Posto Estrela da Serra.", "We left Cabelo near the Serra Star Gas Station."),
		localized("Fica no canto nordeste da cidade. Ele está bem, a gente jura!", "It's in the northeast corner of the city. He's safe, we swear!")
	]
	balao_.balao_sem_seta = true
	balao_.conversa_terminou.connect(unlock_cabelo, CONNECT_ONE_SHOT)
	balao_marker.add_child(balao_)

func unlock_cabelo() -> void:
	set_story_stage(STAGE_CABELO)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Global.in_cutscene = false
