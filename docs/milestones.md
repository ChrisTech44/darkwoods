# Incremental implementation plan

M0 passed and was committed as `ef180d0`. At the user's instruction, the next pass
implements M1. All five steps below are implemented and covered by automated
engine checks. Full input-driven win/loss/restart runs pass headlessly and in a
real graphical session. A human playtest at normal speed remains unrecorded;
do not describe that manual gate as executed. Multiplayer remains M2.

User-requested follow-up: boarding is now explicit and protects seated survivors,
and an authorized visual/map pass expands the camp to 1536×960 with ten furnished
buildings, original character/environment pixel art, shadow-casting lights and a
field map. The user's subsequent request explicitly authorizes woods,
replayability and UI polish ahead of M2: a seeded finite trail maze, five-part
repair/cache objectives, tools/supplies, weather and six original cryptid types
(four per expedition), interactive village/bog/graveyard sites and richer sensing,
search, patrol and projectile behavior. Quick Camp retains M1's three-part acceptance route.
This work does not implement or claim M2 networking.

## M1: offline vertical slice, one verified pass per step

1. **Walking in camp.** Wire Play to a small ForestLevel, original placeholder
   Player, eight-direction movement, facing, sprint/stamina, camera, and solid
   forest/cabin boundaries. Add a configuration Resource for speeds/stamina.
   Gate: manual traversal, diagonal normalization, blocked-wall and stamina checks;
   return to menu works. Keep the scene readable before introducing darkness.
2. **Supplies and van.** Three distinct components, proximity-validated pickup,
   inventory HUD, single-award interaction, component delivery, hold to start,
   configurable countdown, extraction, results, and restart. Gate: complete a
   local escape; distant/duplicate pickup and repeated delivery rejected.
3. **Stalker senses.** One killer with PATROL/INVESTIGATE/CHASE/SEARCH, raycast
   sight, recent noise, navigation, target-loss decay, and stuck recovery.
   Gate: walls occlude sight; sounds trigger investigation; lost targets are
   searched at last sensed positions instead of tracked through walls.
4. **Consequences and round lifecycle.** Down/second-hit elimination, attack
   cooldown, timed revive interaction, defeat when no player can continue,
   per-player outcome, and clean replay. Gate: one complete local win and loss;
   revive verified with a controlled fixture until multiple humans exist in M2.
5. **Visibility and acceptance.** Flashlight, readable night overlay, telegraphs,
   controls/pause/inventory, full local round regression and graphical evidence.
   Gate: a human completes or loses an entire round and restarts successfully.

For each step, record commands, results, and remaining gaps in development_log.md.
Run import/startup and applicable tests before advancing; use configuration values
for mechanics and add tests when they validate real rules. Commit at M1 acceptance.

## Later gates

- M2: ENet listen-server lobby, two local clients, synchronized mechanics,
  deterministic two-client assertions and manual two-window smoke test.
- M3: four players, simultaneous interactions, disconnect/host loss, lobby-only
  late join, shared restart, and practical latency checks.
- M4: desktop export templates/presets, verified available builds, platform status
  and launch notes. No exports before the applicable milestone passes.
- M5: additional replayability/polish after approval. The woods/UI/supplies pass
  is explicitly approved by the user's current request; alternate extraction,
  audio, larger balance studies and further modes remain future work.
