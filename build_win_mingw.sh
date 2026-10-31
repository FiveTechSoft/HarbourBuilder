#!/usr/bin/env bash
# Cross-build the Windows IDE (native win32 backend, same sources as build_win.bat)
# from Linux using a rootless mingw-w64 toolchain, for Wine smoke tests.
# Toolchain layout (rootless): see tests/wine-toolchain-setup.md or rebuild:
#   wine: Kron4ek wine-11.20-amd64-wow64 in $HOME/wine-toolchain/
#   mingw: Ubuntu debs (gcc/g++-mingw-w64-x86-64) extracted to $HOME/wine-toolchain/mingw-root
#   harbour win/mingw64 libs: make install from harbour source with
#   HB_PLATFORM=win HB_COMPILER=mingw64 HB_WITH_ZLIB=local HB_WITH_PNG=local
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
HBDIR_SRC="${HBDIR_SRC:-$HOME/harbour-src}"
MINGW_BIN="${MINGW_BIN:-$HOME/wine-toolchain/mingw-root/usr/bin}"
export PATH="$MINGW_BIN:$PATH" HBDIR="$HBDIR_SRC" HB_CCPATH="$MINGW_BIN/" HB_CCPREFIX=x86_64-w64-mingw32-
# _WIN32_WINNT/_WIN32_IE: mingw headers default lower than MSVC; match what the
# code uses (SetProcessDPIAware, TBCDRF_USECDCOLORS).
# hbmk2 (3.2.1dev r2610242111) mishandles absolute source paths: it derives an
# empty object basename ('/tmp/hbmk_*.dir/.c'), skips every compile and still
# exits 0 with a stale/partial output. Build from $ROOT with relative paths.
cd "$ROOT"
# Hardening: hbmk2 can exit 0 without compiling anything (see above), leaving a
# partial output behind. Build to a temp name, require proof that compiles
# actually ran and that the PE was produced by THIS build, promote only then.
BUILD_LOG="$(mktemp /tmp/hbwin-build.XXXXXX.log)"
TMP_EXE="bin/.hbbuilder_win.new"  # hbmk2 keeps the name as-is (dots = has-extension)
rm -f "$TMP_EXE"
START_EPOCH=$(date +%s)
"$HBDIR_SRC/bin/linux/gcc/hbmk2" -plat=win -comp=mingw64 -gui -w -es2 -O2 \
   -obin/.hbbuilder_win.new \
   source/hbbuilder_win.prg source/hbbuilder_common.prg \
   source/cpp/hbbridge.cpp source/cpp/tform.cpp \
   source/cpp/tcontrol.cpp source/cpp/tcontrols.cpp \
   source/cpp/hb_db_real.cpp \
   source/backends/win32/webview2/fwh_webview2.cpp \
   -Iinclude -Isource/backends/win32/webview2 \
   -cflag=-D_WIN32_WINNT=0x0601 -cflag=-D_WIN32_IE=0x0800 \
   -lgdiplus -lcomctl32 -lcomdlg32 -lmsimg32 -ldwmapi -lshlwapi -lwinspool \
   -lwininet -lhbsqlit3 -lsqlite3 -lstdc++ >"$BUILD_LOG" 2>&1
RC=$?
# Validity of the artifact, NOT its size: 1) hbmk2 RC, 2) both PRG units
# really compiled (the silent no-op prints zero "Compiling" lines and the
# empty-path nm error), 3) temp exe was written during THIS run.
COMPILES=$(grep -c "^Compiling '" "$BUILD_LOG" || true)
NM_EMPTY=$(grep -c "hbmk_.*\.dir/\.c'" "$BUILD_LOG" || true)
# NOTE: mingw links with a deterministic PE timestamp (reproducible builds),
# so freshness is proven by the temp file mtime, not the PE header.
TMP_MTIME=0
[ -f "$TMP_EXE" ] && TMP_MTIME=$(stat -c %Y "$TMP_EXE")
if [ "$RC" -ne 0 ] || [ "$COMPILES" -lt 2 ] || [ "$NM_EMPTY" -ne 0 ] || [ "$TMP_MTIME" -lt "$START_EPOCH" ]; then
  echo "BUILD FAILED/UNVERIFIED: rc=$RC compiling_lines=$COMPILES nm_empty=$NM_EMPTY tmp_mtime=$TMP_MTIME start=$START_EPOCH" >&2
  echo "log: $BUILD_LOG (preserved)" >&2
  rm -f "$TMP_EXE"
  exit 1
fi
mv -f "$TMP_EXE" bin/hbbuilder_win.exe
echo "build OK: rc=0 compiling_lines=$COMPILES tmp_mtime=$TMP_MTIME log=$BUILD_LOG"
# Runtime DLLs next to the exe (paridad con build_win.bat, que copia Scintilla):
cp -f "$ROOT/resources/x64/Scintilla.dll" "$ROOT/resources/x64/Lexilla.dll" "$ROOT/bin/" 2>/dev/null
cp -f "$MINGW_BIN/../lib/gcc/x86_64-w64-mingw32/10-posix/libstdc++-6.dll" \
      "$MINGW_BIN/../lib/gcc/x86_64-w64-mingw32/10-posix/libgcc_s_seh-1.dll" \
      "$MINGW_BIN/../x86_64-w64-mingw32/lib/libwinpthread-1.dll" "$ROOT/bin/" 2>/dev/null
