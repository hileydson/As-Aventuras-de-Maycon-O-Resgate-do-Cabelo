extends SceneTree

# Validação em execução da fase Resgate Cabeludo: abertura, corrida automática,
# câmera, caixas, checkpoints, trampolins, desfiladeiro, copas, arena, vento,
# poeira, sangue e som.

var stage:Node3D
var player:CharacterBody3D
var fails:int = 0

func _init() -> void:
	call_deferred("run")

func ok(label:String, condition:bool, detail:String = "") -> void:
	if not condition:
		fails += 1
	print(("  OK    " if condition else "  FALHA ") + label + ("" if detail.is_empty() else "   [" + detail + "]"))

func step(frames:int) -> void:
	for _i in frames:
		await physics_frame

func release_all() -> void:
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		Input.action_release(action)

func quiet_course() -> void:
	for enemy in root.get_tree().get_nodes_in_group("resgate_enemies"):
		enemy.active = false
	for item in root.get_tree().get_nodes_in_group("resgate_elements"):
		if item.kind == "hazard":
			item.active = false

# Posiciona de forma determinística: a corrida automática fica desligada para os
# testes de geometria e é religada no teste dela.
func place(at:Vector3) -> void:
	release_all()
	player.auto_run = false
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.launch_time = 0.0
	player.hurt_time = 0.0
	player.arena_mode = false
	player.jumps = 0
	stage.hp = 100
	stage.camera.global_position = at + Vector3(0, 2.8, 5.6)
	stage.camera.look_at(at + Vector3(0, 1.3, -4.0))

func settle(at:Vector3, frames:int = 20) -> void:
	place(at)
	await step(frames)

func find_course(node_name:String) -> Node3D:
	return stage.get_node("Course/" + node_name) as Node3D

func framed(label:String) -> void:
	var target:Vector3 = player.global_position + Vector3.UP
	var rect := root.get_viewport().get_visible_rect()
	var behind:bool = stage.camera.is_position_behind(target)
	var point:Vector2 = stage.camera.unproject_position(target)
	var inside:bool = rect.grow(-40).has_point(point)
	ok("enquadramento %s" % label, not behind and inside, "tela=%.0f,%.0f  rect=%.0fx%.0f" % [point.x, point.y, rect.size.x, rect.size.y])

func run() -> void:
	var scene:Node3D = load("res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn").instantiate()
	scene.show_intro = false
	root.add_child(scene)
	stage = scene
	player = stage.player
	print("=== RESGATE CABELUDO - VALIDACAO EM EXECUCAO ===")

	await step(3)
	var deitado:bool = absf(player.visual.rotation.x + PI * 0.5) < 0.1
	var guard:int = 0
	while stage.intro_active and guard < 2400:
		guard += 1
		await physics_frame
	ok("abertura termina e devolve o controle", not stage.intro_active and player.control_enabled, "frames=%d" % guard)
	ok("Maycon comeca deitado, como no aviao", deitado, "rot.x inicial")
	ok("Maycon fica de pe ao assumir o controle", absf(player.visual.rotation.x) < 0.05, "rot.x=%.3f" % player.visual.rotation.x)
	ok("abertura e rapida e sem fade no fim", guard < 900 and fade_alpha() < 0.01, "frames=%d fade=%.2f" % [guard, fade_alpha()])
	quiet_course()

	print("-- HUD, pause e inimigos --")
	var stats:Control = stage.get_node("HUD/Stats")
	var sobras:Array[String] = []
	for extra in ["Blood", "Charge", "Boss"]:
		if stats.has_node(extra):
			sobras.append(extra)
	ok("HUD sem numeros nem pentagrama/poder", sobras.is_empty(), "sobrou=%s" % str(sobras))
	var vida:Label = stage.get_node_or_null("HUD/Stats/Health/Vida")
	ok("palavra VIDA dentro da barra de vida", vida != null and vida.text == tr("RESGATE_LIFE") and vida.text != "RESGATE_LIFE", "texto='%s'" % (vida.text if vida else "<ausente>"))
	ok("pause padrao do projeto (platform_pause)", stage.has_node("PauseFofo"), "no PauseFofo")
	var hint:Label = stage.get_node("HUD/Hint")
	ok("aviso de checkpoint ancorado no canto inferior direito", is_equal_approx(hint.anchor_left, 1.0) and is_equal_approx(hint.anchor_top, 1.0), "ancora=%.1f,%.1f" % [hint.anchor_left, hint.anchor_top])
	var total:int = root.get_tree().get_nodes_in_group("resgate_enemies").size()
	ok("gameplay lotada de inimigos", total >= 180, "total=%d" % total)
	var contador:Node = stage.get_node_or_null("HUD/Pentagramas")
	ok("contador de pentagramas em cima", contador != null and contador.visible and contador.get_child_count() == 2, "nó=%s" % (contador != null))
	ok("corrida 10% mais rapida (8,58 m/s)", is_equal_approx(player.run_speed, 8.58), "run_speed=%.2f" % player.run_speed)
	var com_batalha:int = 0
	for enemy in root.get_tree().get_nodes_in_group("resgate_enemies"):
		if enemy.battle_sprite != null:
			com_batalha += 1
	ok("inimigos usam as folhas da batalha em tempo real", com_batalha >= 140, "com animacao=%d" % com_batalha)
	var casters:int = 0
	for enemy in root.get_tree().get_nodes_in_group("resgate_enemies"):
		if str(enemy.behavior) == "caster":
			casters += 1
	ok("inimigo das bolas rosas removido", casters == 0, "casters=%d" % casters)

	print("-- Pause padrao --")
	var contrato:bool = "exit_started" in stage and "death_in_progress" in stage and stage.has_method("exit_to_menu")
	ok("contrato que o platform_pause exige do pai", contrato, "exit_started/death_in_progress/exit_to_menu")
	press_action("ui_cancel")
	await step(4)
	ok("Esc abre o pause e congela o jogo", root.get_tree().paused, "paused=%s" % root.get_tree().paused)
	press_action("ui_cancel")
	await step(4)
	ok("Esc fecha o pause e devolve o jogo", not root.get_tree().paused, "paused=%s" % root.get_tree().paused)

	print("-- Animacao viva de um inimigo --")
	var alvo:Node3D = stage.get_node("Course/InimigoDoJogo_0056")
	await settle(Vector3(0, 0.4, -40))
	await step(10)
	var quadro_a:int = alvo.battle_sprite.frame
	var tocando:bool = alvo.battle_sprite.is_playing()
	await step(25)
	ok("inimigo anima de verdade, nao fica estatico", tocando and alvo.battle_sprite.frame != quadro_a, "tocando=%s quadros %d->%d" % [tocando, quadro_a, alvo.battle_sprite.frame])
	ok("inimigo tem a animacao de corrida da batalha", alvo.battle_sprite.sprite_frames.has_animation("run"), "anims=%d" % alvo.battle_sprite.sprite_frames.get_animation_names().size())

	print("-- Vento, musica e ambiente --")
	ok("linhas de vento presas na camera", stage.camera.has_node("LinhasDeVento"), "nó na camera")
	ok("last_song em dois canais para emendar o loop", stage.song_slots.size() == 2 and stage.song_slots[0].playing, "tocando=%s" % (stage.song_slots[0].playing if stage.song_slots.size() > 0 else false))
	var birds:AudioStreamPlayer = stage.get_node_or_null("Ambiente")
	ok("song_birds de ambiente no inicio do gameplay", birds != null and birds.playing, "tocando=%s" % (birds.playing if birds else false))

	print("-- Corrida e pulo --")
	# Trecho sem caixas (as caixas do percurso saltam de 620 a 730) para medir locomocao pura.
	var lane := Vector3(2.0, 0.4, -705)
	await settle(lane)
	ok("pousa na trilha", player.is_on_floor(), "y=%.2f" % player.global_position.y)
	Input.action_press("ui_up")
	await step(40)
	var z0:float = player.global_position.z
	await step(60)
	var advance:float = z0 - player.global_position.z
	Input.action_release("ui_up")
	ok("corrida atinge ~8,58 m/s em regime", advance > 8.1 and advance < 9.1, "dz=%.2f m/s  vz=%.2f" % [advance, player.velocity.z])

	await settle(lane)
	var base_y:float = player.global_position.y
	Input.action_press("ui_accept")
	var peak:float = base_y
	for _i in 46:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
	Input.action_release("ui_accept")
	ok("pulo simples sobe ~1.7 m", peak - base_y > 1.4 and peak - base_y < 2.1, "altura=%.2f" % (peak - base_y))

	await settle(lane)
	Input.action_press("ui_accept")
	await step(3)
	Input.action_release("ui_accept")
	await step(10)
	Input.action_press("ui_accept")
	await step(3)
	var double_jumps:int = player.jumps
	Input.action_release("ui_accept")
	await step(40)
	ok("pulo duplo registra dois saltos", double_jumps == 2, "jumps=%d" % double_jumps)

	print("-- Corrida automatica e camera de perto --")
	await settle(lane)
	player.auto_run = true
	release_all()
	z0 = player.global_position.z
	await step(90)
	var alone:float = z0 - player.global_position.z
	ok("fase avanca sozinha, sem nenhum comando", alone > 9.0, "dz=%.2f m" % alone)
	var distance:float = stage.camera.global_position.distance_to(player.global_position)
	ok("camera fica colada no Maycon", distance < 7.5, "dist=%.2f m" % distance)
	framed("na corrida automatica")
	var x0:float = player.global_position.x
	Input.action_press("ui_right")
	await step(40)
	Input.action_release("ui_right")
	ok("desvio lateral responde na corrida automatica", player.global_position.x - x0 > 1.8, "dx=%.2f" % (player.global_position.x - x0))
	player.auto_run = false

	print("-- Sangue no dano --")
	await settle(lane)
	var effects:Node3D = stage.get_node("Effects")
	var before:int = effects.get_child_count()
	player.receive_damage(12.0, player.global_position + Vector3(0, 0, -2))
	await step(3)
	ok("dano espirra sangue para todo lado", effects.get_child_count() - before >= 5, "novos=%d" % (effects.get_child_count() - before))

	print("-- Limite da pista e poeira do pulo --")
	await settle(lane)
	Input.action_press("ui_right")
	await step(150)
	Input.action_release("ui_right")
	ok("nao sai da pista principal de lado", not stage.respawning and player.global_position.x <= 5.7, "x=%.2f" % player.global_position.x)
	await settle(lane)
	var poeira_antes:int = conta_poeira()
	Input.action_press("ui_accept")
	await step(5)
	Input.action_release("ui_accept")
	ok("pulo comum levanta poeira", conta_poeira() > poeira_antes, "estouros %d->%d" % [poeira_antes, conta_poeira()])
	guard = 0
	while player.is_on_floor() and guard < 60:
		guard += 1
		await physics_frame
	# A conta e tirada no ultimo quadro no ar, porque os estouros antigos somem.
	var antes_do_pouso:int = conta_poeira()
	guard = 0
	while not player.is_on_floor() and guard < 180:
		guard += 1
		antes_do_pouso = conta_poeira()
		await physics_frame
	await step(1)
	ok("pouso comum levanta poeira", conta_poeira() > antes_do_pouso, "estouros %d->%d" % [antes_do_pouso, conta_poeira()])

	print("-- Caixas por contato --")
	var crate:Node3D = find_course("Crate_0044")
	await settle(crate.global_position + Vector3(0, 0.4, 4.0))
	var pent_before:int = stage.pentagrams
	var poeira_caixa:int = conta_poeira()
	Input.action_press("ui_up")
	guard = 0
	while crate.active and guard < 120:
		guard += 1
		# A conta e tirada no ultimo quadro antes de quebrar, porque os estouros antigos somem.
		poeira_caixa = conta_poeira()
		await physics_frame
	Input.action_release("ui_up")
	await step(1)
	ok("caixa quebra so de passar nela, sem pulo", not crate.active, "ativa=%s frames=%d" % [crate.active, guard])
	ok("caixa joga o Maycon para cima de leve", player.velocity.y > 3.0 and player.velocity.y < 9.0, "vy=%.2f" % player.velocity.y)
	ok("caixa estoura poeira", conta_poeira() > poeira_caixa, "estouros %d->%d" % [poeira_caixa, conta_poeira()])
	await step(90)
	ok("caixa libera pentagramas coletaveis", stage.pentagrams > pent_before, "antes=%d depois=%d" % [pent_before, stage.pentagrams])

	print("-- Dash --")
	await settle(lane)
	stage.pentagrams = 2
	stage.update_hud()
	press_action("dash_resgate")
	await step(2)
	ok("dash nao sai com menos de 3 pentagramas", player.dash_time <= 0.0 and stage.pentagrams == 2, "pentagramas=%d dash=%.2f" % [stage.pentagrams, player.dash_time])
	stage.pentagrams = 7
	stage.update_hud()
	var z_dash:float = player.global_position.z
	press_action("dash_resgate")
	await step(2)
	ok("dash custa 3 pentagramas", stage.pentagrams == 4, "pentagramas=%d" % stage.pentagrams)
	ok("dash deixa o Maycon invencivel", player.is_invincible, "invencivel=%s" % player.is_invincible)
	ok("dash deixa rastro", stage.get_node("Effects").find_children("RastroDoDash*", "", true, false).size() > 0, "silhuetas=%d" % stage.get_node("Effects").find_children("RastroDoDash*", "", true, false).size())
	var antes_vida:float = stage.hp
	player.receive_damage(20.0, player.global_position + Vector3(0, 0, -2))
	ok("dano nao entra durante o dash", is_equal_approx(stage.hp, antes_vida), "vida=%.0f" % stage.hp)
	guard = 0
	while player.dash_time > 0.0 and guard < 60:
		guard += 1
		await physics_frame
	var alcance:float = z_dash - player.global_position.z
	ok("dash e curto", alcance > 2.0 and alcance < 7.0, "avanco=%.2f m" % alcance)
	await step(5)
	ok("invencibilidade acaba com o dash", not player.is_invincible, "invencivel=%s" % player.is_invincible)
	await settle(lane)
	stage.pentagrams = 9
	Input.action_press("ui_down")
	press_action("dash_resgate")
	await step(2)
	Input.action_release("ui_down")
	ok("dash nunca vai para tras", player.dash_velocity.z <= 0.01, "vz=%.2f" % player.dash_velocity.z)
	await step(20)

	print("-- Checkpoint --")
	var check:Node3D = find_course("Checkpoint_0220")
	await settle(check.global_position + Vector3(0, 0.4, 0))
	await step(10)
	var expected:Vector3 = check.global_position + Vector3(0, 0.2, -2)
	ok("checkpoint registra a posicao", stage.last_checkpoint == check and stage.checkpoint_position.distance_to(expected) < 0.01, "pos=%.1f,%.1f,%.1f" % [stage.checkpoint_position.x, stage.checkpoint_position.y, stage.checkpoint_position.z])
	var aviso:String = (stage.get_node("HUD/Hint") as Label).text
	ok("checkpoint escreve so a palavra", aviso == tr("RESGATE_CHECKPOINT") and aviso.length() <= 12, "texto='%s'" % aviso)

	print("-- Desfiladeiro (trecho inferior) --")
	await settle(Vector3(0, 0.4, -340))
	framed("na borda do desfiladeiro")
	Input.action_press("ui_up")
	guard = 0
	while player.global_position.z > -372 and guard < 300 and not stage.respawning:
		guard += 1
		await physics_frame
	Input.action_release("ui_up")
	await step(30)
	ok("descida ao desfiladeiro nao mata o player", not stage.respawning, "z=%.1f y=%.2f" % [player.global_position.z, player.global_position.y])
	ok("pousa no piso do desfiladeiro (y=-18)", player.is_on_floor() and absf(player.global_position.y + 18.0) < 0.6, "y=%.2f" % player.global_position.y)
	framed("no fundo do desfiladeiro")

	print("-- Trampolim de saida do desfiladeiro --")
	var spring_low:Node3D = find_course("MagicSpring_650")
	await settle(spring_low.global_position + Vector3(0, 0.3, 0), 4)
	ok("trampolim dispara o lancamento", player.launch_time > 0.0, "launch=%.2f" % player.launch_time)
	ok("poeira sai do Maycon no trampolim", player.has_node("PoeiraDoSalto"), "rastro preso no player")
	guard = 0
	while guard < 420 and not stage.respawning and not (player.launch_time <= 0.0 and player.is_on_floor()):
		guard += 1
		await physics_frame
	ok("voo do trampolim nao mata o player", not stage.respawning, "z=%.1f y=%.2f" % [player.global_position.z, player.global_position.y])
	ok("pousa na plataforma SpringLanding", player.is_on_floor() and absf(player.global_position.y) < 0.8 and player.global_position.z < -700 and player.global_position.z > -716, "y=%.2f z=%.1f" % [player.global_position.y, player.global_position.z])
	await step(2)
	ok("pouso enche o chao de poeira", conta_poeira() > 0, "estouros=%d" % conta_poeira())
	framed("na plataforma de pouso")

	print("-- Trampolim de subida as copas --")
	var spring_high:Node3D = find_course("MagicSpring_1030")
	await settle(spring_high.global_position + Vector3(0, 0.3, 0), 4)
	guard = 0
	while guard < 420 and not stage.respawning and not (player.launch_time <= 0.0 and player.is_on_floor()):
		guard += 1
		await physics_frame
	ok("voo as copas nao mata o player", not stage.respawning, "z=%.1f y=%.2f" % [player.global_position.z, player.global_position.y])
	ok("pousa na plataforma CanopyLanding (y=30)", player.is_on_floor() and absf(player.global_position.y - 30.0) < 0.8 and player.global_position.z < -1070 and player.global_position.z > -1086, "y=%.2f z=%.1f" % [player.global_position.y, player.global_position.z])
	framed("na entrada das copas")

	print("-- Copas (trecho elevado) --")
	await settle(Vector3(0, 30.4, -1200))
	ok("pousa na ponte das copas", player.is_on_floor() and absf(player.global_position.y - 30.0) < 0.6, "y=%.2f" % player.global_position.y)
	framed("na ponte das copas")
	Input.action_press("ui_right")
	await step(180)
	Input.action_release("ui_right")
	ok("nao cai da ponte das copas de lado", not stage.respawning and player.global_position.x <= 3.7, "x=%.2f y=%.2f" % [player.global_position.x, player.global_position.y])

	print("-- Buraco de 3,2 m nas copas --")
	await settle(Vector3(0, 30.4, -1160))
	Input.action_press("ui_up")
	guard = 0
	while player.global_position.z > -1168 and guard < 180:
		guard += 1
		await physics_frame
	Input.action_press("ui_accept")
	await step(6)
	Input.action_release("ui_accept")
	guard = 0
	while guard < 180 and not stage.respawning and not (player.is_on_floor() and player.global_position.z < -1175):
		guard += 1
		await physics_frame
	Input.action_release("ui_up")
	ok("buraco das copas e transponivel com um pulo", not stage.respawning and player.global_position.z < -1175, "z=%.1f y=%.2f" % [player.global_position.z, player.global_position.y])

	print("-- Saida das copas para a floresta antiga --")
	await settle(Vector3(0, 30.4, -1350))
	Input.action_press("ui_up")
	guard = 0
	while guard < 420 and not stage.respawning and not (player.is_on_floor() and player.global_position.z < -1372):
		guard += 1
		await physics_frame
	Input.action_release("ui_up")
	ok("descida das copas nao mata o player", not stage.respawning, "z=%.1f y=%.2f" % [player.global_position.z, player.global_position.y])
	ok("pousa na floresta antiga (y=0)", player.is_on_floor() and absf(player.global_position.y) < 0.8, "y=%.2f z=%.1f" % [player.global_position.y, player.global_position.z])
	guard = 0
	while stage.respawning and guard < 300:
		guard += 1
		await physics_frame

	print("-- Cenario atras da largada --")
	var backdrop:Node3D = stage.get_node_or_null("Forest/00_FundoInicial")
	ok("fundo largo existe atras do inicio", backdrop != null and backdrop.get_child_count() > 100, "nós=%d" % (backdrop.get_child_count() if backdrop else 0))
	await settle(Vector3(0, 0.4, 0))
	await step(10)
	var back_edge:Vector3 = Vector3(0, 0, 15.5)
	ok("camera da largada nao alcanca o fim da trilha antiga", stage.camera.is_position_behind(back_edge), "camera z=%.1f" % stage.camera.global_position.z)

	print("-- Pose do Lips --")
	var skel:Skeleton3D = stage.boss.skeleton
	if skel != null:
		var osso := skel.find_bone("Leg_Upper.L")
		if osso < 0:
			osso = 0
		skel.reset_bone_poses()
		var descanso:Quaternion = skel.get_bone_rest(osso).basis.get_rotation_quaternion()
		stage.boss.set_bone(skel.get_bone_name(osso), 0.0)
		var pose:Quaternion = skel.get_bone_pose_rotation(osso)
		ok("balanco zero deixa o osso no descanso", absf(pose.dot(descanso)) > 0.999, "dot=%.4f osso=%s" % [pose.dot(descanso), skel.get_bone_name(osso)])
	else:
		ok("balanco zero deixa o osso no descanso", false, "sem Skeleton3D no Lips")

	print("-- Cabelo da arena --")
	var cabelo:Node = stage.get_node_or_null("Arena/Lips/Hair")
	ok("cabelo da arena e o AnimatedSprite3D da cutscene", cabelo is AnimatedSprite3D and cabelo.sprite_frames != null, "tipo=%s" % (cabelo.get_class() if cabelo else "<ausente>"))

	print("-- Arena final --")
	quiet_course()
	await settle(Vector3(0, 0.4, -1770))
	Input.action_press("ui_up")
	guard = 0
	while guard < 300 and not player.arena_mode and not stage.respawning:
		guard += 1
		await physics_frame
	Input.action_release("ui_up")
	ok("arena liga ao cruzar z=-1778", player.arena_mode, "z=%.1f" % player.global_position.z)
	await step(60)
	ok("Lips entra em acao com 4 pontos", stage.boss.active and stage.boss.hp == 4, "ativo=%s hp=%d" % [stage.boss.active, stage.boss.hp])
	framed("na arena final")

	print("=== FALHAS: %d ===" % fails)
	quit(1 if fails > 0 else 0)

# O Godot renomeia nós repetidos, então a contagem olha o tipo, não o nome.
# Input.action_press nao gera evento, entao o pause precisa de um InputEventAction.
func press_action(action:String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)

func conta_poeira() -> int:
	var n:int = 0
	for child in stage.get_children():
		if child is GPUParticles3D:
			n += 1
	return n

func fade_alpha() -> float:
	return (stage.get_node("HUD/Fade") as ColorRect).color.a
