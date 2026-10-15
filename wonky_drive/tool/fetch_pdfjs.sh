#!/usr/bin/env bash
# Fetches the pdf.js build that Wonky Drive's PDF previews use into
# web/pdfjs/ (Drive 02 §6.3, spike S-D1). The apps are cross-origin
# isolated (COOP/COEP), so pdf.js must be served from the app's own origin;
# `printing` loads `pdf.min.mjs` + `pdf.worker.min.mjs` from
# `window.dartPdfJsBaseUrl` (set in web/index.html).
#
#   tool/fetch_pdfjs.sh [version]
#
# The default version is the one `printing` was tested with (its
# `_pdfJsVersion`). Run from the wonky_drive folder; commit the result.
set -euo pipefail

VERSION="${1:-6.2.108}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/web/pdfjs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading pdfjs-dist@$VERSION from the npm registry…"
curl -fsSL "https://registry.npmjs.org/pdfjs-dist/-/pdfjs-dist-$VERSION.tgz" \
  -o "$WORK/pdfjs.tgz"
tar -xzf "$WORK/pdfjs.tgz" -C "$WORK"

rm -rf "$DEST"
mkdir -p "$DEST"
cp "$WORK/package/build/pdf.min.mjs" "$DEST/"
cp "$WORK/package/build/pdf.worker.min.mjs" "$DEST/"
cp -R "$WORK/package/cmaps" "$DEST/cmaps"
cp "$WORK/package/LICENSE" "$DEST/LICENSE"
echo "$VERSION" > "$DEST/VERSION"
echo "pdf.js $VERSION installed in $DEST"
