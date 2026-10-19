# Player skipping: Genesect network investigation

18 October 2026. Source server on Genesect: Linux Snap **Godot 4.7.2 Mono**;
source clients: macOS Godot 4.7.2. Remote commands/files were confined to
`games/darkwoods`. The regular server on port 27840 and its tracked checkout were
left unchanged. A separate, self-terminating server used UDP 27841 and an isolated
source copy under `artifacts/lag_probe/checkout`.

## Findings and implemented increment

The old client waits for complete compressed world snapshots before updating any
survivor's position. Woods snapshots in the one-client probe averaged 4.8 KB,
requiring about five unreliable ordered RPC packets. A missing/reordered piece
can prevent that entire snapshot from applying. Rendering snaps directly to its
target once the discrepancy exceeds 80px. A separate synthetic replay of the
actual smoothing function produced a 115.5px step after a one-second snapshot gap;
that is a controlled reproduction, not proof of a one-second Genesect outage.

Actual baseline playback over the Genesect path had a **669ms maximum complete
snapshot gap**, 79 skipped snapshot sequences in roughly 24s, and 184ms median
input-to-visible-movement delay. RTT averaged 58ms. Genesect's physics intervals
remained near 16.7ms, with a 33.3ms maximum; its wrapped Net tick peaked at 2.3ms.
That run does not implicate server simulation overload. It cannot rule out other
loads or stalls during the friends' original play session.

Implemented rules **lnac-net-17** on main, also required by the dedicated branch:

- Player position/velocity/facing travel in a small independent 30Hz authority
  packet. One player uses 60 payload bytes; four use 216, below the 900-byte bound.
- Full world state stays at the intended 20Hz. Accumulating the period with a
  small comparison tolerance fixes the former floating-point countdown, which
  could send every fourth 60Hz tick (15Hz) instead of every third.
- World fragments use unordered unreliable delivery. The existing sequence/part
  assembler accepts reordered parts, rejects incomplete state and discards old
  sequences. Player poses already received on the independent stream cannot be
  overwritten by an older full-world snapshot.
- Damage, inventory, stamina, AI, collision and objectives remain authoritative.
  Voice keeps channel 3. Input and player poses use channel 2 in opposite
  directions; world fragments use channel 1, reliable commands channel 0.

## Actual comparison and limits

The final one-client 30Hz player/20Hz world probe measured:

| Measurement | Before | Updated |
| --- | ---: | ---: |
| Average RTT | 57.8ms | 53.6ms |
| Player update median gap | 69.0ms (whole snapshot) | 34.4ms |
| Player update 99th-percentile gap | 331.7ms | 70.5ms |
| Player update maximum gap | 668.9ms | 134.7ms |
| Complete world sequence skips | 79 | 13 |
| Input-to-visible movement median | 183.6ms | 170.9ms |
| Input-to-visible movement maximum | 261.4ms | 345.5ms |

These are short successive real-network runs, not a controlled network emulator.
The packet-loss estimate and traffic conditions varied. **Input latency is not
resolved**: its tail was worse in the final sample, despite much steadier player
updates. There is still no local prediction/reconciliation. That is the next
movement-responsiveness increment; do not describe this transport improvement as
instant input or a complete cure for player skipping. The 80px correction rule
also remains for long interruptions or genuine authority-driven relocations.

An intermediate trial reduced full-world rate to 10Hz. That is not the final
implementation: it was rejected to preserve the intended world-update cadence.
Its 152ms median response and 104ms maximum motion gap must not be substituted for
the final results above.

The probes use normal seed-13 van/boat selection, live AI, unchanged lighting and
no staged teleports/parts. Headless logical replicas suppress scenery drawing;
normal navigation and physics remain enabled. The server diagnostic wraps the
existing Net tick once per physics frame to time it. Server aggregate timings
include its idle wait after clients leave. No microphones were enabled. The
single-client comparison isolates simulation/network from graphical preparation.
Four-client graphical evidence and local authority regressions are recorded in
[selected evidence](evidence/network_transport/README.md).

## Reproduce

Use a spare UDP port on the dedicated branch and a separate checkout so a running
night is not disturbed. For a one-client source server:

```sh
godot --headless --audio-driver Dummy --path . --import
godot --headless --disable-render-loop --audio-driver Dummy --path . --script res://tools/probe_network.gd -- --dedicated-server --port 27841 --mode woods --seed 13 --min-players 1 --start-delay 1
```

From an updated source client checkout:

```sh
LNAC_PROBE_HOST=SERVER_ADDRESS LNAC_PROBE_PORT=27841 godot --headless --disable-render-loop --audio-driver Dummy --path . --script res://tools/probe_network.gd
```

The client marks Ready and alternates short up/down walks for 24 legs, then leaves.
The diagnostic server times out if nobody joins and exits after the measurement.
For graphical checking omit `--headless --disable-render-loop`; optionally set
`LNAC_PROBE_CAPTURE` to an absolute PNG path in an existing artifact directory.
For four clients set the server minimum to four and launch four clients before the
round starts. `LNAC_PROBE_LEAVE_DELAY` staggers their final departures when testing
ordinary cleanup separately from the known simultaneous-disconnect ENet error.
