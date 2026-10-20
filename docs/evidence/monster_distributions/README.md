# Sample monster distributions

[Open the full-size image](sample_distributions.png).

Generated directly from current `RoundPlan.generate` and
`WoodsLayout.roaming_route` for seeds **13, 42 and 2026**, using normal Woods
plans. No gameplay rule or in-game map discovery changes.

- Numbers identify the 29 roaming species, consistently across panels.
- Gray diamonds identify the nine regional creatures; shaded boxes show regions.
- Colored hulls enclose the 16 assigned patrol waypoints for Bear Hug, Lifeguard
  and Huntmaster; small colored dots show those waypoints. The hulls are diagrams,
  not walkable territory, actual traversed paths or pursuit boundaries.
- The Stalker is excluded because it is the separate headline killer.

[Source positions and assigned waypoint data](plans.json) reproduce all markers.
Each seed verifies 29 distinct roaming species plus nine regional creatures,
16 assigned waypoints per roamer and starts at least 1100px from camp center.
Spawn layouts differ; paths can overlap and special brains override patrols.

This is an explicitly revealed diagnostic overview, not an in-game screenshot or
simulation of future movement. It uses no world lighting, frozen gameplay actors,
forced escape routes, microphone capture or paid generation. Rendered through
Godot 4.7.2 on macOS arm64; the PNG was opened and visually inspected.

Reproduce with:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_monster_distributions.gd
```

Required import/startup and `git diff --check` passed. The initial capture used
an invalid viewport property; the corrected run exits cleanly with PNG error 0.
No human balance, cross-platform or Internet acceptance is added by this figure.
