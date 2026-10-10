#!/bin/bash
# Build reproducible CPU-specific distributions without changing the local target.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
ROOT=$PWD
mkdir -p build/releases
for variant in m3 i7; do
  case "$variant" in m3) cpu=m3-7Y32;; i7) cpu=i7-7Y75;; esac
  name="12Limit-Power-1.3.0-$variant"
  stage="$ROOT/build/releases/$name"
  [ ! -e "$stage" ] || { echo "Remove existing staging directory before rebuilding: $stage"; exit 1; }
  mkdir -p "$stage"
  for file in README.md LICENSE src scripts vendor release-notes; do /usr/bin/ditto "$ROOT/$file" "$stage/$file"; done
  mkdir -p "$stage/tests"
  cp "$ROOT"/tests/*.py "$stage/tests/"
  printf '%s\n' "$cpu" > "$stage/target-cpu.txt"
  /bin/bash "$stage/scripts/build-app.sh"
  cp "$stage/scripts/install.command" "$stage/Install.command"
  chmod 755 "$stage/Install.command"
  /usr/bin/codesign --verify --deep --strict "$stage/build/12Limit Power.app"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$stage" "$ROOT/build/releases/$name.zip"
done
cd build/releases
/usr/bin/shasum -a 256 ./*.zip > SHA256SUMS.txt
