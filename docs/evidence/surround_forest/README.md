# Massive surrounding forest evidence

Godot 4.7.2 / macOS arm64. Final full verification: 77 steps, no engine errors
or warnings. The active expedition uses normal input/collision/AI rules with
all 25 enemies enabled; it escaped after about 12,499px/38 visited clearings.

The labelled world overview is an inspection schematic, not the player's map.
Region overviews use brighter light, disabled sight and exact quarter camera
scale only for layout QA. `region_refresh.log` records their final capture pass.
Normal woods/field-notes/escape images retain ordinary gameplay presentation.
Masked/unmasked sight images deliberately raise ambient light to prove opaque
occlusion; the unmasked image is a positive control, not shipped visibility.

`navigation_seeds.log` checks all pickups and four exits across twelve fixed
seeds. `surround_world.log` checks centered bounds, three connected 2410-cell
graphs, region aprons, native exits/homes/sites and actual-input gate traversal.
The replay suite proves whole-graph connectivity plus native paths to about
120 sampled clearings/all pickups/landmarks. Layout checks cover eight seeded
camps and every entrance/pickup. Native seam endpoints allow seven-pixel agent
clearance; input-driven full rounds retain actual physical collision.

Human balance/listening, Windows/Linux/exports and network/voice remain
unverified. No microphone capture or microphone permission request. Word brief
requirements match Markdown structurally, but document visual rendering remains
unavailable because renderer dependencies and LibreOffice are absent.
