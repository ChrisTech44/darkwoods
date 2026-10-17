"""Turn artifacts/clips/<name>/f_*.png frame folders into README GIFs.

Usage: python3 tools/build_clips.py [name ...]
Writes docs/clips/<name>.gif at native 384x216 (GitHub scales it up crisply),
15 fps, with a shared 64-colour palette per clip and frame-difference encoding. Requires ffmpeg.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    source = ROOT / "artifacts" / "clips"
    out = ROOT / "docs" / "clips"
    out.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or sorted(p.name for p in source.iterdir() if p.is_dir())
    for name in names:
        frames = source / name
        target = out / f"{name}.gif"
        graph = ("split[a][b];"
                 "[a]palettegen=max_colors=64:stats_mode=diff[p];"
                 "[b][p]paletteuse=dither=none:diff_mode=rectangle")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "15", "-i",
                        str(frames / "f_%04d.png"), "-vf", graph, "-loop", "0", str(target)], check=True)
        print(f"{target.relative_to(ROOT)} {target.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
