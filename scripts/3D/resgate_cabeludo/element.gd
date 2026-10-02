extends Node3D

const POEIRA = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")

@export_enum("crate", "bounce_crate", "pentagram", "spring", "hazard", "checkpoint", "blood", "butterfly") var kind:String = "crate"
@export var bounces:int = 5
@export var travel:Vector3 = Vector3.ZERO
@export var frequency:float = 1.6
@export var launch_target:Vector3
@export var launch_duration:float = 2.4
var home:Vector3
var time:float = 0.0
var cooldown:float = 0.0
var remaining:int
var active:bool = true
var stage:Node3D

func _ready() -> void:
	stage = get_tree().get_first_node_in_group("resgate_stage")
	home = position
	remaining = bounces
	add_to_group("resgate_elements")

func reset_element() -> void:
	active = true
	visible = true
	remaining = bounces
	cooldown = 0.0
	if has_node("Body/CollisionShape3D"):
		$Body/CollisionShape3D.set_deferred("disabled", false)

func retire() -> void:
	active = false
	visible = false
	if has_node("Body/CollisionShape3D"):
		$Body/CollisionShape3D.set_deferred("disabled", true)

func _physics_process(delta:float) -> void:
	if not active or not is_instance_valid(stage):
		return
	var player:CharacterBody3D = stage.player
	if absf(global_position.z - player.global_position.z) > 85.0:
		return
	time += delta
	cooldown = maxf(0.0, cooldown - delta)
	if kind == "butterfly":
		position = home + Vector3(sin(time) * 2.0, sin(time * 2.5) * 0.45, cos(time) * 1.4)
		$Left.rotation.z = sin(time * 18.0) * 0.7
		$Right.rotation.z = -sin(time * 18.0) * 0.7
		return
	if kind == "hazard":
		position = home + travel * sin(time * frequency)
	if not player.control_enabled:
		return
	var diff := player.global_position - global_position
	var horizontal := Vector2(diff.x, diff.z).length()
	match kind:
		"crate", "bounce_crate":
			# Basta passar por cima ou encostar: a caixa joga o Maycon para cima de
			# leve e estoura em poeira, sem precisar de pulo certeiro.
			if cooldown <= 0.0 and horizontal < 1.25 and diff.y > -0.6 and diff.y < 1.8:
				player.soft_bounce()
				cooldown = 0.24
				remaining -= 1
				stage.release_pentagrams(global_position + Vector3.UP * 1.5, 1 if kind == "bounce_crate" else 3)
				stage.sound("wood")
				POEIRA.aterrar(stage, global_position + Vector3.UP * 0.4)
				if kind == "crate" or remaining <= 0:
					stage.burst(global_position + Vector3.UP * 0.5, Color("c89152"), 12)
					retire()
		"pentagram", "blood":
			$Visual.position.y = sin(time * 3.0) * 0.13
			if horizontal < 1.0 and absf(diff.y) < 1.8 and cooldown <= 0.0:
				if kind == "blood":
					stage.heal(18.0)
				else:
					stage.collect(global_position)
				retire()
		"spring":
			if horizontal < 1.5 and diff.y > -0.2 and diff.y < 1.6 and cooldown <= 0.0:
				cooldown = 2.5
				player.launch_to(launch_target, launch_duration)
				stage.sound("spring")
				stage.burst(global_position, Color("69f5ff"), 24)
		"hazard":
			if horizontal < 1.35 and absf(diff.y) < 1.5:
				player.receive_damage(22.0, global_position)
		"checkpoint":
			if horizontal < 3.8 and absf(diff.y) < 2.5:
				stage.checkpoint(self)
