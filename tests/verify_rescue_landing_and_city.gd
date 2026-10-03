extends SceneTree

# Geometria das bordas e pousos reais, sem executar a abertura nem a batalha.
const LANDING_FIXTURE = """
extends "res://scripts/3D/resgate_cabeludo/stage.gd"
var impacts:int = 0
func opening() -> void:
	intro_active = false
	fade.color.a = 0
	player.auto_run = false
	player.control_enabled = true
func sound(key:String) -> void:
	if key=="hit": impacts += 1
	super.sound(key)
"""

var failures:int = 0
func _init() -> void:
	call_deferred("run")
func check(label:String,condition:bool) -> void:
	print(("OK " if condition else "FAIL ")+label)
	if not condition: failures += 1
func frames(count:int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var stage:Node3D = load("res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn").instantiate()
	var fixture := GDScript.new()
	fixture.source_code = LANDING_FIXTURE
	if fixture.reload()!=OK:
		quit(1)
		return
	stage.set_script(fixture)
	root.add_child(stage)
	current_scene = stage
	await frames(3)
	for enemy in get_nodes_in_group("resgate_enemies"): enemy.active = false
	for element in get_nodes_in_group("resgate_elements"): element.active = false
	var floating := 0
	var anonymous := 0
	for zone in stage.get_node("Forest").get_children():
		for node in zone.get_children():
			if not node is Node3D or not node.scene_file_path.begins_with("res://assets/kenney/platformer_3d/"): continue
			if str(node.name).begins_with("@Node3D"): anonymous += 1
			var d:float = -node.position.z
			if (d>660 and d<700) or (d>1040 and d<1070): floating += 1
	check("all vegetation names are checked, including generated names",anonymous>100)
	check("large platform gaps have no floating vegetation",floating==0)
	stage.player.position = Vector3(0,3,-10)
	stage.player.velocity = Vector3.ZERO
	var floor_reached := false
	for i in 100:
		await frames(1)
		if stage.player.is_on_floor():
			floor_reached = true
			break
	await frames(2)
	check("ordinary landing plays punch sound exactly once",floor_reached and stage.impacts==1)
	var rising := false
	var at_feet := false
	for node in stage.get_children():
		if node is GPUParticles3D and node.process_material is ParticleProcessMaterial:
			rising = rising or node.process_material.direction.y>.9
			at_feet = at_feet or node.global_position.distance_to(stage.player.global_position)<.2
	check("landing creates upward dust at Maycon's feet",rising and at_feet)
	var punch_audio := false
	for node in stage.get_children():
		if node is AudioStreamPlayer and node.stream:
			punch_audio = punch_audio or node.stream.resource_path.ends_with("punch_4.mp3")
	check("landing uses the existing gameplay punch recording",punch_audio)
	await frames(25)
	check("walking on the floor does not repeat landing sounds",stage.impacts==1)
	stage.player.position = Vector3(0,-17.9,-650)
	stage.player.velocity = Vector3.ZERO
	stage.player.was_airborne = false
	await frames(3)
	var start_impacts:int = stage.impacts
	stage.player.launch_to(Vector3(0,.3,-708),3.3)
	var landed := false
	for i in 320:
		await frames(1)
		if stage.impacts>start_impacts:
			landed = true
			break
	check("trampoline crosses the gap and lands on the next platform",landed and stage.player.global_position.z<-700 and stage.player.global_position.y>-.5)
	check("trampoline landing also plays one punch and clears flight dust",stage.impacts==start_impacts+1 and not stage.player.pending_landing and not is_instance_valid(stage.player.jump_dust))
	# Cena integrada: o marcador precisa seguir a avenida na direção correta.
	var city:Node3D = load("res://scenes/3D/last_fight_before_end.tscn").instantiate()
	var anchor:Marker3D = city.get_node("ResgateCityAnchor")
	check("city cinematic follows the avenue east from the gas station",(anchor.basis*Vector3.FORWARD).is_equal_approx(Vector3.RIGHT) and anchor.position.distance_to(Vector3(-535,-7.08,-202))<.01)
	var trigger:CollisionShape3D = city.get_node("cabelo/Area3D/CollisionShape3D")
	var trigger_basis:Basis = (city.get_node("cabelo").transform * city.get_node("cabelo/Area3D").transform * trigger.transform).basis
	var half:Vector3 = trigger.shape.size * .5
	var reach_x:float = (trigger_basis * Vector3(half.x,0,0)).length()
	var reach_y:float = (trigger_basis * Vector3(0,half.y,0)).length()
	var reach_z:float = (trigger_basis * Vector3(0,0,half.z)).length()
	check("cutscene trigger reaches Maycon well before the hair",reach_x>6.5 and reach_z>6.5 and reach_y>2.0)
	if reach_x<=6.5 or reach_z<=6.5 or reach_y<=2.0: print("Trigger reach: %.2f x %.2f x %.2f" % [reach_x,reach_y,reach_z])
	var cutscene:Node3D = load("res://scenes/3D/resgate_cabeludo/city_cutscene.tscn").instantiate()
	check("Cabelo starts above the pavement instead of inside it",cutscene.get_node("Hair").position.y>1)
	var cigar:Sprite3D = cutscene.get_node("Cigarro")
	var feet:float = cigar.position.y-cigar.texture.get_height()*cigar.pixel_size*.5
	check("Cigarro stands at the visible front corner of the roof",is_equal_approx(feet,10.85) and cigar.position.x<10 and cigar.position.z> -97)
	cutscene.free()
	city.free()
	stage.queue_free()
	await frames(2)
	print("RESCUE LANDING AND CITY: %d failures" % failures)
	quit(1 if failures else 0)
