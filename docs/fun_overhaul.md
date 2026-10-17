# Heart-pounding nights: gameplay overhaul plan

Status: **approved planning direction; F1 navigation, F2 night phases, F3 chase toolkit, and F4 map redesign (roads, rotating regions with clues, shortcuts, fences) implemented**
(signposts, skyline markers, wall-map regions, team pins, spare cutters and
crowbar; see [evidence](evidence/navigation/README.md)). Everything else in
this document is still planned until a development-log entry records execution
evidence for it. The user asked (16 October 2026) to make the game
more fun, more dynamic and more heart-pounding, and is explicitly open to
better map designs, new regions and new cross-map requirements. Where this plan
conflicts with older planning text, this plan wins; the
[brief](../AGENT_BRIEF.md) lists the superseded rules.

Related plans: [milestones](milestones.md), [survivors and co-op](survivor_multiplayer_plan.md),
[monster catalog](monster_catalog.md), [biome design](biome_design.md) and
[audio/voice design](audio_multiplayer_design.md).

## What is wrong today

Measured from the current code and rules, not from opinion alone:

- **Searching is long and featureless.** Walking is 70 px/s in a 9,600×9,408
  world with 2,410 maze clearings. The three required caches sit in three
  different directions (village NW, bog E, graveyard S). The field map shows only
  walked trails, and clues name a compass direction. Most of a round is walking
  corridors that look alike, so finding things feels like a puzzle you can't reason about.
- **Co-op bottleneck.** One pair of boltcutters opens every locked cache. Four
  friends either move as one group or watch one person do the important work.
- **Optional content has no pull.** Landmarks give one consumable and a 650px
  noise, so the best play is to skip the most interesting places.
- **Every night has the same shape.** Same recipe, same exit, same stalker,
  flat threat level. Random seeds change positions, not decisions.
- **Fear is binary.** One hit downs you, there is nowhere to hide and nothing to
  slam, so a chase is either a clean escape or an instant down.
- **Roles are small numbers** (stamina +1s, drain ×0.8) that rarely change
  what anybody does.

## Design pillars

1. **Every minute holds a decision.** No stretch longer than ~45 seconds without
   something new to read, choose or fear. Travel is a risk trade, not filler.
2. **Pressure rises.** The night escalates through phases. Your own progress
   (installing parts, loud actions) makes the woods more dangerous.
3. **Friends need each other.** Splitting up is efficient; sticking together is
   safe. Some actions need two people; rescues are dramatic and common.
4. **Every night tells a different story.** Escape method, killer, objective
   regions, modifiers and events vary, so friends compare nights afterwards.
5. **Fear is earned and fair.** Threats always telegraph. Close calls happen
   often, and actual downs are rarer. You can hide, slam, vault and outthink the woods.

## Target shape of a night (40–60 minutes)

User amendment (16 October): expedition rounds span **40–60 minutes**. A night
is 60 minutes long, and objectives are staged so the escape lands in the final third.

| Phase | Clock | Feel | What changes |
| --- | --- | --- | --- |
| **Dusk** | 0–10 min | Prepare, plan, split up | Battery/key in camp, tools, low dread, stalker sweeps camp quietly. |
| **Nightfall** | 10–25 min | Expedition | Radio reveals fuel; supply drop; first storm; full roaming density. |
| **Deep Night** | 25–40 min | Pressure | Radio reveals extra part 1; blackout; stalker hears farther; director peaks more often. |
| **Witching Hour** | 40–60 min | Finale | Radio reveals the last part; stalker chases faster; escape finales; race to camp before dawn. |
| **Dawn** | 60 min | Resolution | Ranger patrol rescues survivors in camp or aboard; anyone in the woods is left behind. |

Phases advance by **clock only**, so no team can finish before 40:00. Installed
parts, loud actions and chases raise **dread** instead, which drives the
director, music and event intensity. *(Implemented in F2; the original
"time or progress" rule was replaced to keep the 40-minute floor.)* There is no
instant loss before dawn. Witching Hour keeps getting harsher (configurable
cap) so stalling is never the safe choice.

**Escape finales** make leaving the climax. Starting the van, transmitting the
radio call or launching the boat creates a team-wide noise beacon and a short
**hold-out** (default 20–40s by escape type) where everything nearby converges.
Passengers board during the hold-out; departure happens at its end.

## Pressure systems

### Dread and the encounter director

A host-owned **dread value** (0–100) rises with time, noise, flares, installs
and chases; it falls slowly during quiet stretches. A bounded **director**
reads dread and team positions, but only the same sensed information the AI
already has, never hidden exact positions. It:

- adjusts roaming density in the band 300–1,200px around survivors by
  steering existing roamers' patrol routes, not by spawning creatures in view;
- enforces **relief windows**: after a chase ends, at least 45s with no new
  aggressive encounter for that survivor (default, tunable);
- schedules **build-ups**: distant calls, a light flicker, footprints, before peaks;
- triggers **night events** (below) at phase boundaries.

Hard limits: no spawns within 400px or inside line of sight, no spawns in camp,
no targeting of unsensed survivors, and no removal of a counterplay window.

### Night events (one or two per phase, seeded)

- **Blackout:** camp generator fails; camp lights and floodlights go out until
  someone refuels/restarts it at Maintenance.
- **The Stalker's Gift:** a stolen supply crate appears in a named region with
  a visible trap tell, a bait reward.
- **Lost Camper:** an NPC counselor calls from a region. Escort them to camp for a
  score bonus and an extra medkit. They walk slowly and panic if chased.
- **Storm Front:** rain and thunder; lightning briefly lights everything in
  view (not through walls) and masks footsteps for AI hearing.
- **The Hunt Begins:** a sounding horn; for 60s every cryptid investigates
  the last loud noise in the inner ring.
- **Sabotage:** see stalker escalation in the [monster catalog](monster_catalog.md#stalker-escalation-and-headline-killers).

## The chase toolkit (heart-pounding, but fair)

- **Wounded before downed.** First hit = *Wounded*: injured breathing, a
  short-lived blood trail visible to AI and players, −10% sprint speed. A second hit
  while Wounded = *Downed*. A medkit or First-Aid Kid patch removes Wounded.
  This replaces the one-hit down and makes chases longer and closer.
- **Hiding spots.** Lockers, under-bunk spaces, wardrobes, dense bush clumps
  and hunting blinds. Entering takes 0.6s and is visible if watched. Inside, the
  view narrows and a **breath meter** drains while a hunter is within 120px;
  release too early or run out and you gasp (noise). An enemy that *saw* you enter
  checks that spot; otherwise it searches normally. One survivor per spot.
- **Slam and vault.** Cabin doors can be closed and slammed (enemy breaks
  through in 2–3s; noisy). Some windows and low fences can be vaulted
  (0.5s, noisy when sprinting). One-use **knock-overs** (woodpiles, shelves,
  canoe racks) block a lane for 6s and stun a pursuer they hit.
- **Flashlight as a weapon of nerve.** A brief flash-stun on some cryptids
  (costs 15 charge, 8s cooldown) gives a clutch escape without making lights spam.
- **Readable chase feedback.** Layered chase music, louder pursuer footsteps,
  heartbeat-linked vignette pulse, screen-edge direction marker for a pursuer
  you have heard but can't see (audio-matched, local hearing only), and
  flashlight flicker when the stalker is close (diegetic tell).
- **Downed is drama, not waiting.** Downed survivors crawl at 20 px/s, can
  hold a "call for help" ping (visible to teammates in voice/marker range), and
  teammates can revive **without a medkit in 6s**; a medkit makes it 3s
  (First-Aid Kid faster). Solo players get one **self-recovery** per night (8s,
  noisy) so solo isn't instant defeat.

## Map redesign: rings, spokes and a skyline

The current maze budget (9,600×9,408) stays, but its structure changes from a
uniform maze into a **readable hub with layered risk**:

- **Camp hub** in the centre, as now, plus a **lake** edge and **floodlit
  gate** to the old ranger road.
- **Inner ring road** (~1,600px radius): a wide, partly lit dirt road around
  camp with lamp posts that work only while camp power is on. Safe-ish, slow to
  travel around, many hiding spots.
- **Four to six spokes**: signposted main trails from camp to region clusters.
  Each spoke has a junction landmark and one **unlockable shortcut** back to camp.
- **Middle band**: objective-capable regions. **Deep band**: optional high-risk
  landmarks with relics, rare tools and the best score.
- **Thickets** between spokes keep the maze feel: dense, dark, faster as the crow
  flies, no lamp posts, more roamers. Cutting through is a deliberate risk.
- **Skyline landmarks**: the fire tower, observatory dome, radio mast, bell tower
  and the bog's green glow draw as silhouettes above the canopy layer within a
  bounded radius. They reveal direction, not trails or creatures.
- **Signposts** at spoke junctions name the next landmark and point to camp.
- **Starting map knowledge**: the Ranger Lodge wall map gives the ring, spokes and
  region names from the start. Thicket trails and cache positions still need exploring.
- **Shortcuts**: gates opened from the far side, a collapsed footbridge you can
  lower, the fire-tower zipline toward camp, a rail handcar from the rail yard,
  a canoe crossing on the lake. Opened shortcuts persist for the night.

Navigation target: walking a spoke from camp to any middle-band region takes
**≤ 60s at walk speed**, and every required step of the night has a return
route under **90s** once its shortcut is open. Measure with the automated
route player before claiming the target.

## Information instead of combing

Every required item belongs to a **clue chain**:

1. **Camp clue** (corkboard, counselor log, ranger radio log) names the region
   for one part and gives vague hints for the others ("near running water").
2. **Field clues** in the woods (notes, tracks, a lantern left burning) upgrade a
   hint to a named region, then to a marked building/cache once you are in it.
3. **Fire tower lookout**: climbing it (noisy, 4s) reveals all region names in
   a radius and briefly shows lit creatures in line of sight from the top.

Teammates can place **map pins** (three per player) that everyone sees, so
splitting up and reporting back is useful even without voice.

## New objectives and cross-map requirements

Each night picks one **primary escape** and seeds one **rumoured secondary**
(learned from a clue). Escapes use parts and steps spread across the map:

| Escape | Chain (cross-map) | Finale |
| --- | --- | --- |
| **Van** (current) | Battery + key in camp; fuel and 2 extras from rotating regions. | Engine start, 20s hold-out, depart. |
| **Radio Rescue** | Fuse at the Power Substation → restore power → climb Radio Relay Station → transmit; then light the landing zone with 3 flares. | 40s hold-out at the landing zone; rescue truck/helicopter arrives. |
| **Boat** | Outboard motor (Logging Camp, heavy), fuel can, and drain plug; launch at the Lakeshore Boathouse. | 25s launch hold-out with Lake Thing pressure. |
| **Ranger Gate** | Three gate-code fragments from different regions + floodlight power; open the gate. | On-foot run down the ranger road with the stalker in pursuit; reach the bridge. |
| **Signal Fire** | Kerosene ×2 and a flare gun from different regions; light the ridge pyre. | Hold the ridge 45s; everything converges. |

Objective regions **rotate per night** from a pool of objective-capable
regions (village, bog, graveyard, plus new ones), drawn so the chain spans at
least three spokes. Every chain step is reachable by every role solo.

**Heavy items** (outboard motor, generator battery, tire): one carrier walks
at 75% speed and cannot sprint; two carriers move at full walk speed. Dropping is
instant. Heavy items never spawn in deep-band dead ends.

**Locks without bottlenecks.** Boltcutters stay in Maintenance, plus one more
pair in a seeded inner-ring site; a crowbar (any toolshed) opens caches noisily
(4s, 500px noise). Different tools mean a team can split up without one person
holding everything.

## Co-op that needs friends

- **Item passing**: give the selected supply to an adjacent teammate (E-hold 0.5s).
- **Two-person actions**: boost over a fence to a shortcut, hold a winch while a
  partner pulls a part, crank a generator while another resets the breaker.
  Solo players get a slower alternative (find the key, take the long way).
- **Cover**: a teammate holding a light on a vampire or Shutter Wraith that hunts
  someone else still slows it; flares and noise tins have team uses.
- **Ghost wisps**: escaped or left-behind players become campfire wisps that
  can, once per minute, lead one living teammate's view toward camp along an
  already explored trail. They cannot reveal creatures, caches or unexplored
  paths, which keeps the spectator-information rule.
- **End-of-night awards**: "Never Left Behind", "Most Flares Wasted", "Bait",
  "Hid In A Locker For Two Minutes", "Saved By A Wisp". Cheap and very social.

Survivor role changes are in [survivors and co-op](survivor_multiplayer_plan.md#roles-20-active-abilities-and-team-play).

## Replayability layer

- **Headline killer rotation**: the stalker plus new headline killers with
  distinct rules (see the [monster catalog](monster_catalog.md#stalker-escalation-and-headline-killers)).
- **Night modifiers** (0–2 per night, shown on the loading card): *Blood Moon*
  (+50% hounds/jackals, faster stalker), *Dead Batteries* (spares hold 40),
  *Fog Bank*, *Silent Night* (no music, louder world), *Generous Woods* (+50%
  loot, more events), *Lone Wolf* (players start in different camp buildings),
  *Hunter's Moon* (two headline killers, rare, after F7 balance).
- **Score and grade** per night: escape, relics recovered, events completed,
  rescues, time and modifier multipliers. Optional landmark **relics** are worth
  score and journal pages, which finally gives deep regions a purpose.
- **Daily seed** and a local per-seed best score table; share seeds with friends.
- **Camp journal** (persistent, local): bestiary entries with tips unlock on first
  sighting and first escape from each creature; region postcards; killer lore
  pieced together from relics.
- **Merit badges** (challenges) unlock survivor outfits and **new survivor roles**,
  and also unlock modifiers. Unlocks never give raw stat power over the base roster.
- **Campaign: "Last Week at Camp"** (after the rest is stable): five linked
  nights, camp damage and injuries carry over, each night adds a region and a
  story beat, and the final night uses the Ranger Gate finale.

## Pacing metrics for playtests

Record these per human playtest (automation alone does not prove fun):

| Metric | Target |
| --- | --- |
| Round length | 40–60 min (expedition) |
| Time from leaving camp to first threat sighting | ≤ 90s |
| Chases per survivor | one every 2–4 min in Nightfall and later |
| Relief window after a chase | ≥ 45s |
| Longest stretch with nothing new | ≤ 45s |
| Close calls (escaped chases) vs downs | ≥ 3 : 1 |
| Time from "where is X?" to a named-region clue | ≤ 3 min |
| Players saying they want another night | the real gate |

## Delivery order (F-track)

Each increment is runnable, verified in solo **and** two-peer co-op (the game
already has ENet authority), logged and pushed before the next one starts.

1. **F1 Navigation** *(implemented)*: skyline markers, junction signposts,
   wall-map region outlines, team map pins (M), second boltcutters + crowbar.
   Clue chains moved to F4: the pack already names each part's exact cache, so
   vaguer clues only make sense once objective regions rotate.
2. **F2 Night phases, dread and director** *(implemented)*: 60-minute phase
   clock, ranger-radio part reveals, dread, director with relief windows,
   phase supply drops, Storm Front and Blackout/generator, dread-scaled music
   with phase stingers, modest stalker escalation and dawn rescue. Deferred:
   distant-call/flicker build-ups, separate chase music layers (needs new
   licensed audio), and the Lost Camper, Hunt Begins and Stalker's Gift events.
3. **F3 Chase toolkit** *(implemented: F3a Wounded state, blood trail, medkit
   patch, kitless revive, downed crawl/help ping, solo self-recovery, flash-stun;
   F3b hiding spots with breath and witnesses, slam/break doors, knock-overs.
   Vaults move to F4 with fences)*: Wounded state, hiding spots and breath meter, doors,
   vaults, knock-overs, kitless revive, downed crawl/ping, solo self-recovery.
4. **F4 Ring-and-spoke map** *(F4a implemented: deterministic lit ring road
   through the three objective regions, four spokes to the map edges, lamps on
   camp power, roads printed on the field map, maze kept as thickets; measured
   18–30s walks to required regions. F4b-1 implemented: three caches rotate across eight regions in three
   directions each night, with corkboard → ranger note → region clue chain.
   F4b-2 implemented: region-side-latched shortcut gates with nav links, and
   vaultable fences on links with long detours. Shortcuts landed for 3 regions
   per night rather than one per spoke, where the trail geometry allowed a
   clean gate)*: rework the woods generator into hub/ring/spokes/
   thickets with unlockable shortcuts, rotating objective regions and the
   camp → field → building clue chains that point to them.
5. **F5 Escapes and new regions**: Radio Rescue first (Substation, Radio Relay
   Station), then Boat (Logging Camp, Lakeshore Boathouse) and Ranger Gate; escape finales.
6. **F6 Roles 2.0 and co-op actions**: active abilities, item passing, heavy
   items, two-person actions, ghost wisps, awards.
7. **F7 Killers and modifiers**: stalker tiers and sabotage, first new headline
   killer, night modifiers.
8. **F8 Meta**: score/grades, daily seed, journal, merit badges and unlocks;
   campaign after that.

F1–F3 come before proximity voice (M3-V). They change moment-to-moment play
the most, and voice should be tuned on the game it will ship with. Voice
can proceed in parallel once F3 passes. The user may reorder this track.

## Fairness and authority rules that still hold

- Host owns dread, director, phases, events, hiding, wounds, shortcuts, heavy
  carries, pins, scores and unlock grants; clients send intents only.
- No full-world radar, no creature reveals through trees, no unsensed targeting.
- Every threat has a visual tell that works with audio muted.
- Every required step is reachable solo by every role; two-person actions
  always have a slower solo path.
- No permanent route seals; shortcuts only add routes.
- Monsters may *displace* a part (stalker sabotage) but never destroy it; the
  displaced part is always marked to its region.
- Unlocks are local and cosmetic or side-grades; online lobbies validate
  unlocked role IDs against the host's ruleset version.
