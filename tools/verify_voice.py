"""Voice checks: single-process codec/routing suite, then a headless two-process ENet
voice exchange. No microphone is opened. Results go to artifacts/voice/."""

import json
import re
import subprocess
import time

from godot_cli import ROOT, godot_binary


def run(name, args, timeout=90):
    folder = ROOT / "artifacts" / "voice"
    folder.mkdir(parents=True, exist_ok=True)
    log = folder / (name + ".log")
    with log.open("w") as stream:
        process = subprocess.Popen([godot_binary(), "--headless", "--path", str(ROOT), "--audio-driver", "Dummy", *args],
                                   cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    return process, log


def result(process, log, timeout):
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    text = re.sub(r"\x1b\[[0-9;]*m", "", log.read_text())
    summaries = [json.loads(line) for line in text.splitlines() if line.startswith("{") and '"test_result"' in line]
    errors = [line for line in text.splitlines() if re.search(r"(?:SCRIPT ERROR|ERROR|Parse Error):", line)]
    passed = process.returncode == 0 and len(summaries) == 1 and summaries[0]["failures"] == 0 and not errors
    return {"name": log.stem, "passed": passed, "exit_code": process.returncode, "errors": errors[:5],
            "result": summaries, "log": str(log.relative_to(ROOT))}


def main():
    records = []
    process, log = run("voice_chat", ["--script", "res://tests/integration/voice_chat.gd"])
    records.append(result(process, log, 90))
    port = 28311
    host, host_log = run("voice_host", ["--script", "res://tests/integration/voice_peer.gd", "--", "--side", "host", "--port", str(port)])
    time.sleep(1.5)
    guest, guest_log = run("voice_guest", ["--script", "res://tests/integration/voice_peer.gd", "--", "--side", "client", "--port", str(port)])
    records.append(result(guest, guest_log, 60))
    records.append(result(host, host_log, 30))
    for record in records:
        print(json.dumps(record))
    passed = all(record["passed"] for record in records)
    (ROOT / "artifacts" / "voice" / "summary.json").write_text(json.dumps({"passed": passed, "results": records}, indent=2) + "\n")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
