extends SceneTree

var failures:int = 0
func _init() -> void:
	call_deferred("run")
func check(message:String, passed:bool) -> void:
	print(("OK " if passed else "FAIL ") + message)
	if !passed: failures += 1
func run() -> void:
	# Exercise the real debug signal and callbacks without writing player saves.
	var fixture:GDScript = GDScript.new()
	fixture.source_code = "extends \"res://scripts/Global.gd\"\nfunc save_settings()->void: pass\nfunc save_to_player_savegame()->void: pass\nfunc _show_debug_mode_toast()->void: pass\n"
	assert(fixture.reload() == OK)
	var global:Node = root.get_node("Global")
	global.set_script(fixture)
	var history:Array = ["blue_key", "red_key"]
	global.game_events["dungeon_key_pickup_order"] = history.duplicate()
	global.game_events["cidade_test_metadata"] = {"count":2}
	var dialog:Node = load("res://scenes/menus/configuracoes_dialog.tscn").instantiate()
	root.add_child(dialog)
	paused = true
	for action:String in ["ui_right","ui_right","ui_left","ui_left","ui_up","ui_up","ui_down","ui_down"]:
		var event:InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = true
		global.check_debug_activation(event)
	check("debug activates while paused with key history present", global.show_debug_tab && !dialog.tab_container.is_tab_hidden(dialog._debug_tab_index()))
	var key_toggle:CheckBox
	var metadata_toggle:bool = false
	for child:Node in dialog.debug_events_container.get_children():
		if child is CheckBox && !child.is_queued_for_deletion():
			metadata_toggle = metadata_toggle || child.text in ["dungeon_key_pickup_order","cidade_test_metadata"]
			if child.text == "dungeon_blue_key_taken": key_toggle = child
	check("metadata is excluded from boolean event switches", !metadata_toggle)
	check("ordinary dungeon event switch remains available", is_instance_valid(key_toggle))
	if is_instance_valid(key_toggle):
		key_toggle.button_pressed = !key_toggle.button_pressed
		check("ordinary event switch still updates its boolean flag", global.game_events["dungeon_blue_key_taken"] == key_toggle.button_pressed)
	check("key history remains intact", global.game_events["dungeon_key_pickup_order"] == history)
	check("dictionary metadata remains intact", global.game_events["cidade_test_metadata"] == {"count":2})
	paused = false
	dialog.free()
	print("DEBUG KEY HISTORY: %d failures" % failures)
	quit(0 if failures==0 else 1)
