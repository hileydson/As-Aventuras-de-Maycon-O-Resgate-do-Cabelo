extends Node3D

@onready var viewport1: SubViewport = $VBoxContainer/SubViewportContainer1/SubViewport1
@onready var container2: SubViewportContainer = $VBoxContainer/SubViewportContainer2
@onready var viewport2: SubViewport = $VBoxContainer/SubViewportContainer2/SubViewport2

@export var world_scene: PackedScene 
@export var player_scene: PackedScene 

var world_instance 

func _ready():
	# 1. Instancia o mundo e coloca no Viewport 1
	world_instance = world_scene.instantiate()
	viewport1.add_child(world_instance)
	
	# 2. Sincroniza o mundo para que o 2 veja o que o 1 vê
	viewport2.world_3d = viewport1.world_3d
	
	# 3. Garante que as telas apareçam (Tira o modo Shape/Cinza)
	container2.visible = false # Começa escondido

func _input(event):
	# Teste com a tecla "P" do teclado ou START do controle 2
	if (event is InputEventKey and event.pressed and event.keycode == KEY_P) or \
	   (event is InputEventJoypadButton and event.device == 1 and event.button_index == JOY_BUTTON_START and event.pressed):
		if not container2.visible:
			print("Chamando spawn_player_2...")
			spawn_player_2()

func spawn_player_2():
	container2.visible = true
	
	# FORÇAR MUNDO (Isso traz a "vida" e texturas de volta)
	viewport2.own_world_3d = false
	viewport2.world_3d = viewport1.world_3d
	
	var p2 = player_scene.instantiate()
	
	# IMPORTANTE: Seta o ID ANTES de adicionar ao mundo
	if p2.has_method("set_device_id"):
		p2.set_device_id(1)
		
	world_instance.add_child(p2)
	
	# CÂMERA (Fazendo a tela de baixo enxergar o mundo)
	var cam_p2 = p2.find_child("Camera3D", true, false)
	if cam_p2:
		# Criamos um Remote para a câmera não se perder
		var remote = RemoteTransform3D.new()
		p2.add_child(remote) 
		
		cam_p2.get_parent().remove_child(cam_p2)
		viewport2.add_child(cam_p2)
		
		await get_tree().process_frame
		remote.remote_path = cam_p2.get_path()
		
		# Garante que o ambiente (luz/céu) seja copiado da câmera 1
		var cam_p1 = world_instance.get_node("maycon_3d").find_child("Camera3D")
		if cam_p1 and cam_p1.environment:
			cam_p2.environment = cam_p1.environment
			
		cam_p2.make_current()
		
