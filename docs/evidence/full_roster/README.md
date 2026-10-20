# Every creature type, every Woods night

19 October 2026. User request supersedes the old rotating-rest/night population
limit. Woods now has 31 creatures plus the Stalker (32 bodies): every one of the
22 roaming types, the Vampire/Witch and six regional guardian types. The jackals
remain a pair. Each roaming type appears once and varies in seeded location/order.
Blood Moon keeps the complete roster instead of replacing pranksters with wolves;
its faster Stalker and more frequent moon remain. Quick Camp stays Stalker-only.

Server and clients must update together to **lnac-net-21**. Enemies replicate by
seeded array index: old rules20 clients would have a missing final creature, and
could misidentify Blood Moon bodies. Rejecting the old rule set prevents that.

Executed locally on macOS Apple M2, Godot 4.7.2, microphones disabled:

- [Modifiers](modifiers.log): 34 assertions, including complete rosters across 60 seeds/modifier combinations and identical normal/Blood Moon encounter types/positions for the same seed.
- [Brains and counterplay](brains.log): 147 assertions, every type present with a brain.
- [Spawn spacing](spacing.log): 52 assertions, preserving the camp buffer, separation and forest coverage.
- [Newer creatures](new_creatures.log): 36 assertions, including all roaming types on each tested seed.
- [Dedicated source plus four clients](dedicated_source.json): 153 assertions, all 32 enemy bodies on every process, authority brains initially enabled, normal extraction/results/second round, relay and simultaneous disconnects.
- [Clean server PCK plus four clients](dedicated_pack.json): the same 153 assertions pass, with [packed authority details](pack_authority.log).
- [Package metadata and hashes](package.json): clean runtime commit `787e98b`, rules21, Godot 4.7.2. Local PCK/ZIP remain ignored. Later evidence updates do not change runtime code.
- [Authority assertions](authority.log) and [Python launcher/package gates](python.log): 12 Python tests pass.

No graphical layout/art/audio changes or new SpriteCook credits. This is targeted
roster/behavior/transport acceptance, not a new full graphical regression, human
balance, Internet or target-OS acceptance. Dedicated lifecycle fixtures freeze AI
after verifying enabled brains, supply objective parts and advance extraction
clocks; the creature suites isolate behavior with other enemies frozen. No regular
server was restarted.
