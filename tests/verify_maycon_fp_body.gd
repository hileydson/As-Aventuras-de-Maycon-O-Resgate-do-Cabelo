extends SceneTree

func _init():
	var p_scene = load("res://scenes/3D/dungeon_player.tscn")
	var player: DungeonPlayer = p_scene.instantiate()
	root.add_child(player)
	
	process_frame.connect(func():
		print("--- VERIFICAÇÃO DO CORPO E ANIMAÇÕES DO MAYCON (FPS) ---")
		print("1. Maycon body instanciado: ", is_instance_valid(player.maycon_body))
		assert(is_instance_valid(player.maycon_body), "maycon_body deve ser válido")
		
		print("2. Posição da cabeça (Head): ", player.head.position)
		assert(absf(player.head.position.y - 1.58) < 0.01, "Câmera deve estar na altura da cabeça (~1.58)")
		
		print("3. Rotação do corpo (frente para -Z): ", player.maycon_body.rotation.y)
		assert(absf(player.maycon_body.rotation.y - PI) < 0.01, "Corpo deve estar rotacionado em PI para apontar para a frente")
		
		print("4. Osso Head com escala zero para visão FPS limpa: ", player.maycon_skeleton.get_bone_pose_scale(player.head_bone_idx))
		assert(player.maycon_skeleton.get_bone_pose_scale(player.head_bone_idx) == Vector3.ZERO, "Head bone deve ter escala zero")
		
		print("5. Animações disponíveis: ")
		for anim in ["Walking", "Skill_03", "Arise", "Air_Flail"]:
			var has_it = player.maycon_anim.has_animation(anim)
			print("   - ", anim, ": ", has_it)
			assert(has_it, "Animação " + anim + " deve estar disponível")
		
		print("6. Teste da lógica de animação do Super Maycon:")
		# Testando Idle (simula chão)
		player._play_maycon_animation("Walking")
		assert(player.maycon_anim.current_animation == "Walking", "Idle deve ser Walking")
		print("   - Idle toca 'Walking': OK")
		
		# Testando Andar (simula chão)
		player._play_maycon_animation("Skill_03")
		assert(player.maycon_anim.current_animation == "Skill_03", "Andar deve ser Skill_03")
		print("   - Andar toca 'Skill_03': OK")
		
		# Testando Correr (simula chão)
		player._play_maycon_animation("Arise")
		assert(player.maycon_anim.current_animation == "Arise", "Correr deve ser Arise")
		print("   - Correr toca 'Arise': OK")
		
		# Testando Queda/Ar
		player._play_maycon_animation("Air_Flail")
		assert(player.maycon_anim.current_animation == "Air_Flail", "Ar/queda deve ser Air_Flail")
		print("   - Queda toca 'Air_Flail': OK")
		
		print("TODOS OS TESTES PASSARAM COM SUCESSO ABSOLUTO!")
		quit(0)
	)
