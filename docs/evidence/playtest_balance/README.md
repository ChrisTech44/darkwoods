# Friends playtest follow-up — 18 October 2026

Actual Godot 4.7.2 / macOS arm64 / OpenGL Compatibility output. Normal seeded
nights (van plus one secondary), no modifiers; every secondary route generated
by the test. AI is frozen. Normal fog-night lighting is preserved. The boat
fixture stages the carrier on the dock, forces Witching Hour and a large phase
elapsed value to check the pressure cap, then freezes progression. The phase
banner is hidden to isolate the repair labels. The Witch is staged beside the
dock with each cast frozen mid-wind-up. These are diagnostic views, not a human
balance session or online playthrough. Microphone capture was not enabled;
Godot used the Dummy audio driver.

Command:

```sh
godot --path . --fixed-fps 60 --audio-driver Dummy --script res://tests/integration/playtest_balance.gd -- --capture
```

Result: **30 checks, zero failures**, including seven image writes. All seven
were inspected. The initial completion row entered the belt area; the final
repair panel and boat were moved north within the dock, and the captures rerun.

- [Carry motor to the marked repair pad](boat_repair_motor.png).
- [Motor installed; fuel and plug still missing](boat_repair_installed.png).
- [Plan names the carrier and destination](boat_plan_carried.png).
- Distinct curse tells: [Frog](witch_frog.png), [Backwards](witch_backwards.png),
  [Swap](witch_swap.png), [Float](witch_float.png).

The normal boat-only fixture exposed an existing dependency on Radio Rescue's
active flag; this prevented boat interactions outside the all-escape diagnostic.
Boat proximity now checks its own active route, actor, range and clear path.

[Focused suite summaries](summary.json): 1,300 checks.
[Real-peer summaries](network_summary.json): 375 checks (Quick Camp and Woods,
two peers plus rejected late join). Final import/startup exited 0 with no engine
errors or warnings. The development log distinguishes earlier failed fixtures
and the incomplete broad-run attempt from final focused verification.
