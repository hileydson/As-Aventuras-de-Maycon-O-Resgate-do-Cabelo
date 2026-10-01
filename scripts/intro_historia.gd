extends Control

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")

@onready var texto: Label = $black_screen/texto
@onready var fade: Node2D = $black_screen/auto_fade_in

const skip_hold_time: float = 1.1
var skip_progress: float = 0.0
var old_film_layer: CanvasLayer
var ui_layer: CanvasLayer
var skip_container: VBoxContainer
var skip_bar: ProgressBar
var skip_label: Label
var skipping: bool = false
var is_mouse_holding: bool = false


func _create_old_film_filter() -> void:
	old_film_layer = CanvasLayer.new()
	old_film_layer.layer = 10
	add_child(old_film_layer)

	var film_rect := ColorRect.new()
	film_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = OLD_FILM_SHADER
	mat.set_shader_parameter("sepia_amount", 0.48)
	mat.set_shader_parameter("grain_amount", 0.082)
	mat.set_shader_parameter("grain_speed", 24.0)
	mat.set_shader_parameter("vignette_intensity", 0.85)
	mat.set_shader_parameter("vignette_radius", 1.0)
	mat.set_shader_parameter("flicker_intensity", 0.048)
	mat.set_shader_parameter("scratch_intensity", 0.40)
	mat.set_shader_parameter("dust_intensity", 0.45)
	mat.set_shader_parameter("jitter_amount", 0.00065)
	film_rect.material = mat

	old_film_layer.add_child(film_rect)


func build_skip_interface() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 25
	add_child(ui_layer)

	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_control)

	skip_container = VBoxContainer.new()
	skip_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_container.offset_left = -304.0
	skip_container.offset_top = 18.0
	skip_container.offset_right = -48.0
	skip_container.offset_bottom = 58.0
	skip_container.alignment = BoxContainer.ALIGNMENT_CENTER
	skip_container.modulate.a = 0.55
	root_control.add_child(skip_container)

	skip_label = Label.new()
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	skip_label.add_theme_font_size_override("font_size", 13)
	skip_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 0.9))
	skip_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	skip_label.add_theme_constant_override("outline_size", 2)
	skip_label.text = tr("UI_HOLD_SKIP")
	skip_container.add_child(skip_label)

	skip_bar = ProgressBar.new()
	skip_bar.custom_minimum_size = Vector2(0, 5)
	skip_bar.min_value = 0.0
	skip_bar.max_value = skip_hold_time
	skip_bar.value = 0.0
	skip_bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.08, 0.12, 0.55)
	bar_bg.set_corner_radius_all(3)
	skip_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.82, 0.35, 0.95)
	bar_fill.set_corner_radius_all(3)
	skip_bar.add_theme_stylebox_override("fill", bar_fill)

	skip_container.add_child(skip_bar)

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
	_create_old_film_filter()
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
	var holding := Input.is_action_pressed("ui_cancel") or Input.is_action_pressed("ui_accept") or is_mouse_holding or Input.is_joy_button_pressed(0, JOY_BUTTON_B) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if holding:
		skip_progress = minf(skip_hold_time, skip_progress + delta)
		skip_container.modulate.a = 1.0
	else:
		skip_progress = maxf(0.0, skip_progress - delta * 3.0)
		skip_container.modulate.a = lerpf(skip_container.modulate.a, 0.55, delta * 5.0)
	skip_bar.value = skip_progress
	if skip_progress >= skip_hold_time:
		skipping = true
		Global.block_pause_before_prologo = false
		get_viewport().gui_disable_input = false
		get_tree().change_scene_to_file("res://scenes/game.tscn")
