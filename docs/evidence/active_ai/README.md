# Active enemies and interaction feedback evidence

Actual ENet UDP loopback graphical processes on macOS arm64 / Godot 4.7.2.
Two peers in both modes: **244 assertions**. Four peers in both modes:
**410 assertions**. Total **14 process runs / 654 assertions**, all passing with
zero errors/warnings. Exact launch commands, results and matching logs are in
the two reports. Network rules version is `lnac-net-3`.

```sh
python3 tools/verify_network.py --mode all --players 2 --graphical
python3 tools/verify_network.py --mode all --players 4 --graphical
python3 tools/verify.py
```

New checks use real native navigation/host AI and replicated stride/enabled
state. A closer downed body loses target priority to a standing teammate. Four
alternating host/guest down/revive cycles keep the round running and the stalker
walking; expedition also checks a roaming Relay Jackal. All 49 expedition
enemies are enabled during these cycles, with protective wards and controlled
positions for isolated assertions. Each client observes continued movement and
no premature defeat. Fixture revives complete via the production hold function;
the existing real-input timed revive remains a separate regression.

A no-kit rescuer recovers a medkit with E beside the body, then revives. An empty
interaction is sent by an actual remote peer, and only its own HUD notice is set;
the host/shared banner and uninvolved clients remain unaffected. Existing shared
light pixels, drops, authority, replay, disconnect and all-down checks remain.

The previously reported alternating-down defeat was not reproduced with a living
or boarded teammate; only current all-down triggers defeat. Downed targeting and
shared feedback were confirmed in the implementation and corrected. Stalled
navigation now recovers even when desired velocity is zero. The stalker starts
on central roads and sweeps camp before its seed-varied perimeter; no omniscient
tracking, teleports or speed increase.

These graphical fixtures do not establish human co-op balance, separate-machine
LAN/Internet, latency/jitter, other-platform exports or voice acceptance. Earlier
shared-light captures remain in `../rescue_lighting`.


Final full `python3 tools/verify.py`: **75 steps passed**, no errors/warnings.
Required import/startup plus focused slice, input-only camp/woods escape, hunt
and content logs are preserved. Camp escape uses a deterministic Jock and the
battery/fuel/key route, with a deliberate loss on the central sweep. Woods
escape uses Overprepared and ordinary belt-input counterplay with all **49
enemies active**: **200 assertions**, 12,502px walked and one flare left.
No AI disabling, teleports or outcome changes in either input-only escape.
Initial movement fixtures were isolated from the earlier patrol, and old solo
bot routes/supply strategy were updated for the stronger active enemies.
