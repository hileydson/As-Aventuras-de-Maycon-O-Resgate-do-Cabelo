extends Control
@onready var pause_animation: AnimationPlayer = $pause_animation
@onready var camera: Camera2D = $black_screen/camera
@onready var maycon: AnimatedSprite2D = $black_screen/maycon

@onready var space_keys: Label = $black_screen/space_keys
@onready var powers: Label = $black_screen/powers
@onready var pause: Label = $black_screen/pause

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.default_language == Global.language_pt_br:
		space_keys.text = "espaço"
		powers.text = " CHUTE \n SOCO \n\n\n PULO"
		pause.text = "CONTROLE"
	else:
		space_keys.text = "space"
		powers.text = " KICK \n PUNCH \n\n\n JUMP"
		pause.text = "CONTROLS"

	await get_tree().create_timer(6.0).timeout
	get_tree().change_scene_to_file("res://scenes/game.tscn")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
