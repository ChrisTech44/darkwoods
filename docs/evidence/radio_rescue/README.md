# F5a Radio Rescue — execution evidence

Executed on macOS arm64 with Godot 4.7.2. Human normal-speed playtests were
explicitly deferred by the user; these are isolated mechanics/authority checks.

| Check | Result | Evidence |
| --- | --- | --- |
| Godot full regression | 109 steps passed; zero errors/warnings | [Verification summary](verify_summary.json) |
| Radio Rescue, headless | 34 assertions, zero failures | [Headless log](radio_headless.log) |
| Radio Rescue, real window | 36 assertions, zero failures; includes two model-visibility pixel comparisons | [Graphical log](radio_graphical.log) |
| Two-peer Woods, graphical | 170 assertions across host, client and late-join probe; all passed | [Summary](summary_woods_2_graphical.json), [host](woods_2_host_0_graphical.log), [client](woods_2_client_1_graphical.log) |
| Four-peer Woods, headless | 276 assertions across four processes; all passed | [Summary](summary_woods_4.json), [host](woods_4_host_0.log) |
| Two-peer Quick Camp, headless | 129 assertions across host, client and late-join probe; all passed | [Summary](summary_camp_2.json) |

The remote player collects the unique fuse, restores power, holds transmit,
lights all signals, starts the holdout and receives the same result as the host.
Signal lamps are enabled on each client. The four-peer case also checks a
mid-round disconnect; the radio finale recovers a downed host. The final
2-peer graphical run additionally checks the replicated RADIO RESCUE result route.

Host-only placements and accelerated phase/countdown tails isolate mechanics.
They do not prove normal-speed pacing, human balance, two-machine Internet,
listening quality or other desktop platforms. No new audio or microphone work
was performed. No new SpriteCook generation credits were spent.

Actual night views and the updated eleven-region inspection atlas are in the
[illustrated guide](../../radio_rescue.md). Source capture fixture:
[radio_rescue.gd](../../../tests/integration/radio_rescue.gd).

Reproduce:

```sh
python3 tools/verify.py
godot --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/radio_rescue.gd -- --capture
python3 tools/verify_network.py --mode woods --players 2 --graphical
python3 tools/verify_network.py --mode woods --players 4
python3 tools/verify_network.py --mode camp --players 2
```
