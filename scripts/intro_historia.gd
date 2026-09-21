extends Control
@onready var texto: Label = $black_screen/texto
@onready var fade: Node2D = $black_screen/auto_fade_in

const skip_hold_time:float = 1.0
var skip_progress:float = 0.0
var skip_bar:ProgressBar
var skip_label:Label
var skipping:bool = false
var skip_interface_revealed:bool = false


func build_skip_interface() -> void:
	skip_label = Label.new()
	skip_label.position = Vector2(326, 552)
	skip_label.size = Vector2(500, 32)
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_label.text = "SEGURE ESC / START PARA PULAR" if Global.default_language == Global.language_pt_br else "HOLD ESC / START TO SKIP"
	skip_label.add_theme_font_size_override("font_size", 18)
	skip_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.92, 0.88))
	skip_label.z_index = 100
	skip_label.visible = false
	$black_screen.add_child(skip_label)
	skip_bar = ProgressBar.new()
	skip_bar.position = Vector2(426, 590)
	skip_bar.size = Vector2(300, 8)
	skip_bar.min_value = 0.0
	skip_bar.max_value = skip_hold_time
	skip_bar.show_percentage = false
	skip_bar.z_index = 100
	skip_bar.visible = false
	$black_screen.add_child(skip_bar)

func _input(event:InputEvent) -> void:
	if skip_interface_revealed || skipping:
		return
	if (event is InputEventKey || event is InputEventJoypadButton) && event.pressed:
		skip_interface_revealed = true
		skip_label.visible = true
		skip_bar.visible = true


func fade_after_msg_replaced()->void:
	fade.get_node("Transition").play("fade_in")
	await get_tree().create_timer(5.0).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	build_skip_interface()
	var time:int = 7
	var pt_br:bool = Global.default_language == Global.language_pt_br

	texto.text = "Após Cabelo ser capturado" if pt_br else "After Cabelo has been captured"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Maycon o procurou por toda parte" if pt_br else "Maycon searched for him everywhere"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Procurou por toda grande Bela Aurora" if pt_br else "He searched all over the great Bela Aurora"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Restando apenas a pracinha da Bela" if pt_br else "With only Bela's little square remaining"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Em um último suspiro Maycon foi lá..." if pt_br else "With his last breath, Maycon went there..."
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout

	texto.visible = false
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if skipping:
		return
	if Input.is_action_pressed("ui_cancel"):
		skip_progress = minf(skip_hold_time, skip_progress + delta)
	else:
		skip_progress = maxf(0.0, skip_progress - delta * 2.5)
	skip_bar.value = skip_progress
	if skip_progress >= skip_hold_time:
		skipping = true
		Global.block_pause_before_prologo = false
		get_viewport().gui_disable_input = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")
