# Architecture and conventions

`AGENT_BRIEF.md` is the authoritative specification. The adjacent Word document
is a supplied reference. M0 contains only the boot/menu, controls guide, and
verification tools. No gameplay, network session, or export is implemented yet.

Validated engine: **4.7.2.stable.official.ed1daf0bf**, macOS arm64. Use this version
to reproduce results. Compatibility renderer, 384×216 base viewport, integer
viewport stretch, nearest texture filtering, and a 1152×648 initial window.
The built-in Godot font is temporary; scenery uses original GDScript geometry.
No external assets, plugins, or package dependencies are required.

## Layout

- `scenes/ui`, `scripts/ui`: opening menu and purely visual forest backdrop.
- `scenes/world`, `scenes/actors`, `scenes/items`: reserved for M1 composition.
- `scripts/core`, `scripts/actors`, `scripts/items`, `scripts/ai`: reserved for M1.
- `scripts/network`: reserved for M2 ENet and authority boundaries.
- `assets/tiles`, `assets/sprites`, `assets/audio`: reserved for original content.
- `tests/integration`: engine-driven scene/input smoke test.
- `tests/unit`: reserved for meaningful mechanic tests as mechanics arrive.
- `tools`: Python standard-library launch and verification scripts.
- `docs`: architecture, testing, milestone plan, and development log.
- `artifacts/verification`: ignored, reproducible logs, JSON, and screenshots.

The backdrop is deliberately decorative; it is not a navigable forest map.
Controls show future gameplay bindings and explicitly say they are planned.
Play is disabled until M1 has a local round to launch. Host/join arrive in M2.
Autoloads and configuration Resources will be introduced when used, rather than
creating nonfunctional placeholders now.

## Implementation direction

M1 uses native `CharacterBody2D`, static world collision, and navigation. Gameplay
rules will live in a shared configuration Resource. World-changing actions should
flow through a single authority path that works offline first, then runs only on
the listen server in M2. Do not let UI directly award items or set health/outcomes.
The menu remains the boot scene throughout development.

M2 adds GameManager and NetworkManager when lifecycle/ENet behavior exists.
Clients send input/intents; the host owns positions, inventory, AI, health, repair,
extraction, and phase changes. Initial late-join policy: lobby only. Direct IP/LAN
or virtual LAN; no relay, NAT traversal, or host migration is promised.
