"""Blender entry point: ``blender -b --python render_jobs.py -- --jobs jobs.json``."""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from kits import architecture, common, figures, items, scenery, terrain, vegetation, vehicles  # noqa: E402

BUILDERS = {
    "terrain": terrain.build_tile,
    "forest": vegetation.build_forest,
    "relief": vegetation.build_relief,
    "figure": figures.build_figure,
    "ship": vehicles.build_ship,
    "wagon": vehicles.build_wagon,
    "building": architecture.build_building,
    "settlement": architecture.build_settlement,
    "goods": items.build_goods,
    "bonus": items.build_bonus,
    "lcr": items.build_lost_city,
    "beach": scenery.build_beach,
    "delta": scenery.build_delta,
    "river": scenery.build_river,
    "riverTexture": scenery.build_river_texture,
    "plow": scenery.build_plow,
    "clouds": scenery.build_clouds,
    "nativeLand": scenery.build_native_land,
    "buildingBackground": scenery.build_building_background,
}


def run(job: dict) -> None:
    common.reset()
    view = common.View(job["elevation"])
    common.world()
    common.sun()
    rng = random.Random(job["seed"])
    BUILDERS[job["kit"]](job, view, rng)
    if job["mode"] == "sprite":
        common.shadow_catcher()
        common.frame_sprite(view, max(job["raw"]))
    else:
        common.frame_tile(view, job["canvas"], job["raw"])
    common.render(job["output"])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobs", required=True)
    parser.add_argument("--samples", type=int, default=96)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    jobs = json.loads(Path(args.jobs).read_text(encoding="utf-8"))
    common.configure(args.samples)
    failures = 0
    for job in jobs:
        started = time.time()
        try:
            run(job)
            print(f"[novaloria] rendered {job['id']} in {time.time() - started:.1f}s", flush=True)
        except Exception:
            failures += 1
            print(f"[novaloria] FAILED {job['id']}", flush=True)
            traceback.print_exc()
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
