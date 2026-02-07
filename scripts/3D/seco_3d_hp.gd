extends Area3D

@onready var barra_vida: ProgressBar = $"../../CanvasLayer/ProgressBar"
@onready var growl_fino: AudioStreamPlayer = $"../../Growl_fino"
@onready var seco_died: Label = $"../../seco_died"
@onready var blackout: ColorRect = $"../../ColorRect"
@onready var canvas_layer: CanvasLayer = $"../../CanvasLayer"
@onready var final_msg: Label = $"../../ColorRect/final_msg"
@onready var final_msg_2: Label = $"../../ColorRect/final_msg2"

var hp:int = 100

func receber_dano(dano:int)->void:
	#hp -= dano
	hp -= 90 # TESTE
	
	# 0.2 de velocidade (bem lento) por 0.3 segundos reais
	efeito_camera_lenta(0.2, 0.3)
	
	# Garante que a vida não fique negativa
	hp = clamp(hp, 0, 100)
	
	# Atualiza o visual da barra
	atualizar_barra()
	
	if hp <= 0:
		morrer()
	
	
func efeito_camera_lenta(intensidade: float, duracao: float):
	# intensidade 0.1 é muito lento, 0.5 é metade da velocidade
	Engine.time_scale = intensidade
	
	# Criamos um timer que IGNORE a escala de tempo, 
	# senão ele também demoraria para acabar.
	await get_tree().create_timer(duracao, true, false, true).timeout
	
	# Volta para a velocidade normal
	Engine.time_scale = 1.0
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func atualizar_barra():
	growl_fino.play()
	# O Tween faz a barra descer suavemente em vez de um corte seco
	var tween = create_tween()
	tween.tween_property(barra_vida, "value", hp, 0.2)

func morrer():
	
	if Global.is_two_player_active:
		for p in get_tree().get_nodes_in_group("player"):
			p.find_child("hud_canvas").visible = false
			
		get_tree().get_first_node_in_group("two_layers_fps_mode").find_child("SubViewportContainer2").visible = false
	
	if Global.default_language != Global.language_en:
			seco_died.text = "DERROTADO!"
			seco_died.visible = true
			final_msg.text = " OLINDÃO FUGIU!"
			final_msg_2.text = "EU AINDA TE PEGO SEU MALDITO!"
			
	$"../../..".process_mode = Node.PROCESS_MODE_DISABLED
	$"../../../../maycon_3d".process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
	canvas_layer.visible = false
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("hud_canvas").visible = false
	$"../../../../fade".get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	
	#cena de encerramento 
	blackout.visible = true
	final_msg.visible = true
	
	await get_tree().create_timer(4.0).timeout 
	final_msg_2.visible = true
	await get_tree().create_timer(4.0).timeout 
	$"../../../../fade".get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	
	Global.game_events["seco_first_scene_castle"]=true
	Global.save_progress("castelo_1")
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn") 
