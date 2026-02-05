extends Control

@export var load_from_castle_1:bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.load_from_castle_1 = load_from_castle_1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
