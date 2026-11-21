#!/usr/bin/env python3
"""Ember Hop art normalizer (Pillow only).

Keys flat magenta (#FF00FF) to real alpha with colour decontamination, splits grid sheets,
trims each cell to its content, scales with one shared factor, and pastes onto a fixed
canvas with a shared anchor so animation frames don't jitter.

  python process_art.py sheet IN.png OUTDIR --grid 4x2 --names a,b,... \
      --ref-height 128 --ref-names idle --canvas 128x144 --anchor bottom
  python process_art.py key IN.png OUT.png [--width 2560]       # key a whole image
  python process_art.py tile IN.png OUTDIR --count 3 --names top,fill,platform --size 64

Exit 0 ok, 2 bad input.
"""
from __future__ import annotations

import argparse
import os
import sys

from PIL import Image, ImageChops, ImageFilter

MAGENTA = (255, 0, 255)


def key_magenta(im: Image.Image, lo: int = 40, hi: int = 150) -> Image.Image:
    """Return RGBA with alpha from 'magenta-ness' = min(R,B) - G, colours decontaminated."""
    im = im.convert("RGB")
    r, g, b = im.split()
    m = ImageChops.subtract(ImageChops.darker(r, b), g)          # 0 for non-magenta, ~255 for bg
    span = hi - lo
    alpha = m.point(lambda v: 255 if v <= lo else (0 if v >= hi else int(255 * (hi - v) / span)))
    px = list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())
    al = list(alpha.get_flattened_data()) if hasattr(alpha, "get_flattened_data") else list(alpha.getdata())
    out = []
    for (pr, pg, pb), a in zip(px, al):
        if a == 0:
            out.append((0, 0, 0, 0))
        elif a == 255:
            out.append((pr, pg, pb, 255))
        else:  # unblend from magenta: P = a*C + (1-a)*M
            f = a / 255.0
            cr = (pr - (1 - f) * 255) / f
            cg = pg / f
            cb = (pb - (1 - f) * 255) / f
            out.append((max(0, min(255, int(cr))), max(0, min(255, int(cg))),
                        max(0, min(255, int(cb))), a))
    res = Image.new("RGBA", im.size)
    res.putdata(out)
    return res


def clean_specks(im: Image.Image, min_alpha: int = 24) -> Image.Image:
    """Drop near-invisible alpha noise."""
    a = im.getchannel("A").point(lambda v: 0 if v < min_alpha else v)
    im = im.copy()
    im.putalpha(a)
    return im


def content_box(im: Image.Image):
    return im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()


def body_center_x(im: Image.Image) -> float:
    """x centre of the upper 70 % of the content (stable against swinging legs)."""
    box = content_box(im)
    if not box:
        return im.width / 2
    top = box[1] + int((box[3] - box[1]) * 0.7)
    upper = im.crop((0, box[1], im.width, top)).getchannel("A")
    cols = [sum(1 for y in range(upper.height) if upper.getpixel((x, y)) > 40) for x in range(upper.width)]
    total = sum(cols)
    return sum(x * c for x, c in enumerate(cols)) / total if total else im.width / 2


def cmd_sheet(a) -> int:
    src = key_magenta(Image.open(a.input))
    cols, rows = (int(v) for v in a.grid.lower().split("x"))
    names = a.names.split(",")
    if len(names) != cols * rows:
        print(f"error: {len(names)} names for {cols*rows} cells", file=sys.stderr)
        return 2
    cw, ch = src.width / cols, src.height / rows
    cells = {}
    for i, name in enumerate(names):
        c, r = i % cols, i // cols
        cell = src.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))
        cell = clean_specks(cell)
        box = content_box(cell)
        if not box:
            print(f"error: cell {name} is empty", file=sys.stderr)
            return 2
        cells[name] = cell.crop(box)
    ref = [n for n in a.ref_names.split(",") if n in cells] or names
    ref_h = sorted(cells[n].height for n in ref)[len(ref) // 2]
    scale = a.ref_height / ref_h
    cw_out, ch_out = (int(v) for v in a.canvas.lower().split("x"))
    os.makedirs(a.outdir, exist_ok=True)
    only = set(a.only.split(",")) if a.only else None
    for name, im in cells.items():
        if only and name not in only:
            continue
        sw, sh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
        small = im.resize((sw, sh), Image.LANCZOS)
        cx = body_center_x(small)
        canvas = Image.new("RGBA", (cw_out, ch_out), (0, 0, 0, 0))
        x = round(cw_out / 2 - cx)
        y = ch_out - sh - a.margin if a.anchor == "bottom" else round((ch_out - sh) / 2)
        if sw > cw_out or sh > ch_out:
            print(f"warning: {name} {sw}x{sh} exceeds canvas {cw_out}x{ch_out}", file=sys.stderr)
        canvas.alpha_composite(small, (max(0, x), max(0, y)))
        canvas.save(os.path.join(a.outdir, f"{a.prefix}{name}.png"))
        print(f"{a.prefix}{name}.png  content {sw}x{sh}")
    print(f"scale {scale:.4f}")
    return 0


def cmd_key(a) -> int:
    im = key_magenta(Image.open(a.input))
    im = clean_specks(im)
    if a.width:
        im = im.resize((a.width, round(im.height * a.width / im.width)), Image.LANCZOS)
    im.save(a.output)
    print(f"{a.output} {im.width}x{im.height}")
    return 0


def make_seamless_x(im: Image.Image, band: int) -> Image.Image:
    """Classic cross-fade: blend the right band into the left band, then drop the right band.
    Result width = w - band; its right edge continues straight into its left edge."""
    w, h = im.size
    out = im.crop((0, 0, w - band, h))
    for i in range(band):
        t = i / band  # 0 at the seam -> take the right-band pixel; 1 -> own pixel
        col = Image.blend(im.crop((w - band + i, 0, w - band + i + 1, h)), im.crop((i, 0, i + 1, h)), t)
        out.paste(col, (i, 0))
    return out


def cmd_tile(a) -> int:
    src = key_magenta(Image.open(a.input))
    names = a.names.split(",")
    # find tiles as horizontal runs of non-empty columns
    alpha = src.getchannel("A")
    colmask = [any(alpha.getpixel((x, y)) > 128 for y in range(0, src.height, 4)) for x in range(src.width)]
    runs, start = [], None
    for x, on in enumerate(colmask + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > src.width * 0.08:
                runs.append((start, x))
            start = None
    if len(runs) != a.count:
        print(f"error: found {len(runs)} tiles, expected {a.count}", file=sys.stderr)
        return 2
    os.makedirs(a.outdir, exist_ok=True)
    for name, (x0, x1) in zip(names, runs):
        sub = src.crop((x0, 0, x1, src.height))
        rows = [y for y in range(sub.height) if any(sub.getpixel((x, y))[3] > 128 for x in range(0, sub.width, 4))]
        y0, y1 = rows[0], rows[-1] + 1
        side = x1 - x0
        if name == "platform":
            # plank occupies the top part of the square: keep a square crop from the plank top
            sq = sub.crop((0, y0, side, y0 + side))
        else:
            sq = sub.crop((0, y0, side, min(y1, y0 + side)))
            sq = sq.resize((side, side), Image.LANCZOS)
        big = a.size * 4
        sq = sq.resize((big, big), Image.LANCZOS)
        sq = make_seamless_x(sq, big // 8)
        if name == "fill":
            sq = make_seamless_x(sq.transpose(Image.ROTATE_90), big // 8).transpose(Image.ROTATE_270)
            sq.putalpha(sq.getchannel("A").point(lambda v: 255))
        sq = sq.resize((a.size, a.size), Image.LANCZOS)
        path = os.path.join(a.outdir, f"tile_{name}.png")
        sq.save(path)
        print(path)
    return 0


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("sheet")
    s.add_argument("input"); s.add_argument("outdir")
    s.add_argument("--grid", required=True); s.add_argument("--names", required=True)
    s.add_argument("--ref-height", type=int, default=128); s.add_argument("--ref-names", default="")
    s.add_argument("--canvas", default="128x144"); s.add_argument("--anchor", choices=["bottom", "center"], default="bottom")
    s.add_argument("--margin", type=int, default=2); s.add_argument("--prefix", default="")
    s.add_argument("--only", default="", help="comma list of cell names to write")
    k = sub.add_parser("key")
    k.add_argument("input"); k.add_argument("output"); k.add_argument("--width", type=int)
    t = sub.add_parser("tile")
    t.add_argument("input"); t.add_argument("outdir")
    t.add_argument("--count", type=int, default=3); t.add_argument("--names", default="top,fill,platform")
    t.add_argument("--size", type=int, default=64)
    a = p.parse_args(argv)
    if not os.path.isfile(a.input):
        print(f"error: {a.input} not found", file=sys.stderr)
        return 2
    return {"sheet": cmd_sheet, "key": cmd_key, "tile": cmd_tile}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
