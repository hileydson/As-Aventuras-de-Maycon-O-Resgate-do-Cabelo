extends Control
@onready var pause_animation: AnimationPlayer = $pause_animation
@onready var camera: Camera2D = $black_screen/camera
@onready var maycon: AnimatedSprite2D = $black_screen/maycon
@onready var close: Button = $black_screen/VBoxContainer/close
@onready var quit: Button = $black_screen/VBoxContainer/quit
@onready var run_label: Label = $black_screen/run_label
@onready var down_label: Label = $black_screen/down_label
@onready var space_keys: Label = get_node_or_null("black_screen/space_keys")
@onready var powers: Label = $black_screen/powers
@onready var v_box_container: VBoxContainer = $black_screen/VBoxContainer
@onready var pause: Label = $black_screen/pause
@onready var maycon_hp: Node2D = $maycon_hp
var realtime_hp_bar:ProgressBar
var realtime_hp_label:Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_realtime_hp_display()
	update_hp_display()
	if Global.game_events["before_prologo"]==false:
		v_box_container.visible = true
		maycon_hp.visible = true
	else:
		v_box_container.visible = false
		maycon_hp.visible = false
	
	var p3 = tr("POWER_DASH") if Global.battle_mode == Global.battle_mode_realtime else tr("POWER_JUMP")
	powers.text = " " + tr("POWER_PUNCH") + " \n " + tr("POWER_KICK") + " \n\n " + p3
	close.text = tr("MENU_CLOSE")
	
	if Global.game_events["before_prologo"]:
		quit.text = tr("MENU_EXIT")
		pause.text = tr("MENU_CONTROLLER")
	else:
		quit.text = tr("MENU_SAVE_QUIT")
	
	run_label.text = tr("MENU_RUN")
	down_label.text = tr("MENU_CROUCH")
		

func processa_pause_unpause()->void:
	update_hp_display()
	if Global.game_events["before_prologo"]==false:
		v_box_container.visible = true
		maycon_hp.visible = true
	else:
		v_box_container.visible = false
		maycon_hp.visible = false
	
	if get_tree().paused:
			close.release_focus()
			quit.release_focus()
			Global.back_to_main_camera = true
			get_tree().paused = false
			
			if $"../maycon_itens":
				$"../maycon_itens".get_node("canvas").visible = true
	else:
		
		if $"../maycon_itens":
			$"../maycon_itens".get_node("canvas").visible = false
		
		if Global.game_events["before_prologo"]==false:
			update_hp_display()
			
		
		close.grab_focus()
		set_process_mode(Node.PROCESS_MODE_ALWAYS)
		camera.make_current()
		get_tree().paused = true
		pause_animation.stop()
		maycon.stop()
		pause_animation.play("intro")
		maycon.play("idle")
		
		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") && (!Global.battle_started) && !Global.block_pause_before_prologo:
		processa_pause_unpause()
			

func _on_close_pressed() -> void:
	processa_pause_unpause()


func _on_quit_pressed() -> void:
	GameSongs.stop(1)
	Global.back_to_main_camera = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func build_realtime_hp_display() -> void:
	realtime_hp_bar = ProgressBar.new()
	realtime_hp_bar.position = Vector2(42, 603)
	realtime_hp_bar.size = Vector2(205, 24)
	realtime_hp_bar.show_percentage = false
	realtime_hp_bar.max_value = Global.realtime_hp_max
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.025, 0.035, 0.94)
	background.border_color = Color(0.95, 0.95, 1.0, 0.7)
	background.set_border_width_all(2)
	background.set_corner_radius_all(7)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("b3132b")
	fill.set_corner_radius_all(6)
	realtime_hp_bar.add_theme_stylebox_override("background", background)
	realtime_hp_bar.add_theme_stylebox_override("fill", fill)
	maycon_hp.add_child(realtime_hp_bar)
	realtime_hp_label = Label.new()
	realtime_hp_label.position = Vector2(42, 574)
	realtime_hp_label.size = Vector2(205, 28)
	realtime_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realtime_hp_label.add_theme_font_size_override("font_size", 18)
	realtime_hp_label.add_theme_color_override("font_color", Color("ffd6dc"))
	maycon_hp.add_child(realtime_hp_label)

func update_hp_display() -> void:
	var realtime = Global.battle_mode == Global.battle_mode_realtime
	$maycon_hp/hp_1.visible = !realtime && Global.maycon_hp_count<=2
	$maycon_hp/hp_2.visible = !realtime && Global.maycon_hp_count<=1
	$maycon_hp/hp_3.visible = !realtime && Global.maycon_hp_count<=0
	if realtime_hp_bar:
		realtime_hp_bar.visible = realtime
		realtime_hp_bar.max_value = Global.realtime_hp_max
		realtime_hp_bar.value = Global.realtime_hp
		realtime_hp_label.visible = realtime
		realtime_hp_label.text = tr("BATTLE_HP_LABEL")
