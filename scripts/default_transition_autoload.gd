extends Node2D

# Load the transition at runtime, outside the editor's export/autoload rebuild.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var scene := load("res://scenes/default_transition_fade_in.tscn") as PackedScene
	if scene == null:
		return
	var transition := scene.instantiate()
	for node in transition.find_children("*", "", true, false):
		node.owner = null
	for child in transition.get_children():
		transition.remove_child(child)
		add_child(child)
	transition.free()
