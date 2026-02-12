extends Node3D
@onready var maycon_3d: Node3D = $maycon_3d
@onready var fade: Node2D = $fade
@onready var cidade_perdida: Label = $cidade_perdida
@onready var cutscene_inicio: AnimationPlayer = $cutscene/cutscene_inicio
@onready var the_almost_end_song: AudioStreamPlayer = $TheAlmostEndSong
@onready var luz_mapa: DirectionalLight3D = $pause_3d_moto_cidade/luz_mapa
@onready var balao_marker: Marker2D = $balao


var balao_

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# cutscene
	get_tree().get_first_node_in_group("player").get_node("hud_canvas").get_node("maycon_hp").visible = false
	Global.in_cutscene = true
	luz_mapa.visible = true
	maycon_3d.process_mode = Node.PROCESS_MODE_DISABLED
	cutscene_inicio.play("intro_mapa")
	#_on_cutscene_inicio_animation_finished("intro_mapa")
	


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
		maycon_3d.process_mode = Node.PROCESS_MODE_INHERIT
		luz_mapa.visible = false
		#seta final do game para pegar equipar a moto
		fade.get_node("Transition").play("fade_in")
		var player = get_tree().get_first_node_in_group("player")
		player.set_final_game()
		player.get_node("hud_canvas").get_node("maycon_hp").visible = false
		the_almost_end_song.play()
		player.set_rain(true)
		Global.in_cutscene=false


func _on_area_3d_cigarro_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("CHAMOU BALAO!")
		#CHAMA BALAOZINHO
		balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
		if Global.default_language == Global.language_pt_br:
			balao_.falas = ["...", "Não sei onde o Cabelo foi parar...", "Já olhei por toda cidade e nada...", "Continue procurando Maycon!"]
		else:
			balao_.falas = ["...", "I don't know where Cabelo went...", "I've looked all over town and found nothing...", "Keep looking, Maycon!"]
		
		balao_.balao_sem_seta = true
		balao_marker.add_child(balao_)


func _on_area_3d_cigarro_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		if balao_:
			balao_.queue_free()


func _on_area_3d_lips_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		print("CHAMOU BALAO!")
		#CHAMA BALAOZINHO
		balao_ = preload("res://scenes/balao_conversa.tscn").instantiate()
		if Global.default_language == Global.language_pt_br:
			balao_.falas = ["...", "Rapaz....", "Fala ai nego veio?", "Que que tu quer por aqui na redondeza mano brown?", "Não vi nenhum tal de Cabelo não cara...", "Mete o pé vacilão!", "Senão te lanço um pescotapa!"]
		else:
			balao_.falas = ["...", "Hey man...", "What's up old man?", "What do you want around here, Mano Brown?", "I didn't see any guy named Cabelo, man...", "Get out of here, you idiot!", "Or I'll give you a slap!"]
		
		balao_.balao_sem_seta = true
		balao_marker.add_child(balao_)


func _on_area_3d_lips_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		if balao_:
			balao_.queue_free()
