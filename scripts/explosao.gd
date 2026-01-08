# Script na cena da Explosão
extends CPUParticles2D

func _ready():
	emitting = true

func _on_finished():
	queue_free() # A explosão se deleta sozinha quando as partículas acabam
