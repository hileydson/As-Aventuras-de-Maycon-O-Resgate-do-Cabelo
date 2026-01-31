extends Node3D

var tempo = 0.0
@export var velocidade = 6.0  # Quão rápido ele sobe e desce
@export var amplitude = 0.10  # A distância do movimento (em pixels)
@onready var posicao_inicial = position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	tempo += delta * velocidade
	# A mágica acontece aqui:
	position.y = posicao_inicial.y + sin(tempo) * amplitude
