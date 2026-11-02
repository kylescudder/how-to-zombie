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

Ground textures also carry wrapped, seeded detail stamps: curved grass blades, mineral chips and pebbles, and branching fissures in asphalt, paving and concrete. Their albedo and normal maps are baked together; the existing material colours, world-space mapping and collision geometry are preserved. Re-run the texture baker to reproduce them.

## Ground objects

`GroundDetail` supplies actual low-poly mesh grass clumps, faceted stones and broken paving lips with open jagged seams, loose chips and weeds. Grass blades have tapered, bent geometry and stones have volume. City curbs, outdoor campaign floors and the rural islands place these meshes deterministically with a separate random stream. City crossings, road centres, rural roads and campaign centre lanes stay clear. The small dressing has no collision.

Shared meshes are instanced in 64 m spatial batches, with an 85 m visibility limit. They supplement the ground materials. The pavement detail is raised fragments around a seam; it does not cut holes into the underlying collision floor.

```sh
tools/godot --headless --fixed-fps 60 -- --solo --test=world
tools/godot --fixed-fps 30 -- --solo --test=ground_capture
```

The capture saves real mesh inspection and generated-city images to `screenshots/ground-detail/3d/`.

## Vehicles

Vehicles are the other deliberate hard edge in the world. `VehicleKit` extrudes a side profile into flat-shaded `Forge` panels, cuts the wheel arches, then adds glass, trim and named fittings, baking each model into one shared mesh. `VehicleCatalog` holds twelve types of ten models; set `CAMP_MODELS`, `STREET_MODELS` or `POLICE_MODEL` to change what appears in the game. The nose is at -Z, the way `TeamVehicle` drives.

```sh
tools/godot --headless -- --solo --test=vehicles             # every model meshes and fits its role
tools/godot --fixed-fps 20 -- --solo --test=vehicle_lineup   # cards and sheets in screenshots/vehicles
```

## Infected

Infected share the vehicles' faceted look. `ZombieKit` lofts each body part from a few cross-sections and paints it face by face: clothing patterns, tears, blood and rot patches are coloured facets, while hats, hair and fittings are added as faceted solids. Each part is baked into one mesh that hangs on `CharacterModel`'s rig, so the gaits, death clips and hit capsule still apply, and an infected costs 13 mesh nodes instead of about 70. `ZombieCatalog` holds twelve types of ten models: six common groups (Townsfolk, Workers, Uniforms, Sporty, Old Timers, Outdoors) that spawn mixed together, plus ten looks each for the Boomer, Hunter, Smoker, Spitter, Tank and Witch. Specials keep their type's silhouette across all ten looks. The spawn seed picks a look, so every peer agrees without extra replication. Eyes stay separate so they can blink and close on death. Gloss for eyes, teeth, gore and hi-vis comes from Forge's wet layer, and the Spitter's acid uses its unlit glow layer.

```sh
tools/godot --headless -- --solo --test=zombies             # every look meshes, every kind has looks, heads fit the capsule
tools/godot --fixed-fps 20 -- --solo --test=zombie_lineup   # cards and sheets in screenshots/zombies
```

## Evidence and reproduction

```sh
tools/godot --fixed-fps 20 -- --solo --test=art_models
tools/godot --headless --fixed-fps 20 -- --solo --test=art_hitbox
screenshots/animations/.venv/bin/python tools/encode_animation_gifs.py --source screenshots/art-pass/after/frames --output screenshots/art-pass/turntables --width 600
```

The capture is muted. Inspection stages use the exact runtime model classes and export their real mesh/node/material geometry as GLB files into `screenshots/art-pass/after/`. Turntable frames and in-game screenshots come from Godot. The GLB geometry can be inspected in other 3D applications; runtime procedural animations and Label3D signage are not baked into those exports.
