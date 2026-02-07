extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@export var velocidade = 2.2
@onready var nav_agent = $NavigationAgent3D
@onready var animated_sprite_3d: AnimatedSprite3D = $AnimatedSprite3D
@onready var area_3d: Area3D = $Area3D

@export var distancia_despawn: float = 120.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var esta_atordoado: bool = false
var player = null

# Função chamada pela Area3D
func parar_por_dano():
	esta_atordoado = true
	# Cria um timer de 1 segundo
	await get_tree().create_timer(1.0).timeout 
	# Se ainda estiver vivo após 1 segundo, volta a perseguir
	esta_atordoado = false

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

		# --- LÓGICA DE DISTÂNCIA (QUEUE_FREE) ---
	if player:
		var distancia_atual = global_position.distance_to(player.global_position)

		if distancia_atual > distancia_despawn:
			# Antes de sumir, avisamos o world_3d para liberar espaço no contador
			var world_3d = get_tree().get_first_node_in_group("world_3d")
			if world_3d:
				world_3d.remove_enemies_count()
			
			queue_free() # Remove o inimigo do jogo
			return # Para o código aqui para não processar o resto do frame
		# ----------------------------------------	

	if esta_atordoado:
		# O inimigo fica parado horizontalmente enquanto leva o hit
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return # SAI DA FUNÇÃO AQUI, ignorando o resto (GPS/Perseguição)
		
	# 2. LÓGICA DE MOVIMENTO
	if player:
		if animated_sprite_3d.animation != "attack" && animated_sprite_3d.animation != "died":
			animated_sprite_3d.play("run")
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
	animated_sprite_3d.play("attack")
	body.levou_dano(1)
	await get_tree().create_timer(1.0).timeout
	animated_sprite_3d.play("died")
	await get_tree().create_timer(1.0).timeout
	var world_3d = get_tree().get_first_node_in_group("world_3d")
	world_3d.remove_enemies_count()
	parar_por_dano()
	area_3d.drop_municao()
	queue_free()
