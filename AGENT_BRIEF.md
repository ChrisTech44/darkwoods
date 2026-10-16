# LAST NIGHT AT CAMP
**Godot 4 multiplayer horror game — agent implementation brief**

Version 1.10 — 16 October 2026 — Codex Sol (medium effort)

User amendment: online proximity voice chat and an original/licensed audio-file
pipeline are planned after synchronized multiplayer gameplay. This supersedes
the original voice-chat exclusion. See [audio/multiplayer design](docs/audio_multiplayer_design.md).
16 October priority amendment: correct visual/map defects, increase seeded camp
layout variety, and implement the user-supplied audio files **before** online
multiplayer and proximity voice. Offline audio has its own local checks; the
networked M2-A and M3-V acceptance gates still require future execution evidence.
Current gameplay supports offline solo and ENet host/join co-op. Two/four independent
local processes are verified in both modes; real cross-machine Internet acceptance,
synchronized-audio listening and voice capture remain pending. Markdown is the
sole maintained specification; the Word brief was removed at the user's request.

16 October menu/defaults amendment: both modes start fresh random camps by
default; fixed seeds and same-seed retries are explicit choices. Menu music and
saved pre-game mix controls are required. Solid woods tree borders must block
flashlight spill into adjacent paths.

16 October forest-surround amendment: hide terrain and creatures outside current
line of sight in the woods; creature calls start nearby and fade by proximity.
Keep title-screen mixer controls behind Settings. Enlarge the finite forest
to 9,600×9,408 around all sides of a central camp, with wider, clean connections
to enlarged village/bog/graveyard regions and monsters around the camp.

16 October survivor/content planning amendment: plan a player selection screen
and six camp-personality archetypes with meaningful escape advantages before
transitioning into authoritative multiplayer, synchronized audio and optional
voice. Expand the design backlog with 48 additional monster concepts and 18
detailed biomes (three existing-region expansions plus 15 new regions).
These are plans, not implemented features or a requirement to ship the whole
catalog before co-op. See [survivor/co-op plan](docs/survivor_multiplayer_plan.md),
[monster catalog](docs/monster_catalog.md) and [biome design](docs/biome_design.md).

16 October content implementation amendment: the user explicitly prioritizes a
large offline survivor/biome/monster update **before online multiplayer**, replacing
the earlier post-M2 content ordering. Six survivor choices/bonuses, a six-slot
supply-type belt (1–6/keypad, V use, G drop), three rare consumables, six optional
landmark biomes and seven additional cryptid species now have offline implementations.
Required parts and reusable cutters remain separate from the belt. The nine major
regions retain the existing required-cache recipe; no new region is mandatory.
The population stays at 24 cryptids plus the camp stalker. New landmark powers are
bounded first versions, not full catalog dossiers. See [content update](docs/content_update.md)
for implemented rules, screenshots and remaining acceptance limits. Human balance,
all-role full input rounds, networking, synchronized audio and voice remain unverified.

Latest user amendment: fix selected survivors rendering as white blocks; remove
trailing belt counts; add roaming monsters and more frequent encounters; then
implement ENet host/join multiplayer for LAN/Wi-Fi and direct-IP or virtual-LAN
Internet play. Voice chat is the next feature and must remain a separate gated
opt-in system. The offline encounter update uses 48 cryptids across 16 species,
including Relay Jackal, Ration Moth and Lens Eater away from landmark biomes.
Required online cross-machine acceptance still needs execution evidence.

Network implementation amendment: the current build has a 1–4 peer listen-host
lobby, authoritative actor/input/item/AI/van state, compressed replica snapshots,
shared results/retry, late-join refusal and host-loss cleanup in both modes.
Default UDP port is 27840. Internet requires reachable UDP routing or a virtual
LAN, without matchmaking/relay/automatic NAT traversal. Local Esc menus do not
pause the shared world. Carried objectives drop on death/disconnect. See the
[multiplayer guide](docs/multiplayer_guide.md) and execution evidence for limits.
Voice is next: stable peer/round IDs, host-owned positions/status and separated
input/world channels are provided; no microphone or voice transport is active.
Human M1-S, real two-machine M2/Internet and M2-A/M3-V gates are not implied by
loopback processes or scripted graphical windows.

Latest rescue/lighting amendment (supersedes earlier death/revive rules): players
never permanently die. Hits down them indefinitely; a teammate must spend a
medkit to revive (3s, or 2.25s as First-Aid Kid). On down/disconnect all parts,
tools and supply units drop once on reachable ground beside the body. All-down
ends the round in defeat. Any successful van passenger escape also rescues
connected downed teammates. Living survivors must still board. Center name
labels by measured text width. Render every actor's authoritative flashlight/
glow and temporary flare lights on every peer, preserving wall/sight occlusion.

Latest AI/feedback amendment: downed survivors are not attack/chase targets.
Enemies must retarget standing survivors or search/patrol, with stalled-path
recovery. The stalker sweeps central camp early before its seeded perimeter
route. Ordinary interaction/supply feedback belongs to the acting player's HUD;
shared down/revive/escape events remain team-wide. Alternating successful revives
and subsequent downs must not end a round while someone is still alive/aboard.
A player without a medkit can collect nearby drops beside a downed teammate.

**Latest fun/heart-pounding amendment (16 October; planning, not implemented):**
the user wants the game more fun, dynamic and tense, and found searching puzzling,
tedious and low on replay value. The user is explicitly open to better map
designs, new regions and new cross-map requirements. The
[gameplay overhaul plan](docs/fun_overhaul.md) is now the authoritative design
direction and its F1–F3 slices precede proximity voice. When each slice ships, it
supersedes these older rules: one-hit downs (→ Wounded then Downed), medkit-only
revives (→ 6s kitless revive, medkit 3s, one solo self-recovery), "monsters cannot
destroy required components" (→ the stalker may *displace*, never destroy, one
part, always marked), fixed village/bog/graveyard objective regions and the single
van escape (→ rotating regions, clue chains and alternate cross-map escapes),
the uniform maze (→ hub, ring road, spokes, thickets and shortcuts within the same
world budget), a single boltcutters pair, and flat threat (→ night phases, dread
and a bounded director). Until then, the current rules describe the build.
F1 navigation aids are implemented (signposts, skyline markers, wall-map regions,
M-key team pins, a woods boltcutters pair and a loud crowbar; rules `lnac-net-4`).
Clue chains moved to F4 alongside rotating objective regions.

> Goal: build an original, playable, 1–4 player co-op slasher game. This is a specification, not proof of implementation.

## Mission & non-negotiables

- Build an original, playable, top-down 2D cooperative woods/slasher survival-horror game in Godot 4.x. Visual direction: Game Boy Advance-era pixel-art scale and readability, with a dark forest, cabins, and localized lighting. All characters, names, sprites, sounds, and maps must be original or licensed for redistribution.

- Four friends must be able to play the same build together from different desktop operating systems (Windows, macOS, Linux). Co-op is 1–4 human survivors versus one AI-controlled killer. Do not implement player-controlled killer in the MVP.

- The first deliverable is a working vertical slice, not a full game: 1 small woodland map, 1 killer, 1 escape objective, 2–4 connected clients, and a complete short round (lobby → play → win/lose → restart). Favor working mechanics over polished content.

## Player experience & replayability

- Fantasy: friends arrive at an isolated campsite at night; a slasher stalks them as they search for supplies, repair a getaway vehicle, and escape together. Intended tone: tense and scary but allows emergent comedic mishaps. Target rounds for eventual game: 15–25 minutes; the MVP may be shorter.

- Core loop: choose survivor offline or host/join a lobby with survivor selection → confirm/ready → spawn at campsite → investigate cabins and wooded trails → collect randomized objective items → avoid/disrupt killer → repair and start escape vehicle → surviving players extract → show outcome screen → replay.

- Fun pillars (see the [overhaul plan](docs/fun_overhaul.md)): every minute holds a decision; pressure rises through Dusk → Nightfall → Deep Night → Witching Hour; friends need each other; every night tells a different story; fear is earned and fair. Track the plan's pacing metrics in human playtests (≤ 45s with nothing new, a close-call-to-down ratio of at least 3:1, a named-region clue within 3 min).

- Planned dynamic systems (overhaul F-track): clue chains and skyline navigation; hiding spots, doors, vaults and a Wounded state; dread-driven night phases, events and escape hold-out finales; a ring-and-spoke map with unlockable shortcuts; rotating objective regions and alternate escapes (van, radio rescue, boat, ranger gate, signal fire) whose steps span the map; role active abilities, heavy two-person carries and ghost wisps; headline killer rotation, night modifiers, scores, journal and unlocks.

- Replayability systems (introduce after core loop): randomized objective item placements; several possible cabin locks and blocked paths; alternate extraction methods; risk/reward optional loot; killer patrol variations and memory of recent sound/sightings. Do not make "infinite procedural maps" the MVP. Both modes default to fresh random camps; only explicit seed entry/retry repeats a recipe. Keep loot, doors and the chart aligned with seeded building placements. The latest approved forest expansion surrounds a central camp with a finite 9,600×9,408 woods, 2,410 forest clearings, four exits, 128px trails, spacious themed regions, clean approach transitions and 24 roaming cryptids in expedition mode.

## MVP gameplay rules

- Movement: top-down 8-direction walking, sprinting with stamina, tile/world collision, visible facing direction, interact key, minimal animation using placeholder sprites.

- Vision: nighttime map, character-centered limited visibility or darkness overlay; flashlight toggled by player; build a readable prototype first. Do not let cosmetic darkness prevent testing. Solid woods tree borders must block flashlight spill into adjacent paths, including when a head-height emitter would otherwise cross a nearby border. An opaque line-of-sight mask must hide occluded trails/creatures even when ambient or other lights illuminate them.

- Items: pickups for three distinct vehicle repair components (for example battery, fuel, key); inventory is server-controlled, with simple UI; item pickup requires server validation of proximity and availability.

- Objectives: place three items in the vehicle at an interaction point, then hold/interact to start it; configurable extraction countdown; round win if at least one living survivor extracts, with per-player escape/death result. Define and display clear victory/failure conditions.

- Killer: autonomous AI with patrol, investigate noise, chase on valid line of sight, search last known location, and disengage to patrol. Killer catches/injures players; simple MVP: one hit downs and a second hit eliminates, with a timed teammate revive interaction. Exact values should be config constants.

- Tension: sprinting, interaction failures, or dropped objects may emit noise events. AI responds to recent sounds but does not automatically know all player locations. Give players telegraphing (footstep audio cue, visible alert animation, or debug indicators).

## Survivor selection and expanded content — implementation targets

- Add M1-S before M2: a dedicated offline survivor selection screen with six readable cards, original preview art, exact advantages, keyboard/mouse navigation, Back/Start and saved choice. Keep menu music and Settings available. Random Night remains on by default; Random Survivor is a separate explicit choice. Retry preserves role; another night offers selection again.

- Use six original camp/slasher personality archetypes independent of appearance or identity. All survivors can collect every part, use tools, revive and start/board the van. Duplicate roles are allowed; every role must remain solo-viable and no team composition is mandatory. Numbers below are proposed tuning defaults, not current stats.

- The Jock (`jock`): stamina capacity 5s instead of 4s; unchanged movement speed and stamina recovery. The Grease Monkey (`mechanic`): engine-start hold 1.5s instead of 2s and one extra spare battery; parts still deliver instantly and departure remains 8s.

- The Scout (`scout`): expedition flashlight drain 0.8 charge/s instead of 1, unchanged 90-charge capacity/+70 recharge/sight, and one extra ration. The First-Aid Kid (`medic`): ordinary teammate revive 2.25s instead of 3s, one starting medkit and one extra flare; medkit revive remains 1.2s, no self-revive.

- The Quiet Kid (`quiet`): personal sprint AI-noise reach ×0.75 after weather, without changing sight, actual playback, microphone gain or environmental noise. The Overprepared One (`quartermaster`): one extra flare, one extra spare battery and one extra ration. Bonuses apply once at fresh round spawn, never on ready toggles, revive or reconnect.

- Role data uses allowlisted stable IDs and private effective per-player configuration; never mutate the shared baseline. The future host validates choices, derives bonuses and locks choices/seed/rules at start. Lobby changes clear ready, initial late join is lobby-only, and disconnect cannot refresh supplies. One host-owned actor advances a revive/ignition hold; changing actor resets progress.

- Expand the planning pool by 48 distinct monster concepts, each with a trigger, nearby visual/audio tell, counterplay, habitat and bounded authority/lifecycle rules. Together with the seven current enemy designs this is a 55-design catalog, not a simultaneous spawn count. No microphone recordings or forged player voices for mimic monsters; no hidden omniscient targeting or unavoidable route locks.

- Plan 18 detailed biome designs: expanded graveyard/village/bog plus 15 new modular regions within the existing massive maze. Each major region reserves collision/navigation/shadow/sight geometry and at least two distinct entrances, an internal loop, clear aprons, optional risk/reward, seeded safe variants and one-time rewards. Keep current objective regions/recipe initially; new deep landmarks remain optional.

- Introduce content one verified slice at a time: Flooded Mill/Boiler Saint, Orchard/Bramble Seamstress, Observatory/Shutter Wraith, then Rail Yard/Last-Car Conductor. Prototype after M1-S and a recorded human baseline; integrate after M2/M2-A stabilize. The remaining catalog is a backlog, not a prerequisite for voice or first distribution.

## Godot implementation & project layout

- Use stable Godot 4.x, GDScript, and Godot native 2D physics/navigation. Prefer TileMapLayer for 4.x versions that support it, scene composition, signals, and Resources for configuration. Avoid unnecessary plugins/dependencies.

- Suggested autoloads: GameManager (round state and session lifecycle), NetworkManager (ENet peer setup and RPC boundaries), AudioManager (optional). Scenes: MainMenu, Lobby, ForestLevel, Player, Killer, Pickup, EscapeVan, HUD, ResultsScreen. Scripts should be focused and small.

- Example tree: project.godot; scenes/{ui,world,actors,items}; scripts/{core,network,actors,items,ai}; assets/{tiles,sprites,audio}; tests/{unit,integration}; tools/{run_server,run_clients}; docs/{architecture,testing,development_log}. Choose consistent names and document any deviations.

- Use placeholder sprites and basic geometric tiles until the mechanics pass. Pixel art should use integer scaling, nearest-neighbor filtering, and a deliberate base viewport (e.g., 320×180 or 384×216) with suitable stretch settings.

## Multiplayer protocol & trust boundaries

- Use Godot high-level ENet multiplayer with a listen-server host in MVP. One host runs server authority and also plays; 1–3 remote clients join by host IP/port. A LAN or virtual LAN (for example Tailscale) is acceptable for early external tests. Later online acceptance requires two separate machines across networks, using documented direct-IP/port-forwarding or virtual-LAN setup. Automatic NAT traversal, managed relay services, Steam integration and matchmaking remain out of scope; proximity voice chat is planned after core network gameplay passes.

- Authoritative host owns round lifecycle, killer AI, player health/downed/death status, item availability, repair progress, escape outcome, random seed, and authoritative positions. Clients send input/intents (move, sprint, interact, use flashlight); server validates and applies world-changing actions.

- Use stable peer IDs for ownership and reconnect/disconnect handling. Spawn a player for every connected peer; joining players must see the same existing state. Ensure no duplicated items or conflicting interaction results from simultaneous pickup requests.

- Provide movement synchronization with an intentionally simple first pass; interpolation is desirable for remote entities. Avoid allowing clients to choose item rewards, damage, teleport locations, or objective completion. Separate server-only logic from visuals so a headless host is feasible.

- If host disconnects, terminate the session gracefully with an explanatory UI message (no host migration for MVP). Ensure disconnected players are removed, and round reset does not leak orphan nodes/RPCs.

## Audio files and planned proximity voice

- Implement local AudioManager playback now, ahead of M2 per the priority amendment, with separate master, effects, ambience/music and voice volume controls. Use original or redistributable files with documented source/license and stable cue IDs; track asset provenance in `assets/audio`. Never claim audio exists while only visual/noise-event cues are implemented. Play ominous music and subdued woods ambience on the menu, with saved Master/Effects/Ambience/Music controls available before Play through Settings. Monster calls must be proximity-gated and attenuate with distance, following moving sources.
- Prioritize footsteps, monster approach/attack cues, witch wind-up/bolt/hex, interaction/cache/cutters, flare/flashlight, revive/damage, van start/departure, village bell and environmental loops. Keep visual cues available; muted or unavailable audio must not prevent play.
- Synchronize world sounds from authoritative gameplay events with event IDs, source positions and variant seeds. Avoid duplicate host/local playback and reject client requests to invent trusted monster, objective or damage cues. Hearing for AI remains a host gameplay decision independent of local mixer volume.
- After M2 and the M2-A audio foundation, add online proximity voice in M3-V: opt-in microphone enablement, push-to-talk by default, device/permission feedback, mic/output gain, per-peer mute/volume and a speaking indicator. Never capture on boot, offline, or after leaving a session; microphone failure must not block joining or playing.
- In active rounds, attenuate nearby survivor voices by distance and apply simple wall muffling; lobby/results use session-wide chat. Dead/escaped/left-behind players use a separate spectator voice group so they cannot relay unrestricted information to living survivors. No audio recording or microphone payloads in logs.
- Host-approved peer identity, position and round state determine voice recipients. Use bounded, compressed low-latency frames on a path isolated from reliable gameplay traffic; drop stale frames rather than building a backlog. Choose/verify the codec, transport, dependency licenses and Internet encryption design in an implementation spike before making performance/platform claims.
- Voice does not attract AI by default. Any later speech-to-game-noise option needs separate balance work and host validation. Clear capture/playback buffers on disconnect, restart and host loss. Test proximity boundaries, occlusion, mute/PTT, denial/no-device behavior, spectator isolation, jitter/load and cross-machine audio.
- Implementation order: visual/map fixes and seeded camp variety → offline audio cues/assets → M1-S survivor selection/bonuses and recorded human baseline → M2 gameplay with role authority and M2-A synchronized audio → M3 reliability → overhaul F1–F3 → M3-V proximity voice (may run in parallel after F3) → F4–F8 → M4 packaged audio/permissions. New biome/monster slices follow stable foundations; online acceptance gates remain future work.

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

- M1-S – Survivor selection: offline selection UI, six personal archetype bonuses, private effective stats, accurate HUD and clean lifecycle. Gate: all-role/both-mode input rounds and modifier boundaries, no bonus duplication/cross-player contamination, graphical UI checks and recorded normal-speed human balance/escape evidence. Teammate fixtures do not prove co-op.

- M2 – Networked slice: host/join lobby with authoritative role selection/ready lock, 2 local clients, synchronized positions, item pickups, killer, objective progress, death and extraction. Start with Quick Camp; verify existing expedition mechanics before claiming Woods co-op. Gate: deterministic automated two-client test plus manual two-window smoke test, including role validation and contested interactions. Do not substitute local split screen.

- M2-A – Synchronized audio foundation (after M2; local playback first): original/licensed audio files, AudioManager/buses, positional cues and synchronized world sound events. Gate: two real clients hear one appropriate cue per accepted event, controls/loops/cleanup work, and audio failure leaves gameplay usable.

- M3 – Reliability: up to 4 players, concurrent interactions, disconnect paths, late join policy (either support or explicitly disallow once round begins), synchronized restart, latency simulation where practical. Gate: no known state divergence in specified scenarios.

- M3-V – Online proximity voice (after M2-A and M3 reliability): opt-in push-to-talk, distance/occlusion, mute/device settings, spectator separation and bounded transport. Gate: two separate machines complete a round with working voice, followed by four-peer/jitter/disconnect checks; denied microphone access does not block gameplay. Record the actual direct-IP/virtual-LAN connection method. Archetypes grant no global voice or extra microphone hearing.

- M4 – Distribution: exported packages for available desktop targets and clear launch instructions, including audio files, codec dependencies and microphone permission behavior once voice is implemented. Gate: packaged audio/voice and builds checked on available platforms; untested target platforms labeled unverified.

- F1–F8 – Fun overhaul track (see [overhaul plan](docs/fun_overhaul.md)): navigation/clues → night phases/director → chase toolkit → ring-and-spoke map → alternate escapes/new regions → roles 2.0/co-op actions → killers/modifiers → meta-progression. F1–F3 come before M3-V voice; each slice needs solo and two-peer co-op verification, graphical evidence and a recorded human pacing playtest before the next. Gate per slice: the plan's fairness/authority rules hold and the targeted pacing metric improves on the recorded baseline.

- M5 – Replayability/polish: the survivor/monster/biome planning backlog is approved for design, with one-at-a-time implementation gates. Further objective rotations, extraction modes, tools, balance, sprite sheets and lighting follow verified slices. Baseline audio cues and voice retain their own M2-A/M3-V gates; a content brainstorm is not execution evidence.

## Testing, verification & evidence

- After every change: run Godot CLI --headless --path . --import and a headless startup/syntax check, and run any applicable tests. Export only after a milestone passes. Treat warnings and errors separately; log relevant results.

- Provide scripts that launch host and multiple clients with known flags/ports and machine-readable logs. Where rendering must be verified, use an actual graphical session and capture screenshots; headless success does not prove visual quality.

- Automate assertions for: 2 clients join; no duplicate spawns; player A movement visible to player B; simultaneous same-item pickup awards once; enemy health/player downed state shared; vehicle parts and extraction consistent; restart returns all peers to identical phase; disconnect cleaned up.

- Include honest evidence in docs/development_log.md: command run, exit status, tests passed/failed, screenshots or logs available, and platform not verified. Never assert builds or multiplayer work without execution evidence.

## Agent operating rules (Sol, medium effort)

- Work in small, independently verifiable increments. Before each coding pass, select one milestone and list the smallest tasks required. Implement and test one coherent piece, then summarize changes, commands run, and next blockers.

- Do not ask for design decisions unless genuinely blocking: resolve details with pragmatic defaults in a config file and document them. Avoid rewriting architecture unnecessarily. Prefer simple implementations that can be upgraded safely.

- Use git commits at verified milestone boundaries. Do not delete unrelated files or use destructive shell commands without approval. Avoid installing unvetted community assets/plugins. Do not use copyrighted Pokémon assets, franchise names, or recognizable R.E.P.O. content in the released game.

- Keep GitHub current after every coherent, verified increment: update the development log and relevant README content, commit the intended changes, push the current branch to `origin`, and confirm the remote commit before finishing. Follow `AGENTS.md` for this user-authorized ongoing publishing workflow; never force-push or publish credentials/unverified changes.

- When a command cannot run due to environment limitations, state exactly what was not tested and provide a reproducible command for a human. Never fabricate screenshots, logs, passed tests, or binary artifacts.

- First task: inspect system and repository, determine Godot version/CLI path, create project structure and minimal Godot opening screen, run import/startup checks, then begin M1. Do not attempt every milestone in a single Codex turn.

## Initial agent instruction (paste into Codex)

- You are building an original 1–4 player cooperative, top-down, pixel-art woods/slasher survival-horror game in Godot 4.x. Treat this document as the project requirements. Your runtime is Sol at medium reasoning effort, so favor small validated increments over large speculative changes. Begin with milestone M0 only: inspect the environment, scaffold a clean Godot project, create a working boot/menu scene, define InputMap actions, set up folders/docs/test scripts, run available headless Godot checks, and report exactly what was tested. After M0, plan M1 as a set of short tasks. Use original or permissively licensed placeholder assets. Do not claim multiplayer or cross-platform builds work until verified. Keep the project runnable and maintain a development log.
