extends Node

func _ready() -> void:
	# O zeramento permanece intacto; a cobertura branca só existe nesta transição.
	var ending:Node = load("res://scenes/demo_end.tscn").instantiate()
	add_child(ending)
	var overlay := CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(white)
	var tween := create_tween()
	tween.tween_property(white, "color:a", 0.0, 4.0)
	tween.tween_callback(overlay.queue_free)
