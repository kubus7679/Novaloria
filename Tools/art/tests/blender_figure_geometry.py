"""Verify the production camera and body scale for every figure job."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))

import bpy  # noqa: E402
import render_jobs  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
from mathutils import Vector  # noqa: E402


def projected(point, canvas):
    scene = bpy.context.scene
    position = world_to_camera_view(scene, scene.camera, point)
    return position.x * canvas[0], (1.0 - position.y) * canvas[1]


def object_points(obj):
    return [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]


def projected_height(objects, canvas):
    ys = [projected(point, canvas)[1] for obj in objects for point in object_points(obj)]
    return max(ys) - min(ys)


def objects_named(names):
    return [obj for obj in bpy.context.scene.objects if obj.name.split(".")[0] in names]


render_jobs.common.render = lambda _: None
payload = json.loads(Path(sys.argv[-1]).read_text())
jobs = payload["jobs"]
muzzles = payload["muzzles"]
measurements = []
for job in jobs:
    render_jobs.run(job)
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    canvas = job["canvas"]
    assert (scene.render.resolution_x, scene.render.resolution_y) == tuple(job["raw"]), job["path"]
    sun = next(obj for obj in scene.objects if obj.type == "LIGHT" and obj.data.type == "SUN")
    travel = sun.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))

    for obj in scene.objects:
        if obj.type != "MESH" or obj.is_shadow_catcher or obj.hide_render:
            continue
        for point in object_points(obj):
            points = [(point, 5)]
            if point.z > 0:
                points.append((point + travel * (-point.z / travel.z), 1))
            for candidate, margin in points:
                x, y = projected(candidate, canvas)
                assert margin <= x <= canvas[0] - margin and margin <= y <= canvas[1] - margin, (
                    job["path"], obj.name, x, y
                )

    role = Path(job["path"]).parent.name
    barrels = objects_named({"musket barrel"})
    if role in muzzles and barrels:
        barrel = barrels[0]
        vertices = [barrel.matrix_world @ vertex.co for vertex in barrel.data.vertices]
        top = max(point.z for point in vertices)
        tip = [point for point in vertices if abs(point.z - top) < 0.01]
        center = sum(tip, Vector()) / len(tip)
        measured = projected(center, canvas)
        assert all(
            abs(actual - wanted) <= 0.5 for actual, wanted in zip(measured, muzzles[role], strict=True)
        ), (
            job["path"], measured, muzzles[role]
        )

    head = projected_height(objects_named({"head"}), canvas)
    torso = projected_height(objects_named({"coat torso"}), canvas)
    mounted = bool(job["params"].get("mounted"))
    body = None if mounted else projected_height(
        objects_named({"head", "neck", "coat torso", "coat skirt", "leg", "stocking", "boot"}), canvas
    )
    measurements.append((job["path"], head, torso, body))

reference = next(row for row in measurements if row[0].endswith("/civilian/freeColonist.png"))
for path, head, torso, body in measurements:
    assert abs(head - reference[1]) <= 0.5, (path, head, reference[1])
    assert abs(torso - reference[2]) <= 0.5, (path, torso, reference[2])
    if body is not None:
        assert abs(body - reference[3]) <= 0.1, (path, body, reference[3])
print(
    f"Validated {len(measurements)} figures: "
    f"head={reference[1]:.2f}px torso={reference[2]:.2f}px body={reference[3]:.2f}px"
)
