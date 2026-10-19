# Player transport execution evidence — 18 October 2026

- [One-client real-network comparison](single_client_comparison.json): old rules 16
  versus final rules 17 (30Hz player poses, 20Hz world). Genesect Linux Snap Mono
  4.7.2 source server; macOS 4.7.2 source client. Synthetic headless replicas hide
  scenery; normal physics/navigation and live AI remain. Normal seed-13 van/boat
  objectives, no staged teleport/inventory or altered lighting. No microphones.
- [Server timings](server_timings.json): baseline, final single-client and final
  four-client source-server measurements. No engine errors/warnings. The Net tick
  is wrapped once per normal physics frame by the diagnostic script; its aggregate
  timings also include the idle wait after clients leave.
- [Four real clients](four_clients.json): one graphical, three headless on the same
  Mac; no engine errors/warnings. Live AI and ordinary up/down walk intents on the
  isolated Genesect server. Four-player pose payload is 216 bytes. Final departures
  were staggered to separate the known simultaneous-close diagnostic.
- [Actual graphical capture](four_clients_graphical.png), inspected: normal camp
  lighting/rain after the scripted walks; other clients may have departed by the
  capture, leaving dropped gear. The graphical client's frame interval averaged
  47.3ms (about 21 FPS) in this four-process run, with 79.5ms maximum. Its mean RTT
  rose to 145ms while a headless peer averaged 60ms; this requires client rendering/
  scheduling investigation, not a claim that server CPU caused the delay. Four
  worlds on one Mac are not four separate players' computers.
- [Final listen-host regressions](listen_host_regression.json): 379 assertions,
  Camp 106 host + 30 guest + 2 late; Woods 181 + 58 + 2. Includes deliberately
  missing world fragments while new player poses continue to arrive and render,
  rejection of partial world state, later recovery, authority/forgery checks,
  objectives, extraction and fresh-round lifecycle. These fixtures use frozen
  enemies/staged positions and all-escape layouts; they are distinct from the
  normal-night real-network probes.

Required final main import/startup and diff checks passed cleanly. No full broad
regression run is claimed. Raw logs remain ignored in artifacts; host addresses
are omitted from this selected evidence. The main
[investigation](../../network_lag_investigation.md) records remaining latency,
rendering, correction and prediction limits. Source-server Linux execution is
established on this host; Linux PCK, Windows and real voice listening are not.

On the dedicated branch, the merged rules-17 exported PCK also passed
[37 server + 4 × 8 client assertions](dedicated_pack_four.json), clean. This checks
movement, authoritative boat extraction, automatic lobby reset, fresh round and
staggered disconnect cleanup against updated main clients. As with the earlier
dedicated fixture, AI/parts/positions/extraction time are staged; this is separate
from the normal live-AI Genesect timing runs above. Four Python launcher tests
also passed; final server import/startup and package export were clean.
