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

# Arraste o arquivo .tscn do seu inimigo para cá no Inspetor
@export var inimigo_scene: PackedScene 

# Referência ao nó que contém os pontos de spawn
@onready var pontos_container = $WorldEnvironment

var lava_material = StandardMaterial3D.new()

func setup_materials():
	# Configura a cor da lava com emissão (brilho)
	lava_material.albedo_color = Color(1, 0.2, 0)
	lava_material.emission_enabled = true
	lava_material.emission = Color(1, 0.3, 0)
	lava_material.emission_energy_multiplier = 2.0
	
func create_dungeon_floor():
# Criando o chão de lava
	var lava = CSGBox3D.new()
	lava.size = Vector3(50, 1, 50)
	lava.position.y = -1
	lava.material = lava_material
	
	# --- A LINHA QUE SALVA SUA VIDA ---
	lava.use_collision = true 
	# ----------------------------------
	
	add_child(lava)
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_materials()
	create_dungeon_floor()
	
	Global.maycon_danos_first_3d_battle = 0
	Global.maycon_pegou_arma_first_3d_battle = false
	
	await get_tree().create_timer(3.0).timeout
	seco_welcome.play()
	
	await get_tree().create_timer(5.0).timeout
	respaw.start()

func maycon_died()->void:
	#get_tree().paused = true
	you_died.visible = true
	fire_seco_3d.process_mode = Node.PROCESS_MODE_DISABLED
	maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
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
	maycon_3d.get_node("CharacterBody3D").add_bullets_to_gun(5)
	

func _on_respaw_timeout() -> void:
	#plotar novo inimigo
	if get_tree().get_nodes_in_group("inimigos").size() < 10:
		respaw_sound.play()
		# 1. Pega todos os Marker3Ds dentro do container
		var pontos = pontos_container.get_children()
		
		if pontos.size() > 0:
			# 2. Escolhe um ponto aleatório da lista
			var ponto_aleatorio = pontos.pick_random()
			
			# 3. Instancia o inimigo
			var novo_inimigo = inimigo_scene.instantiate()
			
			# 4. Adiciona à cena
			add_child(novo_inimigo)
			
			# 5. Coloca o inimigo na posição global do ponto escolhido
			if novo_inimigo.global_position:
				novo_inimigo.global_position = ponto_aleatorio.global_position
				print("Inimigo surgiu em: ", ponto_aleatorio.name)
			
			
