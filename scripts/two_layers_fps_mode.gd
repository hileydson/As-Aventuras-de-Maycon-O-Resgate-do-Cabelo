extends Node3D

@onready var sub_viewport_container_2: SubViewportContainer = $VBoxContainer/SubViewportContainer2

@onready var viewport1: SubViewport = $VBoxContainer/SubViewportContainer1/SubViewport1
@onready var viewport2: SubViewport = $VBoxContainer/SubViewportContainer2/SubViewport2

@export var world_scene: PackedScene 
@export var player_scene: PackedScene 

var world_instance
var p1
var p2
var p2_ativado = false # Trava para ativar apenas uma vez

func _input(event):
	# Detecta o botão START apenas no Controle 2 (device 1)
	if event is InputEventJoypadButton:
		if event.device == 1 and event.button_index == JOY_BUTTON_START and event.pressed:
			if not p2_ativado:
				ativar_segunda_tela()

func ativar_segunda_tela():
	p2_ativado = true
	sub_viewport_container_2.visible = true
	setup_cameras(p1, p2)
	print("Segunda tela ativada pelo Controle 2!")

func _ready():
	# Inicialização do mundo
	world_instance = world_scene.instantiate()
	viewport1.add_child(world_instance)
	
	# Configuração do Viewport 2 (Compartilhando o mundo do 1)
	viewport2.world_3d = viewport1.world_3d
	viewport2.own_world_3d = false
	viewport2.transparent_bg = false 
	
	# Esconde a segunda tela por padrão
	sub_viewport_container_2.visible = false
	
	await get_tree().process_frame
	spawn_players_initial()
# .find_child("CharacterBody3D")
func spawn_players_initial():
	p1 = player_scene.instantiate()
	p1.name = "Player1"
	world_instance.add_child(p1)
	
	p2 = player_scene.instantiate()
	p2.name = "Player2"
	world_instance.add_child(p2)
	
	# Aguarda um frame para o motor de física reconhecer os novos nós
	await get_tree().process_frame
	
	# Define as posições (aumentei o Y para 5 para garantir que caiam no chão)
	# E afastei mais no X (5 metros) para não colidirem um com o outro no nascimento
	p1.global_position = Vector3(0, 5, 0)
	p2.global_position = Vector3(5, 5, 0)
	
	if p1.has_method("set_device_id"): p1.set_device_id(0)
	if p2.has_method("set_device_id"): p2.set_device_id(1)

func setup_cameras(p1_node, p2_node):
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
