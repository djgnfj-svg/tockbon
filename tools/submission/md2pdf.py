"""Markdown -> print-styled HTML -> PDF, for the NAN 2026 submission documents.

Why not a one-liner npx tool: the submission docs are **table-heavy Korean**, and every
off-the-shelf renderer we would reach for either drops the tables (no `tables` extension
by default) or ships no Korean font, which is the exact defect that shipped in the web
build. Chrome is already on this machine, prints from the OS font stack, and honours
`@page`, so it is the whole PDF engine here.

Run:
    python tools/submission/md2pdf.py

Output lands in build/submission/. That folder is not committed.
"""

import base64
import html
import mimetypes
import re
import subprocess
import sys
from pathlib import Path

import markdown

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "docs" / "archive" / "nan2026"
OUT = ROOT / "build" / "submission"
REPO = "https://github.com/djgnfj-svg/tockbon"

# The judge reads a PDF, so a relative `[review.md](review.md)` would be a dead link.
# Point every one of them at the public repo instead — the file is genuinely there.
BLOB = REPO + "/blob/main/"

# (source, PDF title, submitted file name). **The third field is what the judge sees in their
#  download folder** — `plan.pdf` beside forty other `plan.pdf`s says nothing about whose it is
#  or which of the two required documents it answers.
DOCS = [
    ("plan.md", "Tockbon — 게임 소개 및 설명 문서 (NAN 2026 예선)",
     "NAN2026_탁본_게임소개및설명문서.pdf"),
    ("ai-tech.md", "Tockbon — AI 활용 기술 문서 (NAN 2026 예선)",
     "NAN2026_탁본_AI활용기술문서.pdf"),
]

CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
]

# `Malgun Gothic` is the Windows system Korean face. Listing a monospace Korean fallback
# matters for the ASCII diagrams: the magic-circle drawing uses box characters, and a
# monospace face without them substitutes at a different advance width, tearing the box.
CSS = """
@page { size: A4; margin: 16mm 14mm 18mm 14mm; }
* { box-sizing: border-box; }
body {
  font-family: "Malgun Gothic", "맑은 고딕", "Noto Sans KR", sans-serif;
  font-size: 9.6pt; line-height: 1.62; color: #16181d; margin: 0;
  -webkit-print-color-adjust: exact; print-color-adjust: exact;
}
h1, h2, h3, h4 { line-height: 1.3; margin: 1.15em 0 .5em; page-break-after: avoid; }
h1 { font-size: 19pt; letter-spacing: -.02em; border-bottom: 2.5px solid #16181d;
     padding-bottom: .3em; margin-top: 0; }
h2 { font-size: 13.5pt; border-bottom: 1px solid #c9ced6; padding-bottom: .22em;
     margin-top: 1.6em; }
h3 { font-size: 11pt; color: #23262d; }
h4 { font-size: 9.9pt; color: #40454e; }
p, li { orphans: 2; widows: 2; }
p { margin: .55em 0; }
ul, ol { margin: .55em 0; padding-left: 1.35em; }
li { margin: .22em 0; }
strong { font-weight: 700; color: #000; }
a { color: #0a4bd0; text-decoration: none; word-break: break-all; }

table {
  border-collapse: collapse; width: 100%; margin: .8em 0; font-size: 8.6pt;
  page-break-inside: auto;
}
tr { page-break-inside: avoid; page-break-after: auto; }
th, td { border: 1px solid #b9bfc9; padding: 4.5px 7px; vertical-align: top;
         text-align: left; }
th { background: #eef1f5; font-weight: 700; }
tbody tr:nth-child(even) td { background: #fafbfc; }

code { font-family: Consolas, "D2Coding", "Malgun Gothic", monospace;
       font-size: 8.4pt; background: #f0f2f5; padding: 1px 4px; border-radius: 3px; }
pre { background: #f6f7f9; border: 1px solid #dde1e7; border-left: 3px solid #8b93a1;
      padding: 8px 11px; overflow-x: hidden; page-break-inside: avoid;
      white-space: pre-wrap; word-break: break-word; }
pre code { background: none; padding: 0; font-size: 8.1pt; line-height: 1.42; }

blockquote { margin: .8em 0; padding: .35em 0 .35em .95em;
             border-left: 3px solid #9aa2b1; color: #33373f; background: #fbfcfd; }
blockquote p { margin: .3em 0; }
hr { border: 0; border-top: 1px solid #d5dae1; margin: 1.5em 0; }
details { margin: .7em 0; }
summary { font-weight: 700; cursor: default; }

/* The two-column key/value tables that open each document carry the submission links.
   Judges look for those first, so they get a heavier frame. */
h1 + table th, h1 + table td { padding: 6px 9px; font-size: 9.2pt; }

/* Screenshots. `image-rendering: pixelated` is not decoration: the game renders at a
   960x540 viewport and every sprite is hand-placed pixel art, so a smoothed downscale
   turns the 4px cells into mush — the one thing the picture is there to show. */
figure { margin: 1em 0; page-break-inside: avoid; text-align: center; }
figure img { max-width: 100%; border: 1px solid #c9ced6; image-rendering: pixelated; }
figcaption { font-size: 8.2pt; color: #5c626c; margin-top: .35em; }
"""

FOOT = """
<div class="doc-foot">
  Tockbon · NAN 2026 예선 제출 · 플레이 https://djgnfj-svg.github.io/tockbon/
  · 소스 %s
</div>
""" % REPO

FOOT_CSS = """
.doc-foot { margin-top: 2.4em; padding-top: .6em; border-top: 1px solid #d5dae1;
            font-size: 7.6pt; color: #6b717c; page-break-inside: avoid; }
"""


def _rewrite_links(text: str) -> str:
    """Relative `.md` links die in a PDF. Send them to the public repo."""
    return re.sub(
        r"\]\((?!https?://|#)([A-Za-z0-9_./-]+\.md)\)",
        lambda m: "](%sdocs/archive/nan2026/%s)" % (BLOB, m.group(1))
        if "/" not in m.group(1)
        else "](%s%s)" % (BLOB, m.group(1)),
        text,
    )


def _print_fixes(body: str) -> str:
    """Two things that read fine in a browser and lose information on paper."""
    # A collapsed <details> prints as its summary line alone — on the first page of
    # plan.md that silently drops the whole "build it yourself" block. Paper has no
    # disclosure triangle to click, so everything is open.
    body = re.sub(r"<details(?![^>]*\bopen\b)", "<details open", body)
    # The key/value tables written as `| | |` produce a header row of empty <th>,
    # which prints as a grey bar above the table with nothing in it.
    body = re.sub(r"<thead>\s*<tr>\s*(?:<th[^>]*>\s*</th>\s*)+</tr>\s*</thead>",
                  "", body)
    return body


def _embed_images(body: str, base: Path) -> str:
    """Inline every local image as a data URI, and give it a caption.

    The rendered HTML lands in `build/submission/`, not next to the markdown, so a
    relative `img/foo.png` would resolve to nothing and Chrome would print a silent
    empty box. Base64 removes the path question entirely. A missing file is a hard
    failure here on purpose — a screenshot that quietly does not print is the exact
    shape of defect this submission has already been burned by twice.
    """

    def one(m: re.Match) -> str:
        src, alt = m.group("src"), m.group("alt")
        if src.startswith(("http://", "https://", "data:")):
            return m.group(0)
        f = (base / src).resolve()
        if not f.exists():
            print("[md2pdf] missing image %s" % f, file=sys.stderr)
            sys.exit(1)
        mime = mimetypes.guess_type(f.name)[0] or "image/png"
        data = base64.b64encode(f.read_bytes()).decode("ascii")
        cap = "<figcaption>%s</figcaption>" % alt if alt else ""
        return ('<figure><img alt="%s" src="data:%s;base64,%s">%s</figure>'
                % (alt, mime, data, cap))

    # A lone image in markdown comes out as `<p><img ...></p>`; unwrap that paragraph
    # so the figure is not nested inside one.
    body = re.sub(r"<p>\s*(<img[^>]*>)\s*</p>", r"\1", body)
    return re.sub(
        r'<img[^>]*\balt="(?P<alt>[^"]*)"[^>]*\bsrc="(?P<src>[^"]*)"[^>]*>'
        r'|<img[^>]*\bsrc="(?P<src2>[^"]*)"[^>]*\balt="(?P<alt2>[^"]*)"[^>]*>',
        lambda m: one(_Named(m)), body)


class _Named:
    """`markdown` emits src-then-alt or alt-then-src depending on the extension set.
    Both orders are matched above; this hands whichever pair fired to one handler."""

    def __init__(self, m: re.Match) -> None:
        self._m = m

    def group(self, key):
        if key == 0:
            return self._m.group(0)
        return self._m.group(key) or self._m.group(key + "2")


def render(md_path: Path, title: str) -> Path:
    text = _rewrite_links(md_path.read_text(encoding="utf-8"))
    body = markdown.markdown(
        text,
        extensions=["tables", "fenced_code", "sane_lists", "md_in_html"],
    )
    body = _print_fixes(body)
    body = _embed_images(body, md_path.parent)
    page = (
        "<!doctype html><html lang='ko'><head><meta charset='utf-8'>"
        "<title>%s</title><style>%s%s</style></head><body>%s%s</body></html>"
        % (html.escape(title), CSS, FOOT_CSS, body, FOOT)
    )
    out_html = OUT / (md_path.stem + ".html")
    out_html.write_text(page, encoding="utf-8")
    return out_html


def find_chrome() -> Path:
    for c in CHROME_CANDIDATES:
        if c.exists():
            return c
    print("[md2pdf] no Chrome or Edge found — cannot print", file=sys.stderr)
    sys.exit(1)


def to_pdf(chrome: Path, html_path: Path, pdf_name: str) -> Path:
    pdf = html_path.with_name(pdf_name)
    if pdf.exists():
        pdf.unlink()
    cmd = [
        str(chrome),
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--no-pdf-header-footer",
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=10000",
        "--print-to-pdf=%s" % pdf,
        html_path.as_uri(),
    ]
    # **`errors="replace"` is not cosmetic.** Chrome writes UTF-8 to stderr and this
    #  console is cp949, so the reader thread raises UnicodeDecodeError — after the PDF
    #  is already on disk. The run looks like a crash while having fully succeeded.
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180,
                       encoding="utf-8", errors="replace")
    if not pdf.exists():
        print("[md2pdf] Chrome produced no file for %s" % html_path.name, file=sys.stderr)
        print(r.stderr[-2000:], file=sys.stderr)
        sys.exit(1)
    return pdf


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    chrome = find_chrome()
    print("[md2pdf] engine: %s" % chrome.name)
    for name, title, pdf_name in DOCS:
        src = SRC / name
        if not src.exists():
            print("[md2pdf] missing %s" % src, file=sys.stderr)
            sys.exit(1)
        pdf = to_pdf(chrome, render(src, title), pdf_name)
        print("[md2pdf] %-12s -> %s  (%.2f MB)"
              % (name, pdf.name, pdf.stat().st_size / 1048576))
    print("[md2pdf] out: %s" % OUT)


if __name__ == "__main__":
    main()
