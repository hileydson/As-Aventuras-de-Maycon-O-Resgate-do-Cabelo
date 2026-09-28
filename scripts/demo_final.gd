extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var end_demo_thanks: Label = $end_demo_thanks
@onready var label: Label = $Label

var time_to_skip:bool = false
func _ready() -> void:
	await get_tree().create_timer(25.0).timeout 
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra tela inicial
	if time_to_skip and Input.is_action_just_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
	


func _on_node_2d_ready() -> void:
	
	label.text = tr("GAME_TITLE")
	end_demo_thanks.text = tr("GAME_SUBTITLE")
	
	#Global.reset_save_to_fase_1()
	await get_tree().create_timer(7.0).timeout 
	label.visible = true
	await get_tree().create_timer(3.0).timeout 
	end_demo_thanks.visible = true
	
	

func _on_end_movie_animation_finished(anim_name: StringName) -> void:
	if anim_name == "the_end":
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
