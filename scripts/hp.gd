extends AnimatedSprite2D
@onready var hp: AnimatedSprite2D = $"."
@onready var explosao: AudioStreamPlayer = $"../explosao"

func _on_animation_finished() -> void:
	hp.visible = false


func _on_animation_changed() -> void:
	explosao.play()
