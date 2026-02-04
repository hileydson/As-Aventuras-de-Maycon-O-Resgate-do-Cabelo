extends Area3D
@onready var me: Area3D = $"."
@onready var sound_lamp: AudioStreamPlayer = $"../sound_lamp"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.maycon_pegou_lamp_3d_world:
		me.visible = true
	else:
		me.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		Global.maycon_pegou_gas_3d_world = true
		sound_lamp.play()
		queue_free()
