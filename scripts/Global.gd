extends Node

const language_pt_br = "PT-BR"
const language_en = "EN"

var load_from_castle_1:bool = false

var is_two_player_active = false
var back_to_main_camera = false
var back_to_fase = false
var from_slum = false
var battle_background:String = "1" # default o cenario de fogo fora do castelo
var battle_next_enemy:String = "0"
var battle_next_boss:int = 0
var battle_started:bool = false
var last_fase = "fase_1"
var block_pause_before_prologo = false
#var before_prologo:bool = false #TESTE - correto eh TRUE

var maycon_danos_first_3d_battle:int = 0
var seco_danos_first_3d_battle:int = 0
var maycon_pegou_lamp_3d_world:bool = false
var maycon_pegou_gas_3d_world:bool = false
var maycon_pegou_lamp_fire_3d_world:bool = false
var maycon_pegou_arma_first_3d_battle:bool = false
var maycon_pegou_bullet:bool = false

# data to be saved
var can_load:bool = false
var save_array = {}
var default_language:String = language_pt_br
var maycon_hp_count:int = 0
var maycon_itens_default = {axe=false}
var game_stage_1_events_died_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_first_scene_castle=true, first_battle=false, before_prologo=false}
var maycon_itens = {axe=false}
var game_events_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true}
var game_events = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true}
var inimigos_mortos = {}


func reset_default_values()->void:
	back_to_main_camera = false
	back_to_fase = false
	from_slum = false
	battle_background = "1" # default o cenario de fogo fora do castelo
	battle_next_enemy = "0"
	battle_next_boss = 0
	battle_started = false
	last_fase = "fase_1"
	block_pause_before_prologo = false

	maycon_danos_first_3d_battle = 0
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

func reset_save_to_castle_1()->void:
	maycon_danos_first_3d_battle = 0
	seco_danos_first_3d_battle = 0
	maycon_pegou_lamp_3d_world = false
	maycon_pegou_gas_3d_world = false
	maycon_pegou_lamp_fire_3d_world = false
	maycon_pegou_arma_first_3d_battle = false
	maycon_pegou_bullet = false
	
	maycon_hp_count = 0	
	maycon_itens = maycon_itens_default
	game_events = game_stage_1_events_died_default
	inimigos_mortos = {}
	save_progress("castelo_1")
	
func reset_save_to_fase_1()->void:
	maycon_hp_count = 0	
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
	save_array["default_language"] = default_language
	save_array["maycon_itens"] = maycon_itens
	save_array["game_events"] = game_events
	save_array["inimigos_mortos"] = inimigos_mortos
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
			last_fase = save_array["last_fase"]
			maycon_hp_count = save_array["maycon_hp_count"]
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
