extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D

@export var velocidade = 4.0
@onready var nav_agent = $NavigationAgent3D

var player = null
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Espera um frame para garantir que a navegação foi carregada
	await get_tree().physics_frame
	
	# Busca o player pelo grupo (certifique-se de que o player está no grupo "player")
	#player = get_tree().get_first_node_in_group("maycon_3d")
	player = $"../maycon_3d"
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	player = $"../maycon_3d"
	print(player)
	if player!=null:
		# 1. Atualiza o objetivo do agente para a posição do player
		nav_agent.target_position = player.global_position
		
		# 2. Se já estiver muito perto, não precisa calcular movimento
		if nav_agent.is_target_reached():
			return

		# 3. Pega a próxima posição no caminho calculado
		var current_pos = global_position
		var next_path_pos = nav_agent.get_next_path_position()
		
		# 4. Calcula a direção e move
		var direcao = (next_path_pos - current_pos).normalized()
		velocity = direcao * velocidade
		
		# 5. Rotaciona o inimigo para olhar para o player (suavemente)
		look_at_target(player.get_note("CharacterBody3D").global_position)
		
		move_and_slide()

func look_at_target(target_pos):
	# Faz o inimigo olhar para o player sem inclinar para cima/baixo
	var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos, Vector3.UP)
		
func _on_area_3d_body_entered(body: Node3D) -> void:
	print("PEGOU MAYCON!")
