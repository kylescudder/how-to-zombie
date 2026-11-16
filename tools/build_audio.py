#!/usr/bin/env python3
"""Rebuilds assets/audio/ from CC0 recordings on OpenGameArt.

Each entry below cuts one take out of a source recording: where it starts, how long it runs and
how loud its peak should be. Takes are named <sound>_<n>.wav (16-bit mono), which is how Sfx finds them.
Sources are downloaded once into .tools/audio-src/. Needs ffmpeg, and bsdtar (macOS tar) for
the .zip and .7z packs. Every source is CC0; assets/audio/SOURCES.md credits them anyway.

    tools/build_audio.py            # download what's missing, rebuild every take
"""
import array, os, shutil, subprocess, sys, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, ".tools", "audio-src")
OUT = os.path.join(ROOT, "assets", "audio")
FILES = "https://opengameart.org/sites/default/files/"

# slug: (author, download file, archive member root or "")
PACKS = {
    "the-free-firearm-sound-library": ("bart", "Prepared%20SFX%20Library.7z", "Prepared SFX Library/"),
    "gun-reload-sounds": ("SpringySpringo", ["assaultriflereload1_0.wav", "gunreload1.wav", "shotguncock_0.wav"], ""),
    "handgun-reload-sound-effect": ("zer0_sol", ["reload.wav"], ""),
    "gun-reload-sound-effects": ("BMacZero", ["clipload1.wav", "clipload2.wav", "singlebullet1.wav"], ""),
    "zombies-sound-pack": ("artisticdude", "zombies.zip", "zombies/"),
    "undead-moans": ("AntumDeluge", "undead-moans.zip", ""),
    "zomby-sfx-pack": ("saturn91", ["01_zombey.mp3", "02_zombey.mp3", "03_zombey.mp3", "07_zombey.mp3"], ""),
    "zombie-noises-and-moans": ("ianzazz", "zombienoises.zip", ""),
    "80-cc0-creature-sfx": ("rubberduck", "80-CC0-creature-SFX_0.zip", ""),
    "80-cc0-creture-sfx-2": ("rubberduck", "80-CC0-creature-sfx-2.zip", ""),
    "75-cc0-breaking-falling-hit-sfx": ("rubberduck", "sfx_breaking_and_falling.zip", ""),
    "100-cc0-sfx": ("rubberduck", "100-CC0-SFX_0.zip", ""),
    "100-cc0-metal-and-wood-sfx": ("rubberduck", "100-CC0-wood-metal-SFX.zip", ""),
    "glass-break": ("TinyWorlds", ["glass_breaking.wav"], ""),
    "punch": ("qubodup", "qubodupPunch.7z", "qubodupPunch/"),
    "thwack-sounds": ("AntumDeluge", "thwack-1.0.zip", "PCM/"),
    "swishes-sound-pack": ("artisticdude", "swishes.zip", "swishes/"),
    "8-wet-squish-slurp-impacts": ("qubodup", "independent_nu_ljudbank-wet_squish_slurp_impacts.7z", "impsplat/"),
    "explosions-4": ("EZduzziteh", ["explosion1_0.ogg"], ""),
    "chunky-explosion": ("Joth", ["Chunky%20Explosion.mp3"], ""),
    "catching-fire": ("themightyglider", ["flame_0.ogg"], ""),
    "fireplace-sound-loop": ("PagDev", ["fire.wav"], ""),
    "alarm-2": ("Frenchyboy", ["alarm_0.wav"], ""),
    "door-open-door-close-set": ("qubodup", "qubodup-DoorSet.7z", "qubodup-DoorSet/flac/"),
    "7-mechanical-clicks-and-buzzes": ("qubodup", "mechanical.7z", "mechanical/"),
    "storm-siren": ("TinyWorlds", ["storm_3_siren.ogg"], ""),
    "radio-noise-1": ("Kresiek The Furry", ["radio_noise_loop.wav"], ""),
    "their-coming-generic-horn-sound": ("StumpyStrust", ["theircoming3_0.ogg"], ""),
    "heartbeat-sounds": ("bart", ["heartbeat_slow_0.wav"], ""),
    "hurt-sound-effects": ("EZduzziteh", ["hurt_01_0.mp3", "hurt_02.mp3", "hurt_03.mp3", "hurt_04.mp3", "hurt_05.mp3", "hurt_06.mp3"], ""),
    "rpg-sound-pack": ("artisticdude", "rpg_sound_pack.zip", "RPG Sound Pack/"),
    "interface-sounds": ("Kenney", "kenney_interfaceSounds.zip", "Audio/"),
    "51-ui-sound-effects-buttons-switches-and-clicks": ("Kenney", "UI_SFX_Set.zip", ""),
    "sick-noises": ("frosty ham", ["sickness.wav"], ""),
    "old-man-cough": ("AntumDeluge", ["old-man-cough.flac"], ""),
    "evil-screech-1": ("Nocturnal_Vanguard", ["evil_screech_1.ogg"], ""),
    "evil-cackle-laugh-1": ("Nocturnal_Vanguard", ["evil_cackle_laugh_1.ogg"], ""),
    "female-hurt-grunts-groans": ("Nocturnal_Vanguard", ["female_hurt_grunts_groans_1.ogg"], ""),
    "female-scream-1": ("Nocturnal_Vanguard", ["female_scream_1.ogg"], ""),
    "high-pitch-scream-sounds2": ("pauliuw", ["high_pitch_scream.mp3"], ""),
    "dark-stinger-1": ("Kresiek The Furry", ["dark_stinger_0.wav"], ""),
    "string-and-piano-horror-stings": ("congusbongus", ["abyss_0.ogg", "piano_sting.mp3"], ""),
}

GUNS = "the-free-firearm-sound-library"
CREATURE, CREATURE2 = "80-cc0-creature-sfx", "80-cc0-creture-sfx-2"
# sound: [(pack, file in pack, start s, length s or None for the rest), ...], peak dBFS
TAKES = {
    "pistol": ([(GUNS, "Walther PPQ/X_39P.wav", 1.38, 1.0), (GUNS, "Walther PPQ/X_39P.wav", 6.42, 1.0), (GUNS, "1911/A_42P.wav", 0.91, 1.0), (GUNS, "Bersa/F_47P.wav", 0.30, 1.0)], -1),
    "smg": ([(GUNS, "Carl Gustav M45/G_31P.wav", 0.28, 0.6), (GUNS, "Carl Gustav M45/G_31P.wav", 3.47, 0.6), (GUNS, "PPSh/P_30P.wav", 0.94, 0.6), (GUNS, "PPSh/P_30P.wav", 4.36, 0.6)], -1),
    "rifle": ([(GUNS, "AR-15/D_32P.wav", 0.67, 0.9), (GUNS, "AK-47/C_28P.wav", 0.58, 0.9), (GUNS, "AK-47/C_28P.wav", 3.23, 0.9), (GUNS, "SKS/U_14P.wav", 3.55, 0.9)], -1),
    "shotgun": ([(GUNS, "Nova/O_21P.wav", 0.40, 1.4), (GUNS, "Model 12/K_22P.wav", 0.81, 1.4), (GUNS, "CD/H_21P.wav", 0.43, 1.4), (GUNS, "Nova/O_21P.wav", 3.44, 1.4)], -1),
    "sniper": ([(GUNS, "Tikka/W_29P.wav", 0.54, 1.8), (GUNS, "1917/B_24P.wav", 1.28, 1.8), (GUNS, "Savage 10 .300 Blackout/T_27P.wav", 0.92, 1.8)], -1),
    "mag_out": ([("gun-reload-sounds", "assaultriflereload1_0.wav", 0.20, 0.55), ("gun-reload-sounds", "gunreload1.wav", 0.10, 0.5), ("handgun-reload-sound-effect", "reload.wav", 0.05, 0.4)], -3),
    "mag_in": ([("gun-reload-sound-effects", "clipload1.wav", 0.0, None), ("gun-reload-sound-effects", "clipload2.wav", 0.0, None), ("handgun-reload-sound-effect", "reload.wav", 0.55, 0.4)], -3),
    "rack": ([("gun-reload-sounds", "assaultriflereload1_0.wav", 1.00, 0.6), ("gun-reload-sounds", "gunreload1.wav", 1.24, None), ("handgun-reload-sound-effect", "reload.wav", 1.00, 0.6)], -2),
    "shell": ([("gun-reload-sound-effects", "singlebullet1.wav", 0.0, None), ("rpg-sound-pack", "inventory/metal-small3.wav", 0.0, None)], -4),
    "pump": ([("gun-reload-sounds", "shotguncock_0.wav", 0.0, None)], -2),
    "empty": ([("rpg-sound-pack", "inventory/metal-small1.wav", 0.0, 0.2), ("rpg-sound-pack", "inventory/metal-small2.wav", 0.0, 0.2)], -6),
    "swing": ([("swishes-sound-pack", "swish-%d.wav" % n, 0.0, None) for n in (4, 6, 7, 8, 9)], -4),
    "shove": ([("punch", "qubodupPunch01.flac", 0.0, None), ("punch", "qubodupPunch02.flac", 0.0, None)], -3),
    "hit": ([("8-wet-squish-slurp-impacts", "impactsplat%02d.mp3.flac" % n, 0.0, 0.6) for n in (1, 3, 4, 7, 8)], -2),
    "headshot": ([("8-wet-squish-slurp-impacts", "impactsplat02.mp3.flac", 0.0, 0.7), ("8-wet-squish-slurp-impacts", "impactsplat06.mp3.flac", 0.0, 0.7)], -2),
    "hitmarker": ([("51-ui-sound-effects-buttons-switches-and-clicks", "click4.wav", 0.0, None)], -10),
    "click": ([("interface-sounds", "click_002.ogg", 0.0, None)], -8),
    "button": ([("7-mechanical-clicks-and-buzzes", "mechanical_button-01.flac", 0.0, None)], -4),
    "explosion": ([("explosions-4", "explosion1_0.ogg", 0.0, None), ("chunky-explosion", "Chunky Explosion.mp3", 0.0, 4.5)], -0.5),
    "glass": ([("75-cc0-breaking-falling-hit-sfx", "bfh1_glass_breaking_%02d.ogg" % n, 0.0, None) for n in (1, 2, 3, 4)] + [("glass-break", "glass_breaking.wav", 0.0, None)], -3),
    "fire": ([("catching-fire", "flame_0.ogg", 0.0, None)], -3),
    "acid": ([("8-wet-squish-slurp-impacts", "impactsplat05.mp3.flac", 0.0, None)], -4),
    "fire_loop": ([("fireplace-sound-loop", "fire.wav", 2.0, 10.5)], -6),
    "alarm": ([("alarm-2", "alarm_0.wav", 0.0, 1.0)], -8),
    "door": ([("door-open-door-close-set", "qubodup-Door%s0%d.flac" % (kind, n), 0.0, None) for kind in ("Open", "Close") for n in (1, 3, 5)], -4),
    "gate": ([("100-cc0-metal-and-wood-sfx", "metal_open_01.ogg", 0.0, None)], -3),
    "siren": ([("storm-siren", "storm_3_siren.ogg", 2.0, 8.0)], -8),
    "radio": ([("radio-noise-1", "radio_noise_loop.wav", 5.0, 1.8)], -8),
    "rescue_horn": ([("their-coming-generic-horn-sound", "theircoming3_0.ogg", 0.0, None)], -5),
    "heartbeat": ([("heartbeat-sounds", "heartbeat_slow_0.wav", 0.0, 0.85)], -2),
    "hurt": ([("hurt-sound-effects", f, 0.0, None) for f in ("hurt_01_0.mp3", "hurt_02.mp3", "hurt_03.mp3", "hurt_04.mp3", "hurt_05.mp3", "hurt_06.mp3")], -4),
    "incap": ([(CREATURE2, "human_0%d.ogg" % n, 0.0, None) for n in (2, 6, 7)], -4),
    "heal": ([("100-cc0-sfx", "paper_0%d.ogg" % n, 0.0, None) for n in (1, 2, 3, 4)], -6),
    "pills": ([("rpg-sound-pack", "inventory/beads.wav", 0.0, None), ("rpg-sound-pack", "inventory/bottle.wav", 0.0, None)], -6),
    "pickup": ([("rpg-sound-pack", "inventory/cloth.wav", 0.0, None), ("rpg-sound-pack", "inventory/cloth-heavy.wav", 0.0, None), ("rpg-sound-pack", "inventory/metal-small3.wav", 0.0, None)], -6),
    # Infected
    "groan": ([("zombies-sound-pack", "zombie-%d.wav" % n, 0.0, None) for n in (16, 17, 18, 21)] + [("zomby-sfx-pack", f, 0.0, None) for f in ("02_zombey.mp3", "03_zombey.mp3", "07_zombey.mp3")] + [("undead-moans", "undead-2.ogg", 0.0, None)], -8),
    "scream": ([("zombie-noises-and-moans", "zombienoise3.ogg", 0.0, None)] + [("zombies-sound-pack", "zombie-%d.wav" % n, 0.0, None) for n in (9, 11, 12, 19)] + [("zomby-sfx-pack", "01_zombey.mp3", 0.0, None)], -6),
    "die": ([("zombies-sound-pack", "zombie-%d.wav" % n, 0.0, None) for n in (3, 5, 6, 7)], -7),
    "zombie_hit": ([("thwack-sounds", "thwack-%02d.wav" % n, 0.0, None) for n in (1, 2, 3, 4)], -3),
    "boomer": ([(CREATURE, "burble_01.ogg", 0.0, None), (CREATURE, "burble_02.ogg", 0.0, None), (CREATURE, "burp_02.ogg", 0.0, None)], -5),
    "vomit": ([("sick-noises", "sickness.wav", 0.0, 3.7)], -4),
    "hunter": ([("evil-screech-1", "evil_screech_1.ogg", 0.40, 0.85), ("evil-screech-1", "evil_screech_1.ogg", 1.92, 1.05), (CREATURE, "scream_01.ogg", 0.0, None)], -5),
    "pounce": ([(CREATURE2, "attack_02.ogg", 0.0, None), (CREATURE2, "attack_04.ogg", 0.0, None)], -2),
    "smoker": ([("old-man-cough", "old-man-cough.flac", 0.0, 2.35), (CREATURE, "cough_01.ogg", 0.0, None), (CREATURE, "cough_03.ogg", 0.0, None)], -5),
    "tongue": ([(CREATURE2, "slime_05.ogg", 0.0, None), (CREATURE2, "slime_06.ogg", 0.0, None)], -5),
    "spitter": ([("evil-cackle-laugh-1", "evil_cackle_laugh_1.ogg", 0.20, 3.6)], -7),
    "spit": ([(CREATURE, "spit_0%d.ogg" % n, 0.0, None) for n in (1, 2, 3)], -4),
    "tank": ([(CREATURE, "roar_02.ogg", 0.0, None), (CREATURE2, "roar_04.ogg", 0.0, None), (CREATURE2, "roar_05.ogg", 0.0, None), (CREATURE2, "roar_06.ogg", 0.0, None), (CREATURE, "monster_07.ogg", 0.0, None)], -1),
    "punch": ([("punch", "qubodupPunch0%d.flac" % n, 0.0, None) for n in (3, 4, 5)], -1),
    "rock": ([("75-cc0-breaking-falling-hit-sfx", "bfh1_rock_breaking_0%d.ogg" % n, 0.0, None) for n in (1, 2, 3)], -2),
    "witch_cry": ([("female-hurt-grunts-groans", "female_hurt_grunts_groans_1.ogg", s, d) for s, d in ((0.48, 0.75), (2.08, 0.72), (4.96, 1.2), (9.40, 0.98))], -12),
    "witch_scream": ([("female-scream-1", "female_scream_1.ogg", 0.6, 0.85), ("high-pitch-scream-sounds2", "high_pitch_scream.mp3", 0.0, None)], -1),
    # Music stingers
    "horde_music": ([("dark-stinger-1", "dark_stinger_0.wav", 0.0, 6.0)], -6),
    "tank_music": ([("string-and-piano-horror-stings", "abyss_0.ogg", 0.0, None)], -6),
    "saferoom_music": ([("string-and-piano-horror-stings", "piano_sting.mp3", 0.0, 8.0)], -8),
}
LOOP_FADE = 0.5  # Seconds of a loop's tail crossfaded into its head.


def fetch(slug):
    author, files, _root = PACKS[slug]
    folder = os.path.join(CACHE, slug)
    if os.path.isdir(folder) and os.listdir(folder):
        return folder
    os.makedirs(folder, exist_ok=True)
    for name in files if isinstance(files, list) else [files]:
        target = os.path.join(folder, urllib.parse.unquote(name))
        print("  fetching", slug, name)
        request = urllib.request.Request(FILES + name, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request) as response, open(target, "wb") as out:
            shutil.copyfileobj(response, out)
        if target.endswith((".zip", ".7z")):
            subprocess.run(["tar", "-xf", target, "-C", folder], check=True)
    return folder


def source(slug, name):
    folder = fetch(slug)
    path = os.path.join(folder, PACKS[slug][2], name)
    if not os.path.exists(path):
        sys.exit("missing %s in %s" % (name, slug))
    return path


def peak_db(args, chain=""):
    # One -af only: FFmpeg keeps just the last, so the chain and the meter must share it. The
    # meter runs on floats, so a chain that overshoots full scale reads above 0 dB, not at it.
    meter = "aformat=sample_fmts=flt,astats=measure_perchannel=none:measure_overall=Peak_level"
    probe = subprocess.run(["ffmpeg", "-hide_banner"] + args + ["-af", (chain + "," if chain else "") + meter, "-f", "null", "-"], capture_output=True, text=True).stderr
    return float(probe.split("Peak level dB:")[1].split()[0])


def cut(src, start, length, peak, target, loop):
    span = ["-ss", str(start)] + (["-t", str(length + (LOOP_FADE if loop else 0.0))] if length else []) + ["-i", src]
    shape = "aformat=channel_layouts=mono:sample_fmts=flt,aresample=44100,highpass=f=30"  # Float throughout: nothing clips before the gain.
    gain = peak - peak_db(span, shape)
    if loop:
        raw = subprocess.run(["ffmpeg", "-v", "error"] + span + ["-af", shape + ",volume=%.2fdB" % gain, "-f", "s16le", "-"], capture_output=True, check=True).stdout
        pcm = array.array("h", raw)
        n, fade = len(pcm) - int(LOOP_FADE * 44100), int(LOOP_FADE * 44100)
        for i in range(fade):
            k = i / fade
            pcm[i] = int(pcm[i] * k + pcm[n + i] * (1.0 - k))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", "44100", "-ac", "1", "-i", "-", "-c:a", "pcm_s16le", target], input=pcm[:n].tobytes(), check=True)
        return
    duration = length or float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src], capture_output=True, text=True).stdout) - start
    out = min(0.08, duration * 0.2)
    chain = shape + ",volume=%.2fdB,afade=t=in:d=0.003,afade=t=out:st=%.3f:d=%.3f" % (gain, max(duration - out, 0.0), out)
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + span + ["-af", chain, "-c:a", "pcm_s16le", target], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith(".wav"):
            os.remove(os.path.join(OUT, old))
    for sound, (takes, peak) in TAKES.items():
        print(sound)
        for n, (slug, name, start, length) in enumerate(takes, 1):
            target = os.path.join(OUT, "%s_%d.wav" % (sound, n))
            cut(source(slug, name), start, length, peak, target, sound.endswith("_loop"))
            if peak_db(["-i", target]) > min(peak + 0.5, -0.1):
                sys.exit("%s came out hotter than %s dB" % (target, peak))
    used = sorted({slug for takes, _peak in TAKES.values() for slug, *_rest in takes})
    with open(os.path.join(OUT, "SOURCES.md"), "w") as notes:
        notes.write("# Sound sources\n\nEvery recording here is CC0 (public domain) from OpenGameArt. Credit isn't required, but here it is. `tools/build_audio.py` cuts each take from these packs.\n\n")
        for slug in used:
            notes.write("- [%s](https://opengameart.org/content/%s) by %s\n" % (slug.replace("-", " "), slug, PACKS[slug][0]))


if __name__ == "__main__":
    main()
