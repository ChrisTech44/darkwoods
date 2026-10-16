# Offline content execution evidence

`summary.json` preserves the full 69-step headless verification report (all pass,
zero errors/warnings), plus final focused checks and the graphical-content run.
Original runner log paths under `artifacts/verification` are regeneratable;
selected durable logs are preserved here: input-driven camp and expedition
playthroughs, native navigation/region reachability, final content, forest hunt,
woods visibility and graphical content.

Final focused headless content: 301 assertions, zero failures. Graphical content:
309 assertions including eight screenshots, zero failures. Graphical command:

```sh
godot --path . --audio-driver Dummy --fixed-fps 60 \
  --script res://tests/integration/content_expansion.gd -- --capture
```

The PNGs are unedited Godot viewport captures, opened for visual inspection.
`survivor_selection.png` shows the actual selection screen.
`item_belt.png` uses ordinary production night lighting, with supplies packed by
a fixture to demonstrate all six slots. `biome_*.png` are art inspection captures:
sight mask disabled, ambient brightened, camera zoomed out and actors positioned
at each optional landmark. They do not establish production visibility, human
play or balance. Dedicated visibility/navigation regressions pass separately.

macOS arm64 / Godot 4.7.2 only. No Windows/Linux/export/network/voice or microphone
permission acceptance is implied. See [implemented rules](../../content_update.md).


The follow-up README guide correction adds `monster_*.png`: seven native-zoom
close-ups of the new species, captured with AI disabled, brightened ambient,
sight masking disabled and the camper hidden with its local lights disabled for an unobstructed monster portrait.
`guide_graphical.log` records the refreshed graphical tour: **316 assertions,
zero failures, 15 PNG captures**. The original 309-assertion content run above
remains preserved separately. The close-ups are inspection fixtures, not combat
or human-play evidence. All seven were opened and visually inspected.
