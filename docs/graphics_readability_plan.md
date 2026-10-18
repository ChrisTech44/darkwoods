# Graphics audit and map/help overhaul

18 October 2026. Status: audited baseline and proposed implementation plan.
No gameplay graphics or menu redesign ships in this documentation increment.

Follow-up: [world graphics and presentation review](world_graphics_review.md)
extends this audit to all major region types and camp buildings, confirms duplicate
region-name draws, and proposes dramatic phase titles. The
[sound gap review](sound_gap_review.md) reconciles the asset wishlist with current
playback and prioritizes recordings and missing triggers.

## What was inspected

Source: HUD, field map, skyline, objective text, input handling, pickup state,
headline rendering and title-screen field guide. Graphical baseline: Godot 4.7.2,
macOS Apple M2, OpenGL Compatibility, 384×216 viewport (default 3× window).
The capture fixture uses seed 42, all escape pages, no modifiers, frozen enemies,
normal sight/lighting and stopped night progression. All-escape availability is
diagnostic; normal Expeditions offer only van plus one secondary.

[Evidence and reproduction](evidence/readability_audit/README.md).
Screenshots establish the observed layouts, not full-round usability or balance.
This is a targeted rendering/UI audit, not clearance of every sprite, animation,
biome, multiplayer state or export. New captures for those remain acceptance work.

## Confirmed defects and discrepancies

| ID / priority | Finding and evidence | Cause / intended correction |
| --- | --- | --- |
| G01 / high | Map covers right-hand objective hints in both camp and woods. [Camp](evidence/readability_audit/camp_van.png), [woods](evidence/readability_audit/woods_van.png). | `hud.gd`: notes occupy x9–375, y40 onward; chart starts x216,y46 and is drawn later. Split layout or dedicated views; no shared text area. |
| G02 / high | Notes panel extends over the belt and location line; map frame also enters belt space. Same captures. | Label minimum size grows with multiline content; 104px requested height is not a maximum. Chart frame reaches y161; belt starts y150. Use containers with explicit content bounds, scrolling and a protected HUD area. |
| G03 / high | Collected/installed objectives remain at their original numbered map location. | `camp_chart.gd` loops `plan.loot` without checking live availability, inventories, installation or moved drops. Replace static spawn markers with current known objective state. The fixture consumes/delivers the battery; [installed capture](evidence/readability_audit/battery_installed.png) retains its marker. |
| G04 / high | No remote survivor markers on the field map, despite README Mimic guidance telling players real teammates appear there. | `camp_chart.gd` draws only `player`; no survivor iteration. Draw connected teammates and downed state with names/shape distinctions, using replicated actor state. Until implemented, correct player guidance in the implementation slice. |
| G05 / medium | Secondary objective pages hide the map, exactly when their remote destinations matter. [Boat](evidence/readability_audit/page_boat.png). | `forest_level.gd` Tab/T handling sets chart visibility only for objective page zero. Map should be independently accessible for every active route. |
| G06 / medium | Map distorts direction/shape and is only local in the woods; it cannot show the whole trip. | Woods square 1536×1536 maps to 146×91: x scale is 1.60× y scale. Camp 1536×960 is nearly proportional. Use one scalar world-to-map transform, letterboxing, full-world overview plus local zoom. |
| G07 / high | Field guide presents obsolete rules: fixed village/bog/graveyard caches and “Solo build”; omits Space flash, T plans, M pins, X ability, H give and B voice. [Guide](evidence/readability_audit/field_guide.png). | Static `main_menu.tscn` bindings/note text predates co-op/objective rotation. Derive keys from InputMap where possible; update gameplay explanations from current rules. |
| G08 / medium | Small text, long strings and busy world backgrounds compete for attention. [Notice](evidence/readability_audit/long_notice.png), [radio](evidence/readability_audit/page_radio.png). | 6–9px text, long unwrapped objective lines, bottom prompt mixes transient news with interaction help. Give objectives bounded rows and event banners an opaque backing plus history. A long notice can exceed reserved two-line prompt space; test worst-case strings. |

### Additional code-backed graphics concerns

- Map region names use unrestricted `draw_string` widths and there is no map-area
  clip. Long labels near an edge can escape their rectangle; crowded seeds need
  dedicated captures before classifying each collision. Visited dots/links draw
  after region text, so they can paint over it. Draw terrain first, labels last.
- Skyline only collapses nearby **pins**, not landmark/help/part labels as one
  system. Long labels have no shared collision solver. Test crowded edges and
  four-peer rescue/help cases; do not claim those cases were visually reproduced.
- Killer fading tints the body to 12% alpha but draws its ground shadow at 40%
  alpha unconditionally (`killer.gd::_draw`). This can leave a dark footprint
  during a fade; verify against actual ground textures before changing it.
- Paused settings fit this captured configuration, but expose gameplay text
  behind the panel. [Pause](evidence/readability_audit/pause.png). Long device
  names, more voice status text and results content need overflow checks.

## Intended player experience

A player should be able to answer four questions without interpreting a paragraph:
**Where am I? What changed? What should I do next? What is blocking me?**

Example Escape Plan card:

```text
RADIO RESCUE                          Step 1 of 4
NEXT: Find the emergency fuse
WHERE: Flooded Mill — west of camp
THEN: Fit it at the north Power Substation
[Show on map]                         [Next route]
```

This is a wireframe, not a screenshot or shipped screen. Unknown destinations
must remain “north woods — find a ranger note” until existing clue rules reveal
them. Never invent a precise marker or shortest route through unexplored trails.

## Navigation and layout proposal

- **Tab: Camp Notebook**, with visible Map / Escape Plan / Field Guide tabs.
  Remember the last view. Escape closes the notebook first, then opens pause.
  T continues cycling only tonight's available escape plans; opening the notebook
  must not change the selected route. Keep M as the existing pin action initially.
- **Map:** full-world overview, camp/local zoom, center-on-player, compass, scale,
  labeled legend, teammates, downed/help markers, known objectives and extraction.
  A side detail card explains selected markers and offers “track this objective”.
  Roads/region outlines remain known as today; unexplored trails stay concealed.
  Use equal x/y scale, bounded text and grouped edge markers with a visible count.
- **Escape Plan:** show van and the one secondary as named tabs/cards, not an
  invisible page cycle. Separate numbered steps, prerequisites and carried tools
  from optional supplies. Show which teammate carries an item, dropped location,
  installed completion and sabotage relocation using authoritative state.
- **Field Guide:** separate Controls, Survival, Tonight's Killer and Escape Rules.
  Short expandable entries; explain ordinary beam versus Space flash, stalking
  versus chase, and shared Groundskeeper behavior accurately. Include a visible
  keyboard/mouse path back to map and objective plan. Keep the title-screen guide
  on the same content source. Do not add invented real-time killer-state tracking.
- **During play:** retain health/light/belt and a compact tracked next action.
  Separate event banners from E interaction prompts. Event history includes phase
  changes, revealed parts, sabotage, blackout/generator location and rescue timers.
  Show current phase plus “escape preparation advances the night”; elapsed time
  is secondary, with no misleading dawn countdown.
- Show an explicit “world continues in co-op” notice. Offline Tab continues its
  existing non-pausing behavior in the first slice; Esc remains the pause action.

### Readability and art rules

Keep the established camp/forest art. Use dark, quiet panel interiors, clear
headings and one consistent icon set. Pair color with shape/text. Reserve space
for belt, location, interaction and announcements; suppress world-space bearing
labels behind the notebook. Use container layouts, wrapping and bounded scrolling,
with visible focus and scroll affordances. Never shrink text to force a fit.

First prototype within the current 384×216 game canvas: at least 9px body text,
11–13px headings, fewer rows per view. Verify the actual font, not just its size.
If this cannot meet readability goals, prototype a separate 1152×648 UI canvas
with 16–18px body text over a nearest-scaled 384×216 world SubViewport. Treat that
as a separate rendering change: it can affect camera, pointer coordinates,
lighting, screenshot sizing and overlays. Compare both before adopting it; do not
silently change global stretch mode or blur existing pixel art.

## Delivery slices and acceptance

### 1. Correct misleading content and layout defects

Update field-guide facts/keys, stop map/text overlap, protect HUD space, fix stale
objective markers and expose the map on all route pages. Update README map/Mimic
claims with the actual resulting behavior. Preserve the baseline captures.

Acceptance: all five diagnostic pages at start and completion are readable;
consumed/installed objects disappear from spawn markers, dropped/sabotaged known
items appear at live positions; no notes/frame draw into belt or interaction text.
Run import/startup, relevant objective/clue integration checks and graphical QA.

### 2. Shared objective presentation model

Create a presentation adapter from existing plan, clues, live pickups, inventories,
installed steps and sabotage state. One model drives map markers, objective rows
and next-action hints. Stable IDs and explicit states: unknown, bearing known,
region known, discovered, carried, dropped, installed, relocated. Do not add a
second authoritative inventory or change the network protocol unnecessarily.

Acceptance: solo and host/guest see consistent pickup, handoff, drop, down,
disconnect, install and sabotage updates; no hidden locations leaked. Check all
routes, delayed radio reveals and retry cleanup. Test state transitions rather
than string snapshots that merely duplicate implementation.

### 3. Notebook views and usable world map

Implement the three views and one uniform map transform; add full/local zoom,
legend, marker selection, team states and objective tracking. Replace text blobs
with prerequisite-aware steps. Support keyboard, mouse, focus restoration and
back/close behavior. Cache static map geometry instead of scanning all visited
cells for every region on every draw.

Acceptance: map is accessible from every plan; 1/2/4 survivors are distinguishable;
markers/labels stay inside their allocated areas; unexplored terrain remains
hidden; no conflicting Tab/T/M/E inputs or accidental actions behind the menu.
Check co-op world continuation and offline Esc pause.

### 4. Event comprehension, visual polish and human check

Add the separate event banner/history, contextual guide links and phase explanation.
Resolve reproduced skyline collisions and fading artifacts. If needed, ship the
separate UI-resolution prototype only after its own rendering checks.

Acceptance matrix: seeds 1, 42, 2026; Quick Camp and normal two-route Expedition;
all five routes via diagnostic override; camp/woods/interiors; all four facing
directions; flashlight on/off, blackout, storm; wounded, held, downed, rescue and
results; 1/2/4 peers; long names and notices; 768×432, 1152×648 and 1536×864 windows.
Check clipping, contrast, layering, sprite facing, shadows and focus. Reuse
navigation, rendering, clue, night-event and escape suites as applicable.

Human check (pending): without coaching, players identify their location, next
action, blocker and most recent major event in under ten seconds each. Record
actual errors/time and iterate. Do not claim that scripted captures prove this.

## Scope and limits

This plan preserves maps, generation, enemy rules and escape balance. It proposes
presentation changes; it does not authorize silently changing flashlight counters
or spawning both headline killers. Full-map visibility must honor existing clue
and exploration rules. Real cross-machine/device readability and export checks
remain separate from macOS graphical evidence.
