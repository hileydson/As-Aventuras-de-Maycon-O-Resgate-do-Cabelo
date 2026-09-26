extends SceneTree

func _init():
	var p = load("res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb")
	var inst: Node3D = p.instantiate()
	root.add_child(inst)
	var skel: Skeleton3D = null
	for c in inst.find_children("*", "Skeleton3D", true, false):
		skel = c
		break
	if skel == null:
		print("NO SKELETON")
		quit(0)
		return
	print("bone_count=", skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		var rest := skel.get_bone_rest(i)
		print("%d\t%s\tparent=%d\torigin=%s" % [i, skel.get_bone_name(i), skel.get_bone_parent(i), str(rest.origin)])
	quit(0)
