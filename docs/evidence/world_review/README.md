# World presentation and sound review evidence

18 October 2026. Godot 4.7.2, macOS Apple M2, OpenGL 4.1 Compatibility.

The fixture creates 48 actual viewport captures: ten camp buildings, two views
of each of fourteen region types, signpost/crowded bearings/phase transition,
and seven inspection-lighting views. All were visually inspected; twenty selected
screenshots are preserved here. Full output remains under ignored
`artifacts/world_review/`. Seed 42, forced all escapes, no modifiers, frozen
enemies and stopped phase progression. The phase shot forces Deep Night; it does
not prove normal-speed progression. No microphones or co-op sessions are opened.

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_world_review.gd
godot --headless --path . --audio-driver Dummy --script res://tools/audit_sound_feedback.gd
```

| Evidence | Purpose |
| --- | --- |
| [Maintenance approach](building_workshop_1168.png), [bunkhouse](building_bunkhouse_816.png), [cabin](building_cabin_224.png) | Names are dark, partially lit and near/under the top HUD. |
| [Bright Maintenance](inspection_workshop.png), [inside](inspection_workshop_inside.png) | Deliberately raised ambient with sight disabled: reveals names and piled pickup text. Not normal gameplay lighting. |
| [Normal Logging edge](label_logging.png), [bright Logging](inspection_label_logging.png) | Light reveals only fragments; inspection exposes duplicate title draws. |
| [Bright boathouse](inspection_label_boathouse.png), [bright ranger road](inspection_label_ranger.png) | Same duplicate region-title bug in both field-escape regions. |
| [Mill](region_mill.png), [orchard](region_orchard.png), [chapel](region_chapel.png), [bright mill edge](inspection_label_mill.png) | Repeated shrine composition and region titles far from center/normal visibility. |
| [Substation](region_substation.png), [relay](region_relay.png), [Logging center](region_logging.png) | Distinct machinery and contextual text. |
| [Signpost](signpost.png) | Actual sign and HUD-direction presentation. |
| [Crowded bearings](crowded_bearings.png) | Deliberately aligned help and pin signals reproduce label collision. |
| [Deep Night](deep_night_transition.png) | Current small-header/bottom-message phase presentation; no proposed cinematic title is implemented. |
| [Faded killer](inspection_faded_killer.png) | Staged faded flag, inspection lighting: body tint and persistent ground shadow. |

[Label metrics](label_metrics.json) record names, font widths and bounds for
fourteen regions. [Capture log](capture.log): 48 successful PNG writes, exit 0,
no errors/warnings in the final run. A previous run waited on a window redraw
before Logging; it was terminated. The fixture now explicitly forces drawing.
An intermediate completed run reported two ObjectDB cleanup leaks; the final
fixture closes its metrics file and lets pending phase radio timers drain before
shutdown, and its final run reported no such warning. These diagnostics do not
establish a runtime gameplay leak or graphics performance defect.

[Sound diagnostic](sound_feedback.log): exit 0. Successful air-horn use accepted
zero cues. One triggered bear trap accepted two `metal_clang` cues and one
`chain_rattle` cue. These counts are routing evidence, not a listening test.
[Registry audit](audio_registry_audit.json): 50 registered cues, no missing
referenced files and no unregistered literal playback calls in game scripts.
Dynamic cue mappings were reviewed in source separately.

Required [import](import.log) and [startup](startup.log) exited 0 without engine
errors/warnings. Both new GDScript tools also passed `--check-only`. Markdown links
and `git diff --check` passed. No gameplay source changed, so the broad gameplay
regression suite was not rerun. No Windows/Linux exports, live four-peer graphics,
real-device audio or human motion/readability acceptance was performed.

Reports: [graphics critique](../../world_graphics_review.md) and
[sound gaps/recording list](../../sound_gap_review.md).
