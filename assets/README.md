# Original game art

## SpriteCook revamp (16 October 2026)

Part of the art was regenerated with SpriteCook (Nano Banana 2.1, pixel mode) on
the user's SpriteCook account, at the user's request; asset IDs and hashes are
in [spritecook-assets.json](../spritecook-assets.json) and the raw sheets in
`art_sources/spritecook/`. Licensing follows the user's SpriteCook terms.

| Game files | Source | Processing |
| --- | --- | --- |
| `pine_0/1/2`, `birch`, new `spruce`, `dead_tree`, `shrub`, `boulder`, new `stump` | One generated 3×3 props sheet | `tools/slice_spritecook_props.gd`: native pixels, trees bottom-anchored on 64×80 |
| `survivor_<role>` ×6 (+ `camper.png` = scout) | A 6×4 pose grid, generated as an edit of the old poses so each role keeps its colours | `tools/import_spritecook_survivors.gd`: area downscale of the ~28×55 figures to 31 px, snapped to each figure's palette; frames 1–2 add a 1 px step-bob with alternating legs |
| `stalker` | A 2×2 pose grid, generated as an edit of the old poses | `tools/import_spritecook_stalker.gd`: one shared 0.52 scale into new **40×48** frames (was 32×40), same step-bob |

The 16 creatures, terrain atlas, buildings and props drawn in code still use the
original procedural art below; the credit budget ran out after three images.
Re-running `build_pixel_art.py` would overwrite the SpriteCook trees, survivors
and stalker, so re-run the three import tools afterwards.

The camper and stalker sheets, terrain atlas, trees and ground props are original
pixel art authored in `tools/build_pixel_art.py` for this project. No downloaded
assets, franchise sprites, or third-party asset licenses are involved. Rebuild:

```sh
python3 tools/build_pixel_art.py
python3 tools/build_cryptids.py
python3 tools/build_content_art.py
```

Characters use three frames in four directional rows: down, up, right, left.
Camper frames are 24×32; stalker frames are 32×40. The camper has a hiking cap,
plaid overshirt, shorts, boots, backpack and rolled mat. The stalker has a weathered
hooded coat, stitched face covering and logging hook. Atlas tiles are 16×16.
Nearest-neighbor filtering and integer viewport scaling preserve the pixels.

`build_cryptids.py` uses the same standard-library pixel painter for six
original 64×64 creatures, three walking frames in four directional rows:
werewolf (layered grey fur, muzzle, claws and fangs), Sasquatch (hunched ape silhouette, crested skull, shaggy fur, long arms and
large feet), and lantern moth (patterned eyespot wings, segmented body,
antennae and amber eyes). PNG output is deterministic. These are original
interpretations of folklore, not downloaded or franchise character assets.

Building geometry, furniture, roof cutaways, dock, campsite props and field map
are drawn in GDScript. Lighting uses native Godot PointLight2D textures and
LightOccluder2D geometry, generated at runtime; the former darkness shader has
been replaced. `default_config.tres` contains the editable gameplay/light defaults.
Seeded woods ruins, warning gate, weather, loading card, animated menu and field
notes are also original GDScript drawing. Audio files are documented separately below.

The roster also includes original vampire (pale angular face, high collar and
maroon-lined cloak), witch (pointed hat, braid, staff and layered robes), and
briar revenant (antlers, exposed ribs, twig limbs and moss) directional sheets.
All six rebuild with the same standard-library script. Forest site scenery,
soft radial mist, trunk occluders and projectile effects are native GDScript art.

## Audio

The user supplied the MP3 recordings used for local playback. See
[audio cue mapping and provenance](audio/README.md) and [manifest](audio/manifest.json).
These are separate from the repository's reproducible original pixel artwork.


`build_content_art.py` adds six original 24×32 survivor sheets with role outfits,
backpacks, tools and patches, plus seven 64×64 cryptid sheets with three frames
and four directions. It uses the same deterministic standard-library painter.
The expanded biome floors, machinery, trellises, rail switches, quarry terraces
and chapel mosaics are native GDScript drawing in `forest_site.gd`. No external
visual assets or new dependencies are used.

The denser roaming update adds three original 64px directional sheets in
`build_content_art.py`: tall-eared Relay Jackal, patterned Ration Moth and iris-faced
Lens Eater. No external assets or dependencies were added.
