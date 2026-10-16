# Architecture and conventions

`AGENT_BRIEF.md` is the authoritative specification. The adjacent Word document
is a supplied reference. M1 implements an offline survival round. No network
session or export is implemented yet.

Validated engine: **4.7.2.stable.official.ed1daf0bf**, macOS arm64. Use this version
to reproduce results. Compatibility renderer, 384×216 base viewport, integer
viewport stretch, nearest texture filtering, and a 1152×648 initial window.
The built-in Godot font is temporary; scenery uses original GDScript geometry.
No external assets, plugins, or package dependencies are required.

## Layout

- `scenes/ui`, `scripts/ui`: menu, controls, HUD/results, and night overlay.
- `scenes/world`, `scripts/world`: forest round and original fixed camp map.
- `scenes/actors`, `scripts/actors`: survivor body, movement, stamina, and status.
- `scenes/items`, `scripts/items`: pickup and van rules/visuals; the van scene is
  under `scenes/world` because it is a permanent world fixture.
- `scripts/ai`: killer senses, state machine, attacks, and navigation agent.
- `scripts/core`, `assets/default_config.tres`: shared gameplay configuration.
- `scripts/network`: reserved for M2 ENet and authority boundaries.
- `assets/tiles`, `assets/sprites`, `assets/audio`: reserved for original content.
- `tests/integration`: menu, isolated physics/rule fixtures, and full input rounds.
- `tests/unit`: reserved; current rules are verified with real engine physics.
- `tools`: Python standard-library launch and verification scripts.
- `docs`: architecture, testing, milestone plan, and development log.
- `artifacts/verification`: ignored, reproducible logs, JSON, and screenshots.

The menu backdrop is decorative. Play Solo loads ForestLevel, which owns one
offline round. Host/join arrive in M2. Scene replacement frees actors, items,
navigation, UI, and signal connections together on restart or menu return.

## Implementation direction

M1 uses native CharacterBody2D/StaticBody2D physics, NavigationRegion2D and
NavigationAgent2D. CampMap draws geometric ground/props and creates wall shapes
from one obstacle list. NavigationServer2D bakes those obstacles plus the van
with a seven-pixel clearance radius, preserving cabin door access. This deliberate
placeholder approach postpones TileMapLayer and tile assets until mechanics work.

ForestLevel is the offline authority: pickup proximity/availability/raycast checks,
inventory awards, deliveries, revive holds, extraction, and results. HUD only
emits lifecycle requests. CampVan validates deliveries and start holds; CampPlayer
owns movement/stamina and status. CampKiller runs the explicit PATROL →
INVESTIGATE/CHASE → SEARCH → PATROL state machine. It records visible targets with
decay and only pursues current positions while raycast sight is valid. Hearing
records the emitted location; lost targets do not update hidden positions.

Defaults live in CampConfig: walking 70 px/s, sprint 110 px/s, four stamina seconds,
two-second van start, five-second departure, three-second revive, two-second attack
cooldown/revive grace, sixteen-second bleed-out. First hit downs; second eliminates.
At departure, living survivors within 45 pixels of the rear interaction point
escape; others are left behind. At least one escape wins. If all are dead, the
round loses. Solo downing waits for the second hit or bleed-out; no self-revive.

F toggles the visual flashlight, Tab shows inventory, and Esc freezes actor physics
and round timers. The shader keeps distant terrain dimly readable. Footstep hints
and the killer's !/? indicators are visual telegraphs; audio is not added yet.
Pickup and patrol placements stay fixed for M1; randomization belongs to M5.

M2 adds GameManager and NetworkManager when session/ENet behavior exists, moving
the current authority path to the host and replacing direct input with intents.
Clients send input/intents; the host owns positions, inventory, AI, health, repair,
extraction, and phase changes. Initial late-join policy: lobby only. Direct IP/LAN
or virtual LAN; no relay, NAT traversal, or host migration is promised.
