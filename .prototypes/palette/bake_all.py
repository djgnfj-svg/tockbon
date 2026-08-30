# **Bakes every palette in Blender for real, and photographs each one in the game.**
#
# For each palette: rewrite the colour constants in `tools/blender/island_build.py` and
# `buildings_build.py`, bake both through the running Blender, force Godot to re-import, and shoot one
# PNG. Seven bakes, seven shots.
#
# WARNING **THE BUILD SCRIPTS ARE EDITED IN PLACE AND RESTORED AT THE END, ALWAYS** -- including on a
# crash or a Ctrl-C, which is what the `finally` is for. `*.orig` beside this file is the backup, and
# the restore is verified byte-for-byte before this exits.
#
# WARNING **Godot serves its own converted copy of a `.glb` and a `-s` run does NOT re-convert a
# changed source.** `bake_island.ps1` carries the story: three bakes in a row came back identical and
# the third was investigated as a modelling bug while the file on disk was minutes old. **Deleting the
# `.md5` is what forces it** -- removing only the `.scn` leaves the md5 saying the copy is current.
#
# Blender must be open with the MCP add-on listening.
#
# Run:  python .prototypes/palette/bake_all.py
import io
import json
import os
import re
import shutil
import subprocess
import sys

# WARNING **The console is cp949 on this machine and an em dash kills the run at the first print.**
# The `finally` still restored the build scripts, but nothing was baked and nothing said why until the
# traceback was read.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HERE = os.path.join(ROOT, "prototypes", "palette")
GODOT = os.path.join(ROOT, "Godot_v4.7.1-stable_win64.exe")
ISLAND = os.path.join(ROOT, "tools", "blender", "island_build.py")
BUILDINGS = os.path.join(ROOT, "tools", "blender", "buildings_build.py")
SEND = os.path.join(ROOT, "tools", "blender", "send.py")

# Which constant in which script each palette key writes.
LAND_KEYS = {"grass": "GRASS", "grass_high": "GRASS_HIGH", "rock": "ROCK", "shore": "SHORE"}
BUILD_KEYS = {"wall": "WALL", "wood": "WOOD", "roof": "ROOF", "stone": "STONE"}


def read(path):
    return io.open(path, encoding="utf-8").read()


def write(path, text):
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)


def set_const(src, name, rgb):
    """Rewrites `NAME = (r, g, b)` and nothing else.

    WARNING **Anchored to the start of a line and to this exact name.** `ROCK` also appears inside
    `props_build.py` and as a substring of other words; a loose replace would rewrite comments and
    other constants, and the failure would be a slightly wrong colour with nothing on screen saying so.
    """
    pat = re.compile(r"^%s = \([^)]*\)" % re.escape(name), re.M)
    new = "%s = (%.3f, %.3f, %.3f)" % (name, rgb[0], rgb[1], rgb[2])
    out, n = pat.subn(new, src, count=1)
    if n != 1:
        raise SystemExit("bake_all: %s 를 한 번 정확히 못 바꿨다 (%d 곳)" % (name, n))
    return out


def shaded(base_src, name, rgb):
    """The `*_D` twin of a building tone, as the ORIGINAL pair's own per-channel ratio.

    A building's shaded pitch is not a fixed fraction of its lit face -- `WALL_D/WALL` is about 0.88
    and `ROOF_D/ROOF` about 0.77 -- so each pair is measured off the file being replaced and the same
    relationship is carried onto the new base. Inventing one ratio for all four would flatten the
    difference between plaster and fired tile, which is a decision somebody already made.
    """
    def grab(n):
        m = re.search(r"^%s = \(([^)]*)\)" % re.escape(n), base_src, re.M)
        return [float(v) for v in m.group(1).split(",")]
    lit, dark = grab(name), grab(name + "_D")
    return [max(0.0, min(1.0, rgb[i] * (dark[i] / lit[i] if lit[i] > 1e-6 else 1.0))) for i in range(3)]


# WARNING **`buildings_build.flat_mat` REUSES A MATERIAL BY NAME**: `bpy.data.materials.get("b_"+name)`
# returns the one from the previous bake and never applies the new colour. Blender stays open across
# all seven bakes, so **every palette after the first came out wearing the first palette's buildings** —
# and the island recoloured correctly beside them, because it carries vertex colours and makes no named
# material at all. **The roof was red in all seven shots and nothing said why.**
# ⇒ Wipe them between bakes. This runs in Blender, not here.
PURGE_MATS = """
import bpy
n = 0
for m in list(bpy.data.materials):
    if m.name.startswith("b_"):
        bpy.data.materials.remove(m)
        n += 1
print("purged %d building materials" % n)
"""


def send_code(code, what):
    r = subprocess.run([sys.executable, SEND, "-"], cwd=ROOT, input=code, capture_output=True,
                       text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.stdout.write(r.stdout or "")
        sys.stderr.write(r.stderr or "")
        raise SystemExit("bake_all: %s 가 실패했다" % what)
    return r.stdout or ""


def run(cmd, what):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                       errors="replace")
    if r.returncode != 0:
        sys.stdout.write(r.stdout or "")
        sys.stderr.write(r.stderr or "")
        raise SystemExit("bake_all: %s 가 실패했다" % what)
    return r.stdout or ""


def force_reimport(stems):
    """Throws away Godot's converted copies so the next run reads the file just baked."""
    cache = os.path.join(ROOT, ".godot", "imported")
    if os.path.isdir(cache):
        for f in os.listdir(cache):
            if any(f.startswith(s + ".glb-") for s in stems):
                os.remove(os.path.join(cache, f))
    subprocess.run([GODOT, "--headless", "--path", ".", "--import"], cwd=ROOT,
                   capture_output=True, text=True, encoding="utf-8", errors="replace")
    # WARNING **Measured, not trusted.** A bake that quietly did not reach the game is the exact
    # failure `bake_island.ps1` was written for.
    for s in stems:
        src = max(os.path.getmtime(os.path.join(ROOT, p)) for p in _sources(s))
        scn = [os.path.join(cache, f) for f in os.listdir(cache)
               if f.startswith(s + ".glb-") and f.endswith(".scn")]
        if not scn:
            raise SystemExit("bake_all: 고도가 %s 를 다시 안 읽었다 — 캐시가 비어 있다" % s)
        if os.path.getmtime(scn[0]) < src:
            raise SystemExit("bake_all: 고도가 읽은 %s 사본이 원본보다 낡았다" % s)


def _sources(stem):
    return {"island": ["assets/terrain/island.glb"],
            "buildings": ["assets/buildings/buildings.glb"]}[stem]


def main():
    table = json.load(io.open(os.path.join(HERE, "palettes.json"), encoding="utf-8"))
    island_orig = read(os.path.join(HERE, "island_build.py.orig"))
    build_orig = read(os.path.join(HERE, "buildings_build.py.orig"))
    try:
        for p in table["palettes"]:
            print("\n=== %s — %s" % (p["name"], p["principle"]))
            isl = island_orig
            for key, const in LAND_KEYS.items():
                isl = set_const(isl, const, p[key])
            write(ISLAND, isl)
            bld = build_orig
            for key, const in BUILD_KEYS.items():
                bld = set_const(bld, const, p[key])
                bld = set_const(bld, const + "_D", shaded(build_orig, const, p[key]))
            write(BUILDINGS, bld)

            print("  [1/4] 섬을 굽는다")
            run([sys.executable, SEND, ISLAND], "섬 굽기")
            print("  [2/4] 건물을 굽는다")
            send_code(PURGE_MATS, "건물 머티리얼 지우기")
            run([sys.executable, SEND, BUILDINGS], "건물 굽기")
            print("  [3/4] 고도가 새로 읽게 한다")
            force_reimport(["island", "buildings"])
            print("  [4/4] 게임에서 찍는다")
            write(os.path.join(HERE, "current.json"), json.dumps(p, ensure_ascii=False))
            out = run([GODOT, "--path", ".", "-s", ".prototypes/palette/shoot_one.gd"], "촬영")
            if "[palette]" not in out:
                raise SystemExit("bake_all: 촬영이 그림을 안 남겼다 — %s" % p["name"])
    finally:
        # WARNING **Restored whatever happened, and CHECKED.** These are the real build scripts; a
        # crash halfway through would otherwise leave the repo baking one candidate palette forever.
        write(ISLAND, island_orig)
        write(BUILDINGS, build_orig)
        assert read(ISLAND) == island_orig and read(BUILDINGS) == build_orig
        print("\n빌드 스크립트를 원래대로 되돌렸다")
    print("끝났다 — %d 벌" % len(table["palettes"]))


if __name__ == "__main__":
    main()
