# Outer destinations and inward roaming starts — 20 October 2026

Historical initial distribution; the inward-only spawn rule is superseded by
the [region-circuit/interior update](../roamer_coverage/README.md). Outer-region,
objective and resource rules below remain implemented.

[Current three-seed map](sample_distributions.png) · [Before](../monster_distributions/sample_distributions.png)
· [Source positions/waypoints/van parts](plans.json) · [Execution results](results.json).

All fourteen named regions now sit in the outer band. Their scenery, guardians,
regional interactions, escape destinations and objective offsets follow them.
Camp, inner roads and existing lamp placement remain central. Ordinary unlit
approach trails connect each destination back to the inner road network;
optional gated shortcuts support the longer trip, with fences/gates still
preserving alternate access when closed.

All five required **Woods** van parts occupy five distinct outer regions each
night, covering all four cardinal pools. Battery/key are unlocked and available
from Dusk; fuel and the two selected extras retain the existing three locks and
phase unlocks. Nothing required for the van starts in camp. Camp retains lock
tools and ordinary preparation supplies. Quick Camp keeps its shorter original
camp-based three-part recipe. Fuel's corkboard clue, eight ranger notes and
ordinary regional discovery retain the distinction between direction, named
region and mapped cache. Moving parts does not reveal them to clients early.

All 29 roaming starts lie between the existing 1100px camp-center buffer and
68% of each map half-extent, on roads or within one clearing of a region approach.
One start is allocated near each of fourteen approaches; fifteen more are spread
through that transit band by seeded best-candidate placement. Eight checked seeds
have **one to four** roaming starts near each approach. This is initial placement,
not a movement fence or a guarantee of contact: patrols/pursuit and special brains
still work normally. Regional guardians remain at their outer destinations.

The new geometry/placement recipe requires **lnac-net-31**; restart/update host,
clients and dedicated authority together. This increment does not deploy a server
or rebuild the earlier local server ZIP/PCK. Mid-round recipe migration is absent.

## Executed checks

- Outer-layout suite: **594/594**, eight seeds: bounds, separation, all five
  parts outside camp/in distinct regions, approach coverage, reproducibility and
  every secondary-route objective. The all-route subsection is explicitly forced.
- Clue rotation: **15/15**, including 24 generated seed pairs, five distinct
  regions across four directions, eight notes, discovery and sealed-cache markers.
- Night phases **43/43**, native world navigation **113/113**, barriers **32/32**.
- Every pickup/door reachable across eight seeds: **1355/1355**.
- Woods replay/collection **561/561**, four-survivor regression **235/235**.
- Actual native scenery **97/97**, normal two-route nights with staged positions,
  normal lighting/sight, frozen AI/director and voice/microphones off.
- Actual listen-host/client ENet: **261/261**, labelled all-escape fixture.
- Production dedicated authority plus four actual clients: **153/153**.
- Flashlight drain/refill/flash boundaries **24/24**, chase toolkit **29/29**,
  night modifiers **34/34**.
- Required import, five-frame startup, changed Markdown links and whitespace checks.

Native screenshots were opened and inspected: [substation](boat_power_front.png),
[lakeshore](boat_lakeshore.png), [ranger gate](gate_ranger.png) and
[escape guide](escape_guide.png). The guide uses a forced all-escape fixture;
the scenery images use normal route selection. Scenery/escape-guide shots
precede the endurance/flash tune; the survival-guide shot shows final values. The diagram reveals all starts
only for this diagnostic; it does not use world lighting or simulate encounters.
Colored hulls enclose assigned waypoints, not walkable territory or chase limits.

The first layout attempt exposed outer-band/gate-count defects; outer anchors
and longer gated connectors corrected them. Two old capture fixtures also needed
proper scene-readiness waiting/synchronous rendering on background macOS windows.
The functional suites above are clean. Two active solo bot traversals were
**downed**, each ending with 129 assertions and one failure, before/after the
endurance increase. Both collected two forest parts and exhausted supplies;
that is a failed active traversal, not an unreachable-objective result. The bot
now correctly targets all required parts, including unlocked battery/key, rather
than only the locked caches. Neither probe includes the later increased flash
cost; no successful active solo playthrough is claimed. Human encounter frequency,
supply economy and trip length remain playtest gates.
Internet/cross-machine, exports and Windows/Linux remain unverified.

## Endurance and flash tuning

Full ordinary beam now lasts **840s / 14m**; isolated Alex **1120s / 18m40s**.
Actual passive drain and HUD estimates agree for ordinary, isolated and
Night-Light-doubled-drain states. Camp/light-off drain exemptions remain.
Spare batteries restore **140 charge**, capped at existing **90 capacity** (full
refill from empty); Dead Batteries restores **80**, also capped. Full lights do
not consume batteries. Space flash costs **30 charge**, three bursts from 90
before passive drain, with unchanged **8s cooldown** and stun strength.
[Inspected survival guide](survival_guide.png) shows all final values without
clipping. Its earlier overlong survival text was condensed to fit the notebook.

Dedicated checks establish the final layout recipe before the endurance tune;
listen-host checks include doubled endurance/refills before the final flash-cost
change. Final charge thresholds, rejection and unchanged flash cooldown/stun
behavior are exercised by the local endurance/chase tests. No updated exported
pack, deployed server or human balance clearance is claimed.

Reproduce the diagram:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_monster_distributions.gd -- --out=res://docs/evidence/outskirts_layout --region-labels
```
