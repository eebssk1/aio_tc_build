#!/bin/bash

set -euo pipefail

if [ "$#" != 1 ]; then
echo "usage: $0 TOOLCHAIN_ROOT" >&2
exit 2
fi

TOOLCHAIN=$(cd "$1" && pwd) || exit 1
BIN=$TOOLCHAIN/bin
TARGET=x86_64-w64-mingw32

test -x "$BIN/gcc.exe"
test -x "$BIN/g++.exe"
test -x "$BIN/gcc-ar.exe"
test -x "$BIN/objdump.exe"
test -f "$BIN/libgcc_s_seh-1.dll"
test -f "$BIN/libstdc++-6.dll"
test -f "$BIN/libgomp-1.dll"
test -f "$BIN/libwinpthread-1.dll"

# Do not let the runner's UCRT64/MINGW64 toolchain or stale build-tree paths
# satisfy a compiler, linker, header, library, or runtime DLL lookup.  Windows
# system DLLs remain available through the normal loader search order.
unset CC CXX CFLAGS CXXFLAGS CPPFLAGS LDFLAGS
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH
unset GCC_EXEC_PREFIX COMPILER_PATH
export PATH="$BIN:/usr/bin"

test "$(gcc.exe -dumpmachine)" = "$TARGET"
test "$(g++.exe -dumpmachine)" = "$TARGET"
gcc.exe --version
LD_VERSION=$(ld.exe --version)
printf '%s\n' "$LD_VERSION" | sed -n '1p'

WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

cat > smoke.c <<'EOF'
#include <stdio.h>

int main(void)
{
  puts("c-ok");
  return 0;
}
EOF

gcc.exe -O2 -Wall -Wextra -Werror smoke.c -o smoke-c.exe
test "$(./smoke-c.exe)" = "c-ok"
objdump.exe -f smoke-c.exe | grep -Fq 'file format pei-x86-64'

cat > smoke.cc <<'EOF'
#include <iostream>
#include <numeric>
#include <vector>

int main()
{
  const std::vector<int> values{1, 2, 3, 4};
  if (std::accumulate(values.begin(), values.end(), 0) != 10)
    return 1;
  std::cout << "cxx-ok\n";
  return 0;
}
EOF

g++.exe -std=c++20 -O2 -Wall -Wextra -Werror smoke.cc -o smoke-cxx.exe
test "$(./smoke-cxx.exe)" = "cxx-ok"

cat > lto-lib.c <<'EOF'
int lto_answer(void)
{
  return 42;
}
EOF

cat > lto-main.c <<'EOF'
#include <stdio.h>

int lto_answer(void);

int main(void)
{
  if (lto_answer() != 42)
    return 1;
  puts("lto-ok");
  return 0;
}
EOF

gcc.exe -O2 -flto -c lto-lib.c -o lto-lib.o
gcc-ar.exe rcs liblto-smoke.a lto-lib.o
gcc.exe -O2 -flto lto-main.c -L. -llto-smoke -o smoke-lto.exe
test "$(./smoke-lto.exe)" = "lto-ok"

cat > shared.c <<'EOF'
__declspec(dllexport) int shared_answer(void)
{
  return 42;
}
EOF

cat > shared-main.c <<'EOF'
#include <stdio.h>

__declspec(dllimport) int shared_answer(void);

int main(void)
{
  if (shared_answer() != 42)
    return 1;
  puts("dll-ok");
  return 0;
}
EOF

gcc.exe -O2 -shared shared.c -Wl,--out-implib,libsmoke.dll.a -o smoke.dll
gcc.exe -O2 shared-main.c -L. -lsmoke -o smoke-dll.exe
test "$(./smoke-dll.exe)" = "dll-ok"

cat > openmp.c <<'EOF'
#include <omp.h>
#include <stdio.h>

int main(void)
{
  int threads = 0;
#pragma omp parallel reduction(+:threads)
  threads += 1;
  if (threads < 1 || omp_get_max_threads() < 1)
    return 1;
  puts("openmp-ok");
  return 0;
}
EOF

gcc.exe -O2 -fopenmp openmp.c -o smoke-openmp.exe
test "$(./smoke-openmp.exe)" = "openmp-ok"

echo "native MinGW toolchain smoke test passed: $TOOLCHAIN"
