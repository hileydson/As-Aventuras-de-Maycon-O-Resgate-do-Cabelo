extends Area2D
@onready var sangue_fill: Area2D = $"."
@onready var sangue_sprite: AnimatedSprite2D = $sangue_sprite
@onready var buttons: Node2D = $buttons

var hint_panel: PanelContainer
var heal_hint: Label

signal taken_hp
var played:bool = false

func _ready() -> void:
	hint_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	style.border_color = Color(0.65, 0.08, 0.12, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	hint_panel.add_theme_stylebox_override("panel", style)
	hint_panel.position = sangue_sprite.position + Vector2(-230.0, 130.0)
	hint_panel.custom_minimum_size = Vector2(460.0, 68.0)
	hint_panel.z_index = 4
	hint_panel.visible = false
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.z_index = 5

	heal_hint = Label.new()
	heal_hint.text = tr("BLOOD_FIRE_HEAL_HINT")
	heal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heal_hint.add_theme_font_size_override("font_size", 24)
	heal_hint.add_theme_color_override("font_color", Color(0.12, 0.03, 0.05, 1.0))
	heal_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(heal_hint)
	add_child(hint_panel)

func _process(delta: float) -> void:
	if sangue_fill.get_overlapping_bodies().size() >0 && played==false:
		buttons.visible = true
		hint_panel.visible = true
		if Input.is_action_pressed("ui_accept"):
			taken_hp.emit(true)
			played = true
			buttons.visible = false
			hint_panel.visible = false
			Global.maycon_hp_count = 0
			Global.realtime_hp = Global.realtime_hp_max
			Global.save_progress(get_tree().current_scene.name)
			$SangueFillEffect.play()
			sangue_sprite.play("fill")
			await get_tree().create_timer(3.0).timeout
			queue_free()
	else:
		if played == false:
			buttons.visible = false
			hint_panel.visible = false
