extends SceneTree

func _init():
	var p = load("res://assets/horror_creatures/infected_zombie_animated.glb")
	var inst: Node3D = p.instantiate()
	var rot_basis = Basis(Vector3.RIGHT, deg_to_rad(90))
	var skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	if skel:
		for b in ["CityDeadOutfit_Head", "CityDeadOutfit_Spine", "CityDeadOutfit_LeftArm"]:
			var idx = skel.find_bone(b)
			var pos = rot_basis * skel.get_bone_global_rest(idx).origin
			print(b, " pos with rot X 90: ", pos)
	quit(0)
