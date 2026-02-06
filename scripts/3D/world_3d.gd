extends Node3D

@onready var arma: Area3D = $Area3D
@onready var gun_load: AudioStreamPlayer = $GunLoad
@onready var seco_welcome: AudioStreamPlayer = $SecoWelcome
@onready var maycon_3d: Node3D = $maycon_3d
@onready var you_died: Label = $you_died
@onready var fire_seco_3d: Node3D = $fire_seco_3d
@onready var fade: Node2D = $fade
@onready var respaw: Timer = $respaw
@onready var respaw_sound: AudioStreamPlayer = $respaw_sound
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# Arraste o arquivo .tscn do seu inimigo para cá no Inspetor
@export var inimigo_scene: PackedScene 
@export var inimigo_scene_2: PackedScene 
var enemy_chance:bool = false

# Referência ao nó que contém os pontos de spawn
#@onready var pontos_container = $"."
var pontos_container

var enemies_count:int = 0
var lava_material = StandardMaterial3D.new()
var lava

func remove_enemies_count()->void:
	enemies_count -=1

func setup_materials():
	# Configura a cor da lava com emissão (brilho)
	lava_material.albedo_color = Color(1, 0.2, 0)
	lava_material.emission_enabled = true
	lava_material.emission = Color(1, 0.3, 0)
	lava_material.emission_energy_multiplier = 2.0
	
func create_dungeon_floor():
	# 1. Configuração básica da lava
	lava = CSGBox3D.new()
	lava.size = Vector3(50, 1, 50)
	lava.material = lava_material
	lava.use_collision = true  # CRÍTICO: Ativa a colisão física
	
	# 2. Adiciona a lava COMO FILHA da NavigationRegion
	nav_region.add_child(lava)
	
	# 3. Posiciona a lava NO MUNDO (Global)
	lava.global_position = Vector3(0, -0.5, 0)
	
	# --- O PULO DO GATO ---
	# Espera um frame para o Godot registrar a colisão da lava no servidor de física
	await get_tree().process_frame
	
	# 4. Agora sim, gera a malha de navegação (Aparecerá o AZUL no Debug)
	nav_region.bake_navigation_mesh()
	
	# 5. Reposiciona o Player para garantir que ele não caia
	# Certifique-se que o caminho do nó está correto
	var player_node = maycon_3d.get_node("CharacterBody3D")
	if player_node:
		player_node.global_position = Vector3(0, 2, 24)
		
	
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_materials()
	create_dungeon_floor()
	
	Global.maycon_pegou_lamp_3d_world = false
	Global.maycon_pegou_lamp_fire_3d_world = false
	Global.maycon_danos_first_3d_battle = 0
	Global.maycon_pegou_arma_first_3d_battle = false
	
	await get_tree().create_timer(3.0).timeout
	seco_welcome.play()
	
	await get_tree().create_timer(5.0).timeout
	respaw.start()

func maycon_died()->void:
	if Global.default_language != Global.language_en:
			you_died.text = "VOCÊ MORREU!"
	you_died.visible = true
	
	fire_seco_3d.process_mode = Node.PROCESS_MODE_DISABLED
	maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
	var player = get_tree().get_first_node_in_group("player")
	player.get_node("hud_canvas").visible = false
	fade.get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_4.tscn") 
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
	body.add_bullets_to_gun(5)
	
func _on_respaw_timeout() -> void:
	#plotar novo inimigo
	if enemies_count < 3:
		respaw_sound.play()
	
		var novo_inimigo
		if enemy_chance:
			enemy_chance = false
			novo_inimigo = inimigo_scene.instantiate()
		else:
			enemy_chance = true
			novo_inimigo = inimigo_scene_2.instantiate()
	
		add_child(novo_inimigo)

		# 1. Pegamos o tamanho da caixa (lava)
		var largura = lava.size.x
		var profundidade = lava.size.z
		var altura_caixa = lava.size.y

		# 2. Geramos um X e Z aleatórios dentro dos limites da caixa
		# Usamos size/2 porque a posição (0,0,0) da caixa costuma ser o centro
		var x_aleatorio = randf_range(-largura / 2, largura / 2)
		var z_aleatorio = randf_range(-profundidade / 2, profundidade / 2)

		# 3. Calculamos a altura exata do topo
		var altura_topo = lava.global_position.y + (altura_caixa / 2) + 0.5

		# 4. Definimos a posição final
		# Somamos a posição global da lava para que o spawn siga a caixa onde ela estiver
		novo_inimigo.global_position = Vector3(
			lava.global_position.x + x_aleatorio,
			altura_topo,
			lava.global_position.z + z_aleatorio
		)
		enemies_count += 1
