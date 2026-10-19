# Four-survivor overhaul: Christian, John, Max and Alex

19 October 2026. **Four-role implementation and maintained design.**

The playable roster now uses Christian, John, Max and Alex in place of Jock,
Mechanic, Scout, Medic, Quiet and Quartermaster. Existing art is a prototype
stand-in; it does not claim to depict the real friends. This
document records the selected direction and the later Christian amendment;
previous conversation pitches are not additional abilities. The implementation defaults below are executable values; human balance
acceptance remains pending. Target-only differences are called out explicitly.

## Implementation status — 19 October

- Four IDs, four selector/lobby choices, prototype art mapping, saved-role
  reselection and common baseline stats replace the old six roles.
- John: 6s window / 45s cooldown; once-only preparation credit on all five routes.
  Deferred damage uses normal hit grace, effective wound/grab eligibility, and
  settles before boarding/extraction. Existing downed-team rescue is preserved.
- Max: starts at $6, cap $100; searches +$4 and per-thieving-creature first
  recovery +$3; tap buys for $4. Holding raises affordable whole stakes to $8/$12;
  a gamble has 45% bust, otherwise 2/4/6 ordinary supplies. Hits spill one third
  of current cash (minimum one when nonzero), recoverable for its owner.
- Alex: isolation enters beyond 190px after 4s, leaves within 150px; light drain
  x0.75 and stamina recovery x1.35. Marker 75s, channel 2s, success cooldown 40s,
  interrupted/blocked retry guard 2s. Channels retain harmful attachments and
  reject tethers/blocked landings; position changes use authority motion epochs.
- Christian: one sample; source encounter survival window 3s with a 50s pending
  limit, one acquisition per actor/source creature per round. Forms last up to
  10s; secondary pounces have 3s cooldown. Most copied AI statuses cap at 6s;
  headline sensory disruption caps at 2s, with no frog/hold-lock on the Stalker.
  Activations have warnings and finite cleanup; sample casts cannot earn samples.
- Protocol is `lnac-net-19`. Host RNG, cash receipts/spills, sample state and the
  compact movement projection replicate; clients cannot award these outcomes.

Current implementation differences to assess explicitly: creature slime uses a
movement modifier rather than the full survivor skid controller; creature Float
and Backwards alter navigation, rather than applying player input transforms;
Conductor carries Christian only (no passenger system); copied Owl transport is
short and needs E consent for a survivor; full per-species tuning/playtesting is
pending. These are specified target adapters, not universal stun substitutes.
Mimic fools unalert creatures beyond close-inspection range while preserving
truthful map identity; it does not override the headline Stalker's recognition.

Implementation evidence: [checks and graphical captures](evidence/four_survivors/README.md).
The final complete runner passes 218 steps; survivor/prediction suites pass
144/81 checks. Two/four-peer listen-host and dedicated loopback gates pass.
These scripted gates do not replace human balance or cross-machine acceptance.

## Design intent

Four friends should produce four different decisions in the same dangerous
forest. Christian seeks dangerous experiences to experiment with; John stays to
finish the objective; Max risks safety for money; Alex ventures too far because
he trusts his own escape plan. Strength and drawback must come from that same
personality, rather than unrelated stat penalties.

| Character | Passive | X ability | Personal temptation / drawback |
| --- | --- | --- | --- |
| Christian | **Bad Research:** survive a creature encounter to collect its signature sample | **Field Test:** reproduce that creature's power, including transformations and area effects | Getting samples requires dangerous curiosity; experiments can affect friends and himself |
| John | **Making Progress:** completing a preparation step refills stamina | **Push Through:** defer incoming damage and its ordinary hit reactions briefly | He can finish the job, then collapse when the damage lands |
| Max | **Finder's Fee:** optional searches and stolen-gear recovery award cash | **Cash Out:** purchase an ordinary supply or risk more money for a larger random payout | Damage spills money; greed tempts him to return for it |
| Alex | **Travel Alone:** better light economy and stamina recovery while isolated | **My Own Way Back:** place a temporary marker and channel a return with current gear | Damage interrupts; grabs/downing prevent return, leaving him dependent on a rescue |

Everyone retains basic movement, flashlight/flash, supplies, tool use, collection,
installation, vaulting, hiding, teammate help and reviving. Each character must
be viable alone and useful with any available escape. A particular character is
never a required key. The four exclusive systems are samples, deferred damage,
cash and isolation/return markers. Christian's temporary borrowed powers may
share ordinary outcomes with other gameplay; they do not grant another player's
passive, economy or permanent signature kit.

## Christian — I Want to Try Something

### Bad Research and Field Test

Christian carries **one sample**, outside the six-slot supply belt. Its source,
effect and readiness appear beside X. Pressing X uses that sample in the direction
he faces, around him, or as a temporary transformation, according to its type.
There is no creature-selection screen, palm-choice interface or catalogue to
browse during play. The current sample determines the next experiment.

Samples come from actually resolving an eligible creature encounter alive, not
reading a guide or querying hidden enemies. A host-side encounter record must
prove exposure to its signature: receiving and surviving an effect, escaping a
hold, or witnessing and surviving the complete local warning/attack sequence.
Harmless creatures need their characteristic interaction to finish. Exact exposure
windows and repeat-source limits are tuning items. Simply standing near a hidden
creature, taking repeated generic damage, or recovering from a down does not
mint samples. A full slot keeps its current sample instead of silently replacing
it. Player-created experiments cannot generate more samples.

**Field Test is broader than throwing a bottle.** It can emit an attack, produce
a temporary effect, or transform Christian. The source's distinctive rule and
liability must remain recognizable. Do not reduce every sample to generic damage
or stun. Every use has a readable warning and a finite lifetime. Transformation
movement uses the ordinary movement keys; X during a form performs its displayed borrowed action, such as a pounce,
on a bounded cooldown. It cannot consume another sample or extend the form.

### Required special cases

**Werewolf:** using its sample while the game's existing moon flag is active
transforms Christian into a temporary werewolf. He gains its forceful pounce and
ability to burst breakable doors, with a howl, altered silhouette and dangerous
contact along the pounce. Friends can be knocked over too. The transformation
ends when its duration expires, the moon is obscured, or wolfsbane suppresses it.
Outside moonlight, X reports that the sample needs the full moon and does not
consume it. Blood Moon uses the same actual moon state, not a new independent
calendar. Transformation cannot install parts, board the van or operate escape
machinery; carried objectives remain attached to Christian and drop normally
if he is downed. It provides no duplication, free heal or universal immunity.

**Paparazzo:** Christian winds up and produces the camera flashbang. **Everyone
facing the burst in range with clear sight can be blinded**, including teammates.
Christian also receives a brief self-whiteout from firing it; do not silently
make him immune to his own experiment. Turning away or getting behind solid cover
is the counter for other targets. Eligible creatures need an
explicit blindness/search-disruption adapter; a survivor's white overlay alone
cannot blind AI. Photographing exposed survivors also sends their locations to
the Stalker, retaining the source's dangerous photo-delivery consequence.
This is not an unconditional area stun, and it does not bypass the Scarecrow's
watching rule. Source reference: [Paparazzo brain](../scripts/ai/brains/shutter_wraith.gd).

### Creature effect catalogue

All 30 rows below have activation handlers and source encounter hooks. The
implementation includes explicit survivor/AI adapters; per-species balance and
human playtest acceptance remain separate from the scripted activation checks. The species IDs match current brain files;
they are not additional creature spawns. Acquisition follows the encounter rule
above, with explicit per-species completion hooks.

| Source / species ID | Field Test effect | Chaos, limits and counterplay |
| --- | --- | --- |
| Witch / `witch` | Fire a bolt reproducing the sampled curse: Frog, Backwards, Swap or Float | Preserve the sampled subtype. Frog transformations can disable eligible creatures briefly; survivor targets retain their existing curse rules. Swap needs two valid local targets and cannot move machinery or invent a partner; no valid targets means no consumption. Salt reflection and friendly fire need defined ownership. |
| Werewolf / `werewolf` | Transform during the full moon, howl and pounce through breakable doors | Moon, wolfsbane, duration and friendly collision rules above are mandatory. No manual invulnerable wolf mode outside the moon. |
| Paparazzo / `shutter_wraith` | Wind up and flashbang everyone facing the visible burst; photograph exposed survivors | Teammates can be blinded and reveal their locations. Facing, range, walls and AI blindness rules above are mandatory. |
| Puffball / `ration_moth` | Throw a swelling spore cloud: helium/squeaky voice and repeated sneezes | Friends and Christian can inhale it; standing still to hold breath remains a counter. Affected creatures need audible sneeze plus AI-hearing emission to make them noisy distractions. Voice modification only when voice is already opted in. |
| Seamstress / `bramble_seamstress` | Throw a thread that tethers two eligible nearby bodies, or one to the ground | Friends can be stitched; scissors, finite duration, solid-world collision and territorial bounds remain relevant. A creature tether is new gameplay code, not the existing player-only effect reused blindly. |
| Vampire / `vampire` | Briefly emit a directed hypnotic pull while maintaining gaze | Turning a beam on Christian breaks his concentration. Friends in the cone can be pulled too. No blood-drain healing or permanent creature control. |
| Bigfoot / `bigfoot` | A close-range grab-and-throw aimed along Christian's facing | Collision limits the landing; allies are eligible and can drop held gear. No throws through solid walls or forced placement in water. |
| Scarecrow / `briar_revenant` | Temporary scarecrow form: rapid movement while unobserved, frozen while watched | Actual observers, light and walls determine watching; teammates can accidentally freeze him. No objective interaction during form and no normal sprint layered onto it. |
| Lantern Moth / `lantern_moth` | Release a face-clinging moth at the first eligible body on a visible short trajectory | Obscures survivor sight and drains their light; eligible AI suffers reduced visual sensing. Friends can be caught. Flash/spray counters and a lifetime cap apply; no autonomous permanent pet or hidden-target tracking. |
| Snuffer / `candle_grazer` | Carry a temporary darkness bubble that switches off nearby flashlights and extinguishes ordinary flares | Christian and teammates lose light too; glow moss remains the counter. Installed rescue signals and prepared objective state are not deleted or refunded. |
| Buster / `switchback_hound` | Bark at the aimed visible creature/location, drawing the Stalker's investigation there | A sensed-location report, not a hard aggro transfer or teleport. The bark also exposes Christian's general position to nearby listeners. No fabricated hidden-target coordinates. |
| Peeper / `lens_eater` | Lock one visible eligible target in a staring contest | Christian must maintain the stare and also stays still. Breaking the sight line or a flash ends it; not a free hold while he loots. |
| Conductor / `last_car_conductor` | A short ticket ride between existing valid Rail Yard/camp stops | The train-ticket rule selects the destination; it can send Christian somewhere inconvenient. Uses fixed stops, no persistent personal marker, no self-rescue while held. Linked passengers require consent. |
| Mimic / `mimic` | Briefly copy a present teammate's appearance and displayed disguise name | Real team-map identity stays truthful. Close inspection exposes him; creatures with direct evidence can identify the deception. No identity/account impersonation or new microphone capture. Solo uses a generic survivor disguise. |
| Night Owl / `owl` | A brief talon lift and local carry/drop of an eligible body | Capped range, safe landing and breakable hold; flares can force release. Allies opt into deliberate transport. No free flight over the whole maze or carriage into extraction. |
| Bog Hands / `bog_hands` | Place a visible bubbling mud patch that temporarily holds a body stepping into it | Mash/pull/flare counters apply. Friends can be caught. The player variant releases at expiry; it does not instantly down a creature or silently inherit the source's sinking execution. |
| Toadstool Imps / `imps` | Trip a nearby target and knock loose one eligible carried object | Equipment is transferred or dropped exactly once. Cannot manufacture loot from creatures that carry none. Friends can spill supplies. |
| Bear Hug / `teddy` | Enter a committed close-range hug with one target | Christian is also occupied and vulnerable; escape/flash counters and a duration cap prevent indefinite holding. No holding a guardian outside its territory. |
| Groundskeeper / `groundskeeper` | Brief mower form/ride with forward headlight, momentum, wide turns and run-over shove | Cannot turn tightly; walls stop it and friends can be bowled over. No permanent vehicle spawn or repair-part grant. Reuse the existing mower art, not a vehicle-selection screen. |
| Cuckoo / `cuckoo` | Three audible calls then snap one visible target to its own recent recorded position | Target breaks sight or flashes Christian to cancel. Relocates position only: no health, inventory or objective rewind. Cannot target Christian himself or create Alex's personal return marker. |
| Banshee / `banshee` | A warned scream that deafens survivors and disrupts eligible creatures' hearing temporarily | Everyone in the visible radius can lose audio warnings, including friends and Christian. No blanket stun. Visual accessibility tells remain. |
| Slug / `slug` | Leave a short glistening slime trail with slippery acceleration and turning | Christian and friends can skid; salt clears it. Finite footprint/lifetime, no permanent path obstruction. |
| Surveyor / `surveyor` | Emit a local disorientation pulse | Survivors suffer LOST; eligible creatures lose their current navigation target and search locally, rather than receiving a fictional player map. Notes/proximity recovery remain survivor counters. No revealing unexplored terrain. |
| Hitchhiker / `hitchhiker` | Attach a temporary spectral passenger to a target, slowing it and flicking its light off if it has one | Contact can pass it between eligible bodies. Christian can receive it back; no permanent possession or stolen inventory. |
| Tollkeeper / `tollkeeper` | Mark a small temporary toll circle; compatible roaming creatures pause to inspect/pay passage in time | The toll is a brief hesitation, not new cash, stolen objective parts or an impassable barrier. Allies can cross but crossing breaks the effect early. Boss/territorial exceptions are explicit. |
| Echo / `echo` | Place a short-lived false camp-song emitter at a reachable visible point | Creatures investigate only if their senses support it. It can confuse the team's listening and attract the Stalker; nearby light disperses it. |
| Fortune Teller / `fortune_teller` | Deal Christian one random card using the existing beneficial/harmful card family | Light, stamina, health, named-region clue or penalties; no money, paid wager or reroll economy. Region clues follow existing knowledge rules, never exact hidden coordinates. |
| Lullaby Saint / `boiler_saint` | Sing a temporary drowsiness aura; stationary exposed targets can fall asleep | Moving and coffee counter it for survivors. Friends can fall asleep and snore; eligible AI needs a separate sleep adapter. Christian must remain exposed while singing. |
| Trash Jackals / `relay_jackal` | A close-range snatch that recovers one actually carried stolen object, or spills it at Christian's feet | No minted supplies, private inventory copies or bounty from repeated player-generated theft. A teammate target can drop an ordinary supply, making the misfire obvious. |
| Ram / `stoneback_ram` | A telegraphed straight charge with strong shove and breakable-door impact | Direction locks after the warning. Solid walls stop it; allies can be bowled over. Does not acquire a second activation or ignore collision. |

**Special sources:** the Stalker and Lake Thing are not ordinary sample rows.
Proposed Stalker sample: survive a real carry/escape encounter to bottle one loud
camp-song lure; it does not grant hook executions, favourite selection, free
teleportation, rage immunity or control of the headline killer. Proposed Lake
Thing sample: survive a dock strike and throw one warned ripple at a reachable
local point, with friendly fire and a small radius. Both require separate balance
acceptance before entering the normal sample pool; there is no implication they
already use the creature-brain pipeline.

### Target adapters and implementation boundaries

The current [hex projectile](../scripts/ai/hex_bolt.gd) checks survivors and calls
player curse behaviour; [Seamstress](../scripts/ai/brains/bramble_seamstress.gd)
also stores survivor-specific tethers. A monster becoming a frog, sneezing,
being blinded or sleeping requires explicit authority-owned support. Define for
each sample: acquisition event, effect subtype, shape/range, valid targets,
warning, duration, counters, immunity, friendly/self effect and cleanup. No generic
"apply player status to every node" implementation.

One sample and one active transformation/effect per Christian prevent stacking
wolf, mower and scarecrow forms. X commits one use, rejected casts consume
nothing, and end/down/disconnect restores the survivor body without healing or
copying inventory. No passive sample acquisition from Christian's own experiments
or another Christian's copies. Duplicate Christians cannot feed an infinite chain.

Durations and direct damage should be tuned for escape opportunities and chaos,
not clearing the entire creature population. Do not create permanent monster
kills, respawns or new score/cash farms as a side effect. Preserve territory and
physical bounds. The Stalker needs a specific resistance/counter policy for each
borrowed effect; do not silently turn every sample into a boss stun.

## John — Just Let Me Finish

### Making Progress

A completed, new objective preparation step performed by John refills his
stamina. The host records completion once per stable step ID; repeated E,
reinstallation, supply handoffs or reconnect do not award it again. Multiple
parts installed in one interaction give one effective refill, not stored charges.

| Route | Qualifying preparation |
| --- | --- |
| Van, including Quick Camp | Installing a required component |
| Radio Rescue | Installing the emergency fuse, completing transmission, loading each new signal |
| Boat | Installing motor, fuel or plug at the repair pad |
| Ranger Gate | Fitting each code fragment, restoring the shared substation, powering the gate breaker |
| Signal Fire | Installing each required kerosene can and flare gun |

Shared substation work has one event identity even in diagnostic all-route games.
Walking into an extraction zone, elapsed holdout time, collecting a part or
restarting the ordinary camp generator is not a new preparation step. John does
not accelerate the boat/radio/fire countdown or create a task that does not exist.
Installed progress still advances the night normally, with all its consequences.

### Push Through and the bill

For a short, visibly timed window, accepted incoming damage enters a deferred
ledger instead of being immediately subtracted. Ordinary associated hit reactions
are suppressed so John can finish moving or interacting. He remains vulnerable
to grabs, downing conditions outside ordinary damage, curses, traps, tethering
and task range/hold requirements. This is not immunity or a universal CC cleanse.

At expiry, apply the full outstanding damage once through normal down/drop
handling. Show projected remaining health and debt throughout; lethal debt must
be obvious. Deferred damage cannot be healed away before it lands. Proposed first
implementation rejects health-restoring consumables while debt is pending,
without consumption; exact healing UX is a tuning decision, not a loophole.

Existing hit-grace and ward rejection happen before adding debt, so a contact
cannot add damage every physics tick. Effective health (health minus debt)
informs wounded/grab eligibility: delaying damage must not bypass the Stalker's
wounded-target grab. A grab ends the burst and settles outstanding debt. Direct
health drains and forced downs require auditing; all damage sources need an
explicit inclusion/exclusion rule rather than bypassing the ledger accidentally.

Settle debt before boarding or final extraction eligibility; leaving a scene is
not a way to discard it. If settlement downs John, ordinary downed-team rescue
and solo-recovery rules still apply. Down/revive/disconnect cannot apply the same
debt twice or carry a stale lethal ledger onto a revived body. There is no
special protection for John after the job is finished.

## Max — That's Worth Money

### Finder's Fee

Max earns a small cash award from a completed optional stash search and a bounty
from first recovery of legitimately stolen supplies. Cash has a small counter
outside the belt; it is not a second six-slot inventory. It does not unlock
objective parts, tools, characters or real-money purchases.

Award on the authoritative accepted action, not proximity or client UI. Each
stash has a one-time reward identity. Recovery needs a theft/source/item identity
so drop/re-pickup, Max's own payout, a returned spill and Christian's copied theft
cannot generate cash. Repeat theft loops need strict caps. An empty/consumed
stash or rejected belt-full search awards nothing.

### Cash Out and loose pockets

Tap X for a fixed-price guaranteed ordinary supply. Hold X to raise a bounded
wager for a larger random payout; release commits the displayed cost. Always
show cost and possible outcomes before commitment. Exact pool, prices, odds,
hold threshold and maximum wager are tuning items. The gamble is not a hidden
mandatory tax on the guaranteed purchase.

Only ordinary supplies belong in the pool: never escape components, reusable
unlock tools, more cash or recursively profitable payout vouchers. Affordability
and one-shot commit are host validated. If a new supply type cannot fit on the
belt, use the existing reachable dropped-pickup path and tell Max where it landed.

An accepted hit spills a bounded portion of Max's bankroll onto reachable ground.
It is a recoverable cash pickup, not destruction of somebody else's resources.
Teammates can recover it for the owning Max; no new bounty or duplicated value is
awarded. Cash on down/disconnect follows one documented drop/ownership rule and
cannot survive in both player state and a world pickup. Multiple Max characters
have separate ledgers. His temptation is to go back for money when running away
would be wiser.

## Alex — I Don't Need Backup

### Travel Alone

After a sustained period genuinely separated from living teammates, Alex receives
reduced flashlight drain and faster stamina recovery. Use host positions and a
threshold with hysteresis: walking across a distance boundary must not flicker
the bonus or generate resources. These are rate modifiers, not free refill pulses.
The bonus fades near the group; downed, escaped, boarded or disconnected players
are not artificial proximity anchors. One-survivor play can qualify naturally.
Exact distance, activation delay, fade and rates need balance tests.

### My Own Way Back and overconfidence

X places one temporary marker at Alex's actual occupied, valid walkable position.
A later X, while alive, alone and able to act, channels a return to that marker.
Show marker lifetime, channel progress, destination and unavailability reason.
The world continues during the channel. Current gear travels with Alex; damage,
spent supplies, installed components and global phase progress are not rewound.

Damage interrupts. Held, downed, asleep or otherwise unable-to-act Alex cannot
use the ability as a breakout. The return grants no invulnerability, self-revive
or automatic ally rescue. If a tether/attached effect constrains travel, reject
an invalid return rather than silently clearing it. Returning cannot change
someone else's position, rescue a passenger or reset a creature.

Validate the destination again at arrival. A newly blocked or unsafe landing
fails clearly rather than putting Alex through collision or into water. Channels
stop on a hit, loss of isolation, expiry, round finish or invalid ownership.
Proposed cancellation leaves the marker only for its remaining lifetime, with a
retry guard; successful return consumes it and enters cooldown. Fresh markers
cannot refresh duration without respecting the same resource/cooldown budget.

The marker is a personal return point, not a hidden map scout. Placement reveals
nothing beyond ordinary exploration. A return updates known endpoint occupancy,
not an explored corridor through the intervening woods. Attached gear and harmful
effects remain current. Alex's benefit is reaching farther alone; his weakness
is being far away when his plan fails and somebody must come rescue him.

## Replacing the six current roles

The new roster uses stable proposed IDs `christian`, `john`, `max`, `alex`.
Replace, rather than stack onto, Jock/Mechanic/Scout/Medic/Quiet/Quartermaster.
Remove their bonus starting supplies, stat overrides, X abilities and role hooks
(extra clue knowledge, motor exception, blood suppression and related movement
prediction logic). Preserve shared H handoffs, generator cooperation, ordinary
items, rescue rules and truthful team-map knowledge.

| Surface | Required migration |
| --- | --- |
| [Roster](../scripts/core/survivor_roster.gd) / [player](../scripts/actors/player.gd) | Four IDs, common baseline, new personal state; no leftover old bonuses |
| [Abilities](../scripts/world/abilities.gd) | Dispatch, readiness/costs, reset/cleanup, authoritative events; preserve shared passing and useful awards |
| [Session](../scripts/core/session.gd), selection, lobby, results | Four named cards/previews, remembered selection, Random Survivor over four IDs; intentional migration of old saved roles rather than accidental `jock` fallback |
| [Gameplay interactions](../scripts/world/forest_level.gd) and escape controllers | Once-only preparation/theft/search events, damage/return validation and sample acquisition |
| [Networking](../scripts/network/network_session.gd), [snapshots](../scripts/network/world_sync.gd) and movement transport | Validate new IDs and states, costs and RNG on authority; replicate effects without reapplying outcomes |
| Bestiary/Mimic, guide, README, tests and assets | Replace hard-coded six-role assumptions, disguise sheets, bonuses and help text; retire obsolete fixtures only with equivalent new coverage |

Old saves should request a new four-character selection once while preserving
settings, seed/retry preferences and journal history. New portraits/likenesses
need user-approved references before art production; do not invent identifying
appearance. Reuse current animation conventions and effects for prototypes.
Duplicate character selection stays permitted initially, matching current role
selection; distinct identity locks would be a separate lobby policy change.

Quick Camp has no normal woods encounter/stash economy, so do not pretend the
Expedition acquisition loops work there. Implemented fallback: Christian
starts Quick Camp with one Paparazzo sample, Max with $6; John can prepare the van and Alex can use isolation/return.
Quick Camp scripted/network checks pass; fallback fairness still needs human play. Do not add
roaming woods creatures to camp merely to feed abilities.

Normal Expedition remains van plus one seeded secondary. Do not activate all
routes to showcase kits. Preserve solo recovery, clue discovery, finite shared
loot, active-route eligibility and host authority. The old role IDs, bonuses and abilities have been replaced. Common interaction
and migration tests accompany the four-person slice; historical screenshots do
not establish acceptance of the new character art or balance.

## Presentation and technical scope

One X ability and its small status display per character. Christian shows sample
name/subtype, duration and warning; John shows debt/projected health; Max shows
cash and stake; Alex shows isolation/marker/channel state. No additional shops,
creature selection menus, complex currencies or dependencies on sparse cabin
doors. Notebook descriptions contain the full rules; on-screen prompts explain
the immediate action or rejection. Do not shrink the existing 384×216 UI to fit.

Christian can reuse existing creature silhouettes, curse tells, moon indicator,
flash/shutter, spores, thread and dash effects. Reuse is not complete animation
coverage: transformed survivors need facing, motion, carried-object handling,
lighting/depth and identity readability. Paparazzo whiteout needs a restrained,
accessible presentation; no new rapid full-screen strobing requirement. Shared
map identity remains trustworthy during transformations/disguises.

Sample damage/status and Max payouts need authority-owned event IDs and RNG.
Clients request actions, never award cash/samples or dictate arbitrary return
coordinates. State lifetimes, actor references and counts are bounded. Snapshot
application updates presentation without refiring attacks, payouts or debt.
Returning Alex uses the existing authoritative movement-discontinuity mechanism;
new form movement needs shared prediction support or an explicitly tested
bounded alternative. Update the protocol/version policy when compatibility
changes; old/new clients must not silently disagree about IDs or abilities.

Read the [audio/voice design](audio_multiplayer_design.md) for implementation.
AI hearing and audible playback are separate acceptance paths. Reused cries,
sneezes, camera effects and transformation tells need exactly-once replication.
No ability requires microphone capture. Existing opt-in voice effects may be
reused; tests keep voice off unless specifically exercising consented voice work.

## Delivery order and acceptance

1. Add bounded new state, event contracts and a four-character prototype selector
   without deleting shared survival systems. Define timings/costs as central tuning
   data. Test old-save migration and every required menu path.
2. Implement John, Max and Alex with their drawback and cleanup in the same
   increment as their benefit. Add accepted-event and negative-path tests.
3. Implement Christian's sample framework and a first vertical slice containing
   **Werewolf, Paparazzo, Witch, Puffball and Seamstress**. The two user-requested
   special cases are required, not replaced by generic throwable effects.
4. Implement every catalogue adapter in verified batches. Keep unsupported rows
   visibly marked as pending, never silently grant a generic substitute. Retire
   old roles and publish final player instructions only with a coherent playable
   four-role roster; complete catalogue coverage is a separate explicit gate.
5. Tune normal solo/2/4-survivor nights and inspect actual graphical output.
   Record incomplete acceptance honestly; source and headless checks do not
   establish that the chaos is fun or the effects readable.

Required checks: import/startup and diff checks from the brief; relevant escape,
creature, prediction/replication, clue and role integration tests. Extend tests
around transitions and invariants rather than only label strings. Required cases:

- Every sample: acquisition success/rejection, source/subtype, wall/facing rules,
  valid/invalid targets, friendly/self effects, counters and expiration. No
  recursion, permanent creature deletion or objective duplication.
- Werewolf: moon on/off, cloud transition, wolfsbane, down/revive, inventory and
  form interaction rejection. Paparazzo: facing/away/cover, Christian/teammates/AI,
  warning/whiteout and photo-to-Stalker consequence.
- John: all five routes plus Quick Camp, once-only refill, hit grace, wards,
  continuous drain, grabs, lethal settlement, healing rejection, boarding,
  extraction and no repeated debt after revive/disconnect.
- Max: stash contention, empty/full belt, theft identity, repeated recovery,
  affordability, hold/release, RNG/payout once, damage spills, down/disconnect,
  two Maxes and no real-money or objective-item conversion.
- Alex: solo/group transitions, isolation hysteresis, marker expiry, cancellation,
  grabbed/downed rejection, blocked landing, heavy gear, attached effects,
  disconnect/retry cleanup, discontinuity and no hidden exploration reveal.
- Graphical normal nights: woods/interiors, normal and adverse lighting, each
  transformation, crowded friendly effects, debt/cash/marker UI, keyboard/mouse,
  original viewport at supported scales. Label staged poses, frozen AI, altered
  lighting and any forced-route fixture.
- Listen-host and dedicated authority, four peers, contention and reconnection;
  separate macOS editor, packaged OS, real listening and Internet limits.

Open tuning items: sample repeat limits/durations/resistances and target adapters;
John's window, resource budget and damage-source coverage; Max's prices, odds,
anti-farm caps and spill fraction; Alex's distance/delay/rates, channel/expiry and
cooldown; Quick Camp fallback; character art. These are balance tasks, not
permission to drop the specified strengths or personality drawbacks.

## Source baseline and document precedence

The original design inspected main after scenery commit `d68b86a`.
The [README survivor guide](../README.md#survivors-and-their-abilities) now
describes the four playable kits; the [legacy survivor plan](survivor_multiplayer_plan.md)
preserves the older roster history.
Some historical tuning/status prose is stale; code and execution evidence remain
the baseline. This design supersedes those documents' **future roster direction**,
not their implemented-status facts or unrelated co-op acceptance requirements.

Implementation verification and its limits are recorded in the
[development log](development_log.md). The original catalogue remains a design
contract; distinguish individual acceptance cases from the existence of handlers.
The optional Stalker/Lake Thing special-source proposals remain outside the pool.
