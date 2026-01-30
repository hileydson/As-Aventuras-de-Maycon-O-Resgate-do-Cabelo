extends Node3D

# Materiais para o visual
var lava_material = StandardMaterial3D.new()
var wall_material = StandardMaterial3D.new()

func _ready():
	setup_materials()
	create_dungeon_floor()
	add_fire_light(Vector3(0, 2, -5)) # Exemplo de luz de fogueira

func setup_materials():
	# Configura a cor da lava com emissão (brilho)
	lava_material.albedo_color = Color(1, 0.2, 0)
	lava_material.emission_enabled = true
	lava_material.emission = Color(1, 0.3, 0)
	lava_material.emission_energy_multiplier = 2.0
	
	# Parede de pedra escura
	wall_material.albedo_color = Color(0.2, 0.2, 0.2)
	wall_material.roughness = 0.8

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

func add_fire_light(pos: Vector3):
	# Adiciona uma luz dinâmica para simular o fogo da imagem
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1, 0.5, 0.1)
	light.light_energy = 5.0
	light.omni_range = 10.0
	light.shadow_enabled = true
	add_child(light)
