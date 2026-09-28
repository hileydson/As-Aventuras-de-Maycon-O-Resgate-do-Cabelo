extends Control
@onready var me: Control = $"."

var menu = preload("res://scenes/pause.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	#block input e add pause
	Global.game_events["before_prologo"] = true
	Global.block_pause_before_prologo = true
	var menu_instance = menu.instantiate()
	add_child(menu_instance)
	var pause_layer := menu_instance.get_node_or_null("PauseLayer") as CanvasLayer
	if is_instance_valid(pause_layer):
		pause_layer.visible = true
	var maycon := menu_instance.get_node_or_null("PauseLayer/black_screen/maycon") as AnimatedSprite2D
	if is_instance_valid(maycon):
		maycon.position = Vector2(-124.0, 308.0)
		maycon.play("idle")
		var intro := create_tween()
		intro.tween_property(maycon, "position", Vector2(350.0, 308.0), 1.43)
	get_viewport().gui_disable_input = true
	await get_tree().create_timer(10.0).timeout
	var auto_fade := menu_instance.get_node_or_null("PauseLayer/black_screen/auto_fade_in/Transition") as AnimationPlayer
	if is_instance_valid(auto_fade):
		auto_fade.play("fade_out")
	await get_tree().create_timer(2.5).timeout
	Global.game_events["before_prologo"] = true 
	get_viewport().gui_disable_input = false
	Global.block_pause_before_prologo = false
	get_tree().change_scene_to_file("res://scenes/intro_historia.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
