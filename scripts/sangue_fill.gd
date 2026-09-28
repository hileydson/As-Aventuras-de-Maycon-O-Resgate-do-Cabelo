extends Area2D
@onready var sangue_fill: Area2D = $"."
@onready var sangue_sprite: AnimatedSprite2D = $sangue_sprite
@onready var buttons: Node2D = $buttons

var heal_hint: Label

signal taken_hp
var played:bool = false

func _ready() -> void:
	heal_hint = Label.new()
	heal_hint.text = tr("BLOOD_FIRE_HEAL_HINT")
	heal_hint.position = Vector2(-150.0, -72.0)
	heal_hint.size = Vector2(300.0, 44.0)
	heal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heal_hint.add_theme_font_size_override("font_size", 17)
	heal_hint.add_theme_color_override("font_color", Color("ffd4a3"))
	heal_hint.add_theme_color_override("font_shadow_color", Color(0.08, 0.01, 0.0, 0.95))
	heal_hint.add_theme_constant_override("shadow_offset_x", 2)
	heal_hint.add_theme_constant_override("shadow_offset_y", 2)
	heal_hint.visible = false
	add_child(heal_hint)

func _process(delta: float) -> void:
	if sangue_fill.get_overlapping_bodies().size() >0 && played==false:
		buttons.visible = true
		heal_hint.visible = true
		if Input.is_action_pressed("ui_accept"):
			taken_hp.emit(true)
			played = true
			buttons.visible = false
			heal_hint.visible = false
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
			heal_hint.visible = false
