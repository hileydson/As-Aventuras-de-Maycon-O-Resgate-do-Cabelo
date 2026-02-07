extends Area3D
@onready var gun_load: AudioStreamPlayer = $"../GunLoad"
@onready var me: Area3D = $"."


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.maycon_pegou_arma_first_3d_battle:
		me.visible = true
	else:
		me.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.name in ["Maycon", "Cigarro"]:
		#Global.maycon_pegou_bullet = true
		body.add_bullets_to_gun(5) # NAO TA ACHANDO
		gun_load.play()
		queue_free()
