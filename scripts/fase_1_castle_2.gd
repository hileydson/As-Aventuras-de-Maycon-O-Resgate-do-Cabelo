extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var inimigos: Node = $Inimigos
@onready var axe_area: Area2D = $axe_area
@onready var caixa_to_carry: RigidBody2D = $caixa_to_carry

var played_axe:bool = false
var aconteceu_animacao_axe:bool = false

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
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout
	
	played_axe = Global.maycon_itens["axe"]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.maycon_itens["axe"]==false && Global.game_events["gilhotina_broken"]==false:
		axe_area.visible = true
	else:
		axe_area.visible = false
	
	if Global.battle_started == false && played_axe==false && !inimigos.has_node("inimigo_camilita") && Global.maycon_itens["axe"]==false && Global.game_events["gilhotina_broken"]==false:
		played_axe = true
		animacoes.play("axe_fall")
		
	
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
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_3.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn")


func _on_axe_area_body_entered(body: Node2D) -> void:
	if aconteceu_animacao_axe && animacoes.animation_finished:
		Global.maycon_itens["axe"] = true
		Global.game_events["axe_taken"] = true


func _on_animacoes_animation_finished(anim_name: StringName) -> void:
	if anim_name == "axe_fall":
		aconteceu_animacao_axe = true
