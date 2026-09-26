extends SceneTree

func _init():
	var p = load("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
	var inst: Node3D = p.instantiate()
	root.add_child(inst)
	var mi: MeshInstance3D = inst.find_child("char1", true, false)
	if mi and mi.mesh:
		print("Surface count: ", mi.mesh.get_surface_count())
		for s in range(mi.mesh.get_surface_count()):
			var mat = mi.get_surface_override_material(s)
			if not mat:
				mat = mi.mesh.surface_get_material(s)
			print("Surface %d mat: %s" % [s, mat])
			if mat is BaseMaterial3D:
				print(" - albedo texture: ", mat.albedo_texture)
				print(" - albedo color: ", mat.albedo_color)
	quit(0)
