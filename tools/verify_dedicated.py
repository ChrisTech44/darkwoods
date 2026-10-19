"""Exercise a production dedicated authority with real ENet clients."""
import argparse
import json
import os
import re
import subprocess
import socket
import time
from pathlib import Path
from godot_cli import ROOT, godot_binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--players', type=int, choices=[1, 2, 4], default=2)
    parser.add_argument('--mode', choices=['camp', 'woods'], default='woods')
    parser.add_argument('--client-path', type=Path, default=ROOT,
                        help='Use a main checkout to verify client compatibility')
    parser.add_argument('--graphical-clients', action='store_true')
    parser.add_argument('--pack', type=Path, help='Exercise the exported server PCK')
    parser.add_argument('--simultaneous-disconnect', action='store_true',
                        help='Stress back-to-back disconnects instead of staggered departures')
    args = parser.parse_args()
    out = ROOT / 'artifacts/dedicated'
    out.mkdir(parents=True, exist_ok=True)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reserved:
        reserved.bind(('127.0.0.1', 0))
        port = reserved.getsockname()[1]
    tag = f'{args.mode}_{args.players}' + ('_pack' if args.pack else '')
    if args.simultaneous_disconnect:
        tag += '_simultaneous'
    report_tag = tag
    tag += '_' + str(time.time_ns())
    driver = ROOT / 'tests/integration/dedicated_peer.gd'
    running = []
    streams = []
    def spawn(side, index=0):
        path = out / f'{tag}_{side}_{index}.log'
        stream = path.open('w')
        streams.append(stream)
        env = os.environ.copy()
        env.update(LNAC_TEST_SIDE=side, LNAC_TEST_PORT=str(port),
                   LNAC_TEST_PLAYERS=str(args.players), LNAC_TEST_INDEX=str(index),
                   LNAC_TEST_CAPTURE_DIR=str(out),
                   LNAC_TEST_SIMULTANEOUS=str(int(args.simultaneous_disconnect)))
        cmd = [godot_binary(), '--headless', '--disable-render-loop', '--audio-driver', 'Dummy']
        if side == 'client' and args.graphical_clients:
            cmd = [godot_binary(), '--audio-driver', 'Dummy', '--resolution', '768x432']
        if side == 'server' and args.pack:
            cmd += ['--main-pack', str(args.pack.resolve())]
        else:
            cmd += ['--path', str(ROOT if side == 'server' else args.client_path.resolve())]
        cmd += ['--script', str(driver)]
        if side == 'server':
            cmd += ['--', '--dedicated-server', '--port', str(port), '--mode', args.mode,
                    '--seed', '13' if args.mode == 'woods' else '42', '--min-players', str(args.players),
                    '--start-delay', '1', '--result-delay', '8']
        process = subprocess.Popen(cmd, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
        running.append((side, index, process, path, cmd))
    try:
        spawn('server')
        deadline = time.monotonic() + 30
        while 'server_listening' not in running[0][3].read_text() and running[0][2].poll() is None and time.monotonic() < deadline:
            time.sleep(.1)
        if 'server_listening' in running[0][3].read_text():
            for index in range(args.players):
                spawn('client', index)
        deadline = time.monotonic() + 300
        while any(p.poll() is None for _, _, p, _, _ in running) and time.monotonic() < deadline:
            if any(p.poll() not in (None, 0) for _, _, p, _, _ in running):
                break
            time.sleep(.2)
    finally:
        for _, _, process, _, _ in running:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for stream in streams:
            stream.close()
    results = []
    for side, index, process, path, command in running:
        log = path.read_text()
        summaries = [json.loads(line) for line in log.splitlines()
                     if line.startswith('{') and '"test_result"' in line]
        errors = [line for line in log.splitlines() if re.search(r'(?:ERROR:|WARNING:)', line)]
        passed = process.returncode == 0 and len(summaries) == 1 and summaries[0]['failures'] == 0 and not errors
        record = dict(side=side, index=index, exit=process.returncode, passed=passed,
                      errors=errors, results=summaries, command=command, log=str(path.relative_to(ROOT)))
        results.append(record)
        print(json.dumps(record), flush=True)
    report = dict(passed=len(results) == args.players + 1 and all(r['passed'] for r in results), results=results,
                  client_path=str(args.client_path.resolve()), portable_pack=bool(args.pack), simultaneous_disconnect=args.simultaneous_disconnect, graphical_clients=args.graphical_clients, headless_replica_scenery_hidden=not args.graphical_clients)
    (out / f'{report_tag}_summary.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
