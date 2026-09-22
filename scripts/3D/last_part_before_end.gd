extends Node3D

const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const THUG_PAIN_SOUND_1 = preload("res://assets/novos_audios/DS_pain.mp3")
const THUG_PAIN_SOUND_2 = preload("res://assets/novos_audios/doom_pain.mp3")
const THUG_PAIN_SOUND_3 = preload("res://assets/novos_audios/seco_scream.mp3")
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
var fight_hit_count:int = 0
var informant_dialog_available:bool = true
var informant_dialog_start_position:Vector3
var thug_data:Array[Dictionary] = []
var fellas_original_scale:Vector3
var fellas_original_position:Vector3
var fellas_member_original_positions:Dictionary = {}
var motorcycle_rotation_before_dismount:Vector3
var motorcycle_camera_rotation_before_dismount:Vector3
var thug_pain_sounds:Array[AudioStream] = [THUG_PAIN_SOUND_1, THUG_PAIN_SOUND_2, THUG_PAIN_SOUND_3]
var wood_debug_mode:bool = false
var wood_debug_status:Label
var enemy_debug_status:Label

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
	if OS.get_cmdline_user_args().has("--test-wood-pickup"):
		wood_debug_mode = true
		call_deferred("start_wood_pickup_test")

func start_wood_pickup_test() -> void:
	cutscene_inicio.stop()
	maycon_3d.process_mode = Node.PROCESS_MODE_INHERIT
	luz_mapa.visible = false
	player.set_final_game()
	player.get_node("hud_canvas/maycon_hp").visible = false
	player.set_rain(true)
	var test_position := fellas.global_position + Vector3(0.0, 0.0, 15.0)
	place_player_on_ground(test_position)
	player.look_at(Vector3(fellas.global_position.x, player.global_position.y, fellas.global_position.z), Vector3.UP)
	player.velocity = Vector3.ZERO
	objective_ui.visible = true
	the_almost_end_song.play()
	Global.in_cutscene = true
	set_story_stage(STAGE_DISMOUNT)
	build_wood_debug_ui()

func find_ground_position(position:Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(position.x, position.y + 40.0, position.z),
		Vector3(position.x, position.y - 80.0, position.z)
	)
	query.exclude = [player.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("position", position)

func place_player_on_ground(position:Vector3) -> void:
	var ground_position := find_ground_position(position)
	var collision:CollisionShape3D = player.get_node("CollisionShape3D")
	var capsule:CapsuleShape3D = collision.shape
	var player_scale_y := player.global_basis.get_scale().y
	var bottom_offset := collision.position.y * player_scale_y - capsule.height * 0.5 * player_scale_y
	position.y = ground_position.y - bottom_offset + 0.04
	player.global_position = position

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

func build_wood_debug_ui() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var debug_layer := CanvasLayer.new()
	debug_layer.layer = 120
	add_child(debug_layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(10.0, 55.0)
	panel.custom_minimum_size = Vector2(390.0, 0.0)
	var debug_theme := Theme.new()
	debug_theme.default_font_size = 12
	panel.theme = debug_theme
	debug_layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	var title := Label.new()
	title.text = "AJUSTE TEMPORÁRIO DA MADEIRA"
	title.add_theme_font_size_override("font_size", 14)
	content.add_child(title)
	wood_debug_status = Label.new()
	wood_debug_status.text = "Aperte Start ou clique em PEGAR MADEIRA."
	wood_debug_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(wood_debug_status)
	var pickup_button := Button.new()
	pickup_button.text = "PEGAR MADEIRA"
	pickup_button.custom_minimum_size.y = 28.0
	pickup_button.pressed.connect(begin_pickup_cutscene)
	content.add_child(pickup_button)
	var grid := GridContainer.new()
	grid.columns = 3
	content.add_child(grid)
	add_wood_debug_button(grid, "X -", Vector3(-0.05, 0.0, 0.0), Vector3.ZERO)
	add_wood_debug_button(grid, "X +", Vector3(0.05, 0.0, 0.0), Vector3.ZERO)
	add_wood_debug_button(grid, "Y -", Vector3(0.0, -0.05, 0.0), Vector3.ZERO)
	add_wood_debug_button(grid, "Y +", Vector3(0.0, 0.05, 0.0), Vector3.ZERO)
	add_wood_debug_button(grid, "Z -", Vector3(0.0, 0.0, -0.05), Vector3.ZERO)
	add_wood_debug_button(grid, "Z +", Vector3(0.0, 0.0, 0.05), Vector3.ZERO)
	add_wood_debug_button(grid, "GIRAR X -", Vector3.ZERO, Vector3(-5.0, 0.0, 0.0))
	add_wood_debug_button(grid, "GIRAR X +", Vector3.ZERO, Vector3(5.0, 0.0, 0.0))
	add_wood_debug_button(grid, "GIRAR Y -", Vector3.ZERO, Vector3(0.0, -5.0, 0.0))
	add_wood_debug_button(grid, "GIRAR Y +", Vector3.ZERO, Vector3(0.0, 5.0, 0.0))
	add_wood_debug_button(grid, "GIRAR Z -", Vector3.ZERO, Vector3(0.0, 0.0, -5.0))
	add_wood_debug_button(grid, "GIRAR Z +", Vector3.ZERO, Vector3(0.0, 0.0, 5.0))
	var scale_down_button := Button.new()
	scale_down_button.text = "TAMANHO -"
	scale_down_button.custom_minimum_size = Vector2(120.0, 28.0)
	scale_down_button.pressed.connect(adjust_wood_debug_scale.bind(0.95))
	grid.add_child(scale_down_button)
	var scale_up_button := Button.new()
	scale_up_button.text = "TAMANHO +"
	scale_up_button.custom_minimum_size = Vector2(120.0, 28.0)
	scale_up_button.pressed.connect(adjust_wood_debug_scale.bind(1.05))
	grid.add_child(scale_up_button)
	var print_button := Button.new()
	print_button.text = "PRINTAR OFFSET NO LOG"
	print_button.custom_minimum_size.y = 28.0
	print_button.pressed.connect(print_wood_debug_transform)
	content.add_child(print_button)
	var separator := HSeparator.new()
	content.add_child(separator)
	var enemy_title := Label.new()
	enemy_title.text = "AJUSTE DOS INIMIGOS"
	enemy_title.add_theme_font_size_override("font_size", 14)
	content.add_child(enemy_title)
	enemy_debug_status = Label.new()
	enemy_debug_status.text = "Pegue a madeira para liberar os ajustes."
	content.add_child(enemy_debug_status)
	var enemy_grid := GridContainer.new()
	enemy_grid.columns = 2
	content.add_child(enemy_grid)
	add_enemy_debug_button(enemy_grid, "TAMANHO -", 0.95, 0.0)
	add_enemy_debug_button(enemy_grid, "TAMANHO +", 1.05, 0.0)
	add_enemy_debug_button(enemy_grid, "EIXO Y -", 1.0, -0.1)
	add_enemy_debug_button(enemy_grid, "EIXO Y +", 1.0, 0.1)
	var enemy_print_button := Button.new()
	enemy_print_button.text = "PRINTAR INIMIGOS NO LOG"
	enemy_print_button.custom_minimum_size.y = 28.0
	enemy_print_button.pressed.connect(print_enemy_debug_transform)
	content.add_child(enemy_print_button)

func add_wood_debug_button(parent:Control, text:String, position_delta:Vector3, rotation_delta:Vector3) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120.0, 28.0)
	button.pressed.connect(adjust_wood_debug.bind(position_delta, rotation_delta))
	parent.add_child(button)

func adjust_wood_debug(position_delta:Vector3, rotation_delta:Vector3) -> void:
	if !is_instance_valid(weapon_root):
		wood_debug_status.text = "Pegue a madeira antes de ajustar."
		return
	weapon_root.position += position_delta
	weapon_root.rotation_degrees += rotation_delta
	update_wood_debug_status()

func adjust_wood_debug_scale(multiplier:float) -> void:
	if !is_instance_valid(weapon_root):
		wood_debug_status.text = "Pegue a madeira antes de ajustar."
		return
	weapon_root.scale *= multiplier
	update_wood_debug_status()

func update_wood_debug_status() -> void:
	if !wood_debug_mode || !is_instance_valid(wood_debug_status) || !is_instance_valid(weapon_root):
		return
	wood_debug_status.text = "Posição: %s\nRotação: %s\nTamanho: %s" % [weapon_root.position, weapon_root.rotation_degrees, weapon_root.scale]

func print_wood_debug_transform() -> void:
	if !is_instance_valid(weapon_root):
		wood_debug_status.text = "Pegue a madeira antes de imprimir."
		return
	print("WOOD_DEBUG_OFFSET position=", weapon_root.position, " rotation_degrees=", weapon_root.rotation_degrees, " scale=", weapon_root.scale)
	wood_debug_status.text = "Offset impresso no log.\nPosição: %s\nRotação: %s\nTamanho: %s" % [weapon_root.position, weapon_root.rotation_degrees, weapon_root.scale]

func add_enemy_debug_button(parent:Control, text:String, scale_multiplier:float, y_delta:float) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(185.0, 28.0)
	button.pressed.connect(adjust_enemy_debug.bind(scale_multiplier, y_delta))
	parent.add_child(button)

func adjust_enemy_debug(scale_multiplier:float, y_delta:float) -> void:
	if thug_data.is_empty():
		enemy_debug_status.text = "Pegue a madeira para liberar os ajustes."
		return
	fellas.scale *= scale_multiplier
	fellas.global_position.y += y_delta
	update_enemy_debug_status()

func update_enemy_debug_status() -> void:
	if !wood_debug_mode || !is_instance_valid(enemy_debug_status) || thug_data.is_empty():
		return
	enemy_debug_status.text = "Tamanho: %s\nY do grupo: %.4f" % [fellas.scale, fellas.global_position.y]

func print_enemy_debug_transform() -> void:
	if thug_data.is_empty():
		enemy_debug_status.text = "Pegue a madeira antes de imprimir."
		return
	var member_y := {
		"lipao": fellas.global_position.y,
		"iago": $lipao/iago.global_position.y,
		"luks": $lipao/luks.global_position.y,
		"tony": $lipao/tony.global_position.y
	}
	print("ENEMY_DEBUG scale=", fellas.scale, " root_global_y=", fellas.global_position.y, " member_global_y=", member_y)
	enemy_debug_status.text = "Valores dos inimigos impressos.\nTamanho: %s\nY do grupo: %.4f" % [fellas.scale, fellas.global_position.y]

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
			objective_label.text = tr("OBJECTIVE_SEEK_CLUE")
		STAGE_FELLAS:
			objective_label.text = tr("OBJECTIVE_FIND_FELLAS")
		STAGE_DISMOUNT:
			objective_label.text = tr("OBJECTIVE_DISMOUNT")
		STAGE_FIGHT:
			objective_label.text = tr("OBJECTIVE_FIGHT_FELLAS")
		STAGE_SURRENDER:
			objective_label.text = ""
		STAGE_CABELO:
			objective_label.text = tr("OBJECTIVE_CABELO_GAS_STATION")

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
		"DIALOGUE_INFORMANT_1",
		"DIALOGUE_INFORMANT_2",
		"DIALOGUE_INFORMANT_3",
		"DIALOGUE_INFORMANT_4",
		"DIALOGUE_INFORMANT_5",
		"DIALOGUE_INFORMANT_6",
		"DIALOGUE_INFORMANT_7"
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
		"DIALOGUE_FELLAS_1",
		"DIALOGUE_FELLAS_2",
		"DIALOGUE_FELLAS_3",
		"DIALOGUE_FELLAS_4",
		"DIALOGUE_FELLAS_5"
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
	var pickup_direction := -player.global_basis.z
	pickup_direction.y = 0.0
	pickup_direction = pickup_direction.normalized()
	var wood_position := player.global_position + pickup_direction * 1.85
	var ground_position := find_ground_position(wood_position)
	loose_wood.global_position = ground_position + Vector3(0.0, 0.18, 0.0)
	loose_wood.rotation_degrees.z = -90.0
	player_camera.make_current()
	var standing_camera_position := player_camera.position
	var standing_camera_rotation := player_camera.rotation
	var crouched_camera_position := standing_camera_position + Vector3(0.0, -0.05, -0.18)
	var crouched_camera_rotation := standing_camera_rotation
	crouched_camera_rotation.x = deg_to_rad(-45.0)
	var crouch_tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	crouch_tween.tween_property(player_camera, "position", crouched_camera_position, 2.1)
	crouch_tween.tween_property(player_camera, "rotation", crouched_camera_rotation, 2.1)
	await crouch_tween.finished
	await get_tree().create_timer(0.8).timeout
	var pickup_target := player_camera.global_position - player_camera.global_basis.z * 1.05
	pickup_target += player_camera.global_basis.x * 0.52 - player_camera.global_basis.y * 0.3
	var pickup_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pickup_tween.tween_property(loose_wood, "global_position", pickup_target, 0.85)
	await pickup_tween.finished
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
	weapon_root.position = Vector3(0.07, -0.15, -0.4)
	weapon_root.rotation_degrees = Vector3(-105.0, 85.0, 165.0)
	weapon_root.scale = Vector3(0.193711, 0.193711, 0.193711)
	player_camera.add_child(weapon_root)
	var wood_container := create_wood_prop()
	var wood := wood_container.get_child(0)
	wood.reparent(weapon_root)
	wood_container.queue_free()
	wood.position = Vector3(-0.12, 0.36, -0.18)
	wood.rotation_degrees.z = -45.0
	update_wood_debug_status()

func setup_thugs() -> void:
	thug_data.clear()
	fight_hit_count = 0
	# Valores calibrados visualmente no modo temporário de ajuste.
	fellas.scale = Vector3(0.279458, 0.236062, 0.286799)
	var fellas_position := fellas.global_position
	fellas_position.y = -6.49914455413818
	fellas.global_position = fellas_position
	var thugs:Array[Node3D] = [$lipao/iago, $lipao/luks, $lipao/tony]
	var spread := [Vector3(-10.0, 0.0, 4.0), Vector3(0.0, 0.0, 1.0), Vector3(10.0, 0.0, 4.0)]
	var calibrated_y := [-6.42242431640625, -6.48970222473145, -6.47394227981567]
	for index in thugs.size():
		var thug:AnimatedSprite3D = thugs[index]
		thug.position = spread[index]
		var thug_position := thug.global_position
		thug_position.y = calibrated_y[index]
		thug.global_position = thug_position
		add_thug_to_fight(thug)
	add_thug_to_fight(fellas)
	update_enemy_debug_status()

func add_thug_to_fight(thug:Node3D) -> void:
	var shout := Label3D.new()
	shout.position = Vector3(0.0, 3.7, 0.0)
	shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shout.font_size = 38
	shout.outline_size = 10
	shout.modulate = Color("fff1a8")
	shout.text = ""
	thug.add_child(shout)
	var pain_audio := AudioStreamPlayer3D.new()
	pain_audio.name = "PainScream"
	pain_audio.volume_db = -1.0
	pain_audio.unit_size = 7.0
	pain_audio.max_distance = 55.0
	thug.add_child(pain_audio)
	thug_data.append({"node":thug, "hp":3, "shout":shout, "pain_audio":pain_audio})

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
	fight_hit_count += 1
	spawn_hit_blood(closest["node"])
	add_permanent_blood_stains(closest)
	play_thug_pain_scream(closest)
	Input.start_joy_vibration(0, 0.7, 0.85, 0.22)
	player.aplicar_shake(0.32)
	make_thug_retreat(closest)
	if fight_hit_count >= 3:
		finish_fight()

func spawn_hit_blood(thug:Node3D) -> void:
	for _index in 3:
		var blood := BLOOD_SCENE.instantiate()
		add_child(blood)
		blood.global_position = thug.global_position + Vector3(randf_range(-0.8, 0.8), randf_range(1.0, 2.6), randf_range(-0.5, 0.5))

func add_permanent_blood_stains(data:Dictionary) -> void:
	var thug:AnimatedSprite3D = data["node"]
	var hits_taken := 3 - int(data["hp"])
	var blood_tones := [
		Color(0.92, 0.68, 0.68, 1.0),
		Color(0.78, 0.39, 0.39, 1.0),
		Color(0.62, 0.2, 0.2, 1.0)
	]
	thug.modulate = blood_tones[clampi(hits_taken - 1, 0, blood_tones.size() - 1)]
	var bounds := thug.get_aabb()
	var stain_radius := clampf(minf(bounds.size.x, bounds.size.y) * 0.055, 0.13, 0.3)
	for _index in 3:
		var stain := MeshInstance3D.new()
		stain.name = "BloodStain_%d_%d" % [hits_taken, _index]
		var stain_mesh := SphereMesh.new()
		stain_mesh.radius = stain_radius * randf_range(0.7, 1.15)
		stain_mesh.height = stain_mesh.radius * 2.0
		stain_mesh.radial_segments = 10
		stain_mesh.rings = 5
		var stain_material := StandardMaterial3D.new()
		stain_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stain_material.albedo_color = Color(randf_range(0.28, 0.48), 0.015, 0.015, 1.0)
		stain_mesh.material = stain_material
		stain.mesh = stain_mesh
		stain.position = Vector3(
			randf_range(bounds.position.x + bounds.size.x * 0.25, bounds.position.x + bounds.size.x * 0.75),
			randf_range(bounds.position.y + bounds.size.y * 0.2, bounds.position.y + bounds.size.y * 0.82),
			0.0
		)
		stain.scale = Vector3(randf_range(0.8, 1.35), randf_range(0.65, 1.2), 0.22)
		thug.add_child(stain)

func play_thug_pain_scream(data:Dictionary) -> void:
	var pain_audio:AudioStreamPlayer3D = data["pain_audio"]
	pain_audio.stop()
	pain_audio.stream = thug_pain_sounds.pick_random()
	pain_audio.pitch_scale = randf_range(0.88, 1.12)
	pain_audio.play()

func make_thug_retreat(data:Dictionary) -> void:
	var thug:Node3D = data["node"]
	var shout:Label3D = data["shout"]
	var shouts := ["SHOUT_THUG_1", "SHOUT_THUG_2", "SHOUT_THUG_3", "SHOUT_THUG_4"]
	shout.text = tr(shouts.pick_random())
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
		"DIALOGUE_SURRENDER_1",
		"DIALOGUE_SURRENDER_2",
		"DIALOGUE_SURRENDER_3",
		"DIALOGUE_SURRENDER_4"
	]
	balao_.balao_sem_seta = true
	balao_.conversa_terminou.connect(unlock_cabelo, CONNECT_ONE_SHOT)
	balao_marker.add_child(balao_)

func unlock_cabelo() -> void:
	set_story_stage(STAGE_CABELO)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	Global.in_cutscene = false
