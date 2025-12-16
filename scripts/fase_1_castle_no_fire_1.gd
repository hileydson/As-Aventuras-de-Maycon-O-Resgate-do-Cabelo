extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var fase_1_before_castle: Sprite2D = $"."
@onready var mk_dudun: AudioStreamPlayer = $MkDudun

var texture_no_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_no_fire.png")
var texture_with_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_3.png")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = 0
	
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	#pra VOLTAR
	if Global.back_to_main_camera:
		Global.back_to_main_camera = false
		camera.make_current()



func _on_next_scene_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_no_fire_2.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_3.tscn")
