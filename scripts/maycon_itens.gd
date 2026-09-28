extends Node2D


@onready var layer: TextureRect = $canvas/layer
@onready var axe: AnimatedSprite2D = $canvas/layer/axe
var realtime_hp_bar:ProgressBar
var realtime_hp_label:Label

func _ready() -> void:
	build_realtime_hp_display()


func _process(delta: float) -> void:
	
	if get_tree().paused:
		layer.visible = false
	else:
		layer.visible = true
	
	if Global.maycon_itens["axe"] && Global.battle_started == false:
		axe.visible = true
	else:
		axe.visible = false
	
	var realtime = Global.battle_mode == Global.battle_mode_realtime
	$canvas/layer/maycon_hp/hp_1.visible = !realtime && Global.maycon_hp_count<=2
	$canvas/layer/maycon_hp/hp_2.visible = !realtime && Global.maycon_hp_count<=1
	$canvas/layer/maycon_hp/hp_3.visible = !realtime && Global.maycon_hp_count<=0
	if realtime_hp_bar:
		realtime_hp_bar.visible = realtime
		realtime_hp_label.visible = realtime
		realtime_hp_bar.value = Global.realtime_hp
		realtime_hp_label.text = tr("BATTLE_HP_LABEL")

func build_realtime_hp_display() -> void:
	realtime_hp_bar = ProgressBar.new()
	realtime_hp_bar.position = Vector2(-542, 397)
	realtime_hp_bar.size = Vector2(190, 19)
	realtime_hp_bar.show_percentage = false
	realtime_hp_bar.max_value = Global.realtime_hp_max
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.02, 0.03, 0.9)
	background.border_color = Color(1, 1, 1, 0.65)
	background.set_border_width_all(2)
	background.set_corner_radius_all(5)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color("b3132b")
	fill.set_corner_radius_all(4)
	realtime_hp_bar.add_theme_stylebox_override("background", background)
	realtime_hp_bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(realtime_hp_bar)
	realtime_hp_label = Label.new()
	realtime_hp_label.position = Vector2(-542, 370)
	realtime_hp_label.size = Vector2(190, 24)
	realtime_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	realtime_hp_label.add_theme_font_size_override("font_size", 15)
	realtime_hp_label.add_theme_color_override("font_color", Color("ffd6dc"))
	layer.add_child(realtime_hp_label)
