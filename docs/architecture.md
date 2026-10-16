# Architecture and conventions

`AGENT_BRIEF.md` is the authoritative specification. The adjacent Word document
is a supplied reference. M1 implements an offline survival round. No network
session or export is implemented yet.

Validated engine: **4.7.2.stable.official.ed1daf0bf**, macOS arm64. Use this version
to reproduce results. Compatibility renderer, 384×216 base viewport, integer
viewport stretch, nearest texture filtering, and a 1152×648 initial window.
The built-in Godot font is temporary; original pixel-art atlases and composed
GDScript scenery are described in `assets/README.md`.
No external assets, plugins, or package dependencies are required.

## Layout

- `scenes/ui`, `scripts/ui`: menu, loading card, controls, HUD/results, weather,
  night lighting and explored field chart.
- `scenes/world`, `scripts/world`: forest round, authored camp, finite seeded
  woods topology and landmarks.
- `scenes/actors`, `scripts/actors`: survivor body, movement, stamina, and status.
- `scenes/items`, `scripts/items`: pickup and van rules/visuals; the van scene is
  under `scenes/world` because it is a permanent world fixture.
- `scripts/ai`: killer senses, state machine, attacks, and navigation agent.
- `scripts/core`, `assets/default_config.tres`: gameplay configuration, Session
  autoload and seeded RoundPlan.
- `scripts/network`: reserved for M2 ENet and authority boundaries.
- `assets/tiles`, `assets/sprites`: original terrain and directional character/tree
  sheets, reproducible with `tools/build_pixel_art.py` and
  `tools/build_cryptids.py`; audio remains reserved.
- `tests/integration`: menu, isolated physics/rule fixtures, and full input rounds.
- `tests/unit`: reserved; current rules are verified with real engine physics.
- `tools`: Python standard-library launch and verification scripts.
- `docs`: architecture, testing, milestone plan, and development log.
- `artifacts/verification`: ignored, reproducible logs, JSON, and screenshots.

The animated menu selects Quick Camp or Woods Expedition and an optional seed.
Session retains only mode/current seed/next seed, not actors or inventory. The
loading card renders before synchronous scene/world preparation; its moving bar
is an activity indicator, not simulated resource progress. Threaded resource
loading was removed after Godot 4.7.2 emitted leaked RefCounted warnings on exit.
ForestLevel owns one offline round. Host/join arrive in M2. Scene replacement frees actors, items,
navigation, UI, and signal connections together on restart or menu return.

## Implementation direction

M1 uses native CharacterBody2D/StaticBody2D physics, NavigationRegion2D and
NavigationAgent2D. CampMap creates a 3456×1920 world containing the 1536×960
authored camp and a 1600×1600 seeded woods section. TileMapLayer ground,
ten furnished buildings, dense pine/birch woods, paths and a docked lakeshore
remain in the camp.
One obstacle list drives physics, shadow occluders and the native navigation bake.
Seven-pixel navigation clearance preserves door access. Actors and trees share a
Y-sorted container above floors; roofs fade out on entry and return on exit.

ForestLevel is the offline authority: pickup proximity/availability/raycast checks,
inventory awards, deliveries, revive holds, extraction, and results. HUD only
emits lifecycle requests. CampVan validates deliveries and start holds; CampPlayer
owns movement/stamina and status. CampKiller runs the explicit PATROL →
INVESTIGATE/CHASE → SEARCH → PATROL state machine. It records visible targets with
decay and only pursues current positions while raycast sight is valid. Hearing
records the emitted location; lost targets do not update hidden positions.

Defaults live in CampConfig: walking 70 px/s, sprint 110 px/s, four stamina seconds,
two-second van start, eight-second departure, three-second revive, two-second attack
cooldown/revive grace, sixteen-second bleed-out. First hit downs; second eliminates.
Starting automatically boards the driver. CampVan validates other survivors'
proximity and unobstructed access to a side/rear boarding point before E enters
them. BOARDED survivors cannot move or receive hits. At departure only recorded
passengers escape; unboarded survivors are left behind. At least one escape wins;
results still report the local player's actual escaped/left-behind/dead status.
If all are dead, the round loses. Solo downing waits for the second hit or
bleed-out; no self-revive. Multiple-survivor rules remain fixture-tested only.

F toggles a native shadow-casting PointLight2D flashlight, Tab shows inventory and
a field map, and Esc freezes actor physics and round timers. CanvasModulate uses
very low ambient light; small nearby glow preserves the player silhouette while
flashlight beams, warm cabin/camp lights and headlights light local terrain.
Walls/trunks cast visual shadows. The old full-screen darkness shader is removed.
Footstep hints and the killer's !/? indicators are visual telegraphs; no audio yet.
Quick Camp retains fixed M1 pickups/patrol. The user's woods request authorizes
the following replayability work ahead of M2.

RoundPlan uses private seeded RNGs for topology, component pools, cache assignments,
supplies, weather and the two-cryptid roster. WoodsLayout uses DFS plus extra
connections across a finite 10×10 trail grid: all 100 clearings connect, with
dead ends, loops and six separated ruins. Solid 32px cells merge into row spans
for physics/occlusion; trees above them are visual only. Both player and AI use
the same native navigation bake. The woods chart reveals visited clearings and
their immediate connecting trails, not the whole maze or hidden caches.

Expeditions require battery/fuel/key and two parts chosen from belt/fuse/tire/spark
plug. Battery/key use camp location pools; three parts occupy locked woods caches.
One reusable boltcutters pickup in Maintenance unlocks caches. Q throws a 9-second
flare, R consumes a spare battery (+70s, maximum 90s), C consumes rations (full
stamina). Woods flashlight use drains charge; camp use does not. Medkits reduce
teammate revive holds to 1.2s and are consumed only on completion. All awards/use
validate alive status, membership, availability, proximity and clear access as
applicable. Pause freezes actors, battery drain, flares and round timers.

CampCryptid inherits the stalker's sensed-memory FSM, with species-specific
rules: wolf speed 116 during a 0.9s charge in each 3.6s cycle, otherwise 48; Bigfoot
hears 300px but chases 63; moth sees light up to 220px and ignores dark survivors
beyond 45px. Flares repel the stalker, wolf and Bigfoot within 95px of clear sight;
moths investigate visible flares within 220px independently of hearing. Monsters
still use raycasts/navigation and never track unsensed target positions. Fog
reduces enemy sight to 72% and woods beams to 70%; rain reduces hearing to 70%.
Weather visuals render below the HUD. Cryptid sensing ignores survivors in camp;
their sensed-memory searches may briefly follow sounds/trails toward the gate.

The visual expansion was explicitly requested after M1, authorizing this portion
of polish ahead of M2. Battery is in Fern Bunk Cabin, fuel in Maintenance, key in
the Ranger Lodge office. The larger-layout input playthrough obtains native
navigation paths and walks them using normal controls. It waits for a usable
navigation map after creation/reload instead of assuming three frames suffice.

M2 adds GameManager and NetworkManager when session/ENet behavior exists, moving
the current authority path to the host and replacing direct input with intents.
Clients send input/intents; the host owns positions, inventory, AI, health, repair,
extraction, and phase changes. Initial late-join policy: lobby only. Direct IP/LAN
or virtual LAN; no relay, NAT traversal, or host migration is promised.
