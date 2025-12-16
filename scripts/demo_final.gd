extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra VOLTAR do inicio
	await get_tree().create_timer(5.0).timeout 
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	
