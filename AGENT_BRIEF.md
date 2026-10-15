# LAST NIGHT AT CAMP
**Godot 4 multiplayer horror game — agent implementation brief**

Version 1.0 — 15 October 2026 — Codex Sol (medium effort)

> Goal: build an original, playable, 1–4 player co-op slasher game. This is a specification, not proof of implementation.

## Mission & non-negotiables

- Build an original, playable, top-down 2D cooperative woods/slasher survival-horror game in Godot 4.x. Visual direction: Game Boy Advance-era pixel-art scale and readability, with a dark forest, cabins, and localized lighting. All characters, names, sprites, sounds, and maps must be original or licensed for redistribution.

- Four friends must be able to play the same build together from different desktop operating systems (Windows, macOS, Linux). Co-op is 1–4 human survivors versus one AI-controlled killer. Do not implement player-controlled killer in the MVP.

- The first deliverable is a working vertical slice, not a full game: 1 small woodland map, 1 killer, 1 escape objective, 2–4 connected clients, and a complete short round (lobby → play → win/lose → restart). Favor working mechanics over polished content.

## Player experience & replayability

- Fantasy: friends arrive at an isolated campsite at night; a slasher stalks them as they search for supplies, repair a getaway vehicle, and escape together. Intended tone: tense and scary but allows emergent comedic mishaps. Target rounds for eventual game: 15–25 minutes; the MVP may be shorter.

- Core loop: host/join lobby → spawn at campsite → investigate cabins and wooded trails → collect randomized objective items → avoid/disrupt killer → repair and start escape vehicle → surviving players extract → show outcome screen → replay.

- Replayability systems (introduce after core loop): randomized objective item placements; several possible cabin locks and blocked paths; alternate extraction methods; risk/reward optional loot; killer patrol variations and memory of recent sound/sightings. Do not make "infinite procedural maps" the MVP.

## MVP gameplay rules

- Movement: top-down 8-direction walking, sprinting with stamina, tile/world collision, visible facing direction, interact key, minimal animation using placeholder sprites.

- Vision: nighttime map, character-centered limited visibility or darkness overlay; flashlight toggled by player; build a readable prototype first. Do not let cosmetic darkness prevent testing.

- Items: pickups for three distinct vehicle repair components (for example battery, fuel, key); inventory is server-controlled, with simple UI; item pickup requires server validation of proximity and availability.

- Objectives: place three items in the vehicle at an interaction point, then hold/interact to start it; configurable extraction countdown; round win if at least one living survivor extracts, with per-player escape/death result. Define and display clear victory/failure conditions.

- Killer: autonomous AI with patrol, investigate noise, chase on valid line of sight, search last known location, and disengage to patrol. Killer catches/injures players; simple MVP: one hit downs and a second hit eliminates, with a timed teammate revive interaction. Exact values should be config constants.

- Tension: sprinting, interaction failures, or dropped objects may emit noise events. AI responds to recent sounds but does not automatically know all player locations. Give players telegraphing (footstep audio cue, visible alert animation, or debug indicators).

## Godot implementation & project layout

- Use stable Godot 4.x, GDScript, and Godot native 2D physics/navigation. Prefer TileMapLayer for 4.x versions that support it, scene composition, signals, and Resources for configuration. Avoid unnecessary plugins/dependencies.

- Suggested autoloads: GameManager (round state and session lifecycle), NetworkManager (ENet peer setup and RPC boundaries), AudioManager (optional). Scenes: MainMenu, Lobby, ForestLevel, Player, Killer, Pickup, EscapeVan, HUD, ResultsScreen. Scripts should be focused and small.

- Example tree: project.godot; scenes/{ui,world,actors,items}; scripts/{core,network,actors,items,ai}; assets/{tiles,sprites,audio}; tests/{unit,integration}; tools/{run_server,run_clients}; docs/{architecture,testing,development_log}. Choose consistent names and document any deviations.

- Use placeholder sprites and basic geometric tiles until the mechanics pass. Pixel art should use integer scaling, nearest-neighbor filtering, and a deliberate base viewport (e.g., 320×180 or 384×216) with suitable stretch settings.

## Multiplayer protocol & trust boundaries

- Use Godot high-level ENet multiplayer with a listen-server host in MVP. One host runs server authority and also plays; 1–3 remote clients join by host IP/port. A LAN or virtual LAN (for example Tailscale) is acceptable for early external tests. NAT traversal, relays, Steam integration, matchmaking, and voice chat are out of scope.

- Authoritative host owns round lifecycle, killer AI, player health/downed/death status, item availability, repair progress, escape outcome, random seed, and authoritative positions. Clients send input/intents (move, sprint, interact, use flashlight); server validates and applies world-changing actions.

- Use stable peer IDs for ownership and reconnect/disconnect handling. Spawn a player for every connected peer; joining players must see the same existing state. Ensure no duplicated items or conflicting interaction results from simultaneous pickup requests.

- Provide movement synchronization with an intentionally simple first pass; interpolation is desirable for remote entities. Avoid allowing clients to choose item rewards, damage, teleport locations, or objective completion. Separate server-only logic from visuals so a headless host is feasible.

- If host disconnects, terminate the session gracefully with an explanatory UI message (no host migration for MVP). Ensure disconnected players are removed, and round reset does not leak orphan nodes/RPCs.

## Killer AI contract

- States: PATROL → INVESTIGATE → CHASE → SEARCH → PATROL; optional ATTACK/DOWNED interaction as needed. Use a finite state machine with explicit transitions, cooldowns, line-of-sight ray checks, hearing event inputs, and navigation.

- AI tracks the most recent sensed location per target with decay. It should not query unsensed exact positions to decide patrol/search destination. Pursuit may use current player position only while target is actually visible. Implement target-loss and stuck recovery.

- Server runs AI decisions and broadcasts the killer state and transform; clients render cues and animations. Start with one killer and a small map; test against 1, 2, and 4 player counts.

## Cross-platform builds & controls

- Target desktop Windows x86-64, Linux x86-64, and macOS Universal or separate Apple Silicon/Intel artifacts as supported by installed export templates. Use GDScript and built-in APIs to minimize platform-specific code. Export builds should not require users to install Godot.

- Define actions in InputMap: move_up/down/left/right, sprint, interact, flashlight, inventory, pause. Keyboard first, rebindable controls later. Document macOS Gatekeeper and Windows SmartScreen warnings for unsigned builds; do not claim signed/notarized releases.

- Implement explicit host and join controls with address/port, player count, ready state or host start, and informative connection-failure errors. Do not promise seamless internet connection over direct IP without port forwarding, VPN, or relay.

## Milestones and acceptance gates

- M0 – Toolchain: create repo and Godot project; confirm Godot CLI works; document engine version; run headless import and quit. Gate: reproducible setup instructions and zero parse errors.

- M1 – Offline vertical slice: controllable player, forest collisions, pickup and interact mechanics, vehicle repair/escape, killer patrol/chase/search, down/revive/death and round restart. Gate: a human can complete or lose one entire round locally.

- M2 – Networked slice: host/join lobby, 2 local clients, synchronized positions, item pickups, killer, objective progress, death and extraction. Gate: deterministic automated two-client test plus manual two-window smoke test. Do not substitute local split screen.

- M3 – Reliability: up to 4 players, concurrent interactions, disconnect paths, late join policy (either support or explicitly disallow once round begins), synchronized restart, latency simulation where practical. Gate: no known state divergence in specified scenarios.

- M4 – Distribution: exported packages for available desktop targets and clear launch instructions. Gate: build artifacts checked and tested on any available platform; untested target platforms labeled unverified.

- M5 – Replayability/polish (after approval): objective location pools, randomized patrol route seeds, sound cues, additional tools, balance, improved sprite sheets and lighting.

## Testing, verification & evidence

- After every change: run Godot CLI --headless --path . --import and a headless startup/syntax check, and run any applicable tests. Export only after a milestone passes. Treat warnings and errors separately; log relevant results.

- Provide scripts that launch host and multiple clients with known flags/ports and machine-readable logs. Where rendering must be verified, use an actual graphical session and capture screenshots; headless success does not prove visual quality.

- Automate assertions for: 2 clients join; no duplicate spawns; player A movement visible to player B; simultaneous same-item pickup awards once; enemy health/player downed state shared; vehicle parts and extraction consistent; restart returns all peers to identical phase; disconnect cleaned up.

- Include honest evidence in docs/development_log.md: command run, exit status, tests passed/failed, screenshots or logs available, and platform not verified. Never assert builds or multiplayer work without execution evidence.

## Agent operating rules (Sol, medium effort)

- Work in small, independently verifiable increments. Before each coding pass, select one milestone and list the smallest tasks required. Implement and test one coherent piece, then summarize changes, commands run, and next blockers.

- Do not ask for design decisions unless genuinely blocking: resolve details with pragmatic defaults in a config file and document them. Avoid rewriting architecture unnecessarily. Prefer simple implementations that can be upgraded safely.

- Use git commits at verified milestone boundaries. Do not delete unrelated files or use destructive shell commands without approval. Avoid installing unvetted community assets/plugins. Do not use copyrighted Pokémon assets, franchise names, or recognizable R.E.P.O. content in the released game.

- When a command cannot run due to environment limitations, state exactly what was not tested and provide a reproducible command for a human. Never fabricate screenshots, logs, passed tests, or binary artifacts.

- First task: inspect system and repository, determine Godot version/CLI path, create project structure and minimal Godot opening screen, run import/startup checks, then begin M1. Do not attempt every milestone in a single Codex turn.

## Initial agent instruction (paste into Codex)

- You are building an original 1–4 player cooperative, top-down, pixel-art woods/slasher survival-horror game in Godot 4.x. Treat this document as the project requirements. Your runtime is Sol at medium reasoning effort, so favor small validated increments over large speculative changes. Begin with milestone M0 only: inspect the environment, scaffold a clean Godot project, create a working boot/menu scene, define InputMap actions, set up folders/docs/test scripts, run available headless Godot checks, and report exactly what was tested. After M0, plan M1 as a set of short tasks. Use original or permissively licensed placeholder assets. Do not claim multiplayer or cross-platform builds work until verified. Keep the project runnable and maintain a development log.
