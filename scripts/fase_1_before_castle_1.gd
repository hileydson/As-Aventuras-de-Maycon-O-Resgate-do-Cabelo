extends Sprite2D
@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = 0
	animacoes.play("maycon_falling")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(Global.battle_next_enemy)
	#if !maycon_falling.is_playing() && maycon_falling.animation != "on_gound":
	#maycon_falling.play("on_gound")


func _on_next_scene_body_entered(body: Node2D) -> void:
	print("next scene")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()
