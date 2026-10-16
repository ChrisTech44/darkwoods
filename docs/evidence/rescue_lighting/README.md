# Rescue and shared lighting execution evidence

Verified on macOS arm64 / Godot 4.7.2 using real ENet UDP loopback processes.
Two graphical peers in both modes: **177 assertions**. Four graphical peers in
both modes: **303 assertions**. Total: **14 process runs / 480 assertions**, all
passing with zero engine errors/warnings. Exact commands and results are in the
two reports, with matching raw logs. The scripted windows use host-controlled
placements/paused AI to isolate authority and replication; this is not human
balance or actual separate-machine Internet acceptance.

```sh
python3 tools/verify_network.py --mode all --players 2 --graphical
python3 tools/verify_network.py --mode all --players 4 --graphical
python3 tools/verify.py
```

New checks exercise a single down dropping all objectives/supply units once,
loot outside the prone body, persistence through repeated hits and 120 simulated
seconds, rejected no-medkit revive, one consumed kit/no bonus refresh, and a
successful van escape rescuing the connected downed teammate. Disconnect also
releases all gear. Existing lobby/rules/authority/partial-packet/replay checks
remain active. The rules version changed to `lnac-net-2`; both copies must update.

Shared-light checks verify the remote beam and replica flare have active native
lights, then compare actual rendered terrain brightness before/after. HUD,
survivor sprites and flare particles are excluded. The PNGs are unedited engine
captures of client views; representative captures were opened for visual inspection: centered names,
shared beams/flares and accessible downed gear. The local woods sight mask and
wall shadows still apply; lighting does not reveal terrain through walls.

`content.log` records **350 passing assertions**, including all six roles in
both modes, dropped starting supplies and no bonus refresh. An initial full-run
content fixture still expected supplies to remain after downing; it was updated
to assert the new drop-all rule. The final full regression rerun passed **75 steps**, with no errors/warnings;
`offline_summary.json` preserves commands/results. Required import/startup and
focused offline slice/woods/content logs are included.
Real cross-machine LAN/Wi-Fi/Internet, human balance, other platforms/exports,
latency/jitter and microphone/voice acceptance remain unverified.
