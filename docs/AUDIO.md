# Audio

Most sounds are real recordings: CC0 (public domain) packs from OpenGameArt, cut into game-ready takes in `assets/audio/`. That covers every gun, reload, melee hit, infected voice, explosion, door, siren and music stinger. [SOURCES.md](../assets/audio/SOURCES.md) credits each pack. Credit isn't required for CC0, but the packs are credited anyway.

A few sounds are still synthesised in `scripts/autoload/sfx.gd`, where synthesis works well: rain, wind, the drone, thunder, footsteps, vehicle skids and crashes, the engines (`engine_voice.gd`), the pipe bomb's beep and the Spitter's acid sizzle.

## Changing a sound

`tools/build_audio.py` holds the whole list. Each sound is a set of takes, and each take is a source recording, a start time, a length and a target peak level. Run the script to download any missing packs into `.tools/audio-src/` and rebuild every `<sound>_<n>.wav`. To use a different recording, change its entry and rerun the script. To add a variation, add a take. Sfx loads everything in `assets/audio/` at startup and picks a random take each time. A recorded sound replaces a synthesised one with the same name. The script needs `ffmpeg` and `bsdtar` (macOS `tar`).

Gunshots come from a library of real firearm recordings, each cut to one shot and its tail:

- **Pistol:** Walther PPQ, 1911 and Bersa.
- **SMG:** Carl Gustav M45 and PPSh.
- **Rifle:** AR-15, AK-47 and SKS.
- **Shotgun:** Benelli Nova, Winchester Model 12 and Charles Daly.
- **Hunting rifle:** Tikka T3, Springfield 1917 and Savage 10.

Reloads are separate cues placed across the reload time: magazine out, magazine in, then the action racked. Shotguns load shell by shell and finish with a pump. A cancelled or restarted reload drops its remaining cues. Molotov fires carry a looping fire, and Spitter acid carries a looping sizzle, for as long as they last.

## Playback

`Sfx.play()` reuses pooled players. Each kind of sound (guns, blasts, far-carrying sirens and horns, bosses, specials, commons, close foley, interface) sets how far it carries, how much its pitch varies and how many copies may play at once. When a sound hits its cap, the oldest copy is cut, so a horde of 30 groans is six voices. Repeats never pick the same take twice in a row. A 3D sound beyond its earshot is skipped, and two identical starts from the same spot within 25 ms play once. Distance takes the top end off 3D sounds. A hard limiter on Master stops a Tank fight inside a horde from clipping.

Recordings load and the synthesised sounds render on a worker thread at startup, in about a third of a second.

Bus routing is in [SETTINGS.md](SETTINGS.md).

`--test=sfx` loads the whole library headless and checks that every sound the scripts request exists, that synthesised takes are audible and unclipped, that takes differ, and that the voice cap, merging and earshot cut all work.
