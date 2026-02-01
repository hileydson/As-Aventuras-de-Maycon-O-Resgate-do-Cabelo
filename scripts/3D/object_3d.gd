extends Node3D

# Materiais para o visual
var wall_material = StandardMaterial3D.new()

func _ready():
	setup_materials()
	#create_dungeon_floor()
	add_fire_light(Vector3(0, 2, -5)) # Exemplo de luz de fogueira

func setup_materials():
	# Parede de pedra escura
	wall_material.albedo_color = Color(0.2, 0.2, 0.2)
	wall_material.roughness = 0.8


func add_fire_light(pos: Vector3):
	# Adiciona uma luz dinâmica para simular o fogo da imagem
	var light = OmniLight3D.new()
	light.position = pos
	light.light_color = Color(1, 0.5, 0.1)
	light.light_energy = 5.0
	light.omni_range = 10.0
	light.shadow_enabled = true
	add_child(light)
