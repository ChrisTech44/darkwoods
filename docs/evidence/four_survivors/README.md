# Four-survivor implementation evidence

19 October 2026. Godot 4.7.2, macOS, OpenGL Compatibility, 384×216 viewport.
These are executable diagnostic checks and actual graphical captures, not a
human balance/playability acceptance or likeness artwork delivery.

## State and movement

- [Kit/catalogue results](kits.log): 138 checks, zero failures; four unique
  systems, all 30 sample activations, specific counters/adapters, source receipts,
  settlement and handoffs. Frozen AI and forced all routes expose every objective.
- [Prediction results](prediction.log): 81 checks, zero failures; shared movement,
  isolated/channel/mower states, valid authority packets and four-player size cap.
- [Four-player real ENet run](network_four.json): authority 265 checks, clients
  33/60/60 checks, zero failures; missing-world-fragment movement, guest samples,
  extraction, rescue, retries and disconnect cleanup. Loopback, headless, no voice.
- [Import](import.log) and [five-frame startup](startup.log): clean.

## Graphics

[Capture log](gallery.log). Reproduce:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_four_survivors.gd
```

Voice/microphones off. Seed 42, diagnostic all routes/no modifiers, enemies and
night clock frozen; staged poses at a checked traversable camp position (300,400).
Normal fog-night lighting and sight remain enabled. No bright inspection views
are included below. Earlier quarry poses could overlap scenery; the fixture now
asserts traversability. Temporary form textures stay referenced during redraws.
All four selector cards and selected state/form captures were opened and inspected.

| Selection | State/form |
| --- | --- |
| [Christian](select_christian.png) | [Moon form](christian_werewolf.png), [Scarecrow](christian_briar_revenant.png), [Mower](christian_groundskeeper.png), [Mimic](christian_mimic.png) |
| [John](select_john.png) | [Pending debt](john_debt.png), [settlement](john_paid_debt.png) |
| [Max](select_max.png) | [Held stake](max_stake.png), [recoverable spill](max_cash_spill.png) |
| [Alex](select_alex.png) | [Channel](alex_channel.png), [returned with cooldown](alex_returned.png) |

Existing portraits/sheets stand in for the friends. Tiny HUD text and dark woods
retain the wider graphics backlog. These frames do not verify every animation,
source acquisition in a live round, hostile/friendly targeting case or four-peer
visual arrangement. Listening, real microphones, cross-machine Internet and
packaged desktop/platform tests are separate gates.
