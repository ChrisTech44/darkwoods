"""Run real ENet survivor recovery with a listen or dedicated authority."""
import argparse
import json
import os
import re
import socket
import subprocess
import time
from godot_cli import ROOT, godot_binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--dedicated', action='store_true')
    parser.add_argument('--players', type=int, choices=[1, 2, 4], default=2)
    parser.add_argument('--graphical', action='store_true')
    args = parser.parse_args()
    if args.players == 1 and not args.dedicated:
        parser.error("one-player recovery requires --dedicated")
    out = ROOT / 'artifacts/playtest_recovery'
    out.mkdir(parents=True, exist_ok=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    tag = ('dedicated' if args.dedicated else 'listen') + f'_{args.players}'
    running = []
    streams = []
    try:
        for side, index in [('host', 0)] + [('client', i) for i in range(args.players-int(not args.dedicated))]:
            path = out / f'{tag}_{side}_{index}.log'
            stream = path.open('w')
            streams.append(stream)
            env = os.environ.copy()
            env.update(LNAC_RECOVERY_SIDE=side, LNAC_RECOVERY_INDEX=str(index),
                       LNAC_RECOVERY_PORT=str(port), LNAC_RECOVERY_PEERS=str(args.players),
                       LNAC_RECOVERY_DEDICATED=str(int(args.dedicated)),
                       LNAC_RECOVERY_CAPTURE=str(int(args.graphical)))
            cmd = [godot_binary(), '--path', str(ROOT), '--audio-driver', 'Dummy',
                   '--script', 'res://tests/integration/reconnect_peer.gd']
            if not args.graphical or side == 'host' and args.dedicated:
                cmd.insert(1, '--headless')
            process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
            running.append((process, path, cmd))
            if side == 'host':
                time.sleep(0.5)
        deadline = time.monotonic()+240
        while any(p.poll() is None for p, _, _ in running) and time.monotonic() < deadline:
            if any(p.poll() not in (None, 0) for p, _, _ in running):
                break
            time.sleep(0.2)
    finally:
        for process, _, _ in running:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for stream in streams:
            stream.close()
    records = []
    for process, path, cmd in running:
        lines = path.read_text().splitlines()
        summaries = [json.loads(line) for line in lines if line.startswith('{') and json.loads(line).get('event') == 'test_result']
        errors = [line for line in lines if re.search(r'(?:SCRIPT ERROR|ERROR|WARNING):', line)]
        passed = process.returncode == 0 and len(summaries) == 1 and summaries[0].get('failures') == 0 and not errors
        records.append(dict(passed=passed, exit_code=process.returncode, results=summaries,
                            errors=errors, log=str(path.relative_to(ROOT)), command=cmd))
    report = dict(passed=all(r['passed'] for r in records), records=records)
    (out / f'{tag}_summary.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report), flush=True)
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
