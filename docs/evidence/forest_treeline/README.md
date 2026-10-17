# Forest edge: cardinal view evidence

macOS arm64 / Godot 4.7.2, Compatibility renderer. Full `python3 tools/verify.py`:
**104 steps passed**, zero errors/warnings. The standard runner now includes the
new headless treeline regression and its optional graphical counterpart.

Actual graphical runs:

- `treeline.gd`: **20 assertions**, four directions at normal night exposure,
  foliage on/off pixel comparisons, hidden neighboring monsters, native wall
  collision, actual walking/lookahead, HUD clearance, avatar pixels against a wall, and camp recentering.
- `woods_visibility.gd --capture`: **7 assertions**, including full-ambient world
  pixels: hidden trail floor **0.0**, mask-disabled control **0.187** luminance.
- `woods_shadows.gd --capture`: **12 assertions**, four native flashlight shadow
  cases. Adjacent-path gain **0.0**; removing occluders produces positive leakage.
- Two actual graphical ENet peers in both modes: **273 assertions / 6 process
  runs**, all passing. Existing shared flashlight/flare pixel tests pass.

```sh
python3 tools/verify.py
python3 tools/verify_network.py --mode all --players 2 --graphical
godot --path . --audio-driver Dummy --script res://tests/integration/treeline.gd
godot --path . --audio-driver Dummy --script res://tests/integration/woods_visibility.gd -- --capture
godot --path . --audio-driver Dummy --script res://tests/integration/woods_shadows.gd -- --capture
```

`treeline_before_*` uses the prior committed renderer; `treeline_after_*` uses
the new one. Both sets use the same seed, wall fixtures and settled cameras.
Captures are unedited engine images, with normal fog, lighting, HUD and sight
mask; no ambient/exposure boost. All four lit/unlit directions were inspected.
The north and south after images are also in `../../screenshots` and the README.
Before/after tree placements and enemy positions are controlled for inspection;
they are not a human playthrough. The walking case uses ordinary movement input.

Sight/shadow diagnostic tests separately isolate world pixels from UI markers
and fog drawn on higher CanvasLayers. The positive floor probe avoids a native
trunk/shadow at the old single-pixel location. Tests wait for the world to load
and for actual drawn frames/camera cache updates; fixed five-physics-frame waits
previously raced loading/rendering. Initial fixture failures were corrected,
without weakening the black-floor or native shadow thresholds.

No new image generation, credits or external assets were used. Existing
SpriteCook trees/shrubs are reused with original placement/shader code. Only
visible foliage is drawn over fog, fading before the neighboring corridor;
collision, native light occluders, terrain and AI sight are preserved. Human
pacing/play-feel and other-platform acceptance remain unrecorded. Walking
point samples varied from 37 FPS under concurrent verification to 142 FPS in
the final run; these are observations, not a performance benchmark.

A close-wall walking control also caught the old lower canopy duplicate covering
the avatar despite the foreground fade. Native crown bounds now detect overlap
from every side and yield to the surface pass's local opening. A small fog-mask
opening follows the known local silhouette (under 29px) and its 25px body light
remains readable; neither reaches across a forest wall. Far-floor/monster and
native flashlight-occlusion controls still pass. Avatar readability is checked
by hiding only its own drawing (`self_modulate`), holding lights and foliage
constant, and measuring the remaining body pixels.
