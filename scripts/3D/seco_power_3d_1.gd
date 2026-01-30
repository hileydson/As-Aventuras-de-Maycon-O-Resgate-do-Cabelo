extends Area3D

@export var expansao_speed = 10.0 # Quão rápido a onda cresce
@export var tamanho_maximo = 50.0 # Onde ela some
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
	# Se o corpo que entrou tiver a função "receber_dano"
	if body.has_method("receber_dano"):
		body.receber_dano(dano)
