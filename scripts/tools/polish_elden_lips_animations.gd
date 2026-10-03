extends SceneTree

# Amostra os rigs originais em espaço global. As caudas do rig importado de
# Maycon não representam os comprimentos dos braços: usamos os joints reais.
const CONTROLLER = "res://scripts/3D/resgate_cabeludo/elden_lips.gd"
var solver:Node3D
var rig:Node3D
var skeleton:Skeleton3D
var animator:AnimationPlayer
var source:AnimationLibrary
var prefix:String

func _init() -> void:
	call_deferred("bake")

func pose_point(t:float,points:Array) -> Vector3:
	for i in range(1,points.size()):
		if t<=points[i][0]:
			var weight := smoothstep(points[i-1][0],points[i][0],t)
			return (points[i-1][1] as Vector3).lerp(points[i][1],weight)
	return points[-1][1]

func rotate_joint(name:String,axis:Vector3,angle:float) -> void:
	var index := skeleton.find_bone(name)
	if index<0: return
	var pose := skeleton.global_transform*skeleton.get_bone_global_pose(index)
	var desired := Quaternion((rig.global_basis*axis).normalized(),angle)*pose.basis.orthonormalized().get_rotation_quaternion()
	var parent := skeleton.get_bone_parent(index)
	var parent_pose := skeleton.global_transform
	if parent>=0: parent_pose *= skeleton.get_bone_global_pose(parent)
	skeleton.set_bone_pose_rotation(index,(parent_pose.basis.orthonormalized().get_rotation_quaternion().inverse()*desired).normalized())

func hips_offset(offset:Vector3) -> void:
	var index := skeleton.find_bone("Hips")
	skeleton.set_bone_pose_position(index,skeleton.get_bone_pose_position(index)+skeleton.global_basis.inverse()*rig.global_basis*offset)

func limb(upper:String,lower:String,hand:String,wrist:Vector3,pole:Vector3) -> void:
	solver._pose_limb(skeleton,upper,lower,hand,rig.global_transform*wrist,rig.global_transform*pole)

func sample_hero(key:String,t:float) -> void:
	var right := Vector3(-.25,1.02,.36)
	var left := Vector3(.20,1.07,.33)
	var sword_roll := 0.0
	var sword_pitch := 0.0
	var crouch := 0.0
	var lean := 0.0
	var yaw := 0.0
	if key in ["slash","slash_alt","heavy"]:
		var heavy := key=="heavy"
		var alternate := key=="slash_alt"
		var contact := .50 if heavy else .40
		var windup := smoothstep(0,contact-.09,t)*(1-smoothstep(contact-.08,contact+.10,t))
		var follow := smoothstep(contact-.08,contact+.06,t)*(1-smoothstep(.67,1,t))
		yaw = (-.43 if not alternate else .35)*windup+(.46 if not alternate else -.40)*follow
		crouch = .065*windup+.045*follow
		lean = .08*windup+.20*follow
		if heavy:
			right = pose_point(t,[[0,right],[.36,Vector3(-.16,1.67,.10)],[.50,Vector3(-.10,.98,.53)],[.68,Vector3(-.29,.88,.38)],[1,right]])
			sword_pitch = -.90*windup+1.0*follow
		else:
			right = pose_point(t,[[0,right],[.23,Vector3(.10 if alternate else -.47,1.42,-.03)],[.41,Vector3(-.40 if alternate else .19,1.12,.46)],[.65,Vector3(-.43 if alternate else .27,.98,.28)],[1,right]])
			sword_roll = (1 if alternate else -1)*(.95*windup-1.12*follow)
			sword_pitch = .30*follow
		left = Vector3(.18,1.15,.36)
	elif key=="pickup":
		var fold := smoothstep(0,.25,t)*(1-smoothstep(.69,1,t))
		crouch = .60*fold
		lean = .78*fold
		right = pose_point(t,[[0,right],[.30,Vector3(-.30,.18,.42)],[.36,Vector3(-.30,.18,.42)],[.49,Vector3(-.30,.62,.36)],[.70,Vector3(-.28,.66,.36)],[1,right]])
		left = pose_point(t,[[0,left],[.42,Vector3(.29,.52,.30)],[.61,Vector3(.32,.18,.38)],[.67,Vector3(.32,.18,.38)],[.82,Vector3(.23,.85,.39)],[1,left]])
		sword_pitch = -1.20*(1-smoothstep(.36,.53,t))*smoothstep(.18,.30,t)
	elif key=="hurt":
		var recoil := smoothstep(0,.12,t)*(1-smoothstep(.28,1,t))
		lean = -.30*recoil
		yaw = -.17*recoil
		crouch = .10*recoil
		right += Vector3(-.08,.17,-.24)*recoil
		left += Vector3(.11,.14,-.19)*recoil
	elif key=="guard":
		left = Vector3(.02,1.28,.38)
		lean = .10
		crouch = .04
	elif key=="walk":
		crouch = .025*(1-cos(t*TAU*2))
		lean = .08
		yaw = sin(t*TAU)*.04
		right.y += sin(t*TAU)*.025
		left.y -= sin(t*TAU)*.025
	else:
		lean = sin(t*TAU)*.015
	hips_offset(Vector3(0,-crouch,0))
	rotate_joint("Spine02",Vector3.RIGHT,lean*.65)
	rotate_joint("Spine01",Vector3.RIGHT,lean*.35)
	rotate_joint("Spine01",Vector3.UP,yaw)
	for side in ["Left","Right"]:
		var sign_side := 1.0 if side=="Left" else -1.0
		var phase:float = t*TAU+(0 if side=="Left" else PI)
		var foot := Vector3(sign_side*.18,.115,.03)
		if key=="walk": foot += Vector3(0,maxf(0,sin(phase))*.095,cos(phase)*.17)
		var foot_index := skeleton.find_bone(side+"Foot")
		var foot_basis := (skeleton.global_transform*skeleton.get_bone_global_pose(foot_index)).basis.orthonormalized()
		limb(side+"UpLeg",side+"Leg",side+"Foot",foot,Vector3(sign_side*.20,.40,.75))
		var parent_pose := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.get_bone_parent(foot_index))
		skeleton.set_bone_pose_rotation(foot_index,(parent_pose.basis.orthonormalized().inverse()*foot_basis).get_rotation_quaternion())
	limb("LeftArm","LeftForeArm","LeftHand",left,Vector3(.60,.98,.06))
	limb("RightArm","RightForeArm","RightHand",right,Vector3(-.60,1.14,.02))
	rotate_joint("RightHand",Vector3.FORWARD,sword_roll)
	rotate_joint("RightHand",Vector3.RIGHT,sword_pitch)

func sample_boss(key:String,t:float) -> void:
	var right := Vector3(-.40,-.03,.16)
	var left := Vector3(.40,-.03,.16)
	var lean := sin(t*TAU)*.014
	var yaw := 0.0
	var crouch := 0.0
	if key=="walk":
		lean = .075
		yaw = sin(t*TAU)*.035
		crouch = .018*(1-cos(t*TAU*2))
		right += Vector3(0,.08,sin(t*TAU)*.08)
		left += Vector3(0,.08,-sin(t*TAU)*.08)
	elif key.ends_with("windup"):
		var raise := smoothstep(0,.78,t)
		if key.begins_with("sweep"):
			right = right.lerp(Vector3(-.70,.36,-.17),raise)
			yaw = -.30*raise
		else:
			right = right.lerp(Vector3(-.29,.89,.18),raise)
			left = left.lerp(Vector3(.29,.85,.19),raise)
			lean = -.15*raise
			crouch = .09*raise
	elif key=="sweep":
		right = pose_point(t,[[0,Vector3(-.70,.36,-.17)],[.43,Vector3(.20,.18,.58)],[.69,Vector3(.30,-.01,.47)],[1,right]])
		yaw = -.3*(1-smoothstep(0,.43,t))+.40*sin(t*PI)
		lean = .14*sin(t*PI)
	elif key=="slam":
		right = pose_point(t,[[0,Vector3(-.29,.89,.18)],[.48,Vector3(-.24,.93,.20)],[.86,Vector3(-.25,-.48,.48)],[1,Vector3(-.35,-.13,.30)]])
		left = Vector3(-right.x,right.y,right.z)
		crouch = .12*smoothstep(.60,.87,t)
		lean = -.12*(1-smoothstep(.4,.7,t))+.48*smoothstep(.6,.85,t)
	elif key=="throw":
		right = pose_point(t,[[0,Vector3(-.29,.89,.18)],[.36,Vector3(-.25,.33,.65)],[.64,Vector3(-.32,.16,.45)],[1,right]])
		left = left.lerp(Vector3(.45,.21,.24),sin(t*PI))
		lean = .19*sin(t*PI)
	elif key in ["hurt","stagger"]:
		var recoil := smoothstep(0,.10,t)*(1-smoothstep(.30,1,t))
		lean = (-.22 if key=="hurt" else .38)*recoil
		yaw = .13*recoil
		crouch = .06*recoil
		right += Vector3(-.06,.19,-.12)*recoil
		left += Vector3(.06,.17,-.12)*recoil
	hips_offset(Vector3(0,-crouch,0))
	rotate_joint("Spine",Vector3.RIGHT,lean)
	rotate_joint("Chest",Vector3.UP,yaw)
	for side in ["L","R"]:
		var sign_side := 1.0 if side=="L" else -1.0
		var foot := Vector3(sign_side*.18,-.955,-.05)
		if key=="walk":
			var phase:float = t*TAU+(0 if side=="L" else PI)
			foot += Vector3(0,maxf(0,sin(phase))*.075,cos(phase)*.16)
		limb("Leg_Upper."+side,"Leg_Lower."+side,"",foot,Vector3(sign_side*.22,-.62,.60))
	limb("Arm_Upper.L","Arm_Lower.L","",left,Vector3(.90,.20,.0))
	limb("Arm_Upper.R","Arm_Lower.R","",right,Vector3(-.90,.20,.0))

func bake() -> void:
	solver = load(CONTROLLER).new()
	for character in ["maycon","lips"]:
		prefix = character
		var resource_path := "res://assets/modelo_3d/elden_lips/"+prefix+"_combat.res"
		var archive_path := "res://assets/modelo_3d/elden_lips/source/"+prefix+"_cmu_base.res"
		if not FileAccess.file_exists(archive_path):
			DirAccess.copy_absolute(resource_path,archive_path)
		source = load(archive_path) as AnimationLibrary
		var original := "res://assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb" if prefix=="maycon" else "res://assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb"
		rig = load(original).instantiate()
		root.add_child(rig)
		skeleton = rig.find_child("Skeleton3D",true,false)
		animator = rig.find_child("AnimationPlayer",true,false)
		animator.stop()
		animator.add_animation_library("base",source)
		var output := source.duplicate(true) as AnimationLibrary
		var specs := {"idle":2.4,"walk":1.0,"pickup":3.2,"slash":.72,"slash_alt":.72,"heavy":1.15,"hurt":.48,"guard":1.0} if prefix=="maycon" else {"idle":2.4,"walk":1.15,"sweep_windup":1.15,"slam_windup":1.35,"throw_windup":1.15,"sweep":.9,"slam":.85,"throw":.9,"hurt":.42,"stagger":2.0}
		var path := str(animator.get_node(animator.root_node).get_path_to(skeleton))
		for key in specs:
			var duration:float = specs[key]
			var animation := Animation.new()
			animation.length = duration
			if key in ["idle","walk","guard"]: animation.loop_mode = Animation.LOOP_LINEAR
			for index in skeleton.get_bone_count():
				for type in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D]:
					var track := animation.add_track(type)
					animation.track_set_path(track,NodePath(path+":"+skeleton.get_bone_name(index)))
			var count := ceili(duration*60)
			for frame in count+1:
				var t := float(frame)/count
				skeleton.reset_bone_poses()
				animator.play("base/"+prefix+"_"+("walk" if key=="walk" else "idle"))
				animator.seek(t*(1 if key=="walk" else 2),true)
				if prefix=="maycon": sample_hero(key,t)
				else: sample_boss(key,t)
				for index in skeleton.get_bone_count():
					animation.rotation_track_insert_key(index*2,t*duration,skeleton.get_bone_pose_rotation(index))
					animation.position_track_insert_key(index*2+1,t*duration,skeleton.get_bone_pose_position(index))
			var name:String = prefix+"_"+key
			if output.has_animation(name): output.remove_animation(name)
			output.add_animation(name,animation)
		if ResourceSaver.save(output,resource_path)!=OK:
			push_error("Could not save polished "+prefix+" animations")
			quit(1)
			return
		print(prefix,": ",output.get_animation_list().size()," clips with joint-based posing")
		rig.free()
	solver.free()
	quit()
