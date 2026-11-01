# Cartoon world, believable weapons

The visual reference is How to Fish: playful three-dimensional characters and scenery, strong color blocks and exaggerated readable shapes. Zombies are goofy and grotesque. Detailed, mechanically recognizable guns provide the deliberate contrast.

## Shape and material rules

- Heads have a shaped jaw, cheeks and cranium; eyes, noses, ears and expressions carry the personality.
- Bodies use tapering clothing, curved limbs, oversized hands and boots. Accessories break the silhouette. Preserve the existing animation pivots.
- World props use simplified curves, uneven boards, striped fabric, warm painted surfaces and readable signage. Buildings can be rectangular; their details should feel designed rather than repeated placeholder boxes.
- Guns use convincing proportions, identifiable construction, restrained steel highlights and distinct wood/polymer furniture. Moving mechanisms remain separate rigs.
- Lighting is moody but readable: a low warm sun or cold moon, cooler ambient fill, layered fog and contact shadows. Characters keep their colour blocks; the world around them carries the dread.

## First implemented slice

- Gus: red cap and brim, shaped face, beard, jacket, pockets, zipper, backpack, patch, boots and knee repair.
- Common infected: mismatched protruding eyes, uneven jaw, crooked teeth, tongue, spiky hair and a torn shirt. Its hit capsule was raised to match the visible head; an input-fired headshot test covers this.
- M590: continuous walnut stock, narrow receiver, ejection port and bolt, parallel barrel and magazine tube, ribbed wooden pump, shell carrier and bead sight. It retains the existing stats and reload/pump animation interface.
- Bite Size Deli: reusable storefront kit, scalloped striped awning, boarded windows, chalkboard and potted tree. It appears on the first street of maps that contain a street. Parked cars now have curved silhouettes, and Main Street uses a brighter palette.

The shared character construction applies rounded forms to the other survivors and infected. This is the first art slice, not a claim that every gun, special infected and environment prop has received an individual final art pass.

## Atmosphere

`scripts/world/atmosphere.gd` owns each level's sky, light, weather and ambience. Every chapter names a mood in `DB.CHAPTERS`:

- **storm_dusk** (Main Street, the open world): burnt-orange horizon under a breaking storm, rain, lightning every 12–34 s.
- **dead_night** (The Warehouse): close, cold night, dust hanging in torch beams, distant heat lightning.
- **drowned_night** (The Docks): heavy rain and frequent lightning.

The sky is a shader with drifting fbm clouds that light up from the strike direction. Fog layers distance fog, ground mist and (Medium and High quality) volumetric fog, so torches, muzzle flashes and lightning throw beams. Glow makes lit windows and lamps bleed. About a third of linear-campaign street lamps flicker, chosen by position hash so map layout seeds are untouched. Sound adds looped wind, rain and a low drone (Music bus), thunder timed to each strike's distance, occasional distant groans, screams, creaks and sirens, and reverb on the Effects and Voice buses. All of it is cosmetic and local to each peer. The HUD adds film grain, vignette and edge fringing, scaled by the **Film grain and vignette** comfort slider.

## Surfaces

World geometry is textured from `assets/textures`, baked by `godot --headless --path . --script tools/bake_textures.gd`. Albedos are grey and multiply over the colour a surface already has, so colour blocking survives. Materials are triplanar and need no UVs. Set `Build.paint` around static scenery to choose a surface; it maps in world space, so never use it on anything that moves. Everything else gets the local `painted` fallback. The `.import` files beside the textures are committed because they turn on mipmaps and VRAM compression.

## Evidence and reproduction

```sh
tools/godot --fixed-fps 20 -- --solo --test=art_models
tools/godot --headless --fixed-fps 20 -- --solo --test=art_hitbox
screenshots/animations/.venv/bin/python tools/encode_animation_gifs.py --source screenshots/art-pass/after/frames --output screenshots/art-pass/turntables --width 600
```

The capture is muted. Inspection stages use the exact runtime model classes and export their real mesh/node/material geometry as GLB files into `screenshots/art-pass/after/`. Turntable frames and in-game screenshots come from Godot. The GLB geometry can be inspected in other 3D applications; runtime procedural animations and Label3D signage are not baked into those exports.
