extends Area2D
@onready var sangue_fill: Area2D = $"."
@onready var sangue_sprite: AnimatedSprite2D = $sangue_sprite
@onready var buttons: Node2D = $buttons

var played:bool = false

func _process(delta: float) -> void:
	
	if sangue_fill.get_overlapping_bodies().size() >0 && played==false:
		buttons.visible = true
		if Input.is_action_pressed("ui_accept"):
			played = true
			buttons.visible = false
			Global.maycon_hp_count = 0
			$SangueFillEffect.play()
			sangue_sprite.play("fill")
			await get_tree().create_timer(3.0).timeout
			queue_free()
	else:
		if played == false:
			buttons.visible = false
