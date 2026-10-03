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
	# Na fase a cutscene nasce ao lado do WorldEnvironment da cidade; sem um irmão
	# com esse nome o ajuste de iluminação da cena nem roda. Precisa ser irmão em
	# root: a troca de cena só libera a cutscene enquanto ela é filha de root.
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = Environment.new()
	root.add_child(world)
	var city:Node3D = load("res://scenes/3D/resgate_cabeludo/city_cutscene.tscn").instantiate()
	city.pace = .08
	root.add_child(city)
	current_scene = city
	await frames(2)
	check("city starts the requested soundtrack",city.city_song.playing and city.city_song.stream.get_length()>50)
	check("city soundtrack does not loop",not city.city_song.stream.loop)
	var env:Environment = city.camera.environment
	# Entre o dia da versão anterior e a noite fechada da gameplay que a antecede.
	check("cutscene is lit as dusk instead of daylight",env.ambient_light_energy>.2 and env.ambient_light_energy<.4 and env.adjustment_enabled and env.adjustment_brightness<1.0)
	var trails := 0
	for node in city.plane.get_children():
		if node is GPUParticles3D and not node.local_coords and node.emitting: trails += 1
	check("plane leaves two trails and has backward wind lines",trails==2 and city.plane.get_node("VentoDoAviao").velocidade>0)
	var lips_third_person := true
	var lips_angles := {}
	var lips_shots := {}
	var breath_in_fp := false
	var breath_only_fp := true
	var rebound_peak := 0.0
	var rebound_away := false
	var running_fp := false
	var running_tp := false
	var jumping_dust := false
	var correct_grip := false
	var fell_to_spring := false
	var bounced := false
	var white_end := false
	var faded_music := false
	var unobstructed := true
	var held_samples := 0
	var paper_attached := true
	var paper_turns := false
	var largest_hand_gap := 0.0
	var gap_phase := ""
	var previous_grip_phase := -1
	var settled_grip_frames := 0
	var previous_paper_basis := Basis.IDENTITY
	var flashes := 0
	var flash_peak := 0.0
	var blur_idle := 1.0
	var blur_peak := 0.0
	var blur_turns := false
	var previous_blur_direction := Vector2.ZERO
	var lips_min_fov := 65.0
	var lips_max_fov := 0.0
	var maycon_min_fov := 65.0
	var maycon_max_fov := 0.0
	var building := AABB(Vector3(9,0,-108),Vector3(10,10.4,12))
	var roof := AABB(Vector3(8.5,10.35,-108.5),Vector3(11,.5,13))
	for i in 900:
		if not is_instance_valid(city): break
		if not city.is_inside_tree():
			await process_frame
			continue
		if city.follow==city.lips:
			lips_third_person = lips_third_person and not city.bob and city.lips.visible
			if city.follow_offset.z>2: lips_angles["atras"] = true
			if city.follow_offset.z< -2: lips_angles["frente"] = true
			if absf(city.follow_offset.x)>6 and absf(city.follow_offset.z)<3: lips_angles["lado"] = true
			lips_shots[str(city.follow_offset)] = true
		if city.breath_audio.playing:
			breath_in_fp = breath_in_fp or (city.bob and city.maycon_running)
			breath_only_fp = breath_only_fp and city.bob and city.maycon_running
		if city.maycon_entered:
			rebound_peak = maxf(rebound_peak,city.maycon.position.y)
			if city.maycon.position.y>100 and city.plane.position.z<0:
				rebound_away = rebound_away or city.maycon.position.z>0
		if city.attached:
			var sheet:AnimatedSprite3D = city.hair
			var half_height:float = sheet.sprite_frames.get_frame_texture(sheet.animation,sheet.frame).get_height()*sheet.pixel_size*.5
			var held_edge:Vector3 = sheet.global_transform * Vector3(0,half_height,0)
			var local_edge:Vector3 = sheet.transform * Vector3(0,half_height,0)
			paper_attached = paper_attached and sheet.get_parent() is BoneAttachment3D and sheet.get_parent().bone_name=="Arm_Lower.R" and sheet.billboard==BaseMaterial3D.BILLBOARD_DISABLED and local_edge.distance_to(Vector3(0,.3,0))<.001
			var grip_phase:int = 1 if city.lips_running else 2 if city.lips_hanging else 0
			settled_grip_frames = settled_grip_frames + 1 if grip_phase==previous_grip_phase else 0
			previous_grip_phase = grip_phase
			# BoneAttachment acompanha a pose na atualização de render, após os timers
			# que trocam a animação. Aguarda essa atualização antes de medir no mundo.
			if grip_phase>0 and settled_grip_frames>2:
				var gap:float = held_edge.distance_to(city.lips_hand_transform().origin)
				if gap>largest_hand_gap:
					largest_hand_gap = gap
					gap_phase = "run=%s / hanging=%s" % [city.lips_running,city.lips_hanging]
				paper_attached = paper_attached and gap<.12
			if held_samples>0: paper_turns = paper_turns or not sheet.global_basis.is_equal_approx(previous_paper_basis)
			previous_paper_basis = sheet.global_basis
			held_samples += 1
		if city.lips_running and city.focus==city.lips:
			lips_min_fov = minf(lips_min_fov,city.camera.fov)
			lips_max_fov = maxf(lips_max_fov,city.camera.fov)
		if city.maycon_running and city.follow==city.maycon and not city.bob:
			maycon_min_fov = minf(maycon_min_fov,city.camera.fov)
			maycon_max_fov = maxf(maycon_max_fov,city.camera.fov)
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
		var flash:float = city.get_node("HUD/MemoryFlash").color.a
		flashes = city.flashes
		flash_peak = maxf(flash_peak,flash)
		var blur:float = city.blur_material.get_shader_parameter("blur_strength")
		blur_idle = minf(blur_idle,blur)
		blur_peak = maxf(blur_peak,blur)
		var blur_direction:Vector2 = city.blur_material.get_shader_parameter("blur_direction")
		blur_turns = blur_turns or (previous_blur_direction!=Vector2.ZERO and blur_direction.dot(previous_blur_direction)<.99)
		previous_blur_direction = blur_direction
		var color:Color = city.get_node("HUD/Fade").color
		if color.a>.98:
			white_end = color.r==1 and color.g==1 and color.b==1
			faded_music = city.city_song.volume_db< -55
		unobstructed = unobstructed and not building.has_point(city.camera.position) and not roof.has_point(city.camera.position)
		await frames(1)
	world.queue_free()
	check("Lips running and jump shots stay in third person",lips_third_person)
	check("Lips focus alternates between behind, front and side angles",lips_angles.size()==3)
	check("Lips coverage is cut into many distinct camera angles",lips_shots.size()>=9)
	check("Maycon breathing plays only in the first person running takes",breath_in_fp and breath_only_fp)
	check("final rebound hurls Maycon higher and against the plane's heading",rebound_peak>140 and rebound_away)
	if rebound_peak<=140 or not rebound_away: print("Rebound: peak %.1f away=%s" % [rebound_peak,rebound_away])
	check("paper stays attached by its edge to Lips' animated right hand",held_samples>100 and paper_attached and paper_turns)
	if not paper_attached: print("Largest hand gap: %.3f (%s)" % [largest_hand_gap,gap_phase])
	check("every take change flashes like a memory cut",flashes>=22 and flash_peak>.5)
	if flashes<22 or flash_peak<=.5: print("Flashes: %d (peak %.2f)" % [flashes,flash_peak])
	check("motion blur stays light but follows the camera",blur_idle>.0 and blur_idle<.12 and blur_peak>.25 and blur_peak<=.52 and blur_turns)
	if not (blur_peak>.25 and blur_peak<=.52): print("Blur range: %.3f..%.3f (%d flashes)" % [blur_idle,blur_peak,flashes])
	check("Lips running shots gradually zoom toward him",lips_max_fov>62 and lips_min_fov<54)
	check("Maycon third person running shot gradually zooms toward him",maycon_max_fov>62 and maycon_min_fov<54)
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
