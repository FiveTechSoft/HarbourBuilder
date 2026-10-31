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
"$HBDIR_SRC/bin/linux/gcc/hbmk2" -plat=win -comp=mingw64 -gui -w -es2 -O2 \
   -obin/hbbuilder_win \
   source/hbbuilder_win.prg source/hbbuilder_common.prg \
   source/cpp/hbbridge.cpp source/cpp/tform.cpp \
   source/cpp/tcontrol.cpp source/cpp/tcontrols.cpp \
   source/cpp/hb_db_real.cpp \
   source/backends/win32/webview2/fwh_webview2.cpp \
   -Iinclude -Isource/backends/win32/webview2 \
   -cflag=-D_WIN32_WINNT=0x0601 -cflag=-D_WIN32_IE=0x0800 \
   -lgdiplus -lcomctl32 -lcomdlg32 -lmsimg32 -ldwmapi -lshlwapi -lwinspool \
   -lwininet -lhbsqlit3 -lsqlite3 -lstdc++
# Runtime DLLs next to the exe (paridad con build_win.bat, que copia Scintilla):
cp -f "$ROOT/resources/x64/Scintilla.dll" "$ROOT/resources/x64/Lexilla.dll" "$ROOT/bin/" 2>/dev/null
cp -f "$MINGW_BIN/../lib/gcc/x86_64-w64-mingw32/10-posix/libstdc++-6.dll" \
      "$MINGW_BIN/../lib/gcc/x86_64-w64-mingw32/10-posix/libgcc_s_seh-1.dll" \
      "$MINGW_BIN/../x86_64-w64-mingw32/lib/libwinpthread-1.dll" "$ROOT/bin/" 2>/dev/null
