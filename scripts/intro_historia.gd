extends Control
@onready var texto: Label = $black_screen/texto
@onready var fade: Node2D = $black_screen/auto_fade_in

const skip_hold_time:float = 1.1
var skip_progress:float = 0.0
var skip_bar:ProgressBar
var skip_label:Label
var skipping:bool = false
var is_mouse_holding:bool = false


func build_skip_interface() -> void:
	skip_label = Label.new()
	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_label.offset_left = -280.0
	skip_label.offset_top = 18.0
	skip_label.offset_right = -24.0
	skip_label.offset_bottom = 42.0
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.text = tr("UI_HOLD_SKIP")
	skip_label.add_theme_font_size_override("font_size", 13)
	skip_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.92, 0.88))
	skip_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	skip_label.add_theme_constant_override("outline_size", 2)
	skip_label.z_index = 100
	$black_screen.add_child(skip_label)
	skip_bar = ProgressBar.new()
	skip_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_bar.offset_left = -280.0
	skip_bar.offset_top = 46.0
	skip_bar.offset_right = -24.0
	skip_bar.offset_bottom = 51.0
	skip_bar.min_value = 0.0
	skip_bar.max_value = skip_hold_time
	skip_bar.show_percentage = false
	skip_bar.z_index = 100
	$black_screen.add_child(skip_bar)

func _input(event:InputEvent) -> void:
	if skipping:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_mouse_holding = event.pressed


func fade_after_msg_replaced()->void:
	fade.get_node("Transition").play("fade_in")
	await get_tree().create_timer(5.0).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_skip_interface()
	var time:int = 7

	texto.text = tr("STORY_INTRO_1")
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = tr("STORY_INTRO_2")
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = tr("STORY_INTRO_3")
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = tr("STORY_INTRO_4")
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = tr("STORY_INTRO_5")
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout

	texto.visible = false
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if skipping:
		return
	var holding := Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("ui_accept") or is_mouse_holding
	if holding:
		skip_progress = minf(skip_hold_time, skip_progress + delta)
	else:
		skip_progress = maxf(0.0, skip_progress - delta * 2.5)
	skip_bar.value = skip_progress
	if skip_progress >= skip_hold_time:
		skipping = true
		Global.block_pause_before_prologo = false
		get_viewport().gui_disable_input = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")
