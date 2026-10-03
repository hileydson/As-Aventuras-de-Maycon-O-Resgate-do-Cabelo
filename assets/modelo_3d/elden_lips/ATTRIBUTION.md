# Elden Lips — assets and animation sources

- Wooden plank and shield: created for this project through Blender MCP. The editable workshop is in `source/elden_lips_workshop.blend`.
- Wood surface: [Wood Planks, Poly Haven](https://polyhaven.com/a/wood_planks), downloaded from the official asset CDN, CC0. [License](https://polyhaven.com/license).
- Arena paving and column surfaces: existing Poly Haven textures in `assets/polyhaven/realtime_battle/`; see that folder's attribution.
- Food meshes: existing Kenney Food Kit, CC0; see `assets/kenney/food_kit/License.txt`.
- Character meshes: the project's existing Maycon and Lips models are preserved. Only the final arena adds new animation libraries.
- Movement data: [CMU Graphics Lab Motion Capture Database](http://mocap.cs.cmu.edu/search.php?subjectnumber=02), subject 02: 02_01 (walk), 02_04 (jump/balance), 02_06 (bend, scoop, rise), 02_07 (swordplay). The database states the dataset is free for all uses. Original ASF/AMC files are kept in `source/`. The clips use restrained additive joint motion with bespoke weapon, guard and boss poses; they are adaptations rather than exact full-body reproductions of CMU motion.

The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.

Blender exports are archived under `source/` with `.gdignore`. The game loads only the two compact `AnimationLibrary` resources, plus the equipment props. Original character GLBs and other battles are unchanged.

Rebuild: run `scripts/tools/build_elden_lips_assets.py` through Blender MCP in a separate asset-workshop scene, import its root-level GLBs in Godot, then run `scripts/tools/bake_elden_lips_animations.gd`. Archive the intermediate character GLBs and extracted images back into `source/` after baking. Do not erase the Godot cache.

Combat polish: `scripts/tools/polish_elden_lips_animations.gd` bakes the final pose libraries in Godot at 60 Hz, using the original rigs and actual joint positions for two-bone limb posing. This avoids relying on the oversized bone tails found in Maycon's Blender-imported rig. The initial CMU-based libraries are preserved as `source/maycon_cmu_base.res` and `source/lips_cmu_base.res`. The polished clips add a crouch and sequential equipment pickup, alternating cuts, an overhead heavy strike, dedicated hurt reactions, planted walking feet, and separate food windups/attacks. Runtime changes walking playback speed to match movement and keeps damage reactions from replacing an active boss telegraph.

To reproduce the polished libraries after the base assets exist: `Godot --headless --path . --script scripts/tools/polish_elden_lips_animations.gd`. No original character mesh is replaced.
