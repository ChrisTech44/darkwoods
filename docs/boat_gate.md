# Boat, Ranger Gate and F5 art polish

Woods Expedition offers the **Van plus one rumoured escape per night** (Radio
Rescue, Boat, Ranger Gate or, since F5c, Signal Fire); see the README. Tests use
`--all-escapes` to enable every escape on one seed. When offered, the first completed extraction ends the round. Boat and Gate
launch/open as soon as they are prepared (no clock gate). Quick Camp is unchanged.
Press **T** to cycle objective pages; **Tab** closes field notes. Human pacing
tests remain deferred by the user. This slice does not claim all of F5 is done:
Signal Fire, primary/rumoured escape selection and the revised van finale remain.

## Boat

| Component | Location | Carrying |
| --- | --- | --- |
| **Outboard motor** | West Logging Camp | Separate objective inventory, no belt slot. Carrier walks at 75%, cannot sprint or vault. **G** sets down the motor before dropping belt supplies. |
| **Marine fuel** | East Rail Yard | Dedicated boat fuel, distinct from van fuel. No belt slot. |
| **Drain plug** | North Observatory | Separate objective inventory, no belt slot. |

Carry all three to the **southeast Lakeshore Boathouse**; E at the boat fits
carried parts. Installation is permanent and shared. Downing or disconnect drops
uninstalled parts beside the survivor, using the existing reachable-drop rules.

A standing, unhidden teammate can **hold E within 48 px** of the motor carrier,
with a clear path between them, to assist. The carrier walks at full speed;
neither can sprint while assisting. Release E, separate, hide or become downed
and assistance stops. Solo players can carry the same motor slowly with every role.

Once fitted, E starts the **25-second launch**. Stay on the wooden
dock within **80 px of the boat point**, with a clear path to it. Survivors remain
vulnerable and can move/use supplies. Solid lake banks keep walking on shore and
dock; there is no swimming. Ordinary seeded supplies are moved off solid water.

The **Lake Thing** is a bounded launch encounter, not another roaming cryptid.
At 20, 12 and 4 seconds remaining, it marks one of three fixed dock positions.
Each glowing circle warns for **two seconds**, then hits standing survivors
within **26 px**, following ordinary wound/grace/protection rules. Sidestep the
circle or throw a normal flare within **100 px** and clear sight to cancel that
strike. It never reads hidden player positions, seals the dock or teleports a
roaming monster. Chapel signal holders are separate and do not interrupt it.

| Logging Camp | Motorboat launch |
| --- | --- |
| ![Timber workshop, log stacks and motor pickup](screenshots/logging_camp.png) | ![Motorboat on the launch dock](screenshots/boat_launch.png) |

| Boathouse on the shore | Lake Thing warning |
| --- | --- |
| ![Stilt boathouse in the camp art style](screenshots/lakeshore_boathouse.png) | ![Lake Thing emerging inside its marked splash tell](screenshots/lake_thing.png) |

![Boat objective page](screenshots/boat_plan.png)

## Ranger Gate

1. Check the T plan for **three distinct code fragments**. A separate seeded RNG
   picks one region in each of east, south and west, rotating among existing
   landmark regions. The plan names their regions; the notes are physical pickups.
2. Carry them to **Ranger Gate on the far north road** and E to fit them. Fragments
   use no belt slots, drop on down/disconnect, and install once for the whole team.
3. Restore the **north Power Substation** with the mill emergency fuse, as for
   Radio Rescue. Then E at **the gate's left breaker** powers its floodlights and
   the road lamps. Camp blackouts do not undo this dedicated circuit.
4. Hold E at the gate for **four seconds**. Letting go, moving,
   being downed or changing operator resets incomplete progress. The arm opens
   on the host and every client. Evacuation stays locked until these steps are
   complete, even if someone explored beyond the closed central barrier.
5. Run **north along the lit road to the wooden bridge**, about 1,000 px from the
   gate. The first standing, unhidden survivor within 64px starts an **eight-second
   team evacuation window**. Gather on the bridge before it expires.

The gate alarm is a fixed sensed location. It calls the existing stalker from up
to 6,000 px, repeatedly while powered; other creatures hear its initial/opening
noise within 1,000 px and guardians retain their territory rules. The stalker
travels normally, keeps normal sight/attack rules, and is never teleported into
the road or given an unsensed survivor position. Its arrival timing depends on
where it was when the team armed the gate. Use lights, flares, cover and the
existing chase toolkit while travelling.

| Closed checkpoint | Open gate and lit road |
| --- | --- |
| ![SpriteCook ranger barrier and booth](screenshots/ranger_gate_closed.png) | ![Raised barrier and powered road](screenshots/ranger_gate.png) |

| Gate plan | Bridge evacuation |
| --- | --- |
| ![Seeded regional code clues and gate requirements](screenshots/gate_plan.png) | ![North wooden evacuation bridge](screenshots/ranger_bridge.png) |

## Shared outcome

At departure, **standing and unhidden** survivors inside the route's circle and
with a clear path to its centre escape. If any standing survivor escapes,
connected downed teammates anywhere are recovered too. Standing survivors
outside, hidden survivors and van passengers are left behind by these routes.
No standing survivor at extraction means defeat. All-down rules still apply; there is no dawn deadline.
Results identify **BOAT** or **RANGER GATE** on every peer.

## Art and execution limits

One SpriteCook **16-piece sheet**, generated with Nano Banana 2.1 at 1K and matched
to the owned camp-object sheet, cost **12 credits** (716 → 704). It supplies the
transformer, breaker, mast, signal beacon, motor, skiff, boathouse, checkpoint,
barrier, logs, workshop, pier, Lake Thing, bridge, fuel and code notes. Alpha
source/edges were inspected; cutoff 130 was retained. No repeat generation,
paid animation or paid cleanup was needed. Sources and cropped derivatives are
recorded by asset ID/hash in [the manifest](../spritecook-assets.json).
[The slicer](../tools/slice_escape_props.gd) preserves the source and enlarges
native pixels with integer nearest-neighbour sampling for runtime sizing.

These are actual Godot night captures with enemies disabled for inspection and
camera zoom/offset adjusted to show props. The atlas is an inspection overlay;
the in-game map still reveals only explored trails.

![Seed 42 atlas with fourteen regions](screenshots/full_map.png)

Host authority covers parts, assistance, attacks, gates, holds, countdowns and
results under `lnac-net-12` (now `lnac-net-13`). See [execution evidence](evidence/boat_gate/README.md)
and [multiplayer setup](multiplayer_guide.md). Automated fixtures use placements
and accelerated clock/countdown tails. They do not prove normal-speed human
balance, real cross-machine Internet or Windows/Linux/export behavior. No
microphone feature or new audio asset was added.
