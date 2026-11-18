"""Command line entry point: ``uv run novaloria-art build|review``."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

from .animation import write_animations
from .artspec import PROTOTYPE, Spec, full_specs
from .manifest import Manifest, hires_name, load_manifest
from .package import write_mod
from .post import finish_overlay, finish_tile, place_sprite
from .render import job_id, make_job, run_blender
from .review import contact_sheet, map_excerpt

REPO = Path(__file__).resolve().parents[4]
BUILD = REPO / "build" / "art"
STAGING = BUILD / "out"
MOD_DIR = REPO / "Mods" / "NovaloriaAtlas"
ARCHIVE = REPO / "Mods" / "NovaloriaAtlas.zip"
LICENSE = REPO / "Sources" / "Novaloria" / "Resources" / "FreeCol-COPYING"


def _select(
    manifest: Manifest,
    specs: dict[str, Spec],
    prototype: bool,
    only: list[str],
) -> dict[str, Spec]:
    selected = {}
    for path, spec in specs.items():
        if path not in manifest.images:
            print(f"warning: {path} is not referenced by FreeCol's default resources", file=sys.stderr)
            continue
        if prototype and path not in PROTOTYPE:
            continue
        if only and not any(fragment in path for fragment in only):
            continue
        selected[path] = spec
    return selected


def _finish(path: str, spec: Spec, info, raw_file: Path) -> None:
    canvas = spec.canvas or (info.width, info.height)
    with Image.open(raw_file) as raw:
        raw.load()
        for factor in (1, 2):
            if spec.mode == "tile":
                image = finish_tile(raw, canvas, factor)
            elif spec.mode == "overlay":
                image = finish_overlay(raw, canvas, factor)
            else:
                image = place_sprite(raw, canvas, info.bbox, spec.align, factor)
            target = STAGING / (path if factor == 1 else hires_name(path))
            target.parent.mkdir(parents=True, exist_ok=True)
            image.save(target, optimize=True)


def _coverage(manifest: Manifest, lines: list[str]) -> str:
    covered = {line.split("=", 1)[0] for line in lines}
    families: dict[str, list[int]] = {}
    for key, family in manifest.families.items():
        counts = families.setdefault(family, [0, 0])
        counts[1] += 1
        counts[0] += key in covered
    return ", ".join(f"{family} {done}/{total}" for family, (done, total) in sorted(families.items()))


def _review(manifest: Manifest, paths: list[str]) -> None:
    review = BUILD / "review"
    pairs = [(job_id(path), manifest.data_dir / path, STAGING / path) for path in paths]
    contact_sheet(pairs, review / "sheet.png")
    map_excerpt(STAGING, review / "map.png", scale=1, hires=False)
    map_excerpt(STAGING, review / "map@2x.png", scale=2, hires=True)
    map_excerpt(manifest.data_dir, review / "map-freecol.png", scale=1, hires=False)
    print(f"review images written to {review}")


def build(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.freecol)
    BUILD.mkdir(parents=True, exist_ok=True)
    summary = {
        path: {"size": [info.width, info.height], "bbox": info.bbox, "keys": manifest.keys_for(path)}
        for path, info in manifest.images.items()
    }
    (BUILD / "manifest.json").write_text(json.dumps(summary, indent=1), encoding="utf-8")
    specs = full_specs(manifest)
    selected = _select(manifest, specs, args.prototype, args.only)
    render_specs = dict(selected)
    render_infos = {path: manifest.images[path] for path in selected}
    for path, spec in selected.items():
        for variation in manifest.images[path].variations:
            if variation not in render_specs:
                render_specs[variation] = spec
                render_infos[variation] = manifest.images[path]
    raw_dir = BUILD / "raw"
    jobs = [make_job(path, spec, render_infos[path], raw_dir) for path, spec in render_specs.items()]
    if not args.skip_render and jobs:
        print(f"rendering {len(jobs)} assets with {args.blender} …", flush=True)
        log = run_blender(jobs, args.blender, BUILD, args.samples)
        print(f"blender log: {log}")
    for job in jobs:
        path = job["path"]
        _finish(path, render_specs[path], render_infos[path], Path(job["output"]))
    write_animations(manifest, STAGING)
    lines = write_mod(manifest, STAGING, MOD_DIR, LICENSE, ARCHIVE)
    print(f"mod written to {MOD_DIR} ({len(lines)} resource keys); archive {ARCHIVE}")
    print("coverage:", _coverage(manifest, lines))
    _review(manifest, sorted(path for path in specs if (STAGING / path).is_file()))


def review(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.freecol)
    specs = full_specs(manifest)
    _review(manifest, sorted(path for path in specs if (STAGING / path).is_file()))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="novaloria-art", description=__doc__)
    parser.add_argument(
        "--freecol",
        type=Path,
        default=REPO.parent / "freecol",
        help="FreeCol source tree (default: ../freecol)",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    build_parser = commands.add_parser("build", help="render, post-process and package the mod")
    build_parser.add_argument("--prototype", action="store_true", help="only the style prototype assets")
    build_parser.add_argument("--only", nargs="*", default=[], help="path fragments to restrict rendering")
    build_parser.add_argument("--blender", default=shutil.which("blender") or "blender")
    build_parser.add_argument("--samples", type=int, default=96)
    build_parser.add_argument("--skip-render", action="store_true", help="reuse existing raw renders")
    build_parser.set_defaults(handler=build)
    review_parser = commands.add_parser("review", help="rebuild comparison sheet and map excerpts")
    review_parser.set_defaults(handler=review)
    args = parser.parse_args(argv)
    args.handler(args)


if __name__ == "__main__":
    main()
