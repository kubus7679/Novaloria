"""Render damaged artillery with its broken and intact camera-facing wheel."""

import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "blender"))

import bpy  # noqa: E402
from kits import common, vehicles  # noqa: E402

job = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text())
common.configure(96)
common.reset()
view = common.View(job["elevation"])
common.world()
common.sun()
vehicles.build_wagon(job, view, random.Random(job["seed"]))
common.shadow_catcher()
common.frame_sprite(view, max(job["raw"]))
common.render(job["output"])

for obj in list(bpy.context.scene.objects):
    name = obj.name.split(".")[0]
    if name in {"wooden wheel rim", "wheel spoke"}:
        if sum(vertex.co.y for vertex in obj.data.vertices) / len(obj.data.vertices) < 0:
            bpy.data.objects.remove(obj, do_unlink=True)
    elif (name == "wheel hub" and obj.location.y < 0) or name == "broken wheel spoke":
        bpy.data.objects.remove(obj, do_unlink=True)

vehicles._wheel(0.05, -0.39, 0.31, 0.30, bpy.data.materials["wagon wood"],
                bpy.data.materials["iron fittings"])
common.render(str(Path(job["output"]).with_name("intact-reference.png")))
