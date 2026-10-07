extends Sprite2D

const CONTROLS_INTRO = preload("res://scripts/ui/controls_intro_overlay.gd")
var controls_intro_elapsed: float = 0.0
var tutorial_hints_elapsed: float = 0.0
var tutorial_box_moved: bool = false
var tutorial_box_initial_x: float = 0.0
const SESSION_BOX_NAMES = ["caixa4", "caixa", "caixa2", "caixa3"]
var session_box_slot: String

@onready var tutorial_box: RigidBody2D = $"../caixa4"

@onready var animacoes: AnimationPlayer = $animacoes
@onready var maycon_falling: AnimatedSprite2D = $maycon_falling
@onready var camera: Camera2D = $maycon_fase/Camera2D
@onready var maycon_fase: CharacterBody2D = $maycon_fase
@onready var label_stage_1: Label = $node2d_stage_1_label/label_stage_1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"../tutorial_1/Hint".text = tr("STAGE_1_HINT_BOX")
	$"../tutorial_2/Hint".text = tr("STAGE_1_HINT_JUMP")
	$"../tutorial_3/Hint".text = tr("STAGE_1_HINT_DOUBLE_JUMP")
	$"../tutorial_3/Hint".hide()
	tutorial_box_initial_x = tutorial_box.position.x
	session_box_slot = str(Global.current_save_slot)
	restore_session_boxes()
	if Global.stage_1_title_seen:
		disable_stage_title()
	$"../tutorial_1/Hint".hide()
	$"../tutorial_2/Hint".hide()
	Global.game_events["before_prologo"] = false 
	Global.save_progress(get_tree().current_scene.name)
	
	GameSongs.play_song(1)
	
	label_stage_1.text = " " + tr("LEVEL_OLINDAO_WORLD")
	
	#REINICIA AS BATALHAS
	Global.battle_next_boss = 0
	Global.battle_next_enemy = "0"
	Global.battle_background = "1"
	
	var returning_from_realtime = Global.realtime_restore_pending && Global.realtime_return_scene == get_tree().current_scene.scene_file_path
	if returning_from_realtime:
		animacoes.stop()
		maycon_falling.visible = false
		maycon_fase.visible = true
		maycon_fase.global_position = Global.realtime_return_player_position
		maycon_fase.velocity = Vector2.ZERO
		camera.make_current()
	elif Global.back_to_fase == true:
		Global.back_to_fase = false
		maycon_falling.hide()
		maycon_fase.show()
		maycon_fase.velocity = Vector2.ZERO
		animacoes.play("maycon_back_to_fase")
		animacoes.advance(0.3)
		maycon_fase.get_node("AnimatedSprite2D").flip_h = true
		camera.make_current()
		await get_tree().create_timer(1.0).timeout
	else:
		animacoes.play("maycon_falling")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not Global.stage_1_title_seen and $node2d_stage_1_label.visible:
		Global.stage_1_title_seen = true
		Global.save_progress(get_tree().current_scene.name)
	if not tutorial_box_moved:
		if not is_instance_valid(tutorial_box) or absf(tutorial_box.position.x - tutorial_box_initial_x) > 8.0:
			tutorial_box_moved = true
			$"../tutorial_1/Hint".hide()
	if tutorial_hints_elapsed < 33.0:
		tutorial_hints_elapsed += delta
		if tutorial_hints_elapsed >= 26.0:
			$"../tutorial_1/Hint".visible = not tutorial_box_moved
			$"../tutorial_2/Hint".show()
		if tutorial_hints_elapsed >= 33.0:
			$"../tutorial_3/Hint".show()
	if not Global.stage_1_controls_hint_seen:
		controls_intro_elapsed += delta
		if controls_intro_elapsed >= 12.0 and not Global.battle_started and not Global.in_cutscene and maycon_fase.visible:
			Global.stage_1_controls_hint_seen = true
			get_tree().current_scene.add_child(CONTROLS_INTRO.new())
			Global.save_progress(get_tree().current_scene.name)
	
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
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_2.tscn")


func _on_dead_line_body_entered(body: Node2D) -> void:
	if body != maycon_fase:
		return
	maycon_fase.visible = false
	if Global.stage_1_title_seen:
		disable_stage_title()
	animacoes.play("maycon_falling")
	#get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_1.tscn")


func disable_stage_title() -> void:
	var animation := animacoes.get_animation("maycon_falling").duplicate() as Animation
	for track in range(animation.get_track_count()):
		var path := str(animation.track_get_path(track))
		if path.begins_with("node2d_stage_1_label") or path == "../CanvasLayer/intro_batalha_frozen_effect:visible":
			animation.track_set_enabled(track, false)
		elif path == "maycon_fase" and animation.track_get_type(track) == Animation.TYPE_METHOD:
			for key in range(animation.track_get_key_count(track)):
				if animation.method_track_get_name(track, key) == &"unpause":
					animation.track_set_key_time(track, key, 2.85)
	animation.length = 3.0
	var original_library := animacoes.get_animation_library("")
	var library := AnimationLibrary.new()
	for animation_name in original_library.get_animation_list():
		library.add_animation(animation_name, animation if animation_name == &"maycon_falling" else original_library.get_animation(animation_name))
	animacoes.remove_animation_library("")
	animacoes.add_animation_library("", library)
	$node2d_stage_1_label.hide()
	$node2d_stage_1_label/StageSound.stop()
	$"../CanvasLayer/intro_batalha_frozen_effect".hide()


func restore_session_boxes() -> void:
	var states: Dictionary = Global.stage_1_session_boxes.get(session_box_slot, {})
	for box_name in SESSION_BOX_NAMES:
		var box := get_parent().get_node_or_null(NodePath(box_name)) as RigidBody2D
		if not is_instance_valid(box) or not states.has(box_name):
			continue
		if states[box_name] == null:
			box.queue_free()
		else:
			box.transform = states[box_name]
			box.linear_velocity = Vector2.ZERO
			box.angular_velocity = 0.0


func _exit_tree() -> void:
	if session_box_slot.is_empty():
		return
	var states: Dictionary = {}
	for box_name in SESSION_BOX_NAMES:
		var box := get_parent().get_node_or_null(NodePath(box_name)) as RigidBody2D
		states[box_name] = box.transform if is_instance_valid(box) and not box.is_queued_for_deletion() else null
	Global.stage_1_session_boxes[session_box_slot] = states
