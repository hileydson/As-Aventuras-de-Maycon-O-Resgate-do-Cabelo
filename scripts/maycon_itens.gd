extends Node2D


@onready var layer: TextureRect = $canvas/layer
@onready var axe: AnimatedSprite2D = $canvas/layer/axe


func _process(delta: float) -> void:
	
	if get_tree().paused:
		layer.visible = false
	else:
		layer.visible = true
	
	if Global.maycon_itens["axe"] && Global.battle_started == false:
		axe.visible = true
	else:
		axe.visible = false
	
	$canvas/layer/maycon_hp/hp_1.visible = Global.maycon_hp_count<=2
	$canvas/layer/maycon_hp/hp_2.visible = Global.maycon_hp_count<=1
	$canvas/layer/maycon_hp/hp_3.visible = Global.maycon_hp_count<=0
