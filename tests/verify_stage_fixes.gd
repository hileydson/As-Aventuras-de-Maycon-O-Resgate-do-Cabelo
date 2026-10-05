extends SceneTree

var failures:int = 0
func _init() -> void:
	call_deferred("run")
func check(label:String, value:bool) -> void:
	print(("OK " if value else "FAIL ") + label)
	if !value: failures += 1
func fixture(path:String, overrides:String) -> GDScript:
	var script:GDScript = GDScript.new()
	script.source_code = 'extends "%s"\n%s' % [path, overrides]
	assert(script.reload() == OK)
	return script
func run() -> void:
	# Keep production save calls in memory throughout this integration check.
	root.get_node("Global").set_script(fixture("res://scripts/Global.gd", "func save_progress(_fase:String)->void: pass\nfunc save_settings()->void: pass\nfunc save_to_player_savegame()->void: pass\n"))
	var global:Node = root.get_node("Global")
	var battle:Node = load("res://scripts/realtime_battle.gd").new()
	battle.enemy_id = "1001"
	global.realtime_return_scene = "res://scenes/fase_1_outside_castle_again_no_fire_2.tscn"
	check("final Seco damage reduced by 15 percent", is_equal_approx(battle.incoming_player_damage(40.0), 34.0))
	global.realtime_return_scene = "res://scenes/fase_1_castle_1.tscn"
	check("other Seco battles retain damage", is_equal_approx(battle.incoming_player_damage(40.0), 40.0))
	global.realtime_return_scene = "res://scenes/fase_1_outside_castle_again_no_fire_2.tscn"
	battle.enemy_id = "1"
	check("other enemies retain damage", is_equal_approx(battle.incoming_player_damage(40.0), 40.0))
	battle.free()
	var dungeon:Node = load("res://scripts/3D/dungeon_prison.gd").new()
	global.game_events["dungeon_key_pickup_order"] = ["blue_key", "red_key"]
	global.game_events["dungeon_blue_key_taken"] = true
	global.game_events["dungeon_red_key_taken"] = true
	global.game_events["dungeon_red_key_used"] = true
	global.game_events["dungeon_red_gate_open"] = true
	dungeon.return_last_collected_key()
	check("death returns only latest key and closes its lock", !global.game_events["dungeon_red_key_taken"] && !global.game_events["dungeon_red_key_used"] && !global.game_events["dungeon_red_gate_open"] && global.game_events["dungeon_blue_key_taken"])
	check("pickup chronology retained", global.game_events["dungeon_key_pickup_order"] == ["blue_key"])
	dungeon.return_last_collected_key()
	check("following death returns next latest key", !global.game_events["dungeon_blue_key_taken"])
	global.game_events["dungeon_key_taken"] = true
	global.game_events["dungeon_cell_key_used"] = true
	dungeon.return_last_collected_key()
	check("legacy saves return cell key and reset its use", !global.game_events["dungeon_key_taken"] && !global.game_events["dungeon_cell_key_used"])
	dungeon.free()
	var fade:Node = load("res://scenes/default_transition_auto_fade_in_long.tscn").instantiate()
	root.add_child(fade)
	var camera:Camera2D = Camera2D.new()
	camera.position = Vector2(2400, 900)
	camera.zoom = Vector2(1.4, 1.4)
	root.add_child(camera)
	camera.make_current()
	await process_frame
	var rect:ColorRect = fade.get_node("Transition/ScreenCanvas/ColorRect")
	check("fade fills viewport despite camera position and zoom", rect.get_global_rect().position.is_equal_approx(Vector2.ZERO) && rect.size.is_equal_approx(root.get_visible_rect().size))
	fade.free()
	camera.free()
	var capsule:Node = fixture("res://scripts/fase_1_outside_castle_again_no_fire_2.gd", "func _ready()->void: pass\n").new()
	capsule.capsule_cutscene_active = true
	global.battle_started = true
	capsule.reset_maycon_motion()
	check("animation callback cannot release cutscene input", global.battle_started)
	capsule.capsule_cutscene_active = false
	capsule.reset_maycon_motion()
	check("ordinary motion reset still works", !global.battle_started)
	capsule.free()
	var outside:Node = load("res://scenes/fase_1_outside_castle_again_no_fire_3.tscn").instantiate()
	outside.get_node("Fase1BeforeCastle").set_script(fixture("res://scripts/fase_1_outside_castle_again_no_fire_3.gd", "func _ready()->void: pass\n"))
	var actor_script:GDScript = GDScript.new()
	actor_script.source_code = "extends CharacterBody2D\n"
	assert(actor_script.reload() == OK)
	outside.get_node("Fase1BeforeCastle/maycon_fase").set_script(actor_script)
	root.add_child(outside)
	current_scene = outside
	await process_frame
	outside.get_node("Pause").processa_pause_unpause()
	check("outside castle 3 has functional pause", paused && outside.get_node("Fase1BeforeCastle/maycon_fase").can_process() == false)
	paused = false
	outside.free()
	var font:FontVariation = load("res://assets/fonts/contrast_menu.tres")
	check("menu preserves original face with improved spacing", font.base_font.resource_path.ends_with("contrast.ttf") && font.spacing_glyph == 1 && font.variation_embolden < 0)
	TranslationServer.set_locale("pt")
	check("final victory translation has two lines", TranslationServer.translate("BATTLE_FINAL_SECO_VICTORY").contains("\n"))
	var invader:Node = fixture("res://scripts/secos_invader.gd", "func _ready()->void: pass\nfunc _spawn_blood(_at:Vector2)->void: pass\nfunc _spawn_sparks(_at:Vector2,_count:int,_color:Color)->void: pass\nfunc _update_hud()->void: pass\n").new()
	root.add_child(invader)
	invader.punch = AudioStreamPlayer.new()
	invader.add_child(invader.punch)
	invader.maycon = AnimatedSprite2D.new()
	invader.add_child(invader.maycon)
	invader.health = 1.0
	invader.max_health = 100.0
	invader.starting_health = 24.0
	global.battle_mode = global.battle_mode_realtime
	invader._take_hit(999.0)
	check("invader lethal hit restores full health before restart", global.realtime_hp == 100.0)
	invader.free()
	print("STAGE FIXES: %d failures" % failures)
	quit(1 if failures else 0)
