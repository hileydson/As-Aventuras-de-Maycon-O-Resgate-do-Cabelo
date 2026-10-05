extends SceneTree

func _init() -> void:
	call_deferred("run")
func run() -> void:
	var global:Node = root.get_node("Global")
	global.is_two_player_active = false
	var scene:Node3D = Node3D.new()
	scene.name = "VictoryFixture"
	root.add_child(scene)
	current_scene = scene
	var enemies:Node3D = Node3D.new()
	scene.add_child(enemies)
	var boss:Node3D = Node3D.new()
	enemies.add_child(boss)
	var body:Node3D = Node3D.new()
	boss.add_child(body)
	var hp:Area3D = Area3D.new()
	hp.set_script(load("res://scripts/3D/seco_3d_hp.gd"))
	var canvas:CanvasLayer = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	boss.add_child(canvas)
	var bar:ProgressBar = ProgressBar.new()
	bar.name = "ProgressBar"
	canvas.add_child(bar)
	var sound:AudioStreamPlayer = AudioStreamPlayer.new()
	sound.name = "Growl_fino"
	boss.add_child(sound)
	var message:Label = Label.new()
	message.name = "seco_died"
	boss.add_child(message)
	var blackout:ColorRect = ColorRect.new()
	blackout.name = "ColorRect"
	boss.add_child(blackout)
	for label_name:String in ["final_msg", "final_msg2"]:
		var label:Label = Label.new()
		label.name = label_name
		label.visible = false
		blackout.add_child(label)
	var player:Node3D = Node3D.new()
	player.name = "maycon_3d"
	scene.add_child(player)
	body.add_child(hp)
	Engine.time_scale = 10.0
	hp.morrer()
	await create_timer(4.1).timeout
	var passed:bool = enemies.process_mode == Node.PROCESS_MODE_DISABLED && player.process_mode == Node.PROCESS_MODE_DISABLED && hp.final_msg.visible && !message.visible && blackout.color.a > 0.99
	print("OK disabled boss hierarchy does not stop victory blackout" if passed else "FAIL victory stuck before final message")
	await create_timer(7.8).timeout
	passed = passed && hp.final_msg_2.visible && scene.has_node("PostBossLongFadeOut")
	print("OK both victory messages complete and final fade starts" if passed else "FAIL victory does not reach final fade")
	# Finish before the production transition writes progress; no user saves touched.
	Engine.time_scale = 1.0
	scene.free()
	quit(0 if passed else 1)
