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
@onready var player_respaw_back: Marker3D = $player_respaw_back
@onready var player_gun_respaw_back: Marker3D = $player_gun_respaw_back

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
	
	if Global.back_to_fase:
		maycon_3d.get_node("CharacterBody3D").rotation_degrees.y += 180
		Global.back_to_fase = false
		maycon_3d.global_position = player_respaw_back.global_position
		arma.global_position = player_gun_respaw_back.global_position
	
	Global.maycon_pegou_lamp_3d_world = false
	Global.maycon_pegou_lamp_fire_3d_world = false
	Global.maycon_pegou_arma_first_3d_battle = false
	
	if Global.default_language == Global.language_pt_br:
		caminho_das_pedras.text = "Caminho das Pedras"
	
	await get_tree().create_timer(2.0).timeout
	caminho_das_pedras.visible = true
	await get_tree().create_timer(5.0).timeout
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
	if Global.is_two_player_active && Global.players_dead_count > 1:
		maycon_died()
	elif !Global.is_two_player_active && Global.players_dead_count > 0:
		maycon_died()
	
	
	#print("DANOS SECO: -> "+str(Global.seco_danos_first_3d_battle))
	
	if Global.maycon_pegou_arma_first_3d_battle && arma:
		arma.queue_free()
	

func _on_area_3d_body_entered(body: Node3D) -> void:
	Global.maycon_pegou_arma_first_3d_battle = true
	gun_load.play()
	#get_tree().get_first_node_in_group("two_layers_fps_mode").find_child("")
	body.add_bullets_to_gun(5)
	
func _on_respaw_timeout() -> void:
	if enemies_count < 20:
		# 1. Busca a posição atual do jogador
		var player = get_tree().get_first_node_in_group("player")
		if not player: return # Se o player não existir, não spawna nada

		respaw_sound.play()
	
		var novo_inimigo
		if enemy_chance:
			enemy_chance = false
			novo_inimigo = inimigo_scene.instantiate()
		else:
			enemy_chance = true
			novo_inimigo = inimigo_scene_2.instantiate()
			
		# Adiciona o inimigo na cena primeiro para poder acessar os nós dele
		add_child(novo_inimigo)
		
		# Ajusta velocidade (Note que usei o nó raiz, se o script estiver nele tire o get_node)
		var inimigo_script = novo_inimigo.get_node("CharacterBody3D")
		if inimigo_script:
			inimigo_script.velocidade = 7.2

		# --- LÓGICA DE SPAWN AO REDOR DO JOGADOR ---

		# 2. Define o raio de spawn (Ex: entre 30 e 120 metros para não nascer na cara do player)
		var raio_minimo = 30.0
		var raio_maximo = 120.0
		
		# Gera um ângulo aleatório em radianos
		var angulo = randf() * TAU 
		# Gera uma distância aleatória entre o mínimo e o máximo
		var distancia_aleatoria = randf_range(raio_minimo, raio_maximo)

		# Calcula a posição X e Z relativa ao jogador
		var pos_x = player.global_position.x + (cos(angulo) * distancia_aleatoria)
		var pos_z = player.global_position.z + (sin(angulo) * distancia_aleatoria)

		# 3. Pega a altura do terreno (Terrain3D) naquela posição
		var altura_y = 0.0
		var storage = chao.get("storage")
		if storage:
			# Importante: o Terrain3D usa a posição global para checar a altura
			altura_y = storage.get_height(Vector3(pos_x, 0, pos_z))
		else:
			altura_y = 10.0 # Valor de segurança caso o terreno falhe

		# 4. Define a posição final
		novo_inimigo.global_position = Vector3(pos_x, altura_y + 1.5, pos_z)

		enemies_count += 1


func _on_bake_again_timeout() -> void:
	nav_region.bake_navigation_mesh()


func _on_portal_next_scene_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_node("Camera3D"):
		#NEXT SCENE
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_2.tscn")


func _on_portal_next_scene_2_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_node("Camera3D"):
		#NEXT SCENE
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout
		Global.back_to_fase = true
		get_tree().change_scene_to_file("res://scenes/fase_1_outside_castle_again_no_fire_1.tscn")
