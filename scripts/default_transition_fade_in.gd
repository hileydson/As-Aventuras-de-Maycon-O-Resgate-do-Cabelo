extends Node2D
@onready var me: AnimationPlayer = $Transition


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	me.play("fade_in")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
