import json
import shutil
import subprocess
import zipfile
from io import BytesIO
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from novaloria_art.animation import FIGURE_ATTACK_MUZZLES, SHIP_ANIMATION_OVERRIDES, _animation_frames
from novaloria_art.artspec import FIGURE_CANVAS, full_specs
from novaloria_art.manifest import hires_name, load_manifest
from novaloria_art.post import place_sprite
from novaloria_art.properties import read_properties
from novaloria_art.render import make_job

FREECOL = Path(__file__).resolve().parents[4] / "freecol"
BLENDER = shutil.which("blender")
MOD = Path(__file__).resolve().parents[3] / "Mods/NovaloriaAtlas"


@pytest.mark.skipif(not BLENDER, reason="Blender required")
def test_goods_figures_and_vehicles_have_distinctive_details():
    result = subprocess.run(
        [BLENDER, "-b", "--factory-startup", "--python-exit-code", "1",
         "--python", str(Path(__file__).with_name("blender_preview_geometry.py"))],
        capture_output=True, text=True, timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Validated figure, mounted-role, goods and vehicle geometry" in result.stdout


@pytest.mark.skipif(
    not BLENDER or not (FREECOL / "data/default/resources.properties").is_file(),
    reason="Blender and FreeCol source tree required",
)
def test_all_figure_bodies_use_one_scale_and_fit_the_frame(tmp_path):
    manifest = load_manifest(FREECOL)
    jobs = [
        make_job(path, spec, manifest.images[path], tmp_path)
        for path, spec in full_specs(manifest).items()
        if spec.kit == "figure" and path in manifest.images
    ]
    assert jobs
    assert all(tuple(job["canvas"]) == FIGURE_CANVAS for job in jobs)
    job_file = tmp_path / "figure-jobs.json"
    job_file.write_text(json.dumps({"jobs": jobs, "muzzles": FIGURE_ATTACK_MUZZLES}))
    result = subprocess.run(
        [BLENDER, "-b", "--factory-startup", "--python-exit-code", "1",
         "--python", str(Path(__file__).with_name("blender_figure_geometry.py")), "--", str(job_file)],
        capture_output=True, text=True, timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert f"Validated {len(jobs)} figures:" in result.stdout


@pytest.mark.skipif(
    not (FREECOL / "data/default/resources.properties").is_file(), reason="FreeCol tree missing"
)
def test_packaged_units_and_goods_have_expected_sizes_and_visible_content():
    manifest = load_manifest(FREECOL)
    specs = full_specs(manifest)
    selected = {path: spec for path, spec in specs.items()
                if spec.kit in {"figure", "ship", "wagon", "goods"}}
    assert selected
    for path, spec in selected.items():
        info = manifest.images[path]
        width, height = spec.canvas or (info.width, info.height)
        for factor in (1, 2):
            target = MOD / (hires_name(path) if factor == 2 else path)
            with Image.open(target) as image:
                assert image.size == (width * factor, height * factor), (path, factor)
                assert image.convert("RGBA").getchannel("A").getextrema()[1] > 128, (path, factor)
                if spec.kit == "figure":
                    alpha = np.asarray(image.convert("RGBA").getchannel("A"))
                    assert not (
                        alpha[0].any() or alpha[-1].any() or alpha[:, 0].any() or alpha[:, -1].any()
                    ), (path, factor)


@pytest.mark.skipif(
    not (FREECOL / "data/default/resources.properties").is_file(), reason="FreeCol tree missing"
)
def test_packaged_unit_animations_contain_valid_frames():
    manifest = load_manifest(FREECOL)
    paths = {value for key, value in manifest.entries.items()
             if manifest.families[key] == "animation" and not value.startswith("resource:")}
    assert paths
    for path in paths:
        with zipfile.ZipFile(MOD / path) as archive:
            assert archive.testzip() is None, path
            frames = [name for name in archive.namelist() if name.endswith(".png")]
            assert frames, path
            for name in frames:
                with Image.open(archive.open(name)) as frame:
                    frame.verify()


def test_packaged_ship_and_damaged_artillery_animations_match_their_sprites():
    resources = read_properties(MOD / "resources.properties")
    animations = {
        "animation.unit.model.unit.frigate.attack.sw": (
            "resources/images/units/ship/frigate.png",
            "resources/images/units/ship/frigate-attack.sza",
        ),
        "animation.unit.model.unit.privateer.attack.sw": (
            "resources/images/units/ship/privateer.png",
            "resources/images/units/ship/privateer-attack.sza",
        ),
        "animation.unit.model.unit.damagedArtillery.attack.e": (
            "resources/images/units/wagon/damagedArtillery.png",
            "resources/images/units/wagon/damagedArtillery-attack.sza",
        ),
        **SHIP_ANIMATION_OVERRIDES,
    }
    for key, (sprite, animation) in animations.items():
        assert resources[key] == animation
        expected = _animation_frames(MOD / sprite, attack=True)
        with zipfile.ZipFile(MOD / animation) as archive:
            for index, frame in enumerate(expected):
                with (
                    Image.open(archive.open(f"frame-{index:02}.png")) as actual,
                    Image.open(BytesIO(frame)) as wanted,
                ):
                    assert actual.size == wanted.size, (key, index)
                    delta = np.abs(
                        np.asarray(actual.convert("RGBA"), dtype=np.int16)
                        - np.asarray(wanted.convert("RGBA"), dtype=np.int16)
                    )
                    assert delta.mean() < 1, (key, index, delta.mean())


@pytest.mark.skipif(
    not BLENDER or not (FREECOL / "data/default/resources.properties").is_file(),
    reason="Blender and FreeCol source tree required",
)
def test_broken_wheel_is_visible_at_both_packaged_scales(tmp_path):
    manifest = load_manifest(FREECOL)
    path = "resources/images/units/wagon/damagedArtillery.png"
    info = manifest.images[path]
    spec = full_specs(manifest)[path]
    job = make_job(path, spec, info, tmp_path)
    job_file = tmp_path / "vehicle-job.json"
    job_file.write_text(json.dumps(job))
    result = subprocess.run(
        [BLENDER, "-b", "--factory-startup", "--python-exit-code", "1",
         "--python", str(Path(__file__).with_name("blender_vehicle_visibility.py")), "--", str(job_file)],
        capture_output=True, text=True, timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    def composite(image):
        background = Image.new("RGBA", image.size, (206, 197, 170, 255))
        return np.asarray(Image.alpha_composite(background, image), dtype=np.int16)[:, :, :3]

    with Image.open(job["output"]) as source, Image.open(tmp_path / "intact-reference.png") as intact:
        for factor in (1, 2):
            canvas = spec.canvas or (info.width, info.height)
            broken = place_sprite(source, canvas, info.bbox, spec.align, factor)
            complete = place_sprite(intact, canvas, info.bbox, spec.align, factor)
            difference = np.max(np.abs(composite(broken) - composite(complete)), axis=2)
            region = (
                slice(round(info.height * 0.65 * factor), info.height * factor),
                slice(round(info.width * 0.12 * factor), round(info.width * 0.60 * factor)),
            )
            changed = difference[region] > 30
            assert np.count_nonzero(changed) >= 10 * factor**2, factor

            packaged_path = MOD / (hires_name(path) if factor == 2 else path)
            with Image.open(packaged_path) as packaged:
                packaged_pixels = composite(packaged.convert("RGBA"))[region][changed]
                broken_distance = np.abs(packaged_pixels - composite(broken)[region][changed]).mean()
                intact_distance = np.abs(packaged_pixels - composite(complete)[region][changed]).mean()
                assert broken_distance + 10 < intact_distance, (factor, broken_distance, intact_distance)


@pytest.mark.parametrize("factor", [1, 2])
def test_packaged_treasure_chest_has_visible_gold_bands(factor):
    treasure = "resources/images/units/wagon/treasureTrain.png"
    with Image.open(MOD / (hires_name(treasure) if factor == 2 else treasure)) as image:
        pixels = np.asarray(image.convert("RGBA"))
    pixels = pixels[
        round(pixels.shape[0] * 0.40):round(pixels.shape[0] * 0.68),
        :round(pixels.shape[1] * 0.70),
    ].astype(np.float32)
    red, green, blue, alpha = (pixels[:, :, i] for i in range(4))
    gold = (alpha > 180) & (red > 125) & (green > 85) & (red > green * 1.08) & (green > blue * 1.35)
    assert np.count_nonzero(gold) >= 25 * factor**2


@pytest.mark.skipif(
    not BLENDER or not (FREECOL / "data/default/resources.properties").is_file(),
    reason="Blender and FreeCol source tree required",
)
def test_all_map_geometry_matches_freecol_connections_and_canvas(tmp_path):
    manifest = load_manifest(FREECOL)
    jobs = [
        make_job(path, spec, manifest.images[path], tmp_path)
        for path, spec in full_specs(manifest).items()
        if spec.kit in {"forest", "river", "beach", "relief"}
    ]
    job_file = tmp_path / "geometry.json"
    job_file.write_text(json.dumps(jobs))
    result = subprocess.run(
        [BLENDER, "-b", "--factory-startup", "--python-exit-code", "1",
         "--python", str(Path(__file__).with_name("blender_geometry.py")), "--", str(job_file)],
        capture_output=True, text=True, timeout=180,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert f"Validated geometry for {len(jobs)} map assets" in result.stdout


@pytest.mark.parametrize("factor", [1, 2])
def test_packaged_rivers_continue_across_every_connected_edge(factor):
    resources = read_properties(MOD / "resources.properties")
    prefix = "image.tile.model.improvement.river.s"
    rivers = {}
    for key, path in resources.items():
        if key.startswith(prefix):
            with Image.open(MOD / (hires_name(path) if factor == 2 else path)) as image:
                rivers[key.removeprefix(prefix)] = image.convert("RGBA")
    assert len(rivers) == 81
    for style, image in rivers.items():
        for direction, digit in enumerate(style):
            if digit == "0":
                continue
            opposite = (direction + 2) % 4
            neighbor_style = "".join(digit if i == opposite else "0" for i in range(4))
            dx, dy = ((64, -32), (64, 32), (-64, 32), (-64, -32))[direction]
            canvas = Image.new("RGBA", (384 * factor, 192 * factor))
            canvas.alpha_composite(image, (128 * factor, 64 * factor))
            canvas.alpha_composite(rivers[neighbor_style], ((128 + dx) * factor, (64 + dy) * factor))
            # Sample through the shared edge, not just at a branch's interior.
            for step in range(-4 * factor, 4 * factor + 1):
                x = round((192 + dx / 2) * factor + step * dx / 32)
                y = round((96 + dy / 2) * factor + step * dy / 32)
                assert canvas.getpixel((x, y))[3] > 150, (style, direction, step)


@pytest.mark.parametrize("factor", [1, 2])
def test_packaged_forests_have_clear_space_above_crowns(factor):
    files = sorted((MOD / "resources/images/forest").rglob("*.png"))
    files = [path for path in files if (".size2." in path.name) == (factor == 2)]
    assert len(files) == 160
    for path in files:
        with Image.open(path) as image:
            alpha = image.getchannel("A")
            top = alpha.crop((0, 0, image.width, 2 * factor))
            assert top.getextrema()[1] < 128, path.name


@pytest.mark.parametrize("factor", [1, 2])
def test_packaged_beaches_face_only_the_encoded_land_neighbors(factor):
    resources = read_properties(MOD / "resources.properties")
    for form, samples in (
        ("edge", [(92, 18), (92, 46), (36, 46), (36, 18)]),
        ("corner", [(64, 2), (122, 32), (64, 61), (5, 32)]),
    ):
        for index in range(1, 16):
            path = resources[f"image.tile.model.tile.beach.{form}{index}"]
            with Image.open(MOD / (hires_name(path) if factor == 2 else path)) as image:
                for direction, (x, y) in enumerate(samples):
                    alpha = image.getpixel((x * factor, y * factor))[3]
                    assert (alpha > 150) == bool(index & (1 << direction)), (form, index, direction)
