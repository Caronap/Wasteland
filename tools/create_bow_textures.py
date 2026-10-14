from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = ROOT / "mods/wasteland_core/textures"


TRANSPARENT = (0, 0, 0, 0)
BOW_DARK = (76, 41, 18, 255)
BOW_MID = (136, 76, 34, 255)
BOW_LIGHT = (190, 124, 58, 255)
STRING = (228, 218, 176, 255)
ARROW_SHAFT = (96, 62, 31, 255)
ARROW_HEAD = (190, 190, 176, 255)
FLETCH = (210, 230, 238, 255)


def put(img, x, y, color):
    if 0 <= x < 16 and 0 <= y < 16:
        img.putpixel((x, y), color)


def line(img, points, color):
    for x, y in points:
        put(img, x, y, color)


def draw_bow(stage):
    img = Image.new("RGBA", (16, 16), TRANSPARENT)

    # Curved MC-style bow silhouette, thicker than the previous rod-like sprite.
    bow_pixels = [
        (10, 1), (9, 1), (9, 2), (8, 2), (8, 3), (7, 3),
        (7, 4), (6, 5), (6, 6), (6, 7), (6, 8), (6, 9),
        (6, 10), (7, 11), (7, 12), (8, 12), (8, 13), (9, 13),
        (9, 14), (10, 14),
    ]
    line(img, bow_pixels, BOW_DARK)
    line(img, [(x - 1, y) for x, y in bow_pixels if 2 <= y <= 13], BOW_MID)
    line(img, [(x - 2, y) for x, y in bow_pixels if 4 <= y <= 11], BOW_LIGHT)

    if stage == 0:
        string_pixels = [(10, y) for y in range(2, 14)]
        arrow_y = None
    elif stage == 1:
        string_pixels = [(10, 2), (10, 3), (9, 4), (9, 5), (8, 6), (8, 7), (8, 8), (8, 9), (9, 10), (9, 11), (10, 12), (10, 13)]
        arrow_y = 8
    elif stage == 2:
        string_pixels = [(10, 2), (9, 3), (9, 4), (8, 5), (7, 6), (7, 7), (7, 8), (7, 9), (8, 10), (9, 11), (9, 12), (10, 13)]
        arrow_y = 8
    else:
        string_pixels = [(10, 2), (9, 3), (8, 4), (7, 5), (6, 6), (5, 7), (5, 8), (6, 9), (7, 10), (8, 11), (9, 12), (10, 13)]
        arrow_y = 8

    line(img, string_pixels, STRING)

    if arrow_y is not None:
        pull = {1: 1, 2: 2, 3: 3}[stage]
        for x in range(2 + pull, 12):
            put(img, x, arrow_y, ARROW_SHAFT)
        put(img, 12, arrow_y, ARROW_HEAD)
        put(img, 13, arrow_y, ARROW_HEAD)
        put(img, 3 + pull, arrow_y - 1, FLETCH)
        put(img, 3 + pull, arrow_y + 1, FLETCH)

    return img


def main():
    draw_bow(0).save(TEXTURE_DIR / "wasteland_scrap_bow.png")
    for stage in range(1, 4):
        draw_bow(stage).save(TEXTURE_DIR / f"wasteland_scrap_bow_pulling_{stage}.png")


if __name__ == "__main__":
    main()
