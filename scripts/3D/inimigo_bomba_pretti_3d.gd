extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

@export var velocidade = 4.0
@onready var nav_agent = $NavigationAgent3D
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var player = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Espera um frame para garantir que a navegação foi carregada
	await get_tree().physics_frame
	
	# Busca o player pelo grupo (certifique-se de que o player está no grupo "player")
	player = get_tree().get_first_node_in_group("player")
	#player = $"../maycon_3d"
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# 1. GRAVIDADE (Calculada primeiro)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# 2. LÓGICA DE MOVIMENTO
	if player:
		nav_agent.target_position = player.global_position
		
		# Verificamos se o GPS já calculou o caminho e se não chegamos no alvo
		if not nav_agent.is_target_reached():
			var next_path_pos = nav_agent.get_next_path_position()
			var current_pos = global_position
			
			# Calculamos a direção apenas nos eixos X e Z (horizontal)
			var direcao = (next_path_pos - current_pos).normalized()
			
			velocity.x = direcao.x * velocidade
			velocity.z = direcao.z * velocidade
			
			look_at_target(player.global_position)
		else:
			# Se chegou no player, para o movimento horizontal
			velocity.x = 0
			velocity.z = 0

	# 3. ÚNICA CHAMADA DE MOVIMENTO (Aplica a velocidade acumulada)
	move_and_slide()

func look_at_target(target_pos):
	var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_to(look_pos) > 0.5:
		look_at(look_pos, Vector3.UP)
		
func _on_area_3d_body_entered(body: Node3D) -> void:
	print("PEGOU MAYCON!")
