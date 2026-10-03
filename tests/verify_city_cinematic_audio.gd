extends SceneTree

# Executa a sequência completa, a passagem pelo branco e a caminhada do resgate.
var failures:int = 0

func _init() -> void:
	call_deferred("run")

func check(label:String, condition:bool) -> void:
	print(("OK " if condition else "FAIL ") + label)
	if not condition: failures += 1

func frames(count:int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var city:Node3D = load("res://scenes/3D/resgate_cabeludo/city_cutscene.tscn").instantiate()
	city.pace = .08
	root.add_child(city)
	current_scene = city
	await frames(2)
	check("city starts the requested soundtrack",city.city_song.playing and city.city_song.stream.get_length()>50)
	var trails := 0
	for node in city.plane.get_children():
		if node is GPUParticles3D and not node.local_coords and node.emitting: trails += 1
	check("plane leaves two trails and has backward wind lines",trails==2 and city.plane.get_node("VentoDoAviao").velocidade>0)
	var lips_third_person := true
	var running_fp := false
	var running_tp := false
	var jumping_dust := false
	var correct_grip := false
	var fell_to_spring := false
	var bounced := false
	var white_end := false
	var faded_music := false
	var unobstructed := true
	var building := AABB(Vector3(9,0,-108),Vector3(10,10.4,12))
	var roof := AABB(Vector3(8.5,10.35,-108.5),Vector3(11,.5,13))
	for i in 900:
		if not is_instance_valid(city): break
		if city.follow==city.lips:
			lips_third_person = lips_third_person and not city.bob and city.lips.visible and city.follow_offset.z>0
		if city.maycon_running and city.step_audio.playing:
			running_fp = running_fp or (city.bob and not city.maycon.visible)
			running_tp = running_tp or (not city.bob and city.maycon.visible)
		if not city.lips_running and not city.lips_hanging and city.lips.get_parent()==city:
			for node in city.lips.get_children():
				if node is GPUParticles3D and node.emitting: jumping_dust = true
		if city.lips_hanging:
			var sk:Skeleton3D = city.lips_skeleton
			var elbow:Transform3D = sk.get_bone_global_pose(sk.find_bone("Arm_Lower.L"))
			var hand:Vector3 = city.plane.to_local(sk.to_global(elbow * Vector3(0,.3,0)))
			correct_grip = correct_grip or (hand.distance_to(city.PLANE_GRIP)<.02 and elbow.basis.y.normalized().dot(Vector3.UP)>.95 and city.lips.position.y< -6)
		if city.maycon_entered and not city.maycon_running and city.lips.get_parent()==city:
			fell_to_spring = fell_to_spring or city.maycon.position.distance_to(city.get_node("Spring").position)<1.1
			bounced = bounced or (fell_to_spring and city.maycon.position.y>30 and city.lips.position.y>25)
		var color:Color = city.get_node("HUD/Fade").color
		if color.a>.98:
			white_end = color.r==1 and color.g==1 and color.b==1
			faded_music = city.city_song.volume_db< -55
		unobstructed = unobstructed and not building.has_point(city.camera.position) and not roof.has_point(city.camera.position)
		await frames(1)
	check("Lips running and jump shots stay behind Lips and Cabelo",lips_third_person)
	check("Maycon footsteps play in first and third person",running_fp and running_tp)
	check("Lips leaves dust while jumping",jumping_dust)
	check("Lips hangs below the plane with one arm upward and hand attached",correct_grip)
	check("Maycon returns to the same trampoline and rebounds with Lips",fell_to_spring and bounced)
	check("closing fade reaches white and fades the soundtrack",white_end and faded_music)
	check("cinematic camera stays outside Cigarro's building",unobstructed)
	var stage:Node3D = current_scene
	check("city transitions into the rescue scene",is_instance_valid(stage) and stage.scene_file_path=="res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn")
	if not is_instance_valid(stage) or stage.scene_file_path!= "res://scenes/3D/resgate_cabeludo/resgate_cabeludo.tscn":
		quit(1)
		return
	check("rescue starts from full white",stage.fade.color.r==1 and stage.fade.color.g==1 and stage.fade.color.b==1 and stage.fade.color.a>.95)
	await create_timer(1.2).timeout
	check("white opening fade is gradual",stage.fade.color.r==1 and stage.fade.color.a>.4 and stage.fade.color.a<.85)
	for i in 1800:
		if stage.player.control_enabled: break
		await frames(1)
	check("rescue completes opening and restores dark fades",stage.player.control_enabled and stage.fade.color==Color(0,0,0,0))
	stage.player.control_enabled = false
	stage.player.velocity = Vector3.ZERO
	stage.player.global_position = stage.cage.global_position + Vector3(0,0,13)
	stage.player.position.y = .08
	stage.boss.visible = false
	stage.finish()
	var walking := false
	var walk_unchanged := true
	var intervals:Array[float] = []
	var last_step:int = -1
	var previous_timer:float = 0.0
	for i in 3600:
		if not is_instance_valid(stage): break
		if stage.player.animation_player.current_animation=="Skill_03":
			walking = true
			walk_unchanged = walk_unchanged and is_equal_approx(stage.player.animation_player.speed_scale,1) and is_equal_approx(stage.player.velocity.length(),2)
			if stage.player.step_timer>previous_timer:
				if last_step>=0: intervals.append(float(i-last_step)/Engine.physics_ticks_per_second)
				last_step = i
			previous_timer = stage.player.step_timer
		await frames(1)
	var slower := intervals.size()>=2
	for interval in intervals: slower = slower and interval>.8 and interval<1.05
	check("victory keeps Skill_03 and walking speed",walking and walk_unchanged)
	check("victory footsteps have a slower cadence of roughly .9 seconds",slower)
	check("rescue ending completes",is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/3D/resgate_cabeludo/ending_bridge.tscn")
	if is_instance_valid(current_scene): current_scene.queue_free()
	await frames(2)
	print("CITY CINEMATIC AUDIO: %d failures" % failures)
	quit(1 if failures else 0)
