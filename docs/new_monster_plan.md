# New monster plan: five habit-breakers and an invisible hunter

20 October 2026. **Status: implementation in progress.** Executed increments are listed below;
the detailed tables retain their approved design targets and open acceptance
limits. This plan covers six woods creatures and their sounds. Each creature is built from hooks that already exist in the code
(listed per creature) so that no new terrain, water, physics, collision, item or
map system is required.

Implementation defaults: preserve every type every night; keep the Stalker
movement cap; allow its Magician swap only in Witching Hour. New audio is original
procedural synthesis, not recorded character performances. The agreed Shade is
an additional seventh creature. No extra SpriteCook generations beyond the
shared 12-credit design sheet.

## Delivered increments

- **vulture**: brain, full-roster spawn, journal, Christian sample, native cue routing and host/client checks pass (53 cumulative gameplay assertions). [Evidence](evidence/wheel_monsters/vulture_results.json).
- **nightlight_kid**: brain, full-roster spawn, journal, Christian sample, native cue routing and host/client checks pass (42 cumulative gameplay assertions). [Evidence](evidence/wheel_monsters/nightlight_kid_results.json).
- **lifeguard**: brain, full-roster spawn, journal, Christian sample, native cue routing and host/client checks pass (32 cumulative gameplay assertions). [Evidence](evidence/wheel_monsters/lifeguard_results.json).
The four [playtest follow-up concepts](playtest_followup.md#mechanically-distinct-monster-proposals)
and the 48 [catalog concepts](monster_catalog.md) remain separate proposals.

## Design goals

- **Punishing:** each creature costs the team something real: health, stamina,
  position, time or a rescue.
- **Fun:** each one targets a habit players lean on: sprinting, going dark,
  rescuing, flashing and standing in the open. The answer is to change that
  habit, not to mash harder.
- **Loud:** each creature has its own recognisable sound, played through
  `CreatureBrain.cue()` / `CampSoundscape.broadcast()` so every peer hears it once.
  An AI hearing stimulus (`level.loud_noise`) is separate from playback, and every
  creature below states both paths.
- **No overlap** with the 29 shipped brains in `scripts/ai/brains/` or the Stalker.
  The closest existing creature is named under each design.

## Shared implementation pattern

Each creature follows the existing brain recipe:

1. `scripts/ai/brains/<species>.gd` extending `CreatureBrain` (host-only logic;
   `snapshot()`/`restore()` for client drawing).
2. A spawn entry so it joins the full Woods roster. This takes the roster from
   31 creatures plus the Stalker to 37 (see open decisions).
3. Field-guide name and one tip (`CreatureBrain` journal fields).
4. A `CreatureSamples` signature so Christian can borrow it (required by the
   [four-survivor overhaul](four_survivor_overhaul.md)); call
   `CreatureSamples.encounter(actor, body)` on contact, as the Conductor does.
5. Sprite: SpriteCook walk sheet through the existing creature import tool.
   Check the credit balance first and stay above the user's stated floor.
6. Sounds: add files to `assets/audio/`, register them in
   `assets/audio/manifest.json`, map them in `camp_soundscape.gd`, and add them to
   `LOUD_CUES` only when the sound is also meant to alert AI.
7. An integration test in `tests/integration/` covering the trigger, the
   punishment, the counter and online replication.

None of the six adds a movement-blocking status, so `LocalPrediction.EFFECTS`
does not change. Any later change that alters movement must add it there.

---

## 1. The Lifeguard: "NO RUNNING!"

A sunburnt lifeguard ghost on a tall chair, with a whistle and a red float.
It patrols lakeshore and camp trails.

| | |
| --- | --- |
| **Trigger** | A survivor **sprints** inside its sight (`nearest_seen`, `actor.sprinting`). |
| **Tell** | Whistle raised to its lips (0.6 s), then a long whistle blast. |
| **Punishment** | `stamina = 0`, `exhausted = true` (can't sprint until stamina reaches `stamina_restart`). The blast is also `loud_noise(actor position, 700)`, drawing nearby hunters to the exhausted survivor. |
| **Counter** | Walk while it can see you; break line of sight before sprinting. Flash stuns it normally. |
| **Cooldown** | 20 s per survivor, so a group isn't chain-locked. |
| **Witching Hour** | Cooldown 12 s; the whistle also gives `tripped` for 0.8 s. |
| **Closest existing** | None punishes sprinting directly. The Slug changes your movement instead. |
| **Hooks** | `nearest_seen`, `CampPlayer.sprinting/stamina/exhausted`, `level.loud_noise`, `cue`. |
| **New state** | Per-survivor cooldown dictionary in the brain. |
| **Christian sample (proposal)** | Christian blows the whistle: creatures within 200 px pause (`recover_remaining = 2`), but every survivor in range, friends included, is exhausted. |
| **Risk** | Must not fire while the survivor is being chased by the Stalker *and* has no other route; playtest whether exhaustion during a chase is too harsh. |

## 2. The Night-Light Kid: "LEAVE IT ON!"

A small camper ghost in pyjamas, clutching a dead night-light. It is afraid of
the dark and drawn to anyone who is in it.

| | |
| --- | --- |
| **Trigger** | `senses()` returns 1 only for survivors whose flashlight is **off** (and 0 for anyone lit). |
| **Tell** | Rising whimper as it approaches ("it's too dark…"). |
| **Punishment** | On contact it screams "LEAVE IT ON!". A new `nightlight` effect (30 s) forces `flashlight_on = true` and doubles passive drain. It is the inverse of the existing `dark` effect. The scream is `loud_noise(…, 500)`. |
| **Counter** | Keep your light on near it, then switch off once it wanders off. It can't sense lit survivors at all. |
| **Witching Hour** | Effect lasts 45 s. |
| **Closest existing** | The Snuffer forces lights *off*; this forces them *on*. **Do not spawn the two within the same region**, since one would cancel the other. |
| **Hooks** | `senses()`, `flashlight_on`, `flashlight_charge`, `passive_light_rate()`, `add_effect`, `loud_noise`. |
| **New state** | `nightlight` effect checked beside `dark` in `CampPlayer._physics_process`. |
| **Christian sample (proposal)** | Every flashlight within 150 px, friends included, is jammed on for 15 s. |
| **Risk** | Forced-on light at zero charge: the effect must do nothing when charge is empty (no negative charge, no stuck state). |

## 3. The Vulture: punishes the rescue

A bald, oversized vulture that perches beside anyone who goes down.

| | |
| --- | --- |
| **Trigger** | A survivor with `Status.DOWNED` exists. It flies to them over walls, drawn only (not a collision change), and lands beside them. |
| **Tell** | Circling shadow and squawk on arrival; wing-flap before each peck. |
| **Punishment** | While any survivor is reviving the downed one (`level.revive_actor`), the Vulture pecks the reviver every 2 s for 15 damage (`receive_hit`). A reviver who goes down ends the revive through the existing status check. **Solo:** while it perches, `advance_self_recovery` runs at half rate. |
| **Counter** | Flash it before reviving (`on_stunned`): it flees for 20 s. Or one survivor shoos it while the other revives. |
| **Witching Hour** | Pecks every 1.5 s. |
| **Closest existing** | The Hound drags downed survivors toward the hook; the Vulture never moves them, it taxes the rescuer. |
| **Hooks** | `Status.DOWNED`, `level.revive_actor/revive_target`, `receive_hit` (already respects `WOUND_GRACE`), `on_stunned`, `flee_from`. |
| **New state** | Perch target and peck timer in the brain; solo half-rate check in `advance_self_recovery`. |
| **Christian sample (proposal)** | Christian guards a downed teammate: creatures entering 60 px get a 1 s stun, but his own revive speed is halved while guarding. |
| **Risk** | Must leave when the downed survivor is revived, disconnects or is hooked (`survivor_left`). |

## 4. The Huntmaster: the support monster

A tall horned figure in a hunting coat that never attacks. It makes every
other creature worse.

| | |
| --- | --- |
| **Trigger** | Sees a survivor within 300 px. |
| **Tell** | 2 s windup: lifts the horn and draws breath, showing a visible ring. |
| **Punishment** | Horn blast: every creature within 400 px moves **30% faster for 15 s**. It does *not* reveal survivor positions (that is the Hound's job). |
| **Counter** | Flash it during the windup to cancel the blast; otherwise leave the 400 px area. |
| **Cooldown** | 45 s. |
| **Witching Hour** | Radius 550 px. |
| **Closest existing** | None buffs other creatures. |
| **Hooks** | `nearest_seen`, `on_stunned`, `cue`. |
| **New state** | A `haste_remaining` timer on `CampCryptid`, applied in `CampKiller.steer()` and the chase/patrol velocity line. The Stalker's 90 px/s final cap stays in force (see open decisions). |
| **Christian sample (proposal)** | Teammates within 300 px get +20% speed for 10 s, and so does every creature within 400 px. |
| **Sound note** | `hunt_horn_single.mp3` already plays as "The Hunt Begins" horn (`CampSoundscape.hunting_horn`). Reusing it would confuse the two, so record a shorter, brassier blast. |

## 5. The Shell Game Magician: "TA-DA!"

A top-hatted stage magician with too many white gloves. It swaps you with
something worse.

| | |
| --- | --- |
| **Trigger** | Sees a standing, unhidden, unheld survivor within 200 px. |
| **Tell** | Drumroll; a glowing ring under the target for 1.5 s. |
| **Punishment** | If still inside the ring at the end: the survivor **swaps positions with a random other creature** on the map (host sets both `global_position`s). In Witching Hour the Stalker is eligible. |
| **Counter** | Leave the ring during the drumroll. Flash interrupts the trick. |
| **Cooldown** | 40 s; never targets the same survivor twice in a row. |
| **Closest existing** | The Conductor teleports you to one fixed place and can be prevented with a ticket; this swap is random, sends a creature to where you stood, and you dodge it by stepping out of the ring. |
| **Hooks** | `nearest_seen`, the Conductor's direct `global_position` assignment, `add_effect("whiteout", 0.6)` as a transition cover, `on_stunned`. |
| **New state** | Ring centre/timer in the snapshot. Before swapping: clear `hidden_spot`, release holds, end tethers, cancel vaults; skip creatures currently grabbing someone. |
| **Christian sample (proposal)** | Christian swaps with the nearest teammate (a rescue tool), but 30% of the time it picks the nearest creature instead. |
| **Risk** | Both positions were occupied by a body, so neither should be illegal. Still verify no swap lands inside a cabin's single exit or the van boarding area, and that clients don't rubber-band after the jump. |

## 6. The Nobody: the invisible monster

"Nobody's there." A creature that is never drawn. Players learn to track it by
ear and by its prints.

| | |
| --- | --- |
| **Trigger** | Hunts like an ordinary creature (shared hunter loop) at a slow 55 px/s. |
| **Invisibility** | `draw()` returns true and draws nothing. Clients still receive its position for sound placement; this is a local co-op game, so hiding it from the network is not required. |
| **Tells** | (1) A **positional breathing loop** that grows louder as it nears. (2) **Footprints**: its last 8 positions drawn as fading prints in `draw_over()`. (3) **Shimmer**: a faint outline while it's inside any flashlight beam (`in_beam`). |
| **Punishment** | Contact: a heavy hit (35) and an exhale "hahh" right beside you. It then relocates to a far patrol point (Conductor pattern) with 20 s recovery. |
| **Counter** | Sweep your beam where the breathing is; flash it once shimmer shows (normal stun, and it stays fully visible for 3 s). Walk away from fresh prints. |
| **Witching Hour** | Breathing 6 dB quieter; prints fade twice as fast. |
| **Closest existing** | The Scarecrow is visible but moves unwatched; the Echo is visible and fakes a sound. Nothing is unseen. |
| **Hooks** | `draw()`, `draw_over()`, `in_beam`, `snapshot()`, positional loop playback (as the Saint's hymn and the mower already use), `on_stunned`. |
| **New state** | Footprint ring buffer and `revealed_remaining` in the snapshot; one positional loop in `camp_soundscape.gd`. |
| **Christian sample (proposal)** | Christian is invisible to creatures *and teammates* for 10 s, but his breathing plays loudly to everyone. |
| **Accessibility / combos** | A Banshee-deafened survivor loses the breathing tell; prints and shimmer must stay readable without sound. Do not spawn it inside the Snuffer's darkness. |

---

## Sound wish list

Recording guidance: short, dry, mono one-shots; trim leading silence; leave
~3 dB peak headroom (the pack is levelled at runtime). Loops need seamless
start/end points. Existing files are named in the placeholder column only for
prototyping, and each is already used by something else.

| Priority | Cue ID (proposed) | Creature | What it should sound like | Length | Loop | Also an AI stimulus? | Prototype placeholder |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `lifeguard_whistle` | Lifeguard | One sharp, long pea-whistle blast, the kind that stops a whole pool | 1–1.5 s | No | Yes (700) | None (`field_whistle` is the Stalker's camp tune; never reuse it) |
| 1 | `lifeguard_shout` | Lifeguard | Bored, booming "NO RUNNING!" through cupped hands | ~1 s | No | No | None |
| 1 | `nobody_breathing` | Nobody | Slow, wet, close breathing with no voice in it; must be distinct from the survivor's own `fast_breathing_loop` | 4–8 s | **Yes** | No | None (don't reuse the survivor breathing) |
| 1 | `vulture_squawk` | Vulture | Harsh, rasping squawk on landing | ~1 s | No | No | `screech_3.mp3` |
| 1 | `vulture_peck` | Vulture | Hard beak "tok" with a wet tear | 0.3 s | No | No | `thud.mp3` pitched up |
| 2 | `nightlight_whimper` | Night-Light Kid | Small child whimpering "it's too dark…", quiet, looping while it approaches | 3–5 s | **Yes** | No | None |
| 2 | `nightlight_scream` | Night-Light Kid | Piercing child shriek "LEAVE IT ON!" | 1–1.5 s | No | Yes (500) | `screech_1.mp3` |
| 2 | `huntmaster_horn` | Huntmaster | Short, brassy, rising two-note hunting horn, distinct from the long "Hunt Begins" howl | 1.5–2 s | No | No | `hunt_horn_single.mp3` pitched up (prototype only) |
| 2 | `huntmaster_inhale` | Huntmaster | Deep inhale before the blast (windup tell) | ~1.5 s | No | No | `single_gasp.mp3` pitched down |
| 2 | `magician_drumroll` | Magician | Snare drumroll building to a stop | 1.5 s exact | No | No | None |
| 2 | `magician_tada` | Magician | Cymbal crash, then a showman's "TA-DA!" | ~1 s | No | No | None |
| 3 | `nobody_exhale` | Nobody | Sudden close "hahh" right at the ear on contact | 0.5 s | No | No | `single_gasp.mp3` |
| 3 | `nobody_step` | Nobody | Single soft step on leaves, for print placement | 0.3 s | No | No | `single_footstep.mp3` (quieter) |
| 3 | `vulture_wings` | Vulture | Heavy wing flaps for arrival and fleeing | 1 s | No | No | `wind_gust.mp3` |
| 3 | `lifeguard_ambient` | Lifeguard | Distant creak of a tall wooden chair; sells presence before it sees you | 2 s | No | No | `door_creak.mp3` |
| 3 | `magician_poof` | Magician | Smoke-puff "fwump" at both swap points | 0.5 s | No | No | `fire_whoosh.mp3` (short) |

Fifteen sounds: five needed to prototype (priority 1), six to ship all six
creatures (priority 2), and four polish sounds (priority 3).

## Build order

1. **Lifeguard**: cheapest, one new sound, and it teaches the "habit-breaker"
   idea.
2. **Vulture**: cheap; changes how teams handle downs.
3. **Night-Light Kid**: needs the new `nightlight` effect and a Snuffer spawn rule.
4. **Nobody**: needs the breathing loop, prints and shimmer readability checks
   (capture actual graphical output, per the graphics plan).
5. **Huntmaster**: needs the creature haste timer and a decision on the Stalker cap.
6. **Magician**: the swap needs the most edge-case cleanup and online checking.

Each creature is a separate verified increment: brain, sprite, sounds, field-guide
entry, Christian sample, integration test, then the log and push.

## Acceptance gates (per creature)

- Godot import and startup checks from the [brief](../AGENT_BRIEF.md#verification-and-evidence) pass.
- Integration test proves trigger → punishment → counter on the host.
- Online: a client sees the same tell and hears the cue once (snapshot sound log).
- Captured screenshot of the tell (Nobody: prints and shimmer visible in a dark
  scene; label any forced lighting).
- Playback and AI stimulus checked separately where both apply.
- Christian's sample works and keeps its drawback.

## Open decisions for the user

- **Roster size.** Every type currently spawns every Woods night. Adding six takes
  it to 37 creatures plus the Stalker. Keep "everyone, every night", or rotate
  some in?
- **Huntmaster vs. the Stalker.** Should haste apply to the Stalker (still capped
  at 90 px/s), or skip it entirely?
- **Magician and the Stalker.** Is a Witching Hour swap next to the Stalker too
  punishing?
- **Christian samples.** The six proposals above are first drafts.
- **Sounds.** Will you record or source these, or should prototypes use the
  placeholders until real recordings arrive?
