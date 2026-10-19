"""Start a dedicated camp; no display, speaker or microphone devices."""
import argparse
import subprocess
from pathlib import Path
from godot_cli import ROOT, godot_binary


def integer(low, high):
    def parse(value):
        number = int(value)
        if not low <= number <= high:
            raise argparse.ArgumentTypeError(f"must be {low}–{high}")
        return number
    return parse


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=integer(1, 65535), default=27840)
    parser.add_argument("--mode", choices=["camp", "woods"], default="woods")
    parser.add_argument("--seed", type=integer(0, 2147483646), default=0)
    parser.add_argument("--min-players", type=integer(1, 4), default=1)
    parser.add_argument("--start-delay", type=integer(1, 60), default=3)
    parser.add_argument("--result-delay", type=integer(3, 300), default=15)
    parser.add_argument("--pack", type=Path, help="Run a packaged server PCK instead of the source project")
    args = parser.parse_args()
    cmd = [godot_binary(), "--headless", "--disable-render-loop", "--audio-driver", "Dummy"]
    if args.pack:
        if not args.pack.is_file():
            parser.error(f"Pack does not exist: {args.pack}")
        cmd += ["--main-pack", str(args.pack.resolve())]
    else:
        cmd += ["--path", str(ROOT)]
    cmd += ["--", "--dedicated-server"]
    for name in ["port", "mode", "seed", "min_players", "start_delay", "result_delay"]:
        cmd += ["--" + name.replace("_", "-"), str(getattr(args, name))]
    try:
        return subprocess.call(cmd, cwd=ROOT)
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
