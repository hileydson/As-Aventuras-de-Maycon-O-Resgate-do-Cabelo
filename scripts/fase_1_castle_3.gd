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

var texture_no_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_no_fire_paralax.png")
var texture_with_fire = preload("res://assets/novas_imagens/cenarios/in_use/fase_1/fase_1_castle_3_paralax.png")

const FOREGROUND_NO_FIRE_Y_OFFSET := 10.0

var temp_canvas_layer_fogo = canvas_layer
var portal_funcionar:bool = true
var foreground_position: Vector2
var foreground2_position: Vector2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var initial_foreground: Sprite2D = get_node_or_null("../BurntForestForeground/Foreground")
	var initial_foreground2: Sprite2D = get_node_or_null("../BurntForestForeground/Foreground2")
	if initial_foreground:
		foreground_position = initial_foreground.position
	if initial_foreground2:
		foreground2_position = initial_foreground2.position
	
	# SET CAIXA OU QUEUEFREE SE NAO TIVER TRAGO A CAIXA
	if Global.game_events["caixa_to_carry_moved"]:
		portal_funcionar = false
		Global.game_events["caixa_to_carry_moved"] = false
	else:
		portal_funcionar = true
		caixa_to_carry.queue_free() 
	
	if Global.back_to_fase:
		portal_funcionar = false
	
	Global.save_progress(get_tree().current_scene.name)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"
	
	if Global.back_to_fase == true:
		Global.battle_background = "2"
		Global.back_to_fase = false
		var foreground = get_node_or_null("../BurntForestForeground/Foreground")
		var foreground2 = get_node_or_null("../BurntForestForeground/Foreground2")
		if foreground:
			foreground.texture = texture_no_fire
		if foreground2:
			foreground2.texture = texture_no_fire
		fase_1_before_castle.texture = null
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(portal_funcionar)
	#print(Global.game_events["gilhotina_broken"] or Global.game_events["axe_taken"] or Global.back_to_fase)
	
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
	
	if portal_funcionar == false:
		return
	
	portal_funcionar = false
	
	mk_dudun.play()
	GameSongs.stop(1)
	
	if canvas_layer :
		canvas_layer.queue_free()
	else :
		add_child(temp_canvas_layer_fogo)
		
	var foreground: Sprite2D = get_node_or_null("../BurntForestForeground/Foreground")
	var foreground2: Sprite2D = get_node_or_null("../BurntForestForeground/Foreground2")
	
	var is_no_fire: bool = false
	if foreground and foreground.texture == texture_no_fire:
		is_no_fire = true
	elif fase_1_before_castle.texture == texture_no_fire:
		is_no_fire = true
	
	if is_no_fire:
		Global.battle_background = "1"
		if foreground:
			foreground.texture = texture_with_fire
			foreground.position = foreground_position
		if foreground2:
			foreground2.texture = texture_with_fire
			foreground2.position = foreground2_position
		fase_1_before_castle.texture = null
		cabelo.visible = true
		smoke.visible = true
		fogos.visible = true
	else:
		Global.battle_background = "2"
		if foreground:
			foreground.texture = texture_no_fire
			foreground.position = foreground_position + Vector2(0, FOREGROUND_NO_FIRE_Y_OFFSET)
		if foreground2:
			foreground2.texture = texture_no_fire
			foreground2.position = foreground2_position + Vector2(0, FOREGROUND_NO_FIRE_Y_OFFSET)
		fase_1_before_castle.texture = null
		cabelo.visible = false
		smoke.visible = false
		fogos.visible = false
		if inimigos != null:
			inimigos.queue_free()
