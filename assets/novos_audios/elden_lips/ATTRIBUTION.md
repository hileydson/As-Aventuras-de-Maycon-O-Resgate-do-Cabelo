# Elden Lips — audio

`ritual.ogg` and `frenzy.ogg` are original procedural compositions made for this game by `scripts/tools/score_elden_lips.py`. They are synchronised 80-second stems at 96 BPM. The first uses low choir/organ, strings, bells and percussion; the second adds string ostinatos, percussion and upper choir for the second phase. WAV masters are kept under ignored `source/`.

The following existing licensed assets are reused, without copying or modifying their source files:

- [A_Dungeon_Ambience_Loop](https://pixabay.com/sound-effects/film-special-effects-a-dungeon-ambience-loop-79423/), Grubzyy / freesound_community: ritual ambience.
- [zombie growl](https://pixabay.com/sound-effects/horror-zombie-growl-83568/), adharca / freesound_community: food-attack warning and phase-change roar.
- [Gate opening](https://pixabay.com/sound-effects/filme-e-efeitos-especiais-gate-opening-102093/), freesound_community: closing the arena.
- [BOOM](https://pixabay.com/sound-effects/film-special-effects-boom-356126/), DRAGON-STUDIO: low-frequency slam and victory accents.
- [Dark Matter Space Whoosh](https://pixabay.com/sound-effects/film-special-effects-dark-matter-space-whoosh-543214/): weapon swings and dodges.

These use the [Pixabay Content License](https://pixabay.com/service/license-summary/). The project's prior source records are in `assets/novos_audios/calabouco_terror/ATTRIBUTION.md` and the two `seco_*_pixabay.source.txt` files. New Pixabay downloads returned HTTP 403, so the battle uses these already available assets.

- `giant_head_slam.ogg`: rubberduck, [75 CC0 breaking / falling / hit SFX](https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx), CC0; reused for food impacts.
- Wood handling and shield blocks use the existing `wood_barrier_break.mp3`, with per-event pitch and volume.

No audio was copied from Elden Ring or the YouTube reference. To rebuild the score, run the Python script and encode the two WAVs in `source/` with FFmpeg Vorbis quality 5. Runtime enables looping on private stream copies.
