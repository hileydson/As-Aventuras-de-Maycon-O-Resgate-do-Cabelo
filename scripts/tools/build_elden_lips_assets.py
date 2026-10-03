"""Run through Blender MCP. Keeps the original scene and character assets intact."""
from pathlib import Path
import math
import re
import bpy
from mathutils import Euler, Quaternion

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/modelo_3d/elden_lips'
scene = bpy.context.scene
scene.render.fps = 30


def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def export(objects, name, animations=False):
    select(objects)
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name + '.glb')),
        export_format='GLB', use_selection=True, export_animations=animations,
        export_animation_mode='NLA_TRACKS', export_force_sampling=True,
        export_frame_range=False, export_materials='EXPORT')


wood = bpy.data.materials.new('EldenLips_PolyHaven_Wood')
wood.use_nodes = True
nodes = wood.node_tree.nodes
bsdf = nodes.get('Principled BSDF')
bsdf.inputs['Roughness'].default_value = 0.86
tex = nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(str(ROOT / 'assets/polyhaven/elden_lips/wood_planks_diff_1k.jpg'))
wood.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
iron = bpy.data.materials.new('EldenLips_OldIron')
iron.diffuse_color = (0.08, 0.065, 0.045, 1)
iron.use_nodes = True
iron.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value = 0.75
iron.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.72


def plank(name, location, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    bevel = obj.modifiers.new('Worn edges', 'BEVEL')
    bevel.width = 0.015
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


# Blender +Z becomes Godot +Y. Both props originate at the grip.
blade = plank('SplinteredPlank', (0, 0, 0.64), (0.18, 0.12, 1.7), wood)
blade.rotation_euler.y = 0.035
binding = plank('ClothGrip', (0, 0, 0.02), (0.21, 0.14, 0.27), iron)
export([blade, binding], 'wood_blade')
pieces = []
for i in range(5):
    x = (i - 2) * 0.185
    height = 1.18 - abs(i - 2) * 0.10
    pieces.append(plank('ShieldBoard%d' % i, (x, 0, 0.13), (0.176, 0.11, height), wood))
for z in [-0.22, 0.43]:
    pieces.append(plank('ShieldBrace', (0, 0.065, z), (0.91, 0.055, 0.08), iron))
pieces.append(plank('ShieldHandle', (0, -0.12, 0), (0.12, 0.14, 0.24), iron))
export(pieces, 'wood_shield')


def amc(name):
    frames = []
    for line in (OUT / 'source' / name).read_text().splitlines():
        words = line.split()
        if not words or words[0].startswith(('#', ':')):
            continue
        if words[0].isdigit():
            frames.append({})
        elif frames:
            frames[-1][words[0]] = [math.radians(float(v)) for v in words[1:]]
    return frames


sources = {k: amc(v) for k, v in {'walk':'02_01.amc', 'pickup':'02_06.amc',
    'slash':'02_07.amc', 'dodge':'02_04.amc'}.items()}
# Source joint axes are honoured before applying restrained additive motion.
asf = (OUT / 'source/02.asf').read_text()
joint_info = {}
for block in re.findall(r'\bbegin\s+(.*?)\bend', asf, re.S):
    name = re.search(r'\bname\s+(\w+)', block)
    axis = re.search(r'\baxis\s+([\d.eE+ -]+)\s+XYZ', block)
    dof = re.search(r'\bdof\s+([^\n]+)', block)
    if name and axis and dof:
        joint_info[name[1]] = (Euler(tuple(math.radians(float(v)) for v in axis[1].split()), 'XYZ').to_quaternion(), dof[1].split())


def cmu_delta(frames, index, joint):
    if joint not in joint_info:
        return Quaternion()
    axis, dofs = joint_info[joint]
    values = frames[index].get(joint, [])
    first = frames[0].get(joint, [])
    angles = [0.0, 0.0, 0.0]
    for dof, value, base in zip(dofs, values, first):
        angles['xyz'.index(dof[1])] = max(-0.75, min(0.75, value - base)) * 0.30
    return axis @ Euler(angles, 'XYZ').to_quaternion() @ axis.inverted()


MAP = {'LeftUpLeg':'lfemur','RightUpLeg':'rfemur','LeftLeg':'ltibia','RightLeg':'rtibia',
    'LeftArm':'lhumerus','RightArm':'rhumerus','LeftForeArm':'lradius','RightForeArm':'rradius',
    'Spine':'lowerback','Spine01':'upperback','Spine02':'thorax','Head':'head'}


def build_character(path, prefix):
    before = set(scene.objects)
    old_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / path))
    imported = list(set(scene.objects) - before)
    arm = next(o for o in imported if o.type == 'ARMATURE')
    select([arm])
    # Use the established rig's neutral pose, preserving its bind orientation.
    idle = next((a for a in bpy.data.actions if a not in old_actions and a.name.startswith('Idle')), None)
    if idle:
        arm.animation_data_create()
        arm.animation_data.action = idle
        scene.frame_set(1)
    bpy.context.view_layer.update()
    neutral = {b.name:b.rotation_quaternion.copy() for b in arm.pose.bones}
    if arm.animation_data:
        arm.animation_data.action = None
        for track in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(track)
    mapping = MAP if prefix == 'maycon' else {'Leg_Upper.L':'lfemur','Leg_Upper.R':'rfemur',
        'Leg_Lower.L':'ltibia','Leg_Lower.R':'rtibia','Arm_Upper.L':'lhumerus',
        'Arm_Upper.R':'rhumerus','Arm_Lower.L':'lradius','Arm_Lower.R':'rradius',
        'Spine':'lowerback','Chest':'thorax','Head':'head'}
    specs = [('idle',2.0),('walk',1.0),('pickup',2.2),('slash',0.72),
        ('heavy',1.15),('guard',1.0),('dodge',0.62),('slam',1.8),('death',2.3)]
    baked = []
    for name, duration in specs:
        action = bpy.data.actions.new(prefix + '_' + name)
        arm.animation_data_create()
        arm.animation_data.action = action
        frame_count = round(duration * 30)
        clip = sources.get(name, sources['slash'] if name in ['heavy','slam'] else None)
        for f in range(frame_count + 1):
            t = f / frame_count
            wave = math.sin(t * math.pi)
            swing = math.sin(t * math.tau)
            for b in arm.pose.bones:
                b.rotation_mode = 'QUATERNION'
                b.rotation_quaternion = neutral[b.name]
                b.location = (0,0,0)
                if clip and b.name in mapping:
                    # In-place CMU movement, sampled at 120Hz then baked at 30Hz.
                    idx = min(len(clip)-1, round(t * min(len(clip)-1, 120*duration)))
                    b.rotation_quaternion = neutral[b.name] @ cmu_delta(clip,idx,mapping[b.name])
                offset = (0,0,0)
                if prefix == 'maycon':
                    if b.name == 'RightArm': offset = (-0.38,0.12,-0.46)
                    if b.name == 'RightForeArm': offset = (0.48,0,0)
                    if b.name == 'LeftArm': offset = (-0.36,0.1,0.55)
                    if b.name == 'LeftForeArm': offset = (0.85,0,-0.15)
                    if name in ['slash','heavy']:
                        if b.name == 'RightArm': offset = (-0.38-1.1*wave, -0.9*swing, -0.46+0.55*wave)
                        if b.name == 'Spine': offset = (0,-0.48*swing,0)
                        if b.name == 'RightForeArm': offset = (0.48-0.35*wave,0,0)
                    if name == 'guard':
                        if b.name == 'LeftArm': offset = (-1.0,0.15,0.4)
                        if b.name == 'LeftForeArm': offset = (1.1,0,-0.2)
                    if name == 'pickup' and b.name in ['Spine','Spine01']: offset = (0.5*wave,0,0)
                    if name == 'dodge' and b.name == 'Spine': offset = (0.4*wave,0,-0.2*wave)
                else:
                    if b.name == 'Arm_Upper.L': offset = (0,0,-0.9)
                    if b.name == 'Arm_Upper.R': offset = (0,0,0.9)
                    if b.name == 'Arm_Lower.L': offset = (0,0,1.2)
                    if b.name == 'Arm_Lower.R': offset = (0,0,-1.2)
                    if name in ['slam','heavy','slash']:
                        if b.name == 'Arm_Upper.R': offset = (-1.6*wave,0,0.4)
                        if b.name == 'Arm_Upper.L': offset = (-1.6*wave,0,-0.4)
                        if b.name == 'Chest': offset = (0.35*swing,0,0)
                    if name == 'walk' and b.name.startswith('Leg_Upper'): offset = (0.5*swing*(1 if b.name.endswith('L') else -1),0,0)
                if name == 'death' and b.name in ['Spine','Chest']: offset = (0.85*t,0,0.2*t)
                if name == 'idle' and b.name in ['Spine','Chest','Spine01']: offset = (0.018*swing,0,0)
                b.rotation_quaternion = b.rotation_quaternion @ Euler(offset,'XYZ').to_quaternion()
                b.keyframe_insert(data_path='rotation_quaternion',frame=f+1,group=b.name)
        track = arm.animation_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, 1, action)
        baked.append(action.name)
    arm.animation_data.action = None
    # Keep a skin so Godot imports actual Skeleton3D rotation tracks.
    export(imported, prefix + '_combat', True)
    return baked


maycon = build_character('assets/novas_imagens/3d_enemies/maycon_3d_model_ia_animations.glb','maycon')
lips = build_character('assets/modelo_3d/mario_3d_models/lips_3d_rigged.glb','lips')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'source/elden_lips_workshop.blend'))
result = {'props':['wood_blade.glb','wood_shield.glb'],'maycon':maycon,'lips':lips}
