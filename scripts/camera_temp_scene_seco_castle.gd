extends Camera2D

@onready var camera_2d_maycon: Camera2D = $"../maycon_fase/Camera2D"
@onready var msg_block: Label = $msg_block
@onready var fade: Node2D = $fade
@onready var maycon_fase: CharacterBody2D = $"../maycon_fase"
@onready var me: Camera2D = $"."
@onready var animacoes: AnimationPlayer = $"../animacoes"
@onready var inimigo_boss_seco: AnimatedSprite2D = $inimigo_boss_seco
@onready var canvas_layer: CanvasLayer = $"../CanvasLayer"


func _on_ready() -> void:
	if Global.game_events["seco_first_scene_castle"]==false:
		$"../../maycon_itens".get_node("canvas").visible = false
		canvas_layer.visible = false
		GameSongs.stop(1)
		inimigo_boss_seco.get_node("hps").visible = false
		maycon_fase.visible = false
		maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
		
		#executa cena do seco levando o cabelo somente 1x
		me.make_current()
		
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		if Global.default_language == Global.language_pt_br:
			msg_block.text = "Volte aqui Olindão!"
		else:
			msg_block.text = "Come back here Olindão!"
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(1.0).timeout
		
		
		
		await get_tree().create_timer(2.0).timeout
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		if Global.default_language == Global.language_pt_br:
			msg_block.text = "Estou te avisando!"
		else:
			msg_block.text = "I'm not gonna say it again!"
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(1.0).timeout
		
		
		animacoes.play("seco_first_scene_castle")
		
		
		await get_tree().create_timer(2.0).timeout
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		if Global.default_language == Global.language_pt_br:
			msg_block.text = "Eu vou te pegar AGORA Tripa Maior!"
		else:
			msg_block.text = "I'm gonna catch you NOW Tripa Maior!"
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(3.0).timeout
		
		
		#TODO: TEM QUE TER UM IF AQUI PRA NAO IR PRA O MUNDO 3D CASO JAH TENHA IDO E VENCIDO
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")
		
		#TODO: GANHANDO A BATALHA SALVA AS PARADA ABAIXO
		
		#volta ao jogo
		#maycon_fase.visible = true
		#$Running.stop()
		#$"../../maycon_itens".get_node("canvas").visible = true
		#GameSongs.play_song(1)
		#Global.game_events["seco_first_scene_castle"]=true
		#Global.save_progress(get_tree().current_scene.name)
		#maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
		#camera_2d_maycon.make_current()
		#$"../../auto_fade_in".get_node("Transition").play("fade_in")
		#canvas_layer.visible = true
		
