#!/bin/bash

set -euo pipefail

if [ "$#" != 2 ]; then
echo "usage: $0 TOOLCHAIN_ROOT MINGW_HOST_PREFIX" >&2
exit 2
fi

TOOLCHAIN=$(cd "$1" && pwd) || exit 1
HOST_PREFIX=$(cd "$2" && pwd) || exit 1
BIN=$TOOLCHAIN/bin
HOST_BIN=$HOST_PREFIX/bin
OBJDUMP=$HOST_BIN/objdump.exe

test -d "$BIN"
test -x "$OBJDUMP"

# The compiler driver itself imports libwinpthread, so the copy beside gcc.exe
# must match the UCRT64/MINGW64 host ABI.  The target sysroot may contain a DLL
# built for a different CRT; do not let that copy shadow the host runtime.
TARGET_PTHREAD=$TOOLCHAIN/x86_64-w64-mingw32/lib/libwinpthread-1.dll
HOST_PTHREAD=$HOST_BIN/libwinpthread-1.dll
test -f "$HOST_PTHREAD"

echo "host libwinpthread runtime: $HOST_PTHREAD"
sha256sum "$HOST_PTHREAD"
if [ -f "$TARGET_PTHREAD" ]; then
echo "target libwinpthread runtime: $TARGET_PTHREAD"
sha256sum "$TARGET_PTHREAD"
if cmp -s "$HOST_PTHREAD" "$TARGET_PTHREAD"; then
echo "host and target libwinpthread runtimes are identical"
else
echo "host and target libwinpthread runtimes differ; using the host runtime"
fi
fi
cp -fp "$HOST_PTHREAD" "$BIN/libwinpthread-1.dll"
echo "bundled host runtime: libwinpthread-1.dll"

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

# Copy the complete transitive DLL closure used by installed PE executables.
# Resolve imports from the active UCRT64/MINGW64 host prefix, but never replace
# runtimes already produced by this toolchain.  Re-scan copied DLLs until no
# additional dependency is discovered, so package version changes do not make
# a hand-maintained DLL list stale.
while :
do
: > "$WORK/imports"
while IFS= read -r -d '' PE
do
"$OBJDUMP" -p "$PE" | sed -n 's/.*DLL Name: //p' | tr -d '\r' >> "$WORK/imports" || exit 1
done < <(find "$TOOLCHAIN" -type f \( -iname '*.exe' -o -iname '*.dll' \) -print0)

sort -fu "$WORK/imports" > "$WORK/imports.sorted"
COPIED=0
while IFS= read -r DLL
do
test -n "$DLL" || continue
test -f "$BIN/$DLL" && continue
test -f "$HOST_BIN/$DLL" || continue
cp -p "$HOST_BIN/$DLL" "$BIN/$DLL"
echo "bundled host runtime: $DLL"
COPIED=$((COPIED + 1))
done < "$WORK/imports.sorted"

test "$COPIED" = 0 && break
done

test -f "$BIN/libwinpthread-1.dll"
echo "MinGW runtime DLL closure populated: $BIN"
