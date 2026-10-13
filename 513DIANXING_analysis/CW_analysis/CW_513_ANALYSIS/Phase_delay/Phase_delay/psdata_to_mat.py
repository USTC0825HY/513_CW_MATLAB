"""Convert PicoScope psdata using the official PicoScope 6/7 runtime.

Python standard library only. This is NOT a standalone psdata decoder.
Each invocation uses a fresh output directory; source files are unchanged.
"""
from __future__ import annotations
import argparse
import datetime
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid


def find_picoscope(explicit=None):
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if not path.is_file():
            raise RuntimeError(f"PicoScope executable not found: {path}")
        return path
    candidates = []
    for name in ("PicoScope.exe", "picoscope"):
        found = shutil.which(name)
        if found:
            candidates.append(Path(found))
    for variable in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
        base = os.environ.get(variable)
        if base:
            candidates.extend(Path(base).glob("Pico Technology/PicoScope*/PicoScope.exe"))
    candidates = sorted(set(candidates), key=lambda p: ("7" in str(p), str(p)), reverse=True)
    if not candidates:
        raise RuntimeError(
            "PicoScope is not installed/found. This tool requires the official runtime; "
            "it cannot decode proprietary psdata by itself. Install a PicoScope 7 version "
            "supporting BatchConvert (or PicoScope 6), then retry. "
            "Downloads: https://www.picotech.com/downloads ; "
            "custom installation: --picoscope PATH --version 7")
    return candidates[0].resolve()


def build_command(exe, version, source_dir, output_dir):
    if version == "7":
        return [str(exe), "BatchConvert", str(source_dir), str(output_dir), ".mat"]
    return [str(exe), "/c", str(source_dir), "/d", str(output_dir), "/f", "mat", "/b", "all"]


def convert(source, destination, exe, version, timeout=180):
    source = Path(source).resolve()
    if source.is_file() and source.suffix.lower() == ".psdata":
        files = [source]
    elif source.is_dir():
        files = sorted(p for p in source.iterdir() if p.suffix.lower() == ".psdata" and p.is_file())
    else:
        raise RuntimeError(f"Expected a psdata file or directory: {source}")
    if not files:
        raise RuntimeError("No psdata files found.")
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    run = Path(destination).resolve() / f"conversion_{stamp}_{uuid.uuid4().hex[:8]}"
    source_dir = run / "source"
    output_dir = run / "mat"
    source_dir.mkdir(parents=True)
    output_dir.mkdir()
    for file in files:
        shutil.copy2(file, source_dir / file.name)
    command = build_command(exe, version, source_dir, output_dir)
    manifest = {"sources": [str(f) for f in files], "command": command,
                "runtime_version": version, "status": "started"}
    manifest_path = run / "conversion.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    startupinfo = None
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = 0
    try:
        with (run / "conversion.log").open("w", encoding="utf-8") as log:
            process = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                     timeout=timeout, shell=False, startupinfo=startupinfo)
        mat_files = sorted(p for p in output_dir.rglob("*") if p.suffix.lower() == ".mat" and p.is_file())
        # Runtime success plus actual files is necessary; MATLAB validates contents on load.
        if process.returncode != 0 or not mat_files or any(p.stat().st_size == 0 for p in mat_files):
            raise RuntimeError(f"Conversion failed/no usable output (exit {process.returncode}). See {run / 'conversion.log'}")
        manifest.update(status="converted_not_matlab_validated", outputs=[str(p) for p in mat_files])
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as error:
        manifest.update(status="failed", error=str(error))
        raise RuntimeError(f"{error}\nConversion details: {run}") from error
    finally:
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return mat_files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", nargs="?", default=str(Path(__file__).parent), help="psdata file or directory")
    parser.add_argument("--output", default=str(Path(__file__).parent / "converted"))
    parser.add_argument("--picoscope", help="Full path to official PicoScope executable")
    parser.add_argument("--version", choices=("6", "7"), help="CLI generation; inferred from installation folder when possible")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--check", action="store_true", help="Only check runtime availability")
    args = parser.parse_args()
    try:
        exe = find_picoscope(args.picoscope)
        version = args.version
        if not version:
            if "picoscope 7" in str(exe).lower():
                version = "7"
            elif "picoscope6" in str(exe).lower() or "picoscope 6" in str(exe).lower():
                version = "6"
            else:
                raise RuntimeError("Cannot identify runtime generation. Set --version 6 or --version 7.")
        print(f"Runtime: {exe} (CLI {version})")
        if args.check:
            return 0
        if args.timeout <= 0:
            raise RuntimeError("Timeout must be positive.")
        for path in convert(args.source, args.output, exe, version, args.timeout):
            print(path)
        return 0
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
