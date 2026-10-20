# Region circuit and evenly filled interior — 20 October 2026

[Open regenerated maps](sample_distributions.png) · [Previous layout](../outskirts_layout/sample_distributions.png)
· [Source plans](plans.json) · [Before/after measurements](comparison.json).

The earlier inward-only policy left an outer lap connecting the regions with
few roaming starts. The 29 roamers now split into:

- **14 circuit starts**, targeting equal arc-length intervals around the polygon
  joining region centers, with a seeded starting phase. Starts select clearings
  within 384px of the circuit, avoiding region footprints and seeking 600px
  separation from creatures already placed, including guardians.
- **15 interior starts**, repeatedly choosing the clearing farthest from existing
  creatures throughout the enclosed forest. The 1100px camp-center quiet buffer
  and region exclusions remain. A tiny seeded tie-break preserves repeatability.

These are placement rules, not hard territories or forced encounters. Special
brains, patrols and pursuit remain unchanged. The dashed diagram circuit is a
geometric guide, **not a new road**; actual movement follows the existing trails.
Halos identify the fourteen circuit starts, plain circles the fifteen interior
starts. Sample colored hulls enclose assigned patrol waypoints, not chase limits.
Gray diamonds identify regional creatures. The Stalker is excluded from this
spawn comparison. All starts are revealed only in this diagnostic artifact.

The outer regions, five separately placed van parts, clues, lighting, resources
and monster population are preserved. All three illustrated seeds retain exact
van-part assignments/positions. The recipe version is **lnac-net-32**; update and
restart clients/server together. No live server deployment or package refresh.

## Coverage measurements

Values below are the largest sampled straight-line distance to the nearest
initial **roaming** start. Smaller means fewer spatial coverage gaps; the metric
does not count walls, future movement, detection radius or actual encounters.
The circuit is sampled at intervals no greater than 96px; interior samples are
clearing centers outside regions and the camp quiet buffer.

| Seed | Circuit before → after | Interior before → after |
| --- | --- | --- |
| 13 | 2193 → 1156px | 2121 → 1229px |
| 42 | 2308 → 1408px | 1891 → 1462px |
| 2026 | 2477 → 1093px | 2147 → 1229px |

The map is rendered natively from actual Godot 4.7.2 `RoundPlan` output on macOS
arm64, then opened and inspected. No simulated movement, lighting override,
frozen gameplay actors, forced escape routes, paid generation or microphone use.
Eight-seed placement tests cover the 14/15 split, spacing, circuit/interior gaps,
quiet buffer, reproducibility, region bounds and all existing objective rules.
[Execution results](results.json): **522/522** placement checks, **113/113**
native navigation, **261/261** listen-host/client (explicit all-escape fixture),
and **153/153** four-client dedicated checks. Import, startup, Markdown links
and whitespace checks pass. Voice/microphones remain off.

The earlier [active solo bot limitation](../outskirts_layout/README.md) remains
open; active solo traversal and human encounter-frequency/balance testing were
not repeated. These source/placement checks do not establish playtest acceptance.
Internet/cross-machine, packaged platforms and Windows/Linux remain unverified.

Reproduce:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_monster_distributions.gd -- --out=res://docs/evidence/roamer_coverage --region-labels
```
