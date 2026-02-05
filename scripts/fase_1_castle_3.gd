extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var fase_1_before_castle: Sprite2D = $"."
@onready var mk_dudun: AudioStreamPlayer = $MkDudun
@onready var cabelo: AnimatedSprite2D = $"../cabelo"
@onready var smoke: AnimatedSprite2D = $"../smoke"
@onready var inimigos: Node = $Inimigos
@onready var fogos: Node2D = $"../fogos"
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var caixa_to_carry: RigidBody2D = $caixa_to_carry

var texture_no_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_no_fire.png")
var texture_with_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_3.png")

var temp_canvas_layer_fogo = canvas_layer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# SET CAIXA OU QUEUEFREE SE NAO TIVER TRAGO A CAIXA
	if Global.game_events["caixa_to_carry_moved"]:
		Global.game_events["caixa_to_carry_moved"] = false
	else:
		caixa_to_carry.queue_free() 
	
	Global.save_progress(get_tree().current_scene.name)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"
	
	if Global.back_to_fase == true:
		Global.battle_background = "2"
		Global.back_to_fase = false
		fase_1_before_castle.texture = texture_no_fire
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout


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



func _on_next_scene_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout 
	GameSongs.stop(1002)
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_no_fire_1.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	
	if body is RigidBody2D:
		Global.game_events["caixa_to_carry_moved"] = true
		
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	GameSongs.play_song(1002)
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")


func _on_division_no_fire_body_exited(body: Node2D) -> void:
	mk_dudun.play()
	GameSongs.stop(1)
	
	if canvas_layer :
		canvas_layer.queue_free()
	else :
		add_child(temp_canvas_layer_fogo)
		
	
	if fase_1_before_castle.texture == texture_no_fire:
		Global.battle_background = "1"
		fase_1_before_castle.texture = texture_with_fire
		cabelo.visible = true
		smoke.visible = true
		fogos.visible = true
	else:
		Global.battle_background = "2"
		fase_1_before_castle.texture = texture_no_fire
		cabelo.visible = false
		smoke.visible = false
		fogos.visible = false
		if inimigos != null:
			inimigos.queue_free()
