extends Node3D

@onready var arma: Area3D = $Area3D
@onready var gun_load: AudioStreamPlayer = $GunLoad
@onready var seco_welcome: AudioStreamPlayer = $SecoWelcome
@onready var maycon_3d: Node3D = $maycon_3d
@onready var you_died: Label = $you_died
@onready var fire_seco_3d: Node3D = $fire_seco_3d
@onready var fade: Node2D = $fade


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.maycon_danos_first_3d_battle = 0
	Global.maycon_pegou_arma_first_3d_battle = false
	
	await get_tree().create_timer(3.0).timeout
	seco_welcome.play()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	# YOU DIED
	if Global.maycon_danos_first_3d_battle == 5:
		#get_tree().paused = true
		you_died.visible = true
		fire_seco_3d.process_mode = Node.PROCESS_MODE_DISABLED
		maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(3.0).timeout 
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout 
		get_tree().change_scene_to_file("res://scenes/fase_1_before_castle_4.tscn") 
	
	print("DANOS MAYCON: -> "+str(Global.maycon_danos_first_3d_battle))
	print("DANOS SECO: -> "+str(Global.seco_danos_first_3d_battle))
	
	if Global.maycon_pegou_arma_first_3d_battle && arma:
		arma.queue_free()
	


func _on_area_3d_body_entered(body: Node3D) -> void:
	Global.maycon_pegou_arma_first_3d_battle = true
	gun_load.play()
	maycon_3d.get_node("CharacterBody3D").add_bullets_to_gun(5)
	
	
