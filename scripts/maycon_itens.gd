extends Node2D


@onready var axe: TextureRect = $CanvasLayer/axe


func _process(delta: float) -> void:
	if Global.maycon_itens["axe"]:
		axe.visible = true
