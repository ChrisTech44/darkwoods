# Survivor selection and the road to co-op

Status: **offline selection and six personal bonuses implemented**. See
[content update](content_update.md) for the shipped rules and execution evidence.
The human balance gate and full all-role input-only rounds remain pending.
ENet co-op with role authority is implemented and locally tested; voice is not implemented. The following design remains the
acceptance target; the current ENet implementation is documented in the
[multiplayer guide](multiplayer_guide.md), and voice/remaining acceptance are plans. The user's latest amendment
prioritizes offline content before M2.

## What the player chooses

Offline flow: Main Menu → Choose Survivor → loading → round → results.
Online flow: Main Menu → Host/Join → lobby with survivor selection → ready →
loading → round → results → lobby. Keep Settings and menu music available while
choosing. Back returns without starting a round or losing the chosen mode/seed.
Only an explicit Start begins world generation. Do not require a microphone.

Use a full selection screen with six readable cards, an animated original sprite
preview, name, camp personality, exact bonus, recommended use and a short survival
tip. Show both baseline and modified numbers rather than vague star ratings.
Keyboard focus, mouse input, selected/confirmed states and Back must be clear at
384×216 and integer-scaled sizes. Use a scrollable detail panel if needed; do not
shrink all six biographies into the base viewport. No timed selection pressure.

Default to the Jock on first use, remember the last valid choice locally, and
show that choice before confirmation. A separate Random Survivor button chooses
uniformly from the six, reveals the result and allows changing it. Random Night
continues to randomize the world by default; it does not silently randomize the
survivor. Retry This Seed preserves the selected survivor; Another Night returns to the
menu and offers survivor selection before a fresh random night.

Archetypes are affectionate camp/slasher personality tropes. Appearance, name,
gender and skin tone do not determine abilities. Use original designs and let
any cosmetic variant take any archetype. No character has exclusive access to
parts, tools, revives, the van or victory. Duplicate archetypes are allowed.

## Initial six archetypes

These are the implemented initial offline tuning values. Every survivor retains
70px/s walking, 110px/s sprinting, ordinary collision/sight, the full interaction
set and the same two-hit injury rule. Bonuses are personal and do not stack into
team auras. Each role must be able to win alone; useful team specialization must
not require a particular composition.

| Archetype / stable ID | Proposed advantage | Why it helps win | Limits and counterpressure |
| --- | --- | --- | --- |
| **The Jock** / `jock` | Stamina capacity **5s instead of 4s**. | Longer bursts help reach distant caches and return carrying parts. | Sprint speed and recovery rate stay unchanged; empty-to-full recovery takes longer. Noise and enemy charge windows still matter. |
| **The Grease Monkey** / `mechanic` | Engine-start hold **1.5s instead of 2s**; start with **one extra spare battery**. | Shortens the vulnerable final ignition and funds a longer search. | Every part is still required; delivery is currently instant, so this is an ignition bonus, not fictional repair speed. Departure remains 8s. |
| **The Scout** / `scout` | Expedition flashlight drains at **0.8 charge/s instead of 1**; **one extra ration**. | More useful light per battery makes long routes manageable; food also helps in Quick Camp. | Capacity remains 90 charge, recharge +70, and full charge lasts 112.5s in the woods. No beam/range increase or sight through trees. Light still attracts moths. |
| **The First-Aid Kid** / `medic` | Unassisted teammate revive **2.25s instead of 3s**; start with **one medkit and one extra flare**. | Saves rescue time; the extra flare also benefits solo escapes. | Medkit revives remain 1.2s and consume a kit only on success. No self-revive, resurrection or extra health; solo cannot use the teammate bonus. |
| **The Quiet Kid** / `quiet` | Personal sprint-generated AI noise reach **×0.75**. | Safer component runs past enemies that have not seen the survivor. | Multiply each listener's normal hearing radius after weather; do not change actual footsteps, microphone gain, sight, bells, caches or flare noise. Sprinting is still detectable nearby. |
| **The Overprepared One** / `quartermaster` | Start with **one extra flare, one extra spare battery and one extra ration**. | Greater resource margin for retrieving parts and surviving the trip home. | Finite supplies, no periodic regeneration or duplicate loot; flares can attract moths. Later supply-sharing is separately gated. |

Current baseline supplies are 2 flares, 1 spare battery, 1 ration and no medkit.
Apply bonuses once at fresh round spawn, never on reconnect, ready toggles,
down/revive, opening settings or scene resynchronization. Starting extra items
are personal consumables, not extra objective components. No new inventory
transfer mechanic is needed for this first roster.

Examples of useful cooperation: a Scout leads a long search while a Quiet Kid
returns components; a Jock carries out a risky final run while a First-Aid Kid
covers a rescue; a Grease Monkey performs the final start while others approach.
The same objectives must still be solvable by four Scouts or a solo Quiet Kid.
Avoid adding a timer shortcut that makes the van depart before teammates board.

## Roles 2.0: active abilities and team play

**F6a implemented (17 October 2026):** every active ability below, item passing
(H), the Jock/Scout/Quiet team hooks, a two-person quiet generator restart and
end-of-night awards; see the README and `tests/integration/roles_abilities.gd`.
Not implemented: Mechanic workbench/hotwire, First-Aid long-range pings, the
seventh belt slot, unlockable roles, and **ghost wisps**. Wisps have no use under
current rules: the first extraction ends the round and downs never become
deaths, so no player is a spectator while others still play.
Original planning notes (overhaul slice **F6**, [overhaul plan](fun_overhaul.md)): Current stat bonuses rarely change decisions. Each role keeps a
small passive and gains **one active ability** (new `ability` action, proposed
default **X**) with a cooldown or per-night charges, plus a **team hook** that is
useful with friends but never required. Values are starting proposals.

| Role | Passive (kept/trimmed) | Active ability | Team hook |
| --- | --- | --- | --- |
| **The Jock** | 5s stamina | **Second Wind**: instantly refill stamina and gain 2s of +10% sprint; once per night phase. | Carries a heavy item alone at full walk speed; drags a downed teammate at 35 px/s. |
| **Grease Monkey** | 1.5s ignition | **Jury-Rig**: barricade a door for 8s, or re-install a sabotaged part in 1s; 2 charges. | Workbench crafts at double speed; can hotwire the rumoured secondary escape vehicle. |
| **The Scout** | 0.8 light drain | **Mark**: ping one landmark, cache or *seen* creature for all teammates for 6s; 30s cooldown. | Starts each night with one free field clue; climbs the fire tower in 2s. |
| **First-Aid Kid** | Faster revives | **Patch**: remove Wounded from self or an adjacent teammate without a medkit; 2 charges. | Kitless revive at medkit speed; sees downed teammates' ping from twice as far. |
| **The Quiet Kid** | Sprint noise ×0.75 | **Hold Breath**: 6s in which walking makes no AI noise and hiding breath drains half as fast; 45s cooldown. | Enters hiding spots in 0.3s; leaves no blood trail while Wounded. |
| **Overprepared** | Extra supplies | **Unpack**: once per night, open a seventh belt slot and drop a stash crate teammates can loot. | Item passing takes 0.2s instead of 0.5s. |

Rules kept: every role can win alone, duplicates allowed, no exclusive access to
parts or victory, effects are host-derived from the role registry and the active
ability is an intent the host validates (cooldown, charges, range, line of sight).
Mark never reveals what the Scout has not actually seen.

**Unlockable roles** (F8, earned by merit badges; side-grades, not upgrades):
*The Counselor* (team-wide pin range + calm aura: nearby teammates' breath meters
drain 20% slower), *The Prankster* (noise tins rattle 5 times; a decoy flashlight),
*The Lifeguard* (swims short lake channels; faster boat launch).

**Downed, escaped and spectating players** stay involved: downed survivors crawl
and ping for help; escaped/left-behind players become **ghost wisps** (lead one
teammate's view along explored trails once per minute, nothing else). This fits
the spectator voice-isolation rule: wisps show only information the team already has.

**End-of-night awards** add a social layer: per-player titles computed from
host-recorded stats (rescues, hides, flares, distance, time downed). Shared on the results screen.

## M1-S: small offline increments before networking

1. **Selection shell.** Add the selection screen, controller-free keyboard/mouse
   flow, preview, exact descriptions, saved choice and explicit random selection.
   Keep all cards marked preview until their bonuses work. Verify Back/Start,
   both modes, settings/music, result/retry paths and invalid saved IDs.
2. **Role data and application.** Add a small archetype Resource/registry with
   stable IDs, bounded values, description and cosmetics. Build a private
   effective per-player configuration; never mutate the shared default Resource.
   Keep engine/revive thresholds attributed to the acting survivor. Extend
   sprint noise with explicit stimulus strength/range rather than changing the
   entire world's enemy hearing settings. Update HUD timers to effective values.
3. **Role acceptance and balance.** Verify exact stamina/light/revive/ignition
   boundaries, reset-on-interruption, supply counts, no double application and
   no cross-player stat contamination. Run full solo escape/loss/retry paths in
   both modes for every role using recorded seeds. Use teammate fixtures for
   revive until actual multiplayer exists; fixtures do not pass the co-op gate.
   Check that light/noise modifiers preserve tree occlusion and local audio.
4. **Human gate.** Record normal-speed play with every archetype and the current
   giant forest: route length, supplies remaining, chase escapes, objective time,
   down/death causes and whether the bonus changed a decision. Compare repeated
   seeds before tuning; automation does not establish fun or 40–60 minute pacing.

## M2: turn selection into an authoritative lobby

Start with two real ENet peers in Quick Camp and the existing stalker. Add
identity/spawn/input authority first, then contested items, damage/revive,
van/boarding/results/restart. Bring Woods Expedition, all existing enemies,
projectiles, caches, sites, weather and role modifiers to parity in a subsequent
verified increment before declaring expedition co-op supported. Do not introduce
48 new enemy implementations while establishing synchronization.

Each lobby slot shows player name, selected portrait/archetype, connection and
ready state. Selection is editable only before readiness; changing it clears
ready. Host validates an allowlisted archetype ID, broadcasts the accepted
roster and owns start. Lock seed, rules version and choices at round start;
there is no mid-round respec. Late joins are lobby-only initially. A disconnected
client cannot rejoin an active round for fresh supplies. Return to lobby to join
the next round. Host loss closes the session with an explanation.

Clients send selection/input/interaction intents, never their own stamina,
revive speed, starting items, injury immunity or hearing range. The host derives
stats from the authoritative rules/role registry and owns all outcomes. Include
rules/content version in the handshake and reject incompatible peers clearly.
Use entity IDs independent of display names; a portrait is not peer ownership.

When two survivors hold the same revive or ignition interaction, designate one
host-owned actor; changing actor resets progress. Do not sum work or swap to a
faster role near completion. Host snapshots include actor, effective duration
and progress for consistent UI. Simultaneous pickups/kit spending award once.
Each client renders its own current sight mask and explored trails; teammate
lighting must not reveal paths through trees. Hidden enemy labels remain hidden.

M2 gate: deterministic two-client assertions plus a human two-window smoke,
including different and duplicate roles, forged role/stat requests, contested
interactions, round lock, shared results and clean restart. Preserve logs and
platform/version details. Local actor fixtures are insufficient evidence.

## M2-A, M3, M3-V and distribution

**M2-A:** replicate accepted sound events once per listener. Monster calls remain
nearby and attenuated; role selection UI/music is local. Quiet Kid changes AI
stimuli, not another player's volume slider. New monster audio needs stable cue
IDs and original/licensed assets. See [audio/voice design](audio_multiplayer_design.md).

**M3:** stabilize four peers before voice: mixed/all-same roles, simultaneous
interactions, disconnects, slow peers, latency, restart, all 25 existing enemies
and full expedition escape. Record CPU/frame, snapshot/bandwidth and queue
budgets on actual hardware. Supply counts must remain bounded across lifecycle.

**M3-V:** opt-in PTT, permissions/devices, peer mute/volume, speaking indicators,
distance/occlusion and separate spectator speech. No role grants global chat,
extra hearing, voice immunity or mandatory microphone use. Test two separate
machines across networks, then four speaking peers under jitter/load. Do not
claim ENet includes encrypted voice or automatic NAT traversal. No microphone
capture at boot, in offline play, after leaving, or without explicit enablement.
Monster mimic concepts use authored sounds, never captured player speech.

**M4:** export and actually test available desktop targets; package attribution
and chosen codec dependencies and verify permissions in packaged builds. Current
execution evidence is macOS arm64/Godot 4.7.2 only. Windows, Linux, Intel Mac,
exports, real microphones and cross-machine/network Internet sessions remain unverified.

## Later content alongside a stable co-op foundation

[Monster catalog](monster_catalog.md) and [biome design](biome_design.md) define
an approved planning backlog. Prototype the first biome/enemy pair only after
M1-S and a recorded human baseline, then integrate it after multiplayer/audio
foundations are stable. This does not make the whole catalog mandatory for M2,
voice or the first desktop package. Each content slice must pass navigation,
sight, solo/co-op counterplay, lifecycle and event-replication checks before the
next one. Keep the current runnable forest as a fallback throughout.
