extends Node3D
@onready var maycon_3d: Node3D = $maycon_3d
@onready var fade: Node2D = $fade
@onready var cidade_perdida: Label = $cidade_perdida
@onready var cutscene_inicio: AnimationPlayer = $cutscene/cutscene_inicio
@onready var the_almost_end_song: AudioStreamPlayer = $TheAlmostEndSong


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# cutscene
	get_tree().get_first_node_in_group("player").get_node("hud_canvas").get_node("maycon_hp").visible = false
	cutscene_inicio.play("intro_mapa")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_chao_body_entered(body: Node3D) -> void:
	get_tree().reload_current_scene()


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(1.5).timeout 
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(2.0).timeout 
		get_tree().change_scene_to_file("res://scenes/demo_end.tscn")


func _on_cutscene_inicio_animation_finished(anim_name: StringName) -> void:
	if anim_name == "intro_mapa":
		#seta final do game para pegar equipar a moto
		fade.get_node("Transition").play("fade_in")
		var player = get_tree().get_first_node_in_group("player")
		player.set_final_game()
		player.get_node("hud_canvas").get_node("maycon_hp").visible = true
		player.set_rain(true)
		the_almost_end_song.play()
