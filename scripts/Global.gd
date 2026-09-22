extends Node

const language_pt_br = "PT-BR"
const language_en = "EN"
const battle_mode_realtime = "realtime"
const battle_mode_strategic = "strategic"
const realtime_enemy_respawn_seconds:float = 75.0

var load_from_castle_1:bool = false
var load_from_outside_1:bool = false

var back_caminho_das_pedras = false
var cena_caminho_das_pedras = false
var cena_first_seco_boss = false
var is_two_player_active = false
var back_to_main_camera = false
var back_to_fase = false
var from_slum = false
var battle_background:String = "1" # default o cenario de fogo fora do castelo
var battle_next_enemy:String = "0"
var battle_next_boss:int = 0
var battle_started:bool = false
var battle_mode:String = battle_mode_realtime
var realtime_enemy_id:String = "1"
var realtime_enemy_spawn_id:String = ""
var realtime_return_scene:String = ""
var realtime_arena_theme:String = "forest_road"
var realtime_hp_max:float = 210.0
var realtime_hp:float = 210.0
var realtime_return_player_path:NodePath = NodePath("")
var realtime_return_player_position:Vector2 = Vector2.ZERO
var realtime_return_position_valid:bool = false
var realtime_restore_pending:bool = false
var realtime_restore_frames:int = 0
var last_fase = "fase_1"
var block_pause_before_prologo = false
#var before_prologo:bool = false #TESTE - correto eh TRUE

var players_dead_count:int = 0
var seco_danos_first_3d_battle:int = 0
var maycon_pegou_lamp_3d_world:bool = false
var maycon_pegou_gas_3d_world:bool = false
var maycon_pegou_lamp_fire_3d_world:bool = false
var maycon_pegou_arma_first_3d_battle:bool = false
var maycon_pegou_bullet:bool = false

# data to be saved
var can_load:bool = false
var in_cutscene:bool = false
var save_array = {}
var default_language:String = language_pt_br
var maycon_hp_count:int = 0
var maycon_itens_default = {axe=false}
var game_stage_1_events_died_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=true, first_battle=false, before_prologo=false}
var game_stage_outside_1_events_died_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=true, gilhotina_broken=true, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=true, first_battle=false, before_prologo=false}
var maycon_itens = {axe=false}
var game_events_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true}
var game_events = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true}
var inimigos_mortos = {}
var realtime_enemy_respawns:Dictionary = {}
var aim_assist_strength:float = 0.6
var show_debug_tab:bool = false

func _ready() -> void:
	load_settings()

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("gameplay", "aim_assist_strength", aim_assist_strength)
	config.save("user://settings.cfg")

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		aim_assist_strength = float(config.get_value("gameplay", "aim_assist_strength", 0.6))

func _process(_delta: float) -> void:
	restore_realtime_player_position()

func reset_default_values()->void:
	back_to_main_camera = false
	back_to_fase = false
	from_slum = false
	battle_background = "1" # default o cenario de fogo fora do castelo
	battle_next_enemy = "0"
	battle_next_boss = 0
	battle_started = false
	battle_mode = battle_mode_realtime
	realtime_enemy_id = "1"
	realtime_enemy_spawn_id = ""
	realtime_return_scene = ""
	realtime_arena_theme = "forest_road"
	realtime_hp = realtime_hp_max
	realtime_return_player_path = NodePath("")
	realtime_return_player_position = Vector2.ZERO
	realtime_return_position_valid = false
	realtime_restore_pending = false
	realtime_restore_frames = 0
	last_fase = "fase_1"
	block_pause_before_prologo = false

	seco_danos_first_3d_battle = 0
	maycon_pegou_lamp_3d_world = false
	maycon_pegou_gas_3d_world = false
	maycon_pegou_lamp_fire_3d_world = false
	maycon_pegou_arma_first_3d_battle = false
	maycon_pegou_bullet = false

	# data to be saved
	save_array = {}
	maycon_hp_count = 0
	maycon_itens = maycon_itens_default
	game_events = game_events_default
	inimigos_mortos = {}
	realtime_enemy_respawns = {}

func reset_save_to_castle_1()->void:
	seco_danos_first_3d_battle = 0
	maycon_pegou_lamp_3d_world = false
	maycon_pegou_gas_3d_world = false
	maycon_pegou_lamp_fire_3d_world = false
	maycon_pegou_arma_first_3d_battle = false
	maycon_pegou_bullet = false
	
	maycon_hp_count = 0	
	realtime_hp = realtime_hp_max
	maycon_itens = maycon_itens_default
	game_events = game_stage_1_events_died_default
	inimigos_mortos = {}
	save_progress("castelo_1")

func reset_save_to_outside_1()->void:
	seco_danos_first_3d_battle = 0
	maycon_pegou_lamp_3d_world = false
	maycon_pegou_gas_3d_world = false
	maycon_pegou_lamp_fire_3d_world = false
	maycon_pegou_arma_first_3d_battle = false
	maycon_pegou_bullet = false
	
	maycon_hp_count = 0	
	realtime_hp = realtime_hp_max
	maycon_itens = maycon_itens_default
	game_events = game_stage_outside_1_events_died_default
	inimigos_mortos = {}
	save_progress("outside_castelo_1")
	
func reset_save_to_fase_1()->void:
	maycon_hp_count = 0	
	realtime_hp = realtime_hp_max
	maycon_itens = maycon_itens_default
	game_events = game_events_default
	inimigos_mortos = {}
	save_progress("fase_1")
	
func reset_died_stage1()->void:
	reset_save_to_castle_1()
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn") 
	

func save_progress(fase:String)->void:
	save_array = {}
	save_array["maycon_hp_count"] = maycon_hp_count
	save_array["battle_mode"] = battle_mode
	save_array["realtime_hp"] = realtime_hp
	save_array["default_language"] = default_language
	save_array["maycon_itens"] = maycon_itens
	save_array["game_events"] = game_events
	save_array["inimigos_mortos"] = inimigos_mortos
	save_array["aim_assist_strength"] = aim_assist_strength
	save_array["last_fase"] = fase
	
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE) 
	var json_string = JSON.stringify(save_array) 
	file.store_line(json_string)

func check_load():
	if FileAccess.file_exists("user://savegame.save"): 
		can_load = true
	
	return can_load
	
func fade_out_sound(stream_player: AudioStreamPlayer, duracao: float):
	var tween = create_tween()
	# Faz o volume ir do valor atual até -80 dB (silêncio total)
	if stream_player:
		tween.tween_property(stream_player, "volume_db", -20.0, duracao)
	
		
func load_progress()->void:
	
	if load_from_castle_1:
		reset_save_to_castle_1()
		
		load_from_castle_1 = false
		load_progress()
	elif load_from_outside_1:
		reset_save_to_outside_1()
		
		load_from_outside_1 = false
		load_progress()
	else:
		reset_default_values()
		if FileAccess.file_exists("user://savegame.save"): 
			can_load = true
			var file = FileAccess.open("user://savegame.save", FileAccess.READ) 
			var json_string = file.get_as_text() 
			save_array = JSON.parse_string(json_string)
			
			default_language = save_array["default_language"]
			maycon_itens = save_array["maycon_itens"]
			game_events = save_array["game_events"]
			inimigos_mortos = save_array["inimigos_mortos"]
			if save_array.has("aim_assist_strength"):
				aim_assist_strength = float(save_array["aim_assist_strength"])
			last_fase = save_array["last_fase"]
			maycon_hp_count = save_array["maycon_hp_count"]
			battle_mode = save_array.get("battle_mode", battle_mode_realtime)
			realtime_hp = clampf(float(save_array.get("realtime_hp", realtime_hp_max)), 0.0, realtime_hp_max)
			if last_fase == "fase_1":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_1.tscn")
			elif last_fase == "fase_2":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_2.tscn")
			elif last_fase == "fase_3":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")
			elif last_fase == "fase_4":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_4.tscn")
			elif last_fase == "castelo_1":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn")
			elif last_fase == "castelo_2":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")
			elif last_fase == "castelo_3":
				GameSongs.play_song(1)
				get_tree().change_scene_to_file("res://scenes/fase_1_castle_3.tscn")
			elif last_fase == "castelo_no_fire_1":
				get_tree().change_scene_to_file("res://scenes/fase_1_castle_no_fire_1.tscn")
			elif last_fase == "castelo_no_fire_2":
				get_tree().change_scene_to_file("res://scenes/fase_1_castle_no_fire_2.tscn")
			elif last_fase == "outside_castelo_1":
				get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_1.tscn")
			elif last_fase == "outside_castelo_2":
				get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_2.tscn")
			elif last_fase == "outside_castelo_3":
				get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_3.tscn")

func capture_realtime_return_state(scene:Node) -> void:
	realtime_return_position_valid = false
	realtime_return_player_path = NodePath("")
	if scene == null:
		return
	var player_node = find_realtime_player(scene)
	if player_node is Node2D:
		realtime_return_player_path = scene.get_path_to(player_node)
		realtime_return_player_position = player_node.global_position
		realtime_return_position_valid = true

func find_realtime_player(scene:Node) -> Node:
	if scene == null:
		return null
	for player_name in ["maycon_fase", "Maycon"]:
		var player_node = scene.find_child(player_name, true, false)
		if player_node is Node2D:
			return player_node
	return null

func request_realtime_position_restore() -> void:
	if realtime_return_position_valid:
		realtime_restore_pending = true
		realtime_restore_frames = 45

func register_enemy_encounter(enemy_spawn_id:String) -> void:
	realtime_enemy_spawn_id = enemy_spawn_id
	if battle_mode == battle_mode_strategic:
		inimigos_mortos[enemy_spawn_id] = true

func schedule_realtime_enemy_respawn() -> void:
	if battle_mode != battle_mode_realtime || realtime_enemy_spawn_id.is_empty():
		return
	if realtime_enemy_id == "1" && realtime_return_scene.ends_with("fase_1_castle_2.tscn") && realtime_enemy_spawn_id.contains("inimigo_camilita"):
		inimigos_mortos[realtime_enemy_spawn_id] = true
		realtime_enemy_respawns.erase(realtime_enemy_spawn_id)
		realtime_enemy_spawn_id = ""
		return
	if realtime_enemy_id == "1001" || realtime_enemy_spawn_id.contains("inimigo_boss_seco") || realtime_enemy_spawn_id.contains("boss"):
		realtime_enemy_spawn_id = ""
		return
	realtime_enemy_respawns[realtime_enemy_spawn_id] = Time.get_ticks_msec() + int(realtime_enemy_respawn_seconds * 1000.0)
	realtime_enemy_spawn_id = ""

func prepare_realtime_enemy_respawn(enemy:CanvasItem, enemy_spawn_id:String) -> void:
	if battle_mode != battle_mode_realtime || !realtime_enemy_respawns.has(enemy_spawn_id):
		return
	var remaining = get_realtime_enemy_respawn_remaining(enemy_spawn_id)
	if remaining <= 0.0:
		realtime_enemy_respawns.erase(enemy_spawn_id)
		return
	enemy.visible = false
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().create_timer(remaining).timeout.connect(_finish_realtime_enemy_respawn.bind(weakref(enemy), enemy_spawn_id), CONNECT_ONE_SHOT)

func get_realtime_enemy_respawn_remaining(enemy_spawn_id:String) -> float:
	if !realtime_enemy_respawns.has(enemy_spawn_id):
		return 0.0
	return maxf(0.0, (int(realtime_enemy_respawns[enemy_spawn_id]) - Time.get_ticks_msec()) / 1000.0)

func _finish_realtime_enemy_respawn(enemy_reference:WeakRef, enemy_spawn_id:String) -> void:
	var remaining = get_realtime_enemy_respawn_remaining(enemy_spawn_id)
	if remaining > 0.0:
		get_tree().create_timer(remaining).timeout.connect(_finish_realtime_enemy_respawn.bind(enemy_reference, enemy_spawn_id), CONNECT_ONE_SHOT)
		return
	realtime_enemy_respawns.erase(enemy_spawn_id)
	var enemy = enemy_reference.get_ref()
	if !is_instance_valid(enemy):
		return
	enemy.visible = true
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	if enemy.has_method("resetEnemy"):
		enemy.resetEnemy()

func restore_realtime_player_position() -> void:
	if !realtime_restore_pending || get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path != realtime_return_scene:
		return
	var player_node = get_tree().current_scene.get_node_or_null(realtime_return_player_path)
	if !(player_node is Node2D):
		player_node = find_realtime_player(get_tree().current_scene)
	if player_node is Node2D:
		player_node.global_position = realtime_return_player_position
		if player_node is CharacterBody2D:
			player_node.velocity = Vector2.ZERO
		var player_camera = player_node.find_child("Camera2D", true, false)
		if player_camera is Camera2D:
			player_camera.make_current()
		realtime_restore_frames -= 1
		if realtime_restore_frames <= 0:
			realtime_restore_pending = false
