# Lays terrain and sprites in **the real game colors** on top of a backdrop candidate.
#
# Looking at the backdrop alone makes the judgment false — this game's backdrop is not "a picture to look at"
#  but **the ground the character, monsters and fire stand on.** Kill the contrast and you kill the silhouette.
#  Every color is taken verbatim from `DEFS.rgb` in `src/sim/cell_materials.gd`.
import sys, glob, os
from PIL import Image, ImageDraw

STONE = (0x5C, 0x57, 0x4F)
WOOD = (0x6B, 0x45, 0x24)
BEDROCK = (0x23, 0x22, 0x28)
EMPTY = (0x0E, 0x0E, 0x13)
TXT = (220, 215, 210)

W, H = 960, 540
CELL = 4                       # sim_tuning.CELL_PX

# Sprites are read from **the repo's `assets/`**. This once pointed at the scratchpad and the folder was gone
#  by the next session, nearly making the mockup impossible to build.
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "pixel", "out", "_bgmock")


def terrain_town(im):
    """The town floor. **All bedrock, flat** — `docs/design/town.md`, "all town terrain is bedrock".
    No pit and no dirt: the town does not get dug, so a stage slice here would judge the wrong picture."""
    d = ImageDraw.Draw(im)
    ground = 420
    d.rectangle([0, ground, W, H], fill=BEDROCK)
    d.rectangle([0, ground, W, ground + 8], fill=STONE)   # a floor edge line, so the ground reads
    return ground


def terrain(im):
    """A rough slice of terrain. Drawn on the 4px cell grid."""
    d = ImageDraw.Draw(im)
    ground = 400
    d.rectangle([0, ground, W, H], fill=WOOD)                 # dirt
    d.rectangle([0, ground + 60, W, H], fill=BEDROCK)         # bedrock
    d.rectangle([120, ground - 48, 300, ground], fill=STONE)  # stone pillar
    d.rectangle([640, ground - 96, 700, ground], fill=STONE)
    d.rectangle([700, ground - 32, 900, ground], fill=WOOD)
    # A pit — where the player dug
    d.rectangle([400, ground, 500, ground + 60], fill=EMPTY)
    return ground


def mock(bg_path, out, label, town=False):
    bg = Image.open(bg_path).convert("RGBA").resize((W, H), Image.NEAREST)
    im = Image.new("RGBA", (W, H), EMPTY)
    im.alpha_composite(bg)
    g = terrain_town(im) if town else terrain(im)
    # **No monsters in town** — standing a pig there judges a picture the town will never show.
    stand = [("character/wizard_body.png", 240)] if town else [
        ("character/wizard_body.png", 240), ("monster/pig_body.png", 470),
        ("monster/chicken_body.png", 740)]
    for p, x in stand:
        s = Image.open(os.path.join(ROOT, "assets", p)).convert("RGBA")
        # **`wizard_body.png` is a 6-frame strip (192x32), not one sprite.** Pasting it whole lines up six
        #  wizards and the mockup stops measuring "does one silhouette read". Square sheets take frame 0.
        if s.width > s.height * 2:
            s = s.crop((0, 0, s.height, s.height))
        im.alpha_composite(s, (x, g - s.height))
    d = ImageDraw.Draw(im)
    d.text((6, 4), label, fill=TXT)
    im.save(out)
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    rows = []
    # Folders come from argv[2:]. A `town` in the name switches the floor to all-bedrock and drops the monsters.
    folders = sys.argv[2:] or ["bgA_sky", "bgB_farm", "bgC_forest", "bgD_moon"]
    for folder in folders:
        fs = sorted(glob.glob(os.path.join(ROOT, "tools", "pixel", "out", folder, "*960px.png")))
        for i, f in enumerate(fs):
            rows.append(mock(f, f"{OUT}/bgmock_{folder}_{i}.png", f"{folder}  #{i}",
                             town=folder.startswith("town")))
    cols = 2
    n = len(rows)
    sheet = Image.new("RGBA", (cols * (W + 8) + 8, ((n + cols - 1) // cols) * (H + 8) + 8), (0, 0, 0, 255))
    for i, r in enumerate(rows):
        sheet.alpha_composite(r, (8 + (i % cols) * (W + 8), 8 + (i // cols) * (H + 8)))
    sheet.save(f"{OUT}/bg_compare.png")
    print("bg_compare.png", sheet.size, n, OUT)
