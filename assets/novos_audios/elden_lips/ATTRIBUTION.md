# Elden Lips — audio

`ritual.ogg` and `frenzy.ogg` are original procedural compositions made for this game by `scripts/tools/score_elden_lips.py`. They are synchronised 80-second stems at 96 BPM. The first uses low choir/organ, strings, bells and percussion; the second adds string ostinatos, percussion and upper choir for the second phase. WAV masters are kept under ignored `source/`.

The following existing licensed assets are reused, without copying or modifying their source files:

- [A_Dungeon_Ambience_Loop](https://pixabay.com/sound-effects/film-special-effects-a-dungeon-ambience-loop-79423/), Grubzyy / freesound_community: ritual ambience.
- [zombie growl](https://pixabay.com/sound-effects/horror-zombie-growl-83568/), adharca / freesound_community: food-attack warning and phase-change roar.
- [Gate opening](https://pixabay.com/sound-effects/filme-e-efeitos-especiais-gate-opening-102093/), freesound_community: closing the arena.
- [BOOM](https://pixabay.com/sound-effects/film-special-effects-boom-356126/), DRAGON-STUDIO: low-frequency slam and victory accents.

These use the [Pixabay Content License](https://pixabay.com/service/license-summary/). The project's prior source records are in `assets/novos_audios/calabouco_terror/ATTRIBUTION.md` and `seco_invader_boom_pixabay.source.txt`. New Pixabay downloads returned HTTP 403, so the battle uses these already available assets.

No audio was copied from Elden Ring or the YouTube reference. To rebuild the score, run the Python script and encode the two WAVs in `source/` with FFmpeg Vorbis quality 5. Runtime enables looping on private stream copies.

## Combat sound polish

The `sfx/` assets are produced by `scripts/tools/design_elden_lips_sfx.py` (NumPy + FFmpeg, 44.1 kHz). Wooden body contact and shield contact have separate short variants; the body contact combines a muted thud, a dry transient and damped wood resonances. Heavy contact, blade swish, food charge/sweep/launch/slam, tomato splatter, equipment handling, boss footfalls, world transformation, thunder and seamless storm wind are original procedural Foley. No sfxr gameplay sound is used.

`lips_pain_1.ogg`, `lips_pain_2.ogg`, `lips_pain_3.ogg` and `maycon_hurt.ogg` are shortened, enveloped and resampled adaptations of the project's `calabouco_terror/zombie_pain_1.wav`: Ogrebane, [Monster Sound Pack, Volume 1](https://opengameart.org/content/monster-sound-pack-volume-1), CC0. Pain, weather/ritual and impacts have separate runtime voice slots, so rapid contact sounds do not occupy all pain channels.

The prior long wood-breaking and dimensional-whoosh clips are no longer used for weapon contact, guards or ordinary swings in this battle. Impact triggers match the animation contact frame; boss preparation, projectile release and landing use distinct cues. The original score and the licensed Pixabay ambience, arena gate and phase roar remain in use.
