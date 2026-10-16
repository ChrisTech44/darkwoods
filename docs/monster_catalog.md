# Monster catalog: 48 additional encounter concepts

Status: **seven additional offline monster types implemented as first versions**.
The playable build has the stalker and 16 cryptid species. New additions are
Switchback Hound, Bramble Seamstress, Stoneback Ram, Shutter Wraith, Candle
Grazer, Boiler Saint and Last-Car Conductor. Their bounded current behaviors
are documented in [content update](content_update.md); the detailed powers below
remain design targets where they differ. Expedition retains 48 cryptids plus
the stalker. The rest of these 48 concepts remain backlog, for 55 total designs.

Read [biome design](biome_design.md) for encounter spaces and
[survivor/co-op plan](survivor_multiplayer_plan.md) for progression. Entries are
alternatives for seeded encounter sets, not 48 extra simultaneous hunters.

Relay Jackal, Ration Moth and Lens Eater now also have roaming first versions;
see the current [README monster guide](../README.md#know-what-is-following-you).

## Rules every monster must obey

- A unique ability must change a decision: where to step, when to move, what to
  carry, which route to take or how to rescue. Faster recolors are insufficient.
- Pair sound with a visible tell; muted/no-device players can still react. Calls
  remain proximity-gated and attenuated. No global roar revealing a distant
  threat, or audible identity cue used as a substitute for current line of sight.
- Trees/solid walls block vision and flashlight spill. Neither powers nor HUD
  markers expose hidden trails/enemies. Sensor exceptions require bounded,
  explicit stimuli such as a recently disturbed web, never an unsensed position.
- No instant hits from hidden spawns, spawning inside players, uninterruptible
  chains or permanent debuffs. Proposed initial minimum attack tell is 0.8s;
  tune with real play. Leave a recoverable route and a post-attack window.
- Ordinary movement and observation provide counterplay for every role and solo
  player. No mandatory archetype, consumable, second human or microphone.
- A future encounter director reserves safe approach space near camp exits,
  required caches and the van; the exact radius needs simulation/playtesting.
  New blocking powers may never cut every required route. Reject illegal casts
  rather than silently trapping players. Boarded survivors remain safe.
- Default new contact attacks follow the existing down/second-hit rule. Added
  slow/fear/drain effects are short, capped and non-stacking; never immobilize a
  downed actor indefinitely. Monsters cannot destroy required components.
- Host owns senses, state, hazards, timers and outcomes. Replicate telegraph
  start/impact/expiry with stable event IDs, not client-local random decisions.
  Cleanup on death/despawn/restart; late packets cannot resurrect hazards.
- Keep AI state and work bounded. Add one primary power per first prototype;
  expensive path edits, dynamic occlusion and multi-entity powers are later
  experiments with explicit performance tests on the giant forest.
- All mimicry uses authored original/licensed effects, never player microphone
  recordings, forged peer names or fake platform permission/system messages.

## Overhaul amendments to these rules

The [gameplay overhaul plan](fun_overhaul.md) (planning, not implemented) changes
three rules above once its slices ship: contact attacks first **Wound**, then
**Down** (F3); the stalker may **displace** one installed part per night but
never destroy it (F7); and a host-owned **director** may steer existing roamers
toward the survivors' general band using only sensed information, with relief
windows and no in-sight spawns (F2). Every other rule still applies.

Heart-pounding goals for every new or reworked monster:

- **A build-up before the peak**: distant call → nearby sign (tracks, broken
  branches, flickering light) → visible tell → attack. Close calls should
  outnumber downs about 3:1 in human play.
- **Interaction with the chase toolkit**: state whether it checks hiding spots it
  saw you enter, breaks or ignores doors, can be vaulted away from, and is
  affected by knock-overs or flash-stun. Variety here matters more than stats.
- **A phase personality**: how it behaves differently in Witching Hour.

## Stalker escalation and headline killers

The current stalker becomes the first **headline killer**, the night's main
antagonist. Planned for **F7**, with tier changes driven by night phase:

| Tier / phase | Stalker behavior |
| --- | --- |
| 1 Dusk | Quiet camp sweep; does not chase beyond the inner ring. |
| 2 Nightfall | Hunts loud noises across the inner ring and spokes; checks hiding spots it saw used. |
| 3 Deep Night | Search memory +50%; **Sabotage** once: when no survivor is within 300px of the van, it pulls one installed part (van alarm, open hood visible from camp) and carries it to a named region, where it lies marked. |
| 4 Witching Hour | +10% chase speed, breaks doors 1s faster, cuts camp power once if the generator is unguarded. |

Further headline killers rotate by seed (one per night; two only under the rare
*Hunter's Moon* modifier). Each has original design, tells and counterplay:

| ID / killer | Rule that changes how you play | Tell | Counterplay and limits |
| --- | --- | --- | --- |
| H01 **The Groundskeeper** | Sets visible snare traps on trail segments survivors used repeatedly (max 4 active), and rakes leaves to hear footsteps on raked paths. | Snares glint in flashlight within 90px; rake sound nearby; fresh raked patches. | Walk around or disarm (2s, quiet); a teammate frees a snared survivor in 1s. A snare holds 4s solo, never indefinitely. |
| H02 **Smiley, the Camp Mascot** | Moves only while no survivor is looking at it within light or line of sight; very fast when unseen. | Squeaking costume feet; stops mid-pose when lit; grin glows faintly. | Keep a beam on it while backing away; teammates take turns watching. Cannot attack while observed. Flashlight drain is the pressure. |
| H03 **The Drowned Counselor** | Travels through water and the lake; emerges near wet ground with a 1.2s splash tell; hunts the Boat escape heavily. | Dripping footprints appear before it does; whistle call. | Stay on dry boardwalks and stone; it is slow on dry land. Never emerges inside buildings. |
| H04 **The Lantern Warden** | Carries a large lantern; anything in its light is seen at long range; it extinguishes flares it reaches. | Swinging pool of warm light visible from far, which helps you track it. | Stay in shadow, use thickets; flash-stun dims its lantern for 4s. |

The **Lake Thing** in the Boat finale is the Drowned Counselor's landmark
encounter when H03 is not the headline killer: a bounded hold-out pressure
(splash tells at the boathouse ramps), not a free-roaming hunter.

## A. Pursuers and movement traps

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M01 **Switchback Hound** | After seeing a survivor turn a corner, commits to a fast dash toward the last visible position along the next reachable segment. | Claws scrape; shoulders flatten and a short dust streak marks the launch. | Change direction after the tell; it cannot steer or sense through walls during the dash and must recover. | Quarry, outer trails |
| M02 **Bramble Seamstress** | Threads a temporary low tripline between two visible anchor bushes after watching a survivor use a junction. | Needle glint and swaying strands at ankle height. | Walk through slowly or take the open branch; never seals the last route. No invisible lines around corners. | Orchard, burn scar |
| M03 **Stoneback Ram** | Charges a straight lane and stuns itself on existing solid scenery. | Three hoof stamps, lowered stone horns and dust. | Sidestep into an alcove; bait it into a wall. It cannot smash collision, cache doors or camp borders. | Quarry, storm ridge |
| M04 **Ditch Skipper** | Leaps between marked ditch landings, bypassing a local obstacle but not the forest perimeter. | Reeds bend at takeoff; the destination shows scattering pebbles before landing. | Leave the landing disk; it pauses after impact. Host validates both landings and clearance, with no wall-crossing hit. | Bog, flooded mill |
| M05 **Ash Runner** | Repeats the last three visible movement segments as a delayed sprint, leaving brief hot footprints. | A cinder outline retraces the observed route. | Break sight then choose a different return lane; short-lived footprints do not stack or block the only exit. | Burn scar, kilns |
| M06 **Pendulum Huntsman** | Sweeps a hanging hook across a fixed open arc instead of chasing directly. | Chain rattles and the hook draws back, with visible ground sweep markers. | Pass after the sweep or circle the hinge; never attacks through props. Short leash around its anchor. | Rail yard, mill |
| M07 **Burrow Knocker** | Follows recent sprint vibrations to a disturbed patch, then surfaces after a delay. | Moving dirt mound and three localized knocks. | Walk away from the marked patch; underground travel cannot target stationary unsensed survivors or emerge under cabins. | Mycelium hollow, orchard |
| M08 **Relay Jackal** | Places a scent post at its last sighting and checks the next nearby junction before returning. | Raised tail, a visible scratched post and a short bark. | Reverse or take another loop; its ambush uses a bounded last-sighting hypothesis, not the player's current hidden position. One post per jackal. | Outer forest, rail yard |

## B. Light, darkness and perception

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M09 **Shutter Wraith** | Advances in short steps only while no survivor has unobstructed light on it. | Camera-like click and a contracting silhouette before each step. | Briefly illuminate it, then use the pause to move; full-speed normal retreat remains possible with an empty battery. No teleport through trees. | Observatory, village |
| M10 **Prism Leech** | Reflects a lit beam into two harmless decoy silhouettes while its real body crawls sideways. | The real body casts a consistent shadow; decoys shimmer out of sync. | Sweep the beam and read the shadow; decoys never gain collision or create false damage. | Glasshouse, reservoir |
| M11 **Candle Grazer** | Approaches a visible unattended flare, consumes it slowly, then briefly glows and becomes easier to track. | Wick crackle and amber veins along its ribs. | Leave while it feeds or retain the flare for a better moment; it cannot consume inventory or every light source. | Chapel, graveyard |
| M12 **Blackglass Widow** | Places a local dimming film across an already visible floor patch. | Oily rectangular sheen and raised legs before casting. | Take the uncoated lane; silhouettes and attack tells remain readable. Film cannot remove collision cues or the player's sight mask. | Glasshouse, quarry |
| M13 **Dusk Shepherd** | Slowly pushes a small fog bank toward a recently seen survivor to shorten an open sightline. | A crooked staff swings; fog edge curls visibly. | Move perpendicular to the bank; it is bounded, temporary and cannot reveal or erase terrain. Does not stack with weather into total unreadability. | Bog, storm ridge |
| M14 **Afterimage Doe** | Leaves a glowing frozen decoy when it breaks sight, then runs to a nearby valid retreat point. | A doubled hoofbeat; decoy has no moving shadow or breathing. | Observe briefly rather than spend a flare; the real animal must traverse a legal route and cannot attack out of the decoy. | Orchard, ice hollow |
| M15 **Lens Eater** | Winds up a narrow flash that temporarily reduces flashlight efficiency if faced directly. | Expanding iris and a visible cone on the ground. | Turn or sidestep; recovery is automatic and never breaks the lamp or drains all charge. Use a low-contrast pulse, not a strobe. | Observatory, glasshouse |
| M16 **Starless Surveyor** | Draws a short dark measurement line; crossing during its active window alerts it and starts a deliberate approach. | A glowing plumb bob moves between endpoints. | Wait for expiry or use another path; the line cannot extend through trees, across every exit or beyond nearby visibility. | Observatory, ridge |

## C. Sound, decoys and misinformation

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M17 **Bell Widow** | Repeats the last nearby accepted bell stimulus once from its own position, drawing ordinary investigators. | Its throat opens like a bell; dust pulses on the beat. | Move before investigating; repeated bells share a capped stimulus budget and cannot chain themselves. | Village, chapel |
| M18 **Trail Ventriloquist** | Throws an authored branch-snap cue to one reachable nearby point and circles the resulting distraction. | Jaw remains open; loose leaves point toward its real exhale. | Verify movement visually, stay off the obvious bait lane. No player-voice imitation or forged ally markers. | Orchard, outer woods |
| M19 **Echo Taxman** | Stores one recent loud environmental stimulus and re-emits a weaker echo after a delay. | A chest cavity swells and clicks down visibly. | Relocate after loud interactions; it can replay neither another echo nor microphone speech. One stored event, expiring quickly. | Quarry, rail yard |
| M20 **Hush Collector** | Creates a short-radius muffling pocket that suppresses cosmetic ambience but exposes its own footsteps visually. | Hanging cloth stops moving; pale rings mark the pocket edge. | Follow ripples/animation and leave the circle. Never mutes player voice, controls or essential telegraphs; AI hearing rules stay explicit. | Chapel, graveyard |
| M21 **Tin Choir** | Several small tin creatures coordinate a countdown; the final beat attracts a roaming hunter to their nest. | Each can visibly shakes in sequence and flashes a painted symbol. | Leave the nest's lane or interrupt their exposed leader with an ordinary interaction during the tell. Strict cap on summoned investigators. | Funfair, rail yard |
| M22 **Sleeper in the Wall** | Knocks after hearing repeated activity in one building, then attacks through an open doorway. | Dust falls around the actual doorway, with knocks growing closer. | Use another exit or wait out its short attention span; never attacks through a wall or locks a single-exit cabin. | Village, mill |
| M23 **Reed Piper** | Starts a periodic sound lure from a reed nest; approaching close triggers an outward dart. | Reeds sway against the wind; a moving throat sac marks the source. | Pass along the side and dodge the obvious dart lane; darts collide with cover. No input override or forced walking. | Bog, reservoir |
| M24 **Creak Cart** | A crawling cart moves only after a nearby loud stimulus and coasts down a fixed route. | Wheels twitch, axle winds back and a track stripe brightens. | Avoid repeated sprinting on the track; step into a recess while it rolls past. Cannot turn sharply or permanently block a trail. | Mill, rail yard |

## D. Terrain, snares and territory

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M25 **Root Bailiff** | Raises a root rib on one branch of a junction after seeing the survivor enter. | Soil splits along a clearly marked line before the rib rises. | Take the open branch or wait for roots to subside. Connectivity check rejects a cast that cuts all escape/objective routes. | Orchard, mycelium hollow |
| M26 **Silt Bride** | Makes a small muddy patch grip sprinting feet more strongly than walking feet. | Two hands churn the marked water; bubbles move inward. | Walk through or take dry stones; slowdown is capped, ends on exit and cannot disable movement. | Reservoir, bog |
| M27 **Gravel Maw** | Opens a conical sink in loose gravel while remaining anchored in its center. | Pebbles climb uphill, then a visible rim forms. | Circle the rim; the pull is weak enough to walk out, with no teleport or unavoidable fall death. | Quarry |
| M28 **Rafter Spider** | Descends along a visible thread to briefly occupy a doorway. | Thread oscillation and a ceiling shadow appear before descent. | Back away or use the other doorway; it retracts on a fixed timer and cannot block a building's only entrance. | Mill, village |
| M29 **Rust Gardener** | Plants clattering scrap tripods that alert it when disturbed. | Metal scraping and reflective dangling tags. | Walk around or hold interact to dismantle a visible tripod quietly. Limited count; no traps under pickups or inside spawn/boarding space. | Rail yard, kilns |
| M30 **Rime Weaver** | Coats a short surface strip with ice; sprinting causes a small predictable slide. | Frost creeps from its feet and the strip gains directional grooves. | Walk across; steering never reverses, and sliding cannot carry players through collision. | Ice hollow |
| M31 **Mire Lantern** | Moves a tempting false lantern over unsafe shallow muck, then retreats when approached. | Reflection appears offset from the hanging light. | Follow established boardwalk edges; it never creates fake objective icons or asks players to enter lethal water. | Bog, reservoir |
| M32 **Gatekeeper Stag** | Occupies one threshold and challenges a direct sprint with a short antler sweep. | Hooves mark two retreat lines; antlers rise slowly. | Approach walking, back out and circle during recovery. Never owns all exits or the van interaction point. | Graveyard, orchard |

## E. Resource pressure and risky bargains

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M33 **Battery Barnacle** | A nearby stationary parasite drains a small capped amount of flashlight charge only while directly illuminated. | A crackling tether is visible along the beam. | Switch off, sweep past quickly or step out of range; cannot steal spare batteries, affect camp-safe charging or require a battery to escape. | Observatory, reservoir |
| M34 **Pantry Imp** | Guards an optional supply crate and lunges only after its clearly marked latch is disturbed. | Tiny fingerprints and breathing from the crate seam. | Ignore the optional crate or retreat from the tell; required component caches never use indistinguishable mimic lids. | Village, funfair |
| M35 **Ration Moth** | Follows the last accepted ration-use position and circles there before searching. | Torn paper wings and a visible cloud over the old position. | Eat before moving, then leave quietly; it senses the event, not hidden inventory or current location. | Orchard, apiary |
| M36 **Flare Smuggler** | Carries a spent flare and can snatch one unattended burning flare, relocating the light to its nest. | Fingers spark and the flare drags an obvious ember trail. | Track the carried light or leave in the opposite direction. Never steals held supplies, and a transferred flare retains its original lifetime. | Funfair, kilns |
| M37 **Tollkeeper** | Guards a shortcut and offers a visible optional ration-for-passage interaction. Refusing triggers a slow patrol, not instant damage. | An outstretched bowl, a marked toll sign and a clear patrol lane. | Use the free longer loop or pass during patrol recovery; no payment needed for required objectives and no irreversible inventory debt. | Rail yard, quarry |
| M38 **Leech Matron** | Shoots a slow attached leech that briefly increases stamina use until brushed off with a short stationary interaction. | Belly inflates; the projectile and attachment are visible. | Sidestep or use cover; attached drain is capped and expires automatically. Never drains below zero or forces a teammate rescue. | Bog, reservoir |
| M39 **Cinder Miser** | Hoards optional supply bundles; opening a hoard wakes it and brightens the surrounding ash. | Visible glowing ribs beneath a clearly different hoard container. | Choose the loot risk, leave by the second path; never hoards or consumes a required component. | Burn scar, kilns |
| M40 **Clockwork Caretaker** | Rewinds its own short patrol once when it hears a supply interaction, revisiting previously safe space. | Exposed gears rotate backward; its last route gets a brief local dust trail. | Wait for the replay to pass or use another branch. Only its movement history rewinds; no player/item/round state is reversed. | Funfair, observatory |

## F. Landmark guardians and coordinated encounters

| ID / monster | Unique ability and trigger | Nearby tell | Counterplay and limit | Home |
| --- | --- | --- | --- | --- |
| M41 **Grave Procession** | Three linked silhouettes cross cemetery lanes on a fixed cycle; disturbing their leader makes the line turn once. | Shrouds sway in sequence, with three distinct ground shadows. | Cross behind the last figure or use the grave aisle. One encounter budget covers all three; they cannot surround a downed player. | Graveyard |
| M42 **The Empty Bridegroom** | Marks one survivor it can see, then slowly approaches the last observed spot; crossing a chapel threshold ends the mark. | A broken corsage glows on both enemy and local marked-survivor UI. | Break sight and use a reachable threshold; mark also expires, so the chapel is never mandatory. No tracking beyond last sight. | Drowned chapel |
| M43 **Honey Regent** | Directs a small bounded swarm between two visible hive anchors, temporarily making one lane costly. | Wings gather into a visible ribbon before moving. | Use the open lane, wait or walk behind the swarm; never fills every entrance or becomes an unbounded particle/AI army. | Apiary |
| M44 **Mirror Pair** | Two linked creatures alternate active pursuit; the inactive one becomes a visible inert shell. | A silver pulse travels between them with a clear handoff delay. | Reposition during handoff and distinguish the active shadow. One active attacker, shared cooldown; either shell cannot hide behind an unseen damaging double. | Glasshouse, funfair |
| M45 **The Boiler Saint** | Vents hot steam from one pre-marked pipe after a loud interaction near its boiler. | Gauge swings into red, pipe vibrates and a narrow steam outline forms. | Use the dry lane or wait; pipes never seal all approaches. Steam ends promptly and cannot damage through walls. | Flooded mill |
| M46 **Rain Antler** | During rain, follows newly formed puddle ripples from recent fast movement, then releases a radial splash. | Water beads lift toward its antlers and a ring expands before impact. | Walk, leave the old ripple location and step outside the short ring. Dry-weather fallback is ordinary sight, not omniscience. | Storm ridge, reservoir |
| M47 **Spore Parliament** | Rooted fungal heads vote in a visible sequence on one nearby path to briefly cover with spores. | Heads light one at a time; the chosen floor patches swell. | Watch the sequence and use the other branch. Heads share one timer/entity budget; spores do not hide walls or erase the explored map. | Mycelium hollow |
| M48 **Last-Car Conductor** | After the player rings an optional rail signal, travels between two marked platforms and conducts a timed inspection sweep. | Hand lamp rises and platform lamps announce which lane comes next. | Stay in recesses or cross behind the sweep; signal is optional, sweep has a maximum duration, and required loot remains reachable without summoning it. | Rail yard |

## Combinations worth testing, and combinations to prohibit

**Interesting pairs:** Switchback Hound + Root Bailiff creates a visible choice
between a committed dash and an open side branch; Candle Grazer + lantern moth
makes throwing a flare a deliberate light-management decision; Echo Taxman +
Sasquatch punishes staying at a noisy cache rather than arbitrary silence;
Mirror Pair + Lens Eater makes beam direction matter while preserving a retreat.
Each pair needs solo testing before co-op; their shared pressure must stay below
the director's budget, and each must retain its own tell and recovery window.

**Prohibit initially:** Root Bailiff + Rafter Spider on the same choke; Silt
Bride + Rime Weaver on one surface; Hush Collector masking another monster's
only warning; Tin Choir recursively summoning more choirs; resource parasites
stacking charge/stamina drain; multiple light-denial creatures in a required
single corridor; any guardian camping the van or a downed survivor. Shared
crowd-control resistance should prevent a fresh slow from extending an existing
slow indefinitely. Avoid three-or-more power combinations until measured.

## First prototypes and evidence gates

1. **Flooded Mill + Boiler Saint:** a fixed landmark and visible pipe lanes;
   test host-owned timed hazards without editing the navigation graph at runtime.
2. **Orchard + Bramble Seamstress:** introduce readable optional tripline paths;
   prove alternate-route preservation and normal-speed solo counterplay.
3. **Observatory + Shutter Wraith:** test shared observation, light battery
   economy and per-player sight without ever seeing through solid trees.
4. **Rail Yard + Last-Car Conductor:** an optional activated encounter with
   synchronized sweep state, completion/expiry and repeat/abuse rejection.

These are prototypes after the survivor/human-baseline gates, with network
integration after M2/M2-A stabilizes. The other 44 remain a concept pool, not a
promise to ship in the next increment. Voice is not a prerequisite.

For every prototype preserve: fixed seed/biome variant, config/version, graph
reachability, attack tells with audio muted, line-of-sight/flashlight checks,
interrupt/expiry/reset behavior, solo and four-player counterplay, synchronized
effects exactly once, and frame/CPU/network measurements with the agreed roster.
Use genuine graphical captures and human listening/play evidence. No new monster
sprites, audio assets, physics, online sessions or acceptance results are created
by this planning document.
