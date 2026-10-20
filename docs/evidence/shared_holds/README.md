# Online hold ownership — 20 October 2026

The server previously chose the lowest-ID eligible holder every tick. A lower-ID
player joining a higher-ID player's van-start/revive hold changed the operator,
and the hold implementation reset progress. Authority selection now prefers the
current operator while that operator is still eligible. Radio and gate already
used this policy. Boat progress uses shared occupancy instead of operator holds.

Other holders cannot reset or multiply progress. An actual operator change
(release, range, downing or disconnect) still begins a new hold from zero.
This does not change packet state, installed parts or completed objectives;
protocol stays `lnac-net-33`. Restart/update peers to load the code change.

[Results](results.json): staged authority checks **12/12**, real ENet Woods
listen-host/client regression **265/265**, no errors/warnings. Import/startup,
Markdown file links and whitespace checks pass on macOS arm64/Godot 4.7.2.
The regression starts the remote client's ignition, waits for progress, then has
the lower-ID host join; the original operator must finish/board and each client
must observe nondecreasing progress. The authority fixture also checks helper
release, single-rate work, real operator release/range/disconnection and revives.

```sh
godot --headless --path . --import
godot --headless --path . --quit-after 5
godot --headless --path . --fixed-fps 60 --script res://tests/integration/shared_holds.gd
python3 tools/verify_network.py --mode woods --players 2
```

Raw logs are ignored under `artifacts/shared_holds/` and `artifacts/network/`.
Authority tests stage poses/inputs with frozen game simulation; the real ENet
suite uses its existing forced all-escape fixture and staged placements.
No microphone, new graphics, human pacing, Internet/cross-machine, exported-build
or Windows/Linux acceptance. The drawing-only targeting-circle removal was
verified/published separately before this fix.
