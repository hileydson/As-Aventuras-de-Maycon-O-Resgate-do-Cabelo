extends Control
@onready var me: Control = $"."

var menu = preload("res://scenes/pause.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	#block input e add pause
	Global.before_prologo = true
	var menu_instance = menu.instantiate()
	add_child(menu_instance)
	menu_instance.get_node("pause_animation").play("intro")
	menu_instance.get_node("black_screen/maycon").play("idle")
	get_viewport().gui_disable_input = true
	await get_tree().create_timer(10.0).timeout
	Global.before_prologo = false 
	get_viewport().gui_disable_input = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
