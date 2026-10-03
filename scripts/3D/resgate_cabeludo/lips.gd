extends Node3D

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")

@export var max_hp:int = 4
# Ele corre solto pela arena, sem rumo, arrebentando o que estiver na frente.
const CORRIDA := 9.0
const LIMITE_X := 17.0
const LIMITE_Z := 13.0
# Alcance do estrago. As arvores da arena ficam em x = 18, na beirada, entao ele
# precisa derrubar o que esta pouco alem de onde os pes dele chegam.
const ESTRAGO := 3.2
var hp:int = 4
var active:bool = false
var clock:float = 0.0
var invulnerable:float = 0.0
var target:Vector3
var stage:Node3D
var centro:Vector3
# Tudo o que ele pode destruir na arena, com o que precisa ser desligado em cada peça.
var destrutiveis:Array[Node3D] = []
var destruidos:int = 0
@onready var animation:AnimationPlayer = $Visual.find_child("AnimationPlayer", true, false)
@onready var skeleton:Skeleton3D = $Visual.find_child("Skeleton3D", true, false) as Skeleton3D

func _ready() -> void:
	stage = get_tree().get_first_node_in_group("resgate_stage")
	hp = max_hp
	centro = position
	play("Belly_Flop")
	if animation and animation.is_playing():
		animation.seek(animation.current_animation_length, true)
		animation.pause()

func play(anim:String) -> void:
	if animation and animation.has_animation(anim):
		animation.play(anim, 0.15)

func start() -> void:
	hp = max_hp
	active = true
	clock = 0.0
	invulnerable = 1.0
	if animation:
		animation.stop()
	if skeleton:
		skeleton.reset_bone_poses()
	$Warning.visible = false
	colher_destrutiveis()
	sortear_destino()

# Pega o cenário da arena, menos ele mesmo, a jaula e as peças grandes que
# fecham o lugar: o chão, os barrancos das laterais, o portão e a parede do fim.
func colher_destrutiveis() -> void:
	destrutiveis.clear()
	var arena:Node3D = get_parent()
	for filho in arena.get_children():
		if filho == self or filho.name == "Jaula" or not filho is Node3D:
			continue
		if parte_do_lugar(filho as Node3D):
			continue
		destrutiveis.append(filho as Node3D)

# Mede a peça pelas próprias malhas, só na horizontal: o chão, os barrancos, o
# portão e a parede do fim são largos ou compridos. Árvore é alta e fina, então
# ela continua valendo como enfeite que ele arrebenta.
func parte_do_lugar(peca:Node3D) -> bool:
	for malha in peca.find_children("*", "MeshInstance3D", true, false):
		var forma:Mesh = (malha as MeshInstance3D).mesh
		if forma == null:
			continue
		var tamanho:Vector3 = forma.get_aabb().size * (malha as MeshInstance3D).global_transform.basis.get_scale()
		if tamanho.x > 8.0 or tamanho.z > 8.0:
			return true
	return false

func sortear_destino() -> void:
	# De vez em quando ele vai direto para cima de um enfeite, para a corrida
	# sempre acabar arrebentando alguma coisa.
	if not destrutiveis.is_empty() and randf() < 0.4:
		var alvo:Node3D = destrutiveis[randi() % destrutiveis.size()]
		if is_instance_valid(alvo):
			target = Vector3(alvo.global_position.x, position.y, alvo.global_position.z)
			return
	# Destino qualquer dentro da arena, longe do ponto onde ele está.
	for _tentativa in 8:
		var escolha := centro + Vector3(randf_range(-LIMITE_X, LIMITE_X), 0.0, randf_range(-LIMITE_Z, LIMITE_Z))
		if Vector2(escolha.x - position.x, escolha.z - position.z).length() > 9.0:
			target = escolha
			return
	target = centro

# Arrebenta o que estiver no caminho: a peça sai de cena com poeira e estrondo.
func destruir(peca:Node3D) -> void:
	peca.visible = false
	for forma in peca.find_children("*", "CollisionShape3D", true, false):
		(forma as CollisionShape3D).disabled = true
	if peca is StaticBody3D:
		(peca as StaticBody3D).collision_layer = 0
	destruidos += 1
	if is_instance_valid(stage):
		stage.sound("wood")
		stage.burst(peca.global_position + Vector3.UP, Color("8a6a3c"), 20)
		POEIRA.aterrar(stage, peca.global_position + Vector3.UP * 0.3)

func quebrar_no_caminho() -> void:
	for i in range(destrutiveis.size() - 1, -1, -1):
		var peca:Node3D = destrutiveis[i]
		if not is_instance_valid(peca):
			destrutiveis.remove_at(i)
			continue
		var diff := peca.global_position - global_position
		if Vector2(diff.x, diff.z).length() < ESTRAGO:
			destrutiveis.remove_at(i)
			destruir(peca)

func _physics_process(delta:float) -> void:
	if is_instance_valid(stage) and is_instance_valid(stage.final_battle) and stage.final_battle.engaged:
		return
	if not active or not stage.player.control_enabled:
		return
	clock += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	var player:CharacterBody3D = stage.player
	# Corrida sem rumo pela arena, trocando de destino ao chegar.
	var rumo := Vector3(target.x - position.x, 0.0, target.z - position.z)
	if rumo.length() < 1.2:
		sortear_destino()
	else:
		var passo := rumo.normalized() * CORRIDA * delta
		position.x += passo.x
		position.z += passo.z
		$Visual.rotation.y = atan2(passo.x, passo.z)
	position.x = clampf(position.x, centro.x - LIMITE_X, centro.x + LIMITE_X)
	position.z = clampf(position.z, centro.z - LIMITE_Z, centro.z + LIMITE_Z)
	$Visual.position.y = 2.28 + absf(sin(clock * 9.0)) * 0.16
	pose_running(clock * 9.0)
	quebrar_no_caminho()
	var diff := player.global_position - global_position
	var horizontal := Vector2(diff.x, diff.z).length()
	# O pisão na cabeça continua valendo, mesmo com ele correndo.
	if horizontal < 2.6 and diff.y > 3.0 and diff.y < 5.8 and player.velocity.y < -1.0 and invulnerable <= 0.0:
		player.bounce()
		receive_hit()
	elif horizontal < 2.0 and diff.y < 3.2 and diff.y > -1.0:
		player.receive_damage(20, global_position)

# Soco e pisão descontam a mesma coisa, com uma janela de folga entre dois golpes.
func receive_hit() -> void:
	if not active or invulnerable > 0.0:
		return
	hp -= 1
	invulnerable = 0.9
	stage.sound("hit")
	stage.burst(global_position + Vector3.UP * 4, Color("ffdb6a"), 22)
	stage.update_hud()
	if hp <= 0:
		active = false
		play("Belly_Flop")
		if skeleton:
			skeleton.reset_bone_poses()
		$Visual.position.y = 0.6
		stage.finish()

func pose_running(phase:float) -> void:
	if not skeleton:
		return
	skeleton.reset_bone_poses()
	var swing := sin(phase) * 0.75
	set_bone("Hips", -0.13)
	set_bone("Leg_Upper.L", swing)
	set_bone("Leg_Upper.R", -swing)
	set_bone("Leg_Lower.L", maxf(0.0, -swing) * 0.85)
	set_bone("Leg_Lower.R", maxf(0.0, swing) * 0.85)
	set_bone("Arm_Upper.L", -swing * 0.85)
	set_bone("Arm_Upper.R", swing * 0.85)
	set_bone("Head", sin(phase * 2.0) * 0.04)

func set_bone(bone_name:String, angle:float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	# Gira a partir do descanso do osso. Substituir a orientacao virava o pe para
	# dentro da barriga.
	var descanso := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, descanso * Quaternion(Vector3.RIGHT, angle))
