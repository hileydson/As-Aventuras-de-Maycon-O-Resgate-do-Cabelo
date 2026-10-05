extends Sprite2D

const POST_BOSS_FADE_DURATION:float = 4.0

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var camera_temp: Camera2D = $Camera_temp
@onready var sangue_fill_scene: Node2D = $"../sangue_fill_scene"

func taken_hp(taken_hp):
	Global.game_events["taken_hp_fase_1_castle_1"]=true
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var returning_from_first_seco_battle:bool = Global.cena_first_seco_boss
	Global.cena_first_seco_boss = false
	if Global.game_events.get("seco_first_scene_castle", false):
		if not GameSongs.is_song_playing(1):
			GameSongs.play_song(1)
	else:
		GameSongs.stop(1)
	if returning_from_first_seco_battle:
		_play_post_boss_fade_in()

	Global.save_progress(get_tree().current_scene.name)
	
	if Global.game_events["taken_hp_fase_1_castle_1"]:
		$"../sangue_fill_scene".queue_free()
	else:
		sangue_fill_scene.get_node("sangue_fill").taken_hp.connect(taken_hp)
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"
	
	if Global.back_to_fase == true:
		Global.back_to_fase = false
		animacoes.play("maycon_back_to_fase")
		await get_tree().create_timer(1.0).timeout

func _play_post_boss_fade_in() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.name = "PostBossLongFadeIn"
	fade_layer.layer = 100
	get_tree().current_scene.add_child.call_deferred(fade_layer)

	var fade_rect := ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	await get_tree().process_frame
	var fade_tween := get_tree().create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 0.0, POST_BOSS_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_tween.finished
	fade_layer.queue_free()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# previne bug da batalha iniciar e nao haver collision com o maycon
	if Global.battle_started:
		maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
	
	#pra VOLTAR
	if Global.back_to_main_camera && Global.game_events["seco_first_scene_castle"]:
		Global.back_to_main_camera = false
		camera.make_current()



func _on_next_scene_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_2.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	get_tree().reload_current_scene()


func _on_back_stage_body_entered(body: Node2D) -> void:
	get_tree().paused = true
	Global.back_to_fase = true
	await get_tree().create_timer(0.3).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_4.tscn")
