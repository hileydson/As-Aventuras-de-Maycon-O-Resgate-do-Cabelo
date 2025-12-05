extends Node2D
@onready var jamelao_song: AudioStreamPlayer = $JamelaoSong
@onready var song_1: AudioStreamPlayer = $song_1
@onready var explosao_portal: Node2D = $explosao_portal
@onready var inimigo_1: Node2D = $Inimigo1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	explosao_portal.get_node("hp").play("semi_explotion")
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if !explosao_portal.get_node("hp").is_playing() :
		explosao_portal.get_node("hp").visible = true
		explosao_portal.get_node("hp").play("semi_explotion")
	
	if explosao_portal.get_node("hp").animation == "explotion":
		inimigo_1.visible = true
		
		


func _on_area_2_portal_body_entered(body: Node2D) -> void:
	get_tree().change_scene_to_file("res://scenes/batalha_2d.tscn")
