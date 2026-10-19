# Dedicated server execution evidence — 18 October 2026

macOS arm64, Godot 4.7.2, local independent ENet processes, Dummy audio and
microphone capture off. Clients run the published main checkout (`dc96c64`).

| Check | Result |
| --- | --- |
| [Quick Camp, source server + 2 clients](camp_2_summary.json) | 28 + 7 + 7 assertions; clean |
| [Woods, exported PCK + 4 clients](woods_4_pack_summary.json) | 37 + 4 × 8 assertions; clean |
| [Player-hosted Camp regression](listen_host_camp_2_summary.json) | 105 host + 29 guest + 2 late-join assertions; clean |
| [Simultaneous departure stress](woods_4_simultaneous_summary.json) | 69 gameplay assertions passed; **strict harness failed on 3 ENet errors** |

Each dedicated run checks movement, authoritative installation/extraction,
no server survivor/slot, no server voice codec/capture/playback, automatic lobby
reset, a second round, role/inventory reset, departing focus reassignment and
empty-server world cleanup while the listener remains active. Woods seed 13
uses the normal van/boat combination, not a forced all-escape fixture. Quick Camp
uses seed 42. Enemy AI is frozen after loading, inventory/positions are staged,
and extraction timers are advanced; this is authority/lifecycle verification,
not creature-balance or ordinary-play acceptance.

Headless logical replica fixtures hide the world to suppress scenery rendering;
normal navigation/physics remain enabled. The separate normal graphical client
passed 26 server + 10 client assertions through two rounds, without that hiding:
see [graphical captures and result](../scenery_startup/README.md). Main's required
palette comparison passed 1,768 pixel comparisons against the old algorithm.

The normal package test staggers final client departures by 0.35s × client index.
The stress test uses `--simultaneous-disconnect`; it records the observed
`Unable to send packet on channel 0, max channels: 0` errors without suppressing
them. The server still passed empty-world/listener cleanup checks. This remains
an unresolved diagnostic issue, not a clean acceptance result. Earlier package
runs with simultaneous departures were likewise rejected by the strict harness.

Required import/startup checks and Python compilation passed; invalid port,
player-count and mode configurations exited 2 with `server_error`. The launcher
also rejected an invalid minimum. The portable export completed cleanly.

Reproduce from headless-server (substitute your main checkout):

```sh
python3 tools/verify_dedicated.py --mode camp --players 2 --client-path /path/to/main
python3 tools/package_server.py
python3 tools/verify_dedicated.py --mode woods --players 4 --pack artifacts/server/last-night-server.pck --client-path /path/to/main
python3 tools/verify_dedicated.py --mode woods --players 1 --graphical-clients --client-path /path/to/main
python3 tools/verify_dedicated.py --mode woods --players 4 --simultaneous-disconnect --client-path /path/to/main
python3 tools/verify_network.py --mode camp --players 2
```

Raw logs and generated packages remain ignored in artifacts. No Linux/Windows,
exported-client, separate-computer LAN, Internet, sustained-load or human listening
acceptance is claimed. The PCK requires a target-OS Godot 4.7.2 runtime; no native
Linux binary or deployed hosting account was produced.
