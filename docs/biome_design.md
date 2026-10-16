# Forest biomes and landmark encounter design

Status: **six new optional biome pockets implemented, deeper dossiers remain planned**.
The finite 9,600×9,408 forest now contains nine major regions: village, bog,
graveyard, flooded mill, orchard, observatory, rail yard, quarry and chapel,
plus six small ruins. New pockets use connected open loops, distinctive native
pixel scenery, a one-time rare-tool search and leashed guardians. They do not yet
implement every interior, hazard, seeded variant or quest described below.
See [implemented content and evidence](content_update.md). The user's latest
amendment authorizes this offline content ahead of multiplayer.

This plan contains **18 biome designs: three expanded existing regions and
15 new regions**. They are modular pockets in the current maze, not a replacement
world or an instruction to enlarge the map again. See
[monster catalog](monster_catalog.md), [survivor plan](survivor_multiplayer_plan.md)
and [milestones](milestones.md). Working names and stories are original concepts.

## Make the forest feel discovered

Each region should have an unmistakable silhouette, a navigational grammar, a
local survival rule and a memorable risk/reward decision. A player should be able
to describe it as “the mill where the pipes warn before steaming,” rather than
“another clearing with different trees.” Ordinary forest still separates regions
and gives the player room to recover. Major landmarks get hand-authored readable
layouts; seeded variants change approaches, prop slots, loot and encounter
patterns inside verified constraints.

Use three bands around the camp: **near** orientation/supply pockets, **middle**
objective-capable regions, **deep** optional high-risk landmarks. Candidate areas
are assigned by normalized travel distance and graph reachability, not compass
coordinates alone. Keep the existing village northwest, bog east and graveyard
south in the first expansion; randomize their internal safe variants before
moving them. New regions can occupy any compatible quadrant. Never make a
deep optional destination secretly required by placing a part there.

Initial generation target: retain the three current objective regions and add
only **two new major pockets plus three small satellite landmarks per night**.
Treat this as proposed tuning, measure actual available cells/travel time, and
reduce the count if reservations conflict. The catalog is a pool across runs;
do not stamp all 18 into every night. No runtime count change is implied here.

## Shared layout and generation contract

1. Reserve each region's footprint, connection aprons and an outer tree belt
   before decorating. Initial new footprint candidates are 4×4 to 6×5 forest
   cells (768×768 to 1152×960 at 192px/cell), subject to measured reservations.
   Existing regions retain their approved footprints until explicitly expanded.
2. Give major regions at least **two distinct graph-connected trail entrances**,
   an internal loop and two approaches to the main interaction. A shortcut may
   add a third entrance. Avoid two “entrances” that immediately share one choke.
   Minor optional dead ends are short, visibly optional and never hold required
   parts. Camp's four exits and all required routes remain connected.
3. Keep trails at least the current **128px** width and connections at least the
   current **32px** clear apron; widen busy shared approaches to a proposed
   192–256px where the footprint permits. Decorative fences/props may not narrow
   these clearance reservations. A region's interior door is not a maze border.
4. Generate obstacles once for collision, navigation, shadows and sight masking.
   Wet floors are walkable; deep water, sheer edges and machinery are explicit
   solid boundaries. No unlabeled instant-death pits or speculative jump/swim
   controls. Preserve native navigation chunk seams and 7px agent clearance.
5. Required parts/cutters must be reachable by every role without consumables,
   cooperative pressure plates, timed platforming or special powers. Keep three
   required region caches in the first content expansion; rotating objective
   regions is a later rule change with clue/UI and five-part recipe tests.
6. An encounter cannot permanently lock a region, consume its required part or
   make every return path dangerous simultaneously. Optional events are marked
   before activation, cancel/expire safely and have one-time rewards per round.
   A reconnect/restart cannot duplicate a reward or retain old hazards.
7. Use region entrances, local silhouettes and explored field-map names for
   orientation. No full-world radar, undiscovered cache markers, visible enemy
   outlines through trees or region lights shining onto separated paths.
8. Randomize compatible modules, not arbitrary furniture positions: two to four
   entrance/loop variants, several verified loot slots and bounded prop patterns.
   Region ID + world seed + content version reproduce the selection. Maintain
   no-overlap reservations for buildings, routes, caches and door clearances.
9. Environment cues stay local, attenuated and on the right bus. Existing MP3s
   may support broad ambience; unique machinery, bells and calls require new
   original/licensed cues and provenance, not imaginary files in the manifest.
10. Keep a normal-speed return-time budget. The forest's size is already large;
    measure component round trips, recovery space and supplies before adding
    traversal burdens. Target 40–60 minute expedition rounds remain unproven. Every region
    must also work with muted audio and no voice chat.

## The 18 region designs

### B01 — Old Graveyard: procession paths and broken memorials

**Identity and layout.** Expand the existing southern graveyard's detail inside
its 768×768 reservation first: a leaning bell arch opens onto a broad processional
avenue, with staggered grave aisles to either side. A caretaker shed, ossuary
wall, two family memorial courts and the existing crypt form a readable outer
loop. Broken low walls mark routes without hiding the survivor sprite; roofs
cut away normally. Entrances meet the avenue and rear memorial court separately.

**Local rule and sequence.** Keep the current required cache and optional noisy
crypt stash. A proposed optional memorial sequence asks the player to inspect
three nearby visible symbols, then choose matching plaques in the central court.
It needs no external lore or spoken clue. A mistake rings a local mourning bell
and resets only the optional sequence; it does not delete loot or seal the gate.
The first successful completion opens a side supply niche once.

**Threats and counterplay.** Grave Procession (M41) crosses the avenue on a
visible cycle; Gatekeeper Stag (M32) temporarily challenges a side threshold.
Start with either one, not both. Grave rows offer short sight breaks, and the
outer loop stays open. Cues are moving shrouds, shifting dust and muffled stone
scrapes, not global chanting. Reward patient crossing with a safer return lane.

**Variants and verification.** Seed which memorial court holds the optional
sequence and reverse the procession circuit; never relocate the required cache
behind the puzzle. Verify both entrances, every grave aisle, rear crypt approach,
no snagging of downed/reviving actors and no guardian camping the required cache.

### B02 — Abandoned Village: courtyards, shutters and a listening square

**Identity and layout.** Keep the northwest 960×576 site and current bell, well
and cache. Give its two huts differentiated interiors: a boarded general store
with a clear counter loop and a meeting house with benches and a rear door. The
square connects a washed-out lane to a garden passage; porches leave broad
approach space. Laundry lines and shutter silhouettes supply detail above,
rather than collision across the main footpaths.

**Local rule and sequence.** The existing bell remains a deliberate distraction
and the well remains its once-per-round stash. Add an optional hand-pump event:
three short holds prime water for a supply compartment; each stage has a visible
pressure gauge and sound. Releasing saves no hidden progress; the UI explains
whether a stage persists. Wrong timing causes noise only, not unavoidable damage.
Required repair loot remains independent of both events.

**Threats and counterplay.** Bell Widow (M17) can echo one bell; Sleeper in the
Wall (M22) punishes lingering at one noisy doorway. Seed one encounter and retain
all existing safe exits. Window silhouettes never reveal enemies through solid
walls. Local shutters, well-chain movement and dust identify active threats.

**Variants and verification.** Rotate store/meeting-house prop modules and which
garden passage opens, while preserving a two-route square loop. Test bell echo
caps, well reward once, roof fade, both doors and no pickup trapped behind tables.

### B03 — Witch's Bog: island circles and ritual runoff

**Identity and layout.** Detail the current eastern 768×768 region around a
continuous raised boardwalk loop linking a ritual island, collapsed herb hut,
reed pocket and cauldron. Two dry approaches join different islands; short
stepping-stone side paths are fully walkable, with no jumping mechanic. Dark
unwalkable water gets unmistakable banks and matching collision/occlusion.

**Local rule and sequence.** Preserve current cache and one-use cauldron
recharge/hex/noise trade-off. A future optional runoff valve drains one shallow
side pocket, revealing a ration/battery stash but briefly activating marked
spore vents. The main boardwalk never becomes submerged or unsafe end to end.
A player can ignore the valve and still collect the required component.

**Threats and counterplay.** Reed Piper (M23) uses open reed lanes; Silt Bride
(M26) rewards walking across muck. Use one new threat alongside bounded existing
witch pressure. Bubbles, bending reeds and cauldron light provide visible tells;
croaks and water movement stay local. The dry outer loop is the reliable retreat.

**Variants and verification.** Seed herb-hut and reed-pocket placement within
fixed island modules. Test all boardwalk joins, shoreline blockers, cauldron
once/reset, bolt collision and fog plus sight-mask readability without audio.

### B04 — Flooded Sawmill: pressure, gears and dry catwalks

**Identity and layout.** A low mill roof, motionless waterwheel and red pressure
tank dominate a 5×4-cell candidate pocket. A dry perimeter road and interior
catwalk loop connect intake gate, cutting hall, boiler room and loading dock.
Two entrances lead to opposite ends of the dry loop. Timber stacks have clear
gaps; the saw and deep channels are solid scenery, not instant-death surfaces.

**Local rule and sequence.** Three marked valves redirect steam among fixed
pipes. An optional service cabinet opens after depressurizing its gauge; the
short route becomes noisy, while the longer dry loop stays free. Valves use
visible states, ordinary E interactions and a timeout to safe pressure. The
first prototype uses fixed steam zones with no runtime nav-mesh editing.

**Threats and counterplay.** Boiler Saint (M45) answers loud events with one
announced pipe vent; Creak Cart (M24) is a later alternative. Read the gauge and
pipe shake, wait for the vent, then cross. No steam appears through walls or on
both approaches at once. Layer wood groan, waterwheel creak and short steam hiss
locally, leaving room for footsteps and warning cues.

**Variants and verification.** Choose one of three pipe sequences and which
optional cabinet contains the reward. Never randomize valves into unreachable
corners. Test two independent entrances, vent expiry/disconnect cleanup,
simultaneous valve intents and server event IDs before co-op integration.

### B05 — Blackwater Reservoir: drawdown terraces and a stranded boathouse

**Identity and layout.** A crescent concrete retaining wall overlooks shallow
terraces, broken fishing piers and a stranded boathouse. Use a 6×4-cell candidate
with an upper maintenance loop and a lower dry shoreline loop joined twice.
Deep water is blocked; the entire required traversal uses land or fixed decking.
Reflective surfaces must not reveal paths or enemies beyond current sight.

**Local rule and sequence.** An optional sluice wheel exposes a lower supply
locker temporarily. A painted water gauge counts down its safe access window;
expiry closes only the locker interaction, never floods a player or removes the
return path. Failure can be retried with a cooldown, but the reward awards once.

**Threats and counterplay.** Silt Bride (M26) pressures lower muck; Mire Lantern
(M31) tempts players from safe decking. Seed one. Distorted lantern reflections,
visible mud churn and creaking piers teach the difference between lure and route.
The upper loop is longer but reliable. Spare batteries and a flare reward risk.

**Variants and verification.** Swap boathouse orientation and drained-locker
side while keeping both ramps. Verify all shoreline collision, no stranded actor
at expiry and no submerged required component or reflection leaking hidden AI.

### B06 — The Burn Scar: black trunks and warm ash seams

**Identity and layout.** Charred vertical trunks, a collapsed ranger truck and
bands of pale ash distinguish a 4×4-cell pocket. Three broad lanes thread around
blackened root islands; two perimeter routes stay cool. Red glow appears only
under nearby visible ash, with shadow borders matching actual trunks.

**Local rule and sequence.** Recently disturbed hot seams brighten before a
brief flare-up. Walking reveals them early; sprinting makes a larger visible ash
plume and noise. A burned supply box opens normally, with an optional noisy truck
compartment providing a second reward. Fire never spreads dynamically across the
maze or permanently consumes routes, parts, trees or inventory.

**Threats and counterplay.** Ash Runner (M05) repeats observed routes; Cinder
Miser (M39) guards optional hoards. Test separately. Change lanes after breaking
sight and wait for ash to settle. Ember motion and a soft crackle convey danger
without flashing screens or an unavoidable damage-over-time chain.

**Variants and verification.** Seed cool-lane arrangement and truck location
from verified modules. Keep two fully cool routes to each mandatory exit. Check
weather readability, no overlapping heat windows on every lane and complete
cleanup of footprints on reset. Loot emphasizes flares and ration recovery.

### B07 — Overgrown Glasshouse: potting aisles and shuttered light

**Identity and layout.** Broken roof ribs, waist-high planting benches and
curving roots form a 5×4-cell candidate. A potting shed and two glass wings join
through an open central court. Perimeter doors are separated; each wing has an
aisle loop. Use pale frame highlights to distinguish solid panes from open bays.

**Local rule and sequence.** Hand shutters alter a local grow-lamp patch, letting
the player choose a bright, visible shortcut or a darker wider aisle. Lamps do
not bypass the opaque woods mask or illuminate paths through trees. An optional
seed cabinet opens after aligning three simple plant-symbol plates; symbols are
inspectable nearby, with no color-only solution or mandatory timed puzzle.

**Threats and counterplay.** Prism Leech (M10) tests shadow reading; Mirror Pair
(M44) is a later variant. Real bodies keep a consistent shadow and tell. A second
entrance and potting shed break pursuit; never place both perception powers in
the first version. Audio uses pane ticks and leaves rubbing, not constant crashes.

**Variants and verification.** Shuffle bench islands and shutter starting
states within aisle reservations. Check panes against collision/sight, no false
glass openings, roof cutaway, safe lamp transitions and identical host lamp state.

### B08 — Slate Quarry: switchbacks and the silent lifting frame

**Identity and layout.** A silhouette of a crane arm sits over stepped slate
terraces in a 6×5-cell candidate. Two broad switchback ramps connect top and lower
loops; a third short service passage is optional. Elevation is painted scenery
with explicit boundaries, not a new vertical physics system. Crane loads remain
fixed unless a future interaction is separately implemented and verified.

**Local rule and sequence.** Loose gravel makes sprinting conspicuous and
walking deliberate. An optional winch hold lowers a supply cage to a safe pad,
making repeated localized clangs. Release pauses the winch; a visible meter and
maximum event duration prevent a permanent noisy state. Required routes avoid
the winch lane, and the cage never crushes a survivor.

**Threats and counterplay.** Stoneback Ram (M03) gives a clear sidestep challenge
on a wide terrace; Gravel Maw (M27) is a later anchored hazard. Use alcoves and
ram recovery to cross. No attacking from another painted “height” through a wall.

**Variants and verification.** Reverse the main switchback and move safe alcoves
as a whole module. Verify both ramps/agent seams, no false walkable cliff edges,
winch reward once and a retreat without consuming a flare or stamina item.

### B09 — Forgotten Rail Yard: signal loops and empty platforms

**Identity and layout.** Rusted freight cars, a water tower and a tiny signal
cabin surround two platforms in a 6×4-cell candidate. Wide gaps between cars
make a perimeter loop and a cross-yard loop. Rails are ordinary walkable terrain;
closed cars are solid, open cars have two actual doors and readable interiors.

**Local rule and sequence.** An optional hand signal activates an inspection
cycle. Platform lamps announce the next sweep lane; crossing during recovery
allows access to a mail-locker reward. The cycle expires safely and never locks
both perimeter routes. Default lamps remain local state, not global map beacons.

**Threats and counterplay.** Last-Car Conductor (M48) is the encounter's sole
new active attacker initially. Rust Gardener (M29) may replace it in another
seed. Read the hand lamp, shelter in wide recesses and cross behind the sweep.
Optional toll mechanics remain separate; ordinary travel never requires payment.

**Variants and verification.** Seed parked-car modules with verified gaps and
swap the locker platform. Check no item behind a sealed car, signal re-entry
abuse, event expiry and consistent platform state for slow clients. Loot favors
batteries and flares, with no new extraction vehicle in this phase.

### B10 — Collapsed Funfair: queue lanes without a crowd

**Identity and layout.** A stopped carousel canopy, ticket booth and torn tent
form a 5×4-cell candidate. The queue is an optional weaving shortcut beside a
wide open service loop. No moving ride physics or copyright-themed attractions.
Low railings show the queue shape but leave clear exits and no sprite-obscuring
foreground wall across the route.

**Local rule and sequence.** An optional ticket punch opens a supply drawer
after three visible mechanical beats. Each beat attracts attention, and the
player may abandon it. The reward is finite, the drawer cannot hold a required
component, and missing a beat causes only a restart/noise rather than damage.

**Threats and counterplay.** Tin Choir (M21) coordinates a nest warning; Clockwork
Caretaker (M40) is an alternate replaying patrol. The player can read painted
symbols, interrupt the exposed choir leader or retreat along the service loop.
Keep old ride music restrained and local, with silence between mechanical cues.

**Variants and verification.** Swap ticket booth and tent modules, keeping the
carousel as an orientation anchor. Verify queue escape points, no recursive
choir summons, one drawer reward and no fake ally/UI messages from scenery.

### B11 — Hollow Orchard: ordered rows turned wrong

**Identity and layout.** Crooked fruit rows lead to a packing shed, fallen tree
arch and empty irrigation pond in a 5×5-cell candidate. Four traversable cross
rows and a perimeter lane make the grid deliberately more legible than the maze.
Tree crowns preserve trunk collision and fade only as needed for the player.

**Local rule and sequence.** Visible hanging wind chimes react to sprinting near
their posts, creating small noise hazards. An optional irrigation pump opens a
packing-shed supply drawer, but wakes one marked nest. There is no rotten-food
guessing game: actual ration pickups are labeled and follow normal supply rules.

**Threats and counterplay.** Bramble Seamstress (M02) is the initial monster;
Root Bailiff (M25) and Afterimage Doe (M14) are alternatives. Read ankle threads,
walk under them or switch cross rows. The first version does not combine two
route blockers. Fallen fruit, bent branches and stitch glints supply clear tells.

**Variants and verification.** Seed missing-tree gaps and shed orientation from
verified row modules. Check all cross rows, tree/light occlusion, tripline sight
and no permanent cut when a line is placed at a junction. Loot supports stamina.

### B12 — Hill Observatory: shutters and a blind telescope

**Identity and layout.** A cracked dome, dish mast and small generator hut fill
a 5×4-cell candidate. A circular exterior path wraps the dome; two low service
corridors link a central lens room and battery store. The dome roof fades inside;
“hill” elevation is visual only, with normal collision and no overlook radar.

**Local rule and sequence.** Turn a manual shutter wheel to sweep a narrow
lamp patch across fixed interior sectors. Opening an optional observation locker
requires holding a marked sector lit briefly; a visible gauge tracks it. Light
never reveals undiscovered forest, hidden enemies or objective positions. The
outer path remains usable with an empty battery and the locker stays optional.

**Threats and counterplay.** Shutter Wraith (M09) advances when unobserved;
Battery Barnacle (M33) is an alternative, not a simultaneous first encounter.
Read the click/contraction, use brief illumination, and retreat normally during
its pause. No rapid flicker; shutter rotation is deliberate and low contrast.

**Variants and verification.** Rotate starting shutter orientation and locker
side, not the fundamental two-exit circle. Test several observers, conflicting
lamp intents, per-client sight, empty-charge escape and no shared-config mutation.

### B13 — Mycelium Hollow: root chambers under an open canopy

**Identity and layout.** Giant exposed roots shelter fungal shelves and a
collapsed research lean-to in a 4×5-cell candidate. These are top-down forest
alcoves, not a new subterranean layer. A ring path links three fungal courts;
two external trails attach on opposite sides. Glowing caps light only local
surfaces and do not replace line-of-sight restrictions.

**Local rule and sequence.** Fungal heads announce one temporary spore lane
with a sequence of cap motion. Walking avoids disturbing dormant colonies; an
optional sample cabinet triggers one announced cycle and awards a battery/food
bundle. Spores briefly reduce stamina recovery, capped and auto-expiring, without
hiding borders or disabling inputs. The other half of the ring stays clear.

**Threats and counterplay.** Spore Parliament (M47) owns the cycle; Burrow Knocker
(M07) is a separate variant. Read cap order and move to the open branch, rather
than memorize colors or require audio pitch discrimination. Under-root noises
and breathing cap animations remain local and bounded.

**Variants and verification.** Seed court order and safe branch, always preserving
two dry routes. Test muted/color-independent tells, finite head count, no spore
stacking and automatic state cleanup if the active player leaves or dies.

### B14 — Ruined Apiary: hive lanes and a quiet keeper's hut

**Identity and layout.** Collapsed hive boxes surround a keeper's hut, wax press
and weed-choked yard in a 4×4-cell candidate. Offset hive rows create two broad
perimeter paths and a central service lane. Hives are solid readable props;
swarms are limited effects/hazards, not hundreds of independently pathing agents.

**Local rule and sequence.** An optional press hold cracks wax from a supply
compartment, gradually raising a visible agitation meter. Pausing lets it settle;
success awards one ration/flare bundle. No new honey crafting or portable smoke
item is required. Every mandatory route avoids the press and remains viable.

**Threats and counterplay.** Honey Regent (M43) guides a single ribbon swarm
between marked anchors. Watch wing gathering and walk behind the ribbon, using
the open perimeter. Ration Moth (M35) is a later alternative attracted to a recent
food-use location, not the player's unseen inventory. Avoid continuous piercing
audio; buzzing falls off locally and never becomes the only warning.

**Variants and verification.** Move hive rows as clearance-preserving modules
and swap the press side. Check active swarm count, recovery during solo play,
no simultaneous coverage of every entrance and cleanup on restart/host loss.

### B15 — Ice Hollow: sheltered frost and a thaw shed

**Identity and layout.** A shaded sink of frost-coated trees, cracked ice slabs
and a small thaw shed makes a 4×4-cell candidate. Blue-grey cool tones differ
from normal rain; the ice is an unusual local cold pocket, not a promise of a
season/weather overhaul. A rough-gravel ring surrounds a short icy interior lane.

**Local rule and sequence.** Sprinting on grooved ice adds a brief predictable
slide; walking remains stable. An optional thaw crank opens a supply drawer and
temporarily warms one narrow lane, making a local creak. No global warmth meter,
frostbite system or need for special clothing in the first version. Deep cracks
are visibly solid boundaries, not surprise lethal pits.

**Threats and counterplay.** Rime Weaver (M30) lays a short marked strip; Afterimage
Doe (M14) is an alternative on the outer ring. Slow down before the strip and
read the real moving shadow. Sliding never reverses controls, crosses collision
or pushes a survivor into an unavoidable attack.

**Variants and verification.** Seed strip orientations and shed side. Test
diagonals, low stamina, low frame rate, slow expiration, clear rough-route access
and authoritative movement correction without clients sliding differently.

### B16 — Storm Ridge: grounded towers and sheltered cuts

**Identity and layout.** Bent utility poles, a grounded transmitter and a
stone maintenance shelter occupy a 5×4-cell candidate. A ridge track and sheltered
lower cut connect twice around rock islands; painted height gives no ability to
see over forest borders. Fence breaks are wide and visibly traversable.

**Local rule and sequence.** During rain, local puddle ripples reveal recent
fast movement to a particular guardian. An optional grounding switch powers a
sealed supply box after a short visible meter fills; an overloaded cable warns
before a brief marked arc. No random lethal lightning, global weather control
or real-world electrical puzzle is required. Dry weather uses an inert cable
variant and ordinary sight-based threat behavior.

**Threats and counterplay.** Rain Antler (M46) follows old ripples and announces a
short splash ring. Walk away from the old stimulus and use shelter; it cannot
read present hidden positions. Stoneback Ram (M03) is a dry-weather alternative.
Thunder stays restrained; local ripples and raised beads remain readable muted.

**Variants and verification.** Seed shelter/cable modules and choose a wet/dry
encounter table. Verify both cuts, no unsafe arc on the only exit, weather-state
replication and zero unsensed tracking when a survivor stops behind cover.

### B17 — Drowned Chapel: pew islands and a silent vestry

**Identity and layout.** A sunken nave, broken bell cote and leaning cemetery
gate distinguish a 5×4-cell candidate. Water in the nave is shallow walkable
terrain, with solid deeper edges; dry pew aisles connect a front porch, two side
doors and a vestry loop. It is a separate landmark from the existing graveyard,
with no shared mandatory quest chain or hidden loading portal.

**Local rule and sequence.** An optional memorial drawer opens after turning
three visible brass plaques toward matching wall carvings. A mismatch sounds
one local bell and resets that optional puzzle. Each hint can be read in the room;
no religious knowledge, audio-only melody or outside document is required.
Completing it gives a finite rescue-oriented supply bundle, not immunity.

**Threats and counterplay.** Empty Bridegroom (M42) marks on real sight; crossing
a reachable threshold or waiting out the mark breaks its attention. Candle Grazer
(M11) is a later alternative. Read the corsage glow and use the side-door loop;
the guardian must not repeatedly mark through walls or deny every threshold.

**Variants and verification.** Seed plaque order and vestry reward slot. Test
solo mark expiry, no blocking pews, doorway shadows, muted tells and no monster
speech mixed into the real spectator/player voice channel.

### B18 — Charcoal Kilns: vent mouths and the workers' ring

**Identity and layout.** Three squat brick kilns, a coal cart and workers' lean-to
form a 4×5-cell candidate. A wide service ring joins all kiln mouths; cut-through
gaps provide two routes to a rear supply shed. Black soot contrasts with pale
brick rims, making kiln openings and solid walls readable at native pixel scale.

**Local rule and sequence.** Vent shutters cycle between smoldering and cool
states with visible gauge flags. An optional coal-cart push is initially a short
E interaction that moves it between two prevalidated positions, exposing a stash.
It does not become free physics, block a route or crush actors. Completing the
move causes noise and a brief announced hot zone near one kiln only.

**Threats and counterplay.** Cinder Miser (M39) guards optional bundles; Flare
Smuggler (M36) is a separate variant carrying unattended light to a nest. Follow
the ember trail or take the opposite service branch. Neither steals required
parts, adds permanent heat nor changes a burning flare's remaining lifetime.

**Variants and verification.** Choose one cool kiln arrangement and cart side
from modules. Verify both stash approaches, simultaneous cart intent rejection,
finite flare transfer and safe behavior if a player stands on the destination.

## Overhaul: ring-and-spoke map, rotating objectives and new regions

Planned for overhaul slices **F4–F5** ([overhaul plan](fun_overhaul.md));
nothing here is implemented. The user is open to a better map structure, new
regions and requirements that span the map. When F4 ships it supersedes, in
contract items 5 and 7 above, the fixed three objective regions and the
"explored names only" orientation. The world budget stays 9,600×9,408 and every
other contract item still applies.

### Structure

- **Camp hub** (unchanged furnished camp), now with a **lake edge** to the
  south-west and a **floodlit ranger gate** on the old road.
- **Inner ring road**, about 1,600px from camp: 192px wide, lamp posts lit while
  camp power is on, frequent hiding spots, gentle curves so it never feels like
  a corridor. It connects every spoke without passing through camp.
- **Four to six spokes** from camp to the region clusters, each 128–192px wide,
  signposted at the ring and at a mid-spoke **junction landmark** (cairn, shrine,
  broken bus, hunting blind). Each spoke has one **unlockable shortcut** back
  toward camp, opened from the far side.
- **Middle band** of objective-capable regions; **deep band** of optional,
  high-risk relic regions. Bands use measured travel distance, not radius alone.
- **Thickets** fill the space between spokes. The current maze generator lives on
  here: darker, no lamps, more roamers, shorter as the crow flies.
- **Skyline silhouettes** for tall landmarks render on a canopy-top layer within
  a bounded radius; they show direction only, never trails or creatures.

### Rotating objectives

Every night draws its required steps from the **objective-capable pool**
(village, bog, graveyard, mill, rail yard, plus B19–B24 below) so the chain
spans at least three spokes and never sits in a deep-band dead end. Clue chains
(camp → field → building) name the regions; the Lodge wall map names all
regions from the start. Seed + content version reproduce the draw.

### New regions (B19–B26)

| ID / region | Silhouette and layout | Cross-map role | Local tension |
| --- | --- | --- | --- |
| B19 **Ranger Fire Tower** | Tall lookout on a rise, switchback stairs, picnic shelter; skyline landmark. | Lookout reveals region names in a radius and lit creatures in sight; zipline shortcut toward camp; holds clue notes. | Climbing is noisy and exposed; one way down unless the zipline is unlocked. |
| B20 **Power Substation** | Fenced transformer yard, breaker hut, humming lines leading toward camp. | Fuse restores camp power: ring-road lamps, camp floodlights, radio station and ranger gate. Generator battery (heavy) can substitute. | Electric hum masks footsteps for players *and* AI; arcing transformer tells. |
| B21 **Radio Relay Station** | Hilltop mast (skyline), equipment shack, guy-wire maze. | Radio Rescue transmit point once power is on; also the Scout-friendly clue hub. | The 10s transmit hold broadcasts noise; guy-wires create tight lanes. |
| B22 **Logging Camp** | Log decks, a dead skidder, sawhorse rows, a winch line. | Outboard motor (heavy) for the Boat escape; crowbar toolshed; winch two-person action. | Log piles are knock-overs; the Groundskeeper favours it. |
| B23 **Lakeshore Boathouse** | Boathouse, two ramps, dock, canoe racks on the camp lake. | Boat launch point; canoe shortcut across the lake to camp. | Water edges are the Drowned Counselor / Lake Thing's domain; launch hold-out. |
| B24 **Old Copper Mine** | Cliff entrance, timbered tunnels with an ore-cart line, lantern hooks. | Holds a gate-code fragment or kerosene; the ore cart is a one-way fast exit toward a spoke. | Pitch dark interior, short sight, echoing sound that is hard to locate. |
| B25 **Hunting Lodge** | Trophy hall, porch, kennels, a stand of hunting blinds. | Deep-band relic site; flare gun for the Signal Fire; best hiding spots in the woods. | Many hiding spots but the kennels wake hounds; trophies rattle when brushed. |
| B26 **Signal Ridge** | Bare hilltop with a beacon pyre, wind-bent trees, two steep approaches. | Signal Fire escape finale; also a skyline landmark once lit. | Open ground with no hiding; finale hold-out with everything converging. |

Existing concepts B05 Reservoir, B16 Storm Ridge and B08 Quarry can merge into
B23/B26/B24 if that reads better; choose during F5 schematics.

### Acceptance additions for F4–F5

Every seed: hub/ring/spoke graph connected; every shortcut only adds routes;
spoke travel ≤ 60s and post-shortcut return ≤ 90s at walk speed (route player);
required chain spans ≥ 3 spokes and is solo-completable by every role; heavy
items never in deep dead ends; skyline layer occlusion probes pass; objective
rotation and escape choice reproduce by seed in solo and two-peer co-op.

## Satellites that fill travel gaps without another full biome

Use a few small landmarks between major regions: a collapsed hunting blind with
a visible long sightline; a hollow-tree pantry reached by a short loop; a broken
footbridge with an obvious dry bypass; an abandoned picnic shelter with a single
noisy locker; a survey cairn bearing a local camp-direction hint; or a roadside
memorial with an optional flare stash. Each needs a silhouette, one interaction
at most and a verified return route. Do not turn every clearing into a battle.
Keep existing six ruins until replacement modules pass the same graph checks.

## A proposed night, as an experience rather than a content count

A player leaves camp north and finds a survey cairn that confirms the return
direction. The northwest village supplies the first region component; ringing
the bell creates room to leave, but an echo warns not to stay. A Flooded Mill
on a middle-west loop offers optional batteries with an obvious steam trade-off.
The player can bypass it. Eastward, the required bog uses the familiar dry
boardwalk, then an Orchard pocket on a southern loop offers extra rations behind
visible tripline pressure. The south graveyard holds the last region component;
its procession lane asks for patience before the final return to camp. This
example retains the current five-part expedition recipe and adds reasons to
explore without requiring every landmark or a microphone.

## Content production and acceptance

**First slice: Flooded Mill.** Draw a schematic and reserve its footprint in a
fixed-seed copy of the current forest. Establish two approaches, collision,
shadows, sight, navigation and basic scenery before any power. Add one optional
cabinet/valve sequence, then Boiler Saint with original tell art and proven audio
provenance. Only then vary the layout and integrate network state. Preserve
separate evidence for local visuals, mechanics, actual listening and two peers.

**Second/third slices: Orchard, then Observatory.** They test different systems:
temporary route hazards, then shared light observation. Expand current graveyard,
village and bog through small compatible detail passes between slices. Rail Yard
is the fourth candidate after event/lifecycle replication is stable. Remaining
regions stay planned; no biome count is an acceptance gate for voice or exports.

For each region run import/startup, required regression suites, fixed-seed graph
and every-cache/entrance/door reachability, randomized reservation overlap tests,
native nav-chunk seam checks, sight/flashlight border probes, low-charge/low-stamina
solo retreat, interruption/expiry, one-time rewards and all-role compatibility.
Inspect normal-light graphical captures of approaches/interiors; an illuminated
overview alone cannot prove readability. Once networked, test concurrent
interactions, host authority, stale event rejection, state restoration and four
peers moving through the site under latency. Record normal-speed travel/supply
budgets and actual audio listening; do not infer human balance from graph paths.

No new biome, monster, asset, export, microphone behavior or network acceptance
is implemented by this document. All numeric footprint/density targets are
planning defaults to confirm against the actual generator and playtest evidence.
