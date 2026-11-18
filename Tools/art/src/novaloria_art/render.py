"""Builds render jobs and runs them in a headless Blender process."""

from __future__ import annotations

import json
import subprocess
import zlib
from pathlib import Path

from .artspec import Spec
from .manifest import ImageInfo

BLENDER_DIR = Path(__file__).resolve().parents[2] / "blender"
SUPERSAMPLE = 4


def job_id(path: str) -> str:
    return path.removeprefix("resources/images/").removesuffix(".png").replace("/", "-")


def make_job(path: str, spec: Spec, info: ImageInfo, raw_dir: Path) -> dict:
    canvas = spec.canvas or (info.width, info.height)
    if spec.mode == "sprite":
        longest = max(canvas) * SUPERSAMPLE
        raw = [min(max(longest, 384), 1024)] * 2
    else:
        raw = [canvas[0] * SUPERSAMPLE, canvas[1] * SUPERSAMPLE]
    return {
        "id": job_id(path),
        "path": path,
        "kit": spec.kit,
        "params": spec.params,
        "mode": spec.mode,
        "canvas": list(canvas),
        "raw": raw,
        "elevation": spec.elevation,
        "seed": zlib.crc32(path.encode()) & 0x7FFFFFFF,
        "output": str(raw_dir / f"{job_id(path)}.png"),
    }


def run_blender(jobs: list[dict], blender: str, work_dir: Path, samples: int) -> Path:
    work_dir.mkdir(parents=True, exist_ok=True)
    jobs_file = work_dir / "jobs.json"
    jobs_file.write_text(json.dumps(jobs, indent=2), encoding="utf-8")
    log_file = work_dir / "blender.log"
    command = [
        blender, "-b", "--factory-startup", "--python", str(BLENDER_DIR / "render_jobs.py"),
        "--", "--jobs", str(jobs_file), "--samples", str(samples),
    ]
    with log_file.open("w", encoding="utf-8") as log:
        result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=False)
    missing = [job["id"] for job in jobs if not Path(job["output"]).is_file()]
    if result.returncode != 0 or missing:
        tail = "\n".join(log_file.read_text(encoding="utf-8", errors="replace").splitlines()[-40:])
        raise RuntimeError(f"Blender failed (exit {result.returncode}, missing {missing}):\n{tail}")
    return log_file
