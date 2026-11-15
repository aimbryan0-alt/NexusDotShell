#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parent
AWK_FILE = ROOT / "legacy.awk"


def build_candidates(build_dir):
    c_binary = build_dir / "gpu-fdinfo-c"
    haskell_binary = build_dir / "gpu-fdinfo-haskell"
    subprocess.run(
        ["cc", "-O2", "-Wall", "-Wextra", "-Werror",
         str(ROOT / "gpu_fdinfo.c"), "-o", str(c_binary)],
        check=True,
    )
    subprocess.run(
        ["ghc", "-O2", "-Wall", "-Werror",
         "-outputdir", str(build_dir / "ghc"),
         "-o", str(haskell_binary), str(ROOT / "GpuFdinfo.hs")],
        check=True,
    )
    return c_binary, haskell_binary


def environment(proc_root):
    env = os.environ.copy()
    env["PROC_ROOT"] = str(proc_root)
    env["AWK_FILE"] = str(AWK_FILE)
    return env


def baseline_command():
    return [
        "bash", "-c",
        'find "$PROC_ROOT"/[0-9]*/fdinfo -maxdepth 1 -type f -print 2>/dev/null '
        '| awk -f "$AWK_FILE"',
    ]


def candidate_command(binary, proc_root):
    return [str(binary), "--proc-root", str(proc_root)]


def run_checked(command, env=None, capture=False):
    return subprocess.run(
        command,
        check=True,
        env=env,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        text=True,
    )


def create_fixture(root):
    entries = {
        "1000/fdinfo/3": """\
drm-driver: i915
drm-pdev: 0000:00:02.0
drm-client-id: 7
drm-engine-render: 1000 ns
drm-engine-copy: 250 ns
drm-total-system0: 2 MiB
drm-total-local0: 128 KiB
""",
        "1000/fdinfo/4": """\
drm-driver: i915
drm-pdev: 0000:00:02.0
drm-client-id: 7
drm-engine-render: 1500 ns
drm-engine-copy: 500 ns
drm-total-system0: 3 MiB
drm-total-local0: 64 KiB
""",
        "1001/fdinfo/8": """\
drm-driver: amdgpu
drm-pdev: 0000:03:00.0
drm-engine-gfx: 300 ns
drm-total-vram0: 1 GiB
""",
        "1002/fdinfo/5": """\
drm-driver: i915
drm-engine-render: 900 ns
""",
    }
    for relative_path, contents in entries.items():
        path = root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="ascii")


def normalized_records(output):
    return sorted(line for line in output.splitlines() if line.startswith("ENGINE|"))


def record_keys(records):
    return {tuple(line.split("|")[1:5]) for line in records}


def verify_fixture(c_binary, haskell_binary):
    expected = [
        "ENGINE|1000|0000:00:02.0|i915|7|2000|3072|128",
        "ENGINE|1001|0000:03:00.0|amdgpu|8|300|0|1048576",
    ]
    with tempfile.TemporaryDirectory(prefix="gpu-fdinfo-fixture-") as directory:
        fixture = Path(directory)
        create_fixture(fixture)
        env = environment(fixture)
        outputs = {
            "legacy": run_checked(baseline_command(), env, capture=True).stdout,
            "C": run_checked(candidate_command(c_binary, fixture), capture=True).stdout,
            "Haskell": run_checked(candidate_command(haskell_binary, fixture), capture=True).stdout,
        }
        for name, output in outputs.items():
            if normalized_records(output) != expected:
                raise RuntimeError(f"{name} fixture mismatch:\n{output}")


def benchmark_shell_persistent(iterations, env):
    command = [
        "bash", "-c",
        'i=0; while [ "$i" -lt "$ITERATIONS" ]; do '
        'find "$PROC_ROOT"/[0-9]*/fdinfo -maxdepth 1 -type f -print 2>/dev/null '
        '| awk -f "$AWK_FILE" >/dev/null; i=$((i + 1)); done',
    ]
    benchmark_env = env.copy()
    benchmark_env["ITERATIONS"] = str(iterations)
    run_checked(command, benchmark_env)


def measure(action, trials, iterations):
    samples = []
    for _ in range(trials):
        started = time.perf_counter()
        action()
        samples.append((time.perf_counter() - started) * 1000 / iterations)
    return statistics.median(samples)


def main():
    parser = argparse.ArgumentParser(
        description="Compare the legacy shell scan with C and Haskell DRM fdinfo scanners."
    )
    parser.add_argument("--trials", type=int, default=5)
    parser.add_argument("--iterations", type=int, default=5)
    arguments = parser.parse_args()
    if arguments.trials < 1 or arguments.iterations < 1:
        parser.error("--trials and --iterations must be positive")

    missing = [tool for tool in ("cc", "ghc", "bash", "find", "awk") if shutil.which(tool) is None]
    if missing:
        raise SystemExit("missing required benchmark tools: " + ", ".join(missing))

    with tempfile.TemporaryDirectory(prefix="gpu-fdinfo-build-") as directory:
        build_dir = Path(directory)
        c_binary, haskell_binary = build_candidates(build_dir)
        verify_fixture(c_binary, haskell_binary)
        print("Fixture parity: legacy AWK, C, and Haskell agree.")

        proc_root = Path("/proc")
        env = environment(proc_root)
        commands = {
            "shell+awk": baseline_command(),
            "C": candidate_command(c_binary, proc_root),
            "Haskell": candidate_command(haskell_binary, proc_root),
        }
        for command in commands.values():
            run_checked(command, env)

        live_outputs = {
            name: normalized_records(run_checked(command, env, capture=True).stdout)
            for name, command in commands.items()
        }
        reference_keys = record_keys(live_outputs["shell+awk"])
        print("Live scan records: " + ", ".join(
            f"{name}={len(records)}" for name, records in live_outputs.items()
        ))
        for name in ("C", "Haskell"):
            keys = record_keys(live_outputs[name])
            overlap = len(reference_keys & keys) / max(1, len(reference_keys | keys))
            print(f"Live key overlap vs shell+awk ({name}): {overlap:.1%}")

        rotations = list(commands.items())
        one_shot_results = {name: [] for name in commands}
        persistent_results = {name: [] for name in commands}
        for trial in range(arguments.trials):
            ordered = rotations[trial % len(rotations):] + rotations[:trial % len(rotations)]
            for name, command in ordered:
                def one_shot(command=command):
                    for _ in range(arguments.iterations):
                        run_checked(command, env)

                one_shot_results[name].append(
                    measure(one_shot, 1, arguments.iterations)
                )

            for name, command in ordered:
                if name == "shell+awk":
                    action = lambda: benchmark_shell_persistent(arguments.iterations, env)
                else:
                    action = lambda command=command: run_checked(
                        command + ["--benchmark", str(arguments.iterations)], env
                    )
                persistent_results[name].append(
                    measure(action, 1, arguments.iterations)
                )

        print(f"\nMedian wall time per scan ({arguments.trials} trials, "
              f"{arguments.iterations} scans/trial):")
        print(f"{'scanner':<14} {'one-shot ms':>14} {'persistent ms':>16}")
        for name in commands:
            one_shot = statistics.median(one_shot_results[name])
            persistent = statistics.median(persistent_results[name])
            print(f"{name:<14} {one_shot:14.2f} {persistent:16.2f}")


if __name__ == "__main__":
    main()
