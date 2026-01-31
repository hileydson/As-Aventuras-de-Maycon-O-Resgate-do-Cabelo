extends Area3D
@onready var gun_load: AudioStreamPlayer = $"../GunLoad"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node3D) -> void:
	Global.maycon_pegou_bullet = true
	gun_load.play()
	queue_free()
