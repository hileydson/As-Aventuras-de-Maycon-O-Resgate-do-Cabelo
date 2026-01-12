extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var fase_1_before_castle: Sprite2D = $"."
@onready var mk_dudun: AudioStreamPlayer = $MkDudun
@onready var fade: Node2D = $"../fade"
@onready var camera_temp: Camera2D = $Camera_temp
@onready var msg_block: Label = $Camera_temp/msg_block
@onready var barulho_gilhotina: AudioStreamPlayer = $"../BarulhoGilhotina"
@onready var gilhotina_broken: Node2D = $gilhotina_broken
@onready var guilhote: AnimatedSprite2D = $guilhote
@onready var guilhote_temp: AnimatedSprite2D = $Camera_temp/guilhote2
@onready var axe: AnimatedSprite2D = $Camera_temp/axe
@onready var breaking: AnimatedSprite2D = $Camera_temp/breaking

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "2"
	
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout
	
	if Global.game_events["gilhotina_broken"]:
		barulho_gilhotina.stop()

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

	if Global.game_events["gilhotina_broken"] == false:
		guilhote.visible = true
		gilhotina_broken.visible = false
	else:
		gilhotina_broken.visible = true
		guilhote.visible = false


func _on_next_scene_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_2.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_no_fire_2.tscn")


func _on_block_gilhotina_body_entered(body: Node2D) -> void:
	
	if !Global.maycon_itens["axe"] && Global.game_events["gilhotina_broken"] == false:
		Global.battle_started = true # para pausar maycon
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout 
		camera_temp.enabled = true
		camera_temp.make_current()
		
		if Global.default_language == Global.language_pt_br:
			msg_block.text = "Não consigo passar por aqui... \nPreciso de algo para quebrar isso..."
		else:
			msg_block.text = "I can't get throuhg here... \nI need something to break it..."
		
		msg_block.visible = true
		await get_tree().create_timer(5.0).timeout
		msg_block.visible = false
		await get_tree().create_timer(1.0).timeout
		Global.battle_started = false
		get_tree().reload_current_scene()
	
	if Global.maycon_itens["axe"] && Global.game_events["gilhotina_broken"] == false:
		guilhote_temp.visible = true
		axe.visible = true
		barulho_gilhotina.stop()
		Global.battle_started = true # para pausar maycon
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout 
		camera_temp.enabled = true
		camera_temp.make_current()
		animacoes.play("axe_break")
		await get_tree().create_timer(4.0).timeout 
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout 
		Global.battle_started = false
		Global.game_events["gilhotina_broken"] = true
		Global.maycon_itens["axe"] = false
		get_tree().reload_current_scene()
		
		
