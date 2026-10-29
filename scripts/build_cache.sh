#!/usr/bin/env bash
# Signature includes explicit build configuration plus all declared inputs.
# Write the stamp only after compilation succeeds, never during a cache query.
build_signature() {
   local config="$1"; shift
   { printf '%s\n' "$config"; sha1sum "$@"; } | sha1sum | awk '{print $1}'
}
needs_rebuild() {
   local obj="$1" config="$2"; shift 2
   [ ! -f "$obj" ] && return 0
   [ ! -f "$obj.sha" ] && return 0
   [ "$(build_signature "$config" "$@")" != "$(cat "$obj.sha")" ]
}
record_build_signature() {
   local obj="$1" config="$2"; shift 2
   build_signature "$config" "$@" > "$obj.sha"
}
