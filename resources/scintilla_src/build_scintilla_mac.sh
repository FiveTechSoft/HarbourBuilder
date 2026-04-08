#!/bin/bash
# Build Scintilla + Lexilla as static libraries for macOS
# Produces: libscintilla.a + liblexilla.a

set -e

SCIDIR="$(cd "$(dirname "$0")" && pwd)"
SCINTILLA="$SCIDIR/scintilla"
LEXILLA="$SCIDIR/lexilla"
BUILDDIR="$SCIDIR/build"

mkdir -p "$BUILDDIR/obj_sci" "$BUILDDIR/obj_lex"

CXX="clang++"
CXXFLAGS="-std=c++17 -O2 -mmacosx-version-min=10.15 -DNDEBUG -DSCI_NAMESPACE -DSCI_LEXER"
CXXFLAGS="$CXXFLAGS -I$SCINTILLA/include -I$SCINTILLA/src"
OBJCFLAGS="-fobjc-arc"

echo "[1/4] Compiling Scintilla core (C++ sources)..."
for f in "$SCINTILLA"/src/*.cxx; do
    base=$(basename "$f" .cxx)
    $CXX $CXXFLAGS -c "$f" -o "$BUILDDIR/obj_sci/${base}.o" &
done
wait

echo "[2/4] Compiling Scintilla Cocoa (Objective-C++ sources)..."
COCOA_INC="-I$SCINTILLA/cocoa -I$SCINTILLA/include -I$SCINTILLA/src"
for f in "$SCINTILLA"/cocoa/*.mm; do
    base=$(basename "$f" .mm)
    $CXX $CXXFLAGS $COCOA_INC $OBJCFLAGS -c "$f" -o "$BUILDDIR/obj_sci/${base}.o" &
done
wait

echo "[3/4] Compiling Lexilla (lexlib + all lexers)..."
LEXFLAGS="$CXXFLAGS -I$LEXILLA/include -I$LEXILLA/lexlib -I$SCINTILLA/include"
for f in "$LEXILLA"/lexlib/*.cxx; do
    base=$(basename "$f" .cxx)
    $CXX $LEXFLAGS -c "$f" -o "$BUILDDIR/obj_lex/${base}.o" &
done
wait

# Lexers (compile in batches to avoid too many parallel processes)
for f in "$LEXILLA"/lexers/*.cxx; do
    base=$(basename "$f" .cxx)
    $CXX $LEXFLAGS -c "$f" -o "$BUILDDIR/obj_lex/${base}.o" &
done
wait

# Lexilla.cxx (entry point)
$CXX $LEXFLAGS -I"$LEXILLA/src" -c "$LEXILLA/src/Lexilla.cxx" -o "$BUILDDIR/obj_lex/Lexilla.o"

echo "[4/4] Creating static libraries..."
ar rcs "$BUILDDIR/libscintilla.a" "$BUILDDIR"/obj_sci/*.o
ar rcs "$BUILDDIR/liblexilla.a" "$BUILDDIR"/obj_lex/*.o

echo ""
echo "=== Build complete ==="
ls -lh "$BUILDDIR/libscintilla.a" "$BUILDDIR/liblexilla.a"
echo ""
echo "Headers: $SCINTILLA/include/ + $SCINTILLA/cocoa/"
