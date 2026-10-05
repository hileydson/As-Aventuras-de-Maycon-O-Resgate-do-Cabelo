extends Node3D

@export_range(0.0, 3.0, 0.05) var intensidade_luz_ambiente:float = 0.5

@onready var sangue_fill_effect: AudioStreamPlayer = $SangueFillEffect
@onready var sliding: AudioStreamPlayer = $Sliding
@onready var label_3d: Label3D = $paredes/Label3D
@onready var prompt: Control = $escada/prompt
@onready var msg_prompt: Label = $escada/prompt/msg_prompt
@onready var fade: Node2D = $fade
@onready var passagem_pestilenta: Label = $passagem_pestilenta
@onready var subindo_escada: AudioStreamPlayer = $SubindoEscada
@onready var blackout: ColorRect = $blackout
@onready var to_hide: CSGBox3D = $paredes/to_hide
@onready var pause_3d: Node3D = $pause_3d

var fim_cenario_3d:bool = false
var objective_label:Label
var objective_key:String = ""

func _ready() -> void:
	$WorldEnvironment.environment.ambient_light_energy = intensidade_luz_ambiente
	GameSongs.stop(1)
	build_objective_hint()
	# As paredes já possuem colisores manuais. Desabilita os duplicados gerados
	# pelos CSGs, que criavam degraus invisíveis e prendiam o jogador nas quinas.
	for wall in $paredes.get_children():
		if wall is CSGBox3D:
			wall.use_collision = false
	
	label_3d.text = tr("LABEL_YOU_SUCK")
	msg_prompt.text = tr("PROMPT_CLIMB_STAIRS")
	
	var player = get_tree().get_first_node_in_group("player")
	player.safe_margin = 0.06
	player.lamp_light.omni_range = 7.0
	player.lamp_light.light_energy = 2.0
	player.get_node("hud_canvas").get_node("maycon_hp").visible = false
	player.get_node("hud_canvas").get_node("control_gun").visible = false
	
	sliding.play()
	await get_tree().create_timer(2.1).timeout
	Global.finish_well_entry_scream(0.3)
	sangue_fill_effect.play()
	sliding.stop()
	Input.start_joy_vibration(0,0.5, 0.7, 0.3)
	get_tree().get_first_node_in_group("player").aplicar_shake(0.9)
	
	passagem_pestilenta.text = tr("LEVEL_PESTILENT_PASSAGE")
	
	await get_tree().create_timer(2.0).timeout
	passagem_pestilenta.visible = true
	await get_tree().create_timer(5.0).timeout
	passagem_pestilenta.visible = false
	

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	update_objective_hint()
	if Global.maycon_pegou_lamp_3d_world && fim_cenario_3d==false:
		player.get_node("hud_canvas").get_node("control_lamp").visible = true
		if to_hide:
			to_hide.queue_free()
	else:
		player.get_node("hud_canvas").get_node("control_lamp").visible = false
	
	if prompt.visible && !fim_cenario_3d:
		if Input.is_action_pressed("ui_accept"):
			if pause_3d:
				pause_3d.queue_free()
			fim_cenario_3d = true
			get_tree().get_first_node_in_group("player").process_mode = Node.PROCESS_MODE_DISABLED
			fade.get_node("Transition").play("fade_out")
			await get_tree().create_timer(2.0).timeout
			subindo_escada.play()
			blackout.visible = true
			await get_tree().create_timer(3.0).timeout
			Global.fade_out_sound(subindo_escada, 4.0)
			await get_tree().create_timer(3.0).timeout
			Global.from_slum = true
			Global.game_events["passagem_pestilenta_feita"] = true
			Global.save_progress("fase_3")
			get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")


func build_objective_hint() -> void:
	var layer:CanvasLayer = CanvasLayer.new()
	layer.name = "PassageObjective"
	layer.layer = 5
	add_child(layer)
	objective_label = Label.new()
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-360, 72)
	objective_label.size = Vector2(720, 70)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.add_theme_font_size_override("font_size", 24)
	objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_label.add_theme_constant_override("outline_size", 5)
	layer.add_child(objective_label)
	update_objective_hint()

func update_objective_hint() -> void:
	var key:String = ""
	if !fim_cenario_3d && Global.maycon_pegou_lamp_3d_world:
		if Global.maycon_pegou_lamp_fire_3d_world:
			key = "PASSAGE_FIND_EXIT"
		elif Global.maycon_pegou_gas_3d_world:
			key = "PASSAGE_FIND_FIRE"
		else:
			key = "PASSAGE_FIND_FUEL"
	if key == objective_key:
		return
	objective_key = key
	objective_label.text = tr(key) if !key.is_empty() else ""
	objective_label.visible = !key.is_empty()
	if objective_label.visible:
		objective_label.modulate.a = 0.0
		create_tween().tween_property(objective_label, "modulate:a", 1.0, 0.45)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		prompt.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		prompt.visible = false

func _exit_tree() -> void:
	Global.finish_well_entry_scream(0.1)
