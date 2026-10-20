# Ability cooldown tuning — 20 October 2026

This tuning supersedes the marker lifetime/cooldown values in the earlier
[Alex drawback evidence](../alex_return_20261020/README.md).

- Alex: marker lasts 60s. Completed teleport (normal or random) starts 120s
  before another marker can be placed. Expiring an unused marker does not start
  that cooldown. Seven-second channel and two-second interrupted retry remain.
- Max: 120s from starting a spin, including interrupted spins.
- John: 60s from activation, including the six-second damage-deferral window.
- Christian: unchanged.

[Results](results.json): roster **235/235**, wheel/monster **86/86**. Checks
exercise marker expiry, blocking replacement before the full two minutes,
both arrival outcomes, John's timer and interrupted Max spins. Required import,
five-frame startup and whitespace checks pass without engine errors/warnings.

Inspected [Max selection](max_selection.png) and [survivor guide](survivor_guide_disabled.png)
show the updated durations without clipping, including the disabled-powers header.
The world capture is staged seed 42 with frozen AI/director, forced all escapes,
normal Dusk lighting and voice/microphones off; playback uses Dummy audio.
No new art/audio, human balance, Internet/cross-machine or Windows/Linux evidence.
Earlier videos and evidence retain their historical timings.
