extends Area3D

@onready var barra_vida: ProgressBar = $"../../CanvasLayer/ProgressBar"
@onready var growl_fino: AudioStreamPlayer = $"../../Growl_fino"

var hp:int = 100

func receber_dano(dano:int)->void:
	hp -= dano
	# Garante que a vida não fique negativa
	hp = clamp(hp, 0, 100)
	
	# Atualiza o visual da barra
	atualizar_barra()
	
	if hp <= 0:
		morrer()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func atualizar_barra():
	growl_fino.play()
	# O Tween faz a barra descer suavemente em vez de um corte seco
	var tween = create_tween()
	tween.tween_property(barra_vida, "value", hp, 0.2)

func morrer():
	print("Boss derrotado!")
	$"../../..".process_mode = Node.PROCESS_MODE_DISABLED
	$"../../../../maycon_3d".process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().create_timer(3.0).timeout 
	$"../../../../fade".get_node("Transition").play("fade_out")
	await get_tree().create_timer(2.0).timeout 
	Global.game_events["seco_first_scene_castle"]=true
	Global.save_progress("castelo_1")
	get_tree().change_scene_to_file("res://scenes/fase_1_castle_1.tscn") 
