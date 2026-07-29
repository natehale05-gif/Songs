#!/usr/bin/env bash
# Package the Linux release bundle as a single double-clickable AppImage.
#
#   flutter build linux --release
#   tool/make_appimage.sh [output.AppImage]
#
# Produces a self-contained file that needs no install step — the user just
# makes it executable and runs it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
OUT="${1:-$ROOT/build/songs-of-the-church-x86_64.AppImage}"
WORK="$ROOT/build/appimage"

if [ ! -d "$BUNDLE" ]; then
  echo "error: $BUNDLE not found — run 'flutter build linux --release' first" >&2
  exit 1
fi

rm -rf "$WORK"
APPDIR="$WORK/AppDir"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

cp -r "$BUNDLE"/* "$APPDIR/usr/bin/"
cp "$ROOT/linux/packaging/songs-of-the-church.desktop" \
   "$APPDIR/usr/share/applications/"
cp "$ROOT/linux/packaging/songs-of-the-church.png" \
   "$APPDIR/usr/share/icons/hicolor/256x256/apps/"

# appimagetool expects the desktop entry and icon at the AppDir root too.
cp "$ROOT/linux/packaging/songs-of-the-church.desktop" "$APPDIR/"
cp "$ROOT/linux/packaging/songs-of-the-church.png" "$APPDIR/"

# Flutter looks for data/ and lib/ relative to the executable, so cd there
# first rather than relying on the caller's working directory.
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/usr/bin/env bash
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/bin/lib:${LD_LIBRARY_PATH:-}"
cd "${HERE}/usr/bin"
exec ./songs_of_the_church "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Fetch appimagetool and unpack it, since FUSE is unavailable on CI runners.
TOOL_DIR="$WORK/tool"
mkdir -p "$TOOL_DIR"
TOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
curl -fsSL -o "$TOOL_DIR/appimagetool" "$TOOL_URL"
chmod +x "$TOOL_DIR/appimagetool"
( cd "$TOOL_DIR" && ./appimagetool --appimage-extract >/dev/null )

ARCH=x86_64 "$TOOL_DIR/squashfs-root/AppRun" "$APPDIR" "$OUT"
echo "built $OUT"
