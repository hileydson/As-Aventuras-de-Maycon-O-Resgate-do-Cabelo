extends Node3D


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D && Global.maycon_pegou_gas_3d_world:
		if Global.maycon_pegou_lamp_3d_world:
			Global.maycon_pegou_lamp_fire_3d_world = true
