# Player settings

Open **Settings** from the title screen or Esc pause menu. Preferences save to Godot's `user://settings.cfg` on change and reload on launch. Existing name, volume, sensitivity and FOV preferences migrate automatically.

- **Controls:** mouse sensitivity, aim multiplier, controller look sensitivity and dead zone, inverted vertical look, hold/toggle aim and crouch. Click an action to bind a keyboard key, mouse button or controller button. Esc cancels capture. Rebinding replaces that input type and retains the other input types. Stick axes and triggers keep their defaults. Restore default bindings is available.
- **Comfort:** camera shake, head bob, cosmetic weapon sway/bob and damage flash intensity, each independently adjustable from zero to full strength. Gameplay recoil/spread and reload timing are unaffected.
- **Crosshair:** colour, size, opacity, visual hit markers and marker sound. Markers follow host-confirmed infected bullet hits.
- **Audio:** Master, Effects, Music and Voice buses. Existing music stingers route to Music; character vocal effects route to Voice. This does not add voice chat.
- **Display:** FOV, windowed/borderless/exclusive fullscreen, window resolution, VSync, unlimited or fixed FPS caps, graphics quality. Low uses 65% render scale/no MSAA; Medium 85%/2× MSAA; High native/4× MSAA. Fullscreen uses the monitor resolution. Window mode/resolution changes require confirmation within 15 seconds; timeout/closing reverts them. Unconfirmed display values are never persisted, including when another setting saves.

The action continues while menus are open, including solo. Settings block the local player's gameplay input. Controller hardware and platform-specific fullscreen behaviour still need manual testing on target devices.

Verification: `tools/godot --headless -- --solo --test=settings`; native screenshots and mouse capture checks: `tools/godot -- --solo --test=settings`. Test captures mute the game Master bus and restore saved preferences. Evidence is under ignored `screenshots/settings/`.
