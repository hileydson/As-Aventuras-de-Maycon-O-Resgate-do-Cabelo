extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/camera_maycon

#var battle = preload("res://scenes/batalha_2d.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = 0
	animacoes.play("maycon_falling")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra VOLTAR
	if Global.battle_next_enemy == 0 && 1==2 :#battle.get_state():
		pass#if !camera.is_current():
			#camera.make_current()
	
	if Global.battle_next_enemy != 0:
		print(Global.battle_next_enemy)
		#Global.battle_next_enemy = 0
		#filePath.insta
		#Batalha2d.instanci
		#get_tree().paused = true
##		add_child(battle.instantiate())

		
	#if !maycon_falling.is_playing() && maycon_falling.animation != "on_gound":
	#maycon_falling.play("on_gound")


func _on_next_scene_body_entered(body: Node2D) -> void:
	print("next scene")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()
