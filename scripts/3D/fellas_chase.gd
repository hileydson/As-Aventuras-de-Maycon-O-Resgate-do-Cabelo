extends Node3D

signal all_escaped

const BLOOD_SCENE = preload("res://scenes/3D/blood.tscn")
const GUN_SOUND = preload("res://assets/novos_audios/gun_shot.mp3")
const ENGINE_SOUND = preload("res://assets/novos_audios/motorcycle_sound.mp3")
const BATTLE_SONG = preload("res://assets/novos_audios/battle.mp3")
const PAIN_SOUND = preload("res://assets/novos_audios/DS_pain.mp3")
const MARKER_TEXTURE = preload("res://assets/novas_imagens/objects/interrogacao.png")
const MAX_HP := 16
const MINIMAP_SIZE := 220.0
const MINIMAP_WORLD_SIZE := 360.0

var player:CharacterBody3D
var members:Array[Dictionary] = []
var hud:CanvasLayer
var battle_music:AudioStreamPlayer
var player_hp_bar:ProgressBar
var player_hp_text:Label
var speed_lines:Array[Line2D] = []
var close_blurs:Array[Line2D] = []
var minimap_root:Control
var minimap_viewport:SubViewport
var minimap_camera:Camera3D
var minimap_markers:Array[Label] = []
var chase_clock:float = 0.0
var finished:bool = false
var combat_enabled:bool = false
var last_escape_position:Vector3

func start_chase(chase_player:CharacterBody3D) -> void:
	player = chase_player
	var names := ["Lips", "Iago", "Luqs", "Tony"]
	var textures := [
		["lips_moto", "lips_moto_looking", "lips_moto_shoot"],
		["iago_moto", "iago_moto_looking", "iago_moto_shoot"],
		["luqs_moto", "luqs_moto_looking", "luqs_moto_shoot"],
		["tony_moto", "tony_moto_looking", "tony_moto_shoot"]
	]
	build_hud()
	update_player_health()
	build_minimap(names)
	for index in names.size():
		var member_textures:Array[Texture2D] = []
		for texture_name in textures[index]:
			member_textures.append(load("res://assets/novas_imagens/npcs/%s.png" % texture_name))
		var sprite := Sprite3D.new()
		sprite.name = names[index] + "Moto"
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.layers = 2
		sprite.pixel_size = 0.006
		sprite.no_depth_test = false
		sprite.texture = member_textures[0]
		add_child(sprite)
		var angle:float = [-0.4, 0.5, -1.0, 1.1][index] + randf_range(-0.1, 0.1)
		var player_forward := -player.global_basis.z
		player_forward.y = 0.0
		var offset:Vector3 = player_forward.rotated(Vector3.UP, angle) * [38.0, 75.0, 105.0, 135.0][index]
		sprite.global_position = road_position(player.global_position + offset)
		var marker := Sprite3D.new()
		marker.name = names[index] + "MapMarker"
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.texture = MARKER_TEXTURE
		marker.pixel_size = 0.06
		marker.visible = false
		add_child(marker)
		var map_name := Label3D.new()
		map_name.text = names[index].to_upper()
		map_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		map_name.font_size = 48
		map_name.pixel_size = 0.12
		map_name.outline_size = 12
		map_name.position.y = -19.0
		marker.add_child(map_name)
		var engine := AudioStreamPlayer3D.new()
		engine.stream = ENGINE_SOUND.duplicate()
		(engine.stream as AudioStreamMP3).loop = true
		engine.max_distance = 80.0
		engine.unit_size = 7.0
		engine.pitch_scale = 0.86 + index * 0.07
		engine.volume_db = -9.0
		sprite.add_child(engine)
		engine.play()
		var gun := AudioStreamPlayer3D.new()
		gun.stream = GUN_SOUND
		gun.max_distance = 75.0
		gun.unit_size = 7.0
		sprite.add_child(gun)
		var pain := AudioStreamPlayer3D.new()
		pain.stream = PAIN_SOUND
		pain.max_distance = 65.0
		pain.unit_size = 7.0
		sprite.add_child(pain)
		members.append({"sprite":sprite, "marker":marker, "engine":engine, "gun":gun, "pain":pain,
			"textures":member_textures, "hp":MAX_HP, "active":false, "escaped":false,
			"heading":Vector3(sin(angle), 0.0, cos(angle)), "target":Vector3.ZERO,
			"turn_timer":0.0, "shot_timer":randf_range(0.8, 1.6), "shot_state":0,
			"shot_delay":0.0, "burst_remaining":0, "aim_direction":Vector3.ZERO,
			"lost_timer":0.0, "phase":randf() * TAU,
			"bar":hud.get_node("Margin/HBox/Enemy%d/HP" % index),
			"hp_text":hud.get_node("Margin/HBox/Enemy%d/HPText" % index),
			"cross":hud.get_node("Margin/HBox/Enemy%d/Cross" % index),
			"minimap_label":minimap_markers[index]})
	update_minimap()
	battle_music = AudioStreamPlayer.new()
	battle_music.stream = BATTLE_SONG.duplicate()
	(battle_music.stream as AudioStreamMP3).loop = true
	battle_music.volume_db = -6.0
	add_child(battle_music)
	battle_music.play()
	player.motorcycle_fire.connect(on_player_fire)
	player.set_motorcycle_chase(true)

func road_position(target:Vector3) -> Vector3:
	target.x = clampf(target.x, -670.0, 490.0)
	target.z = clampf(target.z, -330.0, 825.0)
	var from := Vector3(target.x, -2.0, target.z)
	var to := Vector3(target.x, -18.0, target.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if !hit.is_empty():
		target.y = (hit["position"] as Vector3).y + 2.1
	else:
		target.y = player.global_position.y + 2.0
	return target

func build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 92
	add_child(hud)
	var player_margin := MarginContainer.new()
	player_margin.name = "PlayerHealth"
	player_margin.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	player_margin.offset_left = -150.0
	player_margin.offset_right = 150.0
	player_margin.offset_top = -75.0
	player_margin.offset_bottom = -75.0
	hud.add_child(player_margin)
	var player_column := VBoxContainer.new()
	player_column.add_theme_constant_override("separation", 3)
	player_margin.add_child(player_column)
	var player_name := Label.new()
	player_name.text = tr("HUD_MAYCON_NAME").to_upper()
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name.add_theme_font_size_override("font_size", 16)
	player_name.add_theme_color_override("font_color", Color("ffe6a7"))
	player_column.add_child(player_name)
	player_hp_bar = ProgressBar.new()
	player_hp_bar.max_value = player.danos_count_limit
	player_hp_bar.value = player.danos_count_limit
	player_hp_bar.show_percentage = false
	player_hp_bar.custom_minimum_size = Vector2(300.0, 14.0)
	var player_fill := StyleBoxFlat.new()
	player_fill.bg_color = Color("cf2633")
	player_fill.corner_radius_top_left = 4
	player_fill.corner_radius_top_right = 4
	player_fill.corner_radius_bottom_left = 4
	player_fill.corner_radius_bottom_right = 4
	player_hp_bar.add_theme_stylebox_override("fill", player_fill)
	var player_background := StyleBoxFlat.new()
	player_background.bg_color = Color("3b1018")
	player_hp_bar.add_theme_stylebox_override("background", player_background)
	player_column.add_child(player_hp_bar)
	player_hp_text = Label.new()
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_text.add_theme_font_size_override("font_size", 12)
	player_hp_text.add_theme_color_override("font_color", Color("efb4b5"))
	player_column.add_child(player_hp_text)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_CENTER_TOP)
	margin.offset_left = -280.0
	margin.offset_right = 280.0
	margin.offset_top = 92.0
	margin.offset_bottom = 92.0
	hud.add_child(margin)
	var row := HBoxContainer.new()
	row.name = "HBox"
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	for index in 4:
		var box := VBoxContainer.new()
		box.name = "Enemy%d" % index
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		var name_label := Label.new()
		name_label.text = ["LIPS", "IAGO", "LUQS", "TONY"][index]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color("ffe6a7"))
		box.add_child(name_label)
		var hp := ProgressBar.new()
		hp.name = "HP"
		hp.max_value = MAX_HP
		hp.value = MAX_HP
		hp.show_percentage = false
		hp.custom_minimum_size.y = 8.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("c51d2b")
		fill.corner_radius_top_left = 3
		fill.corner_radius_top_right = 3
		fill.corner_radius_bottom_left = 3
		fill.corner_radius_bottom_right = 3
		hp.add_theme_stylebox_override("fill", fill)
		var background := StyleBoxFlat.new()
		background.bg_color = Color("3b1018")
		background.corner_radius_top_left = 3
		background.corner_radius_top_right = 3
		background.corner_radius_bottom_left = 3
		background.corner_radius_bottom_right = 3
		hp.add_theme_stylebox_override("background", background)
		box.add_child(hp)
		var hp_text := Label.new()
		hp_text.name = "HPText"
		hp_text.text = "%d/%d" % [MAX_HP, MAX_HP]
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_text.add_theme_font_size_override("font_size", 11)
		hp_text.add_theme_color_override("font_color", Color("efb4b5"))
		box.add_child(hp_text)
		var cross := Label.new()
		cross.name = "Cross"
		cross.text = "✕"
		cross.visible = false
		cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cross.add_theme_font_size_override("font_size", 20)
		cross.add_theme_color_override("font_color", Color.RED)
		box.add_child(cross)
	for index in 14:
		var line := Line2D.new()
		line.width = randf_range(1.0, 3.0)
		line.default_color = Color(0.9, 0.95, 1.0, randf_range(0.12, 0.34))
		line.visible = false
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.ZERO)
		hud.add_child(line)
		speed_lines.append(line)
	for index in 8:
		var blur := Line2D.new()
		blur.width = 12.0 + index % 3 * 9.0
		blur.default_color = Color(0.7, 0.78, 0.9, 0.2) if index % 2 == 0 else Color(0.04, 0.07, 0.12, 0.28)
		blur.visible = false
		blur.add_point(Vector2.ZERO)
		blur.add_point(Vector2.ZERO)
		hud.add_child(blur)
		close_blurs.append(blur)

func build_minimap(names:Array) -> void:
	minimap_root = Control.new()
	minimap_root.name = "ChaseMinimap"
	minimap_root.position = Vector2(16.0, 16.0)
	minimap_root.custom_minimum_size = Vector2.ONE * MINIMAP_SIZE
	minimap_root.size = Vector2.ONE * MINIMAP_SIZE
	minimap_root.clip_contents = true
	minimap_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(minimap_root)
	var background := ColorRect.new()
	background.color = Color(0.1, 0.12, 0.15)
	background.size = Vector2.ONE * MINIMAP_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(background)
	var container := SubViewportContainer.new()
	container.position = Vector2(3.0, 3.0)
	container.size = Vector2.ONE * (MINIMAP_SIZE - 6.0)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(container)
	minimap_viewport = SubViewport.new()
	minimap_viewport.size = Vector2i(214, 214)
	minimap_viewport.world_3d = get_world_3d()
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(minimap_viewport)
	minimap_camera = Camera3D.new()
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.cull_mask = 1
	minimap_camera.size = MINIMAP_WORLD_SIZE
	minimap_camera.near = 0.5
	minimap_camera.far = 260.0
	minimap_viewport.add_child(minimap_camera)
	minimap_camera.make_current()
	var tint := ColorRect.new()
	tint.color = Color(0.34, 0.3, 0.22, 0.22)
	var tint_material := CanvasItemMaterial.new()
	tint_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tint.material = tint_material
	tint.size = Vector2.ONE * MINIMAP_SIZE
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_root.add_child(tint)
	var frame := Panel.new()
	frame.size = Vector2.ONE * MINIMAP_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color("e3b065")
	border.border_width_left = 2
	border.border_width_top = 2
	border.border_width_right = 2
	border.border_width_bottom = 2
	frame.add_theme_stylebox_override("panel", border)
	minimap_root.add_child(frame)
	for name in names:
		var label := Label.new()
		label.text = String(name).to_upper()
		label.size = Vector2(48.0, 18.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color("ff5750"))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		minimap_root.add_child(label)
		minimap_markers.append(label)
	var player_marker := Polygon2D.new()
	player_marker.polygon = PackedVector2Array([Vector2(0.0, -10.0), Vector2(-7.0, 8.0), Vector2(7.0, 8.0)])
	player_marker.color = Color("54e6ff")
	player_marker.position = Vector2.ONE * MINIMAP_SIZE * 0.5
	minimap_root.add_child(player_marker)
	update_minimap()

func update_minimap() -> void:
	if !is_instance_valid(player) or !is_instance_valid(minimap_camera):
		return
	minimap_camera.global_position = player.global_position + Vector3(0.0, 105.0, 0.0)
	minimap_camera.global_basis = Basis(Vector3.UP, player.rotation.y) * Basis(Vector3.RIGHT, -PI * 0.5)
	var center := Vector2.ONE * MINIMAP_SIZE * 0.5
	var pixels_per_meter := (MINIMAP_SIZE - 6.0) / MINIMAP_WORLD_SIZE
	var edge := MINIMAP_SIZE * 0.5 - 28.0
	for index in members.size():
		var member := members[index]
		var label := minimap_markers[index]
		label.visible = !member["escaped"]
		if member["escaped"]:
			continue
		var sprite:Sprite3D = member["sprite"]
		var relative:Vector3 = player.global_basis.inverse() * (sprite.global_position - player.global_position)
		var offset := Vector2(relative.x, relative.z) * pixels_per_meter
		var reach := maxf(absf(offset.x), absf(offset.y))
		var outside := reach > edge
		if outside:
			offset *= edge / reach
		label.position = center + offset - label.size * 0.5
		label.add_theme_color_override("font_color", Color("ffb65f") if outside else Color("ff5750"))

func set_map_visible(open:bool) -> void:
	if is_instance_valid(minimap_root):
		minimap_root.visible = !open and !finished
	for member in members:
		var marker:Sprite3D = member["marker"]
		marker.visible = open and !member["escaped"]

func _physics_process(delta:float) -> void:
	if finished or !is_instance_valid(player):
		return
	update_player_health()
	chase_clock += delta
	var any_active := false
	var close_encounter := false
	for member in members:
		if member["escaped"]:
			continue
		var sprite:Sprite3D = member["sprite"]
		var marker:Sprite3D = member["marker"]
		var to_player := player.global_position - sprite.global_position
		var distance := Vector2(to_player.x, to_player.z).length()
		var player_forward := -player.global_basis.z
		var sight := player_forward.dot(-to_player.normalized())
		if combat_enabled and !member["active"] and distance < 42.0 and sight > 0.35:
			member["active"] = true
			member["lost_timer"] = 0.0
		if member["active"]:
			if distance > 80.0:
				member["lost_timer"] += delta
				if member["lost_timer"] > 4.0:
					member["active"] = false
					member["shot_state"] = 0
			else:
				member["lost_timer"] = 0.0
		if member["active"]:
			any_active = true
			close_encounter = close_encounter or (distance < 33.0 and sight > 0.4)
			move_chasing(member, delta, distance)
			process_enemy_shot(member, delta, distance)
		else:
			move_wandering(member, delta)
			sprite.texture = member["textures"][0]
		sprite.position.y += sin(chase_clock * 18.0 + member["phase"]) * 0.002
		marker.global_position = sprite.global_position + Vector3(0.0, 67.0, 0.0)
		(member["engine"] as AudioStreamPlayer3D).pitch_scale = 0.86 + (0.17 if member["active"] else 0.0) + sin(chase_clock * 3.0 + member["phase"]) * 0.025
	update_minimap()
	update_speed_lines(any_active, close_encounter)

func update_player_health() -> void:
	if !is_instance_valid(player_hp_bar) or !is_instance_valid(player):
		return
	var remaining:int = maxi(0, player.danos_count_limit - player.danos_count)
	player_hp_bar.value = remaining
	player_hp_text.text = "%d/%d" % [remaining, player.danos_count_limit]

func move_wandering(member:Dictionary, delta:float) -> void:
	var sprite:Sprite3D = member["sprite"]
	member["turn_timer"] -= delta
	if member["turn_timer"] <= 0.0 or sprite.global_position.distance_to(member["target"]) < 7.0:
		member["turn_timer"] = randf_range(3.0, 6.0)
		var angle := randf() * TAU
		member["target"] = road_position(sprite.global_position + Vector3(sin(angle), 0.0, cos(angle)) * randf_range(24.0, 65.0))
	var direction:Vector3 = (member["target"] as Vector3) - sprite.global_position
	direction.y = 0.0
	if direction.length() > 0.1:
		member["heading"] = (member["heading"] as Vector3).lerp(direction.normalized(), minf(1.0, delta * 1.2)).normalized()
		move_member(member, delta, 8.0)

func move_chasing(member:Dictionary, delta:float, distance:float) -> void:
	var sprite:Sprite3D = member["sprite"]
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var side := player.global_basis.x
	side.y = 0.0
	var preferred_distance := 29.0 + sin(chase_clock * 0.8 + member["phase"]) * 6.0
	var preferred := player.global_position + forward * preferred_distance + side * sin(chase_clock * 0.65 + member["phase"]) * 7.0
	var heading := preferred - sprite.global_position
	heading.y = 0.0
	if distance < 15.0:
		heading += forward * 20.0
	if distance > 55.0:
		heading -= forward * 10.0
	if heading.length() > 0.1:
		member["heading"] = (member["heading"] as Vector3).lerp(heading.normalized(), minf(1.0, delta * 1.5)).normalized()
	var player_speed := Vector2(player.velocity.x, player.velocity.z).length()
	move_member(member, delta, maxf(10.0, player_speed + 2.0))

func move_member(member:Dictionary, delta:float, speed:float) -> void:
	var sprite:Sprite3D = member["sprite"]
	var heading:Vector3 = member["heading"]
	var target := sprite.global_position + heading * speed * delta
	var ray := PhysicsRayQueryParameters3D.create(sprite.global_position + Vector3.UP, target + Vector3.UP)
	ray.exclude = [player.get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		sprite.global_position = road_position(target)
	else:
		member["turn_timer"] = 0.0
		member["heading"] = heading.rotated(Vector3.UP, randf_range(0.8, 1.8))

func process_enemy_shot(member:Dictionary, delta:float, distance:float) -> void:
	if finished or !combat_enabled:
		return
	var sprite:Sprite3D = member["sprite"]
	member["shot_timer"] -= delta
	if member["shot_state"] == 0 and member["shot_timer"] <= 0.0 and distance < 55.0:
		member["shot_state"] = 1
		member["shot_delay"] = 0.48
		member["burst_remaining"] = randi_range(1, 4)
		var aim:Vector3 = player.global_position - sprite.global_position
		aim.y = 0.0
		member["aim_direction"] = aim.normalized()
		sprite.texture = member["textures"][1]
	elif member["shot_state"] == 1:
		member["shot_delay"] -= delta
		if member["shot_delay"] <= 0.0:
			member["shot_state"] = 2
			member["shot_delay"] = 0.16
			sprite.texture = member["textures"][2]
	elif member["shot_state"] == 2:
		member["shot_delay"] -= delta
		if member["shot_delay"] <= 0.0:
			(member["gun"] as AudioStreamPlayer3D).play()
			var to_player := player.global_position - sprite.global_position
			to_player.y = 0.0
			var aim_direction:Vector3 = member["aim_direction"]
			if distance < 50.0 and to_player.length() > 0.1 and aim_direction.dot(to_player.normalized()) > 0.96:
				var ray := PhysicsRayQueryParameters3D.create(sprite.global_position + Vector3.UP * 1.5, player.global_position + Vector3.UP)
				ray.exclude = [player.get_rid()]
				if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
					player.levou_dano(1)
					update_player_health()
			if to_player.length() > 0.1:
				member["aim_direction"] = aim_direction.lerp(to_player.normalized(), 0.4).normalized()
			member["burst_remaining"] -= 1
			member["shot_state"] = 3 if member["burst_remaining"] > 0 else 4
			member["shot_delay"] = randf_range(0.14, 0.22)
			if member["shot_state"] == 3:
				sprite.texture = member["textures"][1]
	elif member["shot_state"] == 3:
		member["shot_delay"] -= delta
		if member["shot_delay"] <= 0.0:
			member["shot_state"] = 2
			member["shot_delay"] = 0.12
			sprite.texture = member["textures"][2]
	elif member["shot_state"] == 4:
		member["shot_delay"] -= delta
		if member["shot_delay"] <= 0.0:
			member["shot_state"] = 0
			member["shot_timer"] = randf_range(1.1, 1.8)
			sprite.texture = member["textures"][0]

func on_player_fire() -> void:
	if finished:
		return
	var camera:Camera3D = player.get_node("Camera3D")
	var forward := -camera.global_basis.z
	var closest:Dictionary = {}
	var best_distance := 72.0
	for member in members:
		if member["escaped"] or !member["active"]:
			continue
		var sprite:Sprite3D = member["sprite"]
		var to_enemy := sprite.global_position + Vector3(0.0, 1.0, 0.0) - camera.global_position
		var distance := to_enemy.length()
		if distance < best_distance and forward.dot(to_enemy.normalized()) > 0.975:
			var ray := PhysicsRayQueryParameters3D.create(camera.global_position, sprite.global_position + Vector3.UP)
			ray.exclude = [player.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				closest = member
				best_distance = distance
	if closest.is_empty():
		return
	closest["hp"] = maxi(0, int(closest["hp"]) - 1)
	(closest["bar"] as ProgressBar).value = closest["hp"]
	(closest["hp_text"] as Label).text = "%d/%d" % [closest["hp"], MAX_HP]
	if int(closest["hp"]) % 3 == 0:
		(closest["pain"] as AudioStreamPlayer3D).play()
	var sprite:Sprite3D = closest["sprite"]
	var blood := BLOOD_SCENE.instantiate()
	add_child(blood)
	blood.global_position = sprite.global_position + Vector3(0.0, 1.2, 0.0)
	sprite.modulate = Color(1.0, 0.72, 0.72)
	if closest["hp"] <= 0:
		eliminate_member(closest)

func eliminate_member(member:Dictionary) -> void:
	member["escaped"] = true
	member["active"] = false
	(member["minimap_label"] as Label).visible = false
	(member["cross"] as Label).visible = true
	(member["marker"] as Sprite3D).visible = false
	(member["engine"] as AudioStreamPlayer3D).pitch_scale = 1.5
	var sprite:Sprite3D = member["sprite"]
	last_escape_position = sprite.global_position
	var escape_to := sprite.global_position + (member["heading"] as Vector3) * 130.0
	var tween := create_tween()
	tween.tween_property(sprite, "global_position", escape_to, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): sprite.visible = false; (member["engine"] as AudioStreamPlayer3D).stop())
	for other in members:
		if !other["escaped"]:
			return
	finished = true
	minimap_root.visible = false
	player.set_motorcycle_chase(false)
	battle_music.stop()
	all_escaped.emit()

func update_speed_lines(active:bool, close:bool) -> void:
	var size := get_viewport().get_visible_rect().size
	for index in speed_lines.size():
		var line := speed_lines[index]
		line.visible = active
		if active:
			var phase := fposmod(chase_clock * (350.0 + index * 23.0) + index * 85.0, size.y + 180.0)
			var x := size.x * (0.04 + 0.92 * float(index) / speed_lines.size())
			line.set_point_position(0, Vector2(x, phase - 115.0))
			line.set_point_position(1, Vector2(x + (x - size.x * 0.5) * 0.05, phase))
	for index in close_blurs.size():
		var blur := close_blurs[index]
		blur.visible = close
		if close:
			var phase := fposmod(chase_clock * (540.0 + index * 27.0) + index * 170.0, size.y + 250.0) - 125.0
			var side := -1.0 if index % 2 == 0 else 1.0
			var x := size.x * (0.1 if side < 0.0 else 0.9)
			blur.set_point_position(0, Vector2(x + side * 95.0, phase - 95.0))
			blur.set_point_position(1, Vector2(x - side * 90.0, phase + 120.0))
