extends Sprite2D

# Carregue a cena da explosão
const CENA_EXPLOSAO = preload("res://scenes/explosao.tscn")

func destruir_objeto():
	# 1. Cria a instância da explosão
	var explosao = CENA_EXPLOSAO.instantiate()
	
	# 2. Define a posição da explosão igual à do objeto atual
	explosao.global_position = global_position
	
	# 3. Adiciona a explosão à cena principal (não como filho deste objeto!)
	get_tree().current_scene.add_child(explosao)
	
	# 4. Deleta o objeto original
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("ENCOSTOU")
	if Input.is_action_pressed("key_q") || Input.is_action_pressed("key_q"):
		print("ACAO DE GOLPE")
		destruir_objeto()
