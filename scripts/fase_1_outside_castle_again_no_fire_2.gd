extends Sprite2D

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var fase_1_before_castle: Sprite2D = $"."
@onready var mk_dudun: AudioStreamPlayer = $MkDudun
@onready var inimigo_boss_seco: AnimatedSprite2D = $Inimigos/inimigo_boss_seco
@onready var explotion: AnimatedSprite2D = $explotion
@onready var explotion_2: AnimatedSprite2D = $explotion2
@onready var explotion_3: AnimatedSprite2D = $explotion3
@onready var seco_camera: Camera2D = $Inimigos/inimigo_boss_seco/seco_camera
@onready var inimigos: Node = $Inimigos

@onready var breaking_glass: AudioStreamPlayer = $BreakingGlass
@onready var start_seco_break_capsule: Area2D = $start_seco_break_capsule
@onready var sangue_fill_scene: Node2D = $"../sangue_fill_scene"

func taken_hp(taken_hp):
	Global.game_events["taken_hp_fase_1_outside_castle_again_no_fire_2"]=true
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.save_progress(get_tree().current_scene.name)
	
	if Global.game_events["taken_hp_fase_1_outside_castle_again_no_fire_2"]:
		$"../sangue_fill_scene".queue_free()
	else:
		sangue_fill_scene.get_node("sangue_fill").taken_hp.connect(taken_hp)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "2"
	
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout


	if Global.game_events["seco_break_capsule"]==false:
		$smoke.visible = true
		$ScarySmile.play()
		$sound_seco_capsule.play()
	else:
		start_seco_break_capsule.queue_free()
		
		if inimigos.has_node("inimigo_boss_seco"):
			inimigo_boss_seco.visible = true
			inimigo_boss_seco.flip_h = true
			$smoke.visible = false
			$ScarySmile.stop()
			$sound_seco_capsule.play()
		else:
			$smoke.visible = false
			$ScarySmile.stop()
			$sound_seco_capsule.stop()

		
	
	
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
	get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_3.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_1.tscn")


func reset_maycon_motion()->void:
	Global.battle_started = false

func _on_start_seco_break_capsule_body_entered(body: Node2D) -> void:
	#start scene seco break capsule
	$"../maycon_itens".get_node("canvas").visible = false
	inimigo_boss_seco.get_node("hps").visible = false
	Global.battle_started = true
	explotion.play("default")
	explotion_2.play("default")
	explotion_3.play("default")
	breaking_glass.play()
	await get_tree().create_timer(3.0).timeout 
	seco_camera.make_current()
	animacoes.play("seco_break_capsule")
	Global.game_events["seco_break_capsule"] = true
	Global.save_progress(get_tree().current_scene.name)
	start_seco_break_capsule.queue_free()
	await get_tree().create_timer(6.0).timeout 
	inimigo_boss_seco.flip_h = true
	inimigo_boss_seco.get_node("hps").visible = true
	$"../maycon_itens".get_node("canvas").visible = true
	
	
	
	
