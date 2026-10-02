extends Camera2D

const OLD_FILM_SHADER = preload("res://scenes/3D/poco_infinito_old_film.gdshader")

@onready var camera_2d_maycon: Camera2D = $"../maycon_fase/Camera2D"
@onready var msg_block: Label = $msg_block
@onready var fade: Node2D = $fade
@onready var maycon_fase: CharacterBody2D = $"../maycon_fase"
@onready var me: Camera2D = $"."
@onready var animacoes: AnimationPlayer = $"../animacoes"
@onready var inimigo_boss_seco: AnimatedSprite2D = $inimigo_boss_seco
@onready var canvas_layer: CanvasLayer = $"../CanvasLayer"
@onready var pause: Control = $"../../Pause"


func _on_ready() -> void:
	if Global.game_events["seco_first_scene_castle"]==false:
		pause.queue_free()
		$"../../maycon_itens".get_node("canvas").visible = false
		canvas_layer.visible = false
		_create_old_film_filter()
		GameSongs.stop(1)
		inimigo_boss_seco.get_node("hps").visible = false
		maycon_fase.visible = false
		maycon_fase.process_mode = Node.PROCESS_MODE_DISABLED
		
		#executa cena do seco levando o cabelo somente 1x
		me.make_current()
		
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		msg_block.text = tr("SECO_CASTLE_1")
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(1.0).timeout
		
		
		
		animacoes.play("seco_first_scene_castle")
		
		
		await get_tree().create_timer(2.0).timeout
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		msg_block.text = tr("SECO_CASTLE_3")
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(1.0).timeout
		
		await get_tree().create_timer(2.0).timeout
		fade.get_node("Transition").play("fade_in")
		msg_block.visible = true
		msg_block.text = "                         " + tr("SECO_CASTLE_4")
		
		await get_tree().create_timer(2.0).timeout		
		fade.get_node("Transition").play("fade_out")
		await get_tree().create_timer(3.0).timeout
		
		#TODO: TEM QUE TER UM IF AQUI PRA NAO IR PRA O MUNDO 3D CASO JAH TENHA IDO E VENCIDO
		get_tree().paused = false
		GameSongs.stop(1)
		#get_tree().change_scene_to_file("res://scenes/3D/world_3d.tscn")
		Global.cena_caminho_das_pedras = false
		get_tree().change_scene_to_file("res://scenes/3D/seco_boss_intro.tscn")
		
		
		#TODO: GANHANDO A BATALHA SALVA AS PARADA ABAIXO
		
		#volta ao jogo
		#maycon_fase.visible = true
		#$Running.stop()
		#$"../../maycon_itens".get_node("canvas").visible = true
		#GameSongs.play_song(1)
		#Global.game_events["seco_first_scene_castle"]=true #-------------->>>>>>> ATIVAR ESSE SOMENTE APOS MATAR O BOSS 3D
		#Global.save_progress(get_tree().current_scene.name)
		#maycon_fase.process_mode = Node.PROCESS_MODE_INHERIT
		#camera_2d_maycon.make_current()
		#$"../../auto_fade_in".get_node("Transition").play("fade_in")
		#canvas_layer.visible = true

func _create_old_film_filter() -> void:
	var film_rect := ColorRect.new()
	film_rect.name = "OldFilmFilter"
	film_rect.position = $ColorRect.position
	film_rect.size = $ColorRect.size
	film_rect.z_index = 100
	film_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material := ShaderMaterial.new()
	material.shader = OLD_FILM_SHADER
	material.set_shader_parameter("sepia_amount", 0.16)
	material.set_shader_parameter("grain_amount", 0.025)
	material.set_shader_parameter("grain_speed", 20.0)
	material.set_shader_parameter("vignette_intensity", 0.28)
	material.set_shader_parameter("vignette_radius", 1.08)
	material.set_shader_parameter("flicker_intensity", 0.012)
	material.set_shader_parameter("scratch_intensity", 0.10)
	material.set_shader_parameter("dust_intensity", 0.12)
	material.set_shader_parameter("jitter_amount", 0.00012)
	film_rect.material = material
	add_child(film_rect)

	msg_block.z_index = 110
	fade.z_index = 200
		
