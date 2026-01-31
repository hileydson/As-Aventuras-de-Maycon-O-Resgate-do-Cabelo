extends Area3D

@export var expansao_speed = 11.0 # Quão rápido a onda cresce
@export var tamanho_maximo = 70.0 # Onde ela some
@export var dano = 1

func _ready():
	# Conecta o sinal de quando o player encosta
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Faz a onda crescer nos eixos X e Z (horizontal)
	scale.x += expansao_speed * delta
	scale.z += expansao_speed * delta
	
	# Se a onda ficar muito grande, ela desaparece
	if scale.x > tamanho_maximo:
		queue_free()

func _on_body_entered(body):
	Global.maycon_danos_first_3d_battle = Global.maycon_danos_first_3d_battle + 1
