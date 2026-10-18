# World graphics and presentation review

18 October 2026. Critic/reviewer analysis, following the
[map/help audit](graphics_readability_plan.md). Status: findings and proposed
changes; no gameplay rendering or audio implementation changed in this increment.

**Implementation update (later on 18 October):** fixed #1 (each region title is
drawn once, with an outline), #6 (the motor sign and "E / RARE TOOL" now follow
state), the fading killer's dark shadow, and partly #5 (pickup piles label once;
two adjacent piles can both label). Dramatic phase titles shipped with the ranger
radio transcript. Still open: #2 building names, #3 region-entry titles, #4
skyline collision pass, landmark identity. [Evidence](evidence/notebook/README.md).
A further increment fixed #2 (door plaques plus a line-of-sight door name),
#3 (place titles on entry), #4 (one skyline layout pass) and the naming item
(clear short names, CAMP BOATHOUSE vs LAKESHORE). Landmark identity remains open.

## Assessment

The forest has a strong miniature-horror identity: warm camp materials, dark
trail corridors, a readable flashlight cone, treelines with depth, and distinct
machinery at the power/relay sites. The problem is not simply insufficient light.
**Important information is rendered as scenery, then obscured by the scenery's
lighting, roofs, trees and other text.** That creates uncertainty about controls
and location rather than productive uncertainty about danger.

The world also overuses the same little shrine/rare-tool composition across very
different named destinations. The mill, observatory and chapel need recognizable
silhouettes and entrance landmarks, not just different ground textures and names.
Their names promise stronger identities than this baseline often communicates.
This is an editorial judgment from the captures, not a claim that their terrain
or collisions are broken.

## Evidence and coverage

A graphical fixture captured **48 views** on seed 42: all ten camp buildings,
centers and label edges of all fourteen major regions, a signpost, crowded
bearings, a phase change, and explicit bright inspection views. All were opened
and visually inspected. Normal views preserve fog-night lighting and sight;
inspection views intentionally disable sight and brighten ambient light to expose
layering. Enemies and phase progression are frozen; all escapes are forced so
all machinery is available. These are staged placements, not a human playthrough.

[Selected screenshots, metrics, commands and logs](evidence/world_review/README.md).
No universal claim about every seed, animation frame, multiplayer layout or
export follows from this sample. Water animation continuity, movement/flicker
comfort and live combat readability still need normal-speed human testing.

## Concrete graphics defects

### 1. Three region names really are drawn twice — high priority

Logging, boathouse and ranger regions call `FieldEscapeArt.draw_site` from
`ForestSite._draw`, then also execute the generic site-label draw at the end.
The helper draws at `(bounds.x + 12, bounds.end.y - 14)`; the generic label draws
at `(bounds.x + 8, bounds.end.y - 10)`. The same text overlaps with a **4px offset
on both axes**. This is not an intentional shadow: both are colored name draws.

[Logging](evidence/world_review/inspection_label_logging.png),
[boathouse](evidence/world_review/inspection_label_boathouse.png),
[ranger road](evidence/world_review/inspection_label_ranger.png).
Source: [helper](../scripts/world/field_escape_art.gd),
[caller and generic label](../scripts/world/forest_site.gd).

Fix direction: give one label system ownership of each title. Retain a deliberate
single high-contrast outline/backing if desired; do not draw the title twice from
independent renderers.

### 2. Building names are hard to read on the actual approach — high priority

[Maintenance, normal](evidence/world_review/building_workshop_1168.png) and
[bunkhouse](evidence/world_review/building_bunkhouse_816.png) show names nearly
lost in darkness beneath the top HUD. From the door approach, the narrow beam
lights roof center while the label starts far to the left. Roof name tint already
has only 75% alpha before darkness and roof fade. On entering, the entire roof
node fades, including its name. The separate interior name then sits near the
top wall, frequently at/behind HUD height.

Source: [roof](../scripts/world/building_roof.gd),
[interior](../scripts/world/camp_building.gd). The
[bright view](evidence/world_review/inspection_workshop.png) exposes what exists
but is unreadable during ordinary lighting.

Fix direction: an entrance plaque/name anchor that does not inherit roof fade,
plus one nearby screen-space building title. Only show it when the entrance or
building is legitimately visible; do not expose names through walls. Clamp it
into a safe text area and keep the full name available in the notebook.

### 3. Ground-painted region labels are illuminated a few letters at a time

The default region title sits at its clearing's southwest edge, far from many
approaches and its center. At normal flashlight range the cone lights a small
slice of a 90–160px string. Trees and the sight mask can further conceal it.
[Normal Logging label](evidence/world_review/label_logging.png) versus
[bright Logging](evidence/world_review/inspection_label_logging.png) makes this
particularly clear. [Normal mill center](evidence/world_review/region_mill.png)
does not show its world title; the HUD location line carries the useful name.

Fix direction: keep physical signage for flavor, but show a brief canonical
region-entry title and a persistent compact location breadcrumb. Put entrance
signs at actual approaches. Do not force players to sweep their flashlight along
a paragraph on the ground to find out where they are.

### 4. Skyline names collide across categories — high priority

The [crowded-bearings fixture](evidence/world_review/crowded_bearings.png) stacks
one help ping and a player pin along a shared bearing. Only pins deduplicate
against other pins. Landmarks, help, known-part annotations and pins do not share
a collision pass; text can also sit under the top HUD. The fixture deliberately
stages the collision; it does not represent a naturally occurring four-peer round.

Source: [skyline](../scripts/ui/skyline.gd). Fix direction: one layout pass for all
markers, with rescue/help first, tracked objective second, teammates/pins next,
optional landmarks last. Use bounded label boxes, alternate rows, grouped counts
and focus-to-expand. Preserve directional meaning instead of moving icons to
arbitrary screen positions. Hide optional world labels under an open notebook.

### 5. Pickup piles and interior text lack shared spacing

The [workshop interior](evidence/world_review/inspection_workshop_inside.png)
contains overlapping supply words, world names and HUD elements. Pickup cluster
suppression only compares the **same kind**, nearby and strictly leftward;
different kinds and identical-x stacked units can still all label themselves.
Phase supplies are also spawned only 9px apart.

Source: [pickup labels](../scripts/items/pickup.gd),
[phase supply drops](../scripts/core/night_clock.gd).
Fix direction: show icons for nearby items, one selected item's full name and
interaction prompt, and a “supplies ×N” cluster summary. Do not draw a label for
every unit in a stash. Measure text width and reserve HUD-safe bounds.

### 6. Some painted instructions ignore availability/state

`FieldEscapeArt.draw_structure` always paints “MOTOR / HEAVY CARRY” at Logging
Camp when its structures render; it does not test motor availability or whether
the boat route is selected. `ForestSite._draw_landmark` paints “E / RARE TOOL”
even after a used action adds “EMPTY”. These are code-confirmed inconsistencies;
a post-consumption capture for every site was not performed.

Fix direction: flavor signs may persist, but actionable E prompts must come from
current interactable state, have one owner, and disappear or change after use.
Never let a decorative instruction compete with a truthful bottom prompt.

## Other visual observations

- **Positive:** the substation transformers and relay tower have immediately
  recognizable silhouettes. [Power](evidence/world_review/region_substation.png)
  and [relay](evidence/world_review/region_relay.png). Use that standard for other
  landmark regions. Their upper-world drawing is intentionally readable above
  the floor mask; this review did not establish a new floor/monster fog leak.
- **Identity:** shared shrine props in mill/orchard/chapel make distinct regions
  feel like a repeated pickup stop. Add one strong silhouette, entrance motif and
  regional palette cue each before adding more scattered decorative props.
- **Clutter:** roof texture, interior inventory labels, equipment names, horizon
  icons and HUD text currently all compete at similar visual weight. Give
  interactive information clean backing and lower optional decorative contrast.
- **Naming:** POWER/DOME/GRAVES skyline abbreviations require players to map them
  to Power Substation/Starless Observatory/Old Graveyard. Camp Boathouse versus
  Lakeshore Boathouse also deserves explicit names. Use canonical full names in
  location/plan details and consistent short names on signs and skyline.
- **Fading killer:** [inspection view](evidence/world_review/inspection_faded_killer.png)
  shows a ghost body and still-dark ground shadow. Source explicitly uses body
  alpha 0.12 but an unconditional 0.4 shadow. Decide whether this is a ghost tell
  or should disappear; do not call it an accidental invisible killer based on
  this staged `faded` flag alone.
- **Still pending:** sprite animation seams/directional poses in motion, water
  transitions, four-player overlapping names/effects, lightning comfort and
  every seed's occlusion/collision alignment. Static photos cannot clear those.

## Dramatic phase titles: recommended

Yes. Phase changes deserve a short dramatic overlay because they change the
rules and pacing. At present the title is embedded in the small HUD header and a
long lower announcement; [Deep Night capture](evidence/world_review/deep_night_transition.png)
shows the camp-safety warning sharing that text stream. Phase radio static and
chatter already exist; there is no dedicated dramatic phase-title overlay.

Proposed text (copy must remain true to the implementation):

| Phase | Main title | Supporting line |
| --- | --- | --- |
| Dusk | DUSK | Find your way. Prepare an escape. |
| Nightfall | NIGHTFALL | The hunt deepens. Check the ranger's report. |
| Deep Night | DEEP NIGHT | CAMP IS NO LONGER SAFE. |
| Witching Hour | THE WITCHING HOUR | Your escape is nearly ready. Finish it. |

Avoid clock claims such as “midnight”, “one hour left” or “dawn is coming”: this
night advances by progress and bounded time drift, without a dawn deadline.

Presentation proposal:

- Large, restrained upper-center lettering with a quiet dark backing only behind
  the text; ~0.35s fade in, 1.8s hold, 0.6s fade out. A ~3s moment, not a cutscene.
  No pause, input capture, camera takeover or full-screen black interruption.
- Keep player/enemy silhouettes, injury/held prompts and interaction progress
  visible. Critical rescue/down/held information wins priority; collapse the
  phase title to a smaller ribbon if necessary. Support reduced motion.
- Follow with a compact actionable report: revealed part/bearing, supply drop,
  changed camp rule. Keep it in event history after the title disappears.
- One short phase-specific stinger, with radio chatter starting after the accent.
  Do not stack thunder, horn, scream and radio at full level. Silent Night should
  continue honoring its music rule; decide explicitly whether these accents are
  Effects or Music and document the result. Visual text works with audio muted.
- Trigger from the accepted phase transition on each peer, with round/phase
  deduplication. Host `_enter_phase` alone does not implement a client overlay.
  Late joins/retries must not replay stale titles. If progress skips phases in
  one tick, show the resulting phase once and summarize all reveals; do not
  flash a sequence of full titles. Dusk gets one opening title, not every load.

Implementation belongs after fixing basic label ownership. It should make the
change comprehensible, not add another text layer on top of existing collisions.

## Recommended order

1. Remove the three duplicate region-title draws; fix roof-name dependence and
   interaction labels that lie about availability. These have direct evidence.
2. Add one shared label compositor with visibility checks, priority, measured
   bounds and HUD exclusions. Reuse it for buildings, pickups and skyline.
3. Add canonical region-entry titles, location breadcrumbs and notebook linkage.
4. Add phase-title/report choreography and the sound batch from the
   [sound gap review](sound_gap_review.md).
5. Differentiate repeated landmark compositions and run motion/co-op/accessibility
   review before judging a full art replacement necessary.

Acceptance: no overlap in the captured reproduction cases; names readable at
normal lighting without revealing unseen locations; accurate consumed/carried
states; every critical event understandable with audio muted; phase titles fire
once per actual transition and leave control responsive. Expand the previous
plan's seed/window/peer matrix before claiming the overall graphics pass complete.
