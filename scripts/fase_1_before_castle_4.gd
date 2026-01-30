extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var enter_the_castle: ColorRect = $"../enter_the_castle"
@onready var scary_smile: AudioStreamPlayer = $"../enter_the_castle/ScarySmile"
@onready var castle: Label = $"../enter_the_castle/castle"
@onready var loading: AnimatedSprite2D = $"../enter_the_castle/loading"
@onready var canvas_layer: CanvasLayer = $CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_progress(get_tree().current_scene.name)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# previne bug da batalha iniciar e nao haver collision com o maycon
	if Global.battle_started:
		maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
	
	#pra VOLTAR
	if Global.back_to_main_camera:
		Global.back_to_main_camera = false
		camera.make_current()
		
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout	


func load_3d()->void:
	get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")

func _on_next_scene_body_entered(body: Node2D) -> void:	
	$"../maycon_itens".get_node("canvas").visible = false
	canvas_layer.visible = false
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout 
	enter_the_castle.visible = true
	GameSongs.stop(1001)
	scary_smile.play()
	await get_tree().create_timer(0.3).timeout 
	castle.visible = true
	loading.play("default")
	await get_tree().create_timer(3.0).timeout 
	$"../maycon_itens".get_node("canvas").visible = true
	
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn")
	
	# TO DO - 3D PART
	#get_tree().paused = false
	#get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")
