extends AnimatedSprite2D
@onready var hp: AnimatedSprite2D = $"."
@onready var explosao: AudioStreamPlayer = $"../explosao"

var primeira_vez = true

func _on_animation_finished() -> void:
	hp.visible = false


func _on_animation_changed() -> void:
	if primeira_vez == true && Global.battle_started==true:
		primeira_vez = false
		explosao.play()
		
