extends Area3D

@onready var animated_sprite_3d: AnimatedSprite3D = $"../AnimatedSprite3D"
@onready var me: Node3D = $"../.."
@onready var growl_1: AudioStreamPlayer = $"../Growl1"

# Substitua pelo caminho correto da sua cena de munição
const MUNICAO_SCENE = preload("res://scenes/3D/bullets.tscn")

var hp:int = 6

func stop_seek()->void:
	# 2. Avisa o pai (CharacterBody3D) para parar
	var pai = get_parent()
	if pai and pai.has_method("parar_por_dano"):
		pai.parar_por_dano()

func receber_dano(dano:int)->void:

	hp -= dano
	# Garante que a vida não fique negativa
	hp = clamp(hp, 0, 6)
	
	# 1. Toca a animação de dano
	animated_sprite_3d.play("hurt") # Certifique-se de ter essa animação
	growl_1.play()
	stop_seek()
	
	if hp <= 0:
		morrer()

func morrer():
	var world_3d = get_tree().get_first_node_in_group("world_3d")
	world_3d.remove_enemies_count()
	stop_seek()
	animated_sprite_3d.play("died")
	await get_tree().create_timer(0.5).timeout
	drop_municao()
	me.queue_free()
	
func drop_municao():
	# Cria uma instância da cena de munição
	var municao_instancia = MUNICAO_SCENE.instantiate()
	
	# Adiciona a munição na cena principal (ou no "world_3d")
	# É melhor adicionar no root ou no world para ela não sumir com o inimigo
	get_tree().current_scene.add_child(municao_instancia)
	
	# Define a posição da munição para a mesma posição do inimigo
	# Usamos global_position para não ter erro de herança
	municao_instancia.global_position = global_position
	# Ajuste leve no Y para ela não ficar "dentro" do chão
	municao_instancia.global_position.y += 0.5
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
