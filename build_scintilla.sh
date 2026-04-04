#!/bin/bash
# build_scintilla.sh - Download and build Scintilla + Lexilla shared libraries for Linux GTK3
#
# Produces:
#   resources/libscintilla.so  (Scintilla 5.6.1 GTK widget)
#   resources/liblexilla.so    (Lexilla 5.4.8 lexer library)
#
# Prerequisites:
#   sudo apt install libgtk-3-dev g++ make wget

set -e

PROJDIR="$(cd "$(dirname "$0")" && pwd)"
RESDIR="$PROJDIR/resources"
BUILDDIR="/tmp/scintilla_build_$$"

SCI_VER="561"
LEX_VER="548"
SCI_URL="https://www.scintilla.org/scintilla${SCI_VER}.tgz"
LEX_URL="https://www.scintilla.org/lexilla${LEX_VER}.tgz"

echo "=== Building Scintilla + Lexilla for Linux GTK3 ==="
echo "Build directory: $BUILDDIR"
echo ""

mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

# Download sources
if [ ! -f "scintilla${SCI_VER}.tgz" ]; then
   echo "[1/4] Downloading Scintilla ${SCI_VER}..."
   wget -q "$SCI_URL" -O "scintilla${SCI_VER}.tgz"
fi

if [ ! -f "lexilla${LEX_VER}.tgz" ]; then
   echo "[2/4] Downloading Lexilla ${LEX_VER}..."
   wget -q "$LEX_URL" -O "lexilla${LEX_VER}.tgz"
fi

# Extract
echo "[3/4] Extracting and building..."
tar xzf "scintilla${SCI_VER}.tgz"
tar xzf "lexilla${LEX_VER}.tgz"

# Build Scintilla GTK
echo "  Building Scintilla (GTK3)..."
cd "$BUILDDIR/scintilla/gtk"
make GTK3=1 -j$(nproc) 2>&1 | tail -3

# Build Lexilla
echo "  Building Lexilla..."
cd "$BUILDDIR/lexilla/src"
make -j$(nproc) 2>&1 | tail -3

# Copy results
echo "[4/4] Installing to $RESDIR..."
mkdir -p "$RESDIR"

# Scintilla produces bin/scintilla.a or libscintilla.so depending on Makefile
# The GTK build creates a .so in bin/
if [ -f "$BUILDDIR/scintilla/bin/libscintilla.so" ]; then
   cp "$BUILDDIR/scintilla/bin/libscintilla.so" "$RESDIR/libscintilla.so"
elif [ -f "$BUILDDIR/scintilla/bin/scintilla.a" ]; then
   # Older Scintilla builds produce static lib - create shared from it
   echo "  Creating shared library from static archive..."
   cd "$BUILDDIR"
   g++ -shared -o "$RESDIR/libscintilla.so" \
      -Wl,--whole-archive "$BUILDDIR/scintilla/bin/scintilla.a" -Wl,--no-whole-archive \
      $(pkg-config --libs gtk+-3.0) -lstdc++
fi

# Lexilla produces bin/liblexilla.so
if [ -f "$BUILDDIR/lexilla/bin/liblexilla.so" ]; then
   cp "$BUILDDIR/lexilla/bin/liblexilla.so" "$RESDIR/liblexilla.so"
elif [ -f "$BUILDDIR/lexilla/bin/Lexilla.so" ]; then
   cp "$BUILDDIR/lexilla/bin/Lexilla.so" "$RESDIR/liblexilla.so"
fi

# Verify
echo ""
if [ -f "$RESDIR/libscintilla.so" ] && [ -f "$RESDIR/liblexilla.so" ]; then
   ls -lh "$RESDIR/libscintilla.so" "$RESDIR/liblexilla.so"
   echo ""
   echo "=== Scintilla + Lexilla built successfully ==="
else
   echo "ERROR: Build failed - check output above"
   exit 1
fi

# Cleanup
echo "Cleaning up build directory..."
rm -rf "$BUILDDIR"
