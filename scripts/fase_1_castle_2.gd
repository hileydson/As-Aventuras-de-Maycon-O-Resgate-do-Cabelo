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
var transitioning_to_dungeon:bool = false

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
	
	if Global.dungeon_return_pending:
		Global.dungeon_return_pending = false
		await play_dungeon_return()
	elif Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout
	
	played_axe = Global.maycon_itens["axe"] || bool(Global.game_events.get("dungeon_unlocked", false))
	aconteceu_animacao_axe = bool(Global.game_events.get("dungeon_unlocked", false))


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
	if transitioning_to_dungeon:
		return
	var in_first_hole:bool = body.global_position.x >= 550.0 && body.global_position.x <= 875.0
	if in_first_hole && bool(Global.game_events.get("dungeon_unlocked", false)):
		transitioning_to_dungeon = true
		Global.save_progress("fase_1_castle_2")
		get_tree().change_scene_to_file("res://scenes/3D/calabouco_terror.tscn")
	else:
		get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn")


func _on_axe_area_body_entered(body: Node2D) -> void:
	# O machado agora só pode ser recuperado dentro do calabouço.
	pass


func _on_animacoes_animation_finished(anim_name: StringName) -> void:
	if anim_name == "axe_fall":
		aconteceu_animacao_axe = true
		Global.game_events["dungeon_unlocked"] = true
		Global.save_progress("fase_1_castle_2")

func play_dungeon_return() -> void:
	maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	maycon_fase.visible = true
	var landing_position := Vector2(-650.0, 98.0)
	# Ele pulou do trampolim lá no calabouço, então tem que subir pelo mesmo buraco por onde caiu, não descer do céu.
	var hole_position := Vector2(landing_position.x, landing_position.y + 160.0)
	var launch_peak := Vector2(landing_position.x, landing_position.y - 340.0)
	maycon_fase.position = hole_position
	camera.make_current()
	var arrival := create_tween()
	arrival.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrival.tween_property(maycon_fase, "position", launch_peak, 0.55)
	arrival.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	arrival.tween_property(maycon_fase, "position", Vector2(landing_position.x, landing_position.y - 40.0), 0.45)
	arrival.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	arrival.tween_property(maycon_fase, "position", landing_position, 0.35)
	await arrival.finished
	maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
