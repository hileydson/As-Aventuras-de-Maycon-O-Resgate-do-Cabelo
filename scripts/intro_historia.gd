extends Control
@onready var texto: Label = $black_screen/texto
@onready var fade: Node2D = $black_screen/auto_fade_in


func fade_after_msg_replaced()->void:
	fade.get_node("Transition").play("fade_in")
	await get_tree().create_timer(5.0).timeout
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var time:int = 7
	var pt_br:bool = Global.default_language == Global.language_pt_br

	texto.text = "Após Cabelo ser capturado" if pt_br else "After Cabelo has been captured"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Maycon o procurou por toda parte" if pt_br else "Maycon searched for him everywhere"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Procurou por toda grande Bela Aurora" if pt_br else "He searched all over the great Bela Aurora"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Restando apenas a pracinha da Bela" if pt_br else "With only Bela's little square remaining"
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout
	
	texto.text = "Em um último suspiro Maycon foi lá..." if pt_br else "With his last breath, Maycon went there..."
	fade_after_msg_replaced()
	await get_tree().create_timer(time).timeout

	texto.visible = false
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
