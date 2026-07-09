#!/usr/bin/env bash
# clean.sh - Remove build artifacts for HarbourBuilder (Linux/macOS)

echo "Cleaning build artifacts..."

# Root
rm -f *.obj *.o *.exe *.tds *.log *.res *.c 2>/dev/null || true
rm -f startup_timing.log pos_trace.log error_trace.log save_trace.log android_trace.log scintilla_trace.log palette*.log inspector_trace.log bp_trace.log pause_trace.log 2>/dev/null || true

# Dirs
rm -rf test_memo terminals hbbuilder_build hbbuilder_debug 2>/dev/null || true

# Samples/tests
find samples -name '*.obj' -o -name '*.o' -o -name '*.exe' -o -name '*.tds' -o -name '*.log' -o -name '*.c' 2>/dev/null | xargs rm -f || true
find tests -name '*.obj' -o -name '*.o' -o -name '*.c' 2>/dev/null | xargs rm -f || true
rm -rf tests/bin 2>/dev/null || true

# Android/iOS temps
rm -rf "${TEMP:-/tmp}/HarbourAndroid" /c/HarbourAndroid 2>/dev/null || true
rm -rf /tmp/HarbouriOS 2>/dev/null || true

echo "Done."
