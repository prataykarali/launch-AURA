#!/usr/bin/env bash
# =============================================================================
# build_rust_linux.sh — rebuild libaura_lnn.so for Linux and sync into bundle
# =============================================================================
#
# WHY THIS EXISTS
#   The Linux Flutter app links a PREBUILT libaura_lnn.so. CMake only COPIES it
#   (linux/CMakeLists.txt:77-81) — it never rebuilds it. So every time you
#   regenerate the frb Dart bindings (`flutter_rust_bridge_codegen generate`)
#   or edit Rust source, the .so's baked-in content hash goes STALE while the
#   Dart side updates, and at runtime flutter_rust_bridge throws:
#
#     "Content hash on Dart side (X) is different from Rust side (Y),
#      indicating out-of-sync code."
#
#   Run this script AFTER any Rust edit or frb regenerate, BEFORE `flutter run`.
#
# WHAT IT DOES
#   1. cargo build --release  → produces a fresh .so with the current hash
#   2. copies it into the 3 Linux bundle locations CMake/Flutter read from
#   3. reads the hash baked into the .so AND the hash expected by Dart, and
#      FAILS LOUDLY if they differ — so a stale .so can never ship silently.
#
# USAGE
#   bash scripts/build_rust_linux.sh         # build + copy + verify
#   bash scripts/build_rust_linux.sh --debug # use cargo debug profile
# =============================================================================
set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [[ -d "$PROJ_ROOT/candle_LNN/aura_lnn" ]]; then
  RUST_CRATE="$PROJ_ROOT/candle_LNN/aura_lnn"
  FLUTTER_APP="$PROJ_ROOT/aura_notebook"
else
  RUST_CRATE="$PROJ_ROOT/AURA-Proj/candle_LNN/aura_lnn"
  FLUTTER_APP="$PROJ_ROOT/AURA-Proj/aura_notebook"
fi


PROFILE="release"
if [[ "${1:-}" == "--debug" ]]; then PROFILE="debug"; fi

SO_SRC="$RUST_CRATE/target/$PROFILE/libaura_lnn.so"
DART_HASH_FILE="$FLUTTER_APP/lib/src/rust/frb_generated.dart"

BUNDLE_DESTS=(
  "$FLUTTER_APP/linux/bundle/lib/libaura_lnn.so"
  "$FLUTTER_APP/linux_libs/libaura_lnn.so"
  "$FLUTTER_APP/build/linux/x64/debug/bundle/lib/libaura_lnn.so"
  "$FLUTTER_APP/build/linux/x64/release/bundle/lib/libaura_lnn.so"
)

# ── Sanity ───────────────────────────────────────────────────────────────────
if [[ ! -d "$RUST_CRATE" ]]; then
  echo "✗ Rust crate not found: $RUST_CRATE" >&2; exit 1
fi
command -v cargo >/dev/null || { echo "✗ cargo not on PATH" >&2; exit 1; }

# ── 1. Build ─────────────────────────────────────────────────────────────────
echo "▶ Building libaura_lnn.so (profile=$PROFILE)…"
if [[ "$PROFILE" == "release" ]]; then
  ( cd "$RUST_CRATE" && cargo build --lib --release )
else
  ( cd "$RUST_CRATE" && cargo build --lib )
fi
[[ -f "$SO_SRC" ]] || { echo "✗ Build finished but .so not found at $SO_SRC" >&2; exit 1; }

# ── 2. Copy to bundle locations ──────────────────────────────────────────────
echo "▶ Copying into bundle locations…"
for dest in "${BUNDLE_DESTS[@]}"; do
  if [[ -d "$(dirname "$dest")" ]]; then
    cp -f "$SO_SRC" "$dest"
    echo "  ✓ $dest"
  else
    echo "  · skipped (dir absent): $dest"
  fi
done

# Also sync to the FRB hardcoded release path and project root .so.
# frb_generated.dart hardcodes ../candle_LNN/aura_lnn/target/release/ as the
# load path, and a stale aura_notebook/libaura_lnn.so can shadow the bundle.
echo "▶ Syncing FRB release path + project root .so…"
RELEASE_DIR="$RUST_CRATE/target/release"
if [[ -d "$RELEASE_DIR" ]] && [[ "$SO_SRC" != "$RELEASE_DIR/libaura_lnn.so" ]]; then
  cp -f "$SO_SRC" "$RELEASE_DIR/libaura_lnn.so"
  echo "  ✓ $RELEASE_DIR/libaura_lnn.so"
fi
ROOT_SO="$FLUTTER_APP/libaura_lnn.so"
if [[ -f "$ROOT_SO" ]] || [[ -d "$(dirname "$ROOT_SO")" ]]; then
  cp -f "$SO_SRC" "$ROOT_SO"
  echo "  ✓ $ROOT_SO"
fi

# ── 3. Verify content hash matches Dart expectation ──────────────────────────
# Read the i32 the .so returns from frb_get_rust_content_hash (mov imm,%eax; ret)
read_so_hash() {
  objdump -d "$1" 2>/dev/null \
    | grep -A1 "<frb_get_rust_content_hash" \
    | grep -o '0x[0-9a-f]*,%eax' \
    | head -1 \
    | sed 's/,%eax//'
}

SO_HASH_HEX="$(read_so_hash "$SO_SRC" || true)"
if [[ -z "$SO_HASH_HEX" ]]; then
  echo "⚠ Could not read hash from .so (symbol may be inlined) — skipping verify." >&2
else
  SO_HASH_DEC="$(python3 -c "
h=int('$SO_HASH_HEX',16)
print(h-0x100000000 if h>=0x80000000 else h)
")"
  DART_HASH_DEC="$(grep -oP 'rustContentHash => \K-?[0-9]+' "$DART_HASH_FILE" || true)"
  echo "▶ Content hash check:"
  echo "    .so  ($PROFILE): $SO_HASH_DEC"
  echo "    Dart (expected): ${DART_HASH_DEC:-<not found>}"
  if [[ "$SO_HASH_DEC" != "$DART_HASH_DEC" ]]; then
    echo "✗ HASH MISMATCH — .so is still stale! Run 'flutter_rust_bridge_codegen generate' then re-run this script." >&2
    exit 1
  fi
  echo "  ✓ hashes match"
fi

echo ""
echo "✓ Done. You can now: cd aura_notebook && flutter run -d linux"
