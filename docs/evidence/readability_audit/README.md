# Interface readability baseline — 18 October 2026

Godot 4.7.2, macOS Apple M2, OpenGL 4.1 Compatibility. These are actual
384×216 viewport captures with normal lighting/sight, viewed at native resolution.
Seed 42, forced all escapes, no modifiers, frozen enemies and stopped night clock.
The fixture preserves local saved settings; screenshots can show different mixer
or microphone-mode selections on another machine. It does not join co-op or
enable microphone capture. This is a diagnostic scene, not a normal playthrough.

Reproduce from the project root:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_readability_audit.gd
```

Output: `artifacts/readability_audit/*.png`. All ten PNG writes returned `OK`;
the completed graphical process exited 0 with no engine warnings/errors.

| Capture | Observed purpose |
| --- | --- |
| [Camp van](camp_van.png) | Map covers objective hints; panel/frame extends into belt space. |
| [Battery installed](battery_installed.png) | Fixture consumes battery pickup, delivers battery through van logic: 1/5 installed, but map still draws marker 1 at original battery location. |
| [Woods van](woods_van.png) | Same overlap; anisotropic local-map scale. |
| [Radio](page_radio.png) | Secondary plan without map. |
| [Boat](page_boat.png) | Secondary plan without map; cramped instructions. |
| [Gate](page_gate.png) | Multiple prerequisites presented as text rather than clear states. |
| [Signal](page_signal.png) | Dense multiline plan. |
| [Long notice](long_notice.png) | Staged sabotage text competes with contextual help; this does not execute sabotage. |
| [Pause](pause.png) | Settings layout at current saved configuration. |
| [Field guide](field_guide.png) | Obsolete fixed-cache and solo-only help. |

All ten images were visually inspected. Baseline captures are evidence of defects,
not a claim those defects have been fixed. See the
[audit and delivery plan](../../graphics_readability_plan.md).

Required [import](import.log) and [startup](startup.log) checks completed with
exit 0, without engine errors/warnings, outside the filesystem sandbox.
Initial sandboxed attempts printed macOS service/editor-settings/user-log errors
despite exit 0; those were not counted as passes. A second sandboxed graphical
launch stalled with window-service errors and was terminated; the final graphical
run above completed outside the sandbox. The first graphical run completed nine
captures; the final ten-capture run added the consumed/installed-marker case.

No gameplay source changed. Broad regression suites, Windows/Linux exports,
live four-peer layouts, real microphones and human comprehension testing were
not run for this documentation/capture increment.
