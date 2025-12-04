extends Node2D

var damage_count_drop_hp:int = 0

func add_damage()->void:
	damage_count_drop_hp = damage_count_drop_hp+1

func reset_damage()->void:
	damage_count_drop_hp = 0
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
