extends AnimatedSprite2D
@onready var hp: AnimatedSprite2D = $"."
@onready var explosao: AudioStreamPlayer = $"../explosao"

var primeira_vez = true
var suppress_next_explosion_sound:bool = false

func _on_animation_finished() -> void:
	hp.visible = false


func _on_animation_changed() -> void:
	if primeira_vez == true && Global.battle_started==true:
		primeira_vez = false
		if suppress_next_explosion_sound:
			suppress_next_explosion_sound = false
		else:
			explosao.play()

func suppress_explosion_sound_once() -> void:
	suppress_next_explosion_sound = true
	explosao.stop()
		
