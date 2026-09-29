extends Node2D
const PROLOGUE_PORTAL_EFFECT = preload("res://scripts/prologue_portal_effect.gd")

@onready var jamelao_song: AudioStreamPlayer = $JamelaoSong
@onready var song_1: AudioStreamPlayer = $song_1
@onready var explosao_portal: Node2D = $explosao_portal
@onready var inimigo_1: Node2D = get_node_or_null("Inimigo1")
@onready var camera: Camera2D = $Maycon/Camera2D
@onready var inimigo_seco: Node2D = $Inimigo_seco
@onready var mark_balao_seco: Marker2D = $mark_balao_seco
@onready var explosao_portal_2: Node2D = $explosao_portal2

var prologue_portal: Node2D
var portal_unlocked := false
var portal_transition_started := false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.game_events["before_prologo"] = true
	Global.save_progress("prologo")
	inimigo_seco.z_index = 3
	_create_prologue_portal()
	_configure_portal_trigger()
	$Area2_portal.monitoring = false
	explosao_portal.visible = false
	explosao_portal_2.visible = false

func _create_prologue_portal() -> void:
	prologue_portal = PROLOGUE_PORTAL_EFFECT.new()
	prologue_portal.name = "ProloguePortalEffect"
	prologue_portal.position = inimigo_seco.position + Vector2(-10.0, 70.0)
	prologue_portal.z_index = 2
	add_child(prologue_portal)

func _configure_portal_trigger() -> void:
	var collision_shape: CollisionShape2D = $Area2_portal/CollisionShape2D
	var trigger_shape := CircleShape2D.new()
	trigger_shape.radius = 108.0
	$Area2_portal.position = prologue_portal.position
	$Area2_portal.rotation = 0.0
	$Area2_portal.scale = Vector2.ONE
	collision_shape.position = Vector2.ZERO
	collision_shape.shape = trigger_shape

func activate_prologue_portal() -> void:
	if portal_unlocked:
		return
	portal_unlocked = true
	if is_instance_valid(prologue_portal):
		prologue_portal.activate()
	$Area2_portal.monitoring = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if Global.back_to_main_camera == true:
		camera.make_current()
		Global.back_to_main_camera = false
	
func _on_area_2_portal_body_entered(body: Node2D) -> void:
	if !portal_unlocked or portal_transition_started or body != $Maycon:
		return
	portal_transition_started = true
	get_tree().change_scene_to_file("res://scenes/tunel_fogo.tscn")
