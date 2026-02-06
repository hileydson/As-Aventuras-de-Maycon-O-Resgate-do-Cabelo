extends Node3D

@onready var sub_viewport_container_2: SubViewportContainer = $VBoxContainer/SubViewportContainer2

@onready var viewport1: SubViewport = $VBoxContainer/SubViewportContainer1/SubViewport1
@onready var viewport2: SubViewport = $VBoxContainer/SubViewportContainer2/SubViewport2
@onready var ponto_1: Label = $VBoxContainer/SubViewportContainer1/SubViewport1/ponto_1
@onready var ponto_2: Label = $VBoxContainer/SubViewportContainer2/SubViewport2/ponto_2

@export var world_scene: PackedScene 
@export var player_scene: PackedScene 

var world_instance
var p1
var p2
var p2_ativado = false # Trava para ativar apenas uma vez

func _process(delta: float) -> void:
	pass # print(get_tree().get_nodes_in_group("player").size())

func _input(event):
	# Detecta o botão START apenas no Controle 2 (device 1)
	if event is InputEventJoypadButton:
		if event.device == 1 and event.button_index == JOY_BUTTON_START and event.pressed:
			if not p2_ativado:
				ativar_segunda_tela()

func ativar_segunda_tela():
	await get_tree().process_frame
	p2_ativado = true
	sub_viewport_container_2.visible = true
	spawn_players_initial()
	print("Segunda tela ativada pelo Controle 2!")

func _ready():
	Global.is_two_player_active = false
	
	# Inicialização do mundo
	world_instance = world_scene.instantiate()
	viewport1.add_child(world_instance)
	
	# Configuração do Viewport 2 (Compartilhando o mundo do 1)
	viewport2.world_3d = viewport1.world_3d
	viewport2.own_world_3d = false
	viewport2.transparent_bg = false 
	
	# Esconde a segunda tela por padrão
	sub_viewport_container_2.visible = false
	
	
	# REMOVE PAUSE DO CENARIO ANTERIOR
	world_instance.find_child("pause_3d").queue_free()



func spawn_players_initial():
	Global.is_two_player_active = true 
	
	#p1 = player_scene.instantiate().find_child("CharacterBody3D")
	p1 = player_scene.instantiate()
	p1.name = "Player1"
	world_instance.add_child(p1)
	
	p2 = get_tree().get_first_node_in_group("player")
	p2.name = "Player2"
	#world_instance.add_child(p2)
	
	# Aguarda um frame para o motor de física reconhecer os novos nós
	await get_tree().process_frame
	
	# Define as posições (aumentei o Y para 5 para garantir que caiam no chão)
	# E afastei mais no X (5 metros) para não colidirem um com o outro no nascimento
	#p1.global_position = Vector3(0, 5, 0)
	#p2.global_position = Vector3(-100, -100, -100)
	#p2.global_position = get_tree().get_first_node_in_group("3d_before_seco_respaw_on_p2").global_position
	p1.global_position = get_tree().get_first_node_in_group("3d_before_seco_respaw_on_p1").global_position
	p2.global_position = get_tree().get_first_node_in_group("3d_before_seco_respaw_on_p2").global_position
	
	#p1.global_position = Vector3(1, 5, 1)
	#p2.global_position = Vector3(2, 5, 2)
	
	
	if p1.has_method("set_device_id"): p1.set_device_id(0)
	if p2.has_method("set_device_id"): p2.set_device_id(1)
	
	setup_cameras(p1, p2)
	
	#ajusta canvas layer
	p1.find_child("hud_canvas").custom_viewport = viewport1
	p2.find_child("hud_canvas").custom_viewport = viewport2





func setup_cameras(p1_node, p2_node):
	ponto_1.visible = true
	ponto_2.visible = true
	var cam1 = p1_node.find_child("Camera3D", true, false)
	var cam2 = p2_node.find_child("Camera3D", true, false)
	
	if cam1 and cam2:
		# Player 1 mantém a câmera no Viewport 1
		cam1.make_current()
		
		# --- LÓGICA DO PLAYER 2 ---
		
		# 1. Identificamos quem era o pai da câmera no Maycon antes de movê-la
		var pai_original_da_camera = cam2.get_parent()
		
		# 2. Criamos um Pivot no Viewport 2 para receber a posição
		var cam_pivot = Node3D.new()
		cam_pivot.name = "Cam2Pivot"
		viewport2.add_child(cam_pivot)
		
		# 3. Movemos a câmera para dentro desse Pivot no Viewport
		pai_original_da_camera.remove_child(cam2)
		cam_pivot.add_child(cam2)
		
		# 4. Criamos o RemoteTransform no lugar onde a câmera estava
		var remote = RemoteTransform3D.new()
		pai_original_da_camera.add_child(remote) # Agora não dá erro de null!
		
		# 5. Configuramos o Remote para seguir o Pivot (que carrega a câmera)
		remote.remote_path = cam_pivot.get_path()
		remote.update_rotation = true 
		
		# 6. RECONEXÃO: Dizemos ao script do Maycon que a câmera dele é a que está no Viewport
		p2_node.camera_3d = cam2
		
		# Sincroniza ambiente
		if cam1.environment:
			cam2.environment = cam1.environment
		
		cam2.make_current()
		
func setup_cameras_TEMP(p1_node, p2_node):
	ponto_1.visible = true
	ponto_2.visible = true
	var cam1 = p1_node.find_child("Camera3D", true, false)
	var cam2 = p2_node.find_child("Camera3D", true, false)
	
	if cam1 and cam2:
		# Player 1 mantém a câmera no Viewport 1
		cam1.make_current()
		
		# Player 2 move a câmera para o Viewport 2
		var remote = RemoteTransform3D.new()
		cam2.get_parent().add_child(remote)
		
		var cam2_parent = cam2.get_parent()
		cam2_parent.remove_child(cam2)
		viewport2.add_child(cam2)
		
		remote.remote_path = cam2.get_path()
		
		# Sincroniza ambiente para evitar tela azul/transparente
		if cam1.environment:
			cam2.environment = cam1.environment
		
		cam2.make_current()
	
	
	
