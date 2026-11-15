#!/usr/bin/env python3

import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path
import statistics


ROOT = Path(__file__).resolve().parent
LEGACY = ROOT / "legacy.sh"
NATIVE_WRAPPER = (
    'if [ -x "$1" ]; then '
    'if output=$("$1"); then printf "%s\\n" "$output"; exit 0; fi; '
    'fi; . "$2"'
)


def build_collector(build_dir):
    binary = build_dir / "system-stats-c"
    subprocess.run(
        ["cc", "-O2", "-Wall", "-Wextra", "-Werror",
         str(ROOT / "system_stats.c"), "-o", str(binary)],
        check=True,
    )
    return binary


def create_fixture(root):
    proc = root / "proc"
    sys = root / "sys"
    (proc).mkdir(parents=True)
    (proc / "stat").write_text(
        "cpu 100 20 30 400 50 6 7 8 9 10\n"
        "cpu0 60 10 15 200 25 3 4 4 5 5\n"
        "cpu1 40 10 15 200 25 3 3 4 4 5\n"
        "intr 100 0 0\n",
        encoding="ascii",
    )
    (proc / "meminfo").write_text(
        "MemTotal:       16000000 kB\n"
        "MemFree:          100000 kB\n"
        "MemAvailable:    8000000 kB\n"
        "Buffers:           20000 kB\n"
        "Cached:           900000 kB\n"
        "SwapCached:            0 kB\n"
        "SReclaimable:     100000 kB\n"
        "Shmem:             10000 kB\n"
        "SwapTotal:       2000000 kB\n"
        "SwapFree:        1500000 kB\n",
        encoding="ascii",
    )
    (proc / "cpuinfo").write_text(
        "processor : 0\n"
        "model name : Fixture CPU 9000\n"
        "processor : 1\n"
        "model name : Duplicate CPU line\n",
        encoding="ascii",
    )
    thermal = sys / "class" / "thermal"
    for zone, kind, value in (
        ("thermal_zone0", "acpitz", "42000"),
        ("thermal_zone1", "x86_pkg_temp", "58750"),
    ):
        directory = thermal / zone
        directory.mkdir(parents=True)
        (directory / "type").write_text(kind + "\n", encoding="ascii")
        (directory / "temp").write_text(value + "\n", encoding="ascii")
    return proc, sys


def run_legacy(proc, sys):
    env = os.environ.copy()
    env.update(PROC_ROOT=str(proc), SYS_ROOT=str(sys))
    return subprocess.run(
        ["bash", str(LEGACY)],
        check=True,
        capture_output=True,
        text=True,
        env=env,
    ).stdout


def run_c(binary, proc, sys):
    return subprocess.run(
        [str(binary), "--proc-root", str(proc), "--sys-root", str(sys)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def run_native_wrapper(binary):
    return subprocess.run(
        ["bash", "-c", NATIVE_WRAPPER, "myquickshell-stats", str(binary), str(LEGACY)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def record_keys(output):
    keys = set()
    for line in output.splitlines():
        fields = line.split()
        if not fields:
            continue
        keys.add(tuple(fields[:2]) if fields[0] in ("CPU", "MEM") else (fields[0],))
    return keys


def verify_fixture(binary):
    with tempfile.TemporaryDirectory(prefix="system-stats-fixture-") as directory:
        proc, sys = create_fixture(Path(directory))
        legacy = run_legacy(proc, sys)
        native = run_c(binary, proc, sys)
        if legacy != native:
            raise RuntimeError(
                "fixture output mismatch:\n"
                f"legacy:\n{legacy}\nC:\n{native}"
            )
        expected = (
            "CPU cpu 100 20 30 400 50 6 7 8 9 10\n"
            "CPU cpu0 60 10 15 200 25 3 4 4 5 5\n"
            "CPU cpu1 40 10 15 200 25 3 3 4 4 5\n"
            "MEM MemTotal: 16000000\n"
            "MEM MemFree: 100000\n"
            "MEM MemAvailable: 8000000\n"
            "MEM Buffers: 20000\n"
            "MEM Cached: 900000\n"
            "MEM SReclaimable: 100000\n"
            "MEM Shmem: 10000\n"
            "MEM SwapTotal: 2000000\n"
            "MEM SwapFree: 1500000\n"
            "MODEL Fixture CPU 9000\n"
            "CORES 2\n"
            "TEMP 58\n"
        )
        if native != expected:
            raise RuntimeError(f"fixture output differs from expected:\n{native}")


def measure(command, environment, trials, iterations):
    samples = []
    for _ in range(trials):
        started = time.perf_counter()
        for _ in range(iterations):
            subprocess.run(
                command,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=environment,
            )
        samples.append((time.perf_counter() - started) * 1000 / iterations)
    return statistics.median(samples)


def main():
    missing = [tool for tool in ("cc", "bash", "awk") if shutil.which(tool) is None]
    if missing:
        raise SystemExit("missing required benchmark tools: " + ", ".join(missing))

    with tempfile.TemporaryDirectory(prefix="system-stats-build-") as directory:
        binary = build_collector(Path(directory))
        verify_fixture(binary)
        print("Fixture parity: shell/awk and C agree exactly.")

        proc = Path("/proc")
        sys = Path("/sys")
        env = os.environ.copy()
        legacy_env = dict(env, PROC_ROOT=str(proc), SYS_ROOT=str(sys))
        legacy_command = ["bash", str(LEGACY)]
        native_command = [
            "bash", "-c", NATIVE_WRAPPER,
            "myquickshell-stats", str(binary), str(LEGACY)
        ]
        legacy_output = run_legacy(proc, sys)
        native_output = run_native_wrapper(binary)
        legacy_keys = record_keys(legacy_output)
        native_keys = record_keys(native_output)
        overlap = len(legacy_keys & native_keys) / max(1, len(legacy_keys | native_keys))
        print(f"Live output records: shell/awk={len(legacy_output.splitlines())}, C={len(native_output.splitlines())}")
        print(f"Live record-key overlap: {overlap:.1%}")

        trials = 5
        iterations = 5
        legacy_ms = measure(legacy_command, legacy_env, trials, iterations)
        native_ms = measure(native_command, env, trials, iterations)
        print(f"Median one-shot time per scan ({trials} trials, {iterations} scans/trial):")
        print(f"  shell/awk: {legacy_ms:.2f} ms")
        print(f"  C:         {native_ms:.2f} ms")
        print(f"  speedup:   {legacy_ms / max(native_ms, 0.001):.2f}x")


if __name__ == "__main__":
    main()
