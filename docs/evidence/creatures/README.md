# New creatures, Groundskeeper mower, region centrepieces and entrances: evidence

18 October 2026, Godot 4.7.2, macOS Apple M2, 384×216, normal lighting.
Staged captures (`tools/capture_new_creatures.gd`): seed 42, every spawned
creature moved away and frozen, the subject creature placed on a woods trail in
front of the survivor with the flashlight on, AI disabled and its state forced
(Groundskeeper heading/dismount, Cuckoo count 2, Banshee mid-inhale, slime
puddles added, LOST applied, Hitchhiker climbed on, a tarot card applied), night
clock stopped. Entrance shots refill the flashlight before each frame; the
chapel/mill shots are dark because nearby guardians (the Snuffer) still affect
light. `relic_*` are from `tools/capture_world_review.gd` (all escapes forced,
enemies frozen); place titles there can lag one placement because the fixture
teleports.

| Images | Shows |
| --- | --- |
| [riding side](groundskeeper_riding_side.png), [front](groundskeeper_riding_front.png), [parked](groundskeeper_on_foot_parked.png) | Mower views with the Groundskeeper aboard; parked mower with him on foot with his rake |
| [cuckoo](cuckoo_counting.png), [banshee](banshee_inhale.png), [slug](slug_trail.png), [surveyor](surveyor.png), [LOST map](lost_map.png) | Count pips and bird, breath ring, slime trail, the Surveyor, and the scribbled LOST map with `LOST · ???` |
| [hitchhiker](hitchhiker.png), [riding](hitchhiker_riding.png), [tollkeeper](tollkeeper.png), [echo](echo.png), [card](fortune_teller_card.png) | Ghost child, child on a survivor's back, toll ring, translucent Echo, the Tower card |
| `entrance_*` | Region gateway objects at each main approach |
| `relic_*` | Distinct searchable centrepieces replacing the shared altar |

Commands: `godot --path . --audio-driver Dummy --script res://tools/capture_new_creatures.gd`
(exit 0, 22 PNGs) and `tools/capture_world_review.gd` (exit 0). Images were opened
and inspected. Not established: live chase feel (mower turning, speed tuning),
balance of the tarot table and tollkeeper placement, multiplayer play of TAG,
LOST guidance or the Echo's client whistle, or listening checks.
