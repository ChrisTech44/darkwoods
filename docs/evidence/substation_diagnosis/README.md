# North substation black-box diagnosis

18 October 2026; main code f7ba74c, macOS Godot4.7.2, actual 1152×648 window.
Historical investigation only: product code was unchanged in this increment.
The [19 October repair](../objective_scenery/README.md) supersedes its open status.

The center prop is the emergency fuse/breaker cabinet, asset
[f5_breaker.png](../../../assets/sprites/sc/f5_breaker.png), with an open door,
panel and amber beacon. Two transformers flank it. It supplies Radio Rescue or
Ranger Gate on those nights. Interact at the south/front power point with the
emergency fuse; inactive nights intentionally have no power objective.

Confirmed defect: RadioRescue._ready returns immediately when neither radio nor
gate is selected, before creating rescue_structures. All elevated substation
machinery is drawn by that child. CampMap._build_sites always creates its three
solid, light/sight-blocking rectangles. ForestSite draws only the ground site.
Therefore inactive power nights retain invisible machinery collision/occlusion:
the resulting shadow/line-of-sight mask reads as a black box instead of a cabinet.
The sprite file is present and correctly illustrated; this is route-dependent
missing drawing, not a missing or black texture.

Same normal seed13/van+boat, unaltered ambient/sight/light, frozen AI, stopped night
clock, staged front/north player positions and flashlight aimed toward machinery:
[front](boat_front.png), [north](boat_north.png). No power structures are created,
zero breaker props. Comparison uses the SAME seed/poses with **forced all escapes**,
which activates the power system: [front](all_front.png), [north](all_north.png).
Artwork appears, one breaker prop. The comparison is diagnostic and does not
represent a normal all-route night. Weather remains the seed's rain; no raised
inspection lighting, microphone or network session. All four actual captures were
inspected; both processes exited0 without warnings/errors. [Data](observations.json).

The original world review used forced all escapes and therefore showed the
working cabinet, missing this inactive-route failure. Proposed repair: create
static substation machinery independently of escape eligibility, retain its
physical footprint, and gate prompts/interaction/power/lamps by the active route.
Inactive relay geography needs the same ownership review. Check normal boat,
signal, radio and gate nights, both approaches, and preserve clue hiding and host
authority. This investigation records the defect; no rendering fix ships here.
