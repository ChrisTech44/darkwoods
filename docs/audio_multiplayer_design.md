# Audio and online proximity voice design

Status: **local and replicated-source audio implemented; opt-in proximity voice implemented with TwoVoIP (see [multiplayer guide](multiplayer_guide.md#proximity-voice)); real-microphone, listening and encryption acceptance pending**. This user-approved amendment replaces the
original voice-chat exclusion in [AGENT_BRIEF.md](../AGENT_BRIEF.md). The build now includes locally verified ENet co-op; voice is still planned. The 16 October amendment prioritizes visual/map fixes,
seeded camp variation and user-supplied sound files before networking/voice.
Local playback does not establish two-client audio or microphone acceptance. Use [milestones](milestones.md) for delivery gates.
The later survivor/content amendment adds [selection and archetypes](survivor_multiplayer_plan.md)
before M2 and plans [monsters](monster_catalog.md)/[biomes](biome_design.md) as
staged content. Gameplay networking is now implemented; bespoke new cue files and voice remain separate work.

## Delivery order

1. **Offline polish/audio — first.** Fix path/building conflicts, vary seeded camp
   lots and implement the supplied files with local playback/mix/cleanup checks.
2. **M1-S — survivor selection and human baseline.** Add the offline choice flow,
   personal bonuses and accurate HUD, then record normal-speed play. Keep menu
   music/Settings and optional world randomization independent of role choice.
3. **M2 — synchronized gameplay.** Establish host/join, authoritative actors/items/
   enemies/hazards/sites, complete shared rounds and reliable lifecycle cleanup.
   Validate/lock role IDs and derive stats on the host, starting in Quick Camp
   and verifying current expedition parity before advertising Woods co-op.
   Keep the first two-client gate independent of microphones and audio devices.
4. **M2-A — synchronized audio foundation.** Extend the existing local registry,
   AudioManager/mixer and positional playback with authoritative sound events.
   Complete missing cue/provenance work using actual original/licensed files.
   Verify two-client playback and a real listening session.
5. **M3, then M3-V — reliability and online voice.** Keep four-peer gameplay stable,
   then add capture/encoding/transport/playback with opt-in proximity voice.
   Test on separate machines across networks, not just local windows or loopback.
6. **M4 — packaging.** Include files, attribution and approved codec dependencies;
   test permissions/device behavior in actual desktop exports.
7. **Staged content/M5.** Prototype a biome/monster slice after M1-S/human baseline,
   integrate after M2/M2-A stabilize, and tune cues/voice from playtest evidence.
   Full monster/biome catalogs are not prerequisites for voice or distribution.

M2 can first use LAN or virtual LAN. For online acceptance, record a direct-IP
setup with its required port forwarding, or a working virtual LAN, host/client
OS versions and measured connection conditions. Automatic NAT traversal, managed
relays, matchmaking and Steam integration still require separate scope approval.
Do not describe direct-IP hosting as seamless Internet matchmaking.

## Audio files and content priorities

Store runtime assets under [assets/audio](../assets/audio/README.md), grouped as
effects, ambience and music. Keep editable source material separate from runtime
exports. Every cue needs a stable ID, relative asset path, creator/source/license,
edit history, import format/settings, loop information, bus and playback limits.
Track these in the [local manifest](../assets/audio/manifest.json); no placeholder path should imply a shipped file.

| Priority | Planned cues |
| --- | --- |
| First | Survivor/stalker/cryptid footsteps; approach/alert/attack; damage/down/revive; flashlight toggle/empty/recharge; pickup/cutters/cache/install; van start/run/departure; UI confirm/cancel |
| Next | Wolf charge/recovery, Sasquatch rustle, moth wings, vampire approach, witch wind-up/bolt/impact/hex, revenant movement, flare ignition/burn, village bell/well, cauldron, crypt stone |
| Atmosphere | Wind/trees, campfire, cabin creaks, bog water/insects, graveyard/village loops; restrained music after the effects mix is readable |

Use original recordings/synthesis or assets with redistribution rights. Preserve
license/attribution records, including edits. Do not add unverified downloads,
franchise sounds, external-service dependencies or empty fake audio files.
Select file formats/import settings using measured quality, memory and looping
results on the validated engine and export targets.

Provide Master, Effects, Ambience, Music and Voice buses with independent gain/
mute, saved preferences and bounded simultaneous voices. Duck ambience/music
slightly under important cues or speech only after listening tests. Avoid sudden
mix jumps or loudness spikes. Keep gameplay hints and readable visual telegraphs
when audio is muted/unavailable.

## Audio architecture and event contract

AudioManager is now a local playback/mix service; network event handling remains
planned. Headless authority must run
without opening output devices. It plays registered assets by cue ID, positions
world emitters, chooses seeded variants and controls looping emitter lifetimes.
UI/menu audio stays local and does not generate network events.

Accepted gameplay produces a host-owned sound event: session/round ID, unique
event ID, cue ID, source entity/position, variant seed, start time and bounded
parameters. Receivers discard duplicates/stale rounds and unrecognized cue IDs.
Define an explicit local prediction/reconciliation policy so the host and the
acting client do not hear a pickup or footstep twice. Use bounded, freshness-aware
delivery for frequent cues; reserve reliable state transitions for persistent
loops/objective changes where replaying late would otherwise be wrong.

AI hearing remains an authoritative gameplay stimulus with its own range and
timing. It does not depend on a listener's speaker volume, mixer mute, sound file
duration or whether the headless host can play audio. A client cannot invent a
trusted bell, monster attack, completed repair or noise position by sending an
arbitrary cue packet. Simultaneous pickup attempts still award/play one accepted
event. Restore required loop state on scene/session changes without restarting
every looping sound from scratch each snapshot.

The implemented Quiet Kid modifier affects only that actor's sprint-generated AI
stimulus reach (×0.75 after weather), not footstep playback, voice gain or
environmental noise. Role-selection UI sounds stay local. New monster mimicry
uses authored registered cues, never recorded player speech, peer impersonation
or arbitrary client-supplied audio. Threat cues retain visible counterparts and
nearby attenuation; new biome ambience must not mask attack warnings.

## Heart-pounding audio (overhaul F2–F3)

Planned in the [gameplay overhaul plan](fun_overhaul.md); not implemented.
Sound carries most of the tension, so the overhaul adds these local layers on
top of the current cues:

- **Dynamic music by dread and phase**: an ambient bed per phase (Dusk → Witching
  Hour), a *build-up* layer when a threat is sensed nearby, and a *chase* layer
  while a survivor is pursued. Crossfade over 1–2s; never cut abruptly. The local
  layer follows that player's own state (host-replicated chase/phase flags).
- **Stingers** for phase changes, sabotage (van alarm), shortcut opened, and
  part installed, each short and paired with a visual banner.
- **Hiding audio**: muffled world, loud breathing tied to the breath meter,
  pursuer footsteps louder and directional.
- **Stalker tells**: flashlight buzz/flicker near the stalker, heavy distinct
  footsteps, a door-break crunch. New cues need stable IDs and provenance.
- **Hold-out finales**: engine, radio static or burning pyre loops that swell over
  the hold-out, with creature calls converging.

Overhaul ideas for voice (after M3-V's opt-in/PTT baseline):

- **Walkie-talkies** (pickup): a radio channel that lets a holder hear and speak to
  other holders at any distance with static, using normal PTT. Proximity voice
  stays the default. Wisps/spectators remain in their own group.
- **"Loud Voices" night modifier**: optional, off by default and host-validated,
  where voice above a threshold creates a small AI noise stimulus. It needs the
  separate balance work already required above and is never on by default.

## Proximity voice experience

Voice is optional for joining/playing. Default to **mic disabled until explicitly
enabled**, then **push-to-talk** (proposed action `push_to_talk`, default V).
These controls are design defaults, not current InputMap actions.
Show microphone permission/no-device errors, input/output device selection and
gain, per-peer volume/mute, local mute state and a speaking indicator. Provide a
local test/level meter that does not broadcast to other players. Do not enable
open mic silently; any later open-mic mode must be an explicit setting.

| Session/actor state | Planned voice routing |
| --- | --- |
| Lobby/results | Session-wide chat among connected participants who opt in |
| Alive/downed in a round | Distance-based voice among living/downed survivors |
| Boarded, before departure | Full-volume chat between passengers; external living survivors follow proximity rules |
| Dead/escaped/left behind | Separate spectator group; never unrestricted speech into the living-survivor group |
| Offline, disconnected or no session | No microphone capture or network voice playback |

Proposed tuning defaults: full gain within **96 world pixels**, smooth fade to
silence by **480 pixels**, with a simple ray-based wall-muffling modifier.
Distances come from authoritative positions. Avoid abrupt room/range switching;
smooth gain changes and retain enough muffled speech for understandable play.
These distances and attenuation need playtesting, not hard-coded promises.

Releasing PTT, disabling voice, loss of focus, closing/leaving the session, denied
permission or device removal stops outgoing capture promptly. In multiplayer a
local pause/settings menu does not pause the host or grant safety; suspend local
outgoing capture while that menu is open. A round restart flushes old frames and
resumes only with valid session state and a new PTT press. Keep voice preferences,
but do not retain an active recording state across boots or scene transitions.

Do not record voice, save microphone samples to files, or include audio payloads
in logs. Muted peers must be inaudible locally. Gameplay remains usable if capture
or playback fails. Microphone speech does **not** attract monsters by default;
an optional voice-noise mechanic needs separate balance and host validation.

## Voice transport and authority

Plan a VoiceManager separate from gameplay state and AudioManager's asset cues:
capture → encode → bounded frames → host-approved routing → short receive buffer
→ decode → positional playback. Each speaker owns only their capture stream;
the host validates peer identity, session membership, sequence/freshness, payload
size/rate and permitted recipient group. Clients cannot claim arbitrary speaker
IDs, positions, ranges or alive/spectator status.

Select a portable low-latency compressed codec and transport in an implementation
spike. Document dependency licenses, packaging, CPU/bandwidth budgets and the
Internet encryption approach before committing to a production voice stack.
Do not assume ENet gameplay transport alone provides encrypted voice.
No raw unbounded PCM broadcast or reliable retransmission backlog for live voice.

Isolate voice bandwidth/queues from reliable gameplay commands and snapshots.
Bound capture/receive buffers, drop stale/duplicate/out-of-order frames, tolerate
short loss, and reset streams on device/session/peer changes. A slow or abusive
voice sender must not stall movement, interactions or killer simulation.
Capture device samples locally; do not replicate them as authoritative world
sound effects. Verify host-as-player playback once, avoiding self-echo.

Target a measured end-to-end voice delay of **200ms or less on the agreed test
network**, without sacrificing gameplay sync. Treat this as a target to validate,
not an achieved performance claim. Record jitter/loss/bandwidth and listening
results; do not report real microphone quality from synthetic packets alone.

## Acceptance and evidence

- **M2-A:** asset manifest references real files with redistribution rights;
  imports/loops work, levels are comfortable, each accepted world event plays
  once on both clients, muted/deafened/no-device play remains functional, and
  scene transitions remove obsolete emitters. Real listening evidence required.
- **M3-V:** two separate machines complete an online round with PTT/device/mute
  controls, near/far/wall attenuation, correct passenger/spectator routing and no
  capture outside a session. Denied permission/no microphone must not block play.
  Require M3 gameplay reliability first. Archetypes grant no global chat,
  altered microphone hearing or microphone-dependent survival advantage.
- **Reliability:** four peers speaking while moving/repairing/casting; packet
  loss/jitter/reordering/load; silence/duplicate/oversized frames; focus/device
  changes, host loss, peer disconnect/reconnect and round restart. Old peer/round
  streams disappear; gameplay does not diverge or stall.
- **M4:** check actual bundled assets/codec/permissions and record which Windows,
  Linux and macOS packages/devices were tested. Label other platforms unverified.

Use synthetic deterministic audio for routing/load automation and actual opted-in
microphones/headphones for listening tests. Log event counts, queue limits and
latency measurements, never microphone content. Preserve commands and honest
results in the development log; online/microphone tests have not been executed yet. Local-only evidence is in the development log.

## Local menu playback amendment

The main menu now owns ominous music and subdued forest ambience, with the same
saved mixer controls available before Play. Its channels stop/free on departure;
round channels remain separate. This adds no microphone capture or permissions.

The surrounding-forest build keeps the same bounded local audio pool for 24
creatures: calls are gated at 160px, enemy steps at 110px and moving emitters
attenuate quadratically. Native sound assets, AI hearing and optional future
network voice remain separate.


## ENet foundation now available

The current listen host validates lobby identities/roles/readiness, locks round
IDs/seed, and owns positions, health/life state, inventory and accepted actions.
Two/four real local processes exercise both modes and scripted graphical windows
exercise replication. Snapshots carry round-scoped entity IDs for temporary
sources; peer IDs persist within the lobby/session. Reliable control and ordered
unreliable input/world-state channels are separate. No media buffers or microphone
APIs are initialized, including during hosting/joining.

Client replicas retain local attenuation/mixer behavior, enemy movement/call
cues, target-dependent heartbeat and nearby survivor footfalls. This is not proof
of a host-event exactly-once synchronized audio/listening gate. M2-A event-ID
coverage and listening checks, encrypted codec/transport choice, opt-in PTT,
devices/permissions, per-peer mute and living/spectator recipient tests remain
required before claiming voice acceptance. The stable authority/identity/state
boundaries are intended to support that next increment without trusting client
positions or routing microphone traffic through reliable gameplay actions.


17 October F5b cleanup: repeated round-transition testing exposed a delayed
radio timer lambda retaining a freed static source. Named, round-owned callbacks
plus a weak source reference now preserve the existing playback timing while
allowing old-round callbacks to disconnect. This is a lifecycle fix, not a new
audio event, listening acceptance or voice implementation.
