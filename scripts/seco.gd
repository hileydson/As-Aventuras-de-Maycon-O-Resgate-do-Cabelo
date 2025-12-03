extends AnimatedSprite2D
@onready var animated_sprite_2d: AnimatedSprite2D = $"."







func _on_ready() -> void:
	animated_sprite_2d.play("idle")
