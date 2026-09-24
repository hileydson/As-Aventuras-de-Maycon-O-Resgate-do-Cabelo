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

# Parent mesh to armature with automatic bone heat weights (smooth biharmonic diffusion, no jagged edges)
mesh_obj.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.parent_set(type="ARMATURE_AUTO")

# Ensure no vertices are left unweighted and normalize weights to max 4 influences
hips_vg = mesh_obj.vertex_groups.get("Hips")
for v in mesh_obj.data.vertices:
    if len(v.groups) == 0:
        if hips_vg:
            hips_vg.add([v.index], 1.0, "REPLACE")
    else:
        g_weights = [(g.group, g.weight) for g in v.groups]
        g_weights.sort(key=lambda item: item[1], reverse=True)
        top4 = g_weights[:4]
        total = sum(w for _, w in top4)
        if total > 0.0:
            for g in v.groups:
                mesh_obj.vertex_groups[g.group].remove([v.index])
            for grp_idx, w in top4:
                mesh_obj.vertex_groups[grp_idx].add([v.index], w / total, "REPLACE")

print("Smooth automatic skinning with normalized weights complete!")

# Setup keyframed actions
bpy.ops.object.mode_set(mode="POSE")
pb = arm_obj.pose.bones
for b in pb:
    b.rotation_mode = "XYZ"

def reset_pose():
    for b in pb:
        b.location = Vector((0, 0, 0))
        b.rotation_euler = Vector((0, 0, 0))
        # CRITICAL: Always keep scale 1.0 - NEVER flatten or squash bones!
        b.scale = Vector((1.0, 1.0, 1.0))

def insert_all_keys(frame):
    for b in pb:
        b.keyframe_insert(data_path="location", frame=frame)
        b.keyframe_insert(data_path="rotation_euler", frame=frame)
        b.keyframe_insert(data_path="scale", frame=frame)

arm_obj.animation_data_create()
created_actions = []

# Helper: Sit pose (Normal natural shape, no distortion)
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
# 2. Action: Turn (Girando o corpo e quadris para olhar a próxima plataforma)
# -----------------
act_turn = bpy.data.actions.new("Turn")
arm_obj.animation_data.action = act_turn

apply_sit_pose(0.0)
insert_all_keys(0)

# Frame 10: Lift one leg, swivel torso towards target
reset_pose()
pb["Hips"].location = Vector((0, -0.04, -0.44))
pb["Hips"].rotation_euler = Vector((math.radians(8), math.radians(-8), math.radians(16)))
pb["Spine"].rotation_euler = Vector((0, 0, math.radians(10)))
pb["Chest"].rotation_euler = Vector((0, 0, math.radians(12)))
pb["Head"].rotation_euler = Vector((math.radians(-4), math.radians(-8), math.radians(18)))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(80), 0, math.radians(-28)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-16), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(64), 0, math.radians(12)))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-38), 0, math.radians(30)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-58), 0, math.radians(-12)))
insert_all_keys(10)

# Frame 20: Swivel back slightly
reset_pose()
pb["Hips"].location = Vector((0, -0.05, -0.46))
pb["Hips"].rotation_euler = Vector((math.radians(10), math.radians(4), math.radians(-6)))
pb["Spine"].rotation_euler = Vector((0, 0, math.radians(-4)))
pb["Head"].rotation_euler = Vector((math.radians(4), 0, math.radians(8)))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(70), 0, math.radians(-18)))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(76), 0, math.radians(22)))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-50), 0, math.radians(16)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-48), 0, math.radians(-24)))
insert_all_keys(20)

apply_sit_pose(0.0)
insert_all_keys(30)
created_actions.append(act_turn)

# -----------------
# 3. Action: Jump_Prep (Agachando profundamente com as pernas comprimidas, SEM achatar a malha)
# -----------------
act_prep = bpy.data.actions.new("Jump_Prep")
arm_obj.animation_data.action = act_prep

apply_sit_pose(0.0)
insert_all_keys(0)

# Frame 12: Sinking down, spreading knees, hands bracing back (pure rotation & translation, scale = 1.0)
reset_pose()
pb["Hips"].location = Vector((0, -0.09, -0.52))
pb["Hips"].rotation_euler = Vector((math.radians(22), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(14), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(14), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-18), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(86), 0, math.radians(-18)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-48), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(86), 0, math.radians(18)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-48), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-42), 0, math.radians(-30)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-42), 0, math.radians(30)))
insert_all_keys(12)

# Frame 22: Deep crouch gather position
reset_pose()
pb["Hips"].location = Vector((0, -0.11, -0.55))
pb["Hips"].rotation_euler = Vector((math.radians(26), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(18), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(16), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-22), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(90), 0, math.radians(-22)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-54), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(90), 0, math.radians(22)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-54), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-46), 0, math.radians(-40)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-46), 0, math.radians(40)))
insert_all_keys(22)

insert_all_keys(30)
created_actions.append(act_prep)

# -----------------
# 4. Action: Jump_Ascent (Disparo para cima)
# -----------------
act_ascent = bpy.data.actions.new("Jump_Ascent")
arm_obj.animation_data.action = act_ascent

reset_pose()
pb["Hips"].location = Vector((0, 0.04, -0.10))
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

pb["Hips"].location = Vector((0, 0.06, -0.05))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(55), 0, math.radians(28)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(55), 0, math.radians(-28)))
insert_all_keys(15)
insert_all_keys(30)
created_actions.append(act_ascent)

# -----------------
# 5. Action: Belly_Dive (Mergulho no ar com a barriga e cara para baixo)
# -----------------
act_dive = bpy.data.actions.new("Belly_Dive")
arm_obj.animation_data.action = act_dive

reset_pose()
# Torso angled forward/down like a skydiver (belly leading down)
pb["Hips"].location = Vector((0, 0.0, -0.15))
pb["Hips"].rotation_euler = Vector((math.radians(65), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(10), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(10), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-30), 0, 0))
# Arms spread out wide
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(25), 0, math.radians(65)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(25), 0, math.radians(-65)))
# Legs trailing behind
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(-25), 0, math.radians(-18)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(30), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(-25), 0, math.radians(18)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(30), 0, 0))
insert_all_keys(0)

# Subtle flutter in wind
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(35), 0, math.radians(72)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(35), 0, math.radians(-72)))
pb["Head"].rotation_euler = Vector((math.radians(-25), 0, 0))
insert_all_keys(12)

pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(25), 0, math.radians(65)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(25), 0, math.radians(-65)))
pb["Head"].rotation_euler = Vector((math.radians(-30), 0, 0))
insert_all_keys(24)
created_actions.append(act_dive)

# -----------------
# 6. Action: Belly_Flop (Caindo de cara e barriga no chão - SEM ACHATAR A MALHA, TAMANHO 100% NORMAL!)
# -----------------
act_flop = bpy.data.actions.new("Belly_Flop")
arm_obj.animation_data.action = act_flop

# Frame 0: Transitioning into floor
reset_pose()
pb["Hips"].location = Vector((0, 0.06, -0.36))
pb["Hips"].rotation_euler = Vector((math.radians(72), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(8), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-20), 0, 0))
insert_all_keys(0)

# Frame 5: Landing flat on belly on the floor - 100% natural size (scale = (1,1,1))
reset_pose()
pb["Hips"].location = Vector((0, 0.10, -0.50))
pb["Hips"].rotation_euler = Vector((math.radians(82), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(0), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(0), 0, 0))
pb["Head"].location = Vector((0, 0.02, -0.04))
pb["Head"].rotation_euler = Vector((math.radians(4), 0, 0))
# Arms resting flat on the ground spread out
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(6), 0, math.radians(72)))
pb["Arm_Lower.L"].rotation_euler = Vector((0, 0, math.radians(10)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(6), 0, math.radians(-72)))
pb["Arm_Lower.R"].rotation_euler = Vector((0, 0, math.radians(-10)))
# Legs lying flat behind on floor
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(-10), 0, math.radians(-22)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(8), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(-10), 0, math.radians(22)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(8), 0, 0))
insert_all_keys(5)

# Frame 15: Still flat on belly
insert_all_keys(15)

# Frame 25: Flat on belly
insert_all_keys(25)
created_actions.append(act_flop)

# -----------------
# 7. Action: Get_Up (Levantando: empurra com as mãos, recolhe joelhos e senta - TAMANHO NORMAL)
# -----------------
act_get_up = bpy.data.actions.new("Get_Up")
arm_obj.animation_data.action = act_get_up

# Frame 0: Flat on belly
reset_pose()
pb["Hips"].location = Vector((0, 0.10, -0.50))
pb["Hips"].rotation_euler = Vector((math.radians(82), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(6), 0, math.radians(72)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(6), 0, math.radians(-72)))
insert_all_keys(0)

# Frame 12: Hands push against floor, chest lifts up, head looking up
reset_pose()
pb["Hips"].location = Vector((0, 0.04, -0.46))
pb["Hips"].rotation_euler = Vector((math.radians(42), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(-10), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(-14), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(-10), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-28), 0, math.radians(38)))
pb["Arm_Lower.L"].rotation_euler = Vector((math.radians(12), 0, 0))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-28), 0, math.radians(-38)))
pb["Arm_Lower.R"].rotation_euler = Vector((math.radians(12), 0, 0))
insert_all_keys(12)

# Frame 24: Knees tuck underneath, pushing up into a crouch
reset_pose()
pb["Hips"].location = Vector((0, -0.05, -0.42))
pb["Hips"].rotation_euler = Vector((math.radians(20), 0, 0))
pb["Spine"].rotation_euler = Vector((math.radians(6), 0, 0))
pb["Chest"].rotation_euler = Vector((math.radians(4), 0, 0))
pb["Head"].rotation_euler = Vector((math.radians(4), 0, 0))
pb["Leg_Upper.L"].rotation_euler = Vector((math.radians(72), 0, math.radians(-16)))
pb["Leg_Lower.L"].rotation_euler = Vector((math.radians(-22), 0, 0))
pb["Leg_Upper.R"].rotation_euler = Vector((math.radians(72), 0, math.radians(16)))
pb["Leg_Lower.R"].rotation_euler = Vector((math.radians(-22), 0, 0))
pb["Arm_Upper.L"].rotation_euler = Vector((math.radians(-38), 0, math.radians(22)))
pb["Arm_Upper.R"].rotation_euler = Vector((math.radians(-38), 0, math.radians(-22)))
insert_all_keys(24)

# Frame 34: Head shake
reset_pose()
apply_sit_pose(0.3)
pb["Head"].rotation_euler = Vector((0, 0, math.radians(14)))
insert_all_keys(34)

# Frame 40: Head shake other side
apply_sit_pose(0.2)
pb["Head"].rotation_euler = Vector((0, 0, math.radians(-14)))
insert_all_keys(40)

# Frame 48: Settled back into sit pose!
apply_sit_pose(0.0)
insert_all_keys(48)
created_actions.append(act_get_up)

# Stash all actions in NLA tracks
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
print(f"Exported clean rig to {export_path} with {len(created_actions)} actions!")
