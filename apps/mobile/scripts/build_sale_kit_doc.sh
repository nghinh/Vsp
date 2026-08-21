#!/usr/bin/env bash
#
# Builds the one-file product document out of the sale-kit screenshots.
#
#   scripts/build_sale_kit_doc.sh
#
# Reads docs/sale-kit/vsp-sale-kit.template.html, replaces every
# {{IMG:<name>}} with a base64 data URI of docs/sale-kit/dark/<name>.png, and
# writes docs/sale-kit/vsp-sale-kit.html.
#
# One file, because of how it gets used: this document is emailed and sent over
# Zalo to people who will not receive a folder of images alongside it, and a
# page that arrives with broken thumbnails is worse than no page. The PNGs are
# downscaled to JPEG on the way in — a 29 MB kit becomes a document under a
# megabyte, which is the difference between an attachment that sends and one
# that bounces.
#
# Rerun it after every scripts/sale_kit.sh, or the document keeps showing the
# app as it was last month.
set -euo pipefail

cd "$(dirname "$0")/.."

KIT="docs/sale-kit"
TEMPLATE="$KIT/vsp-sale-kit.template.html"
OUT="$KIT/vsp-sale-kit.html"
SHOTS="$KIT/dark"

[ -f "$TEMPLATE" ] || { echo "missing $TEMPLATE" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Only the scenes the document names, and only at the size it displays them.
# sips ships with macOS, which is where the kit is shot anyway.
for name in $(grep -oE '\{\{IMG:[^}]+\}\}' "$TEMPLATE" | sed 's/{{IMG://; s/}}//' | sort -u); do
  src="$SHOTS/$name.png"
  [ -f "$src" ] || { echo "the template asks for $name.png and the kit has no such shot" >&2; exit 1; }
  sips -Z 660 -s format jpeg -s formatOptions 72 "$src" --out "$WORK/$name.jpg" >/dev/null
done

TEMPLATE="$TEMPLATE" WORK="$WORK" OUT="$OUT" python3 - <<'PY'
import base64, os, pathlib, re

template = pathlib.Path(os.environ['TEMPLATE'])
work = pathlib.Path(os.environ['WORK'])
out = pathlib.Path(os.environ['OUT'])

def embed(match):
    jpeg = work / f'{match.group(1)}.jpg'
    return 'data:image/jpeg;base64,' + base64.b64encode(jpeg.read_bytes()).decode()

html = re.sub(r'\{\{IMG:([^}]+)\}\}', embed, template.read_text())
assert '{{IMG:' not in html, 'a placeholder survived'
out.write_text(html)
print(f'==> {out} ({out.stat().st_size / 1024 / 1024:.2f} MB)')
PY
