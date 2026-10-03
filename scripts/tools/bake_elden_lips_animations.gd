extends SceneTree

# Execute após importar os GLBs exportados por build_elden_lips_assets.py.
func _init() -> void:
	call_deferred("bake")

func bake() -> void:
	var controller:Node3D = load("res://scripts/3D/resgate_cabeludo/elden_lips.gd").new()
	for prefix in ["maycon","lips"]:
		var original_path := "res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb" if prefix=="maycon" else "res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb"
		var rig:Node3D = load(original_path).instantiate()
		var player := rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
		var skeleton := rig.find_child("Skeleton3D",true,false) as Skeleton3D
		var generated:PackedScene = load("res://assets/modelo_3d/elden_lips/"+prefix+"_combat.glb")
		controller._load_animations(generated,player,skeleton,prefix)
		var library := player.get_animation_library("elden")
		var error := ResourceSaver.save(library,"res://assets/modelo_3d/elden_lips/"+prefix+"_combat.res")
		if error!=OK:
			push_error("Failed to bake "+prefix)
			quit(1)
			return
		print(prefix,": ",library.get_animation_list().size()," animations saved")
		rig.free()
	controller.free()
	quit()
