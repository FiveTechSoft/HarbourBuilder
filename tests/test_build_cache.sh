#!/usr/bin/env bash
# Exercise the actual dependency/signature helper used by build_linux.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
source "$ROOT/scripts/build_cache.sh"
printf 'source\n' > "$TMP/core.c"
obj="$TMP/core.o"
# Missing object, then failed compilation: neither may cache a success.
needs_rebuild "$obj" 'webkit=none' "$TMP/core.c"
[ ! -f "$obj.sha" ]
touch "$obj"
needs_rebuild "$obj" 'webkit=none' "$TMP/core.c"
record_build_signature "$obj" 'webkit=none' "$TMP/core.c"
if needs_rebuild "$obj" 'webkit=none' "$TMP/core.c"; then exit 1; fi
needs_rebuild "$obj" 'webkit=4.1' "$TMP/core.c"
record_build_signature "$obj" 'webkit=4.1' "$TMP/core.c"
if needs_rebuild "$obj" 'webkit=4.1' "$TMP/core.c"; then exit 1; fi
needs_rebuild "$obj" 'webkit=none' "$TMP/core.c"
printf 'changed\n' >> "$TMP/core.c"
needs_rebuild "$obj" 'webkit=4.1' "$TMP/core.c"
echo 'PASS: missing object, failed build, source and configuration invalidation'
