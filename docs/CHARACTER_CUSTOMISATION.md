# Character customisation and wardrobe

Open **Customise → Character & wardrobe** on the title screen. There are eight selections per category: hair, hair colour, brows, eyes, nose, mouth, facial hair, skin tone, earrings, glasses, watches, necklaces, T-shirts, trousers, shoes, jackets and full outfits. The 136 entries include starter/none selections. All generate real geometry/material variations on the existing animated character rig.

Face and skin choices are free. Clothing and accessories unlock automatically as career wardrobe XP grows. Starter clothing and “none” accessories cost zero. Other entries require 50, 100, 200, 350, 550, 800 or 1200 XP; jacket requirements are doubled and full outfits tripled. This is an unlock threshold, not a purchase: XP is never spent. Gameplay awards 5 XP per common kill, 25 per special kill, 40 per revive and 250 per escape. Only human players receive rewards, via their owning peer from the host. Cosmetic progression is separate from campaign gun credits and survives campaign resets.

Click a selection to preview it, including locked choices. Wear this look saves only unlocked looks. Done/Esc closes without applying unsaved changes; Reset to equipped restores the saved draft. Full outfits override clothing geometry/colours while retaining your individual clothing selections for use when you switch back to Separate pieces. Accessories and facial features remain selected. Drag the preview to rotate, or use arrow buttons. Face and Full body change framing; watches, necklaces and shoes also get category-specific close-ups.

Equipped appearances apply to the local hideout survivor and are sent when hosting/joining a session. The host normalises option IDs and carries the appearance in survivor spawn data, so peers and late joiners build the same look. Bots and story NPCs keep their authored appearances. First-person hand skin, sleeves and left-wrist watches follow the profile. Cosmetic options do not change health, weapon stats or collision capsules. A changed look applies to the next session, not an ongoing one.

Profiles are stored locally in `user://wardrobe.cfg`. This is local co-op progression, not secure online entitlement storage; editing the local file can bypass unlocks. Steam Cloud sync and cross-device account saves are not implemented. Test runs use separate ignored files under `screenshots/test-profiles` and never award XP into the actual player's profile.

Validation:

- `godot --headless --path . -- --test=wardrobe`: counts, actual mesh/material differences for all 136 entries, unlock rejection/earning, profile reload, malformed input, real menu/editor path, locked preview and applying a free choice.
- `godot --path . --resolution 1600x900 -- --test=wardrobe`: same checks plus native editor screenshots and 136 native preview renders, including 720p layout.
- `godot --headless --path . -- --host --test=wardrobe_net_host` and a second process with `--join=127.0.0.1 --test=wardrobe_net_client`: two distinct profiles rendered by both peers, and a remote revive XP reward persisted by the correct client.
- `--solo --linear --test=animation_verify`: existing weapon/reload animation behaviour remains intact.

The procedural style is an initial catalogue rather than final hand-authored cosmetic art. Physical gamepad navigation, real Steam clients, Steam Cloud and exhaustive accessory/hairstyle fit combinations remain unverified. See `screenshots/wardrobe/evidence.md` for the captured build and logs.
