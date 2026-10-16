# Incremental implementation plan

M0 passed and was committed as `ef180d0`. M1's offline implementation and the
requested forest expansions are complete. All five steps below are covered by automated
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
- M2-A (after M2): audio-file/provenance pipeline, AudioManager and mixer buses,
  positional footsteps/monster/spell/objective cues and ambience. Replicate
  authoritative sound events once per receiver; keep AI hearing independent of
  device volume. Gate: two-client cue/cleanup checks and a real listening session.
- M3: four players, simultaneous interactions, disconnect/host loss, lobby-only
  late join, shared restart, and practical latency checks.
- M3-V (after M2-A, alongside M3 reliability): online proximity voice with opt-in
  microphone enablement, push-to-talk, distance falloff, wall muffling, per-peer
  mute/volume, device feedback and separate spectator speech. Gate: a complete
  two-machine round across networks using a documented connection method, then
  four-peer/load/jitter/reset checks; no-mic/denied-permission players can join.
- M4: desktop export templates/presets, verified available builds, platform status
  and launch notes. Package actual audio files and any codec dependencies; verify
  microphone permissions and playback/capture on each claimed target. No exports
  before the applicable milestone passes.
- M5: additional replayability/polish after approval. The woods/UI/supplies pass
  is explicitly approved by the user's current request; alternate extraction,
  expanded ambience/music, larger balance studies and further modes remain future work.

The user has approved including future online voice and audio files in the
design. This does not mark them implemented or collapse the incremental gates.
See [audio and multiplayer design](audio_multiplayer_design.md) for proposed
defaults, event/voice boundaries, content priorities and acceptance criteria.

## 16 October priority amendment

Before networking or voice: correct visual/map bugs, add seeded camp building
variation with aligned loot/door paths, and integrate the supplied MP3 cues.
Verify local audio independently; M2-A still requires future two-client evidence.

Offline layout/audio implementation now includes seeded camp lots and all 14
user-supplied MP3 cues, saved mix controls and local cleanup/decode tests. Asset
license documentation and human listening remain unverified; this does not pass
the synchronized M2-A gate or any voice/platform/export gate.
