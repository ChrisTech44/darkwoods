# Notebook, moon dial, radio transcript and label fixes: evidence

18 October 2026. Godot 4.7.2, macOS Apple M2, OpenGL Compatibility, 384×216
viewport. All images are staged captures, not a playthrough.

## Staging (read before judging the images)

- `tools/capture_notebook.gd`: seed 42, Woods Expedition, **enemies frozen**,
  NightClock processing **stopped** and phases/moon **driven by hand**
  (`_enter_phase(1)`, `moon_clock` set to 55% of its span, `set_moon(true)`),
  normal lighting and sight. `--all-escapes` (diagnostic, all five routes) for
  the plain images; `--blood-moon` (normal two-route rules plus the modifier)
  for the `blood_*` images. Woods trail cells (14–20, 24) are marked visited so
  the local map shows a walked trail. The battery is consumed and installed by
  script to show its marker disappearing.
- `tools/capture_world_review.gd` (existing fixture, all escapes forced, enemies
  frozen): `fixed_*` images. The `inspection` views **disable sight and brighten
  ambient light** on purpose to expose layering; they are not normal lighting.

Commands:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_notebook.gd -- --all-escapes
godot --path . --audio-driver Dummy --script res://tools/capture_notebook.gd -- --blood-moon
godot --path . --audio-driver Dummy --script res://tools/capture_world_review.gd
godot --headless --path . --audio-driver Dummy --script res://tools/audit_sound_feedback.gd
```

All exited 0 with every PNG written and no engine errors. Every retained image
was opened and inspected.

## What the images show

| Image | Shows |
| --- | --- |
| [dusk_title](dusk_title.png) | Opening DUSK title; dark (new) moon dial top right |
| [map_camp](map_camp.png), [battery installed](map_camp_battery_installed.png) | Camp map at one scale; the battery marker is gone once it is installed (G03) |
| [map_woods_local](map_woods_local.png), [overview](map_woods_overview.png) | Local woods view and the whole woods (Z); next step and legend beside the map, nothing over the belt (G01/G02/G06) |
| [plan_van](plan_van.png), [plan_radio](plan_radio.png) | Escape plan view with the route list; the map is reachable for every route (G05) |
| [guide_controls](guide_controls.png), [survival](guide_survival.png), [killer](guide_the_killer.png), [title_guide](title_guide.png) | Shared field guide, current rules and keys (G07) |
| [nightfall_title_radio](nightfall_title_radio.png), [radio_crawl](radio_crawl.png) | Phase title and the ranger radio transcript strip |
| [moon_waxing](moon_waxing.png), [moon_full](moon_full.png), [blood waxing](blood_moon_waxing.png), [blood full](blood_moon_full.png) | Moon dial: half-way to full, out (glow + run-down ring), Blood Moon in red |
| [log](log.png) | Notebook log of earlier announcements |
| [logging](fixed_label_logging.png), [boathouse](fixed_label_boathouse.png), [ranger](fixed_label_ranger.png) | Each region title drawn once (was twice, 4 px apart) |
| [fixed_faded_killer](fixed_faded_killer.png) | Faded killer's ground shadow now fades with the body |
| [fixed_workshop_piles](fixed_workshop_piles.png) | Phase supply drop labelled per pile ("FLARE ×3", "SUPPLIES ×11") instead of one word per unit; two neighbouring piles can still both label |

[sound_feedback.log](sound_feedback.log): air horn now accepts one `air_horn`
cue; one bear-trap activation accepts one `bear_trap`, one `chain_rattle` and the
bite's `grunt` (previously `metal_clang` ×2). Accepted-cue counts are routing
evidence only, not listening evidence.

## Not shown or not established

Teammate and downed markers, help pings and the "world keeps moving" header
need a co-op session; they were not captured. No 1/2/4-peer, 768×432/1536×864
window, human comprehension or listening test was run.
