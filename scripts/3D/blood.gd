extends GPUParticles3D

func _ready():
	emitting = true # Começa o espirro
	print("Sangue instanciado em: ", global_position)
	# Espera 2 segundos (tempo suficiente para subir e cair) e deleta
	await get_tree().create_timer(2.0).timeout
	queue_free()
