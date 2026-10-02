extends Node3D

@export var max_hp:int = 4
@export var slam_radius:float = 6.0
var hp:int = 4
var active:bool = false
var state:String = "run"
var clock:float = 0.0
var invulnerable:float = 0.0
var origin:Vector3
var target:Vector3
var stage:Node3D
@onready var animation:AnimationPlayer = $Visual.find_child("AnimationPlayer", true, false)
@onready var skeleton:Skeleton3D = $Visual.find_child("Skeleton3D", true, false) as Skeleton3D

func _ready() -> void:
	stage = get_tree().get_first_node_in_group("resgate_stage")
	hp = max_hp
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
	state = "run"
	clock = 0.0
	invulnerable = 1.0
	if animation:
		animation.stop()
	if skeleton:
		skeleton.reset_bone_poses()

func _physics_process(delta:float) -> void:
	if not active or not stage.player.control_enabled:
		return
	clock += delta
	invulnerable = maxf(0.0, invulnerable - delta)
	var player:CharacterBody3D = stage.player
	match state:
		"run":
			position.x = sin(clock * 1.1) * 9.0
			$Visual.position.y = 2.28 + absf(sin(clock * 8.0)) * 0.13
			$Visual.rotation.y = PI * 0.5 if cos(clock * 1.1) > 0.0 else -PI * 0.5
			pose_running(clock * 8.0)
			if clock >= 4.0:
				state = "warn"
				clock = 0.0
				target = Vector3(clampf(player.position.x, -11, 11), 0, clampf(player.position.z, -1812, -1788))
				$Warning.global_position = target + Vector3.UP * 0.08
				$Warning.visible = true
				play("Jump_Prep")
		"warn":
			$Warning.scale = Vector3.ONE * (0.85 + sin(clock * 15) * 0.1)
			if clock >= 1.3:
				state = "jump"
				clock = 0.0
				origin = global_position
				stage.sound("grunt")
				play("Jump_Ascent")
		"jump":
			var t := minf(clock / 2.0, 1.0)
			global_position = origin.lerp(target, t) + Vector3.UP * sin(t * PI) * 14.0
			$Warning.global_position = target + Vector3.UP * 0.08
			if t >= 1.0:
				state = "rest"
				clock = 0.0
				$Warning.visible = false
				play("Belly_Flop")
				stage.sound("slam")
				stage.burst(global_position, Color("c9b785"), 28)
				if Vector2(player.position.x - position.x, player.position.z - position.z).length() < slam_radius and player.position.y < 1.6:
					player.receive_damage(30, global_position)
		"rest":
			if clock > 3.6:
				state = "run"
				clock = 0.0
				if animation:
					animation.stop()
				if skeleton:
					skeleton.reset_bone_poses()
	var diff := player.global_position - global_position
	var horizontal := Vector2(diff.x, diff.z).length()
	if horizontal < 2.2 and diff.y > 3.2 and diff.y < 5.5 and player.velocity.y < -1.0 and invulnerable <= 0.0:
		hp -= 1
		invulnerable = 2.0
		player.bounce()
		stage.sound("hit")
		stage.burst(global_position + Vector3.UP * 4, Color("ffdb6a"), 22)
		stage.update_hud()
		if hp <= 0:
			active = false
			play("Belly_Flop")
			stage.finish()
	elif horizontal < 1.8 and diff.y < 3.2 and diff.y > -1.0 and state != "rest":
		player.receive_damage(20, global_position)

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
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, angle))
