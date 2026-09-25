extends Node

const language_pt_br = "pt"
const language_en = "en"
const language_es = "es"
const language_zh = "zh"
const battle_mode_realtime = "realtime"
const battle_mode_strategic = "strategic"
const realtime_enemy_respawn_seconds:float = 75.0
const WELL_ENTRY_SCREAM:AudioStreamMP3 = preload("res://assets/novos_audios/maycon_falling_fase_1_transition.mp3")

var load_from_castle_1:bool = false
var load_from_outside_1:bool = false

var back_caminho_das_pedras = false
var cena_caminho_das_pedras = false
var cena_first_seco_boss = false
var is_two_player_active = false
var back_to_main_camera = false
var back_to_fase = false
var dungeon_return_pending:bool = false
var from_slum = false
var well_entry_scream:AudioStreamPlayer
var well_entry_scream_tween:Tween
var platform_arrival_pending:bool = false
var platform_pentagrams:int = 0
var platform_pentagram_collected:Dictionary = {}
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
var current_save_slot:int = 1
var in_cutscene:bool = false
var save_array = {}
var default_language:String = language_pt_br
var maycon_hp_count:int = 0
var maycon_itens_default = {axe=false}
var game_stage_1_events_died_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=true, first_battle=false, before_prologo=false, passagem_pestilenta_feita=false,
dungeon_unlocked=false, dungeon_flashlight_taken=false, dungeon_pistol_taken=false, dungeon_gun_taken=false, dungeon_blue_key_taken=false, dungeon_red_key_taken=false, dungeon_green_key_taken=false, dungeon_key_taken=false, dungeon_intro_lever=false, dungeon_blue_lever=false, dungeon_red_lever=false, dungeon_green_lever=false, dungeon_finale_triggered=false, dungeon_axe_door_open=false, dungeon_axe_taken=false}
var game_stage_outside_1_events_died_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=true, gilhotina_broken=true, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=true, first_battle=false, before_prologo=false, passagem_pestilenta_feita=false,
dungeon_unlocked=true, dungeon_flashlight_taken=true, dungeon_pistol_taken=true, dungeon_gun_taken=true, dungeon_blue_key_taken=true, dungeon_red_key_taken=true, dungeon_green_key_taken=true, dungeon_key_taken=true, dungeon_intro_lever=true, dungeon_blue_lever=true, dungeon_red_lever=true, dungeon_green_lever=true, dungeon_finale_triggered=true, dungeon_axe_door_open=true, dungeon_axe_taken=true}
var maycon_itens = {axe=false}
var game_events_default = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true, passagem_pestilenta_feita=false,
dungeon_unlocked=false, dungeon_flashlight_taken=false, dungeon_pistol_taken=false, dungeon_gun_taken=false, dungeon_blue_key_taken=false, dungeon_red_key_taken=false, dungeon_green_key_taken=false, dungeon_key_taken=false, dungeon_intro_lever=false, dungeon_blue_lever=false, dungeon_red_lever=false, dungeon_green_lever=false, dungeon_finale_triggered=false, dungeon_axe_door_open=false, dungeon_axe_taken=false}
var game_events = {taken_hp_fase_1_outside_castle_again_no_fire_2=false, taken_hp_fase_1_castle_1=false, caixa_to_carry_moved=false, 
axe_taken=false, gilhotina_broken=false, seco_break_capsule=false, seco_defeated=false, seco_first_scene_castle=false, first_battle=true, before_prologo=true, passagem_pestilenta_feita=false,
dungeon_unlocked=false, dungeon_flashlight_taken=false, dungeon_pistol_taken=false, dungeon_gun_taken=false, dungeon_blue_key_taken=false, dungeon_red_key_taken=false, dungeon_green_key_taken=false, dungeon_key_taken=false, dungeon_intro_lever=false, dungeon_blue_lever=false, dungeon_red_lever=false, dungeon_green_lever=false, dungeon_finale_triggered=false, dungeon_axe_door_open=false, dungeon_axe_taken=false}
var inimigos_mortos = {}
var realtime_enemy_respawns:Dictionary = {}
var aim_assist_strength:float = 0.6
var show_debug_tab:bool = true
var debug_disable_battles:bool = false
var debug_dungeon_invincible:bool = false

# --- Configurações gráficas (aplicadas em tempo real, ver menu Configurações) ---
const shadow_atlas_sizes:Array[int] = [1024, 2048, 4096]
var gfx_msaa_3d:int = 2 # padrão 4x
var gfx_resolution_scale:float = 1.0
var gfx_shadow_atlas_size:int = 4096
var gfx_glow_override:int = -1 # -1 = respeita o valor original da cena, 0 = forçar desligado, 1 = forçar ligado
var gfx_ssao_override:int = -1
var gfx_msaa_2d:int = 2 # padrão 4x
var gfx_texture_filter_2d:int = 0

var _gfx_defaults_captured:bool = false
var _gfx_defaults:Dictionary = {}

func normalize_language(lang: String) -> String:
	var l = lang.to_lower().strip_edges()
	if l.begins_with("pt"):
		return language_pt_br
	elif l.begins_with("es"):
		return language_es
	elif l.begins_with("zh"):
		return language_zh
	elif l.begins_with("en"):
		return language_en
	return language_pt_br

func set_game_language(lang_code: String, should_save: bool = true) -> void:
	default_language = normalize_language(lang_code)
	TranslationServer.set_locale(default_language)
	if should_save:
		save_settings()

func _ready() -> void:
	capture_graphics_defaults()
	load_settings()
	apply_all_graphics_settings()
	get_tree().node_added.connect(_on_node_added_check_environment)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("gameplay", "aim_assist_strength", aim_assist_strength)
	config.set_value("gameplay", "language", default_language)
	config.set_value("debug", "game_events", game_events)
	config.set_value("graphics", "msaa_3d", gfx_msaa_3d)
	config.set_value("graphics", "resolution_scale", gfx_resolution_scale)
	config.set_value("graphics", "shadow_atlas_size", gfx_shadow_atlas_size)
	config.set_value("graphics", "glow_override", gfx_glow_override)
	config.set_value("graphics", "ssao_override", gfx_ssao_override)
	config.set_value("graphics", "msaa_2d", gfx_msaa_2d)
	config.set_value("graphics", "texture_filter_2d", gfx_texture_filter_2d)
	config.save("user://settings.cfg")
	save_to_player_savegame()

func capture_graphics_defaults() -> void:
	if _gfx_defaults_captured:
		return
	var vp := get_viewport()
	if vp == null:
		return
	_gfx_defaults = {
		"msaa_3d": 2, # padrão do jogo é 4x, não o padrão "sem antialiasing" do motor
		"resolution_scale": vp.scaling_3d_scale,
		"shadow_atlas_size": vp.positional_shadow_atlas_size,
		"msaa_2d": 2, # padrão do jogo é 4x, não o padrão "sem antialiasing" do motor
		"texture_filter_2d": vp.canvas_item_default_texture_filter,
	}
	gfx_msaa_3d = _gfx_defaults["msaa_3d"]
	gfx_resolution_scale = _gfx_defaults["resolution_scale"]
	gfx_shadow_atlas_size = _gfx_defaults["shadow_atlas_size"]
	gfx_msaa_2d = _gfx_defaults["msaa_2d"]
	gfx_texture_filter_2d = _gfx_defaults["texture_filter_2d"]
	_gfx_defaults_captured = true

func apply_all_graphics_settings() -> void:
	capture_graphics_defaults()
	apply_gfx_msaa_3d(gfx_msaa_3d)
	apply_gfx_resolution_scale(gfx_resolution_scale)
	apply_gfx_shadow_atlas_size(gfx_shadow_atlas_size)
	apply_gfx_msaa_2d(gfx_msaa_2d)
	apply_gfx_texture_filter_2d(gfx_texture_filter_2d)
	_apply_environment_overrides(get_active_3d_environment())

func apply_gfx_msaa_3d(value:int) -> void:
	gfx_msaa_3d = value
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = value as Viewport.MSAA

func apply_gfx_resolution_scale(value:float) -> void:
	gfx_resolution_scale = value
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = value

func apply_gfx_shadow_atlas_size(value:int) -> void:
	gfx_shadow_atlas_size = value
	var vp := get_viewport()
	if vp:
		vp.positional_shadow_atlas_size = value

func apply_gfx_msaa_2d(value:int) -> void:
	gfx_msaa_2d = value
	var vp := get_viewport()
	if vp:
		vp.msaa_2d = value as Viewport.MSAA

func apply_gfx_texture_filter_2d(value:int) -> void:
	gfx_texture_filter_2d = value
	var vp := get_viewport()
	if vp:
		vp.canvas_item_default_texture_filter = value as Viewport.DefaultCanvasItemTextureFilter

func get_active_3d_environment() -> Environment:
	var vp := get_viewport()
	if vp == null:
		return null
	var cam := vp.get_camera_3d()
	if cam and cam.environment:
		return cam.environment
	if vp.world_3d and vp.world_3d.environment:
		return vp.world_3d.environment
	return null

func apply_gfx_glow_override(value:int) -> void:
	gfx_glow_override = value
	_apply_environment_overrides(get_active_3d_environment())

func apply_gfx_ssao_override(value:int) -> void:
	gfx_ssao_override = value
	_apply_environment_overrides(get_active_3d_environment())

func _apply_environment_overrides(env:Environment) -> void:
	if env == null:
		return
	if gfx_glow_override != -1:
		env.glow_enabled = (gfx_glow_override == 1)
	if gfx_ssao_override != -1:
		env.ssao_enabled = (gfx_ssao_override == 1)

func _on_node_added_check_environment(node:Node) -> void:
	if node is WorldEnvironment:
		_apply_environment_overrides(node.environment)

func restore_graphics_defaults_3d() -> void:
	capture_graphics_defaults()
	apply_gfx_msaa_3d(_gfx_defaults.get("msaa_3d", 2))
	apply_gfx_resolution_scale(_gfx_defaults.get("resolution_scale", 1.0))
	apply_gfx_shadow_atlas_size(_gfx_defaults.get("shadow_atlas_size", 4096))
	apply_gfx_glow_override(-1)
	apply_gfx_ssao_override(-1)

func _graphics_settings_to_dict() -> Dictionary:
	return {
		"msaa_3d": gfx_msaa_3d,
		"resolution_scale": gfx_resolution_scale,
		"shadow_atlas_size": gfx_shadow_atlas_size,
		"glow_override": gfx_glow_override,
		"ssao_override": gfx_ssao_override,
		"msaa_2d": gfx_msaa_2d,
		"texture_filter_2d": gfx_texture_filter_2d,
	}

func _apply_graphics_settings_from_dict(d:Dictionary) -> void:
	apply_gfx_msaa_3d(int(d.get("msaa_3d", gfx_msaa_3d)))
	apply_gfx_resolution_scale(float(d.get("resolution_scale", gfx_resolution_scale)))
	apply_gfx_shadow_atlas_size(int(d.get("shadow_atlas_size", gfx_shadow_atlas_size)))
	apply_gfx_glow_override(int(d.get("glow_override", gfx_glow_override)))
	apply_gfx_ssao_override(int(d.get("ssao_override", gfx_ssao_override)))
	apply_gfx_msaa_2d(int(d.get("msaa_2d", gfx_msaa_2d)))
	apply_gfx_texture_filter_2d(int(d.get("texture_filter_2d", gfx_texture_filter_2d)))

func restore_graphics_defaults_2d() -> void:
	capture_graphics_defaults()
	apply_gfx_msaa_2d(_gfx_defaults.get("msaa_2d", 2))
	apply_gfx_texture_filter_2d(_gfx_defaults.get("texture_filter_2d", 0))

func save_to_player_savegame() -> void:
	_ensure_legacy_save_migration()
	var path := get_slot_save_path(current_save_slot)
	if FileAccess.file_exists(path) or (current_save_slot == 1 and FileAccess.file_exists("user://savegame.save")):
		var open_path := path if FileAccess.file_exists(path) else "user://savegame.save"
		var file = FileAccess.open(open_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json_text)
			if data is Dictionary:
				data["game_events"] = game_events.duplicate()
				data["aim_assist_strength"] = aim_assist_strength
				data["default_language"] = default_language
				data["graphics_settings"] = _graphics_settings_to_dict()
				data["save_timestamp"] = Time.get_datetime_string_from_system()
				var w_file = FileAccess.open(path, FileAccess.WRITE)
				if w_file:
					w_file.store_line(JSON.stringify(data))
					w_file.close()
					save_array = data
				if current_save_slot == 1:
					var leg_w = FileAccess.open("user://savegame.save", FileAccess.WRITE)
					if leg_w:
						leg_w.store_line(JSON.stringify(data))
						leg_w.close()
				return
	
	if last_fase != "":
		save_progress(last_fase)
	else:
		save_progress("fase_1")

func get_slot_save_path(slot: int = -1) -> String:
	var s: int = slot if slot in [1, 2, 3] else current_save_slot
	return "user://savegame_slot_%d.save" % s

func _ensure_legacy_save_migration() -> void:
	if FileAccess.file_exists("user://savegame.save") and not FileAccess.file_exists("user://savegame_slot_1.save"):
		var f_in := FileAccess.open("user://savegame.save", FileAccess.READ)
		if f_in:
			var txt := f_in.get_as_text()
			f_in.close()
			var f_out := FileAccess.open("user://savegame_slot_1.save", FileAccess.WRITE)
			if f_out:
				f_out.store_string(txt)
				f_out.close()

func has_save_slot(slot: int) -> bool:
	_ensure_legacy_save_migration()
	if slot == 1:
		return FileAccess.file_exists("user://savegame_slot_1.save") or FileAccess.file_exists("user://savegame.save")
	return FileAccess.file_exists("user://savegame_slot_%d.save" % slot)

func has_any_save() -> bool:
	return has_save_slot(1) or has_save_slot(2) or has_save_slot(3)

func get_fase_friendly_name(fase_key: String) -> String:
	var map := {
		"fase_1": "FASE_NAME_FASE_1",
		"fase_2": "FASE_NAME_FASE_2",
		"fase_3": "FASE_NAME_FASE_3",
		"fase_3d_platform": "FASE_NAME_FASE_3D_PLATFORM",
		"fase_4": "FASE_NAME_FASE_4",
		"castelo_1": "FASE_NAME_CASTELO_1",
		"castelo_2": "FASE_NAME_CASTELO_2",
		"castelo_3": "FASE_NAME_CASTELO_3",
		"castelo_no_fire_1": "FASE_NAME_CASTELO_1",
		"castelo_no_fire_2": "FASE_NAME_CASTELO_2",
		"outside_castelo_1": "FASE_NAME_OUTSIDE_1",
		"outside_castelo_2": "FASE_NAME_OUTSIDE_2",
		"outside_castelo_3": "FASE_NAME_OUTSIDE_3",
		"fase_1_before_castle_1": "FASE_NAME_FASE_1",
		"fase_1_before_castle_2": "FASE_NAME_FASE_2",
		"fase_1_before_castle_3": "FASE_NAME_FASE_3",
		"fase_1_before_castle_4": "FASE_NAME_FASE_4",
		"fase_1_castle_1": "FASE_NAME_CASTELO_1",
		"fase_1_castle_2": "FASE_NAME_CASTELO_2",
		"fase_1_castle_3": "FASE_NAME_CASTELO_3",
		"fase_1_castle_no_fire_1": "FASE_NAME_CASTELO_1",
		"fase_1_castle_no_fire_2": "FASE_NAME_CASTELO_2",
		"fase_1_outside_castle_again_no_fire_1": "FASE_NAME_OUTSIDE_1",
		"fase_1_outside_castle_again_no_fire_2": "FASE_NAME_OUTSIDE_2",
		"fase_1_outside_castle_again_no_fire_3": "FASE_NAME_OUTSIDE_3",
		"calabouco_terror": "FASE_NAME_CALABOUCO_TERROR",
	}
	if map.has(fase_key):
		return tr(map[fase_key])
	return fase_key.capitalize()

func get_slot_info(slot: int) -> Dictionary:
	_ensure_legacy_save_migration()
	var path := get_slot_save_path(slot)
	if not FileAccess.file_exists(path):
		if slot == 1 and FileAccess.file_exists("user://savegame.save"):
			path = "user://savegame.save"
		else:
			return {"exists": false}

	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {"exists": false}

	var json_str := f.get_as_text()
	f.close()
	var data = JSON.parse_string(json_str)
	if not (data is Dictionary):
		return {"exists": false}

	var fase: String = str(data.get("last_fase", "fase_1"))
	var date_str: String = str(data.get("save_timestamp", ""))
	if date_str == "":
		var mtime := FileAccess.get_modified_time(path)
		var dt := Time.get_datetime_dict_from_unix_time(mtime)
		date_str = "%02d/%02d/%04d %02d:%02d" % [dt.day, dt.month, dt.year, dt.hour, dt.minute]
	elif date_str.contains("T"):
		var parts := date_str.split("T")
		if parts.size() == 2:
			var d_parts := parts[0].split("-")
			if d_parts.size() == 3:
				var time_part := parts[1].substr(0, 5)
				date_str = "%s/%s/%s %s" % [d_parts[2], d_parts[1], d_parts[0], time_part]

	return {
		"exists": true,
		"last_fase": fase,
		"fase_display": get_fase_friendly_name(fase),
		"date": date_str,
		"hp": float(data.get("realtime_hp", realtime_hp_max)),
		"battle_mode": str(data.get("battle_mode", battle_mode_realtime)),
		"pentagrams": int(data.get("platform_pentagrams", 0))
	}

func delete_save_slot(slot: int) -> bool:
	var path := get_slot_save_path(slot)
	var deleted := false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		deleted = true
	if slot == 1 and FileAccess.file_exists("user://savegame.save"):
		DirAccess.remove_absolute("user://savegame.save")
		deleted = true
	if current_save_slot == slot:
		reset_default_values()
		current_save_slot = 1
	return deleted

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		aim_assist_strength = float(config.get_value("gameplay", "aim_assist_strength", 0.6))
		var saved_lang = str(config.get_value("gameplay", "language", default_language))
		set_game_language(saved_lang, false)
		if config.has_section_key("debug", "game_events"):
			var saved_events = config.get_value("debug", "game_events", null)
			if saved_events is Dictionary:
				for k in saved_events.keys():
					game_events[k] = saved_events[k]
		if config.has_section("graphics"):
			gfx_msaa_3d = int(config.get_value("graphics", "msaa_3d", gfx_msaa_3d))
			gfx_resolution_scale = float(config.get_value("graphics", "resolution_scale", gfx_resolution_scale))
			gfx_shadow_atlas_size = int(config.get_value("graphics", "shadow_atlas_size", gfx_shadow_atlas_size))
			gfx_glow_override = int(config.get_value("graphics", "glow_override", gfx_glow_override))
			gfx_ssao_override = int(config.get_value("graphics", "ssao_override", gfx_ssao_override))
			gfx_msaa_2d = int(config.get_value("graphics", "msaa_2d", gfx_msaa_2d))
			gfx_texture_filter_2d = int(config.get_value("graphics", "texture_filter_2d", gfx_texture_filter_2d))
	else:
		set_game_language(default_language, false)


func _process(_delta: float) -> void:
	restore_realtime_player_position()

func reset_default_values()->void:
	debug_dungeon_invincible = false
	back_to_main_camera = false
	back_to_fase = false
	dungeon_return_pending = false
	from_slum = false
	platform_arrival_pending = false
	platform_pentagrams = 0
	platform_pentagram_collected = {}
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
	save_array["graphics_settings"] = _graphics_settings_to_dict()
	save_array["last_fase"] = fase
	save_array["platform_pentagrams"] = platform_pentagrams
	save_array["platform_pentagram_collected"] = platform_pentagram_collected
	save_array["save_timestamp"] = Time.get_datetime_string_from_system()
	
	var path := get_slot_save_path(current_save_slot)
	var file = FileAccess.open(path, FileAccess.WRITE) 
	if file:
		var json_string = JSON.stringify(save_array) 
		file.store_line(json_string)
		file.close()

	if current_save_slot == 1:
		var leg_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
		if leg_file:
			leg_file.store_line(JSON.stringify(save_array))
			leg_file.close()

func check_load():
	return has_any_save()
	
func fade_out_sound(stream_player: AudioStreamPlayer, duracao: float):
	var tween = create_tween()
	# Faz o volume ir do valor atual até -80 dB (silêncio total)
	if stream_player:
		tween.tween_property(stream_player, "volume_db", -20.0, duracao)

func start_well_entry_scream() -> void:
	if is_instance_valid(well_entry_scream_tween) and well_entry_scream_tween.is_running():
		well_entry_scream_tween.kill()
	if !is_instance_valid(well_entry_scream):
		well_entry_scream = AudioStreamPlayer.new()
		var scream_stream:AudioStreamMP3 = WELL_ENTRY_SCREAM.duplicate()
		scream_stream.loop = true
		well_entry_scream.stream = scream_stream
		add_child(well_entry_scream)
	well_entry_scream.volume_db = -2.0
	well_entry_scream.play()

func finish_well_entry_scream(duration: float = 0.25) -> void:
	if !is_instance_valid(well_entry_scream) || !well_entry_scream.playing:
		return
	if is_instance_valid(well_entry_scream_tween) and well_entry_scream_tween.is_running():
		well_entry_scream_tween.kill()
	well_entry_scream_tween = create_tween()
	well_entry_scream_tween.tween_property(well_entry_scream, "volume_db", -30.0, duration)
	well_entry_scream_tween.tween_callback(well_entry_scream.stop)
	
		
func load_progress(slot: int = -1)->void:
	if slot in [1, 2, 3]:
		current_save_slot = slot
	
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
		_ensure_legacy_save_migration()
		var path := get_slot_save_path(current_save_slot)
		if not FileAccess.file_exists(path) and current_save_slot == 1 and FileAccess.file_exists("user://savegame.save"):
			path = "user://savegame.save"

		if FileAccess.file_exists(path): 
			can_load = true
			var file = FileAccess.open(path, FileAccess.READ) 
			var json_string = file.get_as_text() 
			file.close()
			save_array = JSON.parse_string(json_string)
			
			if save_array.has("default_language"):
				set_game_language(str(save_array["default_language"]), false)
			maycon_itens = save_array["maycon_itens"]
			game_events = game_events_default.duplicate()
			game_events.merge(save_array["game_events"], true)
			inimigos_mortos = save_array["inimigos_mortos"]
			if save_array.has("aim_assist_strength"):
				aim_assist_strength = float(save_array["aim_assist_strength"])
			if save_array.has("graphics_settings") and save_array["graphics_settings"] is Dictionary:
				_apply_graphics_settings_from_dict(save_array["graphics_settings"])
			last_fase = save_array["last_fase"]
			platform_pentagrams = int(save_array.get("platform_pentagrams", 0))
			platform_pentagram_collected = save_array.get("platform_pentagram_collected", {})
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
			elif last_fase == "fase_3d_platform":
				get_tree().change_scene_to_file("res://scenes/3D/maycon_platform_3d.tscn")
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
			elif last_fase == "calabouco_terror":
				get_tree().change_scene_to_file("res://scenes/3D/calabouco_terror.tscn")

func reset_dungeon_events(save_now: bool = true) -> void:
	var dungeon_keys := [
		"dungeon_intro_cutscene_seen", "dungeon_unlocked", "dungeon_flashlight_taken", "dungeon_pistol_taken",
		"dungeon_gun_taken", "dungeon_blue_key_taken", "dungeon_red_key_taken",
		"dungeon_green_key_taken", "dungeon_key_taken", "dungeon_intro_lever",
		"dungeon_blue_lever", "dungeon_red_lever", "dungeon_green_lever",
		"dungeon_red_gate_open", "dungeon_green_gate_open", "dungeon_blue_gate_open",
		"dungeon_red_key_used", "dungeon_green_key_used", "dungeon_blue_key_used", "dungeon_cell_key_used",
		"dungeon_finale_triggered", "dungeon_axe_door_open", "dungeon_axe_taken",
		"axe_taken"
	]
	for k in dungeon_keys:
		game_events[k] = false
	maycon_itens["axe"] = false
	if save_now:
		save_to_player_savegame()
		save_settings()

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

func try_debug_instakill_enemy(enemy_node: Node, enemy_id: String, unique_id: String = "") -> bool:
	if not debug_disable_battles:
		return false
	
	if unique_id != "":
		inimigos_mortos[unique_id] = true
	elif enemy_node and is_instance_valid(enemy_node):
		var generated_id: String = ""
		if enemy_node.get_tree() and enemy_node.get_tree().current_scene:
			generated_id = enemy_node.get_tree().current_scene.name + "_" + str(enemy_node.get_path())
		else:
			generated_id = str(enemy_node.get_path())
		inimigos_mortos[generated_id] = true
	
	if enemy_id == "1001" or (unique_id != "" and unique_id.contains("boss_seco")):
		game_events["seco_defeated"] = true
	
	# Cancela qualquer gatilho pendente de batalha
	battle_next_enemy = "0"
	battle_next_boss = 0
	battle_started = false
	
	# Efeito sonoro de impacto rápido
	var punch_stream = load("res://assets/novos_audios/punch_4.mp3")
	if punch_stream:
		var snd := AudioStreamPlayer.new()
		snd.stream = punch_stream
		snd.volume_db = -3.0
		snd.pitch_scale = randf_range(0.95, 1.15)
		add_child(snd)
		snd.finished.connect(snd.queue_free)
		snd.play()

	if enemy_node and is_instance_valid(enemy_node):
		enemy_node.queue_free()
	
	return true

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
