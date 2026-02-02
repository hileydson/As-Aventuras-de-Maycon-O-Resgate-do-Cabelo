extends GPUParticles3D

func _ready():
	emitting = true # Começa o espirro
	await get_tree().create_timer(2.0).timeout
	queue_free()
