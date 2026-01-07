extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var end_demo_thanks: Label = $end_demo_thanks
@onready var label: Label = $Label





# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra VOLTAR do inicio
	await get_tree().create_timer(12.0).timeout 
	if Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	


func _on_node_2d_ready() -> void:
	await get_tree().create_timer(3.0).timeout 
	label.visible = true
	await get_tree().create_timer(3.0).timeout 
	end_demo_thanks.visible = true
