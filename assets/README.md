# Original game art

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
