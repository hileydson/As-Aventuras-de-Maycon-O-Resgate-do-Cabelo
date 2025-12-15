extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = 0
	animacoes.play("maycon_falling")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra VOLTAR
	if Global.back_to_main_camera:
		Global.back_to_main_camera = false
		camera.make_current()



func _on_next_scene_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	print("next scene")


func _on_dead_line_body_entered(body: Node2D) -> void:
	maycon_fase.visible = false
	animacoes.play("maycon_falling")
	#get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_1.tscn")
