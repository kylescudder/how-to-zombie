# Street variety and encounter pacing

The city keeps its 559-block footprint and five-act route. 126 former filler masses become playable lots: neighbourhood markets, community gardens, evacuation aid stations and service yards. Industrial districts favour yards and aid stations. Landmark blocks are excluded. Canopies, planters, trees, shelter, signage and service buildings provide recognisable silhouettes and combat cover. A deterministic coordinate rule makes the same lots on every peer. About a third of lots contain one consumable supply pickup; none are designated safe rooms.

Solid props update the existing navigation grid. Pocket geometry stays inside its lot, leaving roadblock gaps and street corridors intact. Repeated small geometry uses the city's existing batching system. These are reusable scene kits, not 126 individually authored stories or complete building interiors.

## Host-owned encounter clock

`EncounterPacing` decides when to request a wave; `Director` supplies real squad pressure and owns spawning. Normal encounters build for 40 seconds initially (25 after a recovery), surge for up to 32, then recover for at least 32. Escape uses 25-second surges, 18-second recovery and 12-second build-up after recovery. These are targets, not guaranteed spawn times: valid hidden positions and pressure limits still apply.

A downed or pinned survivor, average living team health below 38%, recent damage over 22% of a full squad's health, a death, or a living Tank triggers recovery. Hurt recovery lasts 40 seconds normally or 22 during escape. Recovery cannot end while those conditions remain or at least five alerted enemies remain nearby. Existing enemies are not removed. Boss kills and completed hold-outs grant recovery. Ambient wanderer replenishment pauses during recovery, scripted hold-outs and escape.

Only one of scripted crescendo, finale, escape or normal travel scheduling runs per frame. Repeated wave requests reserve queue capacity against the 36-common cap. Ambient replenishment also accounts for queued enemies. Specials retain difficulty-specific caps. During scripted hold-outs, struggling teams receive four-common reinforcements only when fewer than six commons remain; their objective timers continue. Player-triggered alarms remain dangerous and use the same queue cap.

## Verification and limits

Run `godot --headless --path . --fixed-fps 60 -- --solo --test=city_pacing` for navigation, real player entry in all four lot types, a 2700-second deterministic encounter-model simulation, real queue reservations, injury relief and adaptive hold-out checks. Run without `--headless --fixed-fps 60` for native captures. `barea` tests the five-act route, alarms, roadblock gaps, idol drops and actual ferry escape; `world_horde` tests live spawning across islands; `--linear --test=campaign` checks the legacy campaign.

The model simulation deliberately injects injuries and bosses. It does not simulate a human squad's aim, movement, ammo usage or decisions. It cannot establish that a real run takes 45 minutes or feels balanced. A full squad playtest remains required; no performance improvement or Steam verification is claimed.
