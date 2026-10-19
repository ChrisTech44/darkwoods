# Restarted Genesect server: live verification

18 October 2026. The user updated/restarted Genesect and requested metrics.
SSH confirmed clean source checkout **5debe70**, rules **lnac-net-17**. Tests joined
the regular source server on UDP 27840; no replacement server was launched, no
production code/configuration was edited, and the process was not restarted.
All explicit remote file operations stayed under `games/darkwoods`; temporary
probe files/logs remain ignored under `artifacts/live_verification`.

[Structured metrics](metrics.json) · [Inspected graphical capture](graphical.png)

## Procedure

An unready lobby probe first confirmed the updated server accepted a connection
and the lobby contained only the probe. A guarded graphical client then started
an otherwise empty round and made 60 alternating short walk/stop inputs (about
63s). A guarded headless comparator made 30 inputs in a subsequent normal round.
Each refused to start alongside ordinary players. These were normal random-seed
Woods nights: live AI, normal navigation, no staged inventory/teleports, normal
lighting, Dummy audio and voice/microphone capture off. The capture shows fog;
the first two runs did not record seed metadata and are not a controlled visual
A/B comparison. The headless replica hides scenery while retaining normal physics.

The headless comparator caught a 2.12s gap in both pose/world delivery while its
own frame intervals stayed below 21ms. A third round paired an external headless
client with a headless loopback client running on Genesect for about two minutes.
Both waited for the exact two diagnostic names before marking Ready and aborted
if another player's name was present. Shared seed **1788400090**, fog, live AI;
120 walk/stop inputs each. Both traced pose sequence numbers and local monotonic
arrival times, so correlation does not require synchronized host clocks. A first
pairing attempt safely aborted before Ready because the game truncated its long
probe names; shorter diagnostic names fixed the guard. It is not an accepted run.

The loopback client's data/config/cache overrides were project-local; it was not
an instrumented replacement for the server. No server-side CPU/frame profiler was
injected. Per-run logs contained no engine errors/warnings. Network-quality
outliers and movement-response timeouts are retained in the evidence rather than
calling every clean exit a performance pass. All diagnostic clients exited; an
unready follow-up verified the regular server still accepted a lobby connection.

## Results

| Metric | Graphical (60 inputs) | Headless external (paired) | Loopback (paired) |
| --- | ---: | ---: | ---: |
| RTT median / maximum | 63 / 82ms | 56 / 584ms | 8 / 9ms |
| Pose gap median | 49.6ms | 34.3ms | 34.1ms |
| Pose gap 99th percentile | 60.9ms | 56.4ms | 36.3ms |
| Pose gap maximum | 113.1ms | **2129.1ms** | 37.0ms |
| World gap maximum | 113.1ms | **3506.9ms** | 56.6ms |
| Visible movement-response median | 208.4ms | 157.1ms | 115.2ms |
| Responses failing the one-second leg window | 0/60 | 3/120 | 0/120 |

Movement response means displacement greater than 2px along the requested
direction. The graphical frame interval averaged **45.5ms (~22 FPS)**, maximum
78.2ms. This establishes poor frame pacing on the test Mac, not a measured CPU/GPU
cause or proof of the user's client performance. The paired external client's
own frames stayed below 38.8ms; its two-second delivery gap was not a two-second
application-frame stall.

For the worst external pose gap, sequence **916 → 965**, the loopback client
received **all 50 poses** in that inclusive range, with maximum **35.7ms** spacing
across 1634ms. Across its whole two-minute trace it had no pose gap above 37ms.
The server was therefore still generating/delivering updates locally during the
captured external interruption. This identifies the **external connection/
transport path**, not a global simulation pause. It does not yet distinguish
Wi-Fi, routing/VPN, OS networking, per-peer ENet throttling or packet loss.

The deployed small-pose stream is operating, and ordinary cadence is healthy.
Verification **does not establish consistently smooth play**: external multi-second
stalls remain, graphical frame pacing is poor, and there is still no local input
prediction/reconciliation. No product code change ships in this metrics increment.
The network-path issue and client responsiveness require separate follow-up.
