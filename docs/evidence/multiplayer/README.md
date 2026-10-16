# ENet multiplayer execution evidence

`summary.json` indexes **24 independent-process runs / 685 network assertions**,
all passing with no errors/warnings: two peers in both modes (including late-join
refusal), four peers in both modes, and two actual graphical windows in both
modes, plus four graphical Camp windows (124 assertions). The default game port is UDP 27840; the test runner uses isolated ports
27943/27945/28043/28045, plus 1000 for graphical tests. Commands and per-process
results are preserved in the four `summary_*.json` reports and their logs.

```sh
python3 tools/verify_network.py --mode all --players 2
python3 tools/verify_network.py --mode all --players 4
python3 tools/verify_network.py --mode all --players 2 --graphical
python3 tools/verify_network.py --mode camp --players 4 --graphical
```

The harness operates actual Host/Join lobby button callbacks and sends player
controls/actions over real ENet. It checks rule/ready reset, two-way movement,
contested single-award pickup, rejected forged actions/role/nonfinite direction,
death/teammate rescue and one-time supply use, dropped units/flares, woods bolt/
patch replication, remote mechanic ignition, all-peer boarding/escape, clean
same-seed retry, objective recovery on disconnect and host loss. It intentionally
omits snapshot pieces and verifies incomplete states are never applied and the
next complete state recovers. Largest snapshot payload pieces are at most 1000
bytes, below the transport warning threshold.

The host uses controlled positions, inventory/damage and paused AI for isolated
network rules. These are not input-only human horror rounds. The prior offline
active-enemy escape is recorded in `../denser_forest`. `offline_summary.json`
records 75 passing baseline engine steps; `drop_pool_content.log` adds the final
326-check content regression, including twenty drop/recovery cycles without
pickup-list growth. Final required import/startup logs are preserved.

The network PNGs are unedited engine viewport captures of the connected lobby and
the host/client views in both modes. All were opened and visually inspected.
Additional menu (39 checks) and content (344 checks) graphical logs/captures
verify the corrected selection, item-bar and lobby spacing.
Each uses scripted inputs in real graphical windows; no physical second computer
or human mouse/keyboard smoke is implied.

Verified macOS arm64 / Godot 4.7.2, loopback only. Real cross-machine LAN/Wi-Fi/
Internet/VPN, human balance, jitter/high latency, Windows/Linux and exports remain
unverified. No microphone APIs or voice payloads are initialized. Local audio
follows replicated sources; exactly-once synchronized-audio/listening acceptance
and proximity voice retain separate gates. See [connection guide](../../multiplayer_guide.md).
