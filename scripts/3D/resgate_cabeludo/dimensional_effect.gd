extends Node3D

const DUST = preload("res://scripts/3D/resgate_cabeludo/poeira.gd")
var duration:float = 4.8
var elapsed:float = 0.0
var returning:bool = false
var rings:Array[MeshInstance3D] = []
var glow:Sprite3D
var pixels:CPUParticles3D
var motes:CPUParticles3D
var light:OmniLight3D

func setup(is_returning:bool,duration_seconds:float) -> void:
	returning = is_returning
	duration = duration_seconds
	var color := Color("ffd88b") if returning else Color("79bfc9")
	for i in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 1.1+float(i)*.13
		torus.outer_radius = torus.inner_radius+.035
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = glowing(color,.0)
		add_child(ring)
		rings.append(ring)
	glow = Sprite3D.new()
	glow.texture = DUST.textura()
	glow.pixel_size = .048
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.modulate = Color(color,0)
	add_child(glow)
	pixels = particles(190,color,true)
	motes = particles(140,color,false)
	light = OmniLight3D.new()
	light.light_color = color
	light.omni_range = 7
	light.light_energy = 0
	add_child(light)

func glowing(color:Color,alpha:float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color,alpha)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func particles(amount:int,color:Color,square:bool) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.amount = amount
	emitter.lifetime = 1.6 if square else 2.2
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 1.1 if square else 1.7
	emitter.direction = Vector3.UP
	emitter.spread = 140
	emitter.gravity = Vector3(0,.15,0)
	emitter.initial_velocity_min = .35
	emitter.initial_velocity_max = 1.5
	emitter.scale_amount_min = .45
	emitter.scale_amount_max = 1.1
	emitter.angular_velocity_min = -130
	emitter.angular_velocity_max = 130
	var mesh:Mesh
	if square:
		var chip := BoxMesh.new()
		chip.size = Vector3(.065,.065,.015)
		mesh = chip
	else:
		var quad := QuadMesh.new()
		quad.size = Vector2(.12,.12)
		mesh = quad
	var mat := glowing(color,1)
	mat.vertex_color_use_as_albedo = true
	if not square:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = DUST.textura()
	mesh.material = mat
	emitter.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,0))
	fade.set_color(1,Color(1,1,1,0))
	fade.add_point(.18,Color.WHITE)
	fade.add_point(.65,Color.WHITE)
	emitter.color_ramp = fade
	add_child(emitter)
	emitter.emitting = false
	return emitter

func _process(delta:float) -> void:
	if rings.is_empty(): return
	elapsed += delta
	var progress := clampf(elapsed/duration,0,1)
	var weight := smoothstep(0,.16,progress)*(1-smoothstep(.78,1,progress))
	for i in rings.size():
		var ring := rings[i]
		ring.rotation = Vector3(PI*.5+sin(elapsed*.9+float(i))*.55,elapsed*(.65+float(i)*.2),float(i)*PI/3+elapsed*.4)
		ring.scale = Vector3.ONE*(.7+weight*(.7 if returning else 1.4))
		ring.material_override.albedo_color.a = weight*.65
	glow.modulate.a = weight*.24
	glow.scale = Vector3.ONE*(1+weight*.55)
	light.light_energy = weight*2.8
	pixels.color.a = weight
	motes.color.a = weight
	pixels.emitting = progress<.83
	motes.emitting = progress<.83
	pixels.rotation.y += delta*1.8
	motes.rotation.y -= delta*.7
	if elapsed>duration+2.2: queue_free()
