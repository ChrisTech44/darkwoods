# Camper ability feedback and delivery audit

19 October 2026. Implemented follow-up to the local ability recordings.

Christian's Mimic now borrows the appearance **and overhead display name** of a
living survivor actually present in the round. Solo use keeps the sample. The
mask ends if its source dies or leaves. Network ownership, role, map identity,
voice identity and inventory remain truthful; this is a visual disguise. Shared
unshaded nameplates make names readable without making bodies luminous.

All 30 interactions were classified below. Faint local guides remain visible
while Christian holds a sample, winds it up or sustains it. Shots show direction
and travel limits; aimed actions show cones; auras/patches show their real radius.
Shot paths stop at world geometry. These guides do not scan/reveal creatures,
items, clues or exploration. Other players see the cast/effect, not his aim aid.
Transformations have a separate screen timer and action/ready/cooldown text.

Five ranged copy families now use real swept, wall-blocked projectiles. The four
Witch curses have different sprites; thread, spores, face moth and passenger have
their own sprites. The spore seed bursts on impact or at its 90px landing point;
standing still avoids its spores. The Witch's salt-ward reflection remains.
Physical grabs, throws, gaze, camera flashes and sound effects retain their
specific delivery instead of acquiring an unrelated missile or generic bubble.

## Interaction-by-interaction audit

Distances are world pixels. Short copied durations and AI/headline adapters in
[the overhaul](four_survivor_overhaul.md) still apply; these are not promises of
identical player-input and creature-navigation systems.

| Source | Delivery / range guide | Visual and audible feedback |
| --- | --- | --- |
| Witch | Straight projectile, 272 total travel; ward can reflect | Separate frog, reverse, feather and swap sprites; cackle on cast/impact; frog croak follows victim |
| Werewolf | Full-moon form; 90px pounce path, 30px contact | Form sprite, remaining time, X pounce ready/3s cooldown; native howl |
| Paparazzo | 210px flash area, walls/facing matter | Charge/shutter cues, self/friend whiteout, photographed status and Stalker report |
| Puffball | Spore-seed projectile to 90px, 78px burst | Seed/burst art; native swell cue; helium and sneeze playback/status; stillness counter |
| Seamstress | Thread projectile to 150px, 80px stitch area at hit | Flying needle, native thread between linked bodies, native whip cue; scissors counter |
| Vampire | 150px narrow gaze cone | Gaze streak, hypnotized pull, snarl; a target's beam breaks concentration |
| Bigfoot | Aimed 150px throw | Actual shove/damage and held-item drop; native growl |
| Scarecrow | Form; watched movement rule | Form sprite, remaining time, “move only while nobody watches”; revenant cue |
| Lantern Moth | Moth projectile to 150px | Flying moth, native face overlay/light drain, native screech; flash/bug-spray counters |
| Snuffer | 100px aura | Beams/flare actually extinguish, faint aura boundary; creature cue |
| Buster | 170px aimed report | Native bark and Stalker investigation; caster noise still exposes Christian too |
| Peeper | Aimed 150px committed hold | Actual held state/struggle and caster commitment; native screech; X cancels |
| Conductor | Self transport to existing fixed stop | Real relocation and train cue; carried ticket selects camp; blocked landing rejected |
| Mimic | Present-player disguise, no missile/area | Borrowed sprite/name, remaining time and disguise text; creature cue; no fabricated solo target |
| Owl | Aimed 150px short carry, human E consent | Actual carried state and owl call; X cancels, flare/flash counters |
| Bog Hands | Patch up to 90px ahead, 24px trigger | Mud-hand art, held state, native gurgle; flare counter |
| Imps | Aimed 150px trip/theft | Actual trip/held-supply drop and native giggle |
| Bear Hug | Aimed 150px committed hold | Actual grab/struggle, both bodies commit; squeak; X cancels |
| Groundskeeper | Mower form and 90px burst path | Form/timer, X burst ready/cooldown, native ignition and following engine loop |
| Cuckoo | 210px sight-locked countdown | Clock sigil, three native calls, native rewind bell, rewind/brief whiteout and position history; sight can break count |
| Banshee | 150px scream area | Deafened screen/audio state, native screech; no fake projectile |
| Slug | Actual 22px trail patches | Persistent slime sprites at recorded patch positions, native slippery status and gurgle |
| Surveyor | 110px area | Native Lost location/help presentation and eerie cue |
| Hitchhiker | Passenger projectile to 150px | Ghost wisp, actual passenger transfer/beam-off status; native giggle |
| Tollkeeper | Patch up to 90px ahead, 24px trigger | Toll seal, actual roaming-creature hesitation and native cue; flare counter |
| Echo | False source up to 90px ahead | Wisp sprite, existing whistle and AI stimulus; 110px beam counter guide |
| Fortune Teller | Self card draw | Tarot sprite, card announcement and native bells; actual health/light/clue/supply consequences |
| Lullaby Saint | 120px song area | Song-note art, native **following lullaby loop**, drowsy/sleep overlay and noise; moving resets stillness, coffee protects; X cancels |
| Jackal | Aimed 150px stolen-loot recovery | Actual dropped loot and native recovery cue |
| Ram | 90px committed charge path, 30px contact | Ram sprite, brief form timer/locked direction, native charge cue and actual bowling damage |

## Max: what the button does

- Starts with $6; optional searches pay $4, first stolen-gear recovery pays $3.
- Tap/release X before 0.45s: spend $4 for **one random ordinary supply**.
- Hold at least 0.45s, then release X: gamble the shown stake. It begins at $4,
  increases to $8 at 0.65s and $12 at 1.3s, limited to available whole $4 units.
- 45%: lose the stake and receive nothing. 55%: receive **2/4/6 supplies** for
  $4/$8/$12. Winnings are supplies, not money. A full belt drops overflow nearby.
- A hit spills one third of current cash. Any teammate can recover its drop for
  Max. Cash caps at $100; purchases never award objective parts/tools/more cash.

Selection, field guide and live HUD now explain the distinction. While holding X,
the HUD says BUY or GAMBLE and shows the actual cost/possible payout before release.

## General rules

A full ordinary flashlight lasts **420s (7 minutes)** of woods use; the capacity
and flash/creature costs stay the same. Isolated Alex's 25% saving gives 560s
(9m20s). Camp use still does not passively drain it.

From Nightfall, the Stalker selects an eligible living camper in the woods,
shadows for **90–130s of nearby clear sight**, and chases at most **12s** before
resuming. Calling-card clock starts at **8s**, then repeats every **24s** when he
is physically within 230px; it does not conjure cards from a distant location.
Distance/sight gating, beam fade, speed cap, grabs and deliberate investigations
retain their existing behavior. Human scare/balance acceptance remains pending.

**Camper abilities** defaults on. Offline: compact main-menu Settings checkbox.
Listen host: compact lobby checkbox, visible but locked for guests.
[Control sizing evidence](evidence/abilities_toggle/README.md). Changes clear readiness; the rule is
locked for the round. Dedicated: `python3 tools/run_server.py --no-camper-abilities`
(or the same user flag with direct Godot server launch). It disables all four
passives and actives, including starting samples/cash; movement, ordinary supplies,
flashlights, handoffs, revives, objectives and monsters remain available. New
round/lobby rule packets require **lnac-net-21** on both server and clients.

## Artwork and evidence

One 16-piece SpriteCook NB2.1 sheet, **12 credits** (320 → 308); no paid animation,
reroll or background-cleanup call. Existing creature/form sprites and registered
audio are reused. Asset IDs/hashes are in [the manifest](../spritecook-assets.json);
`tools/slice_ability_effects.gd` preserves the sheet's inspected alpha and boundaries.

[Selected actual screenshots, executed gates and limits](evidence/ability_feedback/README.md).
The private ignored `artifacts/ability_gallery/index.html` now contains 52 refreshed
MP4s from this implementation: all 30 Christian interactions, variants/research,
and John/Max/Alex demonstrations. Every MP4 was fully decoded; all nine contact
sheets were inspected. Staged samples/positions, bright lighting, hidden sight/roof
layers and controlled AI are explicitly labelled; recordings are demonstrations,
not natural-play or dedicated-server acceptance. Microphones stayed off.

Opening the pause/menu cancels Max's pending purchase/gamble without charging.
Christian can cancel his own committed gaze/song/stillness powers even while their
own pulse marks him tripped; outside incapacitation restrictions still apply.
Radio/stinger shutdown now releases native playback and prevents delayed radio
callbacks from starting after stop. See the [follow-up server review](server_review.md).
