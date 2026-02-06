extends Node3D

@onready var viewport1: SubViewport = $VBoxContainer/SubViewportContainer1/SubViewport1
@onready var viewport2: SubViewport = $VBoxContainer/SubViewportContainer2/SubViewport2

@export var world_scene: PackedScene 
@export var player_scene: PackedScene 

var world_instance

func _input(event: InputEvent) -> void:
	print(event)
	
func _ready():
	# 1. Instalação básica
	world_instance = world_scene.instantiate()
	viewport1.add_child(world_instance)
	
	# 2. CONFIGURAÇÃO CRÍTICA DO VIEWPORT 2
	# Forçamos o Viewport 2 a usar o mesmo cenário do 1
	viewport2.world_3d = viewport1.world_3d
	viewport2.own_world_3d = false
	
	# Isso garante que ele não tente ser transparente e mostre o que está atrás
	viewport2.transparent_bg = false 
	viewport2.msaa_3d = viewport1.msaa_3d # Sincroniza qualidade
	
	await get_tree().process_frame
	#spawn_players_initial()

func spawn_players_initial():
	var p1 = player_scene.instantiate()
	p1.name = "Player1"
	world_instance.add_child(p1)
	
	var p2 = player_scene.instantiate()
	p2.name = "Player2"
	world_instance.add_child(p2)
	
	p1.global_position = Vector3(0, 2, 0)
	p2.global_position = Vector3(2, 2, 0)
	
	# Seta IDs (Importante para o script do Maycon que limpamos)
	if p1.has_method("set_device_id"): p1.set_device_id(0)
	if p2.has_method("set_device_id"): p2.set_device_id(1)
	
	setup_cameras(p1, p2)

func setup_cameras(p1, p2):
	var cam1 = p1.find_child("Camera3D", true, false)
	var cam2 = p2.find_child("Camera3D", true, false)
	
	if cam1 and cam2:
		# PLAYER 1
		cam1.make_current()
		
		# PLAYER 2
		var remote = RemoteTransform3D.new()
		cam2.get_parent().add_child(remote)
		
		# Movemos a câmera para o Viewport 2
		cam2.get_parent().remove_child(cam2)
		viewport2.add_child(cam2)
		
		remote.remote_path = cam2.get_path()
		
		# --- O FIX PARA A TRANSPARÊNCIA ---
		# Forçamos a câmera a usar o Environment do mundo
		# Se deixarmos nulo, ela tenta usar o padrão do Viewport (que está vindo azul/transparente)
		if cam1.environment:
			cam2.environment = cam1.environment
		
		cam2.make_current()
