"""Executed inside Blender by test_geometry.py; no renders or external Python packages needed."""

import json
import random
import sys
from pathlib import Path

from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))

import bpy  # noqa: E402
from kits import common, scenery, vegetation  # noqa: E402


def points(obj):
    return [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]


jobs = json.loads(Path(sys.argv[-1]).read_text())
for job in jobs:
    common.reset()
    view = common.View(job["elevation"])
    rng = random.Random(job["seed"])
    kit = job["kit"]
    if kit == "forest":
        vegetation.build_forest(job, view, rng)
        common.fit_tile_contents(view, job["canvas"])
        bpy.context.view_layer.update()
        width, shift = common.tile_metrics(job["canvas"])
        pixel = width / job["canvas"][0]
        for obj in bpy.context.scene.objects:
            if obj.type != "MESH" or obj.is_shadow_catcher:
                continue
            for corner in obj.bound_box:
                x, y = view.screen(obj.matrix_world @ Vector(corner))
                assert abs(x) <= width / 2 - 2.99 * pixel, job["id"]
                assert abs(y - shift) <= job["canvas"][1] / 2 * pixel - 2.99 * pixel, job["id"]
    elif kit == "river":
        scenery.build_river(job, view, rng)
        channels = [obj for obj in bpy.context.scene.objects if obj.name.startswith("river channel")]
        style = job["params"]["style"]
        assert len(channels) == sum(digit != "0" for digit in style)
        for direction, digit in enumerate(style):
            if digit == "0":
                continue
            dx, dy = ((0, 1), (1, 0), (0, -1), (-1, 0))[direction]
            ends = [point for obj in channels for point in points(obj)
                    if abs(point.x * dx + point.y * dy - 1) < 1e-6]
            assert len(ends) == 2, (style, direction)
            half_width = 0.065 if digit == "1" else 0.105
            assert abs((ends[0] - ends[1]).length - 2 * half_width) < 1e-6
            assert ((ends[0] + ends[1]) / 2 - Vector((dx, dy, 0))).length < 1e-6
    elif kit == "beach" and job["params"]["type"] != "center0":
        scenery.build_beach(job, view, rng)
        name = job["params"]["type"]
        form = "edge" if name.startswith("edge") else "corner"
        index = int(name.removeprefix(form).split("_")[0])
        shores = [obj for obj in bpy.context.scene.objects if obj.name.startswith("shore sand")]
        assert len(shores) == index.bit_count(), name
        expected = [direction for direction in range(4) if index & (1 << direction)]
        for obj, direction in zip(sorted(shores, key=lambda obj: obj.name), expected, strict=True):
            # Project into screen coordinates: north is positive screen Y here.
            x, y = view.screen(sum(points(obj), Vector()) / len(points(obj)))
            if form == "edge":
                assert (x > 0) == (direction in (0, 1)), name
                assert (y > 0) == (direction in (0, 3)), name
            else:
                assert (y > abs(x) * 0.4 if direction == 0 else
                        x > abs(y) if direction == 1 else
                        -y > abs(x) * 0.4 if direction == 2 else -x > abs(y)), name
    elif kit == "relief":
        mountain = job["params"]["type"] == "mountains"
        bm = vegetation._heightfield(mountain, rng)
        height = max(vertex.co.z for vertex in bm.verts)
        assert height > 0.5 if mountain else 0.15 < height < 0.31, (job["id"], height)
        bm.free()

print(f"Validated geometry for {len(jobs)} map assets", flush=True)
