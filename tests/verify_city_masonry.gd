extends SceneTree

func _init() -> void:
	call_deferred("run")
func run() -> void:
	var original:Node3D = load("res://scenes/3D/last_fight_before_end.tscn").instantiate()
	var city:Node3D = original.get_node("cidade")
	var anchor:Transform3D = original.get_node("ResgateCityAnchor").transform
	original.remove_child(city)
	original.free()
	var world:Node3D = Node3D.new()
	root.add_child(world)
	world.add_child(city)
	var cinematic:Node3D = load("res://scenes/3D/resgate_cabeludo/city_cutscene.tscn").instantiate()
	var fixture:GDScript = GDScript.new()
	fixture.source_code = "extends \"res://scripts/3D/resgate_cabeludo/city_cutscene.gd\"\nfunc _ready()->void: pass\nfunc _process(_delta:float)->void: pass\nfunc sound(_path:String)->void: pass\n"
	assert(fixture.reload() == OK)
	cinematic.set_script(fixture)
	cinematic.transform = anchor
	world.add_child(cinematic)
	var start:Vector3 = Vector3(-.6, 1.05, -113)
	cinematic.maycon.position = start
	cinematic.begin_masonry_crossing()
	var breach:Vector3 = cinematic.get_node("CigarroBuilding").position + Vector3(0,2.8,0)
	for i in range(1,161):
		var elapsed:float = float(i) / 160.0 * 8.0
		if elapsed <= .9:
			var t:float = elapsed / .9
			cinematic.maycon.position = start.lerp(breach,t) + Vector3.UP * sin(t*PI)*.5
		else:
			var t:float = (elapsed-.9)/7.1
			cinematic.maycon.position = breach.lerp(Vector3(24,168,58),t) + Vector3.UP * sin(t*PI)*26
		cinematic.check_masonry_crossing()
	cinematic.masonry_impacts_active = false
	var chunks:Array[Node] = cinematic.find_children("MasonryChunk*", "RigidBody3D", false, false)
	var passed:bool = cinematic.masonry_impacts>0 && chunks.size()>=36
	print("Impacts on actual city rebound path: ", cinematic.masonry_impacts)
	print("OK building intersection creates real masonry fragments" if passed else "FAIL no building impact on rebound")
	if !chunks.is_empty():
		var chunk:RigidBody3D = chunks[0]
		passed = passed && chunk.linear_velocity.y>9 && chunk.gravity_scale>1
		for i in range(85): await physics_frame
		passed = passed && chunk.linear_velocity.y<0
		print("OK masonry flies upward then falls under gravity" if passed else "FAIL masonry trajectory")
	world.free()
	quit(0 if passed else 1)
