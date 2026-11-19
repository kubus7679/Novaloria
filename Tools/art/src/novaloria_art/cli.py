"""Command line entry point: ``uv run novaloria-art build|review``."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path

from PIL import Image

from .animation import write_animations
from .artspec import PROTOTYPE, Spec, full_specs
from .manifest import Manifest, hires_name, load_manifest
from .package import write_mod
from .post import finish_figure, finish_overlay, finish_tile, place_sprite
from .render import SUPERSAMPLE, job_id, make_job, run_blender
from .review import contact_sheet, map_excerpt, preview_sheet

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


def _finish(path: str, spec: Spec, info, raw_file: Path, staging: Path | None = None) -> None:
    canvas = spec.canvas or (info.width, info.height)
    staging = staging if staging is not None else STAGING
    with Image.open(raw_file) as raw:
        raw.load()
        if spec.mode == "figure":
            expected = tuple(dimension * SUPERSAMPLE for dimension in canvas)
            if raw.size != expected:
                raise ValueError(f"{path}: figure render has size {raw.size}, expected {expected}; "
                                 "rerender without --skip-render")
        for factor in (1, 2):
            if spec.mode == "tile":
                image = finish_tile(raw, canvas, factor)
            elif spec.mode == "overlay":
                image = finish_overlay(raw, canvas, factor)
            elif spec.mode == "figure":
                image = finish_figure(raw, canvas, factor)
            else:
                image = place_sprite(raw, canvas, info.bbox, spec.align, factor)
            target = staging / (path if factor == 1 else hires_name(path))
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


def _review(manifest: Manifest, paths: list[str], staging: Path | None = None) -> None:
    review = BUILD / "review"
    staging = staging if staging is not None else STAGING
    pairs = [(job_id(path), manifest.data_dir / path, staging / path) for path in paths]
    contact_sheet(pairs, review / "sheet.png")
    map_excerpt(staging, review / "map.png", scale=1, hires=False)
    map_excerpt(staging, review / "map@2x.png", scale=2, hires=True)
    map_excerpt(manifest.data_dir, review / "map-freecol.png", scale=1, hires=False)
    print(f"review images written to {review}")


def build(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.freecol)
    BUILD.mkdir(parents=True, exist_ok=True)
    partial = bool(args.only or args.prototype)
    if partial:
        with tempfile.TemporaryDirectory(prefix="partial-", dir=BUILD) as directory:
            _build(args, manifest, Path(directory), partial)
    else:
        _build(args, manifest, STAGING, partial)


def _build(args: argparse.Namespace, manifest: Manifest, staging: Path, partial: bool) -> None:
    if partial:
        for source in sorted((MOD_DIR / "resources").rglob("*")):
            if source.is_file():
                target = staging / source.relative_to(MOD_DIR)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
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
        _finish(path, render_specs[path], render_infos[path], Path(job["output"]), staging)
    if not partial or any(spec.kit in {"figure", "ship", "wagon"} for spec in selected.values()):
        write_animations(manifest, staging, set(render_specs) if partial else None)
    lines = write_mod(manifest, staging, MOD_DIR, LICENSE, ARCHIVE)
    print(f"mod written to {MOD_DIR} ({len(lines)} resource keys); archive {ARCHIVE}")
    print("coverage:", _coverage(manifest, lines))
    _review(manifest, sorted(path for path in specs if (staging / path).is_file()), staging)


def review(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.freecol)
    specs = full_specs(manifest)
    _review(manifest, sorted(path for path in specs if (MOD_DIR / path).is_file()), MOD_DIR)


def preview(args: argparse.Namespace) -> None:
    """Render exact resource paths separately, without changing the installed mod."""
    manifest = load_manifest(args.freecol)
    specs = full_specs(manifest)
    paths = list(dict.fromkeys(args.paths))
    missing = [path for path in paths if path not in manifest.images or path not in specs]
    if missing:
        raise ValueError(f"Unknown render paths: {', '.join(missing)}")
    missing_existing = [path for path in paths if not (MOD_DIR / path).is_file()]
    if missing_existing:
        raise ValueError(f"Current Atlas images not found: {', '.join(missing_existing)}")
    output = args.output.resolve()
    protected = (MOD_DIR.resolve(), STAGING.resolve())
    if any(output == path or output.is_relative_to(path) or path.is_relative_to(output)
           for path in protected):
        raise ValueError("Preview output must be separate from the Atlas and build staging directories")
    raw_dir = output / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    jobs = [make_job(path, specs[path], manifest.images[path], raw_dir) for path in paths]
    print(f"rendering {len(jobs)} preview assets with {args.blender} …", flush=True)
    log = run_blender(jobs, args.blender, output, args.samples)
    for job in jobs:
        path = job["path"]
        _finish(path, specs[path], manifest.images[path], Path(job["output"]), output / "out")
    preview_sheet([(job_id(path), MOD_DIR / path, output / "out" / path) for path in paths],
                  output / "comparison.png")
    print(f"preview: {output / 'comparison.png'}; blender log: {log}")


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
    preview_parser = commands.add_parser("preview", help="render selected exact paths without packaging")
    preview_parser.add_argument("--paths", nargs="+", required=True, help="exact resources/images/... paths")
    preview_parser.add_argument("--output", type=Path, default=BUILD / "preview")
    preview_parser.add_argument("--blender", default=shutil.which("blender") or "blender")
    preview_parser.add_argument("--samples", type=int, default=96)
    preview_parser.set_defaults(handler=preview)
    args = parser.parse_args(argv)
    args.handler(args)


if __name__ == "__main__":
    main()
