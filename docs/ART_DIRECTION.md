# Cartoon world, believable weapons

The visual reference is How to Fish: playful three-dimensional characters and scenery, strong color blocks and exaggerated readable shapes. Zombies are goofy and grotesque. Detailed, mechanically recognizable guns provide the deliberate contrast.

## Shape and material rules

- Heads have a shaped jaw, cheeks and cranium; eyes, noses, ears and expressions carry the personality.
- Bodies use tapering clothing, curved limbs, oversized hands and boots. Accessories break the silhouette. Preserve the existing animation pivots.
- World props use simplified curves, uneven boards, striped fabric, warm painted surfaces and readable signage. Buildings can be rectangular; their details should feel designed rather than repeated placeholder boxes.
- Guns use convincing proportions, identifiable construction, restrained steel highlights and distinct wood/polymer furniture. Moving mechanisms remain separate rigs.
- Lighting preserves color and readability: warm directional light, cooler ambient fill, gentle atmospheric depth and contact shadows.

## First implemented slice

- Gus: red cap and brim, shaped face, beard, jacket, pockets, zipper, backpack, patch, boots and knee repair.
- Common infected: mismatched protruding eyes, uneven jaw, crooked teeth, tongue, spiky hair and a torn shirt. Its hit capsule was raised to match the visible head; an input-fired headshot test covers this.
- M590: continuous walnut stock, narrow receiver, ejection port and bolt, parallel barrel and magazine tube, ribbed wooden pump, shell carrier and bead sight. It retains the existing stats and reload/pump animation interface.
- Bite Size Deli: reusable storefront kit, scalloped striped awning, boarded windows, chalkboard and potted tree. It appears on the first street of maps that contain a street. Parked cars now have curved silhouettes, and Main Street uses a brighter palette.

The shared character construction applies rounded forms to the other survivors and infected. This is the first art slice, not a claim that every gun, special infected and environment prop has received an individual final art pass.

## Barea's city blocks

Ordinary blocks draw from a per-district mix (`BareaCity.MIXES`), built by `CityKits`. Neighbourhoods get terraced rows and detached houses with pitched roofs, doors and chimneys, courtyard flats, two- or three-building frontages with taller corners, parks and car parks. Downtown gets towers (some on podiums, topped with spires, helipads or masts) and multi-storey garages. The industrial estate gets warehouses with sawtooth or barrel roofs, loading bays and container yards. Flat roofs have a coloured membrane inside a parapet rim instead of a grey lid. Colour variants share one batch through per-instance tints (`BareaCity.TINTED`), so variety costs few draw calls. Solid volumes stay inside the 48 m lot; the street grid, roadblocks, landmarks and street pockets are unchanged. `--test=barea` checks the style mix, and `--test=barea_shots` writes one `17_style_*.png` per style.

## Coasts

`Coast` replaces the old uniform beach ring. Each island's shore is laid out in `Coast.LAYOUTS` as stretches of beach, port, cliff or sea wall, with angle 0 at the harbour. Neighbouring stretches blend over about 0.07 rad. Unlisted shore keeps the plain shelf, which is how harbours and Barea's ferry pier stay reachable by boat. Ground height is a per-kind profile across the shoreline, so the terrain mesh, its collision and `Coast.height_at` agree. The interior stays at y = 0. Raised ground is kept off the nav grid, and the cliffs' inland rock step is too steep to climb. Dressing goes through the shared `Batch`, except the ice cream vans and fuel tanks. Seagulls (`scripts/entities/seagull.gd`) are local-only scenery: they scatter from survivors and infected, circle, then land again, and they stop animating away from the camera. `--test=world` checks real collision heights for each kind; `--test=barea_shots` writes `18_coast_*.png`, `19_on_the_beach.png` and `20_island_*.png`.

## Surfaces

World geometry is textured from `assets/textures`, baked by `godot --headless --path . --script tools/bake_textures.gd`. Albedos are grey and multiply over the colour a surface already has, so colour blocking survives. Materials are triplanar and need no UVs. Set `Build.paint` around static scenery to choose a surface; it maps in world space, so never use it on anything that moves. Everything else gets the local `painted` fallback. The `.import` files beside the textures are committed because they turn on mipmaps and VRAM compression.

## Evidence and reproduction

```sh
tools/godot --fixed-fps 20 -- --solo --test=art_models
tools/godot --headless --fixed-fps 20 -- --solo --test=art_hitbox
screenshots/animations/.venv/bin/python tools/encode_animation_gifs.py --source screenshots/art-pass/after/frames --output screenshots/art-pass/turntables --width 600
```

The capture is muted. Inspection stages use the exact runtime model classes and export their real mesh/node/material geometry as GLB files into `screenshots/art-pass/after/`. Turntable frames and in-game screenshots come from Godot. The GLB geometry can be inspected in other 3D applications; runtime procedural animations and Label3D signage are not baked into those exports.
