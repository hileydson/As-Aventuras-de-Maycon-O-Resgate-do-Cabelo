extends Node3D

func _ready():
	create_fire_particles()

func create_fire_particles():
	var particles = GPUParticles3D.new()
	
	# 1. Configurações Básicas
	particles.amount = 200 # Quantidade de brasas
	particles.lifetime = 2.0
	particles.explosiveness = 0.0
	particles.randomness = 1.0
	
	# 2. Process Material (O comportamento das partículas)
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(2, 0.1, 2) # Área de onde as brasas saem
	
	mat.direction = Vector3(0, 1, 0) # Sobe no eixo Y
	mat.spread = 15.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, 0.5, 0) # Gravidade negativa para flutuarem
	
	# Cor: Começa amarelo/laranja e morre vermelho/cinza
	mat.color_ramp = create_fire_gradient()
	
	particles.process_material = mat
	
	# 3. Draw Pass (O que será desenhado - um quadradinho)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.1) # Tamanho da brasa
	
	var mesh_mat = StandardMaterial3D.new()
	mesh_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # Brilha no escuro
	mesh_mat.vertex_color_use_as_albedo = true # Usa as cores do Gradient
	mesh_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES # Sempre olha pra câmera
	
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh
	
	add_child(particles)

func create_fire_gradient():
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.8, 0.2, 1)) # Amarelo vivo
	gradient.set_color(1, Color(1, 0, 0, 0))    # Vermelho sumindo (Alpha 0)
	
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
