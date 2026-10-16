# Menu, random-default and woods-shadow evidence

Actual Godot 4.7.2 / macOS arm64 execution. `menu_defaults.gd` tests both modes
through menu Play, fresh random seeds/layouts, explicit seed/retry, menu music and
pre-game mixer persistence. Temporary preferences are removed and restored.

`woods_shadows.gd` checks full border polygons and safe head-offset emitters.
Graphical probes compare flashlight off/on on the current and adjacent paths,
with horizontal and vertical closed links. Disabling border occluders is a
positive control that reproduces the spill. That unblocked image is a fixture,
not the shipped lighting. Other lights are disabled only for these measurements.

Camp overviews use brighter inspection lighting/a wider camera; normal play
uses the local flashlight. Current path light remains usable in the separate
active camp/woods input-driven escape suites.

Human listening, exported Windows/Linux audio and network/voice remain
unverified. The Word brief matches the Markdown requirements structurally;
visual DOCX rendering is unavailable because the existing renderer dependencies
and LibreOffice are missing. No microphone capture or permission request.
