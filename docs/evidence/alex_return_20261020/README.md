# Alex return drawbacks — 20 October 2026

Historical timing snapshot; marker lifetime/cooldowns are superseded by the
[later tuning](../ability_cooldowns_20261020/README.md).

The host now requires seven uninterrupted seconds to return. Any enabled monster
within 300 world pixels of Alex blocks starting or cancels progress, through
walls, using the heartbeat proximity constant independently of audio settings.
The marker retains its remaining lifetime after interruption; the existing 2s
retry guard applies and X starts a fresh full channel when clear.

On completion one host roll selects a marker return (2/3) or a random valid
landing across the map (1/3). Either arrival consumes the marker and starts the
40s cooldown, preserving gear, charge and injuries. Random sampling rejects
walls, barriers and water. A bounded search failure retains the marker using the
existing blocked-landing retry path. Monsters at a random destination do not
prevent that completed misfire; the proximity check is around Alex before departure.

[Results](results.json): four-survivor suite **228/228**; actual four-person
listen-host and dedicated disabled-ability/authority suites **79/79**. The new
completion branches, exact radius, moving-enemy/moving-Alex interruption,
completion-tick interruption, disabled enemies, preserved marker/state and full
restart are exercised in the gameplay suite. The networking checks establish
existing authority gates, not a separate online random-return scenario.
Required import/startup and whitespace checks pass on macOS arm64 / Godot 4.7.2.

Native captures were inspected for readable, unclipped text:

- [Seven-second HUD](seven_second_return.png).
- [Monster blocks return](blocked_status.png).
- [Compact guide with disabled-powers header](survivor_guide_disabled.png).

These are staged seed-42 scenes, frozen AI/director, forced all escapes and
normal Dusk lighting. Voice/microphones remain off; Dummy audio is used. An early
capture exited without the audio shutdown hook and leaked objects; the final
capture uses normal audio shutdown and has no engine warnings/errors. The guide
previously clipped Alex after the other survivors; compact copy now fits all
four plus the optional host-rule header. No gameplay was changed by that text fit.

Human balance, Internet/cross-machine and Windows/Linux checks remain open.
The local MP4 gallery predates these changes and has not been re-recorded.
