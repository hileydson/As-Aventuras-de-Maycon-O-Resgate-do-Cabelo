extends Area3D

@onready var animated_sprite_3d: AnimatedSprite3D = $"../AnimatedSprite3D"
@onready var me: Node3D = $"../.."
@onready var growl_1: AudioStreamPlayer = $"../Growl1"

var hp:int = 6

func receber_dano(dano:int)->void:

	hp -= dano
	# Garante que a vida não fique negativa
	hp = clamp(hp, 0, 6)
	
	# 1. Toca a animação de dano
	animated_sprite_3d.play("hurt") # Certifique-se de ter essa animação
	growl_1.play()
	
	# 2. Avisa o pai (CharacterBody3D) para parar
	var pai = get_parent()
	if pai and pai.has_method("parar_por_dano"):
		pai.parar_por_dano()
	
	
	if hp <= 0:
		morrer()

func morrer():
	animated_sprite_3d.play("died")
	await get_tree().create_timer(1.5).timeout
	var world_3d = get_tree().get_first_node_in_group("world_3d")
	world_3d.remove_enemies_count()
	me.queue_free()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Script da Area3D carregado com sucesso no nó: ", name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
