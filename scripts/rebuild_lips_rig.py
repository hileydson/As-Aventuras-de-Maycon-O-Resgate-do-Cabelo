import bpy
import math
from mathutils import Vector

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath="assets/modelo_3d/mario_3d_models/lips_3d.glb")
mesh_obj = bpy.data.objects["Mesh_0"]

# Ensure material uses textures properly
for mat in mesh_obj.data.materials:
    if mat and mat.node_tree:
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                node.inputs["Roughness"].default_value = 0.55
                node.inputs["Metallic"].default_value = 0.0

# Create Armature
arm_data = bpy.data.armatures.new("Lips_Armature")
arm_obj = bpy.data.objects.new("Lips_Rig", arm_data)
bpy.context.scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj

bpy.ops.object.mode_set(mode="EDIT")
def add_bone(name, head, tail, parent_name=None):
    b = arm_data.edit_bones.new(name)
    b.head = head
    b.tail = tail
    if parent_name:
        b.parent = arm_data.edit_bones[parent_name]
    return b

add_bone("Root", (0, 0, -0.95), (0, 0, -0.70))
add_bone("Hips", (0, -0.05, -0.40), (0, -0.02, -0.08), "Root")
add_bone("Spine", (0, -0.02, -0.08), (0, 0.0, 0.25), "Hips")
add_bone("Chest", (0, 0.0, 0.25), (0, 0.0, 0.48), "Spine")
add_bone("Head", (0, 0.0, 0.48), (0, 0.05, 0.95), "Chest")

# Left Leg
add_bone("Leg_Upper.L", (0.16, 0.0, -0.38), (0.16, 0.03, -0.68), "Hips")
add_bone("Leg_Lower.L", (0.16, 0.03, -0.68), (0.16, -0.02, -0.95), "Leg_Upper.L")

# Right Leg
add_bone("Leg_Upper.R", (-0.16, 0.0, -0.38), (-0.16, 0.03, -0.68), "Hips")
add_bone("Leg_Lower.R", (-0.16, 0.03, -0.68), (-0.16, -0.02, -0.95), "Leg_Upper.R")

# Left Arm
add_bone("Arm_Upper.L", (0.24, 0.0, 0.44), (0.55, 0.0, 0.42), "Chest")
add_bone("Arm_Lower.L", (0.55, 0.0, 0.42), (0.88, 0.0, 0.40), "Arm_Upper.L")

# Right Arm
add_bone("Arm_Upper.R", (-0.24, 0.0, 0.44), (-0.55, 0.0, 0.42), "Chest")
add_bone("Arm_Lower.R", (-0.55, 0.0, 0.42), (-0.88, 0.0, 0.40), "Arm_Upper.R")

bpy.ops.object.mode_set(mode="OBJECT")

# Parent mesh to armature with automatic weights
mesh_obj.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

print("Skinning done, creating actions...")

bpy.ops.object.mode_set(mode="POSE")
pb = arm_obj.pose.bones
for bone in pb:
    bone.rotation_mode = "XYZ"

def reset_pose():
    for bone in pb:
        bone.location = Vector((0, 0, 0))
        bone.rotation_euler = Vector((0, 0, 0))
        bone.scale = Vector((1, 1, 1))

def insert_all_keys(frame):
    for bone in pb:
        bone.keyframe_insert(data_path="location", frame=frame)
        bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        bone.keyframe_insert(data_path="scale", frame=frame)

arm_obj.animation_data_create()
created_actions = []

# Helper: Sit pose
def apply_sit_pose(breath_fac=0.0):
    reset_pose()
    pb["Hips"].location = Vector((0, -0.05, -0.48 + breath_fac * 0.02))
    pb["Hips"].rotation_euler = Vector((math.radians(12), 0, 0))
    pb["Spine"].rotation_euler = Vector((math.radians(-6 - breath_fac * 4), 0, 0))
    pb["Chest"].rotation_euler = Vector((math.radians(-4 - breath_fac * 3), 0, 0))
    pb["Head"].rotation_euler = Vector((math.radians(breath_fac * 5), 0, 0))
    pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(72), 0, math.radians(-22)))
    pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-28), 0, 0))
    pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(72), 0, math.radians(22)))
    pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-28), 0, 0))
    pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-55), 0, math.radians(25)))
    pb["Arm_Lower.L"].rotation_euler = Vector((0, 0, math.radians(20)))
    pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-55), 0, math.radians(-25)))
    pb["Arm_Lower.R"].rotation_euler = Vector((0, 0, math.radians(-20)))

# -----------------
# 1. Action: Idle (Sitting pose with breathing)
# -----------------
act_idle = bpy.data.actions.new("Idle")
arm_obj.animation_data.action = act_idle
apply_sit_pose(0.0)
insert_all_keys(0)
apply_sit_pose(1.0)
insert_all_keys(30)
apply_sit_pose(0.0)
insert_all_keys(60)
created_actions.append(act_idle)

# -----------------
# 2. Action: Turn (Girando o corpo, quadris e pés para olhar a próxima plataforma)
# -----------------
act_turn = bpy.data.actions.new("Turn")
arm_obj.animation_data.action = act_turn

# Frame 0: Base sitting
apply_sit_pose(0.0)
insert_all_keys(0)

# Frame 10: Lift one leg, swivel torso and head towards turn direction
reset_pose()
pb["Hips"].location = Vector((0, -0.04, -0.42))
pb["Hips"].rotation_euler = Vector((math.radians(8), math.radians(-10), math.radians(18)))
pb["Spine"].rotation_euler = Vector((0, 0, math.radians(15)))
pb["Chest"].rotation_euler = Vector((0, 0, math.radians(18)))
pb["Head"].rotation_euler = Vector((math.radians(-5), math.radians(-12), math.radians(25)))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(85), 0, math.radians(-35)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-15), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(60), 0, math.radians(10)))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-35), 0, math.radians(40)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-65), 0, math.radians(-10)))
insert_all_keys(10)

# Frame 20: Settle other side, adjusting footing
reset_pose()
pb["Hips"].location = Vector((0, -0.05, -0.45))
pb["Hips"].rotation_euler = Vector((math.radians(10), math.radians(6), math.radians(-8)))
pb["Spine"].rotation_euler = Vector((0, 0, math.radians(-6)))
pb["Head"].rotation_euler = Vector((math.radians(5), 0, math.radians(10)))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(68), 0, math.radians(-15)))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(80), 0, math.radians(28)))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-50), 0, math.radians(15)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-45), 0, math.radians(-30)))
insert_all_keys(20)

# Frame 30: Settle into sit
apply_sit_pose(0.0)
insert_all_keys(30)
created_actions.append(act_turn)

# -----------------
# 3. Action: Jump_Prep (Agachando profundamente com as pernas comprimidas, juntando força para saltar)
# -----------------
act_prep = bpy.data.actions.new("Jump_Prep")
arm_obj.animation_data.action = act_prep

apply_sit_pose(0.0)
insert_all_keys(0)

# Frame 12: Sinking down, spreading knees, hands bracing back
reset_pose()
pb["Hips"].location = Vector((0, -0.10, -0.56))
pb["Hips"].rotation_euler = Vector((math.radians(28), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(18), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(18), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-24), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(92), 0, math.radians(-22)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-55), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(92), 0, math.radians(22)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-55), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-45), 0, math.radians(-40)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-45), 0, math.radians(40)))
insert_all_keys(12)

# Frame 22: Maximum deep squat compression, trembling with power
reset_pose()
pb["Hips"].location = Vector((0, -0.14, -0.62))
pb["Hips"].scale = Vector((1.18, 1.18, 0.82))
pb["Hips"].rotation_euler = Vector((math.radians(35), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(22), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(20), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-30), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(98), 0, math.radians(-26)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-65), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(98), 0, math.radians(26)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-65), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-50), 0, math.radians(-50)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-50), 0, math.radians(50)))
insert_all_keys(22)

# Frame 30: Holding the intense squat just before release
insert_all_keys(30)
created_actions.append(act_prep)

# -----------------
# 4. Action: Jump_Ascent (Disparo para cima)
# -----------------
act_ascent = bpy.data.actions.new("Jump_Ascent")
arm_obj.animation_data.action = act_ascent

reset_pose()
pb["Hips"].location = Vector((0, 0.05, -0.10))
pb["Hips"].rotation_euler = Vector((math.radians(-15), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(-8), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(12), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(-20), 0, math.radians(-10)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(20), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(-20), 0, math.radians(10)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(20), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(40), 0, math.radians(20)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(40), 0, math.radians(-20)))
insert_all_keys(0)

pb["Hips"].location = Vector((0, 0.08, -0.05))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(60), 0, math.radians(30)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(60), 0, math.radians(-30)))
insert_all_keys(15)
insert_all_keys(30)
created_actions.append(act_ascent)

# -----------------
# 5. Action: Belly_Dive (Mergulho no ar com a barriga e cara para baixo)
# -----------------
act_dive = bpy.data.actions.new("Belly_Dive")
arm_obj.animation_data.action = act_dive

reset_pose()
# Torso arched backwards like a skydiver (belly leading down)
pb["Hips"].location = Vector((0, 0.0, -0.15))
pb["Hips"].rotation_euler = Vector((math.radians(70), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(15), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(15), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-40), 0, 0))
# Arms spread out wide like wings
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(30), 0, math.radians(70)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(30), 0, math.radians(-70)))
# Legs trailing behind
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(-30), 0, math.radians(-20)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(35), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(-30), 0, math.radians(20)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(35), 0, 0))
insert_all_keys(0)

# Wobble in flight
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(45), 0, math.radians(80)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(45), 0, math.radians(-80)))
pb["Head"].rotation_euler = Vector((math.radians(-35), 0, 0))
insert_all_keys(12)

pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(30), 0, math.radians(70)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(30), 0, math.radians(-70)))
pb["Head"].rotation_euler = Vector((math.radians(-40), 0, 0))
insert_all_keys(24)
created_actions.append(act_dive)

# -----------------
# 6. Action: Belly_Flop (Queda com a cara e barriga no chão - SPLAT!)
# -----------------
act_flop = bpy.data.actions.new("Belly_Flop")
arm_obj.animation_data.action = act_flop

# Frame 0: Entering impact
reset_pose()
pb["Hips"].location = Vector((0, 0.0, -0.35))
pb["Hips"].rotation_euler = Vector((math.radians(75), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(10), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-30), 0, 0))
insert_all_keys(0)

# Frame 5: MASSIVE BELLY-FLOP IMPACT! Face and belly planted flat on floor!
reset_pose()
pb["Hips"].location = Vector((0, 0.20, -0.68))
pb["Hips"].rotation_euler = Vector((math.radians(88), 0, 0))
pb["Hips"].scale = Vector((1.35, 1.35, 0.55))
pb["Spine"].rotation_euler = Vector((math.radians(0), 0, 0))
pb["Spine"].scale = Vector((1.30, 1.30, 0.58))
pb["Chest"].rotation_euler = Vector((math.radians(0), 0, 0))
pb["Head"].location = Vector((0, 0.08, -0.15))
pb["Head"].rotation_euler = Vector((math.radians(8), 0, 0))
pb["Head"].scale = Vector((1.25, 1.25, 0.60))
# Arms slammed flat against the floor spread out
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(10), 0, math.radians(85)))
pb["Arm_Lower.L"].rotation_euler = Vector((0, 0, math.radians(15)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(10), 0, math.radians(-85)))
pb["Arm_Lower.R"].rotation_euler = Vector((0, 0, math.radians(-15)))
# Legs splayed behind on floor
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(-10), 0, math.radians(-35)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(10), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(-10), 0, math.radians(35)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(10), 0, 0))
insert_all_keys(5)

# Frame 12: Slight rebound shudder
pb["Hips"].location = Vector((0, 0.18, -0.64))
pb["Hips"].scale = Vector((1.22, 1.22, 0.68))
insert_all_keys(12)

# Frame 25: Lying dazed flat on the belly
pb["Hips"].location = Vector((0, 0.19, -0.66))
pb["Hips"].scale = Vector((1.25, 1.25, 0.60))
insert_all_keys(25)
created_actions.append(act_flop)

# -----------------
# 7. Action: Get_Up (Levantando: empurra com as mãos, ajoelha e se ergue)
# -----------------
act_get_up = bpy.data.actions.new("Get_Up")
arm_obj.animation_data.action = act_get_up

# Frame 0: Starting flat on belly
reset_pose()
pb["Hips"].location = Vector((0, 0.19, -0.66))
pb["Hips"].rotation_euler = Vector((math.radians(88), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(10), 0, math.radians(85)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(10), 0, math.radians(-85)))
insert_all_keys(0)

# Frame 12: Hands push against floor, chest lifts up, head looking up groggily
reset_pose()
pb["Hips"].location = Vector((0, 0.10, -0.58))
pb["Hips"].rotation_euler = Vector((math.radians(50), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(-15), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(-20), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-15), 0, 0))
# Arms pushing down
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-35), 0, math.radians(45)))
pb["Arm_Lower.L"].rotation_euler = Vector((math.radians(20), 0, 0))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-35), 0, math.radians(-45)))
pb["Arm_Lower.R"].rotation_euler = Vector((math.radians(20), 0, 0))
insert_all_keys(12)

# Frame 24: Knees tuck underneath, pushing up into a crouch
reset_pose()
pb["Hips"].location = Vector((0, -0.05, -0.42))
pb["Hips"].rotation_euler = Vector((math.radians(25), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(10), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(5), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(5), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(80), 0, math.radians(-20)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-30), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(80), 0, math.radians(20)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-30), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-45), 0, math.radians(30)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-45), 0, math.radians(-30)))
insert_all_keys(24)

# Frame 34: Head shake to shake off daze
reset_pose()
apply_sit_pose(0.5)
pb["Head"].rotation_euler = Vector((0, 0, math.radians(18)))
insert_all_keys(34)

# Frame 40: Head shake other way
apply_sit_pose(0.3)
pb["Head"].rotation_euler = Vector((0, 0, math.radians(-18)))
insert_all_keys(40)

# Frame 48: Fully settled back into sit pose!
apply_sit_pose(0.0)
insert_all_keys(48)
created_actions.append(act_get_up)

# Also preserve Butt_Drop and Butt_Slam if needed
# Mark all actions as stashed in NLA tracks so glTF exporter saves them all
for act in created_actions:
    act.use_fake_user = True
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = act.name
    track.strips.new(act.name, 0, act)

bpy.ops.object.mode_set(mode="OBJECT")

export_path = "assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb"
bpy.ops.export_scene.gltf(
    filepath=export_path,
    export_format="GLB",
    use_selection=False,
    export_animations=True,
    export_nla_strips=True
)
print(f"Exported successfully to {export_path} with {len(created_actions)} actions!")
