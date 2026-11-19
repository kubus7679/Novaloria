import numpy as np
import pytest
from PIL import Image

from novaloria_art.artspec import FIGURE_CANVAS, _figure
from novaloria_art.cli import _finish
from novaloria_art.manifest import ImageInfo, hires_name
from novaloria_art.post import diamond_mask, finish_figure, finish_tile, place_sprite, resize
from novaloria_art.render import SUPERSAMPLE


def test_diamond_mask_is_binary_and_tiles_without_gaps():
    mask = np.asarray(diamond_mask(128, 64)) // 255
    assert set(np.unique(mask)) == {0, 1}
    coverage = np.zeros((64 * 3, 128 * 3), dtype=int)
    for row in range(5):
        for column in range(4):
            left = column * 128 + (64 if row % 2 else 0) - 64
            top = row * 32 - 32
            for y in range(64):
                for x in range(128):
                    cy, cx = top + y, left + x
                    if 0 <= cy < coverage.shape[0] and 0 <= cx < coverage.shape[1]:
                        coverage[cy, cx] += mask[y, x]
    interior = coverage[32:128, 64:320]
    assert interior.min() == 1 and interior.max() == 1


def test_premultiplied_resize_keeps_edge_colors():
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    image.paste((240, 220, 40, 255), (16, 16, 48, 48))
    small = np.asarray(resize(image, (16, 16)))
    edge = small[3, 8]
    assert edge[3] > 0
    assert edge[0] > 180 and edge[1] > 160


def test_tile_has_exact_size_and_binary_alpha():
    raw = Image.new("RGBA", (512, 256), (90, 140, 60, 255))
    tile = finish_tile(raw, (128, 64), 2)
    alpha = np.asarray(tile.getchannel("A"))
    assert tile.size == (256, 128)
    assert set(np.unique(alpha)) == {0, 255}


def test_sprite_keeps_original_baseline_and_height():
    raw = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    raw.paste((120, 80, 40, 255), (150, 40, 250, 360))
    sprite = place_sprite(raw, (33, 64), (5, 4, 28, 64), "baseline", 1)
    alpha = np.asarray(sprite.getchannel("A"))
    rows = np.flatnonzero((alpha > 128).any(axis=1))
    assert sprite.size == (33, 64)
    assert rows[0] == 4 and rows[-1] == 63
    doubled = place_sprite(raw, (33, 64), (5, 4, 28, 64), "baseline", 2)
    assert doubled.size == (66, 128)


def test_icon_is_centered_inside_its_box():
    raw = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
    raw.paste((200, 30, 30, 255), (100, 50, 200, 250))
    icon = place_sprite(raw, (32, 32), (2, 2, 30, 30), "icon", 1)
    alpha = np.asarray(icon.getchannel("A"))
    cols = np.flatnonzero((alpha > 128).any(axis=0))
    rows = np.flatnonzero((alpha > 128).any(axis=1))
    assert rows[0] == 2 and rows[-1] == 29
    assert abs((cols[0] + cols[-1]) / 2 - 15.5) <= 1


def test_figure_finishing_preserves_person_size_regardless_of_equipment(tmp_path):
    spec = _figure("colonist")
    bounds = {}
    for variant, equipment in enumerate(((70, 40, 90, 340), (4, 4, 50, 370))):
        path = f"resources/images/units/civilian/figure{variant}.png"
        raw = Image.new("RGBA", tuple(side * SUPERSAMPLE for side in FIGURE_CANVAS))
        raw.paste((220, 30, 30, 255), (152, 80, 200, 320))
        raw.paste((30, 60, 220, 255), equipment)
        raw_path = tmp_path / f"raw{variant}.png"
        raw.save(raw_path)
        info = ImageInfo(path, 21 + variant * 20, 60, (0, 0, 21 + variant * 20, 60))
        _finish(path, spec, info, raw_path, tmp_path / "out")

        for factor in (1, 2):
            output = tmp_path / "out" / (path if factor == 1 else hires_name(path))
            with Image.open(output) as image:
                pixels = np.asarray(image.convert("RGBA"), dtype=np.int16)
            person = (
                (pixels[:, :, 0] > 150)
                & (pixels[:, :, 0] > pixels[:, :, 1] * 2)
                & (pixels[:, :, 0] > pixels[:, :, 2] * 2)
                & (pixels[:, :, 3] > 128)
            )
            rows, columns = np.nonzero(person)
            bounds[variant, factor] = (columns.min(), rows.min(), columns.max() + 1, rows.max() + 1)

    for factor in (1, 2):
        assert bounds[0, factor] == bounds[1, factor]
        assert bounds[0, factor][3] - bounds[0, factor][1] == 60 * factor


def test_figure_finishing_rejects_stale_autoframed_raw(tmp_path):
    path = "resources/images/units/civilian/freeColonist.png"
    raw_path = tmp_path / "old.png"
    Image.new("RGBA", (384, 384), (150, 100, 50, 255)).save(raw_path)
    info = ImageInfo(path, 33, 64, (4, 1, 32, 62))

    with pytest.raises(ValueError, match="rerender without --skip-render"):
        _finish(path, _figure("colonist"), info, raw_path, tmp_path / "out")


@pytest.mark.parametrize("factor", [1, 2])
def test_figure_shadows_fade_smoothly_at_the_canvas_edge(factor):
    raw = Image.new("RGBA", tuple(side * SUPERSAMPLE for side in FIGURE_CANVAS), (20, 20, 20, 120))
    result = finish_figure(raw, FIGURE_CANVAS, factor)
    alpha = np.asarray(result.getchannel("A"))
    assert not alpha[0].any() and not alpha[-1].any()
    assert not alpha[:, 0].any() and not alpha[:, -1].any()
    middle = alpha.shape[1] // 2
    assert 0 < alpha[2 * factor, middle] < alpha[5 * factor, middle] == 120
