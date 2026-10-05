extends SceneTree

var failures:int = 0
func _init() -> void:
	call_deferred("run")
func check(message:String, passed:bool) -> void:
	print(("OK " if passed else "FAIL ") + message)
	if !passed: failures += 1
func fixture(path:String, code:String) -> GDScript:
	var script:GDScript = GDScript.new()
	script.source_code = 'extends "%s"\n%s' % [path,code]
	assert(script.reload() == OK)
	return script
func frames(count:int) -> void:
	for i in count: await physics_frame
func box(parent:Node3D, at:Vector3, size:Vector3) -> void:
	var body:StaticBody3D = StaticBody3D.new()
	body.position = at
	var collision:CollisionShape3D = CollisionShape3D.new()
	var shape:BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
func run() -> void:
	var global:Node = root.get_node("Global")
	var player_root:Node = load("res://scenes/3D/maycon_3d.tscn").instantiate()
	root.add_child(player_root)
	var player:Node = player_root.get_node("CharacterBody3D")
	global.maycon_pegou_arma_first_3d_battle = true
	player.gun_bullets_count = 10
	player.set_wood_melee_mode(true)
	Input.action_press("ui_up")
	Input.action_press("tiro")
	await frames(4)
	Input.action_release("ui_up")
	Input.action_release("tiro")
	check("wood attack and movement never reveal the 2D gun", !player.control_gun.visible && !player.hud_gun_buttons.visible && player.gun_bullets_count == 10)
	player_root.free()
	var battle:Node = load("res://scripts/realtime_battle.gd").new()
	var sprite:AnimatedSprite2D = AnimatedSprite2D.new()
	var normal:AnimatedSprite2D = AnimatedSprite2D.new()
	battle.minions.clear()
	for pair:Array in [[sprite,true],[normal,false]]:
		battle.minions.append({"sprite":pair[0],"sprite_reversed":pair[1],"position":Vector2(800,400),"base_scale":3.2,"behavior":"approach","dead":false})
	battle.update_minion_transforms()
	check("Light Bandit flips visually without changing other capangas", sprite.scale.x < 0 && normal.scale.x > 0)
	sprite.free()
	normal.free()
	battle.free()
	global.maycon_pegou_lamp_3d_world = false
	global.maycon_pegou_gas_3d_world = false
	global.maycon_pegou_lamp_fire_3d_world = false
	var passage:Node = load("res://scenes/3D/cenario_3d_bofore_castle_1.tscn").instantiate()
	passage.set_script(fixture("res://scripts/3D/cenario_3d_bofore_castle_1.gd", "func _ready()->void: pass\nfunc _process(_delta:float)->void: pass\nfunc _exit_tree()->void: pass\n"))
	root.add_child(passage)
	passage.build_objective_hint()
	global.maycon_pegou_lamp_3d_world = true
	passage.update_objective_hint()
	check("lantern pickup shows fuel objective", passage.objective_key == "PASSAGE_FIND_FUEL")
	global.maycon_pegou_gas_3d_world = true
	passage.update_objective_hint()
	check("fuel pickup shows fire objective", passage.objective_key == "PASSAGE_FIND_FIRE")
	global.maycon_pegou_lamp_fire_3d_world = true
	passage.update_objective_hint()
	check("lit lantern shows exit objective", passage.objective_key == "PASSAGE_FIND_EXIT")
	passage.free()
	var world:Node3D = Node3D.new()
	root.add_child(world)
	var camera:Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	world.add_child(camera)
	box(world, Vector3(0,-.5,0), Vector3(20,1,20))
	box(world, Vector3(1,.41,0), Vector3(2,.82,4))
	var walker:CharacterBody3D = fixture("res://scripts/3D/platform_maycon.gd", "func _ready()->void: pass\nfunc _physics_process(delta:float)->void:\n\tvelocity.x = 4.8\n\tvelocity.y -= 23.0 * delta\n\t_step_over_small_lip(delta)\n\tmove_and_slide()\n").new()
	var collider:CollisionShape3D = CollisionShape3D.new()
	var capsule:CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = .9
	walker.add_child(collider)
	walker.position = Vector3(-2,.02,0)
	world.add_child(walker)
	await frames(45)
	check("Maycon walks over the .82m relief without jumping",walker.position.x>.5 && walker.position.y>.8)
	world.free()
	print("CITY/PASSAGE: %d failures" % failures)
	quit(0 if failures==0 else 1)
