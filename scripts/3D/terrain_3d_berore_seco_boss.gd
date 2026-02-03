extends Node3D


@onready var arma: Area3D = $Area3D
@onready var gun_load: AudioStreamPlayer = $GunLoad
@onready var maycon_3d: Node3D = $maycon_3d
@onready var you_died: Label = $you_died
@onready var fade: Node2D = $fade
@onready var respaw: Timer = $respaw
@onready var respaw_sound: AudioStreamPlayer = $respaw_sound
@onready var caminho_das_pedras: Label = $caminho_das_pedras
@onready var chao: Terrain3D = $NavigationRegion3D/Terrain3D
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# Arraste o arquivo .tscn do seu inimigo para cá no Inspetor
@export var inimigo_scene: PackedScene 
@export var inimigo_scene_2: PackedScene 
var enemy_chance:bool = false

# Referência ao nó que contém os pontos de spawn
#@onready var pontos_container = $"."
var pontos_container

var enemies_count:int = 0

func remove_enemies_count()->void:
	enemies_count -=1
		
	

func _ready() -> void:
	
	Global.maycon_danos_first_3d_battle = 0
	Global.maycon_pegou_arma_first_3d_battle = false
	
	if Global.default_language == Global.language_pt_br:
		caminho_das_pedras.text = "Caminho das Pedras"
	
	await get_tree().create_timer(1.0).timeout
	caminho_das_pedras.visible = true
	await get_tree().create_timer(3.0).timeout
	caminho_das_pedras.visible = false
	
	# --- O PULO DO GATO ---
	# Espera um frame para o Godot registrar a colisão da lava no servidor de física
	await get_tree().process_frame
	
	# 4. Agora sim, gera a malha de navegação (Aparecerá o AZUL no Debug)
	nav_region.bake_navigation_mesh()
	
	await get_tree().create_timer(5.0).timeout
	respaw.start()

func maycon_died()->void:
	if Global.default_language != Global.language_en:
			you_died.text = "VOCÊ MORREU!"
	you_died.visible = true
	
	maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("hud_canvas").visible = false
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_1.tscn") 
	# Called every frame. 'delta' is the elapsed time since the previous frame.
	
func _process(delta: float) -> void:
	
	# YOU DIED
	if Global.maycon_danos_first_3d_battle == 5:
		maycon_died()
	
	#print("DANOS SECO: -> "+str(Global.seco_danos_first_3d_battle))
	
	if Global.maycon_pegou_arma_first_3d_battle && arma:
		arma.queue_free()
	

func _on_area_3d_body_entered(body: Node3D) -> void:
	Global.maycon_pegou_arma_first_3d_battle = true
	gun_load.play()
	maycon_3d.get_node("CharacterBody3D").add_bullets_to_gun(5)
	
func _on_respaw_timeout() -> void:
	if enemies_count < 10:
		respaw_sound.play()
	
		var novo_inimigo
		if enemy_chance:
			enemy_chance = false
			novo_inimigo = inimigo_scene.instantiate()
		else:
			enemy_chance = true
			novo_inimigo = inimigo_scene_2.instantiate()
			
		#muda a velocidade do inimigo
		novo_inimigo.get_node("CharacterBody3D").velocidade = 4.2
		add_child(novo_inimigo)

		# --- NOVA LÓGICA PARA TERRAIN3D ---

		# 1. Defina o tamanho da área de spawn (em metros) manualmente
		# Já que o terreno não tem "size" fixo como uma caixa
		var area_spawn = 50.0 

		# 2. Gera X e Z aleatórios ao redor do centro do terreno
		var x_aleatorio = randf_range(-area_spawn, area_spawn)
		var z_aleatorio = randf_range(-area_spawn, area_spawn)

		var pos_x = chao.global_position.x + x_aleatorio
		var pos_z = chao.global_position.z + z_aleatorio

		# 3. Pega a altura exata do terreno naquela coordenada (muito importante!)
		# O Terrain3D tem uma função própria para te dar o Y do chão
		# Em vez de chao.storage.get_height...
		
		# Tente acessar diretamente a propriedade 'storage' sem funções
		var altura_y = 0.0
		if chao.get("storage"): 
			altura_y = chao.get("storage").get_height(Vector3(pos_x, 0, pos_z))
		else:
			# Se ainda assim falhar, vamos imprimir o que o nó tem dentro para descobrir
			altura_y = 10.0 # Valor de segurança

		# 4. Define a posição final (colocamos +1.0 no Y para o inimigo não nascer preso no chão)
		novo_inimigo.global_position = Vector3(pos_x, altura_y + 1.0, pos_z)

		enemies_count += 1


func _on_back_again_timeout() -> void:
	nav_region.bake_navigation_mesh()
	print("baked again!")
