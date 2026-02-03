extends Node3D
@onready var sangue_fill_effect: AudioStreamPlayer = $SangueFillEffect
@onready var sliding: AudioStreamPlayer = $Sliding
@onready var label_3d: Label3D = $paredes/Label3D
@onready var prompt: Control = $escada/prompt
@onready var msg_prompt: Label = $escada/prompt/msg_prompt
@onready var fade: Node2D = $fade
@onready var passagem_pestilenta: Label = $passagem_pestilenta


func _ready() -> void:
	
	if Global.default_language == Global.language_pt_br:
		label_3d.text = "SEU IDIOTA!"
		msg_prompt.text = "subir as escadas?"
	
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("hud_canvas").get_node("maycon_hp").visible = false
	player.get_node("hud_canvas").get_node("control_gun").visible = false
	
	sliding.play()
	await get_tree().create_timer(2.1).timeout
	sangue_fill_effect.play()
	sliding.stop()
	get_tree().get_first_node_in_group("player").aplicar_shake(0.9)
	
	if Global.default_language == Global.language_pt_br:
		passagem_pestilenta.text = "Passagem Pestilenta"
	
	await get_tree().create_timer(2.0).timeout
	passagem_pestilenta.visible = true
	await get_tree().create_timer(5.0).timeout
	passagem_pestilenta.visible = false
	

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if Global.maycon_pegou_lamp_3d_world:
		player.get_node("hud_canvas").get_node("control_lamp").visible = true
	else:
		player.get_node("hud_canvas").get_node("control_lamp").visible = false
	
	if prompt.visible:
		if Input.is_action_pressed("ui_accept"):
			print("subiu escada!")
			
			#IMPLEMENTAR VOLTA PRO 2D
			get_tree().get_first_node_in_group("player").process_mode = Node.PROCESS_MODE_DISABLED
			fade.get_node("Transition").play("fade_out")
			await get_tree().create_timer(2.0).timeout
			Global.from_slum = true
			get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_3.tscn")


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		prompt.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		prompt.visible = false
