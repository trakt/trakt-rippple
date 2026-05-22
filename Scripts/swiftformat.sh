#!/bin/sh

set -u

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MODE="lint"
SCOPE="changed"
BUILD_PHASE=0
STRICT="${SWIFTFORMAT_STRICT:-0}"

if [ "${CI:-}" = "true" ]; then
  STRICT=1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --format)
      MODE="format"
      ;;
    --lint)
      MODE="lint"
      ;;
    --strict)
      STRICT=1
      ;;
    --all)
      SCOPE="all"
      ;;
    --changed)
      SCOPE="changed"
      ;;
    --xcode-build-phase)
      BUILD_PHASE=1
      ;;
    *)
      echo "error: Unknown SwiftFormat option '$1'." >&2
      echo "usage: Scripts/swiftformat.sh [--format|--lint] [--changed|--all] [--strict]" >&2
      exit 64
      ;;
  esac
  shift
done

if [ "${SWIFTFORMAT_DISABLED:-0}" = "1" ] || [ "${SKIP_SWIFTFORMAT:-0}" = "1" ]; then
  echo "warning: SwiftFormat skipped because SWIFTFORMAT_DISABLED or SKIP_SWIFTFORMAT is set."
  exit 0
fi

changed_filelist() {
  filelist="$ROOT/BuildTools/.build/swiftformat-changed-files-$$"
  tmpfile="$filelist.tmp"
  mkdir -p "$(dirname "$filelist")"
  : > "$tmpfile"

  git -C "$ROOT" diff --name-only --diff-filter=ACMR HEAD -- '*.swift' >> "$tmpfile" 2>/dev/null || true
  git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR -- '*.swift' >> "$tmpfile" 2>/dev/null || true
  git -C "$ROOT" ls-files --others --exclude-standard -- '*.swift' >> "$tmpfile" 2>/dev/null || true

  sort -u "$tmpfile" | while IFS= read -r path; do
    case "$path" in
      BuildTools/*|Pods/*|build/*|Rippple/Secrets.swift)
        continue
        ;;
    esac

    if [ -f "$ROOT/$path" ]; then
      printf '%s\n' "$ROOT/$path"
    fi
  done > "$filelist"

  rm -f "$tmpfile"
  printf '%s\n' "$filelist"
}

execute_swiftformat() {
  swiftformat_binary="$ROOT/BuildTools/.build/release/swiftformat"

  if [ -x "$swiftformat_binary" ]; then
    "$swiftformat_binary" "$@"
  elif [ "$BUILD_PHASE" = "1" ] && [ "$STRICT" != "1" ]; then
    echo "warning: SwiftFormat tool is not built yet. Run Scripts/swiftformat.sh --lint --changed once to prepare it. Skipping this build."
    return 0
  else
    swift run -c release --package-path "$ROOT/BuildTools" swiftformat "$@"
  fi
}

run_swiftformat() {
  if [ "$SCOPE" = "changed" ]; then
    filelist="$(changed_filelist)"
    if [ ! -s "$filelist" ]; then
      echo "SwiftFormat: no changed Swift files."
      rm -f "$filelist"
      return 0
    fi
    execute_swiftformat --filelist "$filelist" --config "$ROOT/.swiftformat" --cache "$ROOT/BuildTools/.build/swiftformat.cache" "$@"
    status=$?
    rm -f "$filelist"
    return "$status"
  else
    mkdir -p "$ROOT/BuildTools/.build"
    execute_swiftformat "$ROOT" --config "$ROOT/.swiftformat" --cache "$ROOT/BuildTools/.build/swiftformat.cache" "$@"
  fi
}

if [ "$MODE" = "lint" ]; then
  if [ "$STRICT" = "1" ]; then
    run_swiftformat --lint
  else
    run_swiftformat --lint --lenient
  fi
else
  run_swiftformat
fi

status=$?
if [ "$status" -ne 0 ]; then
  if [ "$BUILD_PHASE" = "1" ] && [ "$STRICT" != "1" ]; then
    echo "warning: SwiftFormat did not complete. Run Scripts/swiftformat.sh --format manually, or set SWIFTFORMAT_STRICT=1 to make this build phase fail."
    exit 0
  fi
  exit "$status"
fi
