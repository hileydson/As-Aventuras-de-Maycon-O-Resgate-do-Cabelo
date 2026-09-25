extends SceneTree

func _init():
	for path in ["res://assets/horror_creatures/infected_zombie_animated.glb", "res://assets/horror_creatures/plague_hound_clean.glb", "res://assets/horror_creatures/horror_mutant.glb"]:
		var res = load(path)
		print("=== Checking in Godot: ", path, " ===")
		if res:
			var inst = res.instantiate()
			print("Instantiated: ", inst.name)
			print_children_recursive(inst, "  ")
			var ap = inst.find_child("AnimationPlayer", true, false)
			if ap:
				print("AnimationPlayer found! Animations: ", ap.get_animation_list())
			else:
				print("NO AnimationPlayer found!")
			inst.queue_free()
		else:
			print("FAILED TO LOAD!")
	quit(0)

func print_children_recursive(node: Node, indent: String):
	for c in node.get_children():
		print(indent, "- ", c.name, " (", c.get_class(), ")")
		if c.get_child_count() > 0:
			print_children_recursive(c, indent + "  ")
