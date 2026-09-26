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
TARGET=x86_64-w64-mingw32
TARGET_LIB=$TOOLCHAIN/$TARGET/lib
TARGET_RUNTIME=$TOOLCHAIN/$TARGET/runtime

test -d "$BIN"
test -x "$OBJDUMP"

# Preserve the DLLs built for target programs before populating the host-tool
# closure in top-level bin.  Native compiler programs and their output share
# the same PE architecture, but their pthread/GCC runtimes can come from
# different builds and are not interchangeable.  Keep the deployment closure
# outside target/bin because that directory contains host as.exe/ld.exe and
# therefore needs host DLLs beside those executables.
mkdir -p "$TARGET_RUNTIME"
for DLL in \
  libatomic-1.dll \
  libgcc_s_seh-1.dll \
  libgomp-1.dll \
  libstdc++-6.dll \
  libwinpthread-1.dll
do
SOURCE=
if [ -f "$TARGET_LIB/$DLL" ]; then
SOURCE=$TARGET_LIB/$DLL
elif [ -f "$BIN/$DLL" ]; then
SOURCE=$BIN/$DLL
fi
test -n "$SOURCE" || continue
cp -fp "$SOURCE" "$TARGET_RUNTIME/$DLL"
echo "preserved target runtime: $TARGET_RUNTIME/$DLL"
done

# GCC's driver imports both libgcc and libwinpthread.  A target-built libgcc
# copied beside gcc.exe can prevent native compiler tools from starting.
# Preserve the target runtimes above before installing the host DLLs.
TARGET_PTHREAD=$TARGET_LIB/libwinpthread-1.dll
HOST_PTHREAD=$HOST_BIN/libwinpthread-1.dll
HOST_LIBGCC=$HOST_BIN/libgcc_s_seh-1.dll
test -f "$HOST_PTHREAD"
test -f "$HOST_LIBGCC"

echo "host libwinpthread runtime: $HOST_PTHREAD"
HOST_PTHREAD_HASH=$(sha256sum "$HOST_PTHREAD" | sed 's/[[:space:]].*//')
echo "$HOST_PTHREAD_HASH  $HOST_PTHREAD"
if [ -f "$TARGET_PTHREAD" ]; then
echo "target libwinpthread runtime: $TARGET_PTHREAD"
TARGET_PTHREAD_HASH=$(sha256sum "$TARGET_PTHREAD" | sed 's/[[:space:]].*//')
echo "$TARGET_PTHREAD_HASH  $TARGET_PTHREAD"
if [ "$HOST_PTHREAD_HASH" = "$TARGET_PTHREAD_HASH" ]; then
echo "host and target libwinpthread runtimes are identical"
else
echo "host and target libwinpthread runtimes differ; using the host runtime"
fi
fi
cp -fp "$HOST_PTHREAD" "$BIN/libwinpthread-1.dll"
echo "bundled host runtime: libwinpthread-1.dll"
cp -fp "$HOST_LIBGCC" "$BIN/libgcc_s_seh-1.dll"
echo "bundled host runtime: libgcc_s_seh-1.dll"

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT

# Copy the complete transitive DLL closure used by installed PE executables.
# Resolve imports from the active UCRT64/MINGW64 host prefix, but never replace
# other runtimes already produced by this toolchain.  Re-scan copied DLLs until
# no additional dependency is discovered.
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

# Windows searches the executable's directory before PATH.  Repair an
# existing target-built libgcc in each host executable directory rather than
# allowing it to shadow the host DLL copied above.
find "$TOOLCHAIN" -type f -iname '*.exe' -printf '%h\n' | sort -u > "$WORK/exe-dirs"
while IFS= read -r PE_DIR
do
if [ -f "$PE_DIR/libgcc_s_seh-1.dll" ]; then
cp -fp "$HOST_LIBGCC" "$PE_DIR/libgcc_s_seh-1.dll"
echo "bundled adjacent host runtime: $PE_DIR/libgcc_s_seh-1.dll"
fi
while IFS= read -r DLL
do
test -n "$DLL" || continue
test -f "$PE_DIR/$DLL" && continue
SOURCE=
if [ -f "$HOST_BIN/$DLL" ]; then
SOURCE=$HOST_BIN/$DLL
elif [ -f "$BIN/$DLL" ]; then
SOURCE=$BIN/$DLL
fi
test -n "$SOURCE" || continue
cp -p "$SOURCE" "$PE_DIR/$DLL"
echo "bundled adjacent runtime: $PE_DIR/$DLL"
done < "$WORK/imports.sorted"
done < "$WORK/exe-dirs"

test -f "$BIN/libwinpthread-1.dll"
test -f "$TARGET_RUNTIME/libgcc_s_seh-1.dll"
test -f "$TARGET_RUNTIME/libstdc++-6.dll"
test -f "$TARGET_RUNTIME/libgomp-1.dll"
test -f "$TARGET_RUNTIME/libwinpthread-1.dll"
if [ -f "$TARGET_PTHREAD" ]; then
test "$(sha256sum "$TARGET_RUNTIME/libwinpthread-1.dll" | sed 's/[[:space:]].*//')" = "$TARGET_PTHREAD_HASH"
fi
echo "MinGW runtime DLL closure populated: $BIN"
